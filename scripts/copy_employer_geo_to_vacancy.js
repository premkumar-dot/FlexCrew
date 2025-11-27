/**
 * Copy employer GeoPoint (users/{uid}.location) -> vacancies/{vacId}.location
 *
 * Usage (from mobile folder):
 *   PowerShell:
 *     $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\serviceAccountKey.json"
 *     npm install firebase-admin
 *     node scripts/copy_employer_geo_to_vacancy.js 500 200 --dry-run
 *
 *   Linux / macOS:
 *     export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
 *     npm install firebase-admin
 *     node scripts/copy_employer_geo_to_vacancy.js 500 200 --dry-run
 *
 * Notes:
 * - Looks for vacancy docs with `employerId` and missing `location`.
 * - Copies `users/{employerId}.location` if it is a GeoPoint-like object.
 * - Use --dry-run first to verify; then run without it to commit writes.
 */

const admin = require('firebase-admin');

admin.initializeApp(); // uses GOOGLE_APPLICATION_CREDENTIALS env var
const db = admin.firestore();

const argv = process.argv.slice(2);
const BATCH_SIZE = Number(argv[0]) || 500;
const MAX_DOCS = Number(argv[1]) || 10000;
const DRY_RUN = argv.includes('--dry-run');

function isGeoPointLike(v) {
  if (!v) return false;
  return (typeof v.latitude === 'number' && typeof v.longitude === 'number') ||
    (typeof v._latitude === 'number' && typeof v._longitude === 'number');
}

(async function main() {
  console.log('Starting: copy employer geo -> vacancy.location');
  console.log({ BATCH_SIZE, MAX_DOCS, DRY_RUN });
  let lastDoc = null;
  let processed = 0;
  let updated = 0;
  let skippedNoEmployer = 0;
  let skippedHasLocation = 0;
  let errors = 0;

  try {
    while (true) {
      let q = db.collection('vacancies').orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_SIZE);
      if (lastDoc) q = q.startAfter(lastDoc);

      const snap = await q.get();
      if (snap.empty) break;

      const vacancies = [];
      const employerIds = new Set();

      for (const doc of snap.docs) {
        processed++;
        const data = doc.data() || {};
        if (data.location !== undefined) {
          skippedHasLocation++;
          continue;
        }
        const employerId = data.employerId;
        if (!employerId) {
          skippedNoEmployer++;
          continue;
        }
        vacancies.push({ id: doc.id, ref: doc.ref, employerId });
        employerIds.add(employerId);
        if (processed >= MAX_DOCS) break;
      }

      if (vacancies.length === 0) {
        lastDoc = snap.docs[snap.docs.length - 1];
        if (processed >= MAX_DOCS) break;
        continue;
      }

      const employerMap = Object.create(null);
      const ids = Array.from(employerIds);
      const CHUNK = 10;
      for (let i = 0; i < ids.length; i += CHUNK) {
        const chunk = ids.slice(i, i + CHUNK);
        try {
          const uSnap = await db.collection('users').where(admin.firestore.FieldPath.documentId(), 'in', chunk).get();
          for (const udoc of uSnap.docs) {
            employerMap[udoc.id] = udoc.data() || {};
          }
        } catch (e) {
          console.error('Failed to load employer chunk', chunk, e);
          errors++;
        }
      }

      let batch = db.batch();
      let batchOps = 0;

      for (const v of vacancies) {
        const emp = employerMap[v.employerId];
        const empLoc = emp ? emp.location : undefined;

        if (!isGeoPointLike(empLoc)) continue;

        const update = {
          location: empLoc,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (DRY_RUN) {
          console.log('[dry-run] would update', v.id, 'with', update);
          updated++;
          continue;
        }

        batch.update(v.ref, update);
        batchOps++;
        updated++;

        if (batchOps >= 500) {
          try {
            await batch.commit();
            batch = db.batch();
            batchOps = 0;
          } catch (e) {
            console.error('Batch commit failed', e);
            errors++;
            batch = db.batch();
            batchOps = 0;
          }
        }
      }

      if (!DRY_RUN && batchOps > 0) {
        try {
          await batch.commit();
        } catch (e) {
          console.error('Final batch commit failed', e);
          errors++;
        }
      }

      lastDoc = snap.docs[snap.docs.length - 1];
      if (processed >= MAX_DOCS) break;
    }

    console.log('Done', { processed, updated, skippedHasLocation, skippedNoEmployer, errors });
    process.exit(0);
  } catch (err) {
    console.error('Fatal error', err);
    process.exit(1);
  }
})();
