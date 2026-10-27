# GEDFA Connect — Project Roadmap

**App name:** GEDFA Connect (repo `gedfa-connect`, package `gedfa_connect`)
**Platforms:** Flutter app: Android (APK) and web (iPhone users via "Add to Home Screen"); native iOS later (see Section 4, Distribution); separate React website by a colleague
**Backend:** Firebase (Auth, Firestore, Cloud Storage, Hosting) on the Blaze plan
**Projects:** `gedfa-connect-dev` (building/testing) and `gedfa-connect-prod` (real GEDFA data)
**Status:** Phase 0 and Phase 1 complete · Phase 2: 2.0–2.8 done; GEDFA's answers in: 2.13 registration update in progress (2.13a–b done), then 2.14 Juvenile, then Phase 3 · web test link live on dev (27 Oct 2026)

See also: `docs/DATA_MODEL.md` (the data contract).

---

## 1. Purpose

A single system that lets the GEDFA third-division league run digitally, from player registration to the final league table and a league news feed, replacing paper forms, Excel sheets and WhatsApp photos of standings.

### About the "non-scoring" league
"Non-scoring" means results are **not reported to the GFA** and the league winner is **not promoted**. Scores and standings are still recorded and published **within the district**. The app records scorelines, cards and standings as normal.

---

## 2. Objectives

### Primary (must have)
1. **Register teams and players digitally.** Teams submit their details, officials and players; the district FA reviews and approves.
2. **Keep player data consistent and clean.** One player record per person, valid dates of birth, unique jersey numbers per team, names entered once.
3. **Generate official team sheets** from *approved* players only, as a printable/shareable PDF.
4. **Record match results.** Referees submit score, scorers, cards and notes; the FA approves the report.
5. **Publish standings automatically** from approved reports only, with PDF/image export.

### Secondary (should have)
6. **League feed.** Automatic posts (fixtures, line-ups, results, table updates, transfers, suspensions) plus FA announcements and team news.
7. **Tactics board.** Coaches place players on a pitch, choose formations and share as an image.
8. **Discipline tracking.** Fair-play table and players with accumulated cards.

### Later (nice to have)
9. **Live match reporting** and a public fan view.
10. **Notifications** (approvals, fixtures, deadlines).
11. **Multi-district support** with per-district data and branding.

### Non-functional
- **Fast:** pagination (`limit(20)`), compressed photos, cached lists.
- **Secure:** access enforced by Firebase security rules, never by screens alone.
- **Works on weak networks:** offline viewing from cache; offline banner; time limits on submissions (see Section 5).
- **Fits every screen:** responsive layouts tested on small phones, typical phones and laptops (see Section 5).
- **Low cost:** stay near Firebase's no-cost allowances; budget alerts on both projects.
- **Privacy-conscious:** collect only what is needed; never show dates of birth publicly.

---

## 3. Users and roles

| Role | Who | Can do |
|---|---|---|
| **FA Admin** | District FA officials | Approve/reject teams and players, create fixtures, assign referees, approve reports, manage roles, post announcements |
| **Team Admin** | Team manager/official | Manage own team, officials and players; build team sheets; post team news |
| **Referee** | Match officials | View assigned fixtures, submit match reports (later live events) |
| **No role yet** | New sign-ups | Submit a team registration request and view its status |
| **Public/fan** *(later)* | Supporters | Read-only fixtures, results, standings, feed (no personal data) |

### How roles work
- Roles live in `users/{uid}`, writable **only by FA admins**. Users can never edit their own role.
- The developer creates the **first FA Admin** (e.g. the Chairman) by hand in the console, **once per project**.
- After that, roles are given **only by invitation**: an FA admin invites an email; the person signs up with that email, confirms it, and the role is granted. No secret codes; no self-registration as admin or referee.
- The last FA admin can't be removed; role changes are logged.
- A new user with no role sees "Register your team", then "Awaiting FA approval". Rejected requests show the reason and can be fixed and resubmitted.

---

