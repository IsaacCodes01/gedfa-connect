# GEDFA Connect — Data Model

**Status:** v1.4, matches security rules v1 and the Phase 1 app (18 Oct 2026)
**Owner:** Isaac Otabil
**Applies to:** the Flutter app *and* the React website. Both use the same Firebase project, this model and the same security rules.

> This file is the contract. Any change to a collection, field name or allowed value goes through the project owner first and is recorded in the changelog at the bottom.

---

## 1. Conventions

| Topic               | Rule                                                                                                                                                                           |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Root path           | Everything lives under`districts/{districtId}/`. Current district: `gomoa-east`.                                                                                           |
| Field names         | `camelCase` (e.g. `jerseyNo`, `createdAt`).                                                                                                                              |
| Document IDs        | Firestore auto-IDs, except where stated (`users`, `teamRequests` use the Auth `uid`; reservation docs use their key).                                                    |
| Times               | Always`serverTimestamp()` for `createdAt`, `updatedAt`, `approvedAt`. Never the device clock.                                                                          |
| Dates of birth      | Stored as a timestamp at midnight UTC. Entered only through a date picker.                                                                                                     |
| Phone numbers       | Stored in international form, e.g.`+233241234567`.                                                                                                                           |
| Search copies       | Fields ending in`Lower` hold a trimmed, lowercase copy for duplicate checks and search.                                                                                      |
| Denormalised copies | Some fields are copied from another document (e.g.`teamName` on players) so lists need one read, not two. When the source changes, the copies are updated in the same batch. |

### Allowed values

| Field                           | Values                                                                                                                                                                  |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `role`                        | `faAdmin`, `teamAdmin`, `referee`                                                                                                                                 |
| `status` (requests, players)  | `pending`, `approved`, `rejected`                                                                                                                                 |
| `position`                    | 23 codes: `GK`, `CB`, `RCB`, `LCB`, `RB`, `LB`, `RWB`, `LWB`, `RFB`, `LFB`, `DM`, `RDM`, `LDM`, `CM`, `RM`, `LM`, `AMF`, `LW`, `RW`, `LWF`, `RWF`, `CF`, `ST` |
| `positionGroup`               | `GK`, `DEF`, `MID`, `FWD` (derived from `position`, never typed by a user)                                                                                    |
| Kit`pattern`                  | `plain`, `stripes`, `hoops`, `halves`, `sash`                                                                                                                 |
| `categories` (teams)          | `division` (Third Division, senior), `juvenile` (youth: U13, U15, U17)                                                                                              |
| `ageGroup` (juvenile players) | `U13`, `U15`, `U17` (derived from date of birth, never typed by a user)                                                                                           |
| Official`role`                | `teamManager`, `headCoach`, `assistantCoach`, `chairman`, `secretary`, `kitManager`, `medicalOfficer`                                                     |

### Kit shape

Used for every kit (home, away, third, goalkeeper, goalkeeper 2). Colours come from the app's fixed list of 16 kit colours and are stored as `#RRGGBB`.

```
{
  primary: "#C8102E", secondary: "#FFFFFF" | null, pattern: "stripes",
  shorts: "#FFFFFF", socks: "#C8102E",
  trim: "#FCD116" | null, shoulderStripes: false, collarAndCuffs: true, shortsStripe: false
}
```

- A `pattern` other than `plain` requires `secondary`.
- `shoulderStripes`, `collarAndCuffs` and `shortsStripe` are optional trims. If any of them is `true`, `trim` (the trim colour) is required; if all are `false`, `trim` is `null`.

### Official shape

```
{ role: "headCoach", name: "Kofi Mensah", phone: "+233241234567", licence: "CAF D" | null }
```

- `teamManager` and `headCoach` are required on every team request and team.
- `licence` is used for the head coach (whether it is required is pending GEDFA).

### Position → group

| Group   | Positions                                      |
| ------- | ---------------------------------------------- |
| `GK`  | GK                                             |
| `DEF` | CB, RCB, LCB, RB, LB, RWB, LWB, RFB, LFB       |
| `MID` | DM, RDM, LDM, CM, RM, LM, AMF                  |
| `FWD` | LW, RW, LWF, RWF, CF, ST                       |

