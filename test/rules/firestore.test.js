// Security rules tests for GEDFA Connect (step 1.7).
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
    await set(`${D}/users/other`, { email: 'other@example.com' });

    // Teams
    await set(`${D}/teams/royal`, { name: 'Royal Unique FC', categories: ['division'] });
    await set(`${D}/teams/stars`, { name: 'Gomoa Stars', categories: ['division'] });

    // Another person's team request
    await set(`${D}/teamRequests/other`, { teamName: 'Other FC', status: 'pending' });

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

  it('cannot approve a request yet (comes in 2.2)', async () => {
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