## 4. Technical approach

- **App:** Flutter/Dart, Material 3, feature-first folders:
  `lib/app` (app, router, theme) · `lib/core` (constants, widgets, connectivity, layout, firebase) · `lib/features/<feature>/{data,presentation}`
- **State management:** Riverpod (one approach everywhere).
- **Routing:** go_router with role-based redirects.
- **Auth:** Firebase Authentication (email/password).
- **Database:** Cloud Firestore (`africa-south1`), everything under `districts/{districtId}/`.
- **Files:** Cloud Storage (`us-east1`, free-tier region) for passport photos and logos, compressed before upload.
- **PDF:** `pdf` and `printing` packages.
- **Local testing:** Firebase Emulator Suite (Auth 9099, Firestore 8080, Storage 9199, UI 4000). Debug builds use the emulators by default; `--dart-define=USE_EMULATORS=false` switches to the real dev project.
- **Rules as files:** `firestore.rules` and `storage.rules` live in the repo and are deployed with the CLI; never edited in the console.
- **Rules tests:** `test/rules/` (Node, `@firebase/rules-unit-testing`). Run `npm test` there while the emulators run. Uses its own project ID (`demo-gedfa-rules`), so app data in the emulator is untouched. Every rules change must keep all tests passing.
- **Unit tests:** `test/` (`flutter test`), e.g. player-key and jersey-ID functions.
- **Emulator data:** start with `firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data`; stop with Ctrl+C so the data is saved. `emulator-data/` is not committed.
- **Cost control:** budget alerts, pagination, few realtime listeners, no backups/PITR on dev.

### Distribution *(decided 18 Oct 2026)*

| Users | How they get the app |
|---|---|
| Android | APK through **Firebase App Distribution** (testers get an install link by email) |
| iPhone | The **web build** on Firebase Hosting, opened in Safari and added with **Share → Add to Home Screen** |
| iPhone, native app | **Later**, only if GEDFA funds an Apple Developer account (US$99/year) |

- **Dev web link:** https://gedfa-connect-dev.web.app (tested on an iPhone 8, 18 Oct 2026).
- **Deploy the web build:**
  1. `flutter build web --release --dart-define=USE_EMULATORS=false`
  2. `firebase deploy --only hosting --project gedfa-connect-dev`
  Always name the project with `--project`.
- **Storage CORS:** the web build loads photos and logos from the Storage bucket, so the bucket must allow the Hosting addresses (set once per project with `gcloud storage buckets update gs://<bucket> --cors-file=cors.json`; done on dev).
- **Rules deploy:** `firebase deploy --only firestore:rules,storage --project gedfa-connect-dev`.

---

## 5. Design and UX standards

### Design system
- Theme in `lib/app/theme.dart`: logo blue `#1E88E5`, deep blue `#1259A8` for buttons/links, Ghana red/gold/green accents, Poppins font.
- Status colours: **green = approved, gold = pending, red = rejected**.
- Reusable widgets in `lib/core/widgets`: `StatusBadge`, `LoadingView`, `EmptyView`, `ErrorView`, `AppToast`, `CountTabs` (status tabs with count bubbles: gold = waiting).
- Every screen has loading, empty, error and offline states. Touch targets ≥ 48dp.
- Mockups: "GEDFA Connect Screens" design canvas.

### Navigation
- **No hamburger menu.** Phones use a bottom navigation bar (≤ 5 tabs, different per role); large screens use a side navigation rail. Rarely used items (profile, settings, log out, help) sit under a "More"/profile tab.
- Built with a go_router `StatefulShellRoute` (`lib/app/app_shell.dart`); each tab keeps its own history. A tab is added only when its screen exists. Detail screens (player, request review) open full-screen above the tabs.
- **Team admin tabs:** Squad · More. **FA admin tabs:** Teams (gold badge = requests waiting) · More. Players (2.3), Fixtures and Feed are added when built.
- **More** is a menu: account card (opens **My profile**), Team profile (team admins), **Settings**, League rules, Help, About, Log out. Rows not built yet open a "Coming soon" page.
- **App bar** (agreed 18 Oct 2026): logo and name (with short name · town) on the left; on the right only frequent actions (search, and the activity bell once it has real content). **Log out and dark mode are not in the app bar.** The theme is chosen only in Settings (Light / Dark / System, saved on the phone); login and welcome screens follow it. Log out always asks "Log out?".

