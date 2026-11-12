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
   - `cd test/rules && npm test` → **all** rules tests pass (463 after 3.6c)
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

## Steps left (Isaac, 11 Nov 2026), in order

Build one at a time, mockup first where it says so; details are in `docs/ROADMAP.md` and `docs/DATA_MODEL.md`.

| # | Step | What it is | Mockup | Notes |
|---|------|------------|--------|-------|
| ✓ | **3.2** Lock and visibility | The FA views any team sheet; the opponent from the lock | — | Done 11 Nov 2026 |
| ✓ | **3.1e** Player suspensions | 3.1e1 suspend / lift, Suspended list, the club's rows and bell; 3.1e2 locked row on the sheet + moving a ban when a match is postponed; unique note icons | Approved | Done 11 Nov 2026. **Next: 3.5** |
| ✓ | **3.5** Match officials + referee Home | ✓ **3.5a** the FA appoints (`fixtureOfficials`, notes to `person:<uid>`); **3.5b** referee Home, Matches, bell, Can't make it (RD1–RD3); **3.5c** officials see **both sheets from the lock, with player IDs** (MC1) | **Approved** (`3.5-match-officials.html`; MC1 in `3.6-match-day-check.html`) | Done 12 Nov 2026 (3.5a–c). **Next: 3.3**. Clubs see officials 24 h before |
| ✓ | **3.3** Official sheet as a PDF | Both teams' sheets with player IDs, kits, officials, captains' signature lines; `pdf` / `printing`; **no QR code** (Isaac) | MC4 approved | Done 12 Nov 2026 (3.3, 3.3b team copy + photo kits). Web: `web/index.html` gives older Safari pdf.js legacy; if the preview fails the screen offers Open the PDF. Deploy after `flutter clean` (a stale build left out the printing web plugin). **Next: 3.6** |
| ✓ | **3.6** Player check (✓ 3.6a photos, ✓ 3.6b Check players, ✓ 3.6c FA's view + note; MC3 later) | "Check players": the **commissioner only** checks each face (big photo, number, ID): Matches / Doesn't match (note) / Absent; a mismatch is **recorded** for the FA and the report, not struck off (MC2, MC5) | MC2, MC5 approved | Photos via a separate locked-down copy, Storage rules too |
| ✓ | **M1, M2** Sending and loading states | Start-up screen, `LoadingView(message:)` / `SkeletonList` / `LoadingLine`, `BusyButton`, `SendingSheet.run` (`core/widgets/loading.dart`, `sending.dart`) | Approved (`m1-m2-loading-and-sending.html`) | Done 12 Nov 2026. New loading / save code must use these. **Next: Refresh (light)**. Full manual tests: `docs/TEST_PLAN.md` |
| 7 | **Refresh (light)** | App icon (`flutter_launcher_icons`), splash (`flutter_native_splash`) + intro before "Get started" | Yes, first | Never mixed with feature work |
| 7b | **3.3c** PDF preview on old iPhones | iPhone 8 (iOS 16), every viewer (FA, commissioner, referee, team): the preview page is blank (pdf.js legacy runs, draws nothing; likely OffscreenCanvas). Print / Download work. Fix: pdf.js without OffscreenCanvas, or on old Safari skip the preview and show "Your sheet is ready" + Open the PDF (`_PreviewUnavailable`) | — | Isaac, 12 Nov 2026: after Refresh (light), before Phase 4 |
| 8 | **Phase 4** Match reports | Referee report form (offline draft), signed sheet photo, FA approval; goals, cards, assists (4th official); **protests** (fee GH₵ 500 in League settings, chairman-editable) | Yes, first | Ask GEDFA: protest answer time, public holidays |
| 9 | **Phase 5** Standings | Table from approved reports, **tie-breakers as the English Premier League**, top scorers, fair play, automatic suspensions from cards | Yes, first | |
| 10 | **Push notifications** | FCM (Blaze is on), 3-day fee reminders | — | Before the pilot |
| 11 | **Production setup** | Prod Firebase project, rules deploy, store listing | — | Only when Isaac says so |
| 12 | **Pilot**, then refresh 2 | Real clubs use it; a second refresh from their feedback | — | |
| 13 | **JA** Juvenile age groups | A club enters 1–3 age groups at registration / by a change request, only before the season is published | Yes, first | GEDFA, 10 Nov 2026 |
| 14 | **JF** Fees by competition | Division and Juvenile affiliation fees (+ referee fee) | Yes, first | GEDFA, 10 Nov 2026 |
| — | Parked until after Phase 5 | 3.0c2 live draw, 3.0c3 bracket, 3.0c4 groups, 3.0c5 two legs / replays; 3.0d next matchday card (D1, J1); 3.0e posters; 3.4 formation; Season records (past seasons, stats screen); 5.5 feed; 6 formation tool; 7 live updates / fan view; 8 release (crash reports, backup, Play Store, user guide, more districts) | | Ask GEDFA first: cup pots before results, juvenile sides in an open cup, final one match, gala match length; U13 play-up limit in a U15 match |

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
- **3.1d1** done (11 Nov 2026, 405 rules tests, 293 Dart tests): **juveniles in the Division** (mockup `3.1d-division-juveniles.html`,
  approved): `squads/{teamId}_divisionJuveniles` (player ID → "U15"), the TEAM names / removes one per write (rules
  `isDivisionJuvenilesChange`, limits counted with `removeAll`); `players/domain/division_juveniles.dart`, repository +
  `myDivisionJuvenilesProvider`, Squad › Division `DivisionJuvenilesCard` + picker; FA told with `teamUpdated`. Rules changed:
  Isaac deploys to dev. Next: **3.1d2** the Division sheet takes the 7 (pills) + juvenile play-up limits (MS6). Widget tests
  with `PlayerAvatar` need `sharedPreferencesProvider` overridden.
- **3.1d2** done (11 Nov 2026, 409 rules tests, 297 Dart tests): Division sheets pick from `division` + `divisionJuveniles`
  (rules `divisionPicksOk`), U17 sheets `playUpOk` (1 U13, 5 U15; `playUpLimit` in `sheet_picks.dart`). The Division list is kept
  exact via `isSquadRemoval` → `notInDivisionJuvenilesAfter` (not in the player rule: it is at the 1000-expression limit).
  **Rules lookups: `exists()` + `get()` of one doc count as 2**; sheet saves are at 10 (U17), so they use `isSheetTeamAdmin`
  (one get) and read the U17 list with one get. **`settings/league` may not exist** (defaults; only made on the first change):
  never `get()` it without `exists()` (that broke every sheet save on dev, fixed 11 Nov). FA note kind `divisionJuveniles`. Rules changed: Isaac deploys to dev. Next: **3.1e**.
- **3.2** done (11 Nov 2026, 411 rules tests, 301 Dart tests): `teamSheets.players` copies (`SheetPlayer`), `SheetPaper` draws
  `SheetPlayer`s; `TeamSheetViewScreen` (`Routes.adminMatchSheet` / `teamMatchSheet`), View in Match details (FA any time,
  opponent from the lock, rule `isOpponentAfterLock`). Rules changed: Isaac deploys to dev. Next: **3.1e** (mockup first).
- **Rules fix** (11 Nov 2026, `c568de6`, 412 rules tests): sheets couldn't save on dev because `settings/league` didn't exist.
- **Next conversation: build 3.1e1** (Isaac, 11 Nov 2026). Mockup `docs/mockups/3.1e-player-suspensions.html` approved (SP1–SP5).
  Isaac's answers: a suspension counts **matches**, not days (the app finds the club's next N scheduled matches in that
  competition and shows "returns Sat 5 Dec, against Ojobi Rangers"); **any FA official** suspends or lifts (reasons: red card,
  violent conduct, yellow cards, other); the club sees the reason and matches left; it applies **only in the competition where
  it was given** (a Division ban: Division matches only, also for a juvenile named for the Division). Planned data:
  `suspensions/{id}` (player, team, competition / age group, reason, note, `matches`, `fixtureIds` to miss, by, at,
  `liftedAt`?); the rules check sheets with NO extra lookups through a `banned` map on each fixture (team ID → player IDs),
  written in the same batch. Beware: fixture saves are near the 1000-expression limit, and sheet saves at 10 lookups.
  Before starting, check that Isaac deployed the `c568de6` rules and that sheets save on dev.
