// Security rules tests for GEDFA Connect (steps 1.7 to 2.6, 2.3c).
//
// Run while the emulators are running:
//   cd test/rules
//   npm test
//
// The tests use their own project ID (demo-gedfa-rules), so they never
// touch the data you use in the app.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { before, after, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const D = 'districts/gomoa-east';

let testEnv;

// ---------- Sample data ----------

/** A valid player. Pass changes to make a different or broken one. */
function playerData(changes = {}) {
  const fullName = changes.fullName ?? 'Kwame Asante';
  return {
    teamId: 'royal',
    teamName: 'Royal Unique FC',
    category: 'division',
    fullName,
    fullNameLower: fullName.toLowerCase(),
    searchKeys: ['kw', 'kwa', 'kwam', 'kwame', 'as', 'asa'],
    playerKey: 'kwame-asante_2004-03-15',
    dob: Timestamp.fromDate(new Date(Date.UTC(2004, 2, 15))),
    position: 'CM',
    positionGroup: 'MID',
    jerseyNo: 10,
    photoUrl: 'https://example.com/photo-1.jpg',
    thumbUrl: 'https://example.com/thumb-1.jpg',
    status: 'pending',
    ...changes,
  };
}

/** A copy of [data] without some fields. */
function without(data, ...fields) {
  const copy = { ...data };
  for (const field of fields) delete copy[field];
  return copy;
}

/**
 * Adds a player the way the app does: player + jersey + player key in one
 * batch. All three succeed or all fail.
 */
function addPlayer(db, playerId, data) {
  const batch = writeBatch(db);
  batch.set(doc(db, `${D}/players/${playerId}`), {
    ...data,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(db, `${D}/teams/${data.teamId}/jerseys/${data.category}-${data.jerseyNo}`),
    { playerId, createdAt: serverTimestamp() },
  );
  batch.set(doc(db, `${D}/playerKeys/${data.playerKey}`), {
    playerId,
    teamId: data.teamId,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}

/** Sends a team request the way the app does: request + name reservation. */
function sendTeamRequest(db, uid, changes = {}) {
  const data = {
    teamName: 'Test United',
    teamNameLower: 'test united',
    nameKey: 'test-united',
    shortName: 'TUN',
    town: 'Afransi',
    homeGround: 'Afransi Park',
    categories: ['division'],
    kits: {
      home: { shirt: '#D32F2F' },
      away: { shirt: '#FFFFFF' },
      goalkeeper: { shirt: '#388E3C' },
    },
    officials: [{ name: 'Kofi Mensah' }, { name: 'Ama Boateng' }],
    agreedToRules: true,
    status: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...changes,
  };
  const batch = writeBatch(db);
  batch.set(doc(db, `${D}/teamRequests/${uid}`), data);
  batch.set(doc(db, `${D}/teamNames/${data.nameKey}`), {
    uid,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}

/** Writes the starting data with the rules switched off. */
async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const now = Timestamp.now();
    const set = (path, data) => setDoc(doc(db, path), data);

    // Users: two team admins and two people with no role yet
    await set(`${D}/users/admin1`, { role: 'teamAdmin', teamId: 'royal' });
    await set(`${D}/users/admin2`, { role: 'teamAdmin', teamId: 'stars' });
    await set(`${D}/users/newbie`, { email: 'newbie@example.com' });
    await set(`${D}/users/fa1`, { role: 'faAdmin' });

    // 2.6: the chairman, an FA official and a referee who joined by
    // invitation, and invitations (pending, expired, accepted)
    const days = (n) => Timestamp.fromMillis(Date.now() + n * 86400000);
    await set(`${D}/users/chair`, { role: 'faAdmin', isChairman: true });
    await set(`${D}/users/off1`, { role: 'faAdmin', name: 'Ama Boateng', email: 'off1@example.com', inviteId: 'off1@example.com', createdAt: now });
    await set(`${D}/users/ref1`, { role: 'referee', name: 'Ebo Quaye', email: 'ref1@example.com', inviteId: 'ref1@example.com', createdAt: now });
    const invite = (email, role, changes = {}) => set(`${D}/invites/${email}`, {
      email, name: 'Invited Person', role, status: 'pending',
      invitedBy: 'chair', invitedByName: 'Kofi Mensah',
      createdAt: now, expiresAt: days(14), ...changes,
    });
    await invite('kwesi@example.com', 'referee');
    await invite('efua@example.com', 'faAdmin');
    await invite('old@example.com', 'referee', { expiresAt: days(-1) });
    await invite('off1@example.com', 'faAdmin', { status: 'accepted', acceptedBy: 'off1', acceptedAt: now });
    await invite('ref1@example.com', 'referee', { status: 'accepted', acceptedBy: 'ref1', acceptedAt: now });
    await set(`${D}/users/other`, { email: 'other@example.com' });

    // Teams
    await set(`${D}/teams/royal`, { name: 'Royal Unique FC', categories: ['division'] });
    await set(`${D}/teams/stars`, { name: 'Gomoa Stars', categories: ['division'] });

    // Another person's team request
    await set(`${D}/teamRequests/other`, { teamName: 'Other FC', status: 'pending' });

    // A pending request from 'applicant' (no role yet, no user document),
    // with its team-name reservation. The FA approves or rejects it.
    await set(`${D}/teamRequests/applicant`, {
      teamName: 'Gomoa United FC',
      nameKey: 'gomoa-united-fc',
      status: 'pending',
      rejectionReason: null,
      createdAt: now,
      updatedAt: now,
    });
    await set(`${D}/teamNames/gomoa-united-fc`, { uid: 'applicant', createdAt: now });

    // p1: Royal, approved, #10
    await set(`${D}/players/p1`, playerData({
      status: 'approved',
      playerCode: 'GE26-0001',
      approvedAt: now,
      approvedBy: 'fa1',
      createdAt: now,
      updatedAt: now,
    }));
    await set(`${D}/teams/royal/jerseys/division-10`, { playerId: 'p1', createdAt: now });
    await set(`${D}/playerKeys/kwame-asante_2004-03-15`,
      { playerId: 'p1', teamId: 'royal', createdAt: now });

    // p3: Royal, pending, #5
    await set(`${D}/players/p3`, playerData({
      fullName: 'Kofi Owusu',
      playerKey: 'kofi-owusu_2005-06-20',
      jerseyNo: 5,
      createdAt: now,
      updatedAt: now,
    }));
    await set(`${D}/teams/royal/jerseys/division-5`, { playerId: 'p3', createdAt: now });
    await set(`${D}/playerKeys/kofi-owusu_2005-06-20`,
      { playerId: 'p3', teamId: 'royal', createdAt: now });

    // p2: Stars, pending, #7
    await set(`${D}/players/p2`, playerData({
      teamId: 'stars',
      teamName: 'Gomoa Stars',
      fullName: 'Yaw Boateng',
      playerKey: 'yaw-boateng_2002-01-01',
      jerseyNo: 7,
      createdAt: now,
      updatedAt: now,
    }));
    await set(`${D}/teams/stars/jerseys/division-7`, { playerId: 'p2', createdAt: now });
    await set(`${D}/playerKeys/yaw-boateng_2002-01-01`,
      { playerId: 'p2', teamId: 'stars', createdAt: now });
  });
}

/** Firestore as a signed-in user whose confirmed email is [email]. */
function dbAsEmail(uid, email) {
  return testEnv
    .authenticatedContext(uid, { email, email_verified: true })
    .firestore();
}

/** Firestore as a signed-in user with a confirmed email. */
function dbAs(uid) {
  return testEnv.authenticatedContext(uid, { email_verified: true }).firestore();
}

// ---------- Setup ----------

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gedfa-rules',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: readFileSync(resolve(here, '../../firestore.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed();
});