### Feedback
- **Top toasts** (`AppToast`) for every completed or failed action, with a message specific to the action (e.g. "Welcome back!", "Team request sent to the FA").
- Firebase error codes are translated into friendly messages by one shared translator.

### Connectivity
- Offline banner on every screen (`connectivity_plus`), plus a brief "back online" banner.
- **Works offline:** viewing previously loaded data; later, drafting match reports that sync when back online.
- **Needs internet:** login/sign-up, photo uploads, submissions that need server confirmation (team requests, adding players, approvals). These wait for Firebase's confirmation and have a time limit with a friendly message.

### Responsive layout
- Material 3 size classes: **compact** < 600, **medium** 600–839, **expanded** ≥ 840 (`lib/core/layout/responsive.dart`).
- Forms sit in `ResponsiveCenter` (max width 480); dashboards use wider limits.
- No fixed heights around text; screens scroll.
- Test every screen on a 360-wide phone, a small/short phone (iPhone SE) and a ~1280-wide laptop view, plus large text.

---

## 6. Data and privacy

- **No ID documents.** Only passport photos plus details of players and officials.
- Still personal data (names, dates of birth, photos, some players under 18):
  - Squad details visible only to FA admins, assigned referees and the team's own admins.
  - Dates of birth are never shown publicly (feed, fan view).
  - Player photos in the feed only if GEDFA and teams agree.
  - Agree a retention rule with the FA.
- Check with the FA whether any data-protection obligations apply. (This roadmap is not legal advice.)

---

## 7. Roadmap

Time estimates assume part-time work and are rough guides.

### Phase 0 — Foundations ✅ *(done 13 Oct 2026)*
- [ ] 0.1 Confirm league rules with GEDFA *(postponed — see Section 10)*
- [x] 0.2 Name (GEDFA Connect) and GitHub repo
- [x] 0.3 Dev and prod Firebase projects (Blaze, budget alerts, Auth, Firestore `africa-south1`, Storage `us-east1`)
- [x] 0.4 Flutter project connected to dev; Firestore write/read test passed
- [x] 0.5 Feature-first folders; Riverpod, go_router, Firebase packages
- [x] 0.6 Data model agreed (`docs/DATA_MODEL.md`)
- [x] 0.7 First FA Admin created on dev
- [x] 0.8 Design foundation: theme, reusable widgets, mockups

### Phase 1 — Auth, roles, team and player registration ✅ *(done 18 Oct 2026)*
- [x] 1.0 Firebase Emulator Suite; app uses emulators in debug
- [x] 1.1a `AppToast`, offline/back-online banner, responsive helpers
- [x] 1.1b Log in, sign up, log out, password reset; Firebase error translator; submission time limits
- [x] 1.2 Role-based router: no role → registration/status; team admin → team dashboard; referee → fixtures; FA admin → FA dashboard
- [x] 1.3 Team registration request form and status screen (club details, logo, 5 kits with trims, officials, review, edit and resubmit, Google sign-in)
- [x] 1.3b Competitions: Division and/or Juvenile (U13, U15, U17) chosen at registration; shown on Review and Status
- [x] 1.4 Team home (squad list with counts, search by name or ID, position filters, Division / Juvenile switch), player details screen, add/edit player form: name, DOB picker, 23 positions in 4 groups, jersey number 1–99 with live check, squad limit 30. *Juvenile extras (age group from DOB, birth certificate, guardian) wait for GEDFA's answers.*
- [x] 1.5 Validation: jersey reservations (`teams/{teamId}/jerseys/{category}-{number}`) and duplicate-player reservations (`playerKeys`); friendly messages; changing name, DOB, jersey or photo of an approved player asks before sending it back to the FA; first unit tests (player-key and jersey-ID functions)
- [x] 1.6 Passport photo, required: cropped to 3:4 on the phone, 300×400 photo + 96×128 thumbnail (JPEG), uploaded to Storage; old files deleted after a change; storage rules check the team admin through Firestore
- [x] 1.7 Security rules v1 for users, teamRequests, teamNames, teams, jerseys, playerKeys, players and storage; **49 automated rules tests passing** (`test/rules/`)
- [x] 1.8 Web build on Firebase Hosting (dev), Storage CORS, rules deployed to dev; tested end to end on an iPhone 8 (sign up, register team, hand-approved team, add player with camera photo)