- **3.1e1** done (11 Nov 2026, 426 rules tests, 316 Dart tests): `playerSuspensions/{id}` (named so, not `suspensions`, to keep it apart from
  the team suspensions of 2.11c) + `fixtures.banned` (team ID → player IDs, FA only, alone: rule `isBanningMatch`; a normal match update must
  keep `banned` as it is, checked early for the expression limit) + bell kinds `playerSuspended` / `playerSuspensionLifted` with
  `notifications.targetId` (Open the player). `features/suspensions/`: `domain/player_suspension.dart` (`BanPlan` = which matches, `BanStatus` =
  matches left from **played** matches, return match), `data/player_suspension_repository.dart` (`faBansProvider`, `myBansProvider`),
  `suspend_player_screen.dart` (SP1, `Routes.adminSuspendPlayer`), `suspended_players_screen.dart` (SP2, `Routes.adminSuspended`),
  `widgets/ban_widgets.dart` (`BanBanner`, `FaBanBar`, `liftBan`). Squad cards: `CardExtra.banLeft`. A 10-match suspension (12 writes) is
  tested within the rules limits. Rules changed: Isaac deploys to dev. **Next: 3.1e2** (sheet lock SP4 with `Fixture.isBanned`, rules on
  `banned` in `isValidTeamSheet` without new lookups, and moving marks when a match is postponed / matches added later).