after(async () => {
  await testEnv?.cleanup();
});

// ---------- Signed-out visitor ----------

describe('Signed-out visitor', () => {
  const db = () => testEnv.unauthenticatedContext().firestore();

  it('cannot read a team', async () => {
    await assertFails(getDoc(doc(db(), `${D}/teams/royal`)));
  });

  it('cannot read a player', async () => {
    await assertFails(getDoc(doc(db(), `${D}/players/p1`)));
  });

  it('cannot check team names', async () => {
    await assertFails(getDoc(doc(db(), `${D}/teamNames/test-united`)));
  });

  it('cannot send a team request', async () => {
    await assertFails(sendTeamRequest(db(), 'nobody'));
  });
});

// ---------- Role-less user ----------

describe('Role-less user (signed up, no team yet)', () => {
  it('can read their own user document', async () => {
    await assertSucceeds(getDoc(doc(dbAs('newbie'), `${D}/users/newbie`)));
  });

  it("cannot read someone else's user document", async () => {
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/users/admin1`)));
  });

  it('cannot make themselves a team admin', async () => {
    await assertFails(setDoc(doc(dbAs('newbie'), `${D}/users/newbie`),
      { role: 'teamAdmin', teamId: 'royal' }));
  });

  it('can send a team request', async () => {
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie'));
  });

  it('can read their own team request', async () => {
    await sendTeamRequest(dbAs('newbie'), 'newbie');
    await assertSucceeds(getDoc(doc(dbAs('newbie'), `${D}/teamRequests/newbie`)));
  });

  it('cannot send a request without a confirmed email', async () => {
    const db = testEnv.authenticatedContext('newbie', { email_verified: false }).firestore();
    await assertFails(sendTeamRequest(db, 'newbie'));
  });

  it('cannot send a request that is already approved', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { status: 'approved' }));
  });

  it('cannot send a request in someone else\'s name', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'other'));
  });

  it("cannot read someone else's team request", async () => {
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/teamRequests/other`)));
  });

  it('cannot create a team', async () => {
    await assertFails(setDoc(doc(dbAs('newbie'), `${D}/teams/newteam`),
      { name: 'New Team', categories: ['division'] }));
  });

  it('cannot read a team', async () => {
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/teams/royal`)));
  });

  it('cannot read a player', async () => {
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/players/p1`)));
  });

  it("cannot list a team's players", async () => {
    const db = dbAs('newbie');
    await assertFails(getDocs(query(collection(db, `${D}/players`),
      where('teamId', '==', 'royal'))));
  });

  it('cannot check player keys', async () => {
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/playerKeys/kwame-asante_2004-03-15`)));
  });

  it('cannot add a player', async () => {
    await assertFails(addPlayer(dbAs('newbie'), 'x1', playerData({
      fullName: 'Kofi Mensah',
      playerKey: 'kofi-mensah_2003-05-01',
      jerseyNo: 11,
    })));
  });
});

// ---------- Team admin: reading ----------

describe('Team admin: reading', () => {
  it('can read their own team', async () => {
    await assertSucceeds(getDoc(doc(dbAs('admin1'), `${D}/teams/royal`)));
  });

  it('cannot read another team', async () => {
    await assertFails(getDoc(doc(dbAs('admin1'), `${D}/teams/stars`)));
  });

  it('can list their own players', async () => {
    const db = dbAs('admin1');
    await assertSucceeds(getDocs(query(collection(db, `${D}/players`),
      where('teamId', '==', 'royal'))));
  });

  it("cannot list another team's players", async () => {
    const db = dbAs('admin1');
    await assertFails(getDocs(query(collection(db, `${D}/players`),
      where('teamId', '==', 'stars'))));
  });

  it("cannot list every team's players", async () => {
    await assertFails(getDocs(collection(dbAs('admin1'), `${D}/players`)));
  });

  it("cannot read another team's player", async () => {
    await assertFails(getDoc(doc(dbAs('admin1'), `${D}/players/p2`)));
  });

  it('can check their own jersey numbers', async () => {
    await assertSucceeds(getDoc(doc(dbAs('admin1'), `${D}/teams/royal/jerseys/division-10`)));
  });

  it("cannot check another team's jersey numbers", async () => {
    await assertFails(getDoc(doc(dbAs('admin1'), `${D}/teams/stars/jerseys/division-7`)));
  });

  it('can check a player key (to catch duplicates)', async () => {
    await assertSucceeds(getDoc(doc(dbAs('admin1'), `${D}/playerKeys/yaw-boateng_2002-01-01`)));
  });
});

// ---------- Team admin: adding players ----------

describe('Team admin: adding players', () => {
  const newPlayer = (changes = {}) => playerData({
    fullName: 'Kofi Mensah',
    playerKey: 'kofi-mensah_2003-05-01',
    jerseyNo: 11,
    ...changes,
  });

  it('can add a valid player', async () => {
    await assertSucceeds(addPlayer(dbAs('admin1'), 'x1', newPlayer()));
  });

  it('cannot add a player without a passport photo', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1',
      without(newPlayer(), 'photoUrl', 'thumbUrl')));
  });

  it('cannot add a player with an empty photo link', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({ photoUrl: '' })));
  });

  it('cannot add a player as already approved', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({ status: 'approved' })));
  });

  it('cannot give a player their own player ID', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({ playerCode: 'GE26-9999' })));
  });

  it('cannot use a jersey number that is taken', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({ jerseyNo: 10 })));
  });

  it('cannot add the same person twice', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({
      playerKey: 'kwame-asante_2004-03-15',
    })));
  });

  it('cannot add a player to another team', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({
      teamId: 'stars',
      teamName: 'Gomoa Stars',
    })));
  });

  it('cannot add a player without the reservations', async () => {
    const db = dbAs('admin1');
    await assertFails(setDoc(doc(db, `${D}/players/x1`), {
      ...newPlayer(),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
  });

  it('cannot add a juvenile player yet', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({ category: 'juvenile' })));
  });

  it('cannot use a position that does not exist', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({
      position: 'XX',
      positionGroup: 'MID',
    })));
  });

  it('cannot use jersey number 100', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'x1', newPlayer({ jerseyNo: 100 })));
  });
});

// ---------- Team admin: editing players ----------

describe('Team admin: editing players', () => {
  const p1 = (db) => doc(db, `${D}/players/p1`); // approved
  const p3 = (db) => doc(db, `${D}/players/p3`); // pending

  it('can change the position of an approved player (stays approved)', async () => {
    const db = dbAs('admin1');
    await assertSucceeds(updateDoc(p1(db), {
      position: 'DM',
      positionGroup: 'MID',
      updatedAt: serverTimestamp(),
    }));
  });

  it('cannot change the name of an approved player and keep it approved', async () => {
    const db = dbAs('admin1');
    await assertFails(updateDoc(p1(db), {
      fullName: 'Kwame Asante Jnr',
      fullNameLower: 'kwame asante jnr',
      updatedAt: serverTimestamp(),
    }));
  });

  it('can change the name if the player goes back to pending', async () => {
    const db = dbAs('admin1');
    await assertSucceeds(updateDoc(p1(db), {
      fullName: 'Kwame Asante Jnr',
      fullNameLower: 'kwame asante jnr',
      status: 'pending',
      updatedAt: serverTimestamp(),
    }));
  });

  it('cannot approve a player themselves', async () => {
    const db = dbAs('admin1');
    await assertFails(updateDoc(p3(db), {
      status: 'approved',
      updatedAt: serverTimestamp(),
    }));
  });

  it('cannot give a player ID themselves', async () => {
    const db = dbAs('admin1');
    await assertFails(updateDoc(p3(db), {
      playerCode: 'GE26-9999',
      updatedAt: serverTimestamp(),
    }));
  });

  it('cannot remove the passport photo', async () => {
    const db = dbAs('admin1');
    await assertFails(updateDoc(p3(db), {
      photoUrl: '',
      updatedAt: serverTimestamp(),
    }));
  });

  it('cannot move a player to another team', async () => {
    const db = dbAs('admin1');
    await assertFails(updateDoc(p3(db), {
      teamId: 'stars',
      updatedAt: serverTimestamp(),
    }));
  });

  it('cannot delete a player', async () => {
    await assertFails(deleteDoc(p3(dbAs('admin1'))));
  });

  it("cannot edit another team's player", async () => {
    const db = dbAs('admin2');
    await assertFails(updateDoc(p1(db), {
      position: 'DM',
      updatedAt: serverTimestamp(),
    }));
  });
});

// ---------- FA admin: team requests (2.1) ----------

describe('FA admin: team requests', () => {
  it('can list every team request', async () => {
    await assertSucceeds(getDocs(collection(dbAs('fa1'), `${D}/teamRequests`)));
  });

  it('can read one team request', async () => {
    await assertSucceeds(getDoc(doc(dbAs('fa1'), `${D}/teamRequests/other`)));
  });

  it('can check a team name reservation', async () => {
    await assertSucceeds(getDoc(doc(dbAs('fa1'), `${D}/teamNames/test-united`)));
  });

  it('can read and list teams', async () => {
    const db = dbAs('fa1');
    await assertSucceeds(getDoc(doc(db, `${D}/teams/royal`)));
    await assertSucceeds(getDocs(collection(db, `${D}/teams`)));
  });

  it('cannot just flip a status without the review fields', async () => {
    await assertFails(updateDoc(doc(dbAs('fa1'), `${D}/teamRequests/other`), {
      status: 'approved',
    }));
  });

  it('a team admin cannot list team requests', async () => {
    await assertFails(getDocs(collection(dbAs('admin1'), `${D}/teamRequests`)));
  });

  it('a role-less user cannot list team requests', async () => {
    await assertFails(getDocs(collection(dbAs('newbie'), `${D}/teamRequests`)));
  });

  it('a role-less user cannot list teams', async () => {
    await assertFails(getDocs(collection(dbAs('newbie'), `${D}/teams`)));
  });
});

// ---------- FA admin: approve and reject (2.2) ----------

/**
 * Approves a request the way the app does: request + team + user role in
 * one batch. Pass changes to break one part on purpose.
 */
function approve(db, { uid = 'applicant', teamId = 'gomoa-united-fc', by = 'fa1',
  role = 'teamAdmin', skipTeam = false, skipUser = false } = {}) {
  const batch = writeBatch(db);
  batch.update(doc(db, `${D}/teamRequests/${uid}`), {
    status: 'approved',
    teamId,
    reviewedBy: by,
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  if (!skipTeam) {
    batch.set(doc(db, `${D}/teams/${teamId}`), {
      name: 'Gomoa United FC',
      nameKey: teamId,
      categories: ['division'],
      adminUids: [uid],
      requestUid: uid,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }
  if (!skipUser) {
    batch.set(doc(db, `${D}/users/${uid}`), {
      role,
      teamId,
      createdBy: by,
      createdAt: serverTimestamp(),
    });
  }
  return batch.commit();
}

/** Rejects a request the way the app does. */
function reject(db, { uid = 'applicant', reason = 'Logo is unclear. Please fix and send again.', by = 'fa1' } = {}) {
  return updateDoc(doc(db, `${D}/teamRequests/${uid}`), {
    status: 'rejected',
    rejectionReason: reason,
    reviewedBy: by,
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
}

describe('FA admin: approve and reject', () => {
  it('can approve: creates the team and makes the club its team admin', async () => {
    await assertSucceeds(approve(dbAs('fa1')));
  });

  it('after approval, the club can read its new team', async () => {
    await approve(dbAs('fa1'));
    await assertSucceeds(getDoc(doc(dbAs('applicant'), `${D}/teams/gomoa-united-fc`)));
  });

  it('cannot approve without creating the team', async () => {
    await assertFails(approve(dbAs('fa1'), { skipTeam: true }));
  });

  it('cannot approve without giving the team admin role', async () => {
    await assertFails(approve(dbAs('fa1'), { skipUser: true }));
  });

  it('cannot make the club an FA admin', async () => {
    await assertFails(approve(dbAs('fa1'), { role: 'faAdmin' }));
  });

  it('cannot use a team ID other than the reserved name', async () => {
    await assertFails(approve(dbAs('fa1'), { teamId: 'some-other-name' }));
  });

  it('cannot sign the review as someone else', async () => {
    await assertFails(approve(dbAs('fa1'), { by: 'admin1' }));
  });

  it('cannot approve the same request twice', async () => {
    await approve(dbAs('fa1'));
    await assertFails(approve(dbAs('fa1')));
  });

  it('can reject with a reason', async () => {
    await assertSucceeds(reject(dbAs('fa1')));
  });

  it('cannot reject without a real reason', async () => {
    await assertFails(reject(dbAs('fa1'), { reason: 'No' }));
  });

  it('a team admin cannot approve', async () => {
    await assertFails(approve(dbAs('admin1'), { by: 'admin1' }));
  });

  it('the club cannot approve its own request', async () => {
    await assertFails(approve(dbAs('applicant'), { by: 'applicant' }));
  });

  it('the club can fix and resend after a rejection', async () => {
    // newbie sends a real request, the FA rejects it, newbie edits it
    await sendTeamRequest(dbAs('newbie'), 'newbie');
    await assertSucceeds(reject(dbAs('fa1'), { uid: 'newbie' }));
    await assertSucceeds(updateDoc(doc(dbAs('newbie'), `${D}/teamRequests/newbie`), {
      town: 'Afransi Junction',
      status: 'pending',
      rejectionReason: null,
      updatedAt: serverTimestamp(),
    }));
  });

  it('the club cannot write the review fields itself', async () => {
    await sendTeamRequest(dbAs('newbie'), 'newbie');
    await assertFails(updateDoc(doc(dbAs('newbie'), `${D}/teamRequests/newbie`), {
      reviewedBy: 'fa1',
      updatedAt: serverTimestamp(),
    }));
  });
});

// ---------- FA admin: players (2.3) ----------

/** This year's two digits, the same way the rules work it out (UTC). */
const YY = String(new Date().getUTCFullYear() % 100).padStart(2, '0');
const COUNTER = `${D}/settings/playerCounter`;

/** Puts the player-ID counter in place with the rules switched off. */
async function seedCounter(next) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), COUNTER), { next });
  });
}

/**
 * Approves a player the way the app does: the player and the counter
 * in one go. [counter] is 'create', 'update' or 'none'.
 */
function approvePlayer(db, playerId, { by = 'fa1', code, next, counter = 'update' } = {}) {
  const batch = writeBatch(db);
  batch.update(doc(db, `${D}/players/${playerId}`), {
    status: 'approved',
    ...(code === undefined ? {} : { playerCode: code }),
    approvedAt: serverTimestamp(),
    approvedBy: by,
    rejectionReason: null,
    changes: deleteField(),
    updatedAt: serverTimestamp(),
  });
  if (counter === 'create') batch.set(doc(db, COUNTER), { next });
  if (counter === 'update') batch.update(doc(db, COUNTER), { next });
  return batch.commit();
}

/** Rejects a pending player with a reason. */
function rejectPlayer(db, playerId, { by = 'fa1', reason = 'Photo is not clear' } = {}) {
  return updateDoc(doc(db, `${D}/players/${playerId}`), {
    status: 'rejected',
    rejectionReason: reason,
    reviewedAt: serverTimestamp(),
    reviewedBy: by,
    changes: deleteField(),
    updatedAt: serverTimestamp(),
  });
}

describe('FA admin: players', () => {
  it('can list every player', async () => {
    await assertSucceeds(getDocs(collection(dbAs('fa1'), `${D}/players`)));
  });

  it("can read a player and check their reservations", async () => {
    const db = dbAs('fa1');
    await assertSucceeds(getDoc(doc(db, `${D}/players/p3`)));
    await assertSucceeds(getDoc(doc(db, `${D}/teams/royal/jerseys/division-5`)));
    await assertSucceeds(getDoc(doc(db, `${D}/playerKeys/kofi-owusu_2005-06-20`)));
  });

  it('can approve with the next ID and move the counter on', async () => {
    await seedCounter(2);
    await assertSucceeds(approvePlayer(dbAs('fa1'), 'p3', { code: `GE${YY}-0002`, next: 3 }));
  });

  it('the first approval ever starts the counter (ID 0001)', async () => {
    await assertSucceeds(approvePlayer(dbAs('fa1'), 'p3', {
      code: `GE${YY}-0001`, next: 2, counter: 'create',
    }));
  });

  it('cannot approve without moving the counter on', async () => {
    await seedCounter(2);
    await assertFails(approvePlayer(dbAs('fa1'), 'p3', { code: `GE${YY}-0002`, counter: 'none' }));
  });

  it('cannot skip numbers on the counter', async () => {
    await seedCounter(2);
    await assertFails(approvePlayer(dbAs('fa1'), 'p3', { code: `GE${YY}-0002`, next: 5 }));
  });

  it('cannot give an ID that is not the next number', async () => {
    await seedCounter(2);
    await assertFails(approvePlayer(dbAs('fa1'), 'p3', { code: `GE${YY}-0009`, next: 3 }));
  });

  it('cannot approve without an ID', async () => {
    await seedCounter(2);
    await assertFails(approvePlayer(dbAs('fa1'), 'p3', { counter: 'none' }));
  });

  it('cannot sign the approval as someone else', async () => {
    await seedCounter(2);
    await assertFails(approvePlayer(dbAs('fa1'), 'p3', {
      by: 'admin1', code: `GE${YY}-0002`, next: 3,
    }));
  });

  it('a re-checked player keeps their ID (the counter stays)', async () => {
    await seedCounter(2);
    // The team changes p1's name, so p1 goes back to pending with GE26-0001
    await updateDoc(doc(dbAs('admin1'), `${D}/players/p1`), {
      fullName: 'Kwame Asante Jnr',
      fullNameLower: 'kwame asante jnr',
      status: 'pending',
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(approvePlayer(dbAs('fa1'), 'p1', { counter: 'none' }));
  });

  it('cannot give a re-checked player a new ID', async () => {
    await seedCounter(2);
    await updateDoc(doc(dbAs('admin1'), `${D}/players/p1`), {
      status: 'pending',
      updatedAt: serverTimestamp(),
    });
    await assertFails(approvePlayer(dbAs('fa1'), 'p1', { code: `GE${YY}-0002`, next: 3 }));
  });

  it('cannot approve a player who is already approved', async () => {
    await assertFails(approvePlayer(dbAs('fa1'), 'p1', { counter: 'none' }));
  });

  it('cannot change player details while approving', async () => {
    await seedCounter(2);
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/players/p3`), {
      status: 'approved',
      playerCode: `GE${YY}-0002`,
      jerseyNo: 99,
      approvedAt: serverTimestamp(),
      approvedBy: 'fa1',
      updatedAt: serverTimestamp(),
    });
    batch.update(doc(db, COUNTER), { next: 3 });
    await assertFails(batch.commit());
  });

  it('can reject with a reason', async () => {
    await assertSucceeds(rejectPlayer(dbAs('fa1'), 'p3'));
  });

  it('cannot reject without a real reason', async () => {
    await assertFails(rejectPlayer(dbAs('fa1'), 'p3', { reason: 'no' }));
  });

  it('a team admin cannot approve or touch the counter', async () => {
    await seedCounter(2);
    await assertFails(approvePlayer(dbAs('admin1'), 'p3', {
      by: 'admin1', code: `GE${YY}-0002`, next: 3,
    }));
    await assertFails(updateDoc(doc(dbAs('admin1'), COUNTER), { next: 3 }));
    await assertFails(getDoc(doc(dbAs('admin1'), COUNTER)));
  });

  it('the counter cannot go backwards', async () => {
    await seedCounter(5);
    await assertFails(updateDoc(doc(dbAs('fa1'), COUNTER), { next: 4 }));
  });

  it('the team can fix and resend after a rejection', async () => {
    await rejectPlayer(dbAs('fa1'), 'p3');
    await assertSucceeds(updateDoc(doc(dbAs('admin1'), `${D}/players/p3`), {
      position: 'DM',
      positionGroup: 'MID',
      status: 'pending',
      rejectionReason: null,
      updatedAt: serverTimestamp(),
    }));
  });

  it('the team cannot write the review fields itself', async () => {
    await assertFails(updateDoc(doc(dbAs('admin1'), `${D}/players/p3`), {
      reviewedBy: 'fa1',
      updatedAt: serverTimestamp(),
    }));
  });
});

