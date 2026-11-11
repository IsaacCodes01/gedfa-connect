# GEDFA Connect — Data Model

**Status:** v2.34.1, matches the rules after step 3.2, team sheets visible to the FA and, from the lock, the opponent (11 Nov 2026)
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

- **Photo kits (2.13b):** instead of a design, a kit can be photos of the real shirt, shorts and socks: `photos: { shirt, shorts, socks }` (download links). Its colours are saved as white; the team's colours come from `colours`.

### Official shape

```
{ role: "headCoach", name: "Kofi Mensah", phone: "+233241234567", licence: "CAF D" | null }
{ role: "other", title: "Welfare officer", name: "Yaw Darko", phone: "+233201112222", licence: null }
```

- `role`: `teamManager`, `headCoach`, `assistantCoach`, `chairman`, `secretary`, `kitManager`, `medicalOfficer` or `other`.
- `teamManager` and `headCoach` are required on every team request and team. **At most 7 officials** (2 required + up to 5).
- `other` means the role isn't in the list: `title` holds the role the club typed (2–40 characters). Only `other` can appear more than once.
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
| `createdBy`   | string    | `uid` of the FA admin who gave it (team admins) |
| `name`        | string    | FA officials and referees: full name (for People and roles) |
| `inviteId`    | string    | FA officials and referees: the accepted invitation (= their email) |
| `isChairman`  | boolean   | **Set by hand in the console** on the chairman's document only. Never written by the app |

- **No document = no role.** A new sign-up has no document and is routed to "Register your team".
- Written **only by an FA admin**. A user can `get` their own document (never list or query users) and never write it. FA admins can `get` any user document.
- **Approving a team** creates the club's document with only `role: teamAdmin`, `teamId`, `createdAt`, `createdBy` (the FA's uid). The rules allow **create only** (never update), **only** the `teamAdmin` role, and only for an admin of the team created in the same batch. **Nobody can be made an FA admin through the app**: FA admins are still created by hand in the console.
- A person's **full name** lives on their Firebase Auth account (`displayName`), set at sign-up and editable on My profile; `displayName` and `email` here are optional copies.
- The app listens to this document live: when the FA changes a role, the app moves the user to the matching home screen at once.
- The first FA admin is created by hand in the Firebase console (see step 0.7), with `isChairman: true`, `name` and `email`.
- **Invitations (2.6):** an invited person creates **their own** document when accepting, with only `role`, `name`, `email`, `inviteId`, `createdAt`. The rules check that their confirmed email has an open invitation for exactly that role, accepted in the same batch. One role per account (create only).
- **Removing a role** deletes the document (the account stays, now with no role). Referees: any FA admin. FA officials: the chairman only. Never yourself, never the chairman. FA admins can **list** users (People and roles).

### 2.1a `invites/{email}` — invitations (2.6)

The document ID is the invited email in lower case, so an email has at most one invitation and the invited person finds theirs with one `get`.

| Field           | Type      | Notes |
| --------------- | --------- | ----- |
| `email`         | string    | Same as the ID |
| `name`          | string    | 3–80 characters |
| `role`          | string    | `faAdmin` (FA official) or `referee` |
| `status`        | string    | `pending`, then `accepted` |
| `invitedBy`     | string    | FA admin `uid` |
| `invitedByName` | string    | Shown to the invited person |
| `createdAt`     | timestamp | |
| `expiresAt`     | timestamp | 14 days after `createdAt` (the rules allow 13–15 for clock differences) |
| `acceptedBy`, `acceptedAt` | string, timestamp | Set when accepted |

- Create: FA admins; **FA officials invite referees only, the chairman invites both**. No email is sent: the FA shares a ready-made message on WhatsApp or by text.
- Accept: only the person whose **confirmed** email is the ID, while pending and not expired.
- Cancel (delete): FA, same who-can-invite rule. Decline (delete): the invited person. An accepted invitation is deleted when the role is removed, so the person can be invited again.

### 2.1b `roleLog/{id}` — role history (2.6)

| Field | Notes |
| ----- | ----- |
| `email`, `name`, `role` | Who and which role |
| `action` | `invited`, `cancelled`, `removed` (by the FA) or `accepted`, `declined` (by the invited person) |
| `uid` | The person's uid, once known |
| `by`, `byName`, `at` | Who did it and when (`at` = server time) |

Written in the **same batch** as every change; FA admins can read it; never edited or deleted.

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
| `logoUrl`              | string           | **Required** (2.13); Storage download URL                                                                                         |
| **Competitions**   |                  |                                                                                                                                   |
| `categories`           | array of strings | Required. 1 or 2 items from`division`, `juvenile`, no repeats. `juvenile` means all three age groups (U13, U15, U17) until step JA, when the club picks its age groups (Section 7, 10 Nov 2026) |
| **Club status** (2.13) |              |                                                                                                                                   |
| `clubStatus`           | string           | Required: `existing` (already in Gomoa East) or `new` (joining the district). Older requests are read as `existing`               |
| `lastLeague`           | string?          | `new` only, required: the league played in last season (2–80 characters). Must be empty for `existing`                           |
| `letterUrl`            | string?          | `new` only, required: the letter to the GEDFA chairman (PDF, Storage download URL). Must be empty for `existing`                   |
| `licenceUrl`           | string?          | Optional club licence (photo or PDF)                                                                                              |
| `licenceType`          | string?          | `pdf` or `image`; set exactly when `licenceUrl` is set                                                                            |
| **Officials**      |                  |                                                                                                                                   |
| `officials`            | array of maps    | Officials (see Official shape); must include`teamManager` and `headCoach`; 2 to 7                                              |
| **Kits**           |                  |                                                                                                                                   |
| `kits`                 | map              | `home`, `away`, `goalkeeper` required; `third`, `goalkeeper2` optional. Each value is a Kit (see Kit shape), designed or photos. A club in one competition (Division **or** Juvenile) has only these |
| `juvenileKits`         | map?             | **Clubs in both competitions only, required** (2.13b): the juvenile sides' own kits, same keys as `kits`. Must be empty for a club in one competition |
| `juvenileName`         | string?          | **Clubs in both competitions only, optional** (JSb, mockup JS1b): the juvenile sides' own name, 2–60 characters. Empty = "B" (the club's name + " B"). Must be empty for a club in one competition |
| `juvenileShortName`    | string?          | Required with `juvenileName`, empty without it: 3–4 capitals, not the club's `shortName` |
| `juvenileNameKey`      | string?          | Required with `juvenileName`: its reservation key in `teamNames` (same key format), not the club's `nameKey`. Reserved for this club in the same batch |
| **Colours** (2.13b)  |                  |                                                                                                                                   |
| `colours`              | map              | Required: `{ home: { main, second }, away: { main, second } }`, each `#RRGGBB`. Suggested from the designed home and away kits |
| **Declaration**    |                  |                                                                                                                                   |
| `agreedToRules`        | boolean          | Must be`true`                                                                                                                   |
| **Review**         |                  |                                                                                                                                   |
| `status`               | string           | `pending` / `approved` / `rejected`                                                                                         |
| `rejectionReason`      | string?          | Set only by the FA when rejecting; cleared when the team resubmits                                                                |
| `createdAt`            | timestamp        | Set once on create                                                                                                                |
| `updatedAt`            | timestamp        | Set on every write                                                                                                                |

- Only a person with a **confirmed email** may create a request (Google accounts count as confirmed).
- The requester may create it, and edit it **only while `pending` or `rejected`**. Every edit sets `status` back to `pending` and clears `rejectionReason`.
- Only an FA admin may set `status` to `approved` or `rejected`, and only on a `pending` request. Review fields, written only by the FA:

| Field          | Type      | Notes                                                   |
| -------------- | --------- | ------------------------------------------------------- |
| `reviewedBy` | string    | uid of the FA admin who approved or rejected            |
| `reviewedAt` | timestamp | When                                                    |
| `teamId`     | string?   | Set on approval: the team created from this request     |

- **Reject:** `status: rejected` + `rejectionReason` (10–500 characters). The club sees the reason, edits and resends (back to `pending`, reason cleared; the review fields stay but the club can never change them).
- **Approve:** see Section 4. An approved request is never edited again; later changes to the team go through change requests (planned, ROADMAP 2.10–2.11).
- One club = one request, whatever it plays in. A club in both competitions registers **once** and ticks both; name, logo, kits and officials are shared.
- Requests saved before `categories` existed are read as `["division"]` by the app; the next edit saves the field.
- The registration steps are: Club details › Club status › Officials › Kits › Colours › Payment, then Review (2.13).
- On approval the team also gets `clubStatus`, `licenceUrl`, `licenceType`, `juvenileKits` and `colours`. The letter and last league stay on the request.
- `season` (`2026-27`): the season this registration is for; its fee must be started before approval (Section 2.11).

### 2.2a `teamNames/{nameKey}` — team name reservations

Stops two teams registering the same name, without letting anyone read other teams' requests.

**Key format:** trim, lowercase, collapse repeated spaces, replace spaces with `-`, remove anything that isn't `a–z`, `0–9` or `-`. Example: `Gomoa  United FC` → `gomoa-united-fc`.

| Field         | Type      | Notes                            |
| ------------- | --------- | -------------------------------- |
| `uid`       | string    | The requester who holds the name |
| `teamId`    | string?   | Only on a name the FA approved for an existing team (2.10b) |
| `createdAt` | timestamp |                                  |

- Created **only if it doesn't exist**, in the **same batch** as the team request.
- **New club name (2.10b):** the FA's approval reserves the new name for the club (`uid` = the team's `requestUid`, `teamId` set), in the same batch. The old name stays reserved for the club too (the team ID is still the old key). A reservation with `teamId` is never deleted by the club.
- If the team name changes while pending or rejected, the old reservation is deleted and the new one created in the same batch.
- **Juvenile side's own name (JSb):** reserved the same way, under the request's `juvenileNameKey` (`uid` = the club), in the same batch as the request. It blocks a club name and another juvenile name alike. Changing it, or going back to "B", frees the old one in the same batch. The club cannot delete a reservation its request still uses (club name or juvenile name).
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
| `lastCorrectionId`     | string?          | The FA's latest correction (`corrections/{id}`, 2.11a)     |
| `suspension`           | map?             | Set by the chairman (2.11c): `id`, `reason`, `since`, `until` (null = until lifted), `byUid`, `byName` |
| `juvenileName`         | string?          | **Club in both competitions only** (juvenile side names): its juvenile sides' own name (U13, U15 and U17 alike). Absent = they play as `name` + " B" ("Royal Unique FC B"). Set only by the FA (registration JSb, change request JSc); never by a direct team edit |
| `juvenileShortName`    | string?          | Only with `juvenileName`: 3–4 capitals. Absent = `shortName` + " B" ("RUF B") |
| `createdAt`            | timestamp        | Approval time                                              |
| `updatedAt`            | timestamp        |                                                            |