The same table is in `position.dart` and in `positionGroups()` in `firestore.rules`. Change all three together.

---

## 2. Collections (Phase 1)

All paths below are relative to `districts/gomoa-east/`.

### 2.1 `users/{uid}` — roles

One document per person who has been given a role. `{uid}` is the Firebase Auth user ID.

| Field           | Type      | Notes                                     |
| --------------- | --------- | ----------------------------------------- |
| `role`        | string    | `faAdmin` / `teamAdmin` / `referee` |
| `teamId`      | string    | Team admins only; the team they manage    |
| `displayName` | string    |                                           |
| `email`       | string    |                                           |
| `createdAt`   | timestamp | When the role was given                   |
| `createdBy`   | string    | `uid` of the FA admin who gave it       |

- **No document = no role.** A new sign-up has no document and is routed to "Register your team".
- Written **only by an FA admin**. A user can `get` their own document (never list or query users) and never write it.
- The app listens to this document live: when the FA changes a role, the app moves the user to the matching home screen at once.
- The first FA admin is created by hand in the Firebase console (see step 0.7).

### 2.2 `teamRequests/{uid}` — team registration requests

Keyed by the requester's `uid`, so each person can have at most one request.

| Field                    | Type             | Notes                                                                                                                             |
| ------------------------ | ---------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Club details**   |                  |                                                                                                                                   |
| `teamName`             | string           | Required, 2–60 characters, trimmed                                                                                               |
| `teamNameLower`        | string           | Lowercase copy, for search                                                                                                        |
| `nameKey`              | string           | Normalised name, e.g.`gomoa-united`; the ID of its `teamNames` reservation                                                    |
| `shortName`            | string           | Required, 3–4 capital letters, e.g.`GUN`                                                                                       |
| `town`                 | string           | Required                                                                                                                          |
| `homeGround`           | string           | Required                                                                                                                          |
| `homeGroundDirections` | string?          | Optional                                                                                                                          |
| `yearFounded`          | number?          | Optional                                                                                                                          |
| `email`                | string?          | Optional                                                                                                                          |
| `logoUrl`              | string?          | Optional; Storage download URL. The app shows the team's initials until a logo is added                                           |
| **Competitions**   |                  |                                                                                                                                   |
| `categories`           | array of strings | Required. 1 or 2 items from`division`, `juvenile`, no repeats. `juvenile` always means all three age groups (U13, U15, U17) |
| **Kits**           |                  |                                                                                                                                   |
| `kits`                 | map              | `home`, `away`, `goalkeeper` required; `third`, `goalkeeper2` optional. Each value is a Kit (see Kit shape)             |
| **Officials**      |                  |                                                                                                                                   |
| `officials`            | array of maps    | Officials (see Official shape); must include`teamManager` and `headCoach`; at most 10                                         |
| **Declaration**    |                  |                                                                                                                                   |
| `agreedToRules`        | boolean          | Must be`true`                                                                                                                   |
| **Review**         |                  |                                                                                                                                   |
| `status`               | string           | `pending` / `approved` / `rejected`                                                                                         |
| `rejectionReason`      | string?          | Set only by the FA when rejecting; cleared when the team resubmits                                                                |
| `createdAt`            | timestamp        | Set once on create                                                                                                                |
| `updatedAt`            | timestamp        | Set on every write                                                                                                                |

- Only a person with a **confirmed email** may create a request (Google accounts count as confirmed).
- The requester may create it, and edit it **only while `pending` or `rejected`**. Every edit sets `status` back to `pending` and clears `rejectionReason`.
- Only an FA admin may set `status` to `approved` or `rejected`.
- One club = one request, whatever it plays in. A club in both competitions registers **once** and ticks both; name, logo, kits and officials are shared.
- Requests saved before `categories` existed are read as `["division"]` by the app; the next edit saves the field.
- **Pending GEDFA:** registration fee payment reference, supporting documents, previous league. These fields will be added when GEDFA answers (see the *Team Registration Requirements* document).