// ---------- Invitations (2.6) ----------

/** A new invitation the way the app writes it, plus its role-history line. */
function invitePerson(db, by, email, role, changes = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `${D}/invites/${email}`), {
    email, name: 'Kojo Mensah', role, status: 'pending',
    invitedBy: by, invitedByName: 'Someone',
    createdAt: serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 14 * 86400000),
    ...changes,
  });
  batch.set(doc(collection(db, `${D}/roleLog`)), {
    email, name: 'Kojo Mensah', role, action: 'invited',
    by, byName: 'Someone', at: serverTimestamp(),
  });
  return batch.commit();
}

/** Accepting: own user document + invitation accepted + history line. */
function acceptInvite(db, uid, email, role, changes = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `${D}/users/${uid}`), {
    role, name: 'Kwesi Arthur', email, inviteId: email,
    createdAt: serverTimestamp(), ...changes,
  });
  batch.update(doc(db, `${D}/invites/${email}`), {
    status: 'accepted', acceptedBy: uid, acceptedAt: serverTimestamp(),
  });
  batch.set(doc(collection(db, `${D}/roleLog`)), {
    email, name: 'Kwesi Arthur', role, action: 'accepted', uid,
    by: uid, byName: 'Kwesi Arthur', at: serverTimestamp(),
  });
  return batch.commit();
}

