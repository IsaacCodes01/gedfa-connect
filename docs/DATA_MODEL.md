# GEDFA Connect — Data Model

**Status:** v1, agreed for Phase 1 (13 Oct 2026)
**Owner:** Isaac Otabil
**Applies to:** the Flutter app *and* the React website. Both use the same Firebase project, this model and the same security rules.

> This file is the contract. Any change to a collection, field name or allowed value goes through the project owner first and is recorded in the changelog at the bottom.

---

## 1. Conventions

| Topic | Rule |
|---|---|
| Root path | Everything lives under `districts/{districtId}/`. Current district: `gomoa-east`. |
| Field names | `camelCase` (e.g. `jerseyNo`, `createdAt`). |
| Document IDs | Firestore auto-IDs, except where stated (`users`, `teamRequests` use the Auth `uid`; reservation docs use their key). |
| Times | Always `serverTimestamp()` for `createdAt`, `updatedAt`, `approvedAt`. Never the device clock. |
| Dates of birth | Stored as a timestamp at midnight UTC. Entered only through a date picker. |
| Phone numbers | Stored in international form, e.g. `+233241234567`. |
| Search copies | Fields ending in `Lower` hold a trimmed, lowercase copy for duplicate checks and search. |
| Denormalised copies | Some fields are copied from another document (e.g. `teamName` on players) so lists need one read, not two. When the source changes, the copies are updated in the same batch. |

### Allowed values

| Field | Values |
|---|---|
| `role` | `faAdmin`, `teamAdmin`, `referee` |
| `status` (requests, players) | `pending`, `approved`, `rejected` |
| `position` | `GK`, `DEF`, `MID`, `FWD` |

---

## 2. Collections (Phase 1)

All paths below are relative to `districts/gomoa-east/`.

### 2.1 `users/{uid}` — roles

One document per person who has been given a role. `{uid}` is the Firebase Auth user ID.

| Field | Type | Notes |
|---|---|---|
| `role` | string | `faAdmin` / `teamAdmin` / `referee` |
| `teamId` | string | Team admins only; the team they manage |
| `displayName` | string | |
| `email` | string | |
| `createdAt` | timestamp | When the role was given |
| `createdBy` | string | `uid` of the FA admin who gave it |

- **No document = no role.** A new sign-up has no document and is routed to "Register your team".
- Written **only by an FA admin**. A user can read their own document but never write it.
- The first FA admin is created by hand in the Firebase console (see step 0.7).

### 2.2 `teamRequests/{uid}` — team registration requests

Keyed by the requester's `uid`, so each person can have at most one request.

| Field | Type | Notes |
|---|---|---|
| `teamName` | string | As typed |
| `teamNameLower` | string | For duplicate-name checks |
| `coachName` | string | Head coach |
| `phone` | string | `+233…` |
| `colors` | map | `{ home: "#RRGGBB", away: "#RRGGBB" }` |
| `logoUrl` | string? | Optional; Storage download URL |
| `status` | string | `pending` / `approved` / `rejected` |
| `rejectionReason` | string? | Set by the FA when rejecting |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

- The requester may create it, and edit it **only while `pending` or `rejected`** (editing a rejected request sets it back to `pending`).
- Only an FA admin may set `status` to `approved` or `rejected`.

### 2.3 `teams/{teamId}` — approved teams

Created by an FA admin when approving a request.

| Field | Type | Notes |
|---|---|---|
| `name` | string | |
| `nameLower` | string | |
| `coachName` | string | |
| `phone` | string | |
| `colors` | map | `{ home, away }` |
| `logoUrl` | string? | |
| `officials` | array of maps | `[{ name, role, phone }]` |
| `adminUids` | array of strings | Users who manage this team (one or more) |
| `requestUid` | string | The `teamRequests` document it came from |
| `createdAt` | timestamp | Approval time |
| `updatedAt` | timestamp | |

#### Subcollection `teams/{teamId}/jerseys/{number}` — jersey reservations

One document per jersey number in use **within this team**. `{number}` is the jersey number as a string (`"9"`). Other teams have their own jersey subcollection, so every team can use any number once.

| Field | Type | Notes |
|---|---|---|
| `playerId` | string | Player holding this number |
| `playerName` | string | For display |
| `createdAt` | timestamp | |

- Can only be **created if it doesn't exist**; that is what blocks a duplicate number.
- Created, moved or deleted **in the same batch** as the player change.

### 2.4 `players/{playerId}` — all players in the league

One collection for the whole district. Team admins see only their own team's players (enforced by rules on `teamId`); the FA sees all.

