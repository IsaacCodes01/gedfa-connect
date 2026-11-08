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
  - [ ] 3.0c2 **The draw, live** (C3, C3b): balls from the pot, byes, pots when seeded; Draw again; Save the draw writes the matches and tells both clubs
  - [ ] 3.0c3 **The bracket** (C4, C4b) and **who went through** (C5); the team's "win and you play" (C6)
  - [ ] 3.0c4 **Groups, then knockout** (group tables; mockup first)
  - [ ] 3.0c5 **Two legs and replays** (aggregate, a replay linked to the first match; mockup first)
- [ ] 3.0d **Match details and the next matchday card**
  - [x] **Match details** (F5, F6), done early at Isaac's request: stadium-night header (pitch lines, gold floodlight glow), crests, kick-off, countdown; Match info (date, kick-off, ground with Directions to Google Maps, competition and matchday, match length and play-up rule, team sheets due, status and reason); What changed (the match history); kits (outfield and goalkeeper); team sheets; officials (Phase 4). Tapping any match opens it, for the FA and teams; the FA manages the match from its ⋯ button. 87 Dart tests *(done 8 Nov 2026)*
  - [ ] The next matchday card: countdown and matches sliding every 5 seconds, on Home and Fixtures, Division and Juvenile (D1, J1)
- [ ] 3.0e **Posters**: one match or a matchday, square or tall, three styles, GEDFA logo (transparent PNG), Save to photos and Share (P1–P4)
- [ ] 3.1 Team sheet builder: approved players only (16 / 5 / 7 from settings), captain, vice-captain, goalkeeper, GFA play-up limits
- [ ] 3.2 Submit and lock 1 hour before kick-off; the FA and the referee see it; the opponent sees it at lock time (V2)
- [ ] 3.3 The paper sheet as a PDF: the team's real kits top-left, captain's signature, QR code to check it (V1)
- [ ] 3.4 Formation on a pitch (optional)

> **Before the pilot:** bundle fonts in the app (offline-safe), set up dev/prod switching (flavors), enable App Check, create the first FA Admin on prod, deploy rules to prod, set Storage CORS and Hosting on prod, set up Firebase App Distribution for the Android APK, consider weekly Firestore backups on prod, **phone push notifications** (Firebase Cloud Messaging, grouped the same way), deploy `firestore.indexes.json`.

> **UI and UX refresh before the pilot** (Isaac, 7 Nov 2026): after Phase 3, a modern look with motion and animations, one screen group at a time, mockups first, never mixed with feature work. After the pilot, a second refresh from the clubs' feedback.

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
