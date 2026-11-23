import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

// Fail closed: unset MIGRATION_SECRET (functions/.env, gitignored) disables the endpoint.
const MIGRATION_SECRET_KEY = process.env.MIGRATION_SECRET || "";
const MAX_USERS = 500;

export const migrateUserSetListOrders = onRequest(async (request, response) => {
  if (!MIGRATION_SECRET_KEY || request.query.secret !== MIGRATION_SECRET_KEY) {
    logger.error("Unauthorized attempt to run setlist order migration. Invalid secret.");
    response.status(403).send("Unauthorized: Invalid secret key.");
    return;
  }

  logger.info("Starting migration for all user setlist orders (triggered via HTTPS)");

  try {
    const usersSnapshot = await db.collection("users").limit(MAX_USERS).get();
    if (usersSnapshot.empty) {
      logger.info("No users found to migrate setlists for.");
      response.status(200).send("Migration check complete: No users found.");
      return;
    }

    let totalSetListsMigrated = 0;
    // ponytail: serial loop capped at MAX_USERS; parallelise if this ever exceeds a minute
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const setListsSnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("setLists")
        .orderBy("createdAt", "asc")
        .get();

      if (setListsSnapshot.empty) continue;

      const batch = db.batch();
      let userSetListsUpdated = 0;

      setListsSnapshot.docs.forEach((slDoc, index) => {
        const slData = slDoc.data();
        if (typeof slData.order !== "number" || slData.order !== index) {
          batch.update(slDoc.ref, {
            order: index,
            updatedAt: FieldValue.serverTimestamp(),
          });
          userSetListsUpdated++;
        }
      });

      if (userSetListsUpdated > 0) {
        await batch.commit();
        logger.info(`Committed ${userSetListsUpdated} setlist order updates for user ${userId}.`);
        totalSetListsMigrated += userSetListsUpdated;
      }
    }

    const successMessage =
      `Setlist order migration completed. Total setlists updated: ${totalSetListsMigrated}.`;
    logger.info(successMessage);
    response.status(200).send(successMessage);
  } catch (error) {
    logger.error("Error during setlist order migration:", error);
    response.status(500).send("Setlist order migration failed. Check logs.");
  }
});
