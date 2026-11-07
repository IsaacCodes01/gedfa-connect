# GEDFA Connect: notes for Claude Code

Flutter + Firebase app for the **Gomoa East District Football Association (GEDFA)** league in Ghana.
Built by Isaac (IT diploma student), step by step. Read `docs/ROADMAP.md` (what is done and what is next)
and `docs/DATA_MODEL.md` (every collection, field and rule) before changing anything.

## How Isaac works (follow this every time)

1. **One small step at a time** (like `2.10a`, `2.10b`). Never start the next step before Isaac says so.
2. **Mockup before code** for anything with new screens or layout. Describe or draw it first; when Isaac
   approves a mockup, the code must match it exactly. Mockups can be simple HTML files in `docs/mockups/`.
3. **Ask before guessing** when a football / GEDFA rule is unclear (fees, ages, squad sizes, who approves).
   Isaac asks GEDFA. Record answers in `docs/DATA_MODEL.md` and the roadmap log.
4. **Explain the code.** Isaac wants to understand it. After each step give him:
   - "How it works" in plain words (analogies are welcome, e.g. his kitchen: domain = recipe card,
     data = storeroom, presentation = the dining room)
   - which files changed and why (a short table)
   - the key code snippets, and a reading order
   - test steps he can do himself in the app
5. **Before every commit**, run (and show the result):
   - `flutter analyze` → must be **0 issues**
   - `cd test/rules && npm test` → **all** rules tests pass (241 after 2.10a)
6. **Commit after each step** with a clear message, e.g.
   `feat(teams): change requests for name, short name, logo and competitions; 250 rules tests; docs v2.12`
7. **Deploy rules only after the tests pass**, and only to the dev project:
   `firebase deploy --only firestore:rules` (and `storage` when `storage.rules` changed).
   Ask Isaac first. Never deploy to production without him saying so.
8. Update `docs/ROADMAP.md` (tick the step, add a log line) and `docs/DATA_MODEL.md`
   (bump the version, add a change-log line) in the same commit.

## Security (never break these)

- **Never commit secrets**: `.env`, service-account JSON (anything with `"private_key"`), passwords.
  `google-services.json` / `firebase_options.dart` are client config and are OK in this public repo.
- **Every write must be allowed by `firestore.rules`** and covered by a test in
  `test/rules/firestore.test.js` (one test that succeeds and at least one that must fail).
  The app checking something is friendly; the rules are the real lock.
- Rules functions must be **defined before they are used** (above the `match` that uses them).
- Team admins only touch their own team (`isTeamAdminOf`). FA-only actions use `isFaAdmin()`.
  Chairman-only settings use the chairman check.
- Counters (`settings/playerCounter`, `settings/juvenileCounter`, `settings/receiptCounter`) move by
  exactly +1, inside the same transaction or batch as the write that uses them.

## Stack and structure

- Flutter 3.44 / Dart 3.12, Android + web from one codebase. Riverpod 3 (`StreamProvider`, `.family`,
  `Provider<AsyncValue>`), go_router (`StatefulShellRoute`; full-screen pages use
  `parentNavigatorKey: rootNavigatorKey`; query params via `state.uri.queryParameters`).
- Feature folders: `lib/features/<feature>/{domain, data, presentation, presentation/widgets}`.
  Paths in `lib/core/constants/firestore_paths.dart` and `storage_paths.dart`. Routes in `lib/app/routes.dart`.
- Firestore writes that belong together go in **one batch or transaction** (e.g. a write + its
  notification). Notifications are grouped: one doc per audience, kind, team and day
  (`NotificationWriter.forFaInBatch` / `forTeamInBatch`).
- On **web**, an exception thrown inside a Firestore transaction loses its type ("Something went
  wrong"). Check things the user must be told about BEFORE the transaction too.
- `Season` holds the live season from `settings/league` (League settings, 2.13d).

## Dart / lint gotchas we hit before

- Use null-aware elements: `?value` in lists, `'key': ?value` in maps.
- `when` cannot be a pattern variable name. Put `<…>` in doc comments inside backticks.
- A local `bool` does not promote a nullable variable; check `x != null` directly or use a
  `final y = cond ? x : null;` local.
- In a `bottomNavigationBar`, wrap a centred button in `Center(heightFactor: 1, …)`;
  a plain `Center` / `ResponsiveCenter` fills the whole screen there.
- `file_picker ^13.3.0` (12.x clashes with `connectivity_plus`).

## Running it

- Emulators: `firebase emulators:start --import=./emulator-data --export-on-exit`
  (Auth 9099, Firestore 8080, Storage 9199, UI 4000). `USE_EMULATORS` is on in debug.
- App: `flutter run -d chrome` (quit with `q`). After the laptop sleeps, if saves say
  "taking too long", restart the emulators and the app first.
- Port 8080 busy: `netstat -ano | findstr :8080` then `taskkill /PID <pid> /F`.

## Where we left off (7 Nov 2026)

- 2.10a (`9aa5b31`) is pushed and its rules are deployed to dev (Isaac, 7 Nov 2026).
- **2.10b change requests** (tested by Isaac) and **2.10c** (changes grouped by team, Reject with a
  reason, Approve all, "Previously …" on renamed teams) are committed (7 Nov 2026, 257 rules tests).
  Isaac deploys the 2.10b rules (`firestore:rules` and `storage`) to dev himself.
- Mockups go in `docs/mockups/` (ignored by git): never commit them.
- Known and accepted in 2.10b: the old `teamRequests` doc keeps the old name (registration
  history), and old payments / notifications keep the name they had.
- **Next:** **2.11** FA corrections (edit, ask for a correction, suspend), **2.12** FA dashboard,
  **Phase 3** team sheets (16 / 5 / 7 from settings, GFA play-up limits, kit in the top-left corner),
  then the "before the pilot" list in the roadmap (push notifications, 3-day fee reminders, prod setup).
- **Later (after Phase 3):** our own app icon (`flutter_launcher_icons`) and splash screens before
  "Get started" (`flutter_native_splash` + an in-app intro). A UI and animation refresh is done as its
  own steps, one screen group at a time, with mockups first, never mixed with feature work.
- turn off the Co-Authored-By line in your commit settings for this project.