### 2.2a `teamNames/{nameKey}` — team name reservations

Stops two teams registering the same name, without letting anyone read other teams' requests.

**Key format:** trim, lowercase, collapse repeated spaces, replace spaces with `-`, remove anything that isn't `a–z`, `0–9` or `-`. Example: `Gomoa  United FC` → `gomoa-united-fc`.

| Field         | Type      | Notes                            |
| ------------- | --------- | -------------------------------- |
| `uid`       | string    | The requester who holds the name |
| `createdAt` | timestamp |                                  |

- Created **only if it doesn't exist**, in the **same batch** as the team request.
- If the team name changes while pending or rejected, the old reservation is deleted and the new one created in the same batch.
- The holder may delete their own reservation; an FA admin may delete any (e.g. to free a name from an abandoned request).
- Any signed-in user may `get` a single key, so the form can say "This name is taken" before submitting.

### 2.3 `teams/{teamId}` — approved teams

Created by an FA admin when approving a request.

| Field                    | Type             | Notes                                                      |
| ------------------------ | ---------------- | ---------------------------------------------------------- |
| `name`                 | string           |                                                            |
| `nameLower`            | string           |                                                            |
| `nameKey`              | string           | Same key as its`teamNames` reservation                   |
| `shortName`            | string           |                                                            |
| `town`                 | string           |                                                            |
| `homeGround`           | string           |                                                            |
| `homeGroundDirections` | string?          |                                                            |
| `yearFounded`          | number?          |                                                            |
| `email`                | string?          |                                                            |
| `logoUrl`              | string?          |                                                            |
| `categories`           | array of strings | Copied from the request:`division`, `juvenile` or both |
| `kits`                 | map              | Same shape as on the request                               |
| `officials`            | array of maps    | Same shape as on the request                               |
| `adminUids`            | array of strings | Users who manage this team (one or more)                   |
| `requestUid`           | string           | The`teamRequests` document it came from                  |
| `createdAt`            | timestamp        | Approval time                                              |
| `updatedAt`            | timestamp        |                                                            |

- **Phase 1 (testing):** teams on dev are created by hand in the console with the same fields as the request. From Phase 2 the FA's Approve button creates them.

#### Subcollection `teams/{teamId}/jerseys/{category}-{number}` — jersey reservations

One document per jersey number in use **within this team and competition**. The document ID is the competition and the number, e.g. `division-9`, so a club's Division and Juvenile sides can both use #9. Other teams have their own jersey subcollection.

| Field          | Type      | Notes                      |
| -------------- | --------- | -------------------------- |
| `playerId`   | string    | Player holding this number |
| `createdAt`  | timestamp |                            |

- Only these two fields are allowed (the rules refuse anything else).
- Can only be **created if it doesn't exist**; that is what blocks a duplicate number.
- The rules check that the player in the same batch really has this team, competition and number.
- Created, moved or deleted **in the same batch** as the player change.
- Readable by the team's own admins (for the live "#10 is free" check).

### 2.4 `players/{playerId}` — all players in the league

One collection for the whole district. Team admins see only their own team's players (enforced by rules on `teamId`); the FA sees all.