- Created **only by the FA's Approve button** (since 2.2), in the same batch as the approval. The **team ID is the reserved name key** (e.g. `gomoa-united-fc`), so it is unique. The rules check: `nameKey == teamId`, `adminUids == [requestUid]`, the reservation belongs to that club, and the request becomes approved in the same batch.
- **Team profile edits (2.10a):** the team's admin may change `town`, `homeGround`, `homeGroundDirections`, `colours`, `kits`, `juvenileKits` (club in both competitions only) and `officials` (2–7) straight away; each part is validated when it changes. Each save writes a `teamUpdated` note to the FA's bell in the same batch.
- **Change requests (2.10b):** name, short name, logo and competitions change only when the FA approves a `teamChanges` request (Section 2.3a). The FA's batch may change only that kind's fields, to exactly what the team asked: `name` + `nameLower`; `shortName`; `logoUrl`; or `categories` (+ `juvenileKits`). Until then the old details are used everywhere. The team ID never changes.
- **Adding a competition:** a Division club adding Juvenile gets `categories: [division, juvenile]` and no juvenile kits yet (it adds them in Kits › Edit). A Juvenile club adding Division keeps its `kits` as its `juvenileKits` (copied in the approval) and as its Division kits until it edits them.
- **Open question for GEDFA (6 Nov 2026):** does adding a second competition mid-season change the season fee? For now: no, GH₵ 1,000 per club.
- **FA corrections (2.11a):** the FA may correct **misspellings and obvious mistakes** itself: `name` + `nameLower`, `town`, `homeGround`, `homeGroundDirections`, `yearFounded`, `email`. Each correction sets `lastCorrectionId` and writes its log line (Section 2.3b) in the same batch; the rules check the log lists exactly the changed fields. A new spelling of the name is reserved in `teamNames` for the club (refused if another club holds it) and copied to every player's `teamName`. **Officials (sensitive data), kits and colours are never corrected by the FA**: it asks the team (2.11b). Short name, logo and competitions stay change requests (2.10b).
- `logoUrl` reuses the request's logo download link (it keeps working). Copying the file to `teams/{teamId}/logo.jpg` needs a server function and is deferred.
- FA admins can `get` and `list` teams; a team admin can `get` only their own.
- Teams created by hand during Phase 1 testing may lack some fields.

### 2.3a `teamChanges/{teamId}_{kind}` — change requests (2.10b)

A team asks the FA to change its name, short name or logo, or to add the competition it is not in yet. The ID is the team and the kind (e.g. `royal_name`), so a team has **at most one request of each kind**. Asking again after the FA decided replaces the old request, so only the latest decision of each kind is kept.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `teamId` | string | |
| `teamName` | string | The team's name when it asked (must match the team) |
| `kind` | string | `name`, `shortName`, `logo`, `competition` or `juvenileName` (JSc, clubs in both only) |
| `from` | string? / array | The value now: name, short name, logo link (may be null), or the `categories` list |
| `to` | string | The new name (2–60), short name (3–4 capitals), logo link, or the competition to add (`division` / `juvenile`, not one the club is in) |
| `nameKey` | string? | `name`, and a juvenile side's own name (`juvenileName`, or `competition` with `juvenileName`): the name's key, not the team ID. Refused if another club holds that reservation |
| `fromShortName`, `toShortName` | string | `juvenileName` only: the juvenile side's short name now ("RUF B") and asked for ("RUC"). `from` must be how the side plays now (`sideNamesOf`). `to` = `''` and `toShortName` = `''` = back to "B" (only for a side with its own name) |
| `juvenileName`, `juvenileShortName` | string? | `competition` adding Juvenile only (JSc): the juvenile side's own name, asked in the same request. Absent = it plays as "B" |
| `reason` | string | "Why? (for the FA)", 5–300 characters; for `juvenileName` it may be empty (mockup JS3b, "Why (optional)") |
| `status` | string | `pending` → `approved` or `rejected` |
| `askedBy`, `askedByName` | string | The team admin's uid and name |
| `rejectionReason` | string? | FA, 10–500 characters ("Not approve") |
| `reviewedBy`, `reviewedAt` | | FA |
| `createdAt`, `updatedAt` | timestamp | |

- **Ask:** the team's admin only, for its own team, while no request of that kind is pending. Same batch: a `changeRequested` note in the FA's bell. A new logo is uploaded first to `teams/{teamId}/logo-<millis>.jpg`.
- **Approve (FA):** one batch: the request `approved` + the team's field(s) + the bell note `changeApproved` for the team. A **name** also updates `teamName` on every player of the team (player IDs never change) and reserves the new name in `teamNames`. The rules check that the team really has the new value after the batch.
- **Juvenile side name (JSc):** approving writes `juvenileName` / `juvenileShortName` on the team (or deletes them for "B") and reserves the own name in `teamNames` (`uid` = the club, `teamId`), in the same batch; "Add Juvenile" with a name does the same with `categories`. The rules check the team has exactly the asked name after the batch.
- **Reject (FA):** `rejected` with a reason + `changeRefused` for the team. The team page shows the reason (red) for a week; the team may ask again.
- **Approve all (2.10c):** the app approves a team's waiting changes one after another (oldest first), each in its own batch as above, because the rules allow only one kind of change per team update. A name another club holds is skipped.
- The FA sees the requests grouped by team (Teams › Changes, one card per team).
- Read: the team's admins (query by `teamId`) and FA admins.

### 2.3b `teams/{teamId}/corrections/{id}` — the FA's corrections log (2.11a)

One line per correction the FA makes itself. Written in the same batch as the correction (the team's `lastCorrectionId` points at it); **never edited or deleted**.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `section` | string | `name` or `details` |
| `fields` | array of strings | The team fields that changed (1–12), e.g. `homeGround`; `nameLower` is not listed |
| `lines` | array of strings | What the team reads (1–20), e.g. `Home ground: Apam Prk → Apam Park` |
| `reason` | string | "What was wrong?", 5–300 characters; the team sees it |
| `nameKey` | string? | `name` only: the key of the new spelling |
| `byUid`, `byName` | string | The FA official |
| `createdAt` | timestamp | |

- Same batch: the team's bell `teamCorrected` ("The FA corrected your team profile", one per team and day).
- Read: FA admins and the team's admins.

### 2.3d `teams/{teamId}/suspensions/{id}` — suspensions (2.11c)

**Chairman only.** A suspension is the team's `suspension` map plus its line here (same `id`), written in one batch. The team stays approved.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `reason` | string | 10–500 characters; the team sees it (same as on the team) |
| `since` | timestamp | |
| `until` | timestamp? | When it ends: the start of the day after the last day the chairman picked (Ghana = UTC). Null: until the chairman lifts it (after the FA board meets the club) |
| `byUid`, `byName` | string | The chairman |
| `liftedAt`, `liftedBy`, `liftedByName` | | Set once, when lifted |
| `liftReason` | string? | `finePaid`, `bondSigned`, `boardDecision` or `other` |
| `liftNote` | string? | Up to 300 characters; required (5+) for `other` |

- **In force** while `suspension` is on the team and `until` is null or still to come. A dated suspension ends by itself: the rules compare `until` with the time of each write.
- **While in force** the rules refuse the team's own writes to `players` (add or edit), `teams` (profile edits) and `teamChanges` (asks). The team still reads everything, pays its fee and sends back corrections. Later: no team sheets (Phase 3).
- **Suspend:** only when not in force (an ended dated one may be replaced). Same batch: `teamSuspended` in the team's bell.
- **Lift:** removes `suspension` from the team and writes `liftedAt` … on its line, in one batch (also for an ended dated one). Same batch: `suspensionLifted` in the team's bell.
- Lines are never deleted. Read: FA admins and the team's admins.

### 2.3c `correctionRequests/{teamId}` — the FA asks a team to correct (2.11b)

What the FA can't (or shouldn't) correct itself: officials (sensitive), kits and colours, players, or club details it isn't sure about. **One per team**; asking again replaces it.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `teamId`, `teamName` | string | `teamName` must match the team |
| `items` | array of strings | 1–4 of `clubDetails`, `officials`, `kits`, `players` |
| `message` | string | "Message to the team", 10–500 characters |
| `status` | string | `asked` → `sentBack` (the team) → `done` (the FA) |
| `round` | number | 1, then + 1 each time the FA asks again |
| `askedBy`, `askedByName`, `askedAt` | | FA |
| `sentBackBy`, `sentBackAt` | | The team admin ("Send back to the FA") |
| `doneBy`, `doneAt` | | FA |
| `updatedAt` | timestamp | |

- **Ask (FA):** creates it (`round` 1), or replaces it after `sentBack` or `done` (`round` + 1); never while the team is still on it (`asked`). Same batch: `correctionAsked` in the team's bell.
- **Send back (team):** only `status`, `sentBackBy`, `sentBackAt`, `updatedAt`, from `asked`. Same batch: `correctionSentBack` in the FA's bell.
- **Done (FA):** only from `sentBack`. Same batch: `correctionDone` in the team's bell.
- The team fixes things with its usual screens (Team profile, players re-checked by the FA as before); this document only carries the request.
- Read: the FA (get and list) and the team's admins (get their own).
- The team sees a yellow banner on its Squad tab while `asked`; the FA sees it in Teams › Changes (sent back ones count in the gold number).

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

- **Juvenile players (2.14)** are added "waiting for screening" (`status: pending`); the FA checks them in person on a screening day (2.14b–c), not in the Players tab. Jersey reservations are per age group (`juvenile-U13-10`), and their player key ends in `_juvenile`, so the same child may also be in the club's Division squad.
- **Screening decisions (2.14c)**: only the FA, only for a pending juvenile player. *Passed*: `status: approved`, a `GJ26-0001` ID from `settings/juvenileCounter` (Division IDs `GE…` are refused for children), in the registered group or an older one (moved up, never down; the jersey reservation moves in the same transaction). *Needs correcting* (2.14d): `status: rejected` with a reason and no `notEligible`; the team fixes it and the child is pending (waiting) again. *Not eligible*: `status: rejected`, `notEligible: true`, a reason (5–500); the team can no longer edit the player, and the player key stays taken, so the child can't be added again in any juvenile group.

One collection for the whole district. Team admins see only their own team's players (enforced by rules on `teamId`); the FA sees all.

| Field               | Type             | Notes                                                                                                                                                                                                                              |
| ------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `teamId`          | string           |                                                                                                                                                                                                                                    |
| `teamName`        | string           | Copied from the team                                                                                                                                                                                                               |
| `category`        | string           | `division` or `juvenile`; must be one of the team's `categories`                                                                                                                                                             |
| `ageGroup`        | string?          | **Juvenile only** (2.14): `U13`, `U15` or `U17`. Age = the season's **start** year − birth year (2026 for 2026/27). Own group or older; never younger; over 17 refused. The app registers a child in the group of the tab they were added from, or moves them **up** to their own group if too old for it (2.14b). Playing up for a match is a team-sheet choice (Phase 3) |
| `guardian`        | map?             | **Juvenile only, required**: `{ relation: mother / father / guardian / other, name, phone }`. Team and FA only |
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
| `screeningDayId`  | string?          | **Juvenile only** (2.14d): the screening day of the FA's last decision. The rules refuse a decision unless that day has started, is under a day old and covers the child's age group. Written only by the FA |
| `notEligible`     | bool?            | **Juvenile only** (2.14c): `true` when the FA found the child not eligible at screening. Written only by the FA |
| `rejectionReason` | string?          |                                                                                                                                                                                                                                    |
| `createdAt`       | timestamp        |                                                                                                                                                                                                                                    |
| `updatedAt`       | timestamp        |                                                                                                                                                                                                                                    |
| `approvedAt`      | timestamp?       |                                                                                                                                                                                                                                    |
| `approvedBy`      | string?          | FA admin`uid`                                                                                                                                                                                                                    |
| `reviewedAt`      | timestamp?       | When the FA last **rejected** the player (approval uses `approvedAt`)                                                                                                                                                              |
| `reviewedBy`      | string?          | FA admin `uid` who rejected                                                                                                                                                                                                        |
| `changes`         | map?             | What the team changed since the FA last reviewed (re-check or resubmission), e.g. `{jerseyNo: {from: '#10', to: '#14'}, photo: {from: <old link>, to: <new link>}}`. Keys: `fullName`, `dob`, `jerseyNo`, `position`, `photo`; at most 8. The first `from` is kept over several saves; a field changed back is dropped. The FA's approval or rejection **must** delete it. While a photo change waits, the old photo file is kept so the FA can compare |

