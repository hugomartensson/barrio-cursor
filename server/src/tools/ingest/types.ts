import type { Category, ItemType } from '@prisma/client';

export interface DraftFields {
  itemType: ItemType | null;
  name: string | null;
  description: string | null;
  category: Category | null;
  address: string | null;
  neighborhood: string | null;
  startTime: string | null;
  endTime: string | null;
  tags: string[];
  imageUrl: string | null;
}

export interface MapperInput {
  rawText?: string;
  sourceUrl?: string;
  imageBase64?: string;
  imageMimeType?: string;
  partialFields?: Partial<DraftFields>;
  preferredType?: ItemType;
}

export interface FetcherResult extends Partial<DraftFields> {
  rawText?: string;
}

export const EMPTY_DRAFT_FIELDS: DraftFields = {
  itemType: null,
  name: null,
  description: null,
  category: null,
  address: null,
  neighborhood: null,
  startTime: null,
  endTime: null,
  tags: [],
  imageUrl: null,
};

export const REQUIRED_FIELDS: (keyof DraftFields)[] = [
  'itemType',
  'name',
  'description',
  'category',
  'address',
  'imageUrl',
];