| Field | Type | Notes |
|---|---|---|
| `teamId` | string | |
| `teamName` | string | Copied from the team |
| `fullName` | string | Entered once, reused everywhere |
| `fullNameLower` | string | |
| `dob` | timestamp | From the date picker |
| `position` | string | `GK` / `DEF` / `MID` / `FWD` |
| `jerseyNo` | number | 1–99 |
| `photoUrl` | string | ~400px passport photo |
| `thumbUrl` | string | ~100px thumbnail for lists |
| `status` | string | `pending` / `approved` / `rejected` |
| `rejectionReason` | string? | |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |
| `approvedAt` | timestamp? | |
| `approvedBy` | string? | FA admin `uid` |

- After approval, changing `fullName`, `dob` or `jerseyNo` sets `status` back to `pending` (FA re-approval).
- Only an FA admin may set `status` to `approved` or `rejected`.

### 2.5 `playerKeys/{key}` — duplicate-player reservations (league-wide)

Stops the same person being registered twice, with any team.

**Key format:** normalised full name + `_` + date of birth
- Name: trim, lowercase, collapse repeated spaces, replace spaces with `-`, remove anything that isn't `a–z`, `0–9` or `-`
- Date: `YYYY-MM-DD`
- Example: `Kofi  Mensah`, born 15 Mar 2004 → `kofi-mensah_2004-03-15`

| Field | Type | Notes |
|---|---|---|
| `playerId` | string | |
| `teamId` | string | |
| `createdAt` | timestamp | |

- Created only if it doesn't exist, in the same batch as the player.
- If a player's name or date of birth is corrected, the old key is deleted and the new one created in the same batch.

### 2.6 `settings/league` — configurable league rules

A single document. Values are placeholders until confirmed with GEDFA.

| Field | Type | Start value |
|---|---|---|
| `maxSquadSize` | number | 30 *(to confirm)* |
| `matchdayStarters` | number | 11 |
| `matchdaySubs` | number | 7 *(to confirm)* |
| `registrationOpen` | boolean | `true` |
| `updatedAt` | timestamp | |

Readable by any signed-in user; writable only by FA admins.

---

## 3. Who can do what (summary)

The security rules (Phase 1.7) enforce this table. Screens hiding a button is **not** security.

| Collection | No role | Team admin | Referee | FA admin |
|---|---|---|---|---|
| `users` | Read own (none exists) | Read own | Read own | Read / write all |
| `teamRequests` | Create / read / edit own while pending or rejected | Read own | — | Read all, set status |
| `teams` | — | Read / edit own team (not `adminUids`) | Read | Read / write all |
| `teams/*/jerseys` | — | Create / delete for own team | — | Read / write all |
| `players` | — | Create / read / edit own team's (not status) | Read players in assigned matches *(Phase 4)* | Read all, set status |
| `playerKeys` | — | Create / delete for own team's players | — | Read / write all |
| `settings/league` | Read | Read | Read | Read / write |

---

## 4. Batched writes

These changes always happen together in **one batch** (all succeed or none do):

| Action | Writes in the batch |
|---|---|
| Add player | create `players/{id}` + create `teams/{teamId}/jerseys/{no}` + create `playerKeys/{key}` |
| Change jersey number | update player + delete old jersey doc + create new jersey doc |
| Correct name or DOB | update player (back to `pending`) + delete old player key + create new player key |
| Remove player | delete player + delete jersey doc + delete player key |
| Approve team request | update request `status` + create `teams/{teamId}` + create/update `users/{uid}` |

---

## 5. Cloud Storage paths

| Path | Contents |
|---|---|
| `districts/gomoa-east/teamRequests/{uid}/logo.jpg` | Logo sent with a request |
| `districts/gomoa-east/teams/{teamId}/logo.jpg` | Approved team logo |
| `districts/gomoa-east/players/{playerId}/photo.jpg` | Passport photo, ~400px |
| `districts/gomoa-east/players/{playerId}/thumb.jpg` | Thumbnail, ~100px |

Images are compressed in the app before upload. Storage rules mirror the Firestore access table.

---

## 6. Later phases (shape only, detailed when reached)

| Collection | Phase | Key fields |
|---|---|---|
| `fixtures/{fixtureId}` | 4 | homeTeamId, awayTeamId, date, venue, refereeId, status |
| `teamSheets/{sheetId}` | 3 | fixtureId, teamId, starters[], subs[], formation, captainId, createdAt |
| `matchReports/{reportId}` | 4 | fixtureId, homeScore, awayScore, scorers[], cards[], notes, signedSheetPhoto, status |
| `matchEvents/{eventId}` | 7 | fixtureId, minute, type, teamId, playerId |
| `standings/{teamId}` | 5 | Calculated from approved reports only, updated when a report is approved |

---

## 7. Open questions for GEDFA

- Squad size, matchday substitutes, any age categories
- Registration window; adding players mid-season
- One team admin or several per team
- Player transfers between teams during a season
- Retention rules for player data

---

## 8. Changelog

| Date | Change |
|---|---|
| 13 Oct 2026 | v1 agreed: Phase 1 collections, reservation docs for jerseys and duplicate players, `adminUids` as a list, single `players` collection. |