**Done when:** a test team admin can register a team request and add players, and a role-less user can't read or write anything beyond their own request. ✅ Proven by the rules tests and on the live dev link.

> **FA admin rules** (reading all requests and players, approving) were moved to Phase 2, where the FA screens that need them are built.

### Phase 2 — FA approval dashboard
- [x] 2.0 Tab shell (bottom bar on phones, rail on wide screens); **More** menu; **My profile** (edit full name, change email with a confirmation link to the new address, password reset link, delete account explains to ask the FA); **Settings** (Light / Dark / System, data saver: no photos in lists, notifications placeholder); app bar clean-up; deep-blue Add player button *(done 19 Oct 2026)*
- [x] 2.1 FA area: Teams tab with a gold badge for waiting requests; team requests list (Pending / Rejected / Approved with counts, search, oldest pending first); review screen (club details, kits, officials with a call button, automatic checks) *(done 20 Oct 2026)*
- [x] 2.2 Approve or reject a team request. **Approve** = one batch: request approved + team created from it (ID = reserved name key, logo link reused) + club's account made team admin. **Reject** = reason (10–500 characters, quick reasons); the club fixes and resends. 71 rules tests *(done 22 Oct 2026)*
- [x] 2.3 FA **Players** tab (gold badge): teams list with totals, progress bar and "N to review", search by team, player name or ID; a team's players in rows by position (Goalkeepers, Defenders, Midfielders, Forwards), 3-column photo grid, To review / Approved / All; **select several and approve together**; review screen (photo, automatic checks, visual verification, details). Approve = transaction giving the player ID (`GE26-0042`) from `settings/playerCounter`; re-checked players keep their ID. Reject with a reason. Notification bell (placeholder) on the main app bars. 90 rules tests *(done 22 Oct 2026)*
- [x] 2.3b **Team Squad and Positions tabs** with the same position rows as the FA (one shared widget). Squad: Approved / Pending / Rejected tiles that filter, search, a notice when players were rejected; cards show the player ID. New **Positions** tab: All / GK / DEF / MID / FWD, rows by detailed position inside a group, average age, "Approved players only" switch (the players who can go on team sheets) *(done 24 Oct 2026)*
- [x] 2.4 Status filters and search *(FA requests and players: status tabs and search; team Squad: status tiles and search)*
- [x] 2.5 Lock approved players (changes to name, DOB, jersey or photo need re-approval) *(done early, in 1.5 and 1.6)*
- [x] 2.6 Role management by **invitation**: More › People and roles (FA admins, referees, invited); the chairman invites FA officials and referees, FA officials invite referees; the invitation is shared on WhatsApp or copied (no automatic email), expires after 14 days; the invited person signs up with that email and accepts or declines; remove role (chairman protected, never yourself); role history. 119 rules tests *(done 24 Oct 2026)*
- [x] 2.3c **Possible duplicates** on the FA player review: same date of birth and a similar name (word order, "Jnr", 1–2 letters), or the same name with a date of birth up to 2 years apart; photos side by side, the FA decides (alongside the name + date-of-birth key). **What the team changed**: re-submitted players list each change from → to (old and new photo side by side); the FA's review clears the list. 124 rules tests *(done 24 Oct 2026)*
- [x] 2.3d **Player profiles** (Positions tab, clipboard icon): availability (Available / Injured / Unavailable, expected back, no medical details) with counts and an "Available players only" switch; height, weight, preferred foot, can also play (2), strengths (3), hometown, at the club since, previous club; captain and vice-captain (one each per squad, C / VC badges; team sheets will fill them in); private emergency contact (**required for Juvenile** later). No FA approval. 136 rules tests *(done 24 Oct 2026)*
- [x] 2.7 **FA announcements**: any FA admin publishes (agreed in the officials' meeting first); to everyone, all teams, Division, Juvenile or referees; Important and Pinned; one-way; pinned card on top of Squad (each team can hide it); the FA sees who has seen it, by team logo *(done 24 Oct 2026)*
- [x] 2.8 **Notifications** behind the bell, with a red unread count: teams get players approved / rejected and team approved; the FA gets team requests, new and resubmitted players (with the change) and accepted invitations; plus announcements. **Grouped**: one notification per kind, team and day that counts up (20 approvals = 1 notification). Written in the same batch as the action. Mark all read. 149 rules tests *(done 24 Oct 2026)*
- [ ] 2.9 FA admin security rules, with rules tests added to `test/rules/` *(in progress: team requests and players done; corrections and settings to come)*
- [ ] 2.10 **Team profile and change requests:** team admins view their team; kits, officials and home ground save directly; **name, short name and logo need FA approval** with a reason/note
- [ ] 2.11 **FA corrections** for approved teams: edit small mistakes directly (logged); **ask for a correction** (yellow banner on the team's squad screen, fix goes back to the FA); **suspend** a team for serious problems. An approved team is never moved back to Pending

- [ ] 2.12 **FA dashboard** (Home tab): totals of teams and players, players by competition and position group, waiting reviews; later referees, cards and suspensions. Uses Firestore count queries so it stays cheap as the league grows

> **Flutter and React:** the Flutter app (Android + web) is the working tool for the FA, team admins and referees. The React website (by a colleague) is the public face for fans: fixtures, results, table, news and approved teams. Both use the same Firebase project, `DATA_MODEL.md` and security rules. *(To be agreed with the colleague.)*

> **Before Phase 3:** go through GEDFA's answers to the open questions (Section 10) and a friend's suggestion, and update the roadmap and data model. *(Answers received 27 Oct 2026: see DATA_MODEL Section 7. They became 2.13 and 2.14.)*

- [ ] 2.13 **Registration update** from GEDFA's answers (mockups R1–R8 on the design canvas). Steps: Club details › Club status › Officials › Kits › Colours › Payment, then Review
  - [x] 2.13a **Club status and officials:** already in the district or a new club (last league + letter to the chairman, PDF); optional licence (photo or PDF); logo required; officials 2 required + up to 5, "Other" with a typed role; FA review shows the letter and licence *(done 27 Oct 2026)*
  - [x] 2.13b **Kits and colours:** upload photos (shirt › shorts › socks, cropped and shrunk on the phone, preview) or design the kit; Team colours step (home and away, main and second, suggested from the designed kits); clubs in both competitions set Division and Juvenile kits apart; FA review shows photos and colours. 166 rules tests *(done 27 Oct 2026)*
  - [ ] 2.13c **Season fee:** GH₵ 1,000 every season, MoMo 0244-\*\*\*-\*\*\* (number to come), paid in parts; MoMo/bank, cash, or paid before the app; the FA confirms each payment (green tick) or marks it "not found" with a reason; receipt number per confirmed payment (`GEDFA-2026-0014`); Approve after the first confirmed payment; team Season fee screen; FA "Send reminder" (automatic push every 3 days comes with phone push before the pilot)
  - [ ] 2.13d **League settings:** registration window open / closed; squad 30, matchday 16, substitutes 5
- [ ] 2.14 **Juvenile:** age group = season start year − birth year (U13 / U15 / U17); play up allowed (GFA limits on the team sheet), overage blocked; parent or guardian required; screening days (announcement + push, a card that disappears after screening); FA decisions: pass, move up automatically, or "not eligible for Juvenile" with a reason

### Phase 3 — Team sheet builder and PDF
- [ ] 3.1–3.7 As before: select fixture, pick approved players within limits, captain/GK, formation, PDF, print/share, FA can view

> **Before the pilot:** bundle fonts in the app (offline-safe), set up dev/prod switching (flavors), enable App Check, create the first FA Admin on prod, deploy rules to prod, set Storage CORS and Hosting on prod, set up Firebase App Distribution for the Android APK, consider weekly Firestore backups on prod, **phone push notifications** (Firebase Cloud Messaging, grouped the same way), deploy `firestore.indexes.json`.

> **PILOT MILESTONE:** registration, approval, team sheets and FA announcements usable. Pilot with the FA and one or two teams.

### Phase 4 — Fixtures and referee match reports
- [ ] 4.1–4.5 As before: fixtures and referee assignment, referee view, report form (draft works offline), signed sheet photo, FA approval

### Phase 5 — Standings and exports
- [ ] 5.1–5.6 As before: table from approved reports, tie-breakers, standings screen, export, fair-play and top scorers, suspensions (stretch)

### Phase 5.5 — League feed *(new)*
**Goal:** a trusted, mostly automatic news feed.
- [ ] 5.5.1 Feed screen (paginated, 20 at a time) with post cards per type
- [ ] 5.5.2 Automatic posts: matchday fixtures, line-ups (published at kick-off), full-time results (after FA approval), table updates, transfers (after FA approval), suspensions, new teams welcomed, milestones (top scorer, hat-tricks, clean sheets)
- [ ] 5.5.3 Team news posts by team admins (own team only)
- [ ] 5.5.4 FA moderation: hide/unhide any post
- [ ] 5.5.5 Privacy checks: no dates of birth; player photos only if agreed

**Done when:** a matchday produces fixtures, line-ups, results and a table update in the feed without anyone typing them.

### Phase 6 — Tactics board
- [ ] 6.1–6.4 As before: pitch canvas, formation presets, load squad, save/export image

### Phase 7 — Live match reporting, public view and notifications
- [ ] 7.1–7.5 As before, plus live goal updates in the feed and the public fan view of the feed

### Phase 8 — Hardening, rollout and expansion
- [ ] 8.1–8.6 As before: real-world testing, crash reporting, data export/backup, Play Store release, user guide, multi-district

---

## 8. Suggested timeline

| Milestone | Approx. time (part-time) |
|---|---|
| Phase 0 | ✅ Done |
| Pilot-ready (Phases 1–3) | ~5–7 weeks from Phase 1 start |
| Results and standings (Phases 4–5) | ~4 weeks after pilot start |
| League feed (Phase 5.5) | ~1–2 weeks after Phase 5 |
| Tactics board (Phase 6) | ~1–2 weeks |
| Live reporting (Phase 7) | After the district is using the system |

Work backwards from the GEDFA season start date to decide what the pilot must contain.

---

## 9. Notes for the website version

1. **One backend, two front-ends.** Same Firebase project, data model and security rules.
2. **`docs/DATA_MODEL.md` and the rules files are the contract.** Changes go through the project owner.
3. **Suggested split:** mobile for team admins and referees; web (React) for the FA dashboard, approvals, fixtures, standings, printing.
4. **Business rules in one place** (standings, squad limits, approvals, player keys).
5. **Collaborator access:** dev project only, limited roles; never commit secrets; only the owner touches prod.

---

## 10. Open questions for GEDFA

- Squad size, matchday substitutes, age categories
- Registration window; adding players mid-season; transfers during a season
- Tie-break rules; card accumulation and suspension rules
- One team admin or several per team
- Retention rules for player data
- Whether player photos may appear in the feed
- Season start date and pilot teams

---

## 11. Risks

| Risk | Mitigation |
|---|---|
| Users editing their own role | Roles written only by FA admins; invite-only; rules tested in the emulator |
| Unexpected Firebase bill | Budget alerts; pagination; limited listeners; no paid features on dev |
| Scope creep | Ship Phases 1–3 first; feed and tactics after real use |
| Poor network at venues | Offline cache and banner; submissions with time limits; offline report drafts |
| Rules differ from assumptions | Confirm with GEDFA; keep limits in `settings/league` |
| Web and mobile diverging | Shared data model, shared rules, one source of business logic |
| Wrong or premature news in the feed | Results/transfers posted only after FA approval; line-ups only at kick-off; FA moderation |
| Minors' personal data exposed | No DOB publicly; photos only with agreement |
| iPhone users without a native app | Web build with Add to Home Screen; tested on an iPhone 8; native iOS only if funded |
| Pilot data typed on dev by mistake | Dev link is for testing only; real GEDFA data goes only to prod; every deploy names `--project` |

---

## 12. Changelog

| Date | Change |
|---|---|
| 12 Oct 2026 | Renamed to GEDFA Connect; dev/prod projects created |
| 13 Oct 2026 | Phase 0 complete; added 0.8 design foundation, 1.0 emulators, 1.1a toasts/connectivity/responsive; invite-only roles (2.6); FA announcements (2.7); new Phase 5.5 League feed; navigation, connectivity and responsive standards; pre-pilot checklist |
| 17 Oct 2026 | 1.1b, 1.2, 1.3 done; new 1.3b Competitions (Division / Juvenile, one registration per club); 1.4 split into Division first, Juvenile after GEDFA answers |
| 27 Oct 2026 | 2.13b done: kit photos or designed kits, Team colours, separate juvenile kits |
| 27 Oct 2026 | GEDFA's answers received; new 2.13 Registration update (2.13a done: club status, letter, licence, logo required, officials up to 7 with "Other") and 2.14 Juvenile |
| 24 Oct 2026 | 2.7 and 2.8 done: announcements, notifications (grouped), bell count, pinned card, who has seen it. Phase 2 core done |
| 24 Oct 2026 | 2.3d done: Player profiles, availability and armbands |
| 24 Oct 2026 | 2.3c done: possible duplicates and the exact changes on the FA player review |
| 24 Oct 2026 | 2.6 done (invitations, People and roles, role history, chairman flag). New 2.3c possible duplicates and 2.3d player profiles (proposed) |
| 24 Oct 2026 | 2.3b and 2.4 done: shared position rows for the FA and the team; team Squad tab filters by status; new Positions tab. Order agreed: 2.6, then 2.7–2.8, then the GEDFA answers and the friend's suggestion **before** Phase 3; 2.10–2.12 before or during the pilot |
| 22 Oct 2026 | 2.3 done: FA Players tab (by team, then by position), select several and approve, player review, player ID transaction, re-checked players keep their ID; notification bell placeholder; 90 rules tests. New 2.12 FA dashboard. Flutter / React split proposed |
| 22 Oct 2026 | 2.0, 2.1, 2.2 done (tab shells, More / My profile / Settings, FA team requests, approve and reject; 71 rules tests). New 2.10 Team profile and change requests (name, short name and logo need FA approval) and 2.11 FA corrections (never back to Pending). Live rules are deployed with the CLI, not pasted in the console. GEDFA answers to be reviewed after Phase 3 |
| 18 Oct 2026 | **Phase 1 complete:** 1.3b–1.7 done; new 1.8 web link on Firebase Hosting (dev), tested on iPhone 8. Distribution decided (Android APK via App Distribution; iPhone via web + Add to Home Screen; native iOS later if funded). 23 positions; squad 30; jersey 1–99. FA admin rules moved to Phase 2 (2.9). New 2.0 Settings screen and app-bar clean-up; new 2.8 activity list (bell). 2.5 done early. Rules tests and emulator-data workflow added to Section 4 |