/** Removing a role: user document + accepted invitation + history line. */
function removeRole(db, by, uid, email, role) {
  const batch = writeBatch(db);
  batch.delete(doc(db, `${D}/users/${uid}`));
  batch.delete(doc(db, `${D}/invites/${email}`));
  batch.set(doc(collection(db, `${D}/roleLog`)), {
    email, name: 'Someone', role, action: 'removed', uid,
    by, byName: 'Someone', at: serverTimestamp(),
  });
  return batch.commit();
}

describe('Invitations: who can invite', () => {
  it('an FA official can invite a referee', async () => {
    await assertSucceeds(invitePerson(dbAs('fa1'), 'fa1', 'new.ref@example.com', 'referee'));
  });

  it('an FA official cannot invite an FA official', async () => {
    await assertFails(invitePerson(dbAs('fa1'), 'fa1', 'new.off@example.com', 'faAdmin'));
  });

  it('the chairman can invite an FA official', async () => {
    await assertSucceeds(invitePerson(dbAs('chair'), 'chair', 'new.off@example.com', 'faAdmin'));
  });

  it('nobody can invite a team admin this way', async () => {
    await assertFails(invitePerson(dbAs('chair'), 'chair', 'x@example.com', 'teamAdmin'));
  });

  it('a team admin cannot invite anyone', async () => {
    await assertFails(invitePerson(dbAs('admin1'), 'admin1', 'x@example.com', 'referee'));
  });

  it('the invitation must expire in about 14 days', async () => {
    await assertFails(invitePerson(dbAs('chair'), 'chair', 'x@example.com', 'referee', {
      expiresAt: Timestamp.fromMillis(Date.now() + 90 * 86400000),
    }));
  });

  it('the email must be the document ID', async () => {
    await assertFails(invitePerson(dbAs('chair'), 'chair', 'x@example.com', 'referee', {
      email: 'someone.else@example.com',
    }));
  });

  it('cannot invite an email that already has an invitation', async () => {
    await assertFails(invitePerson(dbAs('chair'), 'chair', 'kwesi@example.com', 'referee'));
  });

  it('the FA can list invitations, people and the role history', async () => {
    const db = dbAs('fa1');
    await assertSucceeds(getDocs(collection(db, `${D}/invites`)));
    await assertSucceeds(getDocs(query(collection(db, `${D}/users`),
      where('role', 'in', ['faAdmin', 'referee']))));
    await assertSucceeds(getDocs(collection(db, `${D}/roleLog`)));
  });

  it('a team admin cannot list people or invitations', async () => {
    await assertFails(getDocs(collection(dbAs('admin1'), `${D}/users`)));
    await assertFails(getDocs(collection(dbAs('admin1'), `${D}/invites`)));
  });
});