- After approval, changing `fullName`, `dob`, `jerseyNo` or the photo sets `status` back to `pending` (FA re-approval). Changing only `position` keeps it approved. `playerCode` never changes.
- Created by the team admin with `status: pending` and no `playerCode`, `approvedAt` or `approvedBy`. A team may hold at most `settings/league.maxSquadSize` players per competition (checked in the app; 30 for now).
- **No passport photo, no player:** the rules refuse a player without `photoUrl` and `thumbUrl`.
- An approved player stays approved only if the edit changes nothing but `position` (and `positionGroup`). Any other change must set `status` back to `pending`.
- A team admin can't change `teamId`, `category`, `playerCode`, `approvedAt`, `approvedBy`, `reviewedAt`, `reviewedBy` or `createdAt`, and can't delete a player (removing players comes later).
- **FA review (2.3):** the FA may change a **pending** player only. *Approve* touches only `status`, `playerCode`, `approvedAt`, `approvedBy`, `rejectionReason` (null) and `updatedAt`. *Reject* touches only `status`, `rejectionReason` (10–500 characters), `reviewedAt`, `reviewedBy` and `updatedAt`. The FA never edits the player's details.
- **Re-check:** a player approved before and then changed by the team comes back as pending **with** their `playerCode`; approving again keeps that ID and leaves the counter alone.
- Only Division players can be added for now; Juvenile waits for GEDFA's answers.
- **Juvenile players:** the age group (U13 / U15 / U17) is **calculated** from `dob` and the season's cut-off date, never stored as typed input. Extra fields planned, pending GEDFA: birth certificate photo, parent or guardian name and phone, consent. Juvenile player photos are **never shown publicly**.
- Only an FA admin may set `status` to `approved` or `rejected`.
- **Team renamed (2.10b):** the FA's approval of a new club name updates `teamName` (and nothing else) on every player of the team, in the same batch; the rules allow it only when it equals the team's new name.

### 2.4c `playerProfiles/{playerId}` — football details (2.3d)

Kept by the team, **no FA approval**, never part of the registration. Private: the team and FA admins only. No document = nothing filled in, Available.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `teamId` | string | Must be the player's team |
| `heightCm`, `weightKg` | number? | 120–220 cm, 35–130 kg |
| `foot` | string? | `left` / `right` / `both` |
| `otherPositions` | array | Up to 2 position codes ("can also play") |
| `strengths` | array | Up to 3 of `pace, strength, stamina, dribbling, passing, finishing, heading, tackling, setPieces, leadership` |
| `hometown`, `previousClub` | string? | ≤ 60 / ≤ 80 characters |
| `clubSince` | number? | Year, 1980 to this year |
| `availability` | string | `available` / `injured` / `unavailable`. **No medical details** are stored anywhere |
| `unavailableReason` | string? | Only when `unavailable`: `away`, `family`, `workOrSchool`, `clubDiscipline`, `other`. A reason, never details |
| `expectedBack` | timestamp? | Only while not available |
| `availabilityAt` | timestamp | When the availability last changed |
| `emergencyName`, `emergencyPhone` | string? | Private. **Required for Juvenile players** (later) |
| `updatedAt` | timestamp | |

#### Subcollection `teams/{teamId}/armbands/{category}` — captain and vice-captain

`captainId`, `viceCaptainId` (player IDs or null), `updatedAt`. One document per competition, so there is only ever one captain and one vice-captain; both must be players of that team and competition, never the same player. The team sheet (Phase 3) fills them in and can change them for one match.

### 2.4d `squads/{teamId}_{group}` — squad lists for team sheets (3.1a1)

The IDs of a team's **approved** players, one list per competition: `group` is `division`, or a juvenile age group (`U13`, `U15`, `U17`), e.g. `squads/royal_division`, `squads/royal_U15`. Team sheets (3.1) are checked against it: a sheet has up to 18 players and the rules may look at only 10 to 20 documents per save, so one list = **one lookup** instead of 18.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `teamId` | string | Never changes |
| `group` | string | `division` / `U13` / `U15` / `U17`; never changes. The document ID is `{teamId}_{group}` |
| `players` | map | Player ID → `true`, every approved player of that team and group |
| `changed` | string | The one player added or taken off by the last write |
| `updatedAt` | timestamp | Server time |

