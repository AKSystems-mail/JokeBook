# JokeBook audit — 2026-11-23

Auditor: `google/gemini-4-hydrogen` via OpenRouter, read-only pass over the 23
Dart files in `lib/` (~4k lines). Cost $0.08 (38,776 tokens). Findings were
re-verified against the source before any fix was applied; one claim (batch
0.5k limit) is real but unreachable at this app's data volume and was not fixed.

## Deployed state before this pass

```text
firestore:
  match /{document=**} { allow read, write, delete, update: if request.auth != null; }
```

Any signed-in user could read, write and delete **every** document in the
project. Local `firestore.rules` / `storage.rules` now scope everything to
`users/{uid}/**` and were released on 2026-11-23. Anonymous probe against the
released ruleset: `users/{uid}`, `users/{uid}/bits`, `users` and a POST all
return 403 `PERMISSION_DENIED`.

## Fixed

Security / data integrity
1. Firestore rules scoped to `users/{userId}` and `users/{userId}/{document=**}` —
   was global-authenticated read/write/delete.
2. `storage.rules` committed (`users/{userId}/{allPaths=**}`), matching what was
   already deployed; `firebase.json` now points at both rule files.
3. `functions/src/index.ts` rewritten for the v2 API: `MIGRATION_SECRET` is
   fail-closed (unset = endpoint disabled), the secret is checked before any
   Firestore work, and the scan is capped at `MAX_USERS = 500`.
4. Delete order reversed in `RecordingsProvider.deleteRecording` — Firestore row
   first, audio file second (an orphaned row pointing at a missing file was the
   failure mode). A failed row delete now rethrows and the screen shows it
   instead of a cheerful "deleted" snack.
5. `FirestoreService.deleteRecording` no longer swallows the failure.

Cross-account state
6. `main.dart` rebuilds the provider tree per signed-in user
   (`StreamBuilder<User?>` + `ValueKey(uid)`), so signing out disposes the old
   providers instead of leaking another account's bits/set lists/recordings.
   The dead `authStateChanges` listener in `main()` is gone.
7. `BitProvider` / `SetListProvider` keep their `StreamSubscription` and cancel
   it in `dispose()`; `SetListProvider._fetchSetLists` cancels before
   re-listening (its reorder-error retry used to stack a second listener).

Correctness
8. `create_bit_screen` error snack was gated on `_title.isEmpty && _body.isEmpty`
   — a condition the function returns early on, so failures were silent.
9. Bits / set lists / recordings swipe-to-delete now await the delete and report
   failures instead of firing and forgetting.
10. `WillPopScope` in create/edit bit awaits the save before popping.
11. `Recording.fromFirestore` tolerates a missing or non-Timestamp `createdAt`.
12. `SetListAdapter` (hand-edited, `hive_generator` not re-run) now persists
    `order` (field 6) — it was declared on the model but never written, so every
    persisted set list came back unordered. Guarded by
    `test/set_list_adapter_test.dart`.

Dependencies
13. Root `firebase` 11.2.0 → 13.4.0, `overrides["@grpc/grpc-js"] = "^1.13.6"`;
    `npm audit` at the root is now clean (0 vulnerabilities).
14. `functions`: `npm audit fix`, Node runtime `20` → `22` (Node 20 was
    decommissioned 2026-10-30, which blocks every function deploy). Two moderate
    advisories remain in the functions tree — they need a breaking major bump.
15. `functions/.eslintrc.js`: `max-len` 100, `object-curly-spacing: always`;
    lint and `tsc --noEmit` clean.

## Not fixed

- **Function deploy is blocked**: `joke-book-d1510` is on the Spark plan, so
  `firebase deploy --only functions` fails with "Extensions require the Blaze
  plan". Rules and Storage deployed fine. The hardened `index.ts` is committed
  but not live.
- **Deployed functions have diverged from the repo**: the project runs both
  `migrateUserSetListOrders` and `migrateUserBitOrders` (nodejs20), but only the
  setList one ever existed in git. Deploying this repo verbatim after a Blaze
  upgrade will delete `migrateUserBitOrders`; recreate it deliberately or accept
  the deletion.
- **Batch ceiling (≤500 writes)**: `addBit` / `addSetList` rewrite the `order`
  field of every existing item in one batch. Real, but the batch only breaks past
  ~499 items. Fix properly with a sparse/fractional order or paging when a user
  gets that far; a guard today would just be a different wrong behaviour.
- **Cross-user rule change is only probed anonymously.** Verifying that user A
  cannot read user B needs a real ID token — worth doing on the next device
  smoke test (sign in, confirm bits/set lists/recordings still load).

## Verification

```text
flutter analyze     0 errors, 0 warnings (44 pre-existing infos)
flutter test        1/1  set_list_adapter_test.dart
functions           npm run lint clean, tsc --noEmit clean
root npm audit      0 vulnerabilities
firebase deploy     firestore:rules + storage released 2026-11-23
anonymous probe     403 on users/{uid}, users/{uid}/bits, users, POST
```
