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
   - `cd test/rules && npm test` → **all** rules tests pass (355 after JSc2)
   - `flutter test` → all Dart tests pass (layout smoke tests and the kit check)
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
- The theme's Filled / Outlined buttons are **full-width** (`minimumSize: Size.fromHeight`). A button in a `Row` (not in
  `Expanded`) needs `style: …styleFrom(minimumSize: const Size(0, 40))`, or the row breaks on the web. Screen tests use
  `AppTheme.light()` / `dark()` so this is caught.

## Running it

- Emulators: `firebase emulators:start --import=./emulator-data --export-on-exit`
  (Auth 9099, Firestore 8080, Storage 9199, UI 4000). `USE_EMULATORS` is on in debug.
- App: `flutter run -d chrome` (quit with `q`). After the laptop sleeps, if saves say
  "taking too long", restart the emulators and the app first.
- Port 8080 busy: `netstat -ano | findstr :8080` then `taskkill /PID <pid> /F`.
- After a step, make sure no flutter test / analyze run is left running. If one was stopped
  partway, end its dart processes before finishing.

## Where we left off (7 Nov 2026)

- 2.10a (`9aa5b31`) is pushed and its rules are deployed to dev (Isaac, 7 Nov 2026).
- **2.10b change requests** (tested by Isaac) and **2.10c** (changes grouped by team, Reject with a
  reason, Approve all, "Previously …" on renamed teams) are committed (7 Nov 2026, 257 rules tests).
  Isaac deploys the 2.10b rules (`firestore:rules` and `storage`) to dev himself.
- Mockups go in `docs/mockups/` (ignored by git): never commit them.
- Known and accepted in 2.10b: the old `teamRequests` doc keeps the old name (registration
  history), and old payments / notifications keep the name they had.
- **2.11 FA corrections** done (7 Nov 2026, 285 rules tests): 2.11a the FA fixes misspellings itself
  (name, town, ground, directions, year, email; never officials, kits or colours), 2.11b asks the team to
  correct, 2.11c the chairman suspends and lifts. Isaac deploys the rules to dev himself.
- **2.12 FA dashboard** done (7 Nov 2026). FA tabs are Home · Teams · Players · More; the FA lands on
  `/admin/home`; `/admin` is still Teams. Screens opened from Home carry `from=home` (back arrow to Home);
  links on FA screens use `context.goKeepingHome` / `pushKeepingHome` (`core/widgets/back_to_home.dart`)
  so the note travels. Dashboard numbers are live from the existing streams (no count queries yet).
- Layout test: `flutter test` runs `test/dashboard_smoke_test.dart` (phone and laptop, light and dark).
- **3.0a fixtures** done (8 Nov 2026): `fixtures/{id}` carries a copy of both teams and their kits; every
  save re-reads the teams (`FixtureRepository.loadTeam`). Kit clash table in `kit_clash.dart` (draft).
  Tabs: FA Home · Teams · Players · Fixtures · More; team Squad · Fixtures · Profiles · More.
- **3.0b Make the season** done (8 Nov 2026): `round_robin.dart`, `season_plan.dart`, drafts in
  `fixtureDrafts` (FA only); publish 3 matches per batch (rules lookup limit), fixed IDs so a retry resumes.
- **Match details** (F5, F6) done (8 Nov 2026): `match_details_screen.dart`; tapping any match opens it
  (`Routes.adminMatch` / `Routes.teamMatch`); the FA manages a match from its ⋯ (`showFixtureActions`).
- **3.0c1** done (8 Nov 2026): `cups/{id}` (class `Cup`, because `Competition` is already the Division /
  Juvenile enum), `cup_format.dart` (knockout with byes, groups, gala timetable), Competitions (C1, from the
  🏆 on the Fixtures tab), New cup / New gala (C2, C2b). Mockup `3.0c-competitions.html`. Still asked of GEDFA:
  pots before results, which juvenile sides in an open cup, final one match, gala match length. Next: **3.0c2**
  the live draw (C3, C3b). Rules changed (`cups`): Isaac deploys to dev.
