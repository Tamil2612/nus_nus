'use strict';

// One-time Admin SDK migration for profiles created before phoneKey indexing.
// Run `node backfill_phone_keys.js --dry-run` first, then add `--apply` to write.
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { normalizeLookupPhone } = require('./phone_lookup');

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.SERVICE_ACCOUNT_PATH;
if (keyPath && fs.existsSync(keyPath)) {
  const serviceAccount = JSON.parse(fs.readFileSync(path.resolve(keyPath), 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id || process.env.GCLOUD_PROJECT || 'nus-nus',
  });
} else {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || 'nus-nus',
  });
}

async function main() {
  const apply = process.argv.includes('--apply');
  const db = admin.firestore();
  const users = db.collection('users');
  const pageSize = 400;
  let cursor = null;
  let scanned = 0;
  let changed = 0;

  while (true) {
    let query = users.orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;

    let batch = db.batch();
    let writes = 0;
    for (const doc of page.docs) {
      scanned++;
      const rawPhone = doc.get('phoneNumber');
      const normalized = typeof rawPhone === 'string'
        ? normalizeLookupPhone(rawPhone)
        : '';
      const phoneKey = normalized.length >= 7 && normalized.length <= 15
        ? normalized
        : null;
      if ((doc.get('phoneKey') ?? null) === phoneKey) continue;

      changed++;
      if (!apply) continue;
      batch.update(doc.ref, {
        phoneKey: phoneKey ?? admin.firestore.FieldValue.delete(),
      });
      writes++;
    }

    if (apply && writes > 0) await batch.commit();
    cursor = page.docs[page.docs.length - 1];
    console.log(`${apply ? 'Processed' : 'Would process'} ${scanned} profiles; ${changed} keys ${apply ? 'updated' : 'need updating'}.`);
  }

  console.log(`${apply ? 'Backfill complete' : 'Dry run complete'}: ${scanned} profiles scanned, ${changed} keys ${apply ? 'updated' : 'would be updated'}.`);
}

main().catch((error) => {
  if (String(error.message || '').includes('Could not load the default credentials')) {
    console.error('\nAuthentication Required:');
    console.error('To run Admin SDK scripts on your local machine, provide Google credentials:\n');
    console.error('Option 1 (Quickest):');
    console.error('  gcloud auth application-default login\n');
    console.error('Option 2 (Service Account Key JSON):');
    console.error('  1. Go to Firebase Console -> Project Settings -> Service accounts');
    console.error('  2. Click "Generate new private key" to download a .json file');
    console.error('  3. Run: GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json" node backfill_phone_keys.js\n');
  } else {
    console.error('Phone key backfill failed:', error);
  }
  process.exitCode = 1;
});