describe('Invitations: the invited person', () => {
  it('can read their own invitation', async () => {
    await assertSucceeds(getDoc(doc(dbAsEmail('kwesi', 'kwesi@example.com'), `${D}/invites/kwesi@example.com`)));
  });

  it("cannot read someone else's invitation", async () => {
    await assertFails(getDoc(doc(dbAsEmail('kwesi', 'kwesi@example.com'), `${D}/invites/efua@example.com`)));
  });

  it('can accept and gets exactly the invited role', async () => {
    const db = dbAsEmail('kwesi', 'kwesi@example.com');
    await assertSucceeds(acceptInvite(db, 'kwesi', 'kwesi@example.com', 'referee'));
    await assertSucceeds(getDoc(doc(db, `${D}/users/kwesi`)));
  });

  it('cannot accept with a different role', async () => {
    await assertFails(acceptInvite(dbAsEmail('kwesi', 'kwesi@example.com'), 'kwesi', 'kwesi@example.com', 'faAdmin'));
  });

  it('cannot make themselves chairman while accepting', async () => {
    await assertFails(acceptInvite(dbAsEmail('efua', 'efua@example.com'), 'efua', 'efua@example.com', 'faAdmin', { isChairman: true }));
  });

  it("cannot accept someone else's invitation", async () => {
    await assertFails(acceptInvite(dbAsEmail('kwesi', 'kwesi@example.com'), 'kwesi', 'efua@example.com', 'faAdmin'));
  });

  it('cannot accept without a confirmed email', async () => {
    const db = testEnv.authenticatedContext('kwesi', { email: 'kwesi@example.com', email_verified: false }).firestore();
    await assertFails(acceptInvite(db, 'kwesi', 'kwesi@example.com', 'referee'));
  });

  it('cannot accept an expired invitation', async () => {
    await assertFails(acceptInvite(dbAsEmail('old', 'old@example.com'), 'old', 'old@example.com', 'referee'));
  });

  it('cannot accept an invitation twice', async () => {
    const db = dbAsEmail('kwesi', 'kwesi@example.com');
    await acceptInvite(db, 'kwesi', 'kwesi@example.com', 'referee');
    await assertFails(acceptInvite(db, 'kwesi', 'kwesi@example.com', 'referee'));
  });

  it('cannot give themselves a role without an invitation', async () => {
    await assertFails(setDoc(doc(dbAsEmail('newbie', 'newbie@example.com'), `${D}/users/newbie`), {
      role: 'referee', name: 'Newbie', email: 'newbie@example.com',
      inviteId: 'newbie@example.com', createdAt: serverTimestamp(),
    }));
  });

  it('can decline (deletes the invitation)', async () => {
    await assertSucceeds(deleteDoc(doc(dbAsEmail('kwesi', 'kwesi@example.com'), `${D}/invites/kwesi@example.com`)));
  });
});