- **3.0c1b** done (8 Nov 2026, 310 rules tests): a cup's page `cup_screen.dart` (C7) with ⋯ Change / History /
  Delete; `cups/{id}/history` lines from `cupChanges` (`cup_changes.dart`); the C2 form doubles as Change
  (`CupFormScreen(cupId:)`). Agreed order next: **3.0c1c** postpone (C10, C11), **the back arrow** on every tab
  opened from another tab, **juvenile side names** ("B"), then **3.0c2**. Rules changed: Isaac deploys to dev.
- **3.0c1c** done (9 Nov 2026, 314 rules tests, no rules change): postpone a league (⋯ on its row in Competitions,
  `postpone_plan.dart`, `FixtureRepository.postponeMatches`, 3 per batch, Try again resumes) or a Gala
  (`CupRepository.postponeGala`); dialog `widgets/postpone_dialog.dart`. A cup's Postpone waits for the draw.
- **3.0c1d** done (9 Nov 2026, 318 rules tests): a league's postpone is saved first in `postponeJobs/{competitionId}`
  (FA only, one per league, `done` ticked in the same batch as each match, deleted with the last notes);
  `startPostpone` + `finishPostpone`; Competitions shows a stopped one with Finish (C13). Rules changed: Isaac deploys
  to dev. Next: **the back arrow**, then juvenile side names, then 3.0c2.
- **3.0f1** done (9 Nov 2026, 321 rules tests, 152 Dart tests): a tap opens Notification details
  (`notification_details_screen.dart`, `Routes.adminNote` / `Routes.teamNote`) and marks only that note read
  (`readMarks/{uid}.reads`, `ReadMark.isUnread`); icons, targets and button names in `widgets/note_look.dart`.
  Rules changed: Isaac deploys to dev.
- **3.0f2** done and **3.0f tested by Isaac** (9 Nov 2026, 157 Dart tests, no rules change): open pages with **`context.open(route)`** and leave
  with **`context.goBack(fallback)`** / **`AppBackButton(fallback:)`** (`core/widgets/back_to_home.dart`), not `context.go`.
  `open` pushes full-screen pages and same-tab pages; otherwise it uses go with `back=` (`Routes.withBack`), and
  `GedfaAppBar` adds ← to it. Never `push` a tab's page from a full-screen page: go_router crashes (Duplicate GlobalKey).
  `GoRouter.optionURLReflectsImperativeAPIs = true` in `main.dart`. Test: `test/back_navigation_test.dart`.
  The bell's ← goes where it was opened (`bellOriginProvider` in `notification_bell.dart`). Never call
  `GoRouterState.of` on a page pushed with `Navigator.push` / `MaterialPageRoute`: it loops forever (app freezes).
  Next: juvenile side names, then the team admin dashboard.
- **Juvenile side names: mockup drawn** (9 Nov 2026), `docs/mockups/juvenile-side-names.html` (JS1–JS6). Isaac's answers
  (in `DATA_MODEL.md`): short name "RUF B"; own juvenile names reserved in `teamNames`; the name is asked in the same
  "Add Juvenile" request ("B" by default); after approval **every** juvenile match shows the new name, played ones too,
  with the gold "Previously …" pill (`previous_name_pill.dart`, like 2.10c). **Build it next, in a new conversation.**
- **JSa** done (9 Nov 2026, 324 rules tests, 165 Dart tests): a club in both competitions plays its juvenile matches as
  "Royal Unique FC B" / "RUF B" (`side_name.dart`, `Team.sideName(category)`, rules `sideNamesOf`); a "B" crest has a gold
  ring (`FixtureSide.isBSide`). Match saves are near the rules' **1000-expression limit**: compute things once per side
  (`let`), and test a juvenile match change. Rules changed: Isaac deploys to dev. Next: **JSb** registration, then **JSc** ask the FA.
