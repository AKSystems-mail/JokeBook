import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

const MIGRATION_SECRET_KEY = "104tenfour";

// In functions/src/index.ts (add this as a new exported function)

export const migrateUserSetListOrders = functions
    .https.onRequest(async (request, response) => {
      // --- Basic Security Check (use the same MIGRATION_SECRET_KEY or a new one) ---
      if (request.query.secret !== MIGRATION_SECRET_KEY) { // Ensure MIGRATION_SECRET_KEY is defined
        functions.logger.error("Unauthorized attempt to run setlist order migration. Invalid secret.");
        response.status(403).send("Unauthorized: Invalid secret key.");
        return;
      }

      functions.logger.info("Starting migration for all user setlist orders (triggered via HTTPS)...");

      try {
        const usersSnapshot = await db.collection("users").get();
        if (usersSnapshot.empty) {
          functions.logger.info("No users found to migrate setlists for.");
          response.status(200).send("Migration check complete: No users found.");
          return;
        }

        let totalSetListsMigrated = 0;
        const migrationPromises = usersSnapshot.docs.map(async (userDoc) => {
          const userId = userDoc.id;
          functions.logger.info(`Processing setlists for user: ${userId}`);

          const setListsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("setLists") // Target 'setLists' collection
            .orderBy("createdAt", "asc")
            .get();

          if (setListsSnapshot.empty) {
            functions.logger.info(`No setlists for user: ${userId}`);
            return;
          }

          const batch = db.batch();
          let userSetListsUpdated = 0;

          setListsSnapshot.docs.forEach((slDoc, index) => {
            const slData = slDoc.data();
            if (slData.order === undefined || typeof slData.order !== "number" || slData.order !== index) {
              functions.logger.info(`  User ${userId}, SetList ${slDoc.id} (Title: ${slData.title || "N/A"}): setting order to ${index}`);
              batch.update(slDoc.ref, {
                order: index,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              userSetListsUpdated++;
            }
          });

          if (userSetListsUpdated > 0) {
            await batch.commit();
            functions.logger.info(`  Committed ${userSetListsUpdated} setlist order updates for user ${userId}.`);
            totalSetListsMigrated += userSetListsUpdated;
          } else {
            functions.logger.info(`  No setlist order updates needed for user ${userId}.`);
          }
        });

        await Promise.all(migrationPromises);

        const successMessage = `Setlist order migration completed. Total setlists updated: ${totalSetListsMigrated}.`;
        functions.logger.info(successMessage);
        response.status(200).send(successMessage);

      } catch (error) {
        functions.logger.error("Error during setlist order migration:", error);
        response.status(500).send("Setlist order migration failed. Check logs.");
      }
    });