describe('Invitations: removing roles', () => {
  it('an FA official can remove a referee', async () => {
    await assertSucceeds(removeRole(dbAs('fa1'), 'fa1', 'ref1', 'ref1@example.com', 'referee'));
  });

  it('an FA official cannot remove another FA official', async () => {
    await assertFails(removeRole(dbAs('fa1'), 'fa1', 'off1', 'off1@example.com', 'faAdmin'));
  });

  it('the chairman can remove an FA official', async () => {
    await assertSucceeds(removeRole(dbAs('chair'), 'chair', 'off1', 'off1@example.com', 'faAdmin'));
  });

  it("nobody can remove the chairman's role", async () => {
    await assertFails(deleteDoc(doc(dbAs('off1'), `${D}/users/chair`)));
  });

  it('nobody can remove their own role', async () => {
    await assertFails(deleteDoc(doc(dbAs('off1'), `${D}/users/off1`)));
  });

  it("a team admin's role cannot be removed this way", async () => {
    await assertFails(deleteDoc(doc(dbAs('chair'), `${D}/users/admin1`)));
  });

  it('an FA official cannot cancel an FA official invitation', async () => {
    await assertFails(deleteDoc(doc(dbAs('fa1'), `${D}/invites/efua@example.com`)));
  });

  it('the role history cannot be edited', async () => {
    const db = dbAs('chair');
    const ref = doc(collection(db, `${D}/roleLog`));
    await setDoc(ref, {
      email: 'x@example.com', role: 'referee', action: 'invited',
      by: 'chair', byName: 'Kofi', at: serverTimestamp(),
    });
    await assertFails(updateDoc(ref, { action: 'removed' }));
    await assertFails(deleteDoc(ref));
  });
});

