# GEDFA Connect: full test plan

Every test we have done since Phase 1, in one place, so the whole app can be tested again from start to end.
Written 12 Nov 2026 (after M1, M2). Tick each box as you go; write what went wrong next to it.

**How to use it**

- Work top to bottom: later sections use the teams, players and matches made in earlier ones.
- Test on a **phone** (Android or the iPhone 8) and on a **laptop** (Chrome). Do at least one pass in **dark mode** (More › Settings).
- ✅ = what should happen. If something else happens, note the screen, what you tapped, and take a screenshot.

---

## 0. Before you start

- [ ] Emulators: `firebase emulators:start --import=./emulator-data --export-on-exit` (Auth 9099, Firestore 8080, Storage 9199, UI 4000)
- [ ] App: `flutter run -d chrome` (or the dev web build on Firebase Hosting for phones)
- [ ] Automatic checks (all must pass): `flutter analyze` → 0 issues · `flutter test` → all pass · `cd test/rules && npm test` → all pass
- [ ] Accounts you need (use different browsers / private windows):

| Who | Role | Used for |
|-----|------|----------|
| A | FA chairman | everything FA, chairman-only settings, suspend a team |
| B | FA official (not chairman) | to see what only the chairman can do |
| C, D | Two clubs (team admins) | registration, squads, sheets; C in **both** Division and Juvenile |
| E | Referee | appointments, sheets, PDF |
| F | Commissioner (referee or FA) | the players check |

---

## 1. Start-up, loading and sending (M1, M2, new)

