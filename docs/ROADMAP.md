# GEDFA Connect — Project Roadmap

**App name:** GEDFA Connect (repo `gedfa-connect`, package `gedfa_connect`)
**Platforms:** Flutter app: Android (APK) and web (iPhone users via "Add to Home Screen"); native iOS later (see Section 4, Distribution); separate React website by a colleague
**Backend:** Firebase (Auth, Firestore, Cloud Storage, Hosting) on the Blaze plan
**Projects:** `gedfa-connect-dev` (building/testing) and `gedfa-connect-prod` (real GEDFA data)
**Status:** Phase 0 and Phase 1 complete · Phase 2: 2.0–2.8 and 2.10–2.14 done; next Phase 3, then the UI/UX refresh and the pilot · web test link live on dev (27 Oct 2026)

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
- [x] 2.10 **Team profile and change requests:** team admins view their team; kits, officials and home ground save directly; **name, short name and logo need FA approval** with a reason/note
  - [x] 2.10a **Team profile** (P1, P3): More › Team profile shows the club; town, home ground, colours, kits and officials save straight away (registration screens reused) and the FA gets "X updated their profile" in the bell. 241 rules tests *(done 6 Nov 2026)*
  - [x] 2.10b **Change requests** (P2, P4, P5): Team profile › "Ask to change" (club name, short name, logo) or "Add Juvenile / Division" with a required "Why?"; one pending request of each kind; the team page shows it pending (gold), not approved with the FA's reason (red) or approved (green, for a week). FA Teams tab: **New teams | Changes** (gold counts, also in the tab badge); a change shows now → asked for, why, who asked, and the app's name check; **Approve** (one batch: the team, every player's team name, the name reservation, the team's bell) or **Not approve** with a reason. Bell: the FA when asked, the team when decided. 257 rules tests *(done 7 Nov 2026)*
  - [x] 2.10c **Changes grouped by team** (Isaac's review): Teams › Changes shows one card per team with all its requests (the gold number counts teams); a team's screen decides each change on its own card (**Reject** opens a box for the reason, sent to the team), plus **Approve all**; Approved teams show the team as it is now, with "Previously …" after a rename (also on the registration's header) *(done 7 Nov 2026)*
- [x] 2.11 **FA corrections** for approved teams (mockups A1–A4, B1–B4, C1–C5). An approved team is never moved back to Pending
  - [x] 2.11a **The FA corrects a misspelling or an obvious mistake itself:** the FA's team page shows the team as it is now (not the registration); "✎ Correct name" (the name check, players' team name follows, the new spelling reserved for the club) and Club details › Edit (town, home ground, directions, year founded, email); "Save correction" asks "What was wrong?"; corrections log and "FA fixed" on the page; team bell "The FA corrected your team profile". Officials (sensitive), kits and colours are not corrected by the FA (Isaac, 7 Nov 2026). 268 rules tests *(done 7 Nov 2026)*
  - [x] 2.11b **Ask the team to correct** (B1–B4): FA team page ⋮ › "Ask the team to correct…" and "Wrong? Ask the team to correct it" under officials and kits; tick club details / officials / colours and kits / players and write a message; yellow banner on the team's Squad tab with "Send back to the FA"; Teams › Changes shows sent back (Done / Ask again) and waiting ones, counted in the gold number; bell notes both ways; "X updated their profile" now opens the FA's team page. 276 rules tests *(done 7 Nov 2026)*
  - [x] 2.11c **Suspend a team** (C1–C5, chairman only): FA team page ⋮ › Suspend team… with a reason, ending on a date or when the chairman lifts it (after the FA board meets the club); red banner on the FA page (Lift suspension) and on the team's Squad tab; "Suspended" on the Teams list; Lift with why (fine paid, bond signed, board decision, other + note); history on the FA page; while in force the rules refuse adding or editing players, profile edits and change requests (later: team sheets); bell notes for the team. 285 rules tests *(done 7 Nov 2026)*

- [x] 2.12 **FA dashboard** (Home tab): totals of teams and players, players by competition and position group, waiting reviews; later referees, cards and suspensions. Live from the lists the FA app already streams (no extra reads); count queries when the league reaches thousands of players *(done 7 Nov 2026)*
  - [x] 2.12a **Home tab and Needs you** (mockup 2.12-fa-dashboard): Home is the FA's first tab (Home · Teams · Players · More) and where the FA lands after signing in; blue header with greeting, date, season, team and player registration open or closed, and the bell; "Needs you" lists only what is waiting (new teams, team changes, players to approve, waiting for screening with the next screening day, payments to confirm, corrections sent back), each row opens its screen; "All caught up" when nothing waits. Live, from the same streams as the tab badges (no extra reads). No rules changes, 285 rules tests *(done 7 Nov 2026)*
  - [x] 2.12b **League at a glance and charts:** tiles for teams (both competitions, suspended), players approved (+ this week), fees collected (every FA official), squads ready (Division teams with at least the matchday squad from League settings, 16); each tile opens its screen with the way back to Home; players by competition (Division, U17, U15, U13) and by position (GK, DEF, MID, FWD in Ghana colours; Division | Juvenile); Season stats card (switched off until match reports); Coming later (fixtures, referee appointments, cards, player suspensions). Live, no pull to refresh ("Live · updates by itself"); numbers count up and bars grow once (none when the phone asks for less motion). New layout test `test/dashboard_smoke_test.dart` (phone 320 / 360 and laptop, light and dark). 285 rules tests *(done 7 Nov 2026)*

> **Flutter and React:** the Flutter app (Android + web) is the working tool for the FA, team admins and referees. The React website (by a colleague) is the public face for fans: fixtures, results, table, news and approved teams. Both use the same Firebase project, `DATA_MODEL.md` and security rules. *(To be agreed with the colleague.)*

> **Before Phase 3:** go through GEDFA's answers to the open questions (Section 10) and a friend's suggestion, and update the roadmap and data model. *(Answers received 27 Oct 2026: see DATA_MODEL Section 7. They became 2.13 and 2.14.)*

- [ ] 2.13 **Registration update** from GEDFA's answers (mockups R1–R8 on the design canvas). Steps: Club details › Club status › Officials › Kits › Colours › Payment, then Review
  - [x] 2.13a **Club status and officials:** already in the district or a new club (last league + letter to the chairman, PDF); optional licence (photo or PDF); logo required; officials 2 required + up to 5, "Other" with a typed role; FA review shows the letter and licence *(done 27 Oct 2026)*
  - [x] 2.13b **Kits and colours:** upload photos (shirt › shorts › socks, cropped and shrunk on the phone, preview) or design the kit; Team colours step (home and away, main and second, suggested from the designed kits); clubs in both competitions set Division and Juvenile kits apart; FA review shows photos and colours. 166 rules tests *(done 27 Oct 2026)*
  - [x] 2.13c-1 **Season fee, registration and FA review:** Payment step (GH₵ 1,000, MoMo / bank, cash, or paid before; in parts); the FA confirms each payment with the green tick (receipt `GEDFA-2026-0001`, …), marks it "not found" with a reason, or records cash; Approve only after a confirmed payment (also in the rules). 187 rules tests *(done 27 Oct 2026)*
  - [x] 2.13c-2 **Season fee, after approval:** team More › Season fee (R8: confirmed of GH₵ 1,000, what's left, every payment with receipt or reason, Add a payment); FA More › Season fees (collected, to confirm, Owing / Paid, by team) and a team's fee with "Send reminder"; bell: payment confirmed / not found / reminder for teams, payment sent for the FA. 195 rules tests *(done 28 Oct 2026)*
  - Original plan for 2.13c: GH₵ 1,000 every season, MoMo 0244-\*\*\*-\*\*\* (number to come), paid in parts; MoMo/bank, cash, or paid before the app; the FA confirms each payment (green tick) or marks it "not found" with a reason; receipt number per confirmed payment (`GEDFA-2026-0014`); Approve after the first confirmed payment; team Season fee screen; FA "Send reminder" (automatic push every 3 days comes with phone push before the pilot)
  - [x] 2.13d **League settings:** FA › More › League settings: team and player registration switches (by hand; history and a bell note for every official), squad 30 / matchday 16 / subs 5 / fewest players 7, season, fee and MoMo number (chairman only), tie-breakers as the Premier League; closed registration hides the buttons and the rules refuse it. 205 rules tests *(done 30 Oct 2026)*
- [x] 2.14 **Juvenile** (mockups J1–J6): age group = season start year − birth year (U13 / U15 / U17); play up allowed (GFA limits on the team sheet), overage blocked; parent or guardian required
  - [x] 2.14a **Juvenile players:** Squad › Juvenile with U13 / U15 / U17 tabs; add a player per age group (date picker, age-group box, "Register in" own group or older, parent or guardian); "waiting for screening"; jersey numbers per age group; the same child may also play Division; Juvenile kept out of the FA Players tab. 214 rules tests *(done 30 Oct 2026)*
  - [x] 2.14b-1 **FA sees juvenile players** (J2, J5): "Register in" follows the tab the club came from and only moves a child UP when too old (Isaac, 30 Oct 2026); FA Players tab gets a Division | Juvenile switch (waiting per age group, teams with age-group chips, a team's children with photo, date of birth and parent); bell note "N juvenile players from X". Badge stays Division only. 215 rules tests *(done 2 Nov 2026)*
  - [x] 2.14b-2 **Screening days** (J3): FA › More › Juvenile screening; saving announces it to Juvenile teams ("Bring: …" only if the FA typed it); cancelling tells them too, with an optional reason; a blue card on their Squad tab until the day after; "Next screening" strip on Players › Juvenile. 220 rules tests *(done 2 Nov 2026)*
  - [x] 2.14c **Screening decisions** (J4): from a screening day (opens at its start time), one child after another ("3 of 41", Skip): pass in their group or an older one (moved up, no second screening, jersey moves along) with a `GJ26-0001` ID, or "not eligible for Juvenile" with a reason (can't be edited or added again in any juvenile group). Team bell: "N juvenile players passed" / "N children not eligible". The FA can open any child from Players › Juvenile (read only). 231 rules tests *(done 3 Nov 2026)*
  - [x] 2.14d **Screening review** (J3, J4, J6): decisions only on a started screening day (checked by the rules too); "Needs correcting" back to the team; possible duplicates; "Screen player" from a child's page; countdown from the moment a day is saved. 236 rules tests *(done 3 Nov 2026)*

### Phase 3 — Fixtures, team sheet builder and PDF
Mockup `3.0-fixtures-and-sheet.html` (approved 8 Nov 2026).
- [x] 3.0a **Fixtures by hand**: FA Fixtures tab (Home · Teams · Players · Fixtures · More) with Division | Juvenile and U13 / U15 / U17, matches by matchday, postponed, cancelled; Add one match (F2) with the home ground filled in, warnings (a team twice on a matchday, a ground used that day, a suspended team) and the kit check; Change a match (E1, swap home and away, why); Postpone with a new date now or later (E2), Set the new date, Cancel with a reason; Kits for a match (K1: home keeps its home kit, the app picks the away and goalkeeper kits, the FA can change them); team Fixtures tab (Squad · Fixtures · Profiles · More) with the next match card and "Team sheet due in …" (F4). Bell notes for both teams. 298 rules tests, 25 Dart tests *(done 8 Nov 2026)*
- [x] 3.0b **Make the season** (G1, G2): round robin by the circle method (home and away or once; fair home and away, no rematch within 2 matchdays), weekends with Sat and Sun or Sat only, kick-off, weeks off, juvenile one age group at a time, teams left out; draft with summary, warnings (shared grounds moved to Sunday, a team resting, kit clashes to choose), tap a match to swap or change date, time or ground, Draw again, Save the draft for later (FA only) and Continue; Publish 3 matches per save with progress, safe to retry, one bell note per team. 301 rules tests, 78 Dart tests *(done 8 Nov 2026)*
- [ ] 3.0c **Competitions and cups** (mockup `3.0c-competitions.html`, approved 8 Nov 2026)
  - [x] 3.0c1 **Competitions and a new cup or gala** (C1, C2, C2b): Competitions from the Fixtures tab (🏆): the leagues (tap one to go back to it), cups and galas with what to do next; New cup: who plays (Division, U13, U15, U17, Open), every approved team in by default, the suggested format (knockout with a first round and byes, or groups then knockout), one match or home and away (no away goals, the final one match), level at the end (penalties, extra time then penalties, replay with one-match rounds), the bracket fixed from (the start, round of 16, quarter-finals, semi-finals), seeding with pots; New gala: ground, days, first kick-off, time between kick-offs and the timetable it makes (warns when it doesn't fit). New `cups` collection. 305 rules tests, 111 Dart tests *(done 8 Nov 2026)*
  - [x] 3.0c1b **A cup's page** (C7, C8, C9): tap a cup in Competitions; what the first draw is, how it's played (with Change), its history (who and when, newest first); ⋯ menu: Change (the same form, filled in, only before the draw), History, Delete (any time; everything goes). New `cups/{id}/history`. A new cup opens its page after saving. 310 rules tests, 134 Dart tests *(done 8 Nov 2026)*
  - [x] 3.0c1c **Postpone** (C10, C11): a league from the ⋯ on its row in Competitions (every match not played yet moves by the same number of days, at the same time, weeks off included; postponed ones without a date and cancelled ones stay; 3 matches per save with a progress bar, Try again carries on where it stopped; a history line on each match; one bell note per club with its next match and the reason); a Gala from its ⋯ (its days move, a history line, every club told, one batch). A cup's Postpone waits for the draw (3.0c2): its matches have no dates before. The league line says "starts Sat 5 Dec" until a match is played. No rules change. 314 rules tests, 138 Dart tests *(done 9 Nov 2026)*
  - [x] 3.0c1d **Finish a stopped postpone** (C12 to C15, mockup approved 9 Nov 2026): a league's postpone is saved first as a job (`postponeJobs/{competitionId}`: days, reason, each match's old and new kick-off) and ticked off in the same batch as each match; if it stops, Try again or Later (C12); Competitions shows "Division League: postponing stopped" with progress, who, when, why and **Finish** (C13); the league line says "postponing: 42 of 306 moved"; Postpone stays off until it is finished (C14); Finish moves only what is left (C15); the clubs are told once, when finished, and the job goes. No undo (Isaac). New FA-only rules. 318 rules tests, 144 Dart tests *(done 9 Nov 2026)*
- [x] 3.0f **Notifications and Back** (mockup `3.0f-notifications-and-back.html`, N1–N3, approved 9 Nov 2026)
  - [x] 3.0f1 **One note at a time** (N1, N2): a tap marks only that note (or announcement) read (`readMarks/{uid}.reads`: note ID → the time read; a grouped note that changes is unread again, with a gold line saying so) and opens **Notification details**: icon, title, "From GEDFA" or the team, time, the full text with every name one per line, "Status: Read", and a bottom button named after where it goes ("Open Squad", "Review players"…). Mark all read still marks everything. 321 rules tests, 152 Dart tests *(done 9 Nov 2026)*
  - [x] 3.0f2 **Back** (N3), with **the back arrow** (Isaac, 8 Nov 2026): `context.open` opens full-screen pages and pages of the same tab on top (push); another tab, or a tab's page from a full-screen page (a note's details), switches with go and carries `back=` (go_router cannot push a tab's page over a full-screen one: it crashes), so ← goes back to the note or tab it came from. `context.goBack` / `AppBackButton`: ← goes to `back=`, else the page underneath, else the tab's main screen; the phone's Back does the same. On the web a pushed page shows its own address, so a refresh keeps it. 60 of the 75 `context.go` changed; the 15 left are sign-in and registration flows, the Home links (`from=home`), the Division / Juvenile switch, the end of a flow (Publish, Invite) and the screening days' own Back. 321 rules tests, 157 Dart tests *(done 9 Nov 2026)*
  - [x] **Juvenile side names** (mockup `juvenile-side-names.html`, JS1–JS6, approved 9 Nov 2026): the club's name with "B" or its own name (and short name); clubs already in both competitions ask the FA
    - [x] JSa **Show the name** (JS5, JS6): a club in both competitions plays its juvenile matches as "Royal Unique FC B" / "RUF B" (or its own juvenile name, once it has one); a "B" side's crest has a thin gold ring; Squad › Juvenile shows the juvenile name. Every match save re-reads the teams, so a re-saved match picks it up. Rules check the name (`sideNamesOf`). 324 rules tests, 165 Dart tests *(done 9 Nov 2026)*
    - [x] JSb **Registration** (JS1, JS1b, JS2): ticking both competitions shows "Your juvenile side's name": "Royal Unique FC B" (default, gold ring in the preview) or its own name and short name (green tick when fine; not the club's name or short name; checked online on Next, and again when sending); an own name is reserved in `teamNames` in the same batch; Review shows "Juvenile side"; the FA sees "Juvenile side name" with an "Own name" or "B" tag in Club details; approval copies it to the team. 334 rules tests, 171 Dart tests *(done 9 Nov 2026)*
    - [x] JSc1 **Ask the FA** (JS3, JS3b, JS4): Team profile › "Juvenile side name" row (clubs in both) with Ask to change; Ask the FA to change has a "Juvenile side name" chip: Now, "<name> B" or its own name and short name, Why (optional); "Add Juvenile" asks the juvenile name too ("B" by default); the FA sees the crest and name now → the new one, approves (the name reserved for the club) or rejects with a reason; the club's bell "Change approved: Juvenile side name → …". 348 rules tests, 177 Dart tests *(done 9 Nov 2026)*
    - [x] JSc2 **Renamed teams in matches** (mockup `jsc2-renamed-teams.html`, R1–R5, approved 9 Nov 2026): after the FA approves a new club name, short name or juvenile side name, every match of that side (played, upcoming, postponed, cancelled; Division and juvenile; a "B" side follows its club) shows the new name. A new name adds the gold "Previously <old name>" pill (with the team's mini crest) in the top-right corner of the row and of match details, for everyone; a tap opens a small note under it (which side, the old name, the day). The Approve dialog says how many matches change; "Renaming matches… 12 of 34"; if it stops, the FA's team page shows "Finish renaming". 355 rules tests, 189 Dart tests *(done 9 Nov 2026)*
  - [ ] 3.0c2 **The draw, live** (C3, C3b): balls from the pot, byes, pots when seeded; Draw again; Save the draw writes the matches and tells both clubs
  - [ ] 3.0c3 **The bracket** (C4, C4b) and **who went through** (C5); the team's "win and you play" (C6)
  - [ ] 3.0c4 **Groups, then knockout** (group tables; mockup first)
  - [ ] 3.0c5 **Two legs and replays** (aggregate, a replay linked to the first match; mockup first)
- [ ] 3.0d **Match details and the next matchday card**
  - [x] **Match details** (F5, F6), done early at Isaac's request: stadium-night header (pitch lines, gold floodlight glow), crests, kick-off, countdown; Match info (date, kick-off, ground with Directions to Google Maps, competition and matchday, match length and play-up rule, team sheets due, status and reason); What changed (the match history); kits (outfield and goalkeeper); team sheets; officials (Phase 4). Tapping any match opens it, for the FA and teams; the FA manages the match from its ⋯ button. 87 Dart tests *(done 8 Nov 2026)*
  - [ ] The next matchday card: countdown and matches sliding every 5 seconds, on Home and Fixtures, Division and Juvenile (D1, J1)
- [ ] **Team dashboard** (mockup `td-team-dashboard.html`, TD1–TD4 and TF1–TF2, approved 10 Nov 2026); the referee's Home (RD1) is built with 3.5
  - [x] TDa **Home tab**: teams land on Home (Home · Squad · Fixtures · Profiles · More); header (crest, greeting, status, competitions, season, player registration, bell); Division | Juvenile switch with age group chips (clubs in both, matches only, remembered); Next match (crests, kick-off, "in 4 days", venue, our kit, Previously pill, Postponed; Match details, Kits); Coming up (next 2); Needs you (players sent back, a correction asked, screening day, fee owed, fewer than 18 approved, red below 7); All caught up. `/team/home`, `team_dashboard_screen.dart`, logic in `dashboard/domain/team_home.dart` (19 tests), layout test `test/team_dashboard_smoke_test.dart`; the switch is remembered on the phone (`matchViewProvider`). No rules change, 355 rules tests, 213 Dart tests *(done 10 Nov 2026)*
  - [x] TDb **Squad at a glance** (Division players of 30, match-ready of 18 with "Can play" from 7, Juvenile by age group, matches this season), Season fee (Paid in full), Waiting on the FA, From GEDFA, Coming later, Live line; laptop layout; layout smoke test. Match-ready for a juvenile-only club shows its weakest age group. The FA's `GlanceTile` and `ComingLater` are shared. No rules change, 355 rules tests, 218 Dart tests *(done 10 Nov 2026)*
  - [x] TDc **Fixtures tab**: the same Division | Juvenile switch and age chips, List | Calendar; the month calendar (‹ ›, opponent crest on match days, gold ring for a B side, trophy for a Gala; blue League, gold Cup, purple Gala; tap a day for its matches), also on Home under Coming up. A day with one match opens it; several are listed under the calendar ("+1" on the crest). League = `competitionId` ending in `-league`, else the cup (`cups.kind` gala or cup). `fixtures/domain/match_calendar.dart`, `widgets/match_calendar_card.dart`. No rules change, 355 rules tests, 229 Dart tests *(done 10 Nov 2026)*
- [ ] **JA Juvenile age groups** (GEDFA, 10 Nov 2026; mockup first): a club enters 1, 2 or 3 age groups (`juvenileAgeGroups`) at registration and by a change request the FA approves, only before the season is published; Make the season uses them; no children outside its groups (rules and tests); same juvenile fee
- [ ] **JF Fees by competition** (GEDFA, 10 Nov 2026; mockup first): a Division and a Juvenile affiliation fee (one Juvenile fee whatever the age groups; a club in both pays both) and a referee fee for each competition, amounts in League settings, every fee paid in instalments; the team's Season fee and the FA's Fees screen show each one
- [ ] 3.0e **Posters**: one match or a matchday, square or tall, three styles, GEDFA logo (transparent PNG), Save to photos and Share (P1–P4)
- [ ] 3.1 Team sheet builder: approved players only (18 = 11 + 7 on the bench, 7 at least, from settings), captain, vice-captain, goalkeeper, GFA play-up limits (mockup `3.1-team-sheet.html`)
  - [x] 3.1a1 **Squad lists** `squads/{teamId}_{group}` (approved player IDs per competition and age group): the FA's approval and screening pass add the player in the same transaction, a team edit back to pending takes them off (rules), FA Repair in League settings for players approved earlier. `players/data/squad_list.dart`. 369 rules tests, 234 Dart tests *(done 10 Nov 2026)*
  - [x] 3.1a2 **Players step and Save** (MS2, MS3): `teamSheets/{fixtureId}_{teamId}`, approved players by position (juvenile: the age group, then playing up), 11 | Bench, counters, checks (7 to 11 starting, a goalkeeper, bench only with 11, at most 7), injured players with a warning, C / VC, Save until the lock 1 hour before kick-off (in the rules); Match details › Team sheets: Make team sheet / Change, saved or not for the FA. Squad list Repair only in debug builds. `features/team_sheets/`. 387 rules tests, 252 Dart tests *(done 10 Nov 2026)*
  - [x] 3.1b **Roles and numbers** (MS4, MS4b, MS4c): step 2 of the sheet; captain (must start) and vice-captain from Profiles, changeable for this match; any starter as goalkeeper (the only registered GK starting is picked for you); shirt numbers for this match with a number picker (usual number by default, 1–99, clashes in red); team officials ticked (manager and head coach locked); Save on step 2 until 3.1c adds Check. Rules check all of it. Make sheet on the Fixtures card fixed. 395 rules tests, 270 Dart tests *(done 11 Nov 2026)*
  - [x] 3.1c **Check step and sheet lines** (MS1, MS1b, MS5, MS7): step 3 Check (the sheet as it will look with today's kit, C / VC / GK, "usual 17", officials; the checks; Save); the Home Next match card's sheet line (Make team sheet, or View sheet and Change), Needs you "Team sheet for Saturday" from 2 days before (red on the day), the Fixtures tab card (saved / Change / View) and row tags ("Sheet saved", "Sheet due Sat" within a week), Match details View after the lock; "Use last sheet"; laptop (840 px and wider): players left, the sheet, roles and checks right. 396 rules tests, 285 Dart tests *(done 11 Nov 2026)*
  - [x] 3.1d1 **Juveniles in the Division**: the club's list of up to 7 (Squad › Division card with U13 / U15 / U17 counters and Remove, the picker with limits, rules, bell note to the FA; at most 1 U13 and 3 U15) (mockup DJ1, DJ2). `squads/{teamId}_divisionJuveniles`. 405 rules tests, 293 Dart tests *(done 11 Nov 2026)*
  - [x] 3.1d2 **The Division sheet takes the 7** (section "Juveniles (Division list)" with age pills, pills on the Check step, DJ3, DJ4) and the **juvenile play-up limits** (U17 match: 1 U13 and 5 U15, counters, "U13 limit reached" lock, MS6); a corrected juvenile leaves the Division list in the same save. Fixed: U17 sheets were over the rules' lookup limit. 409 rules tests, 297 Dart tests *(done 11 Nov 2026)*
  - [ ] 3.1e Player suspensions by the FA (a number of matches, a reason); suspended players can't be picked
- [x] 3.2 **Lock and visibility**: the lock 1 hour before kick-off (in the rules since 3.1a2); the sheet keeps a copy of each picked player; **View** in Match details opens a team's sheet read only (`TeamSheetViewScreen`, the MS5 look): the FA any time, the opponent from the lock. The referee and commissioner come with 3.5. 411 rules tests, 301 Dart tests *(done 11 Nov 2026)*
- [ ] 3.3 The paper sheet as a PDF: the team's real kits top-left, captain's signature, QR code to check it (V1)
- [ ] 3.4 Formation on a pitch (optional)

> **Before the pilot:** bundle fonts in the app (offline-safe), set up dev/prod switching (flavors), enable App Check, create the first FA Admin on prod, deploy rules to prod, set Storage CORS and Hosting on prod, set up Firebase App Distribution for the Android APK, consider weekly Firestore backups on prod, **phone push notifications** (Firebase Cloud Messaging, grouped the same way), deploy `firestore.indexes.json`.

> **UI and UX refresh before the pilot** (Isaac, 7 Nov 2026): after Phase 3, a modern look with motion and animations, one screen group at a time, mockups first, never mixed with feature work. After the pilot, a second refresh from the clubs' feedback.

> **PILOT MILESTONE:** registration, approval, team sheets and FA announcements usable. Pilot with the FA and one or two teams.

### Phase 4 — Fixtures and referee match reports
- [ ] 4.1–4.5 As before: fixtures and referee assignment, referee view, report form (draft works offline), signed sheet photo, FA approval
- [ ] **Season records** (Isaac, 8 Nov 2026), one screen for everyone (FA and teams): standings and stats of this season and **past seasons** (top scorers, assists, clean sheets, best attack and defence …), and the **winners of every cup and Gala** by season; a cup's page shows who won it before. Mockup first

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
| 11 Nov 2026 | 3.2 done: the FA views any saved team sheet, the opponent from the lock; sheets carry copies of the players. Steps left listed in a table in CLAUDE.md (Isaac). 411 rules tests, 301 Dart tests |
| 11 Nov 2026 | 3.1d2 done: Division sheets take the club's juveniles with pills; U17 sheets: 1 U13 and 5 U15 at most; U17 sheets saved again (they were over the rules' 10-lookup limit since 3.1a2). 409 rules tests, 297 Dart tests |
| 11 Nov 2026 | Fix (Isaac): the FA's note for juveniles in the Division said "updated their profile" and opened the team. New note kind `divisionJuveniles` ("Royal Unique FC: juveniles in the Division", one line per change: "+ Kojo Brew (U15)", "− Yaw Sam (U17)"), opening the team's players page, which now lists the club's 7 (read only). 406 rules tests |
| 11 Nov 2026 | 3.1d1 done: a club in both competitions names up to 7 juveniles for the Division on its Squad tab (1 U13 and 3 U15 at most), checked by the rules; the FA is told. 405 rules tests, 293 Dart tests |
| 11 Nov 2026 | 3.1d planned (Isaac): juveniles in the Division, up to 7 named by the club (1 U13, 3 U15 at most), mockup `3.1d-division-juveniles.html` (DJ1–DJ4) for approval; 3.1d1 the list, 3.1d2 the sheet and the juvenile play-up limits |
| 11 Nov 2026 | Fix (Isaac's test on dev): the theme's buttons are full-width (`Size.fromHeight`), so a button in a row broke the layout on the web: Match details had no Make team sheet / Change (so matches under Coming up looked impossible), the sheet's search bar collapsed and Use last sheet vanished, and Make the season's kick-off button too. Buttons in rows get a small minimum size; Match details shows View and Change; screen tests now use the app's theme. 286 Dart tests |
| 11 Nov 2026 | 3.1c done: the Check step, sheet lines on Home, Needs you, Fixtures and Match details, Use last sheet, and the laptop layout. 396 rules tests, 285 Dart tests |
| 11 Nov 2026 | 3.1b done: roles and numbers on the team sheet (captain, vice-captain, goalkeeper, shirt numbers for this match, officials), checked by the rules. Isaac: sheets open any time until the lock (GPL regulations only set a latest time, 1 h 20 before kick-off). 395 rules tests, 270 Dart tests |
| 10 Nov 2026 | 3.1a2 done: the team picks its 11 and bench from approved players and saves, until 1 hour before kick-off (the lock is already in the rules; 3.2 adds who else sees it). Isaac: the squad list Repair only in debug builds. 387 rules tests, 252 Dart tests |
| 10 Nov 2026 | 3.1a1 done: squad lists for team sheets (one rules lookup instead of 18), kept exact by the rules at approval, screening and team edits; FA Repair. 3.1a split into 3.1a1 (lists) and 3.1a2 (Players step and Save). 369 rules tests, 234 Dart tests |
| 10 Nov 2026 | 3.1 mockup drawn (`3.1-team-sheet.html`, MS1–MS7, MS4b–MS4c). Isaac: one Save button, editable until the lock; bench only with 11 starting; injured players with a warning; captain starts; any starter in goal; player suspensions as 3.1e; cup sheets 1 hour before (Gala 20 min); order 3.1a–3.1e agreed. Shirt numbers: clubs lack 30 jerseys, so a number for this match on the sheet, the registered number kept as the usual one (approved) |
| 10 Nov 2026 | Isaac, for 3.1: the other team gets one extra substitute too; a goalkeeper in the starting 11 is required |
| 10 Nov 2026 | Isaac, for 3.1: the extra substitute is for head injuries only, in every competition; any number of goalkeepers, the bench never more than 7 |
| 10 Nov 2026 | Calendar style (Isaac): a soft blue wash, the Ghana stripe on top and the GEDFA logo as a faint one-colour watermark (ink 6% light, white 9% dark) behind the days; `assets/images/gedfa_logo.png` committed (transparent, also for the posters). 229 Dart tests |
| 10 Nov 2026 | Isaac, for 3.1: 7 on the bench and 5 may come on; a second goalkeeper on the bench; juvenile the same (play-up limits). Asked of GEDFA: an extra substitute for an injury (the Laws allow one only for a concussion, if the competition opts in, and the other team gets one too). The 3.1 mockups are drawn in the next conversation |
| 10 Nov 2026 | TDc done, **team dashboard finished**: Division / Juvenile switch and age chips on the team's Fixtures tab (the same choice as Home), List / Calendar, the month calendar on Fixtures and Home. Isaac: order now **3.1 team sheets next (mockup first)**, then JA, JF and the rest in the agreed order. 355 rules tests, 229 Dart tests |
| 10 Nov 2026 | TDb done: Squad at a glance (Division players of 30, Match-ready of 18 / can play from 7, Juvenile by age group, matches this season), Season fee (Paid in full, payments waiting, Add payment, History), Waiting on the FA (players, children without a screening day, change requests, payments, a correction sent back), From GEDFA (pinned announcement, unread notes), Coming later; laptop: tiles 4 in a row, then matches and Needs you on the left, fee, waiting and From GEDFA on the right. 355 rules tests, 218 Dart tests. Next: TDc |
| 10 Nov 2026 | TDa done: teams land on Home (Home · Squad · Fixtures · Profiles · More), header with crest and tags, Division / Juvenile switch with age chips, Next match ("in 4 days", kit, Previously pill, Match details, Kits), Coming up, Needs you; the FA header is shared (`DashboardHeader` takes a label, crest, subtitle and tags). The kit shows its slot name ("Home kit") with a small kit drawing, not colour names. 355 rules tests, 213 Dart tests. Next: TDb |
| 10 Nov 2026 | Team dashboard mockup approved (TD1–TD4, TF1–TF2; RD1 referee preview for 3.5). Isaac: Home first; match-ready = 18, can play from 7; team sheet line in 3.1; a Division / Juvenile switch on Home and Fixtures and a month calendar (League, Cup, Gala) on both. Sliding matchday card stays 3.0d (parked). GEDFA: a club picks 1 to 3 juvenile age groups, only before the season is published, same fee, no children outside them: new step JA. Order: TDa, TDb, TDc, then JA. GEDFA fees: a separate Juvenile affiliation fee, a referee fee for each competition, all in instalments: new step JF |
| 9 Nov 2026 | Isaac: a spelling correction stays as built (Finish renaming, with the pill). Next, in a new conversation: **dashboards for teams and referees** (the FA has one since 2.12), so everyone on the app has a summary of what they need to know; mockups first |
| 9 Nov 2026 | JSc2 done: renamed teams in matches (R1–R5), juvenile side names finished. Isaac's change to the mockup: the pill opens a small note in place (no pop-up), with the team's mini crest in the pill. Known: an FA edit to a match made before its renaming finishes takes the new name without the pill; an FA spelling correction (2.11a) leaves the matches for Finish renaming (which adds the pill). Rules changed (`fixtures`): Isaac deploys to dev. Next: Team admin dashboard (mockup first) |
| 9 Nov 2026 | Isaac's answer for JSc2: a new club name or juvenile side name renames every match of that side, played and upcoming, Division and juvenile, with "Previously <old name>" in the top-right corner, seen by everyone |
| 9 Nov 2026 | JSc1 done: ask the FA for a juvenile side name (JS3, JS3b, JS4) and the name in "Add Juvenile". Built in the existing Ask the FA to change screen (a chip, like the other kinds) instead of the bottom sheet drawn in JS3b, and as a row in the profile's Name and logo card. "Why" is optional for this kind only (JS3b). Rules changed (`teamChanges`, team update, `teamNames`): Isaac deploys to dev. Next: JSc2 |
| 9 Nov 2026 | JSb done: juvenile side name at registration (JS1, JS1b, JS2). The picker sits under the Competitions cards on the Club step (where the app has them; the mockup drew Competitions alone). New widgets `juvenile_name_picker.dart` (reused in JSc) and `b_side_ring.dart`. Rules changed (`teamRequests`, `teamNames`, team create): Isaac deploys to dev. Next: JSc ask the FA |
| 9 Nov 2026 | Isaac tested JSa: all good. Answer: a Juvenile-first club that adds Division (same name) gets "B" on its juvenile sides too, as built |
| 9 Nov 2026 | JSa done: juvenile side names shown in matches ("Royal Unique FC B", "RUF B", gold ring on the crest) and on Squad › Juvenile. Found by a new test: the extra name check pushed changing a juvenile match over the rules' 1000-expression limit; fixed by looking up each side's kits once. Juvenile matches made before keep the plain club name until they are next saved (or renamed in JSc). Rules changed: Isaac deploys to dev. Next: JSb registration |
| 9 Nov 2026 | Fixes (found by Isaac): (1) More › League rules and Help froze the app: their "Coming soon" page is pushed by hand, and `GedfaAppBar` looked up `back=` with `GoRouterState.of`, which never ends on such a page; it now looks only on go_router pages. (2) The FA's bell ← landed on Teams: the bell's address is under Teams. The bell now remembers where it was opened (`bellOriginProvider`, `BellBackButton`) and its ← goes there; an announcement from the FA's bell has its own full-screen page (`/admin/notifications/announcement/:id`), so it never touches the More tab; a tab opened from a note with `back=` starts fresh when picked in the tab bar (like tabs opened from Home). 159 Dart tests |
| 9 Nov 2026 | Fix (Isaac): an announcement in the FA's bell did not open. The bell pushed the FA's announcement page, which is in the More tab, over the bell (a full-screen page): the go_router crash found in 3.0f2. The bell now uses `context.open` (switches with `back=`, ← back to the bell) |
| 9 Nov 2026 | Isaac tested 3.0f (notifications and Back): all good |
| 9 Nov 2026 | Juvenile side names mockup drawn (JS1–JS6) and Isaac's answers: short name "RUF B"; own juvenile names reserved; the name asked when adding Juvenile; after approval every juvenile match shows the new name, played ones too, with "Previously …" like a renamed team. Build in the next conversation |
| 9 Nov 2026 | 3.0f2 done: Back (N3) and the back arrow. Found by a test: go_router crashes ("Duplicate GlobalKey") when a tab's page is pushed over a full-screen page, so those switch with go and `back=`. Pushed pages keep the bottom tab they were opened from lit. No rules change. 3.0f done. Next: juvenile side names (mockup first) |
| 9 Nov 2026 | 3.0f1 done: a tap marks only that note read and opens its details (N1, N2). 3.0f split in two: 3.0f1 notifications, 3.0f2 Back (N3). The details button still switches tab as the tap used to; 3.0f2 makes it open on top with ← back to the note. Small change from the mockup: the gold line says "New since you last read it" (no number of new names: only the time is kept). Rules changed (`readMarks.reads`): Isaac deploys to dev. Next: 3.0f2 |
| 9 Nov 2026 | 3.0c1d done: finish a stopped postpone (mockups C12 to C15, approved). Isaac: the clubs are told only when it is finished; a stopped postpone can only be finished, not undone. Rules changed (new `postponeJobs`): Isaac deploys to dev. Next: the back arrow |
| 9 Nov 2026 | 3.0c1c done: postpone a league (C11) or a Gala (C10), the clubs told with the reason. Isaac: a Gala's clubs are told even before the draw. No rules change (the FA could already move a match into the future and change a Gala before the draw). Known: if the FA stops after a lost connection, the matches already moved stay moved (Try again finishes the same plan). For 3.0c2: a drawn cup's matches move with `postponeMatches`, and the `cups` rule must let a drawn Gala's days move. Next: 3.0c1d (finish a stopped postpone), then the back arrow |
| 8 Nov 2026 | 3.0c1b done: a cup's page (C7), ⋯ Change / History / Delete (C8, C9), `cups/{id}/history`. GEDFA's answers: delete at any time and everything goes; postpone a cup, Gala or a league's start (3.0c1c, mockups C10, C11); Pot 1 gets the byes first; juvenile "B"; Gala sheets 20 minutes before kick-off. New from Isaac: the back arrow on every tab opened from another tab; Season records (past standings, stats and cup winners, for everyone). Order: 3.0c1c, back arrow, juvenile names, 3.0c2. Rules changed (`cups`, history): Isaac deploys to dev |
| 8 Nov 2026 | 3.0c1 fixes after Isaac's test and GEDFA's answers: "Gala" with a capital in the app; minutes between kick-offs typed (30–240); the final is always one match (switch removed, `finalOneMatch` dropped); seeding text: the FA ticks Pot 1; match details countdown with seconds (FA and teams). Next: cup page with edit, delete and history (mockup first); juvenile side names (registration, mockup first) |
| 8 Nov 2026 | 3.0c1 done: Competitions (C1), New cup (C2) and New gala (C2b), new `cups` collection. Groups of 3 to 5 clubs (6 only when needed: 11 clubs make 6 and 5, never a group of 2). Gala: last kick-off 4:30 pm and a free slot between a club's matches (app rule until GEDFA answers). Open cups use the U17 sides until GEDFA answers. Rules changed (`cups`): Isaac deploys to dev |
| 8 Nov 2026 | 3.0c cup answers (GEDFA via Isaac): draw round by round until the bracket is fixed; random byes; optional pots from the standings; no away goals; groups 3/1/0 then goal difference, goals scored, head-to-head; every approved team; open cups mixing Division and juvenile sides; **galas** (one-off straight knockout, one match per tie). 3.0c split into c1 (competitions, new cup or gala), c2 (the draw), c3 (bracket, who went through), c4 (groups), c5 (two legs, replays). Mockup `3.0c-competitions.html` (bracket like a World Cup draw) |
| 8 Nov 2026 | Match details (F5, F6) done ahead of 3.0c (Isaac): match info with Directions, what changed, kits, team sheets, officials. Next: 3.0c in a new conversation |
| 8 Nov 2026 | 3.0b done: Make the season (round robin, calendar, draft, publish). The first home/away rule was unfair (a team could be home 19 times in a row); measured three rules and chose one with at most 3 in a row and fair totals, tested for 2 to 20 teams |
| 8 Nov 2026 | 3.0a fix after Isaac's test on dev: goalkeepers clashed too often (referee assumed black, the two keepers had to differ, a too-strict colour table). Now: clash = CIEDE2000 colour difference below 20.5; goalkeepers only against outfield shirts (Law 4), as a warning. The FA team page uses the team ID saved at approval. Still open: kits showing white on some dev teams (data needed). Ideas for after Phase 3 (Isaac): a **team dashboard**; **colours for every photo kit** (third, goalkeepers), suggested from the photo (mockup first); the referee's shirt colour suggested at appointments (Phase 4) |
| 8 Nov 2026 | 3.0a done: fixtures by hand, change, postpone (new date now or later), cancel, kit check with GEDFA's rule, FA and team Fixtures tabs. Each match carries a copy of both teams and their kits (teams can't read other teams); every save re-copies them. 298 rules tests; kit check and fixtures layout tests (25 Dart tests) |
| 8 Nov 2026 | Mockup 3.0 approved by Isaac. Cup answers: the FA picks draw rules (penalties, extra time then penalties, replay) and one or two legs per cup; normal qualification; fully random draw; a juvenile cup per age group. Steps 3.0a–e (fixtures and changes, Make the season, competitions and cups, match details and the matchday card, posters) |
| 8 Nov 2026 | Fixtures plan (mockup 3.0 v4): competitions with an automatic cup draw (knockout or groups then knockout) and a bracket; next matchday card with a live countdown and matches sliding every 5 seconds (Home and Fixtures, Division and Juvenile); change any match; postpone with a new date. GEDFA: home team keeps its home kit; juvenile photos only for people signed in for the match |
| 7 Nov 2026 | Phase 3 answers: simple fixtures move first (new 3.0); team sheet due 1 hour before kick-off; the FA sees and gets every sheet; GFA play-up limits (1 U13 and 5 U15 in a U17 match); paper sheet as a standard match sheet until GEDFA's copy arrives. Mockup 3.0 (fixtures + paper sheet draft) made |
| 7 Nov 2026 | 2.12b fix (Isaac, web): the glance tiles overflowed at the bottom (Poppins loads late on web, numbers change size while counting). Tiles and Coming later boxes now have fixed parts (one-line label, two-line detail, bar room) instead of `IntrinsicHeight`; the position switch shrinks with large text. Layout test checks every count-up frame and 130% text |
| 7 Nov 2026 | 2.12b done, 2.12 complete: League at a glance, the two charts, Season stats card, Coming later. Totals are live from the lists the app already streams instead of count queries (no extra reads; Isaac, 7 Nov 2026). Squads ready counts Division teams only (Isaac, 7 Nov 2026) |
| 7 Nov 2026 | 2.12a: the way back to Home goes deeper. Links and back arrows on FA screens pass `from=home` on (`goKeepingHome` / `pushKeepingHome`), so Home → Players → a team → back → back ends on Home again; from the tabs nothing changes |
| 7 Nov 2026 | 2.12a fixes (Isaac tested): Google users' first name in the greeting (Google's name is copied onto the account when it has none); screens opened from a Needs you row show a back arrow to Home (the phone's Back too), the same tab opened from the navigation bar has none |
| 7 Nov 2026 | 2.12a done: FA Home tab (dashboard) first, FA lands on it; header and Needs you. Season stats (top scorers, assists, clean sheets, best attack and defence) get their own screen in Phase 4; fourth officials will record assists. Order agreed: 2.12b, Phase 3, UI/UX refresh with motion and the "before the pilot" list, pilot, a second refresh from feedback, then Phase 4 (Isaac, 7 Nov 2026) |
| 7 Nov 2026 | 2.11c done, 2.11 complete: the chairman suspends a team (ends on a date or when lifted with why) and lifts it; the rules lock the team's player, profile and change-request writes while it is in force |
| 7 Nov 2026 | 2.11b done: the FA asks a team to correct (officials, kits, colours, players, club details); the team sends it back, the FA marks it done or asks again. One request per team at a time |
| 7 Nov 2026 | 2.11 split into 2.11a–c; 2.11a done: the FA corrects only misspellings and obvious mistakes (club name, town, ground, directions, year founded, email), each with "What was wrong?" in a log the team can read; officials, kits and colours go to "ask the team" (2.11b). Suspensions: chairman only, end on a date or when lifted (fine paid, bond signed, board decision) (Isaac, 7 Nov 2026) |
| 7 Nov 2026 | 2.10c done (Isaac tested 2.10b): changes grouped by team, Reject with a reason, Approve all, "Previously …" on renamed teams. Mockups stay out of git (`docs/mockups/` ignored). Isaac deploys the rules himself |
| 7 Nov 2026 | 2.10b done: change requests (name, short name, logo, add a competition) and the FA's New teams / Changes switch; 2.10 complete. The old name stays reserved for the club after a rename; a Juvenile club adding Division keeps its kits as its Juvenile kits. Fee unchanged (still open with GEDFA) |
| 6 Nov 2026 | 2.10a done: team profile with direct edits. Isaac: town and colours direct, adding a competition needs the FA, direct edits ping the FA, the old name stays until a change is approved; fee unchanged when a competition is added (for now) |
| 3 Nov 2026 | 2.14d done (Isaac's review): server refuses screening before the day starts; "Needs correcting" with quick reasons; possible duplicates on the screening screen; Screen player on a child's page; countdown on screening days |
| 3 Nov 2026 | 2.14c done: screening decisions, juvenile IDs `GJ26-…`. 2.14 Juvenile complete |
| 2 Nov 2026 | 2.14b-2 done: screening days with automatic announcements, the team's blue card, the FA's next-screening strip |
| 2 Nov 2026 | 2.14b-1 done: FA Players Division / Juvenile switch, juvenile bell note, "Register in" by tab. Isaac: playing up for a match is chosen on the team sheet (Phase 3); a younger child registered in an older squad stays there and can still play their own age |
| 30 Oct 2026 | 2.14a done: juvenile players by age group, parent or guardian, waiting for screening. GEDFA: moved-up children are not screened again; juvenile IDs `GJ26-…`; the screening day is the only check; 16–17-year-olds may also play Division |
| 30 Oct 2026 | 2.13d done: League settings; 2.13 complete |
| 28 Oct 2026 | 2.13c-2 done: team Season fee screen and payments after approval, FA Season fees and reminders, payment notifications |
| 28 Oct 2026 | 2.13c-1 fixes: "not found" sends the registration back; edit recorded cash; R7 buttons; team requests grouped in the FA's bell (one a day) |
| 27 Oct 2026 | 2.13c-1 done: Payment step, FA confirms (green tick, receipts) or "not found", record cash; approval needs a confirmed payment |
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