| Field               | Type             | Notes                                                                                                                                                                                                                              |
| ------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `teamId`          | string           |                                                                                                                                                                                                                                    |
| `teamName`        | string           | Copied from the team                                                                                                                                                                                                               |
| `category`        | string           | `division` or `juvenile`; must be one of the team's `categories`                                                                                                                                                             |
| `fullName`        | string           | Entered once, reused everywhere                                                                                                                                                                                                    |
| `fullNameLower`   | string           |                                                                                                                                                                                                                                    |
| `searchKeys`      | array of strings | Set by the app from`fullName`: every word and its beginnings (2+ letters), lowercase. `Kwame Asante` → `kw, kwa, kwam, kwame, as, asa, asan, asant, asante`. Lets the FA and referees find a player by any part of the name. At most 80 items |
| `playerKey`       | string           | The ID of this player's `playerKeys` reservation, e.g. `kwame-asante_2004-03-15` (see 2.5). Set by the app from `fullName` and `dob` |
| `playerCode`      | string?          | The**player ID**, e.g. `GE26-0042`. Set **only by the FA at approval**, never changed afterwards (see 2.4a). `null` until approved                                                                                 |
| `dob`             | timestamp        | From the date picker                                                                                                                                                                                                               |
| `position`        | string           | Detailed position, e.g.`RCB`, `AMF` (see allowed values)                                                                                                                                                                       |
| `positionGroup`   | string           | `GK` / `DEF` / `MID` / `FWD`, set by the app from `position`                                                                                                                                                             |
| `jerseyNo`        | number           | 1–99 (agreed 18 Oct 2026)                                                                                                                                                                                                         |
| `photoUrl`        | string           | **Required.** Download link of the 300×400 passport photo (3:4, JPEG). 10–2000 characters                                                                                                                                         |
| `thumbUrl`        | string           | **Required.** Download link of the 96×128 thumbnail for lists                                                                                                                                                                      |
| `status`          | string           | `pending` / `approved` / `rejected`                                                                                                                                                                                          |
| `rejectionReason` | string?          |                                                                                                                                                                                                                                    |
| `createdAt`       | timestamp        |                                                                                                                                                                                                                                    |
| `updatedAt`       | timestamp        |                                                                                                                                                                                                                                    |
| `approvedAt`      | timestamp?       |                                                                                                                                                                                                                                    |
| `approvedBy`      | string?          | FA admin`uid`                                                                                                                                                                                                                    |

- After approval, changing `fullName`, `dob`, `jerseyNo` or the photo sets `status` back to `pending` (FA re-approval). Changing only `position` keeps it approved. `playerCode` never changes.
- Created by the team admin with `status: pending` and no `playerCode`, `approvedAt` or `approvedBy`. A team may hold at most `settings/league.maxSquadSize` players per competition (checked in the app; 30 for now).
- **No passport photo, no player:** the rules refuse a player without `photoUrl` and `thumbUrl`.
- An approved player stays approved only if the edit changes nothing but `position` (and `positionGroup`). Any other change must set `status` back to `pending`.
- A team admin can't change `teamId`, `category`, `playerCode`, `approvedAt`, `approvedBy` or `createdAt`, and can't delete a player (removing players comes later).
- Only Division players can be added for now; Juvenile waits for GEDFA's answers.
- **Juvenile players:** the age group (U13 / U15 / U17) is **calculated** from `dob` and the season's cut-off date, never stored as typed input. Extra fields planned, pending GEDFA: birth certificate photo, parent or guardian name and phone, consent. Juvenile player photos are **never shown publicly**.
- Only an FA admin may set `status` to `approved` or `rejected`.

### 2.4a Player ID (`playerCode`)

**Format:** `GE` + two-digit year of first approval + `-` + four-digit running number. Example: `GE26-0042`.

- One running number for the whole district (Division and Juvenile together), so no two players ever share an ID.
- Stays with the person for life: a transfer to another team, or a youth player moving up to the Division side, keeps the same ID.
- Made inside the FA's **approval transaction**: read `settings/playerCounter.next`, write the player with that number, add 1 to the counter. Firestore retries if two approvals happen at once, so numbers are never repeated.

### 2.4b Search

| Who        | Searches              | How                                                              |
| ---------- | --------------------- | ---------------------------------------------------------------- |
| Team admin | Own squad             | In the app, over the squad already loaded (name or ID, any part) |
| FA admin   | All players           | `searchKeys array-contains <word>` or `playerCode == <ID>`   |
| Referee    | Approved players only | As FA, plus`status == approved`. Date of birth never shown     |

### 2.5 `playerKeys/{key}` — duplicate-player reservations (league-wide)

Stops the same person being registered twice, with any team.

**Key format:** normalised full name + `_` + date of birth

- Name: trim, lowercase, collapse repeated spaces, replace spaces with `-`, remove anything that isn't `a–z`, `0–9` or `-`
- Date: `YYYY-MM-DD`
- Example: `Kofi  Mensah`, born 15 Mar 2004 → `kofi-mensah_2004-03-15`