- **JSb** done (9 Nov 2026, 334 rules tests, 171 Dart tests): `teamRequests.juvenileName / juvenileShortName / juvenileNameKey`
  (clubs in both; empty = "B"), reserved in `teamNames` (rules `isValidJuvenileName`, `isMyRequestName`); approval copies the
  name to the team (left out for "B": a null field would break `team.get('juvenileName', name + ' B')`). Picker
  `widgets/juvenile_name_picker.dart` (reuse it for JS3b), ring `widgets/b_side_ring.dart`. Run `dart format` on single
  files only (the folder reformats ~44 untouched files). Rules changed: Isaac deploys to dev. Next: **JSc** ask the FA.
- **JSc1** done (9 Nov 2026, 348 rules tests, 177 Dart tests): change kind `juvenileName` (`to` '' = back to "B",
  `toShortName`, `fromShortName`; "Why" optional) and "Add Juvenile" with `juvenileName` / `juvenileShortName` / `nameKey`;
  approval sets or deletes the team's name and reserves it (`_reserveJuvenileName`). Chip in `ask_change_screen.dart`
  (`JuvenileNamePicker(compact: true)`), row on Team profile, FA card `_JuvenileNameChange`. Next: **JSc2** rename matches.
- **JSc2** done, **juvenile side names finished** (9 Nov 2026, 355 rules tests, 189 Dart tests): `fixtures.previousNames`
  (team ID → `{ name, until }`); `FixtureRepository.renameTeam` (6 per save, `renameUpdate` on the raw doc) after the FA
  approves a name / short name / juvenile name (`renameTeamMatches` dialog in `widgets/rename_matches.dart`); pill and note
  `widgets/renamed_pill.dart` in `FixtureRow` and match details; FA team page `_StaleMatches` + Finish renaming. Rules
  `isRenamingMatch`; the normal match update checks `previousNames` FIRST (expression limit). Next: **Team admin dashboard**.
