# Käpp (Flutter)

Flutter port of the Käpp dog park app (TalTech ICD0018). The React Native original and the API live in
[ICD0018-kapp](https://github.com/metuzaladev/ICD0018-kapp); this app talks to the same API.

## Run

1. Start the API from ICD0018-kapp: `npm run db:up && npm run db:migrate && npm run db:seed && npm run dev:api`.
2. `flutter pub get`
3. `flutter run` (iOS simulator uses `http://localhost:3000`; on a phone: `--dart-define=API_URL=http://<computer-ip>:3000`).
   Social sign-in: `--dart-define=AUTH_APPLE=true` / `AUTH_GOOGLE=true` when the API has credentials.

## Structure

- `lib/core` — API client, Better Auth client (session cookie in the Keychain), a small TanStack-Query-style
  cache (`core/query`), i18n (same JSON tables as the RN app), theme tokens, formatting, pure logic.
- `lib/hooks` — data hooks (flutter_hooks), one per RN hook file.
- `lib/components`, `lib/screens` — Figma components and all screens of the RN app.
- `assets/i18n`, `assets/data` — translations and legal texts exported from `packages/shared`.

## Known gaps

- Push notifications are not wired up (the API expects Expo push tokens).
- Maps use OpenFreeMap vector tiles via flutter_map; zoom levels are MapLibre + 1.
- `integration_test/app_flow_test.dart` is work in progress (fails after the sign-up step).