| Field         | Type      | Notes |
| ------------- | --------- | ----- |
| `playerId`  | string    |       |
| `teamId`    | string    |       |
| `createdAt` | timestamp |       |

- Created only if it doesn't exist, in the same batch as the player.
- If a player's name or date of birth is corrected, the old key is deleted and the new one created in the same batch.
- Any team admin may `get` a single key, so the app can say "already registered with your team" or "already registered with another team" before saving. Listing keys is never allowed.
- Same name with a **different** date of birth is allowed (two different people). Same name **and** same date of birth is blocked; an FA override for real namesakes is an open question (Section 7).

### 2.6 `settings/league` — configurable league rules

A single document. Values are placeholders until confirmed with GEDFA.

| Field                | Type      | Start value                             |
| -------------------- | --------- | --------------------------------------- |
| `maxSquadSize`     | number    | 30 per competition (agreed 18 Oct 2026) |
| `matchdayStarters` | number    | 11                                      |
| `matchdaySubs`     | number    | 7*(to confirm)*                       |
| `registrationOpen` | boolean   | `true`                                |
| `updatedAt`        | timestamp |                                         |

Readable by any signed-in user; writable only by FA admins.

### 2.7 `settings/playerCounter` — player ID numbering

| Field    | Type   | Notes                                                         |
| -------- | ------ | ------------------------------------------------------------- |
| `next` | number | The running number the next approved player gets. Starts at 1 |

Readable and writable only by FA admins, and only changed inside the approval transaction.

---

## 3. Who can do what (summary)

The security rules enforce this table. Screens hiding a button is **not** security.

**Rules v1 (Phase 1, live on dev)** cover the *No role* and *Team admin* columns and are proven by 49 automated tests in `test/rules/`. The *Referee* and *FA admin* columns are the plan; their rules come with Phases 2 and 4. Until then anything not listed is refused.

| Collection          | No role                                                             | Team admin                                                                 | Referee                                       | FA admin *(Phase 2)* |
| ------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------- | -------------------- |
| `users`           | Get own (none exists)                                               | Get own                                                                    | Get own                                       | Read / write all     |
| `teamRequests`    | Create (confirmed email) / get / edit own while pending or rejected | Get own                                                                    | —                                            | Read all, set status |
| `teamNames`       | Get any key; create / delete own                                    | Get any key                                                                | Get any key                                   | Read / delete all    |
| `teams`           | —                                                                  | Get own team *(editing later)*                                             | Read                                          | Read / write all     |
| `teams/*/jerseys` | —                                                                  | Get / create / delete for own team                                         | —                                            | Read / write all     |
| `players`         | —                                                                  | Create / read / edit own team's (never status, player ID or team); no delete yet | Read players in assigned matches*(Phase 4)* | Read all, set status |
| `playerKeys`      | —                                                                  | Get any key; create / delete for own team's players                        | —                                            | Read / write all     |
| `settings/league` | Read *(rule to add)*                                                | Read *(rule to add)*                                                       | Read                                          | Read / write         |
| Storage: request logo | Write / read own (image < 1 MB)                                  | —                                                                          | —                                            | Read all             |
| Storage: player photos | —                                                                | Create / read / delete for own team (JPEG < 1 MB, `photo-` / `thumb-` names) | —                                          | Read all             |

---

## 4. Batched writes

These changes always happen together in **one batch** (all succeed or none do):

| Action                                | Writes in the batch                                                                           |
| ------------------------------------- | --------------------------------------------------------------------------------------------- |
| Add player                            | create`players/{id}` + create `teams/{teamId}/jerseys/{category}-{no}` + create `playerKeys/{key}` |
| Change jersey number                  | update player + delete old jersey doc + create new jersey doc                                 |
| Correct name or DOB                   | update player (back to`pending`) + delete old player key + create new player key            |
| Remove player *(later)*               | delete player + delete jersey doc + delete player key                                         |
| Submit team request                   | create`teamRequests/{uid}` + create `teamNames/{nameKey}`                                 |
| Rename team while pending or rejected | update request + delete old`teamNames` doc + create new one                                 |
| Approve team request                  | update request`status` + create `teams/{teamId}` + create/update `users/{uid}`          |

