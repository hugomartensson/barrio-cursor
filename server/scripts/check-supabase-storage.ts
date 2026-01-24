/**
 * Diagnostic script to check Supabase Storage configuration
 * Run with: tsx scripts/check-supabase-storage.ts
 */

import { supabaseAdmin, STORAGE_BUCKET } from '../src/services/supabase.js';
import { config } from '../src/config/index.js';

async function checkStorageBucket() {
  console.log('🔍 Checking Supabase Storage configuration...\n');

  // 1. Check bucket name
  console.log(`📦 Bucket name: ${STORAGE_BUCKET}`);
  console.log(`🔗 Supabase URL: ${config.SUPABASE_URL}`);
  console.log(`🔑 Service key present: ${config.SUPABASE_SERVICE_KEY ? 'Yes' : 'No'}\n`);

  // 2. Check if bucket exists
  console.log('1️⃣ Checking if bucket exists...');
  try {
    const { data: buckets, error: listError } = await supabaseAdmin.storage.listBuckets();

    if (listError) {
      console.error(`   ❌ Error listing buckets: ${listError.message}`);
      console.error(`   Error details:`, listError);
      return;
    }

    console.log(`   ✅ Found ${buckets?.length || 0} bucket(s):`);
    buckets?.forEach((bucket) => {
      console.log(`      - ${bucket.name} (${bucket.public ? 'public' : 'private'})`);
    });

    const bucketExists = buckets?.some((b) => b.name === STORAGE_BUCKET);
    if (bucketExists) {
      console.log(`   ✅ Bucket "${STORAGE_BUCKET}" exists!\n`);
    } else {
      console.log(`   ❌ Bucket "${STORAGE_BUCKET}" does NOT exist!\n`);
      console.log(`   💡 You need to create it in Supabase Dashboard or via API\n`);
    }
  } catch (error) {
    console.error(`   ❌ Exception checking buckets:`, error);
  }

  // 3. Test uploading a small file
  console.log('2️⃣ Testing file upload...');
  try {
    const testContent = Buffer.from('test file content');
    const testPath = `test-${Date.now()}.txt`;

    const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
      .from(STORAGE_BUCKET)
      .upload(testPath, testContent, {
        contentType: 'text/plain',
        upsert: false,
      });

    if (uploadError) {
      console.error(`   ❌ Upload failed: ${uploadError.message}`);
      console.error(`   Error details:`, uploadError);
    } else {
      console.log(`   ✅ Upload successful! Path: ${uploadData.path}`);

      // Try to get public URL
      const {
        data: { publicUrl },
      } = supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(testPath);
      console.log(`   ✅ Public URL: ${publicUrl}`);

      // Clean up test file
      await supabaseAdmin.storage.from(STORAGE_BUCKET).remove([testPath]);
      console.log(`   🧹 Cleaned up test file\n`);
    }
  } catch (error) {
    console.error(`   ❌ Exception during upload test:`, error);
  }

  // 4. Test fetching from Picsum Photos
  console.log('3️⃣ Testing Picsum Photos API...');
  try {
    const testUrl = 'https://picsum.photos/800/600';
    console.log(`   Testing URL: ${testUrl}`);

    const response = await fetch(testUrl, {
      method: 'HEAD', // Just check if it exists
      redirect: 'follow',
    });

    console.log(`   Status: ${response.status} ${response.statusText}`);
    console.log(`   Content-Type: ${response.headers.get('content-type')}`);
    console.log(`   Content-Length: ${response.headers.get('content-length')}`);

    if (response.ok) {
      console.log(`   ✅ Picsum Photos URL is accessible\n`);
    } else {
      console.log(`   ⚠️  Picsum Photos URL returned non-OK status\n`);
    }
  } catch (error) {
    console.error(`   ❌ Exception fetching from Picsum Photos:`, error);
    console.error(`   Error:`, error instanceof Error ? error.message : error);
  }

  // 5. Test full upload flow (download from Picsum and upload)
  console.log('4️⃣ Testing full upload flow (download → upload)...');
  try {
    const testImageUrl = 'https://picsum.photos/800/600';
    console.log(`   Downloading from: ${testImageUrl}`);

    const fetchResponse = await fetch(testImageUrl, {
      redirect: 'follow',
    });

    if (!fetchResponse.ok) {
      throw new Error(`Failed to fetch: ${fetchResponse.statusText}`);
    }

    const arrayBuffer = await fetchResponse.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    console.log(`   ✅ Downloaded ${buffer.length} bytes`);

    const uploadPath = `test-upload-${Date.now()}.jpg`;
    const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
      .from(STORAGE_BUCKET)
      .upload(uploadPath, buffer, {
        contentType: 'image/jpeg',
        upsert: false,
      });

    if (uploadError) {
      console.error(`   ❌ Upload to Supabase failed: ${uploadError.message}`);
      console.error(`   Error details:`, uploadError);
    } else {
      console.log(`   ✅ Successfully uploaded to Supabase!`);
      const {
        data: { publicUrl },
      } = supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(uploadPath);
      console.log(`   ✅ Public URL: ${publicUrl}`);

      // Clean up
      await supabaseAdmin.storage.from(STORAGE_BUCKET).remove([uploadPath]);
      console.log(`   🧹 Cleaned up test file\n`);
    }
  } catch (error) {
    console.error(`   ❌ Exception in full upload flow:`, error);
    console.error(`   Error:`, error instanceof Error ? error.message : error);
  }

  console.log('\n✅ Diagnostic complete!');
}

checkStorageBucket()
  .catch((e) => {
    console.error('❌ Diagnostic failed:', e);
    process.exit(1);
  })
  .finally(() => {
    process.exit(0);
  });
