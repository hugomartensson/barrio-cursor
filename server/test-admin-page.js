/**
 * Test script for the admin page
 * Run with: node test-admin-page.js
 */

import puppeteer from 'puppeteer';

const TEST_URL = 'http://localhost:3000/admin';
const TEST_EMAIL = 'hugo1martensson@gmail.com';
const TEST_PASSWORD = '950829Hugo';
const TEST_EVENTBRITE_URL = 'https://www.eventbrite.es/e/comunicar-arquitectura-comunicar-ciudad-sesion-1-de-4-identidad-y-relato-tickets-1978889741487';

async function testAdminPage() {
  console.log('🚀 Starting admin page test...\n');
  
  const browser = await puppeteer.launch({
    headless: false, // Show browser for debugging
    defaultViewport: { width: 1280, height: 800 },
  });

  const page = await browser.newPage();

  // Enable console logging
  page.on('console', (msg) => {
    const type = msg.type();
    const text = msg.text();
    if (type === 'error') {
      console.log(`❌ Browser Console Error: ${text}`);
    } else if (type === 'warning') {
      console.log(`⚠️  Browser Console Warning: ${text}`);
    } else {
      console.log(`📝 Browser Console: ${text}`);
    }
  });

  // Capture page errors
  page.on('pageerror', (error) => {
    console.log(`❌ Page Error: ${error.message}`);
  });

  // Capture failed requests
  page.on('requestfailed', (request) => {
    console.log(`❌ Request Failed: ${request.url()}`);
    console.log(`   Failure: ${request.failure().errorText}`);
  });

  try {
    // Step 1: Navigate to admin page
    console.log('📍 Step 1: Navigating to admin page...');
    await page.goto(TEST_URL, { waitUntil: 'networkidle0' });
    await page.screenshot({ path: 'test-screenshots/01-initial-load.png' });
    console.log('✅ Screenshot saved: 01-initial-load.png\n');

    // Step 2: Login
    console.log('📍 Step 2: Logging in...');
    await page.type('#login-email', TEST_EMAIL);
    await page.type('#login-password', TEST_PASSWORD);
    await page.click('#login-btn');
    
    // Wait for login to complete
    await page.waitForSelector('#main-section:not(.hidden)', { timeout: 10000 });
    await page.screenshot({ path: 'test-screenshots/02-after-login.png' });
    console.log('✅ Login successful! Screenshot saved: 02-after-login.png\n');

    // Step 3: Extract event from URL
    console.log('📍 Step 3: Extracting event from Eventbrite URL...');
    await page.type('#extract-url', TEST_EVENTBRITE_URL);
    await page.click('#extract-btn');
    
    console.log('⏳ Waiting 10 seconds for extraction...');
    await page.waitForTimeout(10000);
    
    await page.screenshot({ path: 'test-screenshots/03-after-extract.png' });
    console.log('✅ Screenshot saved: 03-after-extract.png\n');

    // Step 4: Check for status messages
    console.log('📍 Step 4: Checking page status...');
    
    const statusMsg = await page.$eval('#status-msg', el => ({
      text: el.textContent,
      classes: el.className,
      hidden: el.classList.contains('hidden')
    })).catch(() => null);

    if (statusMsg && !statusMsg.hidden) {
      console.log(`📊 Status Message: ${statusMsg.text}`);
      console.log(`   Classes: ${statusMsg.classes}`);
    } else {
      console.log('ℹ️  No status message visible');
    }

    // Check if form is visible
    const formVisible = await page.$eval('#event-form', el => !el.classList.contains('hidden')).catch(() => false);
    console.log(`📊 Event form visible: ${formVisible}`);

    // Check if extract button is still disabled
    const extractBtnDisabled = await page.$eval('#extract-btn', el => el.disabled).catch(() => false);
    console.log(`📊 Extract button disabled: ${extractBtnDisabled}`);

    // Get form field values if form is visible
    if (formVisible) {
      const formData = await page.evaluate(() => {
        return {
          title: document.getElementById('field-title')?.value || '',
          description: document.getElementById('field-description')?.value || '',
          address: document.getElementById('field-address')?.value || '',
          venueName: document.getElementById('field-venueName')?.value || '',
          startTime: document.getElementById('field-startTime')?.value || '',
        };
      });
      
      console.log('\n📋 Extracted Form Data:');
      console.log(`   Title: ${formData.title || '(empty)'}`);
      console.log(`   Description: ${formData.description ? formData.description.substring(0, 100) + '...' : '(empty)'}`);
      console.log(`   Venue: ${formData.venueName || '(empty)'}`);
      console.log(`   Address: ${formData.address || '(empty)'}`);
      console.log(`   Start Time: ${formData.startTime || '(empty)'}`);
    }

    // Step 5: Check browser console for errors
    console.log('\n📍 Step 5: Checking for JavaScript errors...');
    const errors = await page.evaluate(() => {
      return window.__errors || [];
    });

    if (errors.length > 0) {
      console.log(`❌ Found ${errors.length} JavaScript errors`);
      errors.forEach((err, i) => console.log(`   ${i + 1}. ${err}`));
    } else {
      console.log('✅ No JavaScript errors detected');
    }

    console.log('\n✨ Test completed successfully!');
    console.log('📁 Screenshots saved in test-screenshots/ directory');

  } catch (error) {
    console.error('\n❌ Test failed with error:');
    console.error(error);
    await page.screenshot({ path: 'test-screenshots/error.png' });
    console.log('📸 Error screenshot saved: error.png');
  } finally {
    // Keep browser open for manual inspection
    console.log('\n⏸️  Browser will remain open for 30 seconds for inspection...');
    await page.waitForTimeout(30000);
    await browser.close();
    console.log('👋 Browser closed');
  }
}

// Create screenshots directory
import { mkdirSync } from 'fs';
try {
  mkdirSync('test-screenshots', { recursive: true });
} catch (err) {
  // Directory already exists
}

// Run the test
testAdminPage().catch(console.error);