**Photos and batches.** Storage files can't be part of a Firestore batch, so a player's photo is handled around it:

1. The app picks the player's ID first (`players.doc()`), then uploads `photo-<time>.jpg` and `thumb-<time>.jpg`.
2. It runs the batch above with the two download links.
3. If the batch fails, the files just uploaded are deleted. If it succeeds after a photo change, the **old** files are deleted.

A leftover file is harmless; a player without a photo can't exist.

---

## 5. Cloud Storage paths

| Path                                                                        | Contents                                  |
| --------------------------------------------------------------------------- | ----------------------------------------- |
| `districts/gomoa-east/teamRequests/{uid}/logo.jpg`                        | Logo sent with a request                  |
| `districts/gomoa-east/teams/{teamId}/logo.jpg`                            | Approved team logo *(Phase 2)*            |
| `districts/gomoa-east/teams/{teamId}/players/{playerId}/photo-<millis>.jpg` | Passport photo, 300×400, JPEG quality 85  |
| `districts/gomoa-east/teams/{teamId}/players/{playerId}/thumb-<millis>.jpg` | Thumbnail, 96×128, JPEG quality 80        |

- Images are processed in the app before upload: logos at most 512 px wide; passport photos turned upright, centre-cropped to 3:4 and resized. All JPEG, under 1 MB.
- Player photos sit under the **team** folder, so the storage rules can check "is this the team's admin?" by reading `users/{uid}` (`role == teamAdmin` and `teamId` matches). Only file names `photo-<digits>.jpg` and `thumb-<digits>.jpg` are allowed, and files are never overwritten: a new photo gets a new name (`<millis>` = upload time), which also stops phones showing an old cached picture.
- Storage rules: a requester may write and read only their own request logo; a team admin may create, read and delete only their own team's player photos; FA admins read all *(Phase 2)*.
- **Web build:** the bucket needs a CORS setting that allows the Hosting addresses, or photos and logos won't load in browsers (set on dev, 18 Oct 2026; to do on prod).

---

## 6. Later phases (shape only, detailed when reached)