- **Next (new conversation, Isaac 9 Nov 2026): dashboards for teams AND referees** (the FA's is 2.12), so everyone on the
  app has a summary of what they need to know and the app feels attractive. Mockups first, one step at a time.
  A spelling correction (2.11a) stays as built: its matches wait for Finish renaming (with the pill).
- **Team dashboard mockup approved** (10 Nov 2026, `docs/mockups/td-team-dashboard.html`, TD1–TD4, TF1–TF2): build **TDa** (Home tab,
  header, Division | Juvenile switch, Next match, Coming up, Needs you), then **TDb** (tiles, fee, Waiting on the FA, From GEDFA, laptop),
  **TDc** (switch and month calendar on Fixtures, calendar on Home), then **JA** juvenile age groups (GEDFA: 1 to 3, only before the season
  is published; mockup first), then **JF** fees by competition. Referee Home (RD1) comes with 3.5. Match-ready = 18, can play from 7.
- **TDa** done (10 Nov 2026, 355 rules tests, 213 Dart tests, no rules change): teams land on `/team/home`
  (`Routes.teamHome`, tab 0; Squad is still `Routes.team`); `team_dashboard_screen.dart`, logic `dashboard/domain/team_home.dart`,
  cards `widgets/team_home_widgets.dart`, switch `matchViewProvider` (shared preferences; TDc reuses it on Fixtures).
  `DashboardHeader` takes `label`, `crest`, `subtitle`, `tags` (`HeaderTag`). `AccentTone.grey` added.
- **TDb** done (10 Nov 2026, 355 rules tests, 218 Dart tests): tiles, fee, Waiting on the FA, From GEDFA, Coming later, laptop
  (`widgets/team_home_cards.dart`; FA's `GlanceTile` takes `onTap` / `valueText`, `ComingLater` takes `items`). `dart format` on
  `theme.dart` reflows the whole file: don't.
- **TDc** done, **team dashboard finished** (10 Nov 2026, 355 rules tests, 229 Dart tests): Fixtures tab has the same switch
  (`matchViewProvider`) and List | Calendar; `MatchCalendarCard` on Fixtures and Home. Tests that build a team screen need
  `sharedPreferencesProvider` overridden. **Next (Isaac): 3.1 team sheet builder, mockup MS1 first**, then JA, JF, the rest in order.
- **3.1 answers** (Isaac, 10 Nov 2026, in `DATA_MODEL.md` Section 7): 18 = 11 + 7 on the bench, 5 may come on; any number of
  goalkeepers, the bench never more than 7; juvenile the same with play-up limits. One extra substitute for a **head injury only**
  (concussion), in every competition, not counted in the 5; the other team then gets one extra too. A goalkeeper in the 11 is required.
- **3.1 mockup approved** (10 Nov 2026, `docs/mockups/3.1-team-sheet.html`, MS1–MS7, MS4b–MS4c; answers in `DATA_MODEL.md`
  Section 7): one Save button, editable until the lock (3.2); bench only when 11 start; injured players with a warning; captain
  starts; any starter in goal (never changes the registered position); **shirt numbers for this match** on the sheet (`numbers`,
  1–99, no two the same), the registered `jerseyNo` stays as the usual number; cup sheets 1 h before (Gala 20 min).
  Build **3.1a** Players step + Save (`teamSheets`, `squads` list at approval), then 3.1b roles and numbers, 3.1c check and
  sheet lines, 3.1d juvenile play-up, 3.1e player suspensions.
- **3.1a1** done (10 Nov 2026, 369 rules tests, 234 Dart tests): `squads/{teamId}_{group}` (`division` / `U13` / `U15` / `U17`,
  `players` map ID → true, `changed` = the one player of each write); `approve` / `passJuvenile` add in the transaction, a team edit
  back to pending removes in the batch (`players/data/squad_list.dart`); FA Repair in League settings (`repairSquadLists`).
  Rules changed: Isaac deploys to dev, then presses Repair once. Repair shows only in debug builds (`kDebugMode`, Isaac).
- **3.1a2** done (10 Nov 2026, 387 rules tests, 252 Dart tests): `teamSheets/{fixtureId}_{teamId}` (`starters`, `bench`,
  `savedBy`, `savedAt`); rules `isValidTeamSheet` (lock `now + 1 h < kickoffAt`, squad lists via `pickableIds`);
  `features/team_sheets/` (`sheet_picks.dart` = taps and checks, `team_sheet_screen.dart` = MS2, `Routes.teamSheet`);
  Match details › Team sheets has Make team sheet / Change. Rules changed: Isaac deploys to dev. Next: **3.1b** roles and numbers.
- **3.1b** done (11 Nov 2026, 395 rules tests, 270 Dart tests): `teamSheets` adds `captainId`, `viceCaptainId`?, `goalkeeperId`,
  `numbers` (every picked player, 1–99, checked against `shirtNumbers()`), `officials` (copies, manager [0], coach [1]); rules
  `hasValidSheetRoles`. `domain/sheet_roles.dart` (`SheetRoles.fitTo` keeps the team's choices and fits them to the picks),
  `SheetCheck.roleProblems`; screen views Players → Roles & numbers → Shirt numbers (`_View`, `PopScope`);
  `widgets/sheet_roles_step.dart`, `widgets/shirt_numbers.dart`. Sheets open any time until the lock (Isaac). Rules changed:
  Isaac deploys to dev. Next: **3.1c** Check step and sheet lines. Rules tests: if the emulators run, `npm test` alone; else
  `firebase emulators:exec --only firestore "cd test/rules && npm test"`.
- **3.1c** done, **team sheet builder finished for Division** (11 Nov 2026, 396 rules tests, 285 Dart tests, no rules change):
  step 3 Check (`widgets/sheet_check_step.dart`: `SheetPaper`, `SheetCheckList`); `myTeamSheetsProvider` (a team lists its
  own sheets); `domain/sheet_status.dart` (`SheetStatus.of`, `needsYou` 2 days before, `lastSheetFor` = Use last sheet);
  `widgets/sheet_line.dart` on the Home card (`HomeNextMatchCard.sheetLine`); Needs you rows; Fixtures `_DueBox` and
  `FixtureRow.extraTags`; `Routes.teamSheet(id, check: true)` opens on Check (`?view=check`). Laptop (>= 840 px): two
  columns, no steps. Tests building team screens override `myTeamSheetsProvider`. Next: **3.1d** juvenile play-up limits.
- Calendar backdrop (`_CalendarBackdrop` in `match_calendar_card.dart`): GEDFA logo as a one-colour watermark (its letters are white,
  so tint it with `color` + `BlendMode.srcIn`). `assets/images/gedfa_logo.png` is now committed.
- **Plan agreed 9 Nov 2026 (deadline Thu 12 Nov, 12:30 pm; Isaac's prompts in that conversation):** next, in order:
  1. **3.0f Notifications and Back** (mockup `3.0f-notifications-and-back.html`, N1–N3, **approved**): a tap marks only
     that note read (reads kept per note in `readMarks/{uid}`: note ID → the `updatedAt` read; a grouped note with a newer
     `updatedAt` is unread again; Mark all read keeps working; owner-only rules with tests) and opens Notification details
     (icon, title, "From GEDFA" or the team, time, full text with every name, "Status: Read", bottom button named after the
     target: "Open Squad", "Review players"…). Back: pages, details and editors use `context.push`; only bottom-tab switches
     use `context.go`; ← pops, or goes to its tab's main screen; the phone's Back = ←. Audit all ~77 `context.go` in lib/
     and list the ones changed.
  2. Juvenile side names (mockup first). 3. **Team admin dashboard** (Home tab: next match, sheet due, squad ready, fee,
     notes; mockup first).
  3. Match day, one step at a time, mockups MS1–MS4 to make first: **3.1** team sheet builder (18 = 11 + 7 subs from
     `settings/league.matchdaySquad`, at least `minPlayers` 7; up to 7 team officials, manager and head coach required;
     captain, vice; no suspended players; 1 U13 and 5 U15 in a U17 match), with a public squad list
     `squads/{teamId}_{category}` written by the FA in the same batch as every approval / eligibility / player suspension
     (the rules check the sheet's IDs against it: 1 lookup; FA suspends players by hand), **3.2** lock 1 h before kick-off
     in the rules, visibility (team + FA, then opponent and appointed officials), **3.5** appoint match officials (referee,
     2 assistants, 4th, commissioner = FA admin or referee; fixture `officials` map; bell notes) + **referee dashboard**,
     **3.3** official sheet + PDF (`pdf` / `printing`, **no QR code**), **3.6** player check (commissioner only).
  4. Shared sending and loading states (M1, M2; part of the UI/UX refresh), light refresh (icon, splash).
  5. Phase 4 (referee reports, protests: fee GH₵ 500 in League settings, chairman-editable; answer time and public
     holidays: GEDFA), Phase 5 (Premier League tie-breakers), Thursday: push notifications (Blaze is on), prod setup.
     Parked until after Phase 5: cups 3.0c2–c5, next matchday card, posters, formation, Season records.
- **Then:** **3.0c** competitions and cups (mockups C1–C4 in `3.0-fixtures-and-sheet.html`:
  the FA picks draw rules, one or two legs; random draw; knockout with byes or groups then knockout;
  live draw; bracket; a juvenile cup per age group). Then the rest of 3.0d (next matchday card, D1, J1)
  and 3.0e posters (`assets/images/gedfa_logo.png`, transparent, not committed yet). Rules changed in 3.0b
  (`fixtureDrafts`): Isaac deploys to dev. (mockup `3.0-fixtures-and-sheet.html`), then **Phase 3** team sheets (18 = 11 + 7 subs, minimum 7, from settings, GFA play-up limits, kit in the top-left corner),
  then the **UI/UX refresh with motion and animations** and the "before the pilot" list (push
  notifications, 3-day fee reminders, prod setup), then the pilot, a second refresh from feedback, Phase 4.
- **The refresh (after Phase 3, before the pilot):** our own app icon (`flutter_launcher_icons`), splash
  screens before "Get started" (`flutter_native_splash` + an in-app intro), and a modern look with
  motion, done as its own steps, one screen group at a time, mockups first, never mixed with feature work.
- Phase 4 ideas agreed: a Season stats screen (top scorers, assists, clean sheets, best attack and defence;
  fourth officials record assists) and referee appointments per fixture.
- turn off the Co-Authored-By line in your commit settings for this project.