- **One player per write**, named in `changed`. The rules keep the list exact:
  - **FA approval** (`approve`) and **screening pass** (`passJuvenile`): the player must be on the list of the group they end in after the same transaction (a child moved up goes on the older group's list). The app reads the list first and adds the player only if missing.
  - **Team edit** that sends an approved player back to pending: the player must leave their list in the same batch (the app reads the list first; a player approved before the lists existed may not be on one).
  - The FA may add an approved player (repair) or take off a player who is not approved. Nobody else writes it.
- Read: the team (its own lists; a missing list may be looked for) and the FA.
- **Repair** (FA › More › League settings › Team sheets › Squad lists › Repair, `PlayerRepository.repairSquadLists`): adds every approved player missing from their list and takes off anyone no longer approved. Needed once for players approved before 10 Nov 2026; safe to run again.

### 2.4d2 `squads/{teamId}_divisionJuveniles` — juveniles in the Division (3.1d1)

A club in **both** competitions names up to **7** of its approved juvenile players who may also play Division matches (Isaac, 11 Nov 2026; like last season's photo album). They still play their juvenile matches. Kept beside the squad lists so a Division team sheet can check them with one more lookup (3.1d2).

| Field | Type | Notes |
| ----- | ---- | ----- |
| `teamId` | string | Never changes |
| `group` | string | Always `divisionJuveniles`. The document ID is `{teamId}_divisionJuveniles` |
| `players` | map | Player ID → age group (`U13` / `U15` / `U17`) when named. At most 7; **at most 1 U13 and 3 U15**, U17 without a limit |
| `changed` | string | The one player named or removed by the last write |
| `updatedAt` | timestamp | Server time |

- **Write: the team admin only** (not the FA), its own team, not while suspended, and only a club whose `categories` hold both `division` and `juvenile`. **One player per write**: named (the player must be on its juvenile squad list for that age group, i.e. approved: 1 lookup) or removed; a player's age group never changes in place. The 7 and the 1 / 3 limits are counted from the map's values (`removeAll`, the rules have no loops).
- **No FA approval** (Isaac): the same batch writes a `divisionJuveniles` note to the FA's bell ("Royal Unique FC: juveniles in the Division", `names` one line per change: "+ Kojo Brew (U15)" / "− Yaw Sam (U17)"); it opens the team's players page, which lists the 7 (read only). The kind is in both notification lists in the rules.
- **Kept exact (3.1d2):** the list only holds approved juveniles. When a juvenile leaves their age group's squad list (the team corrects them: back to pending), the same batch must take them off this list too (rule `isSquadRemoval` → `notInDivisionJuvenilesAfter`); the app does it in `PlayerRepository.update` and tells the FA ("− Esi Mensah (U15, corrected: waits for screening)").
- Read: the team and the FA (the FA sees the 7 at the bottom of the team's players page).
- The app: Squad tab › Division, card "Juveniles in the Division" (DJ1) and the picker (DJ2), `players/data/division_juveniles_repository.dart`.

### 2.4e `teamSheets/{fixtureId}_{teamId}` — team sheets (3.1a2)

A team's sheet for one match. Saved again and again (each save replaces it) until it **locks 1 hour before kick-off**. It can be made **any time before the lock**: no opening time (Isaac, 11 Nov 2026, like the GPL, whose regulations only set a latest time on match day).

| Field | Type | Notes |
| ----- | ---- | ----- |
| `fixtureId`, `teamId` | string | The document ID is `{fixtureId}_{teamId}` |
| `category` | string | `division` / `juvenile`, the match's |
| `ageGroup` | string? | Juvenile only: the match's age group |
| `starters` | array | Player IDs, `minPlayers` (7) to 11 |
| `bench` | array | Player IDs, at most 7 and at most `matchdaySquad` − 11; **only when 11 start** (Isaac, 10 Nov 2026) |
| `captainId` | string | **Must start** (3.1b). Filled from the armbands in Profiles; changing it here changes this match only |
| `viceCaptainId` | string? | Any player on the sheet, not the captain; may be left out |
| `goalkeeperId` | string | **Any starter** (Isaac, 10 Nov 2026); filled when exactly one registered goalkeeper starts; never changes the registered position |
| `numbers` | map | Player ID → shirt number **for this match**, one for every picked player, 1 to 99, no two the same. The usual (registered) `jerseyNo` by default; the registration never changes (3.1b, MS4b) |
| `officials` | array of maps | 2 to 7 copies of the club's officials (`role`, `name`, `title`?, `licence`?; **no phone**): the **team manager first, the head coach second** (3.1b) |
| `players` | map | **A copy of each picked player** (3.2): player ID → `name`, `position` ("CB"), `usual` (registered number), `code`?, `ageGroup`? (juveniles). No photo, no date of birth. Exactly the picked players (rules). The FA and the opponent read the sheet from it, without the club's player files |
| `savedBy`, `savedAt` | | The team admin and server time |

- **Write: the team admin only**, its own team, not while suspended. The match must be `scheduled`, the team in `teamIds`, and `now + 1 h < kickoffAt` (the lock). The same player can't be picked twice, and starting + bench ≤ `matchdaySquad` (18).
- **Players:** every ID must be on the team's squad list (2.4d): the Division list, **or the club's juveniles in the Division** (2.4d2, 3.1d2: one more lookup, only when a juvenile is picked); in a juvenile match the match's age group **and the younger ones** (playing up), with the **GFA limits in a U17 match: at most 1 U13 and 5 U15** (3.1d2, MS6; a U13 in a U15 match has no limit until GEDFA gives one).
- **Lookups:** a sheet save is near the rules' limit of 10 (`exists()` and `get()` of one document count as 2; a U17 match reads 3 age lists), so the user and `settings/league` are read with one `get` each (`isSheetTeamAdmin`, `sheetLeagueValue`): **`settings/league` must exist** for sheets to save.
- **Roles (rules, 3.1b):** the captain and the goalkeeper are in `starters`; the vice-captain (if any) is in `starters` + `bench` and isn't the captain; `numbers` has exactly the picked players, every value in 1–99 (checked against a list, the rules have no loops), all different; `officials` has 2 to 7, `[0]` the team manager, `[1]` the head coach.
- **App only:** injured or unavailable players (Profiles) are picked with a warning.
- **Read:** the team and the FA any time; **the other team of the match from the lock** (`now + 1 h >= kickoffAt`, rule `isOpponentAfterLock`, 3.2); the match officials come with 3.5. A team may look for its sheet before making it, and **list its own sheets** (`where teamId ==` its team, 3.1c: the sheet lines on Home and Fixtures, Needs you, "Use last sheet"); never another team's.

### 2.4a Player ID (`playerCode`)

**Format:** `GE` + two-digit year of first approval + `-` + four-digit running number. Example: `GE26-0042`.

- One running number for the whole district (Division and Juvenile together), so no two players ever share an ID.
- Stays with the person for life: a transfer to another team, or a youth player moving up to the Division side, keeps the same ID.
- Made inside the FA's **approval transaction**: read `settings/playerCounter.next` (1 if the counter doesn't exist yet), write the player with that number, add 1 to the counter. Firestore retries if two approvals happen at once, so numbers are never repeated.
- The rules rebuild the ID themselves (`playerCodeFor` in `firestore.rules`, same as `lib/core/utils/player_code.dart`) and refuse any other ID, a skipped number or a counter that doesn't move on by exactly 1.
- Approving several players at once = one transaction per player, in order.

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

### 2.6 `settings/league` — league settings (2.13d)

A single document, edited in FA › More › League settings. Missing fields use the defaults (the app works before the FA saves anything).

| Field                    | Type    | Default        | Who may change it | Notes |
| ------------------------ | ------- | -------------- | ----------------- | ----- |
| `teamRegistrationOpen`   | boolean | `true`         | any FA admin      | Closed: no new team requests (rules). Existing requests can still be edited |
| `playerRegistrationOpen` | boolean | `true`         | any FA admin      | Closed: no new players (rules). Rejected players can still be corrected |
| `maxSquadSize`           | number  | 30 (11–40)     | any FA admin      | Per competition |
| `matchdaySquad`          | number  | 18 (11–23)     | any FA admin      | Phase 3: 11 starters + 7 on the bench (Isaac, 9 Nov 2026) |
| `matchdaySubs`           | number  | 5 (0–12)       | any FA admin      | Substitutions allowed in a match (match report) |
| `minPlayers`             | number  | 7 (7–11)       | any FA admin      | Team sheet red until reached (Phase 3) |
| `season`                 | string  | `2026-27`      | **chairman**      | A new season starts a new fee for every team |
| `fee`                    | number  | 1000           | **chairman**      | GH₵ per team per season; the rules cap payments at it |
| `momoNumber`             | string  | `0244-***-***` | **chairman**      | Shown on the Payment step |
| `updatedBy`, `updatedAt` |         |                |                   | |

- Readable by any signed-in user. Registration is switched **by hand** (no closing date). Tie-breakers: as the Premier League (Phase 4).
- Every save also writes **`settingsLog/{id}`** `{ by, byName, at, changes: { field: { from, to } } }` (FA only, never edited) and, when registration opens or closes, a `registrationChanged` note in the FA's bell, so every official sees who did it.

### 2.7a `settings/juvenileCounter` — juvenile player IDs (2.14c)

`{ next: 5 }`. FA only; moves on by exactly 1 per child passed at screening, like `settings/playerCounter`. IDs read `GJ26-0001`.

### 2.7 `settings/playerCounter` — player ID numbering

| Field    | Type   | Notes                                                         |
| -------- | ------ | ------------------------------------------------------------- |
| `next` | number | The running number the next approved player gets. Starts at 1 |

Readable and writable only by FA admins. Created with `next: 2` by the very first approval; afterwards it can only go up by exactly 1 at a time.

---

### 2.8 `announcements/{id}` — FA announcements (2.7)

| Field | Notes |
| ----- | ----- |
| `title` (3–80), `body` (10–2000) | Never changed after publishing |
| `to` | `everyone` / `teams` / `division` / `juvenile` / `referees` |
| `important`, `pinned` | booleans; only `pinned` can change later |
| `createdBy`, `createdByName`, `createdAt` | Any FA admin |

- Read by anyone with a role (the app shows each person the ones for them); written, pinned and deleted by FA admins.
- **`seen/{teamId or uid}`** `{at, by}`: written when a team admin (key = team ID) or referee (key = uid) opens it. Only FA admins read it ("Seen by 7 of 12").

### 2.9 `notifications/{id}` — the bell (2.8)

**One document per audience, kind, team and day**, e.g. `team-royal_playersApproved_royal_2026-10-24`. Each event updates it with `count + 1` and one more name, so 20 approvals = 1 notification. **Team requests** for the FA are grouped across clubs: `fa_teamRequest_all_<day>` ("3 new team requests"). The app counts **different names**, so saving the same player twice still reads "1 player".

| Field | Notes |
| ----- | ----- |
| `audience` | `fa` or `team:<teamId>` |
| `kind` | `playersApproved`, `playersRejected`, `teamApproved`, `paymentConfirmed`, `paymentNotFound`, `feeReminder`, `changeApproved`, `changeRefused`, `teamCorrected`, `correctionAsked`, `correctionDone`, `teamSuspended`, `suspensionLifted`, `fixtureAdded`, `fixtureChanged`, `fixturePostponed`, `fixtureCancelled` (for teams, written by the FA); `teamRequest`, `playersSubmitted`, `playersResubmitted`, `juvenileSubmitted`, `inviteAccepted`, `paymentSent`, `teamUpdated`, `changeRequested`, `correctionSentBack` (for the FA) |
| `teamId`, `teamName` | The team concerned (`teamRequest`: the club's uid) |
| `names` | e.g. `Kojo Arthur (GE26-0011)`, `Yaw Boateng: Jersey number #10 → #14` |
| `count`, `day`, `updatedAt` | |

- Written in the **same batch or transaction** as the action. Teams write only `playersSubmitted` / `playersResubmitted` / `juvenileSubmitted` / `paymentSent` / `teamUpdated` / `changeRequested` / `correctionSentBack` for their own team; only the FA writes team notifications.
- Read: the FA reads `fa`; a team admin reads `team:<their team>`.
- Indexes: `audience` + `updatedAt` (desc); announcements `to` + `createdAt` (desc). See `firestore.indexes.json`.

### 2.10 `readMarks/{uid}` — my bell

`notificationsSeenAt` (Mark all read), `reads` (3.0f: the notes and announcements I opened one by one, note ID → its `updatedAt` / `createdAt` when I read it; at most 100, only the IDs still in my bell are kept, emptied by Mark all read) and `hiddenAnnouncements` (pinned cards I closed, up to 30). Mine only.

A note is **unread** when it is newer than `notificationsSeenAt` and newer than its own `reads` time (compared in milliseconds: the web keeps no microseconds). A grouped note that gets one more name has a newer `updatedAt`, so it is unread again.

### 2.11 `payments/{id}` — season fee payments (2.13c)

The affiliation fee is **GH₵ 1,000 every season**, paid to GEDFA's MoMo (number to come: `0244-***-***`), **in parts if needed**. The club sends each payment; the FA confirms it against its own records. Payments are never rejected: "not found" is only for an ID that isn't on the FA's statement, or details that are false.

| Field        | Type       | Notes |
| ------------ | ---------- | ----- |
| `requestUid` | string     | The club's account (its `teamRequests` ID) |
| `teamId`     | string?    | Set on payments made after approval |
| `teamName`   | string     | |
| `season`     | string     | `2026-27` |
| `method`     | string     | `momo` (MoMo or bank), `cash`, `before` (already paid before the app) |
| `amount`     | number?    | Whole cedis, 1–1,000. Required for `momo` and `cash`; for `before` the FA fills it in when confirming |
| `reference`  | string?    | `momo` only, required: the transaction ID (4–30 characters) |
| `paidOn`     | timestamp? | `momo` only, required: the day it was paid |
| `paidWhen`   | string?    | `cash`: "about when", optional |
| `paidTo`     | string?    | `cash`: who received it, optional |
| `proofUrl`   | string?    | Screenshot of the payment message, optional |
| `status`     | string     | `waiting` → `confirmed` or `notFound` |
| `receiptNo`  | string?    | Set when confirmed: `GEDFA-2026-0014` (season start year + 4 digits from `settings/receiptCounter`) |
| `reason`     | string?    | `notFound` only (5–300 characters); the club sees it and can send again |
| `recordedBy` | string     | `club`, or `fa` for cash the FA recorded itself (confirmed straight away) |
| `createdBy`, `createdAt`, `reviewedBy`, `reviewedAt` | | |
| `editedBy`, `editedAt` | | FA-recorded cash only: the FA corrected the amount (receipt unchanged, total changed by the difference) |

- The first payment is sent in the **same batch** as the team request.
- **Confirm** is one transaction: the payment (`confirmed`, `receiptNo`, `amount`), `settings/receiptCounter` + 1, and `fees/{season}_{uid}.confirmed` + amount. The rules check the receipt number and the new total.
- **Not found** on a pending registration with nothing confirmed yet also **rejects the request** in the same batch (`rejectionReason`: "Payment not found: …"); the club must send a new payment when it resends.
- **After approval** the team adds payments from More › Season fee (`teamId` set; the FA's bell gets `paymentSent`). Confirming, "not found" and recorded cash for an approved team go to the team's bell in the same transaction or batch (`paymentConfirmed`, `paymentNotFound`). The FA's **Send reminder** writes `feeReminder` ("GH₵ 400 left"): one a day at most. Automatic reminders every 3 days come with phone push, before the pilot.
- The FA can **approve a team only after a payment is confirmed** (`fees/{season}_{uid}.confirmed > 0`; checked by the rules). The approval adds `teamId` to that fees document.

### 2.12 `fees/{season}_{uid}` — confirmed total per club and season

`{ season, requestUid, teamName, teamId?, confirmed, updatedAt }`. Written only by the FA, in the same transaction as each confirmation. The club can read its own (even before it exists). Balance = 1,000 − `confirmed`.

### 2.13 `settings/receiptCounter` — receipt numbering

`{ next: 15 }`. FA only; moves on by exactly 1 per receipt, like `settings/playerCounter`.

### 2.14 `screeningDays/{id}` — juvenile screening days (2.14b)

| Field | Notes |
| ----- | ----- |
| `startsAt` | timestamp, date and start time; must be in the future when saved |
| `venue` | 2–80 characters |
| `groups` | 1–3 of `U13`, `U15`, `U17`, no repeats |
| `note` | optional, ≤ 200: "what to bring" |
| `announcementId` | the announcement saved with it (`to: juvenile`) |
| `season` | e.g. `2026-27` |
| `createdBy`, `createdAt` | the FA admin, server time |

- Read by anyone with a role; created and deleted (cancelled) by FA admins; never edited (cancel and add again).
- The team's blue "Juvenile screening" card shows each day until midnight after it.

### 2.15 `fixtures/{fixtureId}` — matches (3.0a)

One match. Made by the FA (one at a time in 3.0a; "Make the season" and cups follow in 3.0b and 3.0c). Read by everyone with a role. **Never deleted**: a called-off match is cancelled.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `season` | string | `2026-27`; never changes |
| `competitionId` | string | League matches: `<season>_division-league` or `<season>_juvenile-league`; cup matches: the cup's ID in `cups` (from the draw, 3.0c2); never changes |
| `category` | string | `division` / `juvenile`; never changes |
| `ageGroup` | string? | **Juvenile only**: `U13`, `U15`, `U17`; never changes. Absent for Division |
| `round` | number | The matchday, 1 to 99 |
| `teamIds` | array | `[home.id, away.id]`, exactly (teams query their matches with `array-contains`) |
| `home`, `away` | map | `{ id, name, shortName, logoUrl, colour }`: a **copy** of the team (teams can't read other teams). The rules check it matches the team document as it is now, and that the team plays this competition. In a **juvenile** match a club in both competitions is copied with its juvenile side's name: `juvenileName` / `juvenileShortName`, or `name` + " B" / `shortName` + " B" (rules `sideNamesOf`, app `side_name.dart`). A short name ending in " B" marks a "B" side (gold ring on its crest) |
| `kits` | map | `{ home, away, homeGk, awayGk }`, each `{ slot, kit }`: which of the team's kits it wears and that kit **exactly as on the team** (juvenile kits for a club in both competitions). Outfield slots `home`/`away`/`third`, goalkeeper slots `goalkeeper`/`goalkeeper2` |
| `previousNames` | map? | **JSc2:** team ID → `{ name, until }`: the team's name in this match before the FA approved a new club name or juvenile side name, and when (the gold "Previously …" pill and its note, for everyone). Only the FA's rename sets it; a new match has none; a normal change keeps it as it is |
| `kickoffAt` | timestamp? | Empty only while **postponed** with no new date |
| `venue` | string | 2–80; the home team's ground unless the FA changes it |
| `status` | string | `scheduled` → `postponed` → `scheduled` again, or `cancelled` (final) |
| `note` | string? | Up to 200. The reason; **required** (3–200) when postponed or cancelled |
| `createdBy`, `createdAt`, `updatedBy`, `updatedAt` | | Who and when (server time) |

- **Create (FA):** always `scheduled`, kick-off in the future. Same batch: a history line and `fixtureAdded` in both teams' bells.
- **Update (FA):** season, competition, category, age group and creator never change; a new kick-off is in the future; cancelling keeps the date; a cancelled match is never changed again. Every save re-copies both teams (they may have changed their name, logo or kits since). Same batch: a history line and a note in the bells of every team involved (`fixtureChanged`, `fixturePostponed`, `fixtureCancelled`).
- **Kits (GEDFA, 8 Nov 2026):** the home team keeps its home kit; the away team wears the first of home, away, third whose shirt doesn't clash (then shorts and socks). Two colours clash when their CIEDE2000 colour difference is below **20.5** (`kitClashThreshold` in `kit_clash.dart`): on the 16 kit colours that is yellow–gold, black–navy, maroon–brown, navy–purple, red–orange and red–maroon. Goalkeepers (Law 4) must look different from both teams' outfield shirts; the two goalkeepers may match; the referee's colour is checked when referees are appointed (Phase 4). A goalkeeper clash is a warning, an outfield clash a problem for the FA. Photo kits read the team's home and away colours; third and goalkeeper photo kits have no colours yet (planned). The FA can change any choice.
- **Team sheets** are due `kickoffAt` − 1 hour (GEDFA); nothing is stored for that yet (3.1).
- `fixtures/{id}/history/{entryId}`: `{ what, reason?, by, byName, at }`, written by the FA with each change (the match must exist after the batch). Read by everyone with a role.

### 2.15a `fixtureDrafts/{draftId}` — "Make the season" drafts (3.0b)

A draft the FA saved for later. **FA only** (read, write, delete). ID: `<season>_<category>-league`, plus `_U13` / `_U15` / `_U17` for a juvenile age group.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `season`, `competitionId`, `category`, `ageGroup?` | | As on a match |
| `settings` | map | `{ firstDay, homeAndAway, sundayToo, kickoffHour, kickoffMinute, weeksOff: [{ start, end }] }` |
| `teamIds` | array | Up to 40, in the order of the draw |
| `matches` | array | Up to 1,600 `{ round, homeId, awayId, kickoffAt, venue }`. Not checked one by one: each match is checked when it is published |
| `updatedBy`, `updatedAt` | | |

- **The draw** (`round_robin.dart`): the circle method. Everyone meets everyone once (or once at each ground); nobody plays twice on a matchday; with an odd number one team rests. Measured for 3 to 20 teams: home games differ by at most 2 between teams, nobody is home or away more than 3 matchdays in a row, and two teams never meet again within 2 matchdays (the second half starts one round later).
- **The calendar** (`season_plan.dart`): one matchday a weekend from the first date, skipping weeks off; with Sunday too, half on Saturday and half on Sunday; a team sharing a ground with another that day moves to the other day (a warning says so). Matchdays continue after any already in the league.
- **Publishing** writes the matches 3 at a time (the rules may look up about 20 documents per save), with fixed IDs `<draftId>_md<round>_<home>_v_<away>`, so publishing again after a lost connection skips the ones already saved. Then ONE `fixtureAdded` note per team ("Division League: 34 matches, the first v … on Sat 14 Nov") and the saved draft is removed. Kits are picked for each match by the kit rule.

### 2.15a2 `postponeJobs/{competitionId}` — a league's postpone while it runs (3.0c1d)

Saved **before any match moves**, so a postpone that stopped (no network, the phone died, the FA tapped Later) can be finished later on any phone or laptop, and no match moves twice. **FA only** (read, write, delete). ID: the league, `<season>_<category>-league`, so a league has **one at a time**: a second postpone of it is refused until this one is finished.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `season`, `competitionId`, `category` | | As on a match; the ID must be the competition |
| `name` | string | 3–40, "Division League" |
| `days` | int | 1–365, how many days later |
| `reason` | string | 3–200, the clubs read it |
| `moves` | array | 1–1,600 `{ id, from, to }`: each match and its old and new kick-off, first match first. Never changed |
| `done` | array | The match IDs moved (or skipped: changed by hand since). Starts `[]`, only grows, never longer than `moves` |
| `byName`, `startedBy`, `startedAt`, `updatedBy`, `updatedAt` | | Who started it and when |

- **Moving:** 3 matches per batch (the rules look up both teams of each), each with its history line, and their IDs added to `done` in the **same batch**. Each move has its new kick-off written down, so running it again only sets the same date again.
- **Finished:** one `fixturePostponed` note per club (its next match and the reason), and the job is **deleted** with the last notes. The clubs are told only then (Isaac, 9 Nov 2026). A stopped postpone can only be finished, not undone (Isaac, 9 Nov 2026).

### 2.15b `cups/{cupId}` — cups and galas (3.0c1, 3.0c1b)

A cup or a gala of one season. Made by the FA (C2, C2b); read by everyone with a role. Its matches will be ordinary `fixtures` with the cup's ID as `competitionId` (the draw, 3.0c2). Random ID. The FA **changes** it only before the draw (the same form, filled in; same season, `createdBy` / `createdAt` kept) and **deletes** it at any time: everything goes, the cup, its history and (after the draw) its matches; nothing is kept (GEDFA, 8 Nov 2026).

| Field | Type | Notes |
| ----- | ---- | ----- |
| `season` | string | `2026-27` |
| `kind` | string | `cup`, or `gala`: a one-off straight knockout, one match per tie, at one ground (GEDFA plays one before the season) |
| `name` | string | 3–60, e.g. `GEDFA Cup 2026/27` |
| `category` | string | Who plays: `division`, `juvenile` or `open` (Division and juvenile sides together, like the Ghana FA Cup) |
| `ageGroup` | string? | `U13` / `U15` / `U17`: **required** for `juvenile` (the age group) and `open` (`U17`: only U17 sides play in an open cup, GEDFA); absent for `division` |
| `entries` | array | 2–64 `{ teamId, category }`: every approved team by default, the FA can leave some out. A club in both competitions can have both sides in an open cup. Not checked one by one: each match is checked when the draw saves it |
| `format` | string | `knockout` (with a first round and byes when the number isn't 4, 8, 16, 32, 64) or `groups` (3–5 clubs a group, 6 only when needed; the top 2 go through). A gala: `knockout` |
| `legs` | number | `1` (one match) or `2` (home and away; aggregate, **no away goals**). A gala: `1`. The **final is always one match**, at a ground the FA picks (GEDFA) |
| `level` | string | Level at the end: `penalties`, `extraTime` (then penalties) or `replay` (**only with one-match rounds**; never in a gala) |
| `bracketFrom` | number | The bracket is fixed from the round with this many clubs left: `16`, `8` (quarter-finals), `4` (semi-finals), or `0` = the whole draw at once. Until then each round is drawn after the one before it is played |
| `seeded` | bool | Seeding with pots: the FA ticks the Pot 1 clubs by hand at the draw (the league standings only for a cup made mid-season, once results exist); Pot 1 clubs never meet in that round. Off = fully random; the FA can mix the teams again before the draw. A gala: `false` |
| `stage` | string | `notDrawn` (3.0c1); the draw moves it on (3.0c2) |
| `gala` | map? | **Galas only, required**: `{ ground (2–80), firstDay, lastDay (not before firstDay), kickoffHour, kickoffMinute, gapMinutes (30–240, typed by the FA) }`. One pitch. Absent for a cup |
| `createdBy`, `createdAt`, `updatedBy`, `updatedAt` | | Who and when (server time) |

- **The format** (`cup_format.dart`): straight knockout, for 18 clubs: 2 first-round ties (4 clubs), 14 byes, then a round of 16. Groups: as few groups (2, 4, 8, 16) as possible; 18 clubs → 5, 5, 4, 4, the top 2 to the quarter-finals. The app suggests knockout; groups are offered from 6 clubs.
- **Postpone (3.0c1c):** a Gala's `gala.firstDay` and `gala.lastDay` move by the same number of days, with a history line ("Postponed 4 weeks: … → …. Why.") and a `fixturePostponed` note for every club in it, in one batch. A league: every match not played yet (`scheduled`, kick-off in the future) gets `kickoffAt` the same number of days later at the same time and `note` = the reason, with a line in `fixtures/{id}/history`; then one `fixturePostponed` note per club. Since 3.0c1d this runs through a saved job (`postponeJobs`, 2.15a2). A cup (not a Gala) is postponed after the draw (3.0c2).
- **`cups/{cupId}/history/{lineId}`** (3.0c1b): one line per change, `{ text (3–200), by, byName (1–80), at }`, written in the same batch as the cup ("Cup made", "Each round: one match → home and away", "Teams: Ojobi Stars left out"). Read by everyone with a role; created only by the FA, with the cup there after the batch; never changed; deleted with the cup. The lines come from `cupChanges` (`cup_changes.dart`).
- **A gala's timetable** (`GalaPlan`): kick-offs every `gapMinutes` from the first kick-off, no later than 4:30 pm (before dark). A round starts 2 slots after the last kick-off of the round before, so every club has a free slot to rest. The form warns when the matches don't fit in the days.

## 3. Who can do what (summary)

The security rules enforce this table. Screens hiding a button is **not** security.

**Rules (live on dev)** cover the *No role* and *Team admin* columns, and the FA admin's team-request and player review work, and invitations, proven by **119 automated tests** in `test/rules/`. The rest of the *FA admin* column (corrections, settings) comes later; the *Referee* column with Phase 4. Anything not listed is refused.

| Collection          | No role                                                             | Team admin                                                                 | Referee                                       | FA admin *(Phase 2)* |
| ------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------- | -------------------- |
| `users`           | Get own (none exists)                                               | Get own                                                                    | Get own                                       | Get / list ✓; create a `teamAdmin` role on approval ✓; remove FA official (chairman) / referee roles ✓ |
| `invites`         | Get own (by confirmed email); accept or decline ✓                  | —                                                                          | —                                            | Create / list / cancel ✓ (officials: referees only) |
| `roleLog`         | Create own accepted / declined line ✓                               | —                                                                          | —                                            | Read; create ✓; never edit |
| `teamRequests`    | Create (confirmed email) / get / edit own while pending or rejected | Get own                                                                    | —                                            | Get / list all ✓; approve or reject pending ✓ |
| `teamNames`       | Get any key; create / delete own                                    | Get any key                                                                | Get any key                                   | Read / delete all    |
| `teams`           | —                                                                  | Get own team *(editing later)*                                             | Read                                          | Get / list ✓; create on approval ✓; edit later |
| `teams/*/jerseys` | —                                                                  | Get / create / delete for own team                                         | —                                            | Get any ✓            |
| `players`         | —                                                                  | Create / read / edit own team's (never status, player ID or team); no delete yet | Read players in assigned matches*(Phase 4)* | Read / list all ✓; approve or reject pending ✓ |
| `playerKeys`      | —                                                                  | Get any key; create / delete for own team's players                        | —                                            | Get any key ✓        |
| `settings/playerCounter` | —                                                           | —                                                                          | —                                            | Get ✓; create / +1 in the approval ✓ |
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
| Correct name or DOB                   | update player (back to`pending`) + delete old player key + create new player key + take an approved player off their squad list (3.1a1) |
| Remove player *(later)*               | delete player + delete jersey doc + delete player key                                         |
| Submit team request                   | create`teamRequests/{uid}` + create `teamNames/{nameKey}`                                 |
| Rename team while pending or rejected | update request + delete old`teamNames` doc + create new one                                 |
| Edit the team profile (team admin)    | update `teams/{teamId}` (only the fields of one section + `updatedAt`) + FA notification `teamUpdated` |
| Ask the FA to change (team admin)     | set `teamChanges/{teamId}_{kind}` (pending) + FA notification `changeRequested`               |
| Approve a change (FA)                 | update the request (`approved`) + update `teams/{teamId}` (that kind's fields only) + team notification `changeApproved`. A new name also: update `teamName` on every player of the team + create `teamNames/{newKey}` (`uid`, `teamId`) |
| Not approve a change (FA)             | update the request (`rejected`, `rejectionReason`) + team notification `changeRefused`         |
| Approve team request (FA)             | update request (`status: approved`, `teamId`, `reviewedBy`, `reviewedAt`) + create `teams/{teamId}` + create `users/{uid}` (`role: teamAdmin`) |
| Reject team request (FA)              | update request only (`status: rejected`, `rejectionReason`, review fields)                    |
| Approve player (FA) — **transaction** | read player (must be pending) + read the squad list + read counter → update player (`approved`, `playerCode`, `approvedBy`, `approvedAt`) + set / update counter (`next + 1`) + add the player to `squads/{teamId}_division` (3.1a1). A player who already has an ID keeps it and the counter is not touched |
| Reject player (FA)                    | update player only (`status: rejected`, `rejectionReason`, `reviewedBy`, `reviewedAt`)        |
| Pass a child at screening (FA) — **transaction** | read the child (must be pending) + the new jersey doc if moving up + the squad list of the group they end in + the juvenile counter → update player (`approved`, `GJ…` ID, `ageGroup`) + move the jersey reservation if moving up + counter `next + 1` + add the child to `squads/{teamId}_{ageGroup}` (3.1a1) + team notification |
| Child not eligible (FA)               | update player (`rejected`, `notEligible: true`, reason) + team notification                    |
| Save a screening day (FA)             | create `announcements/{id}` (`to: juvenile`) + create `screeningDays/{id}` pointing to it      |
| Cancel a screening day (FA)           | delete the day + delete its announcement + create a "Screening cancelled" announcement        |

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
| `districts/gomoa-east/teamRequests/{uid}/letter.pdf`                      | New club's letter to the chairman (PDF, under 5 MB) |
| `districts/gomoa-east/teamRequests/{uid}/licence.pdf` or `licence.jpg`    | Optional club licence (PDF or photo, under 5 MB)    |
| `districts/gomoa-east/payments/{uid}/proof-<millis>.jpg`                 | Payment screenshot (optional), under 1 MB |
| `districts/gomoa-east/teamRequests/{uid}/kits/<set>-<slot>-<part>-<millis>.jpg` | Kit photo, e.g. `division-home-shirt-…`; shirt 600×600, shorts 600×360, socks 360×600, JPEG, under 1 MB |
| `districts/gomoa-east/teams/{teamId}/logo-<millis>.jpg`                   | A new logo the team asks for (2.10b), image under 1 MB. Used only once the FA approves; a refused one stays unused |
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

**Answered by GEDFA (27 Oct 2026):** squad up to 30 (fewer is fine); matchday squad up to 16 (fewer is fine); 5 substitutes; normal jersey rules; registration window not open yet; tie-breakers as the English Premier League; officials up to 7 (team manager and head coach required); logo required; licence and owners optional; third kit and second goalkeeper kit optional; new clubs send a letter and their last league; season fee GH₵ 1,000 every season, paid in parts, the FA confirms each payment (no payment is rejected unless it can't be found or is false), reminders every 3 days until paid; juvenile kits are separate; juvenile age group = season **start** year − birth year; younger players may play up (as the GFA); overage players are not allowed.

**Decided by Isaac (7 Nov 2026), for 2.11:** the FA corrects only misspellings and obvious mistakes itself (club name, town, ground, directions, year founded, email); officials (sensitive data), kits, colours and players it asks the team to correct. Only the **chairman** suspends a team and lifts a suspension. A suspension stops adding or editing players, profile edits and change requests (later: team sheets); the team still sees everything and pays its fee. It ends on a date (set by the offence) or lasts until the FA board has met the club; the chairman may lift it early, e.g. a fine was paid or a bond was signed.

**Decided by Isaac (7 Nov 2026), for 2.12 and Phase 4:** a squad is "ready" on the dashboard with at least the matchday squad (`settings/league.matchdaySquad`, 16) of approved players. Fourth officials (and other match officials) will take notes during matches, so match reports can record **assists** as well as goals and cards. The FA appoints referees and other officials to each fixture (Phase 4).

**Answered by Isaac (7 Nov 2026), for Phase 3:** simple fixtures come first (3.0), because a team sheet belongs to a match. The FA sees every team sheet and gets a copy. A team sheet must be sent **1 hour before kick-off**. Juvenile play-up follows the GFA limits. The paper sheet follows a standard match sheet until GEDFA's own copy arrives.

**Answered by GEDFA via Isaac (8 Nov 2026):** kit clashes: the home team keeps its home kit and the away team changes (away kit, then third), in the Division and the Juvenile league; goalkeepers must differ from both teams and the referee. On juvenile team sheets, children's photos show only to people signed in for that match (the FA, the referee and the two teams), never on the public QR page.

**Decided by Isaac (8 Nov 2026), fixtures:** competitions (leagues and cups) are made by the app: a league by round robin, a cup by an automatic draw (straight knockout with byes, or groups then knockout, by the number of teams). "Add one match" stays for special cases (friendlies, replays). The FA can change any match the app made (teams, home and away, date, time, venue, round). Postponing asks for the new date and time at once, or later.

**Answered by GEDFA via Isaac (8 Nov 2026), cups:** when the FA creates a cup it chooses the rules: a draw after 90 minutes goes to penalties, extra time then penalties, or a replay; one leg or two legs per round. Who goes through follows normal qualification for the format (group places, then knockout winners). The draw is fully random (no seeding). There is a juvenile cup for each age group (U13, U15, U17).

**Answered by GEDFA via Isaac (8 Nov 2026), cups (2):** each round is drawn after the one before it is played, until the round the FA picks; from that draw on the bracket is fixed (every club knows who it meets if it wins). Byes are drawn at random. Seeding only if the FA wants it: the top clubs in the standings go in Pot 1, the rest in Pot 2. **No away goals**: level on aggregate goes to penalties, or extra time then penalties, as set when the competition is made. Groups: 3 points a win, 1 a draw; level on points by goal difference, goals scored, then head-to-head. Every approved team plays by default; a cup may mix Division and juvenile sides (like the Ghana FA Cup). The FA may also make a **gala**: a one-off straight knockout, one match per tie, no home and away (GEDFA plays one before the season starts). Mockup `3.0c-competitions.html`.

**Answered by GEDFA via Isaac (8 Nov 2026), cups (3):** seeding: the FA ticks the pots by hand; the league standings are used only for a cup made mid-season; otherwise everything is random, and in every cup (not only the pre-season Gala) the FA can mix the teams and mix again before making the draw. An open cup has **only U17** juvenile sides, with Division teams. The **final is always one match**, at a ground the FA picks. A Gala has **one pitch**; the FA sets the times when making it. Team sheets for a cup or Gala are sent before kick-off, but not 1 hour before (less time); a club sends **one sheet for the whole Gala**, reused as it goes through. **Juvenile side names:** a club in both competitions keeps one account and gives its juvenile side its own name, or the same name with "II" or "B" added automatically; a club may still choose separate accounts (a later step).

**GFA colts guidelines 2023/24 (found online, 7 Nov 2026):** U13 players may play for U15 and U15 players for U17; in a U17 match at most 1 U13 player and 5 U15 players. Match length U17 2 × 45, U15 2 × 40, U13 2 × 25 minutes. Not stated: how many U13 players in a U15 match (asked GEDFA).

**Answered by GEDFA via Isaac (8 Nov 2026), cups (4):** the FA can **delete** a cup at any time (even after the draw) and everything goes, nothing is kept. The FA can **postpone** a cup or Gala to a new date, and even the **start of a league** (every matchday not played yet moves by the same number of days); the clubs are told, with the reason. In a seeded cup the **Pot 1 clubs get the byes first** in a first round. **Juvenile side names:** "**B**" is added when a club keeps the same name; the juvenile side gets its own short name only when it gets a new name; a club already in both competitions asks the FA (like a name change), and the name shows everywhere after approval. **Gala team sheets: 20 minutes before kick-off.** Only "Cup" takes a plural ("Cups and Gala").

**Answered by Isaac (9 Nov 2026), juvenile side names** (mockup `juvenile-side-names.html`, JS1–JS6): (1) a "B" side's short name is the club's short name with " B" ("RUF B") where space is tight; (2) an own juvenile name is **reserved** like a club name (`teamNames`); (3) a Division club asking to add Juvenile picks the juvenile name in the same request ("B" by default); (4) after the FA approves a new juvenile name, **every** juvenile match shows it, **played ones too**, with the gold **"Previously Royal Unique FC B"** pill in the top corner, like a renamed team (2.10c, `previous_name_pill.dart`).

**Answered by Isaac (9 Nov 2026), juvenile side names (2):** a club that registered for **Juvenile first** and adds Division later (same name) is treated like any club in both: its juvenile sides get the **"B"** ("Apam Youth B") and the Division side plays under the club's name. This is what JSa already does.

**Answered by Isaac (9 Nov 2026), renamed teams in matches (JSc2):** when the FA approves a new **club name** or a new **juvenile side name** (including a "B" side whose club is renamed), **every match** of that side changes to the new name: played ones **and** upcoming ones, Division and juvenile alike. Each of those matches shows a gold **"Previously <old name>"** pill in its **top-right corner**, and **everyone** who sees the match (both clubs, opponents, referees, the FA) sees it, like a renamed team (2.10c). A team renamed twice (A → B → C) shows **"Previously B"**: the name just before (Isaac, 9 Nov 2026). An FA **spelling correction** (2.11a) is not renamed separately without a pill: as built, its matches keep the old spelling until the FA uses Finish renaming, which adds the pill (Isaac, 9 Nov 2026).

**Answered by Isaac (9 Nov 2026), match day:** a team sheet has **18** players, 11 starters and **7** substitutes (`matchdaySquad` 18; `matchdaySubs` stays the substitutions allowed in a match, 5). Team officials on the sheet: up to 7 of the club's registered officials, team manager and head coach required. **No QR code** on the official sheet. The commissioner can be an FA official (an FA admin account) or a referee. **Player suspensions:** the FA suspends a player by hand for a number of matches, with a reason; automatic suspensions from cards come in Phase 5. **Protest fee: GH₵ 500**, editable in League settings like the season fee and MoMo number (the protest answer time and the public holidays are still to be confirmed by GEDFA).

**Answered by Isaac (9 Nov 2026), Phases 4 and 5:** tie-breakers stay as GEDFA said (27 Oct): the English Premier League order, 3 points a win and 1 a draw, then goal difference, goals scored, then head-to-head. The FA appoints the referees for each matchday, and referees use the app (their own dashboard). The Firebase project is on the pay-as-you-go plan, so Cloud Functions can send phone notifications and fee reminders.

**Answered by GEDFA via Isaac (10 Nov 2026), juvenile age groups:** a club enters one, two or all three juvenile age groups (U13, U15, U17), according to the sides it really has. It can add or drop an age group only **before the season is published**, never after. The juvenile fee is the same whether the club enters one, two or three age groups, and the FA can change it in League settings. A club **cannot** register children in an age group it has not entered (play up only inside the groups it entered). Planned for step JA: `teamRequests` / `teams` gain `juvenileAgeGroups` (1 to 3 of `U13`, `U15`, `U17`), Make the season puts a club only in the age groups it entered, and the rules refuse a juvenile player in another age group.

**Answered by Isaac (10 Nov 2026), team sheets (3.1):** a sheet is 18 = 11 starters + **7 on the bench**, of whom **5 may come on** (`settings/league.matchdaySquad` 18, `matchdaySubs` 5); at least `minPlayers` (7) to start. **A goalkeeper in the starting 11 is required**; otherwise **any number of goalkeepers** (Isaac, 10 Nov 2026, replacing "a second one on the bench"); what matters is that the bench is **never more than 7**. The same 18 / 7, with the play-up limit (1 U13 and 5 U15 in a U17 match), applies to juvenile sheets. **Extra substitute (Isaac, 10 Nov 2026): for head injuries only** (a suspected concussion, as the Laws of the Game since 1 July 2024), in **every competition** (Division, Juvenile, cups and galas); it doesn't count in the 5, and **the other team then gets one extra too** (Isaac, 10 Nov 2026, as the Laws).

**Answered by Isaac (10 Nov 2026), team sheet builder (mockup `3.1-team-sheet.html`, MS1–MS7):** (1) one button, **Save team sheet**: the FA sees the latest save, and the team can change it until it locks 1 hour before kick-off (3.2); no separate Send. (2) A team with only 7 to 10 players may start with them; the **bench opens only when 11 start**. (3) Injured or unavailable players (the team's own Profiles) can be picked, with a warning. (4) The **captain must start**; the vice-captain is any of the 18. (5) **Any starter** may be marked the goalkeeper for the match; this never changes the player's registered position or how players are picked. (6) **Shirt numbers:** most clubs don't own 30 jerseys, so the registered `jerseyNo` stays as the player's **usual number** (still unique in the squad, still FA-checked), and the sheet gives each picked player a **number for this match** (the usual one by default, any other 1–99, no two the same on one sheet), without touching the registration (no FA re-approval); the sheet and the PDF show "usual 17" beside a changed number (MS4b–MS4c, approved by Isaac 10 Nov 2026). (7) The FA suspends players by hand as step **3.1e**. (8) **Cup** team sheets are due 1 hour before kick-off, like the league (this replaces "less than 1 hour"); only a **Gala** is shorter (20 minutes, one sheet for the whole Gala). Build order 3.1a–3.1e agreed; the juvenile play-up screen (MS6) agreed.

**Answered by Isaac (11 Nov 2026), juveniles in the Division (3.1d, mockup `3.1d-division-juveniles.html`):** as with last season's photo album, a club in **both** competitions names **up to 7 of its approved juvenile players** who may also play Division matches; only they can be picked on a Division team sheet, with a pill showing their age group. It is a **season list** the club can change during the season, **chosen by the club alone** (the FA is told; no approval). GEDFA limits on the 7: **at most 1 U13 and 3 U15**, U17 unlimited. Juvenile matches keep their own play-up limits (1 U13 and 5 U15 in a U17 match). The 7 **still play juvenile matches**. Clubs in one competition have no such list. Team sheets have **no opening time**: they can be made any time until the lock (Isaac, 11 Nov 2026).

**Answered by Isaac (11 Nov 2026), player suspensions (3.1e, mockup `3.1e-player-suspensions.html`):** a suspension counts **matches**, not days: the app finds the club's next matches in the calendar and tells the club when the player is back ("Kofi Boateng returns on Sat 30 Nov, against Royal Unique FC"); no date is typed. **Any FA official** can suspend (the chairman may be busy); reasons: red card, violent conduct, yellow cards. The club sees the reason and the matches left.

**Answered by GEDFA via Isaac (10 Nov 2026), fees:** the **Juvenile affiliation fee is separate from the Division one**. A club pays one Juvenile fee whatever the number of age groups it enters; a club in both competitions pays the Division fee too. There is also a **referee fee**, for the Division and for the Juvenile league. Every fee (affiliation and referee) can be paid in instalments, like the affiliation fee today, and its amount is set in League settings. Planned as its own payments step (after JA): today `settings/league.fee` and `fees/{season}_{uid}` hold one affiliation fee per club.

**Decided by Isaac (10 Nov 2026), team dashboard (mockup `td-team-dashboard.html`):** a team is match-ready with the matchday squad (`settings/league.matchdaySquad`, 18) of approved players, per competition and per juvenile age group; with fewer than that but at least `minPlayers` (7) it can still play. Teams land on a new Home tab (Home · Squad · Fixtures · Profiles · More). A club in both competitions gets a Division | Juvenile switch on Home and Fixtures (matches only), and a month calendar (opponent crests on match days; League, Cup, Gala) on Home and in Fixtures. The team sheet line comes in 3.1.

**Answered by Isaac (9 Nov 2026):** when a Gala is postponed **before its draw**, the clubs in it still get the note (they plan around its dates).

Still open:


- Juvenile: coach per age group? Welfare or child-safety officer required?
- Juvenile: age cut-off date per age group, per season
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
| 11 Nov 2026 | v2.34.1: Section 7, Isaac's answers on player suspensions (3.1e). |
| 11 Nov 2026 | v2.34 (3.2): `teamSheets.players` (copies: name, position, usual number, player ID, age group); the opponent reads a sheet from the lock. 411 rules tests. |
| 11 Nov 2026 | v2.33 (3.1d2): a Division sheet may pick the club's juveniles in the Division; in a U17 match at most 1 U13 and 5 U15; the Division list kept exact (a juvenile leaving their age list leaves it too); sheet saves read the user and League settings with one get each (lookup limit). 409 rules tests. |
| 11 Nov 2026 | v2.32.1: notification kind `divisionJuveniles` (team → FA) with one line per change. 406 rules tests. |
| 11 Nov 2026 | v2.32: new `squads/{teamId}_divisionJuveniles` (3.1d1): the club names up to 7 approved juveniles for the Division (at most 1 U13 and 3 U15), one per write, the team only, clubs in both competitions; the FA is told in the bell. 405 rules tests. |
| 11 Nov 2026 | v2.31.1: Section 7, Isaac's answers on juveniles in the Division (3.1d): up to 7 named by the club, at most 1 U13 and 3 U15, they still play juvenile matches. |
| 11 Nov 2026 | v2.31 (3.1c): no new fields or rules; a team lists its own `teamSheets` (new rules test). Needs you shows a sheet not started from 2 days before it is due, red on the day. 396 rules tests. |
| 11 Nov 2026 | v2.30: `teamSheets` (3.1b) adds `captainId` (starts), `viceCaptainId` (optional, on the sheet), `goalkeeperId` (any starter), `numbers` (shirt numbers for this match, 1–99, no two the same, every picked player) and `officials` (2–7 copies without phones, manager first, head coach second). Isaac: sheets open any time until the lock. 395 rules tests. |
| 10 Nov 2026 | v2.29: new `teamSheets/{fixtureId}_{teamId}` (3.1a2): `starters` (7 to 11), `bench` (at most 7, only with 11 starting, 18 in all), approved players only via the squad lists (juvenile: the match's age group and younger), locked 1 hour before kick-off; the team writes, the team and the FA read. The squad list Repair shows only in debug builds. 387 rules tests. |
| 10 Nov 2026 | v2.28: new `squads/{teamId}_{group}` (3.1a1): the IDs of a team's approved players per competition / age group, one player per write (`changed`). The FA's approval and screening pass must add the player in the same transaction; a team edit that sends an approved player back to pending must take them off; FA Repair in League settings. 369 rules tests. |
| 10 Nov 2026 | v2.27.8: no data change yet. Isaac's team sheet builder answers in Section 7 (one Save button, bench only with 11 starting, captain starts, any starter in goal, cup sheets 1 hour before; shirt numbers for one match approved, the registered number kept as the usual number). |
| 10 Nov 2026 | v2.27.7: no data change. Isaac: when a team uses the head-injury substitute the other team gets one extra too; a goalkeeper in the starting 11 is required. |
| 10 Nov 2026 | v2.27.6: no data change. Isaac: the extra substitute is for head injuries only, in every competition; any number of goalkeepers, the bench never more than 7. |
| 10 Nov 2026 | v2.27.5: no data change. Team sheet answers in Section 7 (7 on the bench, 5 may come on, a second goalkeeper on the bench, the same for juvenile); the extra injury / concussion substitute is asked of GEDFA. |
| 10 Nov 2026 | v2.27.4 (TDc): no data or rules change. The calendar tells League, Cup and Gala apart from `fixtures.competitionId` (league IDs end in `-league`; a cup match carries its cup's ID) and `cups.kind`, which teams can already read. 355 rules tests. |
| 10 Nov 2026 | v2.27.3 (TDb, team Home): no data or rules change. Squad tiles, fee, Waiting on the FA and From GEDFA read the team's players, fixtures, `fees`, `payments`, `teamChanges`, `correctionRequests`, announcements and notes, all already readable by the team. 355 rules tests. |
| 10 Nov 2026 | v2.27.2 (TDa, team Home): no data or rules change. The team's Home reads what the team app already streams (team, players, fixtures, fee, correction request, screening days); the Division / Juvenile choice is kept on the phone only (shared preferences), not in Firestore. 355 rules tests. |
| 10 Nov 2026 | v2.27.1: no data change yet. GEDFA's answers on juvenile age groups (a club picks 1 to 3, only before the season is published; same fee; no children outside its groups) and the team dashboard decisions in Section 7; `juvenileAgeGroups` planned for step JA. Fees: a separate Juvenile affiliation fee (one, whatever the age groups) and a referee fee for each competition, all in instalments (payments step after JA). |
| 9 Nov 2026 | v2.27 (JSc2, renamed teams in matches): `fixtures` gain `previousNames` (team ID → `{ name, until }`). New FA rule `isRenamingMatch`: only a side's `name` / `shortName` change, to the team's names now (`sideNamesOf`), with the old name in `previousNames` (a short name alone: none); played, postponed and cancelled matches too. The normal change rule checks `previousNames` first (1000-expression limit). The app renames 6 matches per save right after the FA approves a new name, short name or juvenile side name; Finish renaming on the team's page carries on. 355 rules tests. |
| 9 Nov 2026 | v2.26 (JSc1, juvenile side names: ask the FA): new change kind `juvenileName` (`from`/`fromShortName` = how the side plays now, `to`/`toShortName` = its own name, or empty = back to "B"; `nameKey`; "Why" optional); "Add Juvenile" (`competition`) may carry `juvenileName` / `juvenileShortName` / `nameKey`. Approval sets or removes the team's juvenile name and reserves the own name in `teamNames`. Rules: `sideNamesOf` moved up (used by teamChanges), `isOwnJuvenileName`, `isApprovedNameKey`. 348 rules tests. |
| 9 Nov 2026 | v2.25 (JSb, juvenile side names at registration): `teamRequests` gain `juvenileName`, `juvenileShortName`, `juvenileNameKey` (clubs in both only; empty = "B"); the own name is reserved in `teamNames` in the same batch; the FA's approval copies `juvenileName` / `juvenileShortName` to the team (left out for "B") and the rules check they match the request. 334 rules tests. |
| 9 Nov 2026 | v2.24 (JSa, juvenile side names): `teams` gain optional `juvenileName` and `juvenileShortName` (set in JSb / JSc). A club in both competitions is copied into its juvenile matches as "Royal Unique FC B" / "RUF B", or its own juvenile name; the rules check it (`sideNamesOf`). Rules: the kits of a side are looked up once (`isKitChoice` takes the kits), to stay under the 1000-expression limit. 324 rules tests. |
| 9 Nov 2026 | v2.23 (3.0f2): no data change. Pages opened from another tab, or from a full-screen page, carry `back=` in their address (where ← goes). 321 rules tests. |
| 9 Nov 2026 | v2.23 (3.0f1): `readMarks/{uid}` gains `reads` (map, at most 100): a tap marks only that note read; Notification details page. Owner-only, as before. 321 rules tests. |
| 9 Nov 2026 | v2.22 (3.0c1d): new `postponeJobs/{competitionId}` (FA only): a league's postpone is saved before any match moves and ticked off in the same batch as each match, so a stopped one is finished later and nothing moves twice; deleted with the last notes. 318 rules tests. |
| 9 Nov 2026 | v2.21.1 (3.0c1c): no new field or rule. Postpone a league (every match not played yet moves by the same days) or a Gala (its days move); the clubs get a `fixturePostponed` note with the reason. 314 rules tests. |
| 8 Nov 2026 | v2.21 (3.0c1b): the FA changes a cup before the draw and deletes one at any time; new `cups/{id}/history`. GEDFA's cup answers (4) in Section 7 (delete, postpone, Pot 1 byes, juvenile "B", Gala sheets 20 minutes before). 310 rules tests. |
| 8 Nov 2026 | v2.20.1: `cups.finalOneMatch` removed (the final is always one match, GEDFA). GEDFA's cup answers (3) in Section 7. 305 rules tests. |
| 8 Nov 2026 | v2.20 (3.0c1): new `cups/{id}` (cups and galas: who plays, format, one or two legs, level rule, bracket fixed from, seeding, the gala's ground and days). Read by everyone with a role, made by the FA, not changed yet. GEDFA's cup answers (2) in Section 7. 305 rules tests. |
| 8 Nov 2026 | v2.19.1: no data change. Match details reads `fixtures/{id}/history` newest first (teams can read it). |
| 8 Nov 2026 | v2.19 (3.0b): new `fixtureDrafts/{id}` (FA only); "Make the season" publishes matches with fixed IDs, 3 per save. 301 rules tests. |
| 8 Nov 2026 | v2.18.1 (3.0a fix): kit clashes measured (CIEDE2000 < 20.5) instead of a hand-made table; goalkeepers by Law 4 (not against each other or the referee). The FA team page reads the team ID saved at approval. |
| 8 Nov 2026 | v2.18 (3.0a): new `fixtures/{id}` with a copy of both teams and their kits for the match, and `fixtures/{id}/history`; four match notification kinds. Kit rule (home keeps its home kit) and clash table. 298 rules tests. |
| 7 Nov 2026 | v2.17 (2.12b): no new collections or rules. The dashboard's totals are worked out in the app from `teams`, `players` and `fees` (already streamed for the FA), not count queries. Squads ready = Division teams with at least `settings/league.matchdaySquad` approved Division players. |
| 7 Nov 2026 | v2.16 (2.12a): no new collections or rules. The FA dashboard reads what is already there (team requests, team changes, players, waiting payments, correction requests, screening days). Section 7: squads ready = matchday squad (16); fourth officials record assists (Phase 4). |
| 7 Nov 2026 | v2.15 (2.11c): suspensions by the chairman: `teams.suspension` and `teams/{teamId}/suspensions` (ends on a date or when lifted with why: fine paid, bond signed, board decision, other); while in force the team's player, profile and change-request writes are refused; notification kinds `teamSuspended`, `suspensionLifted`. 285 tests. |
| 7 Nov 2026 | v2.14 (2.11b): new `correctionRequests/{teamId}` (the FA asks a team to correct officials, kits, colours, players or club details; asked → sent back → done, or asked again); notification kinds `correctionAsked`, `correctionSentBack`, `correctionDone`. 276 tests. |
| 7 Nov 2026 | v2.13 (2.11a): FA corrections: new `teams/{teamId}/corrections` log and `teams.lastCorrectionId`; the FA corrects the name, town, ground, directions, year founded and email (never officials, kits or colours), a new spelling reserved in `teamNames` for the club; notification kind `teamCorrected`. Isaac's 2.11 decisions recorded in Section 7. 268 tests. |
| 7 Nov 2026 | v2.12.1 (2.10c): no field or rule changes. "Approve all" = one batch per change, oldest first; requests grouped by team for the FA. 257 tests. |
| 7 Nov 2026 | v2.12 (2.10b): new `teamChanges` (name, short name, logo, add a competition; one pending per kind; approve or not approve with a reason); the FA applies an approved change to the team, renames `teamName` on its players and reserves the new name (`teamNames.teamId`); notification kinds `changeRequested`, `changeApproved`, `changeRefused`. Storage: `teams/{teamId}/logo-<millis>.jpg`. 257 tests. |
| 6 Nov 2026 | v2.11 (2.10a): team admins edit town, ground, colours, kits and officials of their approved team; kind `teamUpdated`. 241 tests. |
| 3 Nov 2026 | v2.10 (2.14d): every screening decision carries `screeningDayId` and is refused before the day starts, a day after it, or for an age group the day doesn't cover; "needs correcting" (back to the team); kind `juvenileToCorrect`. 236 tests. |
| 3 Nov 2026 | v2.9 (2.14c): juvenile IDs `GJ26-…` from `settings/juvenileCounter`; pass (move up only, jersey moves along) or `notEligible`; the FA may move a child's jersey reservation; notification kinds `juvenilePassed`, `juvenileNotEligible`. 231 tests. |
| 2 Nov 2026 | v2.8 (2.14b-2): `screeningDays` saved and cancelled with announcements to Juvenile teams. 220 tests. |
| 2 Nov 2026 | v2.7 (2.14b-1): notification kind `juvenileSubmitted` ("9 juvenile players from X", one per team and day); "Register in" follows the tab, moving up only. 215 tests. |
| 30 Oct 2026 | v2.6 (2.14a): juvenile players: `ageGroup`, `guardian`, jersey IDs `juvenile-U13-10`, player keys `…_juvenile`; the rules check the age group from the season's start year. 214 tests. |
| 30 Oct 2026 | v2.5 (2.13d): `settings/league` rules and fields (registration switches, squad numbers, season / fee / MoMo by the chairman), `settingsLog`, `registrationChanged` notification; the payment cap follows the fee. 205 tests. |
| 28 Oct 2026 | v2.4 (2.13c-2): payments after approval; notification kinds `paymentConfirmed`, `paymentNotFound`, `feeReminder`, `paymentSent`; `teams.requestUid` used for the fee. 195 tests. |
| 28 Oct 2026 | v2.3.1: "not found" sends a pending registration back; FA can correct recorded cash (`editedBy`, `editedAt`); FA team-request notifications grouped into one a day. 190 tests. |
| 27 Oct 2026 | v2.3 (2.13c-1): `payments`, `fees`, `settings/receiptCounter`; `teamRequests.season`; approval needs a confirmed payment. Storage: payment proof. 187 tests. |
| 27 Oct 2026 | v2.2 (2.13b): kits can be photos (`photos`); `juvenileKits` for clubs in both competitions; `colours` (home / away, main / second) required. Storage: `kits/` photos. 166 tests. |
| 27 Oct 2026 | v2.1 (2.13a): `teamRequests` gain `clubStatus`, `lastLeague`, `letterUrl`, `licenceUrl`, `licenceType`; logo required; officials at most 7, new role `other` with `title`. Storage: `letter.pdf`, `licence.pdf` / `licence.jpg`. GEDFA's answers recorded in Section 7. |
| 24 Oct 2026 | v2.0: `announcements` (+ `seen`), grouped `notifications`, `readMarks` (2.7 – 2.8); composite indexes. 149 tests. |
| 24 Oct 2026 | v1.9.1: `playerProfiles.unavailableReason`; the availability tiles filter the Player profiles tab. 137 tests. |
| 24 Oct 2026 | v1.9: new `playerProfiles` and `teams/*/armbands` (2.3d). 136 tests. |
| 24 Oct 2026 | v1.8: players gain `changes` (what the team changed, for the FA); approval and rejection clear it. 124 tests. |
| 24 Oct 2026 | v1.7: invitations (2.6). New `invites/{email}` and `roleLog`; `users` gain `name`, `inviteId` and the hand-set `isChairman`; invited people create their own user document when accepting; roles removed by deleting the document (chairman protected). FA can list users. 119 tests. |
| 22 Oct 2026 | v1.6: FA review of players (2.3). Players gain `reviewedAt`, `reviewedBy` (rejection). FA may read every player, jersey and player key, and approve or reject pending players; approval is a transaction with `settings/playerCounter`, re-checked players keep their ID, the ID year is the year of first approval. Access table updated (90 tests). |
| 22 Oct 2026 | v1.5: FA review of team requests. `teamRequests` gain `reviewedBy`, `reviewedAt`, `teamId`; reject needs a 10–500 character reason. Teams are created only by the FA's Approve batch, ID = reserved name key, logo link reused. `users`: the FA can get any and create a `teamAdmin` role on approval (never `faAdmin`). Full name lives on the Auth account. Access table updated (71 tests). |
| 18 Oct 2026 | v1.4: matches security rules v1. Jersey reservation ID is now `{category}-{number}` (e.g. `division-9`) with only `playerId` and `createdAt` (`playerName` dropped). Players gain `playerKey`; `photoUrl` and `thumbUrl` are now **required** (300×400 and 96×128). Player photos moved to `teams/{teamId}/players/{playerId}/photo-<millis>.jpg` / `thumb-<millis>.jpg`. Team admins may `get` any `playerKeys` key. Section 3 marks what rules v1 cover; Storage rows added. Photo-and-batch order added to Section 4. Storage CORS for the web build. |
