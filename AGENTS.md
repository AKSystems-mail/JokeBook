# AGENTS.md — JokeBook

**What JokeBook is:** a personal notebook app for comedians — write, organize, and record comedy material (jokes, set lists, recordings). Flutter + Firebase.

## Dev commands

```bash
flutter build apk --release    # release APK
flutter run                    # debug
```

## Compliance

**This app ships to Google Play.** Before building releases or changing permissions/features, read `~/dev/GOOGLE_POLICIES.md` (shared, dated compliance reference). Current actions: verify Play Console registration for all apps by 2026-09-30; no anonymous-chat, contacts, precise-location, call-log, or geofencing usage expected — re-check if new features land.

## Gotchas

- `google_sign_in` is used for auth — keep it working (Google OAuth client inactivity deletes it after 5 months; a sign-in resets the clock).
- App icon source: `assets/icon/icon-512.png` via flutter_launcher_icons (keep blue #0175C2).