| Collection                  | Phase     | Key fields                                                                                                                                                                     |
| --------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fixtures/{fixtureId}`    | 4         | homeTeamId, awayTeamId, date, venue, refereeId, status                                                                                                                         |
| `teamSheets/{sheetId}`    | 3         | fixtureId, teamId, starters[], subs[], formation, captainId, createdAt                                                                                                         |
| `matchReports/{reportId}` | 4         | fixtureId, homeScore, awayScore, scorers[], cards[], notes, signedSheetPhoto, status                                                                                           |
| `matchEvents/{eventId}`   | 7         | fixtureId, minute, type, teamId, playerId                                                                                                                                      |
| `standings/{teamId}`      | 5         | Calculated from approved reports only, updated when a report is approved                                                                                                       |
| `invites/{email}`         | 2.6       | role (`faAdmin` / `referee`), teamId?, invitedBy, createdAt. Created only by FA admins; used once when the invited person signs up with that confirmed email, then deleted |
| `roleLog/{logId}`         | 2.6       | action, targetUid, role, byUid, createdAt — history of role changes                                                                                                           |
| `feedPosts/{postId}`      | 2.7 / 5.5 | type, title, body, teamIds[], fixtureId?, playerIds[]?, imageUrl?, source (`auto` / `fa` / `team`), createdBy, createdAt, hidden (bool), hiddenBy?                       |

### Feed post types (Phase 5.5)

| `type`         | Source | Created when                              |
| ---------------- | ------ | ----------------------------------------- |
| `announcement` | FA     | An FA admin posts it                      |
| `teamNews`     | Team   | A team admin posts about their own team   |
| `fixtures`     | Auto   | The FA publishes a matchday's fixtures    |
| `lineup`       | Auto   | A team sheet is locked at kick-off        |
| `result`       | Auto   | The FA approves a match report            |
| `tableUpdate`  | Auto   | Standings change after approved results   |
| `transfer`     | Auto   | The FA approves a player's move           |
| `suspension`   | Auto   | A player reaches the card limit           |
| `newTeam`      | Auto   | A team is approved                        |
| `milestone`    | Auto   | Top scorer, hat-trick, clean-sheet streak |

Feed rules: never include dates of birth; player photos only if agreed with GEDFA; FA admins can hide any post; team admins post only for their own team.

---

## 7. Open questions for GEDFA

- Squad size, matchday substitutes
- Juvenile: separate kits or the same as the Division side?
- Juvenile: coach per age group? Welfare or child-safety officer required?
- Juvenile: age cut-off date per age group, per season
- Juvenile: can a player play up an age group (e.g. U13 in U15)?
- Juvenile: must a club field all three age groups?
- Separate registration fees for Division and Juvenile?
- Registration window; adding players mid-season
- One team admin or several per team
- Player transfers between teams during a season
- Retention rules for player data
- Two real players with the same name **and** the same date of birth: should the FA be able to override the duplicate check?

---

## 8. Changelog

| Date        | Change                                                                                                                                                                                                                                                                                                                           |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 13 Oct 2026 | v1 agreed: Phase 1 collections, reservation docs for jerseys and duplicate players,`adminUids` as a list, single `players` collection.                                                                                                                                                                                       |
| 13 Oct 2026 | Positions: 16 detailed GEDFA positions in`position`, plus derived `positionGroup` (GK/DEF/MID/FWD).                                                                                                                                                                                                                          |
| 13 Oct 2026 | Planned shapes added:`invites` and `roleLog` (Phase 2.6), `feedPosts` with post types (Phases 2.7 and 5.5).                                                                                                                                                                                                                |
| 15 Oct 2026 | `users`: access narrowed to `get` own document only (first live security rule); role changes are followed live.                                                                                                                                                                                                              |
| 15 Oct 2026 | Team registration expanded: short name, town, home ground (+ directions), year founded, email, logo; full kits (home, away, third, goalkeeper, goalkeeper 2) with shirt pattern, shorts and socks; officials list replaces`coachName`/`phone`; `agreedToRules`. `colors` replaced by `kits`. Same fields on `teams`. |
| 15 Oct 2026 | New`teamNames/{nameKey}` reservations to block duplicate team names. Only confirmed-email users may submit a request. Fee, documents and previous league pending GEDFA.                                                                                                                                                        |
| 17 Oct 2026 | v1.2: Kit shape gains optional trims (`trim`, `shoulderStripes`, `collarAndCuffs`, `shortsStripe`).                                                                                                                                                                                                                      |
| 17 Oct 2026 | v1.2: competitions.`categories` (`division`, `juvenile`; one or both) on `teamRequests` and `teams`; one registration per club. Players gain `category`; juvenile age group derived from date of birth. Juvenile questions added for GEDFA.                                                                          |
| 18 Oct 2026 | v1.3: players gain`playerCode` (player ID `GE26-0042`, set at FA approval, never changes) and `searchKeys` (name search). New `settings/playerCounter`. Photo change also needs re-approval. Squad size 30 per competition; jersey 1–99 confirmed.                                                                      |
| 18 Oct 2026 | Positions: 23 (added CB, LFB, RFB, LM, RM, LWF, RWF); position → group table updated to match `position.dart` and the rules. |
| 18 Oct 2026 | v1.4: matches security rules v1. Jersey reservation ID is now `{category}-{number}` (e.g. `division-9`) with only `playerId` and `createdAt` (`playerName` dropped). Players gain `playerKey`; `photoUrl` and `thumbUrl` are now **required** (300×400 and 96×128). Player photos moved to `teams/{teamId}/players/{playerId}/photo-<millis>.jpg` / `thumb-<millis>.jpg`. Team admins may `get` any `playerKeys` key. Section 3 marks what rules v1 cover; Storage rows added. Photo-and-batch order added to Section 4. Storage CORS for the web build. |