// ---------- What the team changed (2.3c) ----------

describe('Re-check: what the team changed', () => {
  const p1 = (db) => doc(db, `${D}/players/p1`); // approved, GE26-0001

  /** The team changes p1's jersey from 10 to 14 and says so. */
  async function changeJersey() {
    const db = dbAs('admin1');
    const batch = writeBatch(db);
    batch.update(p1(db), {
      jerseyNo: 14,
      status: 'pending',
      changes: { jerseyNo: { from: '#10', to: '#14' } },
      updatedAt: serverTimestamp(),
    });
    batch.delete(doc(db, `${D}/teams/royal/jerseys/division-10`));
    batch.set(doc(db, `${D}/teams/royal/jerseys/division-14`), {
      playerId: 'p1', createdAt: serverTimestamp(),
    });
    return batch.commit();
  }

  it('the team can save the list of changes when re-submitting', async () => {
    await assertSucceeds(changeJersey());
  });

  it('the FA approval clears the list (ID kept)', async () => {
    await changeJersey();
    await assertSucceeds(approvePlayer(dbAs('fa1'), 'p1', { counter: 'none' }));
  });

  it('the FA cannot approve and leave the list behind', async () => {
    await changeJersey();
    await assertFails(updateDoc(p1(dbAs('fa1')), {
      status: 'approved',
      approvedAt: serverTimestamp(),
      approvedBy: 'fa1',
      rejectionReason: null,
      updatedAt: serverTimestamp(),
    }));
  });

  it('the FA rejection clears the list too', async () => {
    await changeJersey();
    await assertSucceeds(rejectPlayer(dbAs('fa1'), 'p1'));
  });

  it('the list cannot be added to an approved player that stays approved', async () => {
    await assertFails(updateDoc(p1(dbAs('admin1')), {
      position: 'DM',
      positionGroup: 'MID',
      changes: { position: { from: 'CM', to: 'DM' } },
      updatedAt: serverTimestamp(),
    }));
  });
});