- **3.1e2** done (11 Nov 2026, 431 rules tests, 321 Dart tests): sheets refuse `fixture.banned[teamId]` (rules, no lookup); sheet rows
  locked (`_PlayerRow.banNote`, `banMessage`), a saved sheet drops a newly suspended player. `suspensions/data/ban_mover.dart`
  (`BanMover.moveOff`, `BanPlan.movesFor`) runs in **its own batch before** `FixtureRepository.postpone` / `cancel`: **the rules'
  1000-expression limit counts every write of a batch together** (a postpone + the moves went over), so never add writes to a
  postpone or match-change batch. Notes: `noteKindIcon(kind)` in `note_look.dart`, one icon per kind (test in
  `player_suspension_test.dart`); a new kind needs a new, unused icon.
- **3.1e3** done (11 Nov 2026, Isaac's rule): a suspension **blocks every competition** until served; only where it was given counts.
  `BanPlayer.canBePickedFor`, `BanStatus.blocks` / `blockedUntil`, `BanSyncPlan` (pure) + `BanSync.syncTeams` / `trySync` in
  `ban_mover.dart`, called after suspend, lift and every `FixtureRepository` write (add, publish, change, postpone, new date, cancel,
  league postpone). It sets whole `banned.{team}` lists (rule `isBanningMatch`). The sheet also computes the blocking from
  `myBansProvider`, so it is right even if a sync failed. 432 rules tests, 326 Dart tests. **Next: 3.5.**
- **3.5a** done (12 Nov 2026, 441 rules tests, 336 Dart tests): `fixtureOfficials/{fixtureId}` (its own doc so clubs read it only from
  24 h before; rules `isValidMatchOfficials`, `isOfficialPlace`, `isClubOfMatchSoon`); `features/officials/`: `domain/match_officials.dart`
  (`OfficialPlace`, `MatchOfficials.withPlace`, `busyElsewhere`, `refereeColoursFor`), `data/officials_repository.dart` (`save` + notes,
  `seasonOfficialsProvider`, `matchOfficialsProvider`), `widgets/officials_card.dart` (`OfficialsSection` on Match details, picker),
  `appoint_round_screen.dart` (MO3, `Routes.adminAppointRound`, from the matchday heading). Notes `NotificationWriter.forPersonInBatch`
  (audience `person:<uid>`, kinds `appointed` / `appointmentRemoved`; their targets point at `Routes.referee` until 3.5b). Rules changed:
  Isaac deploys to dev. **Next: 3.5b** (referee tabs Home · Matches · More, their bell reads `person:<uid>`, Can't make it).
- **3.5b** done (12 Nov 2026, 445 rules tests, 349 Dart tests): referee area `/referee` (Home `RefereeHomeScreen`), `/referee/matches`
  (`RefereeMatchesScreen`, `match/:id` = `MatchDetailsScreen(isOfficial: true)`), `/referee/more`, `/referee/notifications`;
  `refereeDestinations` in `app_shell.dart`; `MorePaths` knows `/referee`. `BellPlaces` / `bellPlacesProvider` (`notification_bell.dart`)
  give each role its bell, note, announcement, home and match routes: use them, not `isFa ? … : …`. `myAudienceListProvider` + `mergeNotes`:
  the FA's bell reads `fa` and `person:<uid>`. Can't make it: `OfficialsRepository.cantMakeIt` (`fixtureOfficials.cantMake.{uid}` + FA note
  `cantMakeIt` in one batch), `MatchOfficials.cantMake` (`withPlace` drops people no longer in). `appointmentsOf`, `othersLine` in the domain.
  `PlaceholderHome` removed. Rules changed: Isaac deploys to dev. **Next: 3.5c** (both sheets for officials from the lock, MC1).
- **3.5c** done, **3.5 finished** (12 Nov 2026, 446 rules tests, 350 Dart tests): rule `isOfficialAfterLock` (teamSheets read by
  `fixtureOfficials.officialIds` from the lock); `SheetPaper.showIds` (position · player ID); `savedSheetPaper(f, sheet, showIds:)` in
  `team_sheet_view_screen.dart` draws any saved sheet (use it for 3.3 too); `_OfficialSheets` on Match details (`isOfficial`). Rules
  changed: Isaac deploys to dev. **Next: 3.3** the official sheet as a PDF (MC4 approved, `pdf` / `printing`, no QR code).
- **FA sees IDs** (Isaac, 12 Nov 2026): `TeamSheetViewScreen` draws `savedSheetPaper(f, s, showIds: isFa)`; the opponent's view has no IDs.
- **Next conversation (Isaac, 12 Nov 2026): build 3.3**, the official team sheet as a PDF (mockup MC4 in `3.6-match-day-check.html`,
  approved): both teams' sheets with player IDs (`savedSheetPaper` / `SheetPlayer.code`), kits, the officials from `fixtureOfficials`,
  captains' signature lines; packages `pdf` / `printing`; **no QR code**. Before starting, check Isaac deployed the 3.5 rules to dev.
- **3.3** done (12 Nov 2026, 446 rules tests, 358 Dart tests, no rules change): `team_sheets/domain/official_sheet.dart`
  (`OfficialSheet.of` = what the paper says, pure and tested), `presentation/official_sheet_pdf.dart` (`officialSheetPdf`, `kitSvg`,
  `OfficialSheetFonts` = Noto Sans from `assets/fonts/`, so it prints offline), `official_sheet_screen.dart` (`PdfPreview`, Print,
  Share / Download on the web; `Routes.adminMatchPdf` any time, DRAFT before the lock; `Routes.refereeMatchPdf` from the lock).
  `_OfficialSheetCard` on Match details. To look at a PDF: `OFFICIAL_SHEET_OUT=file.pdf flutter test test/official_sheet_test.dart`.
  **3.3b** (Isaac, 360 Dart tests): `SheetViewer.fa / official / team`; a team prints its own sheet (`Routes.teamMatchPdf`,
  `OfficialSheet.of(onlyTeamId:)`, "Print your team sheet" card); photo kits: `loadKitPhotos` then `_kitBox` stacks shirt / shorts /
  socks in the kit box (`KitPictures`). Next: **3.6** player check (MC2, MC5).
- **3.6a** done (12 Nov 2026, 452 rules tests, 363 Dart tests): `playerPhotos/{playerId}` (`players/data/player_photos.dart`:
  `playerPhotoCopy`, `playerPhotoRef`, `PlayerPhoto`, `playerPhotoProvider`), written by the FA in `approve` / `passJuvenile` and
  `repairPlayerPhotos` (the Squad lists Repair runs both); rule `isPlayerPhotoCopy` (only the player's own links); read by FA and
  referees. Isaac: check from the lock to 2 h after kick-off; MC3 later. Rules changed: Isaac deploys to dev, then presses Repair.
  **Next: 3.6b** Check players (MC2) for the commissioner, `playerChecks/{fixtureId}`; then 3.6c the FA's view (MC5) + note.
- **3.6b** done (12 Nov 2026, 458 rules tests, 376 Dart tests): `features/player_checks/` (`domain/player_check.dart`: `CheckResult`,
  `PlayerCheck`, `MatchPlayerChecks.entryWrite` (one player, `changed`; an old note is deleted), `CheckWindow` (lock to kick-off + 2 h),
  `CheckLine.forSheet` (shirt order), `nextUnchecked`; `data/player_check_repository.dart`, `playerChecksProvider`;
  `presentation/check_players_screen.dart` (MC2, `_NoteDialog` owns its controller), `Routes.refereeMatchCheck` / `adminMatchCheck`;
  `_PlayersCheckCard` on Match details (commissioner only). Rules `isCommissionerOf`, `isValidPlayerCheck`. Rules changed: Isaac deploys
  to dev. **Next: 3.6c** the FA's view (MC5) on Match details + a bell note to the FA when a player doesn't match.
- **3.6c** done, **3.6 finished** (12 Nov 2026, 463 rules tests, 381 Dart tests): `CheckSummary` (counts, mismatchLines) in
  `player_check.dart`; `_PlayersCheckResults` on Match details (FA and officials, from the lock); `PlayerCheckRepository.record`
  takes the `Fixture` and writes the check + FA note (`playerMismatch`, `mismatchNoteLine`) in one batch; rules `playerCheckDoc`,
  `isMismatchJustRecorded` (defined above `canNotifyFa`). Icon `face_retouching_off_rounded`. Rules changed: Isaac deploys to dev.
  **Next: M1, M2** (shared sending and loading states, mockup first), then Refresh (light), then 3.3c.
- **3.6 tested by Isaac** (12 Nov 2026). **Next conversation: M1, M2, mockup first** (Isaac's direction): the styled loading
  starts at **app start-up**, when a user opens the app, with a **friendly message**; after start-up, **loading** (fetching) and
  **submitting** (saving / sending) each get their **own messages** in the app. One shared look everywhere (replace the plain
  `LoadingView` / spinners and the "saving…" states screen by screen). Then Refresh (light), then 3.3c.
- **M1, M2** done (12 Nov 2026, 463 rules tests, 389 Dart tests, no rules change): every page's loading says its own words
  (`LoadingView(message: …)`, exported from `state_views.dart`); lists use `SkeletonList` (a `ListView`: only as a body or in
  `Expanded`); save buttons use `BusyButton(label, busyLabel, busy, onPressed)` (`showSlowNote: false` beside another button);
  long saves use `SendingSheet.run(context, title:, unit:, start:, task: (progress) => …)`. An `AnimationController` that a
  widget may never use must be made in `initState`, not `late final … =` (made first in `dispose` it crashes). Isaac's full
  manual test list: `docs/TEST_PLAN.md` (keep it up to date with each step). **Next: Refresh (light)**, then 3.3c.
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
