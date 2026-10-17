# GEDFA Connect — Project Roadmap

**App name:** GEDFA Connect (repo `gedfa-connect`, package `gedfa_connect`)
**Platforms:** Flutter app (Android first, iOS later, web build available); separate React website by a colleague
**Backend:** Firebase (Auth, Firestore, Cloud Storage) on the Blaze plan
**Projects:** `gedfa-connect-dev` (building/testing) and `gedfa-connect-prod` (real GEDFA data)
**Status:** Phase 0 complete · Phase 1 in progress (17 Oct 2026)

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
- **Cost control:** budget alerts, pagination, few realtime listeners, no backups/PITR on dev.

---

## 5. Design and UX standards

### Design system
- Theme in `lib/app/theme.dart`: logo blue `#1E88E5`, deep blue `#1259A8` for buttons/links, Ghana red/gold/green accents, Barlow / Barlow Condensed fonts.
- Status colours: **green = approved, gold = pending, red = rejected**.
- Reusable widgets in `lib/core/widgets`: `StatusBadge`, `LoadingView`, `EmptyView`, `ErrorView`, `AppToast`.
- Every screen has loading, empty, error and offline states. Touch targets ≥ 48dp.
- Mockups: "GEDFA Connect Screens" design canvas.

### Navigation
- **No hamburger menu.** Phones use a bottom navigation bar (≤ 5 tabs, different per role); large screens use a side navigation rail. Rarely used items (profile, settings, log out, help) sit under a "More"/profile tab.

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

### Phase 1 — Auth, roles, team and player registration *(in progress)*
- [x] 1.0 Firebase Emulator Suite; app uses emulators in debug
- [x] 1.1a `AppToast`, offline/back-online banner, responsive helpers
- [x] 1.1b Log in, sign up, log out, password reset; Firebase error translator; submission time limits
- [x] 1.2 Role-based router: no role → registration/status; team admin → team dashboard; referee → fixtures; FA admin → FA dashboard
- [x] 1.3 Team registration request form and status screen (club details, logo, 5 kits with trims, officials, review, edit and resubmit, Google sign-in)
- [ ] 1.3b Competitions: Division and/or Juvenile (U13, U15, U17) chosen at registration; shown on Review and Status
- [ ] 1.4 Add/edit player form: name, DOB picker, position (16 positions, grouped), jersey number, passport photo; Division first, Juvenile extras (age group from DOB, birth certificate, guardian) after GEDFA answers
- [ ] 1.5 Validation: jersey and duplicate-player reservations, name entered once; first unit tests (player-key function)
- [ ] 1.6 Photo compression and upload
- [ ] 1.7 Security rules v1, tested in the emulator (users, teamRequests, teamNames and logo storage done; teams, players, FA admin still to do)

**Done when:** a test team admin can register a team request and add players, and a role-less user can't read or write anything beyond their own request.

### Phase 2 — FA approval dashboard
- [ ] 2.1 Queue of pending team requests
- [ ] 2.2 Approve a team: create team, assign Team Admin role
- [ ] 2.3 Pending players queue: approve/reject with reason
- [ ] 2.4 Status filters and search
- [ ] 2.5 Lock approved players (changes to name, DOB or jersey need re-approval)
- [ ] 2.6 Role management by **invitation**: invite FA admins and referees by email; last-admin protection; role change history
- [ ] 2.7 **FA announcements** (first part of the league feed)

### Phase 3 — Team sheet builder and PDF
- [ ] 3.1–3.7 As before: select fixture, pick approved players within limits, captain/GK, formation, PDF, print/share, FA can view

> **Before the pilot:** bundle fonts in the app (offline-safe), set up dev/prod switching (flavors), enable App Check, create the first FA Admin on prod, deploy rules to prod, consider weekly Firestore backups on prod.

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

---

## 12. Changelog

| Date | Change |
|---|---|
| 12 Oct 2026 | Renamed to GEDFA Connect; dev/prod projects created |
| 13 Oct 2026 | Phase 0 complete; added 0.8 design foundation, 1.0 emulators, 1.1a toasts/connectivity/responsive; invite-only roles (2.6); FA announcements (2.7); new Phase 5.5 League feed; navigation, connectivity and responsive standards; pre-pilot checklist |
| 17 Oct 2026 | 1.1b, 1.2, 1.3 done; new 1.3b Competitions (Division / Juvenile, one registration per club); 1.4 split into Division first, Juvenile after GEDFA answers |
