/**
 * Populate vacancy.locationText from employer document fields.
 *
 * Usage (from mobile folder):
 *   PowerShell:
 *     $env:GOOGLE_APPLICATION_CREDENTIALS="$PWD\serviceAccountKey.json"
 *     node scripts/set_vacancy_location_text.js "<default text>" [batchSize] [maxDocs] [--dry-run]
 *
 * Example dry run:
 *   node scripts/set_vacancy_location_text.js "Tampa, FL" 500 200 --dry-run
 */

const admin = require('firebase-admin');

admin.initializeApp(); // uses GOOGLE_APPLICATION_CREDENTIALS env var
const db = admin.firestore();

const argv = process.argv.slice(2);
const DEFAULT_TEXT = argv[0] || 'Not specified';
const BATCH_SIZE = Number(argv[1]) || 500;
const MAX_DOCS = Number(argv[2]) || 10000;
const DRY_RUN = argv.includes('--dry-run');

function pickLocationFromUser(u = {}) {
  // check common candidate paths in order
  const candidates = [
    u.locationText,
    u.address,
    u.profile && u.profile.locationText,
    u.profile && u.profile.address,
    u.city,
    u.region,
    u.town,
  ];
  for (const c of candidates) {
    if (typeof c === 'string' && c.trim().length > 0) return c.trim();
  }
  return null;
}

(async function main() {
  console.log('Populate vacancy.locationText (dry-run =', DRY_RUN, ')');
  console.log({ DEFAULT_TEXT, BATCH_SIZE, MAX_DOCS });

  let lastDoc = null;
  let processed = 0;
  let updated = 0;
  let skipped = 0;
  let errors = 0;

  try {
    while (true) {
      let q = db.collection('vacancies').orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_SIZE);
      if (lastDoc) q = q.startAfter(lastDoc);

      const snap = await q.get();
      if (snap.empty) break;

      let batch = db.batch();
      let ops = 0;

      for (const doc of snap.docs) {
        processed++;
        const v = doc.data() || {};
        if (v.locationText !== undefined && v.locationText !== null) {
          skipped++;
        } else {
          let locText = null;

          if (v.employerId) {
            try {
              const uDoc = await db.collection('users').doc(v.employerId).get();
              if (uDoc.exists) {
                locText = pickLocationFromUser(uDoc.data() || {});
              }
            } catch (e) {
              console.error('Failed to load employer', v.employerId, e);
              errors++;
            }
          }

          if (!locText) locText = DEFAULT_TEXT;

          if (DRY_RUN) {
            console.log('[dry-run] would set', doc.id, '->', locText);
            updated++;
          } else {
            batch.update(doc.ref, { locationText: locText, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
            ops++;
            updated++;
          }
        }

        if (ops >= 500) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }

        if (processed >= MAX_DOCS) break;
      }

      if (!DRY_RUN && ops > 0) await batch.commit();

      lastDoc = snap.docs[snap.docs.length - 1];
      if (processed >= MAX_DOCS) break;
    }

    console.log('Done', { processed, updated, skipped, errors });
    process.exit(0);
  } catch (err) {
    console.error('Fatal error', err);
    process.exit(1);
  }
})();