- [ ] Open the app: ✅ blue start-up screen, Ghana stripe on top, GEDFA logo gently "breathing", gold bar sliding, a greeting ("Good morning / afternoon / evening!") then friendly lines every 2 s ("Warming up…", "Pumping the balls…", … "Almost kick-off…"), "Season 2026/27" at the bottom
- [ ] Same in dark mode (darker blue)
- [ ] Slow: stop the Firestore emulator (or turn on airplane mode), open the app: after 8 s ✅ "Still working, your connection seems slow."
- [ ] Account can't load: ✅ "We couldn't reach the pitch." with **Try again**; turn the connection back on, tap Try again → ✅ goes in
- [ ] Pages loading: open Match details, a player, League settings: ✅ rolling football with the screen's own words ("Loading the match…")
- [ ] Lists loading: Squad, Notifications, FA Requests, Fixtures, Fees, People, Suspended players, referee Matches: ✅ grey cards shimmering with "Getting your squad…" etc.
- [ ] FA team fee card: ✅ small line "Getting the payments…"
- [ ] Check players (commissioner): ✅ a shimmering photo box while a photo loads
- [ ] Any page left loading 8 s: ✅ "Still working, your connection seems slow." under it
- [ ] Save buttons (Team profile Save, Add player "Send for FA approval", Send payment, Ask to change "Send to the FA", Publish announcement, Add / change a match, Suspend player, registration Next / Submit): ✅ the button keeps its colour, shows a spinner and what it is doing ("Saving…", "Sending to GEDFA…", "Publishing…", "Suspending…", "Checking…"); tapping again does nothing; after 8 s "Still sending, your connection seems slow."
- [ ] Long saves: Publish the season, Postpone a league, Finish a stopped postpone, renaming matches after a name change: ✅ a sheet from the bottom with the send icon, the title ("Publishing the season…"), "Match 21 of 36", a moving bar and "Don't close the app…"; it closes by itself; green toast after
- [ ] Phone Back while that sheet is open: ✅ nothing happens (it can't be closed by mistake)
- [ ] A save that fails (stop the emulator mid-save): ✅ red toast, the form unlocks, nothing lost; postpone: "It stopped at N of M" with Try again / Later

---

## 2. Accounts and sign-in (Phase 1)

- [ ] Sign up with email and password → ✅ email check screen ("Verify your email"); the link from the Auth emulator UI confirms it
- [ ] Log in, log out, wrong password → ✅ friendly message, not a Firebase code
- [ ] Forgot password → ✅ reset link sent (shown in the Auth emulator)
- [ ] Google sign-in (web)
- [ ] Each role lands in its own place: no role → Welcome / registration; team admin → team **Home**; referee → referee **Home**; FA → FA **Home**
- [ ] Offline banner at the top when the connection drops, "Back online" when it returns
- [ ] More › My profile: change full name; change email (link to the new address); password reset link; "delete account" explains to ask the FA
- [ ] More › Settings: Light / Dark / System; data saver (no photos in lists)

## 3. Team registration (1.3, 2.13, JSb)

- [ ] Welcome → Register your team: club details, logo (required), club status (already in the district / new club with last league + letter PDF), optional licence
- [ ] Competitions: Division and/or Juvenile (U13 / U15 / U17)
- [ ] Ticking both: "Your juvenile side's name": default "<Club> B" (gold ring in the preview) or its own name + short name (green tick; not the club's own name; checked online on Next and again when sending)
- [ ] Kits: photos (shirt › shorts › socks, cropped) or designed kits; Division and Juvenile kits apart for clubs in both; team colours step
- [ ] Officials: 2 required + up to 5, "Other" with a typed role
- [ ] Payment step: GH₵ 1,000, MoMo / bank, cash, paid before, in parts
- [ ] Review shows everything (with "Juvenile side"); Submit → status screen "Pending"
- [ ] Club name already taken → ✅ friendly message
- [ ] Registration closed in League settings → ✅ the button is hidden

## 4. FA approves teams (2.1, 2.2, 2.13c)

- [ ] FA Teams tab: gold badge; New teams | Changes; Pending / Rejected / Approved with counts; search
- [ ] Review screen: club details, kits (photos and colours), officials with a call button, automatic checks, letter and licence, juvenile side name ("Own name" or "B")
- [ ] Payment: confirm with the green tick (receipt GEDFA-2026-0001), "not found" with a reason, or record cash
- [ ] Approve is blocked without a confirmed payment
- [ ] Approve → ✅ team created, club becomes team admin, club's bell "team approved"
- [ ] Reject with a reason (10–500 characters, quick reasons) → club sees it, fixes and resends

## 5. Players (1.4–1.6, 2.3, 2.3b–d, 2.14)

- [ ] Squad › Add player: name, date of birth, 23 positions, jersey 1–99 (live check; a used number is refused), passport photo cropped 3:4; squad limit 30
- [ ] Same person twice (same name + date of birth) → ✅ refused
- [ ] Changing name / DOB / jersey / photo of an approved player → ✅ asks first, goes back to the FA
- [ ] FA Players tab: teams with totals and "N to review"; a team's players by position; select several and approve together; review screen (photo, checks, possible duplicates side by side, "what the team changed")
- [ ] Approve / reject a player → ✅ club's bell; player gets an ID
- [ ] Squad tab: Approved / Pending / Rejected tiles, search, player cards with IDs; Positions tab (GK / DEF / MID / FWD, average age, "Approved players only")
- [ ] Profiles (clipboard): availability (Available / Injured / Unavailable), height, foot, strengths, captain C / vice VC
- [ ] **Juvenile** (club C): Squad › Juvenile › U13 / U15 / U17; add a child (age group from DOB, "Register in" own group or older, parent / guardian); "waiting for screening"
- [ ] FA › More › Juvenile screening: make a screening day (teams told; blue card on their Squad until the day after); cancel one (teams told)
- [ ] From a started screening day: one child after another, Pass (own or older group, GJ26-0001 ID) or "not eligible" with a reason; Needs correcting; Skip
- [ ] **Juveniles in the Division** (club C): Squad › Division card, pick up to 7 (at most 1 U13, 3 U15), Remove; FA's bell told

## 6. Team profile, changes, corrections (2.10, 2.11, JSc)

- [ ] More › Team profile: town, ground, colours, kits, officials save straight away; FA bell "X updated their profile"
- [ ] Ask to change club name / short name / logo / juvenile side name, or Add Juvenile / Division, with a "Why?" → pending (gold)
- [ ] FA Teams › Changes: one card per team, approve each, Reject with a reason, Approve all; "Previously …" after a rename
- [ ] After a rename: ✅ "Renaming matches…" sheet (see section 1); every match of that side shows the new name with the gold "Previously …" pill; if it stops: FA team page "Finish renaming"
- [ ] FA corrects a misspelling itself (Correct name, Club details › Edit, "What was wrong?") → "FA fixed" on the page
- [ ] FA "Ask the team to correct…" → yellow banner on the club's Squad tab → "Send back to the FA"
- [ ] Chairman suspends a team (reason, end date or until lifted) → red banners; Lift with why; history. Not chairman (B) → ✅ no Suspend option

## 7. People, announcements, notifications (2.6, 2.7, 2.8, 3.0f)

- [ ] More › People and roles: chairman invites an FA official and a referee; share on WhatsApp / copy; invited person signs up with that email and accepts; remove role (never the chairman, never yourself); invitation expires after 14 days
- [ ] FA announcements: publish to everyone / teams / Division / Juvenile / referees; Important; Pinned (card on top of Squad, the team can hide it); FA sees who has seen it
- [ ] Bell: red count; grouped notes (20 approvals = 1 note counting up); tap one → **Notification details** (icon, title, from, time, full text, "Status: Read", button named after the target) and only that one is marked read; Mark all read
- [ ] Back arrow everywhere: ← returns to where you came from (the note, the tab); phone Back does the same; a page refreshed on the web keeps its address

## 8. Season fee and league settings (2.13c-2, 2.13d)

- [ ] Club More › Season fee: confirmed of GH₵ 1,000, what's left, each payment, Add a payment
- [ ] FA More › Season fees: collected, to confirm, Owing / Paid; a team's fee with Send reminder; bells for confirmed / not found / reminder
- [ ] FA More › League settings: registration switches (history, bell note), squad / matchday / subs / fewest numbers; season, fee, MoMo number **chairman only** (B can't change them)
- [ ] Debug only: Repair (squad lists and player photos)

## 9. Dashboards (2.12, TDa–TDc, 3.5b)

- [ ] FA Home: greeting, season, registration open/closed, Needs you (only what is waiting), tiles (teams, players, fees, squads ready) that open their screens with ← back to Home, charts by competition and position
- [ ] Team Home: header, Division | Juvenile switch (remembered), Next match, Coming up, Needs you (team sheet due from 2 days before, red on the day), tiles, fee, Waiting on the FA, From GEDFA, calendar
- [ ] Team Fixtures tab: same switch; List | Calendar (crests on match days, gold ring for a B side, tap a day)
- [ ] Laptop: two-column layouts look right; phone: nothing cut off

## 10. Fixtures, competitions, postpone (3.0a–3.0c1d)

- [ ] FA Fixtures: Division | Juvenile, U13 / U15 / U17, matchdays; Add a match (home ground filled in; warnings: team twice on a matchday, ground used, suspended team; kit check)
- [ ] Change a match (swap home/away, why), postpone (new date now or later), cancel → clubs' bells; Match history
- [ ] Make the season: round robin, weekends, kick-off, weeks off; draft with warnings; tap a match to change it; Save draft; **Publish** → sending sheet (section 1) → every team told
- [ ] 🏆 Competitions: leagues, New cup / New gala, a cup's page (Change before the draw, History, Delete)
- [ ] Postpone a league from its ⋯ (days, reason) → sending sheet; stop it midway → "It stopped at N of M", Later → Competitions shows "postponing stopped" with **Finish**
- [ ] Postpone a Gala
- [ ] Match details: header with countdown, info, Directions, what changed, kits, team sheets, officials

## 11. Team sheets (3.1, 3.2, 3.3)

- [ ] Club: Match details › Make team sheet: Players (11 | Bench, 7–11 starting, a goalkeeper, bench only with 11, at most 7; injured warning) → Roles & numbers (captain must start, vice, goalkeeper, shirt numbers 1–99 no clashes, officials with manager and coach locked) → Check → Save
- [ ] Juvenile U17 sheet: at most 1 U13 and 5 U15 ("U13 limit reached")
- [ ] Division sheet of club C: the "Juveniles (Division list)" section with age pills
- [ ] "Use last sheet"; change it until 1 h before kick-off; after the lock → refused
- [ ] FA views any sheet any time (with player IDs); the opponent only from the lock (no IDs)
- [ ] Official sheet PDF: FA from Match details (DRAFT before the lock), referee from the lock, a team prints its own; both teams, kits (photo kits stacked), numbers, C / VC / GK, IDs, officials, signature lines; Print and Download / Share
- [ ] iPhone 8: the preview may be blank (known, step 3.3c); Print / Download work

## 12. Player suspensions (3.1e)

- [ ] FA: a player's page › Suspend (reason, 1–10 matches, note; shows the matches missed and the return match) → sending button "Suspending…" → club's bell with Open the player
- [ ] "Suspended · 2 left" on Squad cards; red box on the player's page (FA and club)
- [ ] The player can't be picked on any competition's sheet ("Suspended · Division ban"), rules refuse it
- [ ] Postpone / cancel a match → the ban moves to the club's next match
- [ ] FA › Players › Suspended players: Lift (why) → club told

## 13. Match officials and the referee (3.5)

- [ ] FA: Match details › Officials (referee, 2 assistants, 4th, commissioner): Appoint, Change, Take off, referee colours; picker warns "busy elsewhere" (gold within 3 h); appoint a whole matchday from Fixtures
- [ ] Referee E: bell note; Home (next appointment, place, kits, colour, others, when sheets open), Matches (coming up, played)
- [ ] Can't make it (why) → FA told, sees it beside the name
- [ ] Clubs see the officials' names only from 24 h before
- [ ] From the lock, officials see both sheets with player IDs

## 14. Player check on match day (3.6)

- [ ] Commissioner F, from the lock to 2 h after kick-off: Match details › Players check › Check players: one player at a time in shirt order (big photo, number, ID), Matches / Doesn't match (note) / Absent, both teams
- [ ] Doesn't match → FA's bell "#9 … doesn't match" with Open the match
- [ ] FA and officials: Match details › Players check: per team, green all matched, red with the note, who and when
- [ ] Not the commissioner → ✅ no Check players button; outside the window → closed

---

## 15. Refresh (light)

- [ ] R-a Android: install the new build → ✅ the home screen shows the round blue icon with the GEDFA logo, named **Gedfa Connect**
- [ ] R-a Android: open the app → ✅ deep navy splash with the logo (Android 12+: in a circle), then the blue start-up screen "Gedfa Connect"
- [ ] R-a Web (Chrome, laptop and iPhone 8): the tab says **Gedfa Connect** with the new icon; a fresh load shows the navy splash with the logo, then the start-up screen (no white flash, no stuck splash)
- [ ] R-a Web on a phone: Add to Home screen → ✅ the icon is the GEDFA logo on blue, named Gedfa Connect; pinch-zoom still works

---

## Known and accepted

- iPhone 8 / old Safari: PDF preview blank (fix planned in 3.3c).
- Old team requests and old payments keep the old team name.
- A spelling correction's matches wait for Finish renaming (with the pill).
