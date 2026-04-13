import { createStep, createWorkflow } from '@mastra/core/workflows';
import { downloadAndUploadIngestImage } from '../lib/ingest-image.js';
import { resolvePlaceCoordinates } from '../lib/places-resolve.js';
import { draftToPublishPayload, getPortalClient } from '../lib/portal-client.js';
import {
  draftSchema,
  humanResumeSchema,
  humanSuspendSchema,
  publishInputSchema,
  publishOutputSchema,
  verifiedDraftSchema,
  workflowInputSchema,
} from '../schemas/draft.js';

const extractStep = createStep({
  id: 'extract',
  inputSchema: workflowInputSchema,
  outputSchema: draftSchema,
  execute: async ({ inputData, mastra }) => {
    const agent = mastra.getAgent('extractor');
    let prompt = '';
    if (inputData.inputType === 'telegram_link') {
      prompt = `Extract venue/event data from this URL: ${inputData.rawInput}`;
    } else if (inputData.inputType === 'telegram_text') {
      prompt = `Find and extract venue/event data for: ${inputData.rawInput}`;
    } else {
      prompt = `Extract venue/event data from: ${inputData.rawInput}`;
    }
    if (inputData.contextNote) {
      prompt += `\n\nAdditional context from the user: ${inputData.contextNote}`;
    }

    const result = await agent.generate(prompt, {
      structuredOutput: {
        schema: draftSchema,
        // Gemini 2.5: cannot combine API response_format (JSON) with tools in one call
        jsonPromptInjection: true,
      },
      maxSteps: 28,
    });

    const draft = result.object;
    console.log('[ingest:extract] image decision', {
      name: draft.name,
      hasImage: Boolean(draft.imageUrl),
      imageSource: draft.imageSource ?? 'not_set',
      candidateCount: draft.imageUrls?.length ?? 0,
      imageUrl: draft.imageUrl ?? null,
    });

    return draft;
  },
});

const verifyStep = createStep({
  id: 'verify',
  inputSchema: draftSchema,
  outputSchema: verifiedDraftSchema,
  execute: async ({ inputData, mastra }) => {
    const verifier = mastra.getAgent('verifier');
    const result = await verifier.generate(
      `Review this extracted Portal draft JSON and return the corrected full object including verifierNotes.\n${JSON.stringify(inputData, null, 2)}`,
      {
        structuredOutput: { schema: verifiedDraftSchema },
        maxSteps: 8,
      },
    );
    return result.object;
  },
});

const enrichLocationStep = createStep({
  id: 'enrich-location',
  inputSchema: verifiedDraftSchema,
  outputSchema: verifiedDraftSchema,
  execute: async ({ inputData }) => {
    const addr = inputData.address?.trim();
    if (!addr) {
      return {
        ...inputData,
        publishReady: false,
        publishBlockers: ['Missing address for location'],
      };
    }
    const r = await resolvePlaceCoordinates({
      address: addr,
      name: inputData.name,
      neighborhood: inputData.neighborhood,
    });
    if (!r.ok) {
      return {
        ...inputData,
        publishReady: false,
        publishBlockers: [r.reason],
      };
    }
    return {
      ...inputData,
      latitude: r.latitude,
      longitude: r.longitude,
      resolvedAddress: r.formattedAddress,
      placeId: r.placeId,
      publishReady: true,
      publishBlockers: [],
    };
  },
});

const humanReviewStep = createStep({
  id: 'human-review',
  inputSchema: verifiedDraftSchema,
  outputSchema: publishInputSchema,
  resumeSchema: humanResumeSchema,
  suspendSchema: humanSuspendSchema,
  execute: async ({ inputData, resumeData, suspend, bail }) => {
    if (resumeData === undefined || typeof resumeData.approved !== 'boolean') {
      return await suspend({
        draft: inputData,
        message: `Draft ready: ${inputData.name ?? 'Unnamed'} (${inputData.type})`,
      });
    }

    if (resumeData.approved === false) {
      return bail({ reason: 'Skipped by reviewer' });
    }

    const { verifierNotes: _drop, ...base } = inputData;
    const merged = {
      ...base,
      ...(resumeData.correctedFields ?? {}),
    };
    const out = { ...merged, collectionId: resumeData.collectionId ?? undefined };
    return out;
  },
});

const publishStep = createStep({
  id: 'publish',
  inputSchema: publishInputSchema,
  outputSchema: publishOutputSchema,
  execute: async ({ inputData }) => {
    const imageSource = inputData.imageUrl;
    if (!imageSource) {
      throw new Error('Cannot publish: imageUrl is required');
    }

    const supabaseUrl = await downloadAndUploadIngestImage(imageSource);
    const { collectionId, ...draftFields } = inputData;
    const payload = draftToPublishPayload(
      { ...draftFields, collectionId: collectionId ?? null },
      supabaseUrl,
    );
    return getPortalClient().publish(payload);
  },
});

export const ingestWorkflow = createWorkflow({
  id: 'ingest',
  inputSchema: workflowInputSchema,
  outputSchema: publishOutputSchema,
})
  .then(extractStep)
  .then(verifyStep)
  .then(enrichLocationStep)
  .then(humanReviewStep)
  .then(publishStep)
  .commit();
