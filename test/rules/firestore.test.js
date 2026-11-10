// Security rules tests for GEDFA Connect (steps 1.7 to 2.14a).
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
import assert from 'node:assert/strict';
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
  increment,
  arrayUnion,
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
  // 'division-10', or 'juvenile-U13-10' for a juvenile player (2.14)
  const jerseyId = data.category === 'juvenile'
    ? `juvenile-${data.ageGroup}-${data.jerseyNo}`
    : `${data.category}-${data.jerseyNo}`;
  batch.set(
    doc(db, `${D}/teams/${data.teamId}/jerseys/${jerseyId}`),
    { playerId, createdAt: serverTimestamp() },
  );
  batch.set(doc(db, `${D}/playerKeys/${data.playerKey}`), {
    playerId,
    teamId: data.teamId,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}

/** Team colours: red / white at home, white / red away (2.13b). */
const COLOURS = {
  home: { main: '#D71920', second: '#FFFFFF' },
  away: { main: '#FFFFFF', second: '#D71920' },
};

/** A full set of kits, e.g. for the juvenile sides. */
const KITS = {
  home: { primary: '#1E5BC6' },
  away: { primary: '#FFFFFF' },
  goalkeeper: { primary: '#009A44', photos: { shirt: 'https://e.com/s.jpg', shorts: 'https://e.com/sh.jpg', socks: 'https://e.com/so.jpg' } },
};

/** Sends a team request the way the app does: request + name reservation. */
function sendTeamRequest(db, uid, changes = {}, { reserveJuvenile = true } = {}) {
  const data = {
    teamName: 'Test United',
    teamNameLower: 'test united',
    nameKey: 'test-united',
    shortName: 'TUN',
    town: 'Afransi',
    homeGround: 'Afransi Park',
    categories: ['division'],
    logoUrl: 'https://example.com/logo.jpg',
    clubStatus: 'existing',
    kits: {
      home: { shirt: '#D32F2F' },
      away: { shirt: '#FFFFFF' },
      goalkeeper: { shirt: '#388E3C' },
    },
    colours: COLOURS,
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
  // A juvenile side's own name is reserved in the same batch (JSb)
  if (data.juvenileNameKey && reserveJuvenile) {
    batch.set(doc(db, `${D}/teamNames/${data.juvenileNameKey}`), {
      uid,
      createdAt: serverTimestamp(),
    });
  }
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
    // The applicant's season fee is started, so the FA may approve (2.13c)
    await set(`${D}/fees/2026-27_applicant`, {
      season: '2026-27', requestUid: 'applicant', teamName: 'Gomoa United FC', confirmed: 500,
    });

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

  it('cannot add a juvenile player like a Division one (no age group or guardian)', async () => {
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

// ---------- Juvenile players (2.14) ----------

/** A juvenile player: born 2015 (11 in 2026), U13, with a mother. */
function juvenileData(changes = {}) {
  const born = changes.born ?? 2015;
  const fullName = changes.fullName ?? 'Esi Mensah';
  const data = playerData({
    category: 'juvenile',
    fullName,
    fullNameLower: fullName.toLowerCase(),
    dob: Timestamp.fromDate(new Date(Date.UTC(born, 2, 3))),
    playerKey: `esi-mensah_${born}-03-03_juvenile`,
    ageGroup: 'U13',
    guardian: { relation: 'mother', name: 'Abena Mensah', phone: '+233245551234' },
    jerseyNo: 9,
    ...changes,
  });
  delete data.born;
  return data;
}

describe('Juvenile players', () => {
  beforeEach(async () => {
    // Royal plays in both competitions
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teams/royal`),
        { name: 'Royal Unique FC', categories: ['division', 'juvenile'] });
    });
  });

  it('a U13 player with a parent can be added', async () => {
    await assertSucceeds(addPlayer(dbAs('admin1'), 'j1', juvenileData()));
  });

  it('a younger player can play up (born 2015 in U15)', async () => {
    await assertSucceeds(addPlayer(dbAs('admin1'), 'j1', juvenileData({ ageGroup: 'U15' })));
  });

  it('nobody plays down (born 2011 = 15, not U13)', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'j1', juvenileData({ born: 2011 })));
    await assertSucceeds(addPlayer(dbAs('admin1'), 'j2', juvenileData({ born: 2011, ageGroup: 'U15' })));
  });

  it('nobody over 17 (born 2008 = 18)', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'j1', juvenileData({ born: 2008, ageGroup: 'U17' })));
  });

  it('a parent or guardian is required', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'j1', without(juvenileData(), 'guardian')));
    await assertFails(addPlayer(dbAs('admin1'), 'j1',
      juvenileData({ guardian: { relation: 'uncle', name: 'Kofi', phone: '+233245551234' } })));
  });

  it('each age group has its own jersey numbers', async () => {
    await addPlayer(dbAs('admin1'), 'j1', juvenileData());
    await assertSucceeds(addPlayer(dbAs('admin1'), 'j2', juvenileData({
      fullName: 'Ama Owusu', playerKey: 'ama-owusu_2015-03-03_juvenile', ageGroup: 'U15',
    })));
  });

  it('the same child can also be in the Division squad', async () => {
    await addPlayer(dbAs('admin1'), 'j1', juvenileData({ born: 2010, ageGroup: 'U17' }));
    await assertSucceeds(addPlayer(dbAs('admin1'), 'd1', playerData({
      fullName: 'Esi Mensah', fullNameLower: 'esi mensah',
      dob: Timestamp.fromDate(new Date(Date.UTC(2010, 2, 3))),
      playerKey: 'esi-mensah_2010-03-03', jerseyNo: 23,
    })));
  });

  it('a team not in the Juvenile competition cannot add juvenile players', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teams/royal`),
        { name: 'Royal Unique FC', categories: ['division'] });
    });
    await assertFails(addPlayer(dbAs('admin1'), 'j1', juvenileData()));
  });

  it('a Division player has no age group or guardian', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'd1', playerData({
      fullName: 'Kofi Mensah', fullNameLower: 'kofi mensah', playerKey: 'kofi-mensah_2003-05-01',
      jerseyNo: 11, ageGroup: 'U17',
    })));
  });
});

// ---------- Team requests: club status, logo, officials (2.13) ----------

const LETTER = 'https://example.com/letter.pdf';
const SEVEN = Array.from({ length: 7 }, (_, i) => ({ name: `Official ${i + 1}` }));

describe('Team requests: club status, logo and officials', () => {
  it('a club already in the district needs no letter', async () => {
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie'));
  });

  it('a new club can send its last league and letter', async () => {
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie', {
      clubStatus: 'new', lastLeague: 'Awutu Senya Division Three', letterUrl: LETTER,
    }));
  });

  it('a new club must upload the letter', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      clubStatus: 'new', lastLeague: 'Awutu Senya Division Three',
    }));
  });

  it('a new club must give its last league', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      clubStatus: 'new', letterUrl: LETTER,
    }));
  });

  it('a club in the district cannot keep a letter or league', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { letterUrl: LETTER }));
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { lastLeague: 'Some League' }));
  });

  it('the club status must be one of the two', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { clubStatus: 'maybe' }));
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { clubStatus: null }));
  });

  it('the logo is required', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { logoUrl: null }));
  });

  it('a licence needs its type (photo or PDF)', async () => {
    const licenceUrl = 'https://example.com/licence.pdf';
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie', { licenceUrl, licenceType: 'pdf' }));
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { licenceUrl }));
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { licenceUrl, licenceType: 'word' }));
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { licenceType: 'pdf' }));
  });

  it('allows 7 officials but not 8', async () => {
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie', { officials: SEVEN }));
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      officials: [...SEVEN, { name: 'Official 8' }],
    }));
  });
});

// ---------- Team requests: kits and colours (2.13b) ----------

describe('Team requests: kits and colours', () => {
  it('a club in both competitions sends separate juvenile kits', async () => {
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie', {
      categories: ['division', 'juvenile'], juvenileKits: KITS,
    }));
  });

  it('a club in both competitions must send juvenile kits', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      categories: ['division', 'juvenile'],
    }));
  });

  it('juvenile kits need home, away and goalkeeper', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      categories: ['division', 'juvenile'],
      juvenileKits: { home: KITS.home, away: KITS.away },
    }));
  });

  it('a club in one competition has no separate juvenile kits', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { juvenileKits: KITS }));
  });

  it('a juvenile-only club uses kits, like everyone', async () => {
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie', { categories: ['juvenile'] }));
  });

  it('team colours are required', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', { colours: null }));
  });

  it('team colours need home and away, each main and second', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      colours: { home: COLOURS.home },
    }));
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      colours: { ...COLOURS, away: { main: '#FFFFFF' } },
    }));
  });

  it('colours must be #RRGGBB', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      colours: { ...COLOURS, home: { main: 'red', second: '#FFFFFF' } },
    }));
  });
});

// ---------- Season fee: payments, receipts, totals (2.13c) ----------

const SEASON = '2026-27';

/** A MoMo payment as the club sends it. Pass changes to break it. */
function momoPayment(changes = {}) {
  return {
    requestUid: 'newbie',
    teamId: null,
    teamName: 'Test United',
    season: SEASON,
    method: 'momo',
    amount: 500,
    reference: '8123456789',
    paidOn: Timestamp.fromDate(new Date(Date.UTC(2026, 9, 12))),
    proofUrl: null,
    status: 'waiting',
    recordedBy: 'club',
    createdBy: 'newbie',
    createdAt: serverTimestamp(),
    ...changes,
  };
}

function sendPayment(db, id = 'pay1', changes = {}) {
  return setDoc(doc(db, `${D}/payments/${id}`), momoPayment(changes));
}

/**
 * The FA confirms a payment the way the app does: the payment, the
 * receipt counter and the club's total in one batch.
 */
function confirmPayment(db, { id = 'pay1', uid = 'newbie', amount = 500,
  receipt = 'GEDFA-2026-0001', next = 2, total = 500, skipTotal = false, by = 'fa1' } = {}) {
  const batch = writeBatch(db);
  batch.update(doc(db, `${D}/payments/${id}`), {
    status: 'confirmed',
    amount,
    receiptNo: receipt,
    reviewedBy: by,
    reviewedAt: serverTimestamp(),
  });
  batch.set(doc(db, `${D}/settings/receiptCounter`), { next });
  if (!skipTotal) {
    batch.set(doc(db, `${D}/fees/${SEASON}_${uid}`), {
      season: SEASON, requestUid: uid, teamName: 'Test United', confirmed: total,
      updatedAt: serverTimestamp(),
    });
  }
  return batch.commit();
}

describe('Season fee: the club', () => {
  beforeEach(async () => {
    await sendTeamRequest(dbAs('newbie'), 'newbie');
  });

  it('can send a MoMo payment', async () => {
    await assertSucceeds(sendPayment(dbAs('newbie')));
  });

  it('can send a cash payment, and "already paid" without an amount', async () => {
    await assertSucceeds(sendPayment(dbAs('newbie'), 'cash1',
      { method: 'cash', reference: null, paidOn: null, paidWhen: 'September 2026' }));
    await assertSucceeds(sendPayment(dbAs('newbie'), 'before1',
      { method: 'before', amount: null, reference: null, paidOn: null }));
  });

  it('MoMo needs the transaction ID and the date', async () => {
    await assertFails(sendPayment(dbAs('newbie'), 'p', { reference: null }));
    await assertFails(sendPayment(dbAs('newbie'), 'p', { paidOn: null }));
  });

  it('the amount is 1 to 1,000 whole cedis', async () => {
    await assertFails(sendPayment(dbAs('newbie'), 'p', { amount: 1001 }));
    await assertFails(sendPayment(dbAs('newbie'), 'p', { amount: 0 }));
    await assertFails(sendPayment(dbAs('newbie'), 'p', { amount: 99.5 }));
  });

  it('"already paid" has no amount (the FA fills it in)', async () => {
    await assertFails(sendPayment(dbAs('newbie'), 'p',
      { method: 'before', amount: 500, reference: null, paidOn: null }));
  });

  it('cannot send a payment as confirmed, or with a receipt', async () => {
    await assertFails(sendPayment(dbAs('newbie'), 'p', { status: 'confirmed' }));
    await assertFails(sendPayment(dbAs('newbie'), 'p', { receiptNo: 'GEDFA-2026-0001' }));
  });

  it('cannot send a payment for another club', async () => {
    await assertFails(sendPayment(dbAs('newbie'), 'p', { requestUid: 'other', createdBy: 'other' }));
  });

  it('cannot confirm its own payment', async () => {
    await sendPayment(dbAs('newbie'));
    await assertFails(confirmPayment(dbAs('newbie'), { by: 'newbie' }));
  });

  it('reads its own total, even before anything is confirmed', async () => {
    await assertSucceeds(getDoc(doc(dbAs('newbie'), `${D}/fees/${SEASON}_newbie`)));
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/fees/${SEASON}_applicant`)));
  });

  it('cannot write its own total', async () => {
    await assertFails(setDoc(doc(dbAs('newbie'), `${D}/fees/${SEASON}_newbie`),
      { season: SEASON, requestUid: 'newbie', teamName: 'Test United', confirmed: 1000 }));
  });
});

describe('Season fee: an approved team adds a payment', () => {
  beforeEach(async () => {
    // admin1 registered Royal Unique FC (its request is approved)
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teamRequests/admin1`),
        { teamName: 'Royal Unique FC', status: 'approved', teamId: 'royal' });
    });
  });

  const royalPayment = (changes = {}) => momoPayment({
    requestUid: 'admin1', createdBy: 'admin1', teamId: 'royal', teamName: 'Royal Unique FC', ...changes,
  });

  it('for its own team', async () => {
    await assertSucceeds(setDoc(doc(dbAs('admin1'), `${D}/payments/r1`), royalPayment()));
  });

  it('not for another team', async () => {
    await assertFails(setDoc(doc(dbAs('admin1'), `${D}/payments/r2`), royalPayment({ teamId: 'stars' })));
  });

  it('reads its own payments', async () => {
    await setDoc(doc(dbAs('admin1'), `${D}/payments/r1`), royalPayment());
    await assertSucceeds(getDocs(query(collection(dbAs('admin1'), `${D}/payments`),
      where('requestUid', '==', 'admin1'), where('season', '==', SEASON))));
    await assertFails(getDocs(query(collection(dbAs('admin2'), `${D}/payments`),
      where('requestUid', '==', 'admin1'))));
  });
});

describe('Season fee: without a registration', () => {
  it('cannot send a payment', async () => {
    await assertFails(sendPayment(dbAs('newbie')));
  });
});

describe('Season fee: the FA', () => {
  beforeEach(async () => {
    await sendTeamRequest(dbAs('newbie'), 'newbie');
    await sendPayment(dbAs('newbie'));
  });

  it('confirms with the next receipt number and adds it to the total', async () => {
    await assertSucceeds(confirmPayment(dbAs('fa1')));
  });

  it('cannot skip a receipt number', async () => {
    await assertFails(confirmPayment(dbAs('fa1'), { receipt: 'GEDFA-2026-0002' }));
  });

  it("cannot confirm without adding to the club's total", async () => {
    await assertFails(confirmPayment(dbAs('fa1'), { skipTotal: true }));
    await assertFails(confirmPayment(dbAs('fa1'), { total: 1000 }));
  });

  it("cannot change the club's amount", async () => {
    await assertFails(confirmPayment(dbAs('fa1'), { amount: 600, total: 600 }));
  });

  it('cannot confirm the same payment twice', async () => {
    await confirmPayment(dbAs('fa1'));
    await assertFails(confirmPayment(dbAs('fa1'), { receipt: 'GEDFA-2026-0002', next: 3, total: 1000 }));
  });

  it('can mark a payment not found, with a reason', async () => {
    await assertSucceeds(updateDoc(doc(dbAs('fa1'), `${D}/payments/pay1`), {
      status: 'notFound', reason: 'ID not on our statement',
      reviewedBy: 'fa1', reviewedAt: serverTimestamp(),
    }));
  });

  it('cannot mark it not found without a reason', async () => {
    await assertFails(updateDoc(doc(dbAs('fa1'), `${D}/payments/pay1`), {
      status: 'notFound', reviewedBy: 'fa1', reviewedAt: serverTimestamp(),
    }));
  });

  it('can record cash: confirmed straight away, with a receipt', async () => {
    // One database handle for the whole batch: each dbAs() call makes a
    // new Firestore instance, and a batch can't mix them.
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.set(doc(db, `${D}/payments/cash9`), {
      requestUid: 'newbie', teamId: null, teamName: 'Test United', season: SEASON,
      method: 'cash', amount: 300, paidWhen: 'at the meeting', status: 'confirmed',
      receiptNo: 'GEDFA-2026-0001', recordedBy: 'fa', createdBy: 'fa1',
      createdAt: serverTimestamp(), reviewedBy: 'fa1', reviewedAt: serverTimestamp(),
    });
    batch.set(doc(db, `${D}/settings/receiptCounter`), { next: 2 });
    batch.set(doc(db, `${D}/fees/${SEASON}_newbie`), {
      season: SEASON, requestUid: 'newbie', teamName: 'Test United', confirmed: 300,
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });

  it('"not found" can send the registration back to the club, in one batch', async () => {
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/payments/pay1`), {
      status: 'notFound', reason: 'ID not on our statement',
      reviewedBy: 'fa1', reviewedAt: serverTimestamp(),
    });
    batch.update(doc(db, `${D}/teamRequests/newbie`), {
      status: 'rejected', rejectionReason: 'Payment not found: ID not on our statement',
      reviewedBy: 'fa1', reviewedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });

  it('can correct the amount of cash it recorded (the total follows)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `${D}/payments/cash8`), {
        requestUid: 'newbie', teamName: 'Test United', season: SEASON, method: 'cash',
        amount: 300, status: 'confirmed', receiptNo: 'GEDFA-2026-0001', recordedBy: 'fa',
      });
      await setDoc(doc(db, `${D}/fees/${SEASON}_newbie`), {
        season: SEASON, requestUid: 'newbie', teamName: 'Test United', confirmed: 300,
      });
    });
    const correct = (total) => {
      const db = dbAs('fa1');
      const batch = writeBatch(db);
      batch.update(doc(db, `${D}/payments/cash8`), {
        amount: 200, editedBy: 'fa1', editedAt: serverTimestamp(),
      });
      batch.set(doc(db, `${D}/fees/${SEASON}_newbie`), { confirmed: total }, { merge: true });
      return batch.commit();
    };
    await assertFails(correct(300));   // total not corrected
    await assertSucceeds(correct(200));
  });

  it("cannot change the amount of a payment the club sent", async () => {
    await confirmPayment(dbAs('fa1'));
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/payments/pay1`), {
      amount: 400, editedBy: 'fa1', editedAt: serverTimestamp(),
    });
    batch.set(doc(db, `${D}/fees/${SEASON}_newbie`), { confirmed: 400 }, { merge: true });
    await assertFails(batch.commit());
  });

  it('a team admin cannot confirm payments', async () => {
    await assertFails(confirmPayment(dbAs('admin1'), { by: 'admin1' }));
  });

  it('cannot approve a team before a payment is confirmed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(doc(context.firestore(), `${D}/fees/2026-27_applicant`));
    });
    await assertFails(approve(dbAs('fa1')));
  });
});

// ---------- League settings (2.13d) ----------

const LEAGUE = `${D}/settings/league`;

function saveLeague(db, fields, by) {
  return setDoc(doc(db, LEAGUE), {
    ...fields, updatedBy: by, updatedAt: serverTimestamp(),
  }, { merge: true });
}

async function seedLeague(fields) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), LEAGUE), fields);
  });
}

describe('League settings', () => {
  it('everyone signed in can read them', async () => {
    await seedLeague({ maxSquadSize: 30 });
    await assertSucceeds(getDoc(doc(dbAs('admin1'), LEAGUE)));
  });

  it('any FA official can open or close registration and set squad numbers', async () => {
    await assertSucceeds(saveLeague(dbAs('fa1'),
      { teamRegistrationOpen: false, playerRegistrationOpen: false, maxSquadSize: 28 }, 'fa1'));
  });

  it('squad numbers stay in range', async () => {
    await assertFails(saveLeague(dbAs('fa1'), { maxSquadSize: 60 }, 'fa1'));
    await assertFails(saveLeague(dbAs('fa1'), { minPlayers: 5 }, 'fa1'));
  });

  it('only the chairman changes the season, fee and MoMo number', async () => {
    await assertFails(saveLeague(dbAs('fa1'), { fee: 1200 }, 'fa1'));
    await assertFails(saveLeague(dbAs('fa1'), { momoNumber: '0244 000 111' }, 'fa1'));
    await assertSucceeds(saveLeague(dbAs('chair'), { fee: 1200, momoNumber: '0244 000 111' }, 'chair'));
  });

  it('a team admin cannot change them', async () => {
    await assertFails(saveLeague(dbAs('admin1'), { playerRegistrationOpen: true }, 'admin1'));
  });

  it('the history: the FA writes its own lines, nobody edits them', async () => {
    const entry = (by) => ({ by, byName: 'Kofi', at: serverTimestamp(), changes: { fee: { from: 1000, to: 1200 } } });
    await assertSucceeds(setDoc(doc(dbAs('fa1'), `${D}/settingsLog/h1`), entry('fa1')));
    await assertFails(setDoc(doc(dbAs('fa1'), `${D}/settingsLog/h2`), entry('chair')));
    await assertFails(setDoc(doc(dbAs('admin1'), `${D}/settingsLog/h3`), entry('admin1')));
    await assertFails(updateDoc(doc(dbAs('fa1'), `${D}/settingsLog/h1`), { byName: 'Someone' }));
  });

  it('team registration closed: no new requests', async () => {
    await seedLeague({ teamRegistrationOpen: false });
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie'));
  });

  it('team registration closed: a club already registered can still edit', async () => {
    await sendTeamRequest(dbAs('newbie'), 'newbie');
    await seedLeague({ teamRegistrationOpen: false });
    await assertSucceeds(updateDoc(doc(dbAs('newbie'), `${D}/teamRequests/newbie`), {
      town: 'Afransi Junction', updatedAt: serverTimestamp(),
    }));
  });

  it('player registration closed: no new players', async () => {
    await seedLeague({ playerRegistrationOpen: false });
    await assertFails(addPlayer(dbAs('admin1'), 'x1', playerData({
      fullName: 'Kofi Mensah', playerKey: 'kofi-mensah_2003-05-01', jerseyNo: 11,
    })));
  });

  it("the fee comes from the settings (here GH₵ 1,200)", async () => {
    await seedLeague({ fee: 1200 });
    await sendTeamRequest(dbAs('newbie'), 'newbie');
    await assertSucceeds(sendPayment(dbAs('newbie'), 'big', { amount: 1100 }));
    await assertFails(sendPayment(dbAs('newbie'), 'bigger', { amount: 1300 }));
  });
});

// ---------- Juvenile side names: registration (JSb) ----------

describe('Team requests: juvenile side name (JSb)', () => {
  const BOTH = { categories: ['division', 'juvenile'], juvenileKits: KITS };
  const OWN = {
    ...BOTH,
    juvenileName: 'Test United Colts', juvenileShortName: 'TUC', juvenileNameKey: 'test-united-colts',
  };

  it('a club in both may keep "B" (no juvenile name)', async () => {
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie', BOTH));
  });

  it('...or send its own juvenile name, reserved in the same batch', async () => {
    await assertSucceeds(sendTeamRequest(dbAs('newbie'), 'newbie', OWN));
  });

  it('an own juvenile name must be reserved in the same batch', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', OWN, { reserveJuvenile: false }));
  });

  it("an own juvenile name can't be another club's name", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teamNames/test-united-colts`), { uid: 'someoneElse' });
    });
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', OWN));
  });

  it('a club in one competition has no juvenile name', async () => {
    await assertFails(sendTeamRequest(dbAs('newbie'), 'newbie', {
      ...OWN, categories: ['juvenile'], juvenileKits: null,
    }));
  });

  it("the juvenile name and short name differ from the club's, and the short name is 3–4 capitals", async () => {
    const db = dbAs('newbie');
    await assertFails(sendTeamRequest(db, 'newbie', { ...OWN, juvenileShortName: 'TUN' }));
    await assertFails(sendTeamRequest(db, 'newbie', { ...OWN, juvenileShortName: 'tuc' }));
    await assertFails(sendTeamRequest(db, 'newbie', { ...OWN, juvenileShortName: 'TU' }));
    await assertFails(sendTeamRequest(db, 'newbie', { ...OWN, juvenileNameKey: 'test-united' }));
    await assertFails(sendTeamRequest(db, 'newbie', { ...OWN, juvenileName: 'T' }));
    // A name needs its short name, and the other way round
    await assertFails(sendTeamRequest(db, 'newbie', without(OWN, 'juvenileShortName')));
    await assertFails(sendTeamRequest(db, 'newbie', without(OWN, 'juvenileName')));
  });

  it("the club can't give up its juvenile name while its request uses it", async () => {
    await sendTeamRequest(dbAs('newbie'), 'newbie', OWN);
    await assertFails(deleteDoc(doc(dbAs('newbie'), `${D}/teamNames/test-united-colts`)));
  });

  it('switching back to "B" frees the juvenile name in the same batch', async () => {
    await sendTeamRequest(dbAs('newbie'), 'newbie', OWN);
    const db = dbAs('newbie');
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/teamRequests/newbie`), {
      juvenileName: null, juvenileShortName: null, juvenileNameKey: null, updatedAt: serverTimestamp(),
    });
    batch.delete(doc(db, `${D}/teamNames/test-united-colts`));
    await assertSucceeds(batch.commit());
  });
});

// ---------- FA admin: approve and reject (2.2) ----------

/**
 * Approves a request the way the app does: request + team + user role in
 * one batch. Pass changes to break one part on purpose.
 */
function approve(db, { uid = 'applicant', teamId = 'gomoa-united-fc', by = 'fa1',
  role = 'teamAdmin', skipTeam = false, skipUser = false, team = {} } = {}) {
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
      ...team,
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

  it("the team gets the request's juvenile side name exactly (JSb)", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/teamRequests/applicant`), {
        juvenileName: 'Gomoa United Colts', juvenileShortName: 'GUC',
      });
    });
    await assertFails(approve(dbAs('fa1'), { team: { categories: ['division', 'juvenile'] } }));
    await assertFails(approve(dbAs('fa1'), { team: {
      categories: ['division', 'juvenile'], juvenileName: 'Other Colts', juvenileShortName: 'GUC',
    } }));
    await assertSucceeds(approve(dbAs('fa1'), { team: {
      categories: ['division', 'juvenile'], juvenileName: 'Gomoa United Colts', juvenileShortName: 'GUC',
    } }));
  });

  it('a request with "B" makes a team without a juvenile name', async () => {
    await assertFails(approve(dbAs('fa1'), { team: { juvenileName: 'Gomoa United Colts' } }));
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
function approvePlayer(db, playerId, {
  by = 'fa1', code, next, counter = 'update', squad = 'royal_division',
} = {}) {
  const batch = writeBatch(db);
  if (squad) addToSquad(batch, db, squad, playerId);
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

/**
 * Puts [playerId] on the squad list [squadId] ('royal_division',
 * 'royal_U13'…) the way the app does: one player per write (3.1a1).
 */
function addToSquad(batch, db, squadId, playerId) {
  const [teamId, group] = squadId.split('_');
  batch.set(doc(db, `${D}/squads/${squadId}`), {
    teamId, group, players: { [playerId]: true }, changed: playerId, updatedAt: serverTimestamp(),
  }, { merge: true });
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

// ---------- Player profiles and armbands (2.3d) ----------

/** A valid profile for p1 (Royal). Pass changes to break it. */
function profileData(changes = {}) {
  return {
    teamId: 'royal',
    heightCm: 182,
    weightKg: 76,
    foot: 'right',
    otherPositions: ['CB', 'DM'],
    strengths: ['heading', 'tackling', 'leadership'],
    hometown: 'Gomoa Fetteh',
    clubSince: 2023,
    previousClub: 'Afransi Stars',
    availability: 'injured',
    expectedBack: Timestamp.fromDate(new Date(Date.now() + 20 * 86400000)),
    availabilityAt: serverTimestamp(),
    emergencyName: 'Akua Boateng (mother)',
    emergencyPhone: '0241234567',
    updatedAt: serverTimestamp(),
    ...changes,
  };
}

const profile = (db, id = 'p1') => doc(db, `${D}/playerProfiles/${id}`);
const armbands = (db, team = 'royal') => doc(db, `${D}/teams/${team}/armbands/division`);

describe('Player profiles', () => {
  it('the team can save a profile without the FA', async () => {
    await assertSucceeds(setDoc(profile(dbAs('admin1')), profileData()));
  });

  it('the team can read its own profiles; the FA can read any', async () => {
    await setDoc(profile(dbAs('admin1')), profileData());
    await assertSucceeds(getDoc(profile(dbAs('admin1'))));
    await assertSucceeds(getDoc(profile(dbAs('fa1'))));
  });

  it("another team cannot read or write it (emergency contact is private)", async () => {
    await setDoc(profile(dbAs('admin1')), profileData());
    await assertFails(getDoc(profile(dbAs('admin2'))));
    await assertFails(setDoc(profile(dbAs('admin2')), profileData()));
  });

  it("cannot save a profile for another team's player", async () => {
    await assertFails(setDoc(profile(dbAs('admin1'), 'p2'), profileData()));
  });

  it('cannot use an impossible height or a strength that does not exist', async () => {
    await assertFails(setDoc(profile(dbAs('admin1')), profileData({ heightCm: 300 })));
    await assertFails(setDoc(profile(dbAs('admin1')), profileData({ strengths: ['magic'] })));
  });

  it('cannot pick more than 2 other positions or 3 strengths', async () => {
    await assertFails(setDoc(profile(dbAs('admin1')), profileData({ otherPositions: ['CB', 'DM', 'RB'] })));
    await assertFails(setDoc(profile(dbAs('admin1')), profileData({ strengths: ['pace', 'heading', 'tackling', 'passing'] })));
  });

  it('unavailable can say why (from the list only)', async () => {
    const db = dbAs('admin1');
    await assertSucceeds(setDoc(profile(db), profileData({
      availability: 'unavailable', unavailableReason: 'away',
    })));
    await assertFails(setDoc(profile(db), profileData({
      availability: 'unavailable', unavailableReason: 'sick',
    })));
    await assertFails(setDoc(profile(db), profileData({
      availability: 'injured', unavailableReason: 'away',
    })));
  });

  it('cannot write extra fields (e.g. medical details)', async () => {
    await assertFails(setDoc(profile(dbAs('admin1')), profileData({ injury: 'hamstring' })));
  });

  it("saving a profile doesn't touch the FA's approval", async () => {
    await setDoc(profile(dbAs('admin1')), profileData());
    let status;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), `${D}/players/p1`));
      status = snap.data().status;
    });
    if (status !== 'approved') throw new Error('p1 should still be approved');
  });
});

describe('Armbands', () => {
  it('the team can set its captain and vice-captain', async () => {
    await assertSucceeds(setDoc(armbands(dbAs('admin1')), {
      captainId: 'p1', viceCaptainId: 'p3', updatedAt: serverTimestamp(),
    }));
  });

  it('the same player cannot be captain and vice-captain', async () => {
    await assertFails(setDoc(armbands(dbAs('admin1')), {
      captainId: 'p1', viceCaptainId: 'p1', updatedAt: serverTimestamp(),
    }));
  });

  it("cannot make another team's player captain", async () => {
    await assertFails(setDoc(armbands(dbAs('admin1')), {
      captainId: 'p2', viceCaptainId: null, updatedAt: serverTimestamp(),
    }));
  });

  it("another team cannot change the armbands", async () => {
    await assertFails(setDoc(armbands(dbAs('admin2'), 'royal'), {
      captainId: null, viceCaptainId: null, updatedAt: serverTimestamp(),
    }));
  });
});

// ---------- Announcements and notifications (2.7 – 2.8) ----------

function announcementData(changes = {}) {
  return {
    title: 'Registration closes 15 Nov',
    body: 'All Division players must be registered by Saturday 15 November.',
    to: 'division',
    important: true,
    pinned: true,
    createdBy: 'fa1',
    createdByName: 'Kofi Mensah',
    createdAt: serverTimestamp(),
    ...changes,
  };
}

/** A grouped notification the way the app writes it (set + merge). */
function notify(db, id, data) {
  return setDoc(doc(db, `${D}/notifications/${id}`), {
    names: arrayUnion(...(data.names ?? ['Someone'])),
    count: increment(1),
    day: '2026-10-24',
    teamName: 'Royal Unique FC',
    updatedAt: serverTimestamp(),
    ...data,
    ...(data.names ? { names: arrayUnion(...data.names) } : {}),
  }, { merge: true });
}

describe('Announcements', () => {
  it('any FA admin can publish', async () => {
    await assertSucceeds(setDoc(doc(dbAs('fa1'), `${D}/announcements/a1`), announcementData()));
  });

  it('a team admin cannot publish', async () => {
    await assertFails(setDoc(doc(dbAs('admin1'), `${D}/announcements/a1`),
      announcementData({ createdBy: 'admin1' })));
  });

  it('team admins and referees can read; role-less users cannot', async () => {
    await setDoc(doc(dbAs('fa1'), `${D}/announcements/a1`), announcementData());
    await assertSucceeds(getDoc(doc(dbAs('admin1'), `${D}/announcements/a1`)));
    await assertSucceeds(getDoc(doc(dbAs('ref1'), `${D}/announcements/a1`)));
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/announcements/a1`)));
  });

  it('the FA can unpin but not rewrite the text', async () => {
    const ref = doc(dbAs('fa1'), `${D}/announcements/a1`);
    await setDoc(ref, announcementData());
    await assertSucceeds(updateDoc(ref, { pinned: false }));
    await assertFails(updateDoc(ref, { title: 'Something else' }));
  });

  it('a team marks it seen for its own team only; only the FA reads who saw it', async () => {
    await setDoc(doc(dbAs('fa1'), `${D}/announcements/a1`), announcementData());
    const mine = (db, key) => doc(db, `${D}/announcements/a1/seen/${key}`);
    await assertSucceeds(setDoc(mine(dbAs('admin1'), 'royal'), { at: serverTimestamp(), by: 'admin1' }));
    await assertFails(setDoc(mine(dbAs('admin1'), 'stars'), { at: serverTimestamp(), by: 'admin1' }));
    await assertFails(getDocs(collection(dbAs('admin1'), `${D}/announcements/a1/seen`)));
    await assertSucceeds(getDocs(collection(dbAs('fa1'), `${D}/announcements/a1/seen`)));
  });
});

// ---------- Juvenile screening days (2.14b) ----------

function screeningData(changes = {}) {
  return {
    startsAt: Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 3600 * 1000)),
    venue: 'Fetteh Park',
    groups: ['U13', 'U15'],
    note: 'Birth certificate and a parent or guardian',
    announcementId: 'ann1',
    season: '2026-27',
    createdBy: 'fa1',
    createdAt: serverTimestamp(),
    ...changes,
  };
}

/** "Save and announce": the day and its announcement in one batch. */
function saveScreening(db, dayChanges = {}, announcementChanges = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `${D}/announcements/ann1`),
    announcementData({ to: 'juvenile', pinned: false, ...announcementChanges }));
  batch.set(doc(db, `${D}/screeningDays/day1`), screeningData(dayChanges));
  return batch.commit();
}

describe('Juvenile screening days', () => {
  it('the FA saves a day together with its Juvenile announcement', async () => {
    await assertSucceeds(saveScreening(dbAs('fa1')));
  });

  it('a day needs its announcement, and it must be for Juvenile teams', async () => {
    const db = dbAs('fa1');
    await assertFails(setDoc(doc(db, `${D}/screeningDays/day1`), screeningData()));
    await assertFails(saveScreening(dbAs('fa1'), {}, { to: 'division' }));
  });

  it('a day must be in the future, with valid age groups and a venue', async () => {
    const past = Timestamp.fromDate(new Date(Date.now() - 3600 * 1000));
    await assertFails(saveScreening(dbAs('fa1'), { startsAt: past }));
    await assertFails(saveScreening(dbAs('fa1'), { groups: [] }));
    await assertFails(saveScreening(dbAs('fa1'), { groups: ['U13', 'U19'] }));
    await assertFails(saveScreening(dbAs('fa1'), { groups: ['U13', 'U13'] }));
    await assertFails(saveScreening(dbAs('fa1'), { venue: '' }));
  });

  it('a team admin cannot add a day; teams and referees can read them', async () => {
    await assertFails(saveScreening(dbAs('admin1'), { createdBy: 'admin1' },
      { createdBy: 'admin1' }));
    await saveScreening(dbAs('fa1'));
    await assertSucceeds(getDoc(doc(dbAs('admin1'), `${D}/screeningDays/day1`)));
    await assertSucceeds(getDoc(doc(dbAs('ref1'), `${D}/screeningDays/day1`)));
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/screeningDays/day1`)));
  });

  it('only the FA cancels a day, and nobody edits one', async () => {
    await saveScreening(dbAs('fa1'));
    await assertFails(updateDoc(doc(dbAs('fa1'), `${D}/screeningDays/day1`),
      { venue: 'Afransi Park' }));
    await assertFails(deleteDoc(doc(dbAs('admin1'), `${D}/screeningDays/day1`)));
    await assertSucceeds(deleteDoc(doc(dbAs('fa1'), `${D}/screeningDays/day1`)));
  });
});

// ---------- Juvenile screening decisions (2.14c) ----------

const JCOUNTER = `${D}/settings/juvenileCounter`;

/**
 * Passes a child the way the app does: the player (GJ ID, maybe an older
 * group), the moved jersey reservation and the juvenile counter together.
 */
function passJuvenile(db, playerId, {
  code, next, group = 'U13', from = 'U13', jersey = 9, counter = 'create', day = 'day1',
  squad = `royal_${group}`,
} = {}) {
  const batch = writeBatch(db);
  if (squad) addToSquad(batch, db, squad, playerId);
  batch.update(doc(db, `${D}/players/${playerId}`), {
    status: 'approved',
    screeningDayId: day,
    playerCode: code,
    ageGroup: group,
    approvedAt: serverTimestamp(),
    approvedBy: 'fa1',
    rejectionReason: null,
    changes: deleteField(),
    updatedAt: serverTimestamp(),
  });
  if (group !== from) {
    batch.delete(doc(db, `${D}/teams/royal/jerseys/juvenile-${from}-${jersey}`));
    batch.set(doc(db, `${D}/teams/royal/jerseys/juvenile-${group}-${jersey}`),
      { playerId, createdAt: serverTimestamp() });
  }
  if (counter === 'create') batch.set(doc(db, JCOUNTER), { next });
  if (counter === 'update') batch.update(doc(db, JCOUNTER), { next });
  return batch.commit();
}

/** "Not eligible for Juvenile" with a reason. */
function notEligible(db, playerId, reason = 'Looks older than 17', day = 'day1') {
  return updateDoc(doc(db, `${D}/players/${playerId}`), {
    status: 'rejected',
    notEligible: true,
    screeningDayId: day,
    rejectionReason: reason,
    reviewedAt: serverTimestamp(),
    reviewedBy: 'fa1',
    changes: deleteField(),
    updatedAt: serverTimestamp(),
  });
}

/** "Needs correcting": back to the team with a reason (2.14d). */
function sendBack(db, playerId, reason = 'Photo is not clear', day = 'day1') {
  return updateDoc(doc(db, `${D}/players/${playerId}`), {
    status: 'rejected',
    screeningDayId: day,
    rejectionReason: reason,
    reviewedAt: serverTimestamp(),
    reviewedBy: 'fa1',
    changes: deleteField(),
    updatedAt: serverTimestamp(),
  });
}

/** A screening day [hoursAgo] hours ago (negative = in the future). */
async function seedDay(id, hoursAgo, groups = ['U13', 'U15', 'U17']) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `${D}/screeningDays/${id}`), {
      startsAt: Timestamp.fromDate(new Date(Date.now() - hoursAgo * 3600 * 1000)),
      venue: 'Fetteh Park', groups, announcementId: 'ann1', season: '2026-27',
      createdBy: 'fa1', createdAt: Timestamp.now(),
    });
  });
}

describe('Juvenile screening decisions', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teams/royal`),
        { name: 'Royal Unique FC', categories: ['division', 'juvenile'] });
    });
    await seedDay('day1', 1); // started an hour ago
    await addPlayer(dbAs('admin1'), 'j1', juvenileData()); // born 2015, U13, #9
  });

  it('the FA passes a child with the first juvenile ID (GJ…-0001)', async () => {
    await assertSucceeds(passJuvenile(dbAs('fa1'), 'j1', { code: `GJ${YY}-0001`, next: 2 }));
  });

  it('juvenile IDs have their own counter, separate from Division', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), JCOUNTER), { next: 5 });
      await setDoc(doc(context.firestore(), COUNTER), { next: 40 });
    });
    await assertFails(passJuvenile(dbAs('fa1'), 'j1', {
      code: `GJ${YY}-0040`, next: 41, counter: 'update',
    }));
    await assertSucceeds(passJuvenile(dbAs('fa1'), 'j1', {
      code: `GJ${YY}-0005`, next: 6, counter: 'update',
    }));
  });

  it('a child cannot get a Division (GE) ID', async () => {
    await assertFails(approvePlayer(dbAs('fa1'), 'j1', {
      code: `GE${YY}-0001`, next: 2, counter: 'create',
    }));
  });

  it('moved up to U15: the jersey reservation moves with the child', async () => {
    await assertSucceeds(passJuvenile(dbAs('fa1'), 'j1', {
      code: `GJ${YY}-0001`, next: 2, group: 'U15',
    }));
  });

  it('moving up without moving the jersey reservation is refused', async () => {
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/players/j1`), {
      status: 'approved', playerCode: `GJ${YY}-0001`, ageGroup: 'U15', screeningDayId: 'day1',
      approvedAt: serverTimestamp(), approvedBy: 'fa1', rejectionReason: null,
      changes: deleteField(), updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, JCOUNTER), { next: 2 });
    await assertFails(batch.commit());
  });

  it('nobody is moved down (registered U15, passed in U13)', async () => {
    await addPlayer(dbAs('admin1'), 'j2', juvenileData({
      fullName: 'Ama Owusu', playerKey: 'ama-owusu_2015-03-03_juvenile', ageGroup: 'U15', jerseyNo: 4,
    }));
    await assertFails(passJuvenile(dbAs('fa1'), 'j2', {
      code: `GJ${YY}-0001`, next: 2, group: 'U13', from: 'U15', jersey: 4,
    }));
  });

  it('a team admin cannot screen its own children', async () => {
    await assertFails(notEligible(dbAs('admin1'), 'j1'));
  });

  it('not eligible needs a reason', async () => {
    await assertFails(notEligible(dbAs('fa1'), 'j1', 'No'));
    await assertSucceeds(notEligible(dbAs('fa1'), 'j1'));
  });

  it('a child found not eligible cannot be edited or added again', async () => {
    await notEligible(dbAs('fa1'), 'j1');
    await assertFails(updateDoc(doc(dbAs('admin1'), `${D}/players/j1`), {
      status: 'pending', notEligible: deleteField(), updatedAt: serverTimestamp(),
    }));
    await assertFails(addPlayer(dbAs('admin1'), 'j9', juvenileData({ ageGroup: 'U15', jerseyNo: 30 })));
  });

  it('a team cannot write the not-eligible flag itself', async () => {
    await assertFails(addPlayer(dbAs('admin1'), 'j3', juvenileData({
      fullName: 'Kojo Badu', playerKey: 'kojo-badu_2015-03-03_juvenile', jerseyNo: 11, notEligible: false,
    })));
  });

  it('2.14d: no decision before the screening day starts', async () => {
    await seedDay('later', -2); // in two hours
    await assertFails(passJuvenile(dbAs('fa1'), 'j1', { code: `GJ${YY}-0001`, next: 2, day: 'later' }));
    await assertFails(notEligible(dbAs('fa1'), 'j1', 'Looks older than 17', 'later'));
  });

  it('2.14d: no decision on an old day, or without a day', async () => {
    await seedDay('old', 30); // 30 hours ago
    await assertFails(sendBack(dbAs('fa1'), 'j1', 'Photo is not clear', 'old'));
    await assertFails(sendBack(dbAs('fa1'), 'j1', 'Photo is not clear', 'nope'));
  });

  it("2.14d: the day must cover the child's age group", async () => {
    await seedDay('u17only', 1, ['U17']);
    await assertFails(passJuvenile(dbAs('fa1'), 'j1', { code: `GJ${YY}-0001`, next: 2, day: 'u17only' }));
  });

  it('2.14d: needs correcting goes back to the team, who fix it and send it again', async () => {
    await assertFails(sendBack(dbAs('fa1'), 'j1', 'No'));
    await assertSucceeds(sendBack(dbAs('fa1'), 'j1'));
    await assertSucceeds(updateDoc(doc(dbAs('admin1'), `${D}/players/j1`), {
      status: 'pending', rejectionReason: null, updatedAt: serverTimestamp(),
    }));
  });

  it('2.14d: the team cannot change the screening day on the player', async () => {
    await sendBack(dbAs('fa1'), 'j1');
    await assertFails(updateDoc(doc(dbAs('admin1'), `${D}/players/j1`), {
      status: 'pending', screeningDayId: 'other', updatedAt: serverTimestamp(),
    }));
  });

  it('the FA tells the team: juvenile players passed / not eligible', async () => {
    await assertSucceeds(notify(dbAs('fa1'), 'team_juvenilePassed_royal',
      { audience: 'team:royal', kind: 'juvenilePassed', teamId: 'royal' }));
    await assertSucceeds(notify(dbAs('fa1'), 'team_juvenileNotEligible_royal',
      { audience: 'team:royal', kind: 'juvenileNotEligible', teamId: 'royal' }));
    await assertSucceeds(notify(dbAs('fa1'), 'team_juvenileToCorrect_royal',
      { audience: 'team:royal', kind: 'juvenileToCorrect', teamId: 'royal' }));
  });
});

// ---------- Team profile: direct edits (2.10a) ----------

const OFFICIALS = [
  { role: 'teamManager', name: 'Kwame Asante', phone: '+233244000001', licence: null },
  { role: 'headCoach', name: 'Yaw Boateng', phone: '+233244000002', licence: null },
];
describe('Team profile (2.10a)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teams/royal`), {
        name: 'Royal Unique FC', shortName: 'RUFC', town: 'Gomoa Fetteh',
        homeGround: 'Fetteh Park', categories: ['division'], kits: KITS,
        colours: COLOURS, officials: OFFICIALS, logoUrl: 'https://example.com/logo.png',
        adminUids: ['admin1'], updatedAt: Timestamp.now(),
      });
    });
  });

  const edit = (db, changes) => updateDoc(doc(db, `${D}/teams/royal`),
    { ...changes, updatedAt: serverTimestamp() });

  it('the team admin changes the town, ground, colours, kits and officials straight away', async () => {
    const db = dbAs('admin1');
    await assertSucceeds(edit(db, { town: 'Gomoa Afransi', homeGround: 'Afransi Park', homeGroundDirections: 'Near the market' }));
    await assertSucceeds(edit(db, { colours: { ...COLOURS, away: { main: '#000000', second: '#FFFFFF' } } }));
    await assertSucceeds(edit(db, { kits: KITS }));
    await assertSucceeds(edit(db, { officials: [...OFFICIALS, { role: 'chairman', name: 'Kofi Mensah', phone: '+233244000003', licence: null }] }));
  });

  it('name, short name, logo and competitions need the FA (2.10b)', async () => {
    const db = dbAs('admin1');
    await assertFails(edit(db, { name: 'Royal Stars FC' }));
    await assertFails(edit(db, { shortName: 'RSFC' }));
    await assertFails(edit(db, { logoUrl: 'https://example.com/new.png' }));
    await assertFails(edit(db, { categories: ['division', 'juvenile'] }));
    await assertFails(edit(db, { adminUids: ['admin1', 'admin2'] }));
  });

  it('another team cannot edit it', async () => {
    await assertFails(edit(dbAs('admin2'), { homeGround: 'Somewhere Park' }));
  });

  it('edits must stay valid', async () => {
    const db = dbAs('admin1');
    await assertFails(edit(db, { homeGround: 'X' }));
    await assertFails(edit(db, { kits: { home: KITS.home, away: KITS.away } }));
    await assertFails(edit(db, { officials: [OFFICIALS[0]] }));
    await assertFails(edit(db, { colours: { home: COLOURS.home } }));
    // Separate juvenile kits only for a club in both competitions
    await assertFails(edit(db, { juvenileKits: KITS }));
  });

  it('the team tells the FA: "Royal Unique FC updated their kits"', async () => {
    await assertSucceeds(notify(dbAs('admin1'), 'fa_teamUpdated_royal',
      { audience: 'fa', kind: 'teamUpdated', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'fa_teamUpdated_stars',
      { audience: 'fa', kind: 'teamUpdated', teamId: 'stars' }));
  });
});

describe('Change requests (2.10b)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const now = Timestamp.now();
      await setDoc(doc(db, `${D}/teams/royal`), {
        name: 'Royal Unique FC', nameLower: 'royal unique fc', nameKey: 'royal',
        shortName: 'RUFC', town: 'Gomoa Fetteh', homeGround: 'Fetteh Park',
        categories: ['division'], kits: KITS, juvenileKits: null, colours: COLOURS,
        officials: OFFICIALS, logoUrl: 'https://example.com/logo.png',
        adminUids: ['admin1'], requestUid: 'admin1', updatedAt: now,
      });
      await setDoc(doc(db, `${D}/teams/stars`), {
        name: 'Gomoa Stars', shortName: 'GST', categories: ['juvenile'], kits: KITS,
        adminUids: ['admin2'], requestUid: 'admin2', updatedAt: now,
      });
      await setDoc(doc(db, `${D}/teamNames/royal`), { uid: 'admin1', createdAt: now });
      await setDoc(doc(db, `${D}/teamNames/gomoa-stars`), { uid: 'admin2', createdAt: now });
    });
  });

  /** What the team sends for [kind] (pass changes to break it). */
  const changeData = (kind, changes = {}) => ({
    teamId: 'royal',
    teamName: 'Royal Unique FC',
    kind,
    ...{
      name: { from: 'Royal Unique FC', to: 'Royal Unique Stars FC', nameKey: 'royal-unique-stars-fc' },
      shortName: { from: 'RUFC', to: 'RUSF' },
      logo: { from: 'https://example.com/logo.png', to: 'https://example.com/logo-2.jpg' },
      competition: { from: ['division'], to: 'juvenile' },
    }[kind],
    reason: 'The club merged with Fetteh Stars this season.',
    status: 'pending',
    askedBy: 'admin1',
    askedByName: 'Kwame Asante',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...changes,
  });

  const ask = (db, kind, changes = {}, id = `royal_${kind}`) =>
    setDoc(doc(db, `${D}/teamChanges/${id}`), changeData(kind, changes));

  /** Puts a pending request in place, with the rules off. */
  const seedChange = (kind, changes = {}) =>
    testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teamChanges/royal_${kind}`),
        { ...changeData(kind), createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...changes });
    });

  const decided = (db, batch, kind, status, changes = {}) =>
    batch.update(doc(db, `${D}/teamChanges/royal_${kind}`), {
      status, reviewedBy: 'fa1', reviewedAt: serverTimestamp(), updatedAt: serverTimestamp(), ...changes,
    });

  const teamUpdate = (db, batch, changes) =>
    batch.update(doc(db, `${D}/teams/royal`), { ...changes, updatedAt: serverTimestamp() });

  /** The FA's full "approve the new name" batch, as the app sends it. */
  function approveName(db, { to = 'Royal Unique Stars FC', key = 'royal-unique-stars-fc', reserve = true, players = true } = {}) {
    const batch = writeBatch(db);
    decided(db, batch, 'name', 'approved');
    teamUpdate(db, batch, { name: to, nameLower: to.toLowerCase() });
    if (reserve) {
      batch.set(doc(db, `${D}/teamNames/${key}`), { uid: 'admin1', teamId: 'royal', createdAt: serverTimestamp() });
    }
    if (players) {
      batch.update(doc(db, `${D}/players/p1`), { teamName: to });
      batch.update(doc(db, `${D}/players/p3`), { teamName: to });
    }
    return batch.commit();
  }

  it('the team asks for a new name, short name, logo or competition, with a bell note for the FA', async () => {
    const db = dbAs('admin1');
    const batch = writeBatch(db);
    batch.set(doc(db, `${D}/teamChanges/royal_name`), changeData('name'));
    batch.set(doc(db, `${D}/notifications/fa_changeRequested_royal_d`), {
      audience: 'fa', kind: 'changeRequested', teamId: 'royal', teamName: 'Royal Unique FC',
      names: arrayUnion('name'), count: increment(1), day: '2026-11-07', updatedAt: serverTimestamp(),
    }, { merge: true });
    await assertSucceeds(batch.commit());
    await assertSucceeds(ask(db, 'shortName'));
    await assertSucceeds(ask(db, 'logo'));
    await assertSucceeds(ask(db, 'competition'));
  });

  it('one pending request of each kind; asking again only after the FA decided', async () => {
    const db = dbAs('admin1');
    await seedChange('name');
    await assertFails(ask(db, 'name', { to: 'Royal Stars FC', nameKey: 'royal-stars-fc' }));
    await seedChange('name', { status: 'rejected', rejectionReason: 'Too close to another club' });
    await assertSucceeds(ask(db, 'name', { to: 'Royal Stars FC', nameKey: 'royal-stars-fc' }));
  });

  it('a name another club holds is refused; the club\'s own old name is fine', async () => {
    const db = dbAs('admin1');
    await assertFails(ask(db, 'name', { to: 'Gomoa Stars', nameKey: 'gomoa-stars' }));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teamNames/royal-fc`), { uid: 'admin1', teamId: 'royal', createdAt: Timestamp.now() });
    });
    await assertSucceeds(ask(db, 'name', { to: 'Royal FC', nameKey: 'royal-fc' }));
  });

  it('another team cannot ask for it, and the request must be complete', async () => {
    await assertFails(ask(dbAs('admin2'), 'name'));
    await assertFails(ask(dbAs('admin2'), 'name', { teamId: 'stars' }, 'royal_name'));
    const db = dbAs('admin1');
    await assertFails(ask(db, 'name', {}, 'royal_logo'));
    await assertFails(ask(db, 'name', { reason: 'Why' }));
    await assertFails(ask(db, 'name', { to: 'Royal Unique FC' }));
    await assertFails(ask(db, 'name', { from: 'Somebody FC' }));
    await assertFails(ask(db, 'name', { status: 'approved' }));
    await assertFails(ask(db, 'name', { askedBy: 'admin2' }));
    await assertFails(ask(db, 'shortName', { to: 'rufc2' }));
    await assertFails(ask(db, 'shortName', { to: 'RUFC' }));
    await assertFails(ask(db, 'logo', { to: 'https://example.com/logo.png' }));
    // Already in Division
    await assertFails(ask(db, 'competition', { to: 'division' }));
    await assertFails(ask(db, 'competition', { to: 'futsal' }));
  });

  it('the team cannot approve its own request', async () => {
    await seedChange('name');
    const db = dbAs('admin1');
    await assertFails(updateDoc(doc(db, `${D}/teamChanges/royal_name`), { status: 'approved' }));
    await assertFails(updateDoc(doc(db, `${D}/teams/royal`), { name: 'Royal Unique Stars FC', updatedAt: serverTimestamp() }));
  });

  it('the team reads its own requests, not another team\'s; the FA reads all', async () => {
    await seedChange('name');
    await assertSucceeds(getDocs(query(collection(dbAs('admin1'), `${D}/teamChanges`), where('teamId', '==', 'royal'))));
    await assertFails(getDocs(query(collection(dbAs('admin2'), `${D}/teamChanges`), where('teamId', '==', 'royal'))));
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/teamChanges/royal_name`)));
    await assertSucceeds(getDocs(collection(dbAs('fa1'), `${D}/teamChanges`)));
  });

  it('the FA approves a new name: the team, its players and the name reservation in one batch', async () => {
    await seedChange('name');
    await assertSucceeds(approveName(dbAs('fa1')));
  });

  it('approving a name needs the team renamed and the new name reserved', async () => {
    await seedChange('name');
    const db = dbAs('fa1');
    const onlyApproved = writeBatch(db);
    decided(db, onlyApproved, 'name', 'approved');
    await assertFails(onlyApproved.commit());
    await assertFails(approveName(db, { reserve: false }));
    // Another name than the club asked for
    await assertFails(approveName(db, { to: 'Royal Kings FC', key: 'royal-kings-fc' }));
  });

  it('the FA cannot rename a team or its players without an approved request', async () => {
    const db = dbAs('fa1');
    await assertFails(updateDoc(doc(db, `${D}/teams/royal`), { name: 'Royal Kings FC', nameLower: 'royal kings fc', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, `${D}/players/p1`), { teamName: 'Royal Kings FC' }));
    await assertFails(setDoc(doc(db, `${D}/teamNames/royal-kings-fc`), { uid: 'admin1', teamId: 'royal', createdAt: serverTimestamp() }));
  });

  it('the club can never give up its team name reservation', async () => {
    await seedChange('name');
    await approveName(dbAs('fa1'));
    await assertFails(deleteDoc(doc(dbAs('admin1'), `${D}/teamNames/royal-unique-stars-fc`)));
  });

  it('the FA approves a short name or a logo', async () => {
    await seedChange('shortName');
    await seedChange('logo');
    const db = dbAs('fa1');
    const shortName = writeBatch(db);
    decided(db, shortName, 'shortName', 'approved');
    teamUpdate(db, shortName, { shortName: 'RUSF' });
    await assertSucceeds(shortName.commit());
    const logo = writeBatch(db);
    decided(db, logo, 'logo', 'approved');
    teamUpdate(db, logo, { logoUrl: 'https://example.com/logo-2.jpg' });
    await assertSucceeds(logo.commit());
  });

  it('applying a change touches only that change', async () => {
    await seedChange('shortName');
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    decided(db, batch, 'shortName', 'approved');
    teamUpdate(db, batch, { shortName: 'RUSF', town: 'Somewhere' });
    await assertFails(batch.commit());
  });

  it('the FA adds Juvenile to a Division club', async () => {
    await seedChange('competition');
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    decided(db, batch, 'competition', 'approved');
    teamUpdate(db, batch, { categories: ['division', 'juvenile'] });
    await assertSucceeds(batch.commit());
  });

  it('adding Division to a Juvenile club keeps its kits as the juvenile kits', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, `${D}/teams/royal`), { categories: ['juvenile'] });
      await setDoc(doc(db, `${D}/teamChanges/royal_competition`), {
        ...changeData('competition', { from: ['juvenile'], to: 'division' }),
        createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
    });
    const db = dbAs('fa1');
    const noKits = writeBatch(db);
    decided(db, noKits, 'competition', 'approved');
    teamUpdate(db, noKits, { categories: ['juvenile', 'division'] });
    await assertFails(noKits.commit());
    const batch = writeBatch(db);
    decided(db, batch, 'competition', 'approved');
    teamUpdate(db, batch, { categories: ['juvenile', 'division'], juvenileKits: KITS });
    await assertSucceeds(batch.commit());
  });

  it('the FA refuses with a reason (10 to 500 characters)', async () => {
    await seedChange('name');
    const db = dbAs('fa1');
    const ref = doc(db, `${D}/teamChanges/royal_name`);
    const refuse = (reason) => updateDoc(ref, {
      status: 'rejected', rejectionReason: reason, reviewedBy: 'fa1',
      reviewedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    await assertFails(refuse('No'));
    await assertSucceeds(refuse('Too close to Royal Kings FC in the same town.'));
    // Decided: the FA can't change it again
    await assertFails(refuse('Changed my mind about this one.'));
  });

  it('bell notes: the team tells the FA; only the FA tells the team', async () => {
    await assertSucceeds(notify(dbAs('admin1'), 'fa_changeRequested_royal',
      { audience: 'fa', kind: 'changeRequested', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'fa_changeRequested_stars',
      { audience: 'fa', kind: 'changeRequested', teamId: 'stars' }));
    await assertSucceeds(notify(dbAs('fa1'), 'team-royal_changeApproved_royal',
      { audience: 'team:royal', kind: 'changeApproved', teamId: 'royal' }));
    await assertSucceeds(notify(dbAs('fa1'), 'team-royal_changeRefused_royal',
      { audience: 'team:royal', kind: 'changeRefused', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'team-royal_changeApproved_x',
      { audience: 'team:royal', kind: 'changeApproved', teamId: 'royal' }));
  });
});

// ---------- Juvenile side names: ask the FA (JSc) ----------

describe('Juvenile side name requests (JSc)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const now = Timestamp.now();
      // A club in both competitions, its juvenile sides playing as "B"
      await setDoc(doc(db, `${D}/teams/royal`), {
        name: 'Royal Unique FC', nameLower: 'royal unique fc', nameKey: 'royal',
        shortName: 'RUFC', town: 'Gomoa Fetteh', homeGround: 'Fetteh Park',
        categories: ['division', 'juvenile'], kits: KITS, juvenileKits: KITS, colours: COLOURS,
        officials: OFFICIALS, logoUrl: 'https://example.com/logo.png',
        adminUids: ['admin1'], requestUid: 'admin1', updatedAt: now,
      });
      await setDoc(doc(db, `${D}/teams/stars`), {
        name: 'Gomoa Stars', shortName: 'GST', categories: ['juvenile'], kits: KITS,
        adminUids: ['admin2'], requestUid: 'admin2', updatedAt: now,
      });
      await setDoc(doc(db, `${D}/teamNames/royal`), { uid: 'admin1', createdAt: now });
      await setDoc(doc(db, `${D}/teamNames/gomoa-stars`), { uid: 'admin2', createdAt: now });
    });
  });

  const OWN = {
    from: 'Royal Unique FC B', fromShortName: 'RUFC B',
    to: 'Royal Unique Colts', toShortName: 'RUC', nameKey: 'royal-unique-colts',
  };

  /** What the team sends (kind juvenileName unless [kind] says otherwise). */
  const request = (changes = {}, kind = 'juvenileName', teamId = 'royal') => ({
    teamId,
    teamName: teamId === 'royal' ? 'Royal Unique FC' : 'Gomoa Stars',
    kind,
    ...(kind === 'juvenileName' ? OWN : {}),
    reason: 'Our academy is known as the Colts',
    status: 'pending',
    askedBy: teamId === 'royal' ? 'admin1' : 'admin2',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...changes,
  });

  const ask = (db, changes = {}, kind = 'juvenileName', teamId = 'royal') =>
    setDoc(doc(db, `${D}/teamChanges/${teamId}_${kind}`), request(changes, kind, teamId));

  const seedChange = (changes = {}, kind = 'juvenileName') =>
    testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teamChanges/royal_${kind}`), {
        ...request(changes, kind), createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
    });

  /** The FA's approve batch: the request, the team and the reservation. */
  function approve(db, { kind = 'juvenileName', team, reserve = 'royal-unique-colts' } = {}) {
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/teamChanges/royal_${kind}`), {
      status: 'approved', reviewedBy: 'fa1', reviewedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    batch.update(doc(db, `${D}/teams/royal`), { ...team, updatedAt: serverTimestamp() });
    if (reserve) {
      batch.set(doc(db, `${D}/teamNames/${reserve}`), { uid: 'admin1', teamId: 'royal', createdAt: serverTimestamp() });
    }
    return batch.commit();
  }

  it('a club in both asks for its juvenile side\'s own name; "Why" is optional', async () => {
    await assertSucceeds(ask(dbAs('admin1')));
  });

  it('...and may leave "Why" empty', async () => {
    await assertSucceeds(ask(dbAs('admin1'), { reason: '' }));
  });

  it('the request must say how the side plays now, and use a new, free name', async () => {
    const db = dbAs('admin1');
    await assertFails(ask(db, { from: 'Royal Unique FC', fromShortName: 'RUFC' }));
    await assertFails(ask(db, { to: 'Royal Unique FC' }));
    await assertFails(ask(db, { toShortName: 'RUFC' }));
    await assertFails(ask(db, { toShortName: 'ruc' }));
    await assertFails(ask(db, { nameKey: 'royal' }));
    // Another club's name
    await assertFails(ask(db, { to: 'Gomoa Stars', nameKey: 'gomoa-stars' }));
    // "Why" given but too short
    await assertFails(ask(db, { reason: 'Why' }));
    // Already "B": nothing to change
    await assertFails(ask(db, { to: '', toShortName: '', nameKey: null }));
  });

  it('a club in one competition has no juvenile side name to change', async () => {
    await assertFails(ask(dbAs('admin2'), {
      from: 'Gomoa Stars', fromShortName: 'GST', to: 'Gomoa Stars Colts', toShortName: 'GSC',
      nameKey: 'gomoa-stars-colts',
    }, 'juvenileName', 'stars'));
  });

  it('other kinds carry no juvenile short names, and still need a reason', async () => {
    const db = dbAs('admin1');
    await assertFails(setDoc(doc(db, `${D}/teamChanges/royal_shortName`), {
      ...request({ from: 'RUFC', to: 'RUSF', toShortName: 'RUC' }, 'shortName'),
    }));
    await assertFails(setDoc(doc(db, `${D}/teamChanges/royal_shortName`), {
      ...request({ from: 'RUFC', to: 'RUSF', reason: '' }, 'shortName'),
    }));
  });

  it('the FA approves: the team gets the name and it is reserved for the club, in one batch', async () => {
    await seedChange();
    await assertSucceeds(approve(dbAs('fa1'), {
      team: { juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC' },
    }));
  });

  it('approving needs the reservation and exactly the asked name', async () => {
    await seedChange();
    await assertFails(approve(dbAs('fa1'), {
      team: { juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC' }, reserve: null,
    }));
    await assertFails(approve(dbAs('fa1'), {
      team: { juvenileName: 'Royal Colts', juvenileShortName: 'RUC' },
    }));
  });

  it('nobody sets a juvenile name on a team without an approved request', async () => {
    const team = doc(dbAs('fa1'), `${D}/teams/royal`);
    await assertFails(updateDoc(team, {
      juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(dbAs('admin1'), `${D}/teams/royal`), {
      juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC', updatedAt: serverTimestamp(),
    }));
  });

  it('a club with its own name may go back to "B"', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/teams/royal`), {
        juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC',
      });
    });
    const back = {
      from: 'Royal Unique Colts', fromShortName: 'RUC', to: '', toShortName: '', nameKey: null,
    };
    await assertSucceeds(ask(dbAs('admin1'), back));
  });

  it('the FA approves "B": the name is removed from the team', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/teams/royal`), {
        juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC',
      });
    });
    await seedChange({
      from: 'Royal Unique Colts', fromShortName: 'RUC', to: '', toShortName: '', nameKey: null,
    });
    await assertFails(approve(dbAs('fa1'), { team: { juvenileName: 'Royal Colts' }, reserve: null }));
    await assertSucceeds(approve(dbAs('fa1'), {
      team: { juvenileName: deleteField(), juvenileShortName: deleteField() }, reserve: null,
    }));
  });

  it('"Add Juvenile" may name the juvenile side ("B" without a name)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/teams/royal`), {
        categories: ['division'], juvenileKits: null,
      });
    });
    const db = dbAs('admin1');
    const add = { from: ['division'], to: 'juvenile' };
    // A name needs its short name and key
    await assertFails(ask(db, { ...add, juvenileName: 'Royal Unique Colts' }, 'competition'));
    await assertSucceeds(ask(db, {
      ...add, juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC', nameKey: 'royal-unique-colts',
    }, 'competition'));
  });

  it('"Add Juvenile" without a name: the side will play as "B"', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/teams/royal`), {
        categories: ['division'], juvenileKits: null,
      });
    });
    await assertSucceeds(ask(dbAs('admin1'), { from: ['division'], to: 'juvenile' }, 'competition'));
  });

  it('the FA approves "Add Juvenile" with the name, reserved in the same batch', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/teams/royal`), {
        categories: ['division'], juvenileKits: null,
      });
    });
    await seedChange({
      from: ['division'], to: 'juvenile',
      juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC', nameKey: 'royal-unique-colts',
    }, 'competition');
    const team = { categories: ['division', 'juvenile'] };
    // Without the name the team would play as "B": not what was approved
    await assertFails(approve(dbAs('fa1'), { kind: 'competition', team, reserve: null }));
    await assertSucceeds(approve(dbAs('fa1'), {
      kind: 'competition',
      team: { ...team, juvenileName: 'Royal Unique Colts', juvenileShortName: 'RUC' },
    }));
  });

  it('a Juvenile-only club adding Division names no juvenile side', async () => {
    await assertFails(ask(dbAs('admin2'), {
      from: ['juvenile'], to: 'division',
      juvenileName: 'Gomoa Stars Colts', juvenileShortName: 'GSC', nameKey: 'gomoa-stars-colts',
    }, 'competition', 'stars'));
  });
});

describe('FA corrections (2.11a)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const now = Timestamp.now();
      await setDoc(doc(db, `${D}/teams/royal`), {
        name: 'Royal Unique FC', nameLower: 'royal unique fc', nameKey: 'royal',
        shortName: 'RUFC', town: 'Gomoa Fetteh', homeGround: 'Fetteh Prk',
        categories: ['division'], kits: KITS, colours: COLOURS, officials: OFFICIALS,
        logoUrl: 'https://example.com/logo.png', adminUids: ['admin1'],
        requestUid: 'admin1', updatedAt: now,
      });
      await setDoc(doc(db, `${D}/teamNames/royal`), { uid: 'admin1', createdAt: now });
      await setDoc(doc(db, `${D}/teamNames/gomoa-stars`), { uid: 'admin2', createdAt: now });
    });
  });

  /**
   * The FA's correction as the app sends it: the team (pointing at the
   * log line) and the log line, in one batch. [more] adds to the batch.
   */
  function correct(db, changes, log = {}, { id = 'c1', more } = {}) {
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/teams/royal`),
      { ...changes, lastCorrectionId: id, updatedAt: serverTimestamp() });
    batch.set(doc(db, `${D}/teams/royal/corrections/${id}`), {
      section: 'details',
      fields: Object.keys(changes).filter((field) => field !== 'nameLower'),
      lines: ['Home ground: Fetteh Prk → Fetteh Park'],
      reason: 'Spelling.',
      byUid: 'fa1',
      byName: 'Ama Owusu',
      createdAt: serverTimestamp(),
      ...log,
    });
    more?.(batch);
    return batch.commit();
  }

  /** A name correction: team, log, name reservation and players. */
  function correctName(db, { to = 'Royal Unique F.C.', key = 'royal-unique-f-c', reserve = true, players = true } = {}) {
    return correct(db, { name: to, nameLower: to.toLowerCase() },
      { section: 'name', nameKey: key, lines: [`Club name: Royal Unique FC → ${to}`] },
      {
        more: (batch) => {
          if (reserve) {
            batch.set(doc(db, `${D}/teamNames/${key}`), { uid: 'admin1', teamId: 'royal', createdAt: serverTimestamp() });
          }
          if (players) {
            batch.update(doc(db, `${D}/players/p1`), { teamName: to });
            batch.update(doc(db, `${D}/players/p3`), { teamName: to });
          }
        },
      });
  }

  it('the FA corrects the ground, town, directions, year founded and email, with a log line', async () => {
    const db = dbAs('fa1');
    await assertSucceeds(correct(db, { homeGround: 'Fetteh Park' }));
    await assertSucceeds(correct(db, { yearFounded: 1998, email: 'royal@gmail.com', town: 'Gomoa Afransi' }, {}, { id: 'c2' }));
    await assertSucceeds(correct(db, { homeGroundDirections: 'Behind the Methodist school' }, {}, { id: 'c3' }));
  });

  it('kits, colours and officials (sensitive): the FA asks the team instead (2.11b)', async () => {
    const db = dbAs('fa1');
    await assertFails(correct(db, { kits: { ...KITS, third: { primary: '#000000' } } }));
    await assertFails(correct(db, { colours: { ...COLOURS, away: { main: '#000000', second: '#FFFFFF' } } }));
    await assertFails(correct(db, { officials: [OFFICIALS[0], { ...OFFICIALS[1], phone: '+233244000009' }] }));
    // Other log sections are refused too
    await assertFails(correct(db, { homeGround: 'Fetteh Park' }, { section: 'officials' }));
  });

  it('the FA corrects the spelling of the name: the team, its players and the reservation in one batch', async () => {
    await assertSucceeds(correctName(dbAs('fa1')));
  });

  it('only the capitals of the name change: the club keeps its reservation', async () => {
    await assertSucceeds(correctName(dbAs('fa1'), { to: 'ROYAL UNIQUE FC', key: 'royal', reserve: false }));
  });

  it('a name correction needs the new name reserved for the club; another club\'s name is refused', async () => {
    const db = dbAs('fa1');
    await assertFails(correctName(db, { reserve: false }));
    await assertFails(correctName(db, { to: 'Gomoa Stars', key: 'gomoa-stars' }));
    await assertFails(correctName(db, { to: 'Gomoa Stars', key: 'gomoa-stars', reserve: false }));
    // The reservation is only for a name correction in the same batch
    await assertFails(setDoc(doc(db, `${D}/teamNames/royal-kings-fc`), { uid: 'admin1', teamId: 'royal', createdAt: serverTimestamp() }));
  });

  it('a correction needs its log line, listing exactly the fields that changed', async () => {
    const db = dbAs('fa1');
    // No log line
    await assertFails(updateDoc(doc(db, `${D}/teams/royal`),
      { homeGround: 'Fetteh Park', lastCorrectionId: 'c1', updatedAt: serverTimestamp() }));
    // The log says less, or more, than what changed
    await assertFails(correct(db, { homeGround: 'Fetteh Park', town: 'Apam' }, { fields: ['homeGround'] }));
    await assertFails(correct(db, { homeGround: 'Fetteh Park' }, { fields: ['homeGround', 'town'] }));
    // Nothing corrected
    await assertFails(correct(db, {}, { fields: ['homeGround'] }));
    // "What was wrong?" is required (5 to 300 characters)
    await assertFails(correct(db, { homeGround: 'Fetteh Park' }, { reason: 'Typo' }));
    await assertFails(correct(db, { homeGround: 'Fetteh Park' }, { byUid: 'fa2' }));
    // A name without its key
    await assertFails(correct(db, { name: 'Royal Unique F.C.', nameLower: 'royal unique f.c.' }, { section: 'name' }));
  });

  it('the FA cannot correct the short name, logo, competitions or team admins this way', async () => {
    const db = dbAs('fa1');
    await assertFails(correct(db, { shortName: 'RUF' }));
    await assertFails(correct(db, { logoUrl: 'https://example.com/new.png' }));
    await assertFails(correct(db, { categories: ['division', 'juvenile'] }));
    await assertFails(correct(db, { adminUids: ['admin1', 'admin2'] }));
  });

  it('corrections must stay valid', async () => {
    const db = dbAs('fa1');
    await assertFails(correct(db, { homeGround: 'X' }));
    await assertFails(correct(db, { officials: [OFFICIALS[0]] }));
    await assertFails(correct(db, { yearFounded: 1800 }));
    await assertFails(correct(db, { name: 'R', nameLower: 'r' }, { section: 'name', nameKey: 'r1' }));
    await assertFails(correct(db, { name: 'Royal Unique F.C.', nameLower: 'royal unique fc' }, { section: 'name', nameKey: 'royal' }));
  });

  it('a team admin cannot correct its team or write the log; it reads its own log', async () => {
    await assertFails(correct(dbAs('admin1'), { homeGround: 'Fetteh Park' }, { byUid: 'admin1' }));
    await correct(dbAs('fa1'), { homeGround: 'Fetteh Park' });
    await assertSucceeds(getDocs(collection(dbAs('admin1'), `${D}/teams/royal/corrections`)));
    await assertFails(getDocs(collection(dbAs('admin2'), `${D}/teams/royal/corrections`)));
    await assertSucceeds(getDocs(collection(dbAs('fa1'), `${D}/teams/royal/corrections`)));
  });

  it('the log is never edited or deleted', async () => {
    const db = dbAs('fa1');
    await correct(db, { homeGround: 'Fetteh Park' });
    await assertFails(updateDoc(doc(db, `${D}/teams/royal/corrections/c1`), { reason: 'Something else.' }));
    await assertFails(deleteDoc(doc(db, `${D}/teams/royal/corrections/c1`)));
  });

  it('the FA tells the team: "The FA corrected your team profile"', async () => {
    await assertSucceeds(notify(dbAs('fa1'), 'team-royal_teamCorrected_royal',
      { audience: 'team:royal', kind: 'teamCorrected', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'team-royal_teamCorrected_x',
      { audience: 'team:royal', kind: 'teamCorrected', teamId: 'royal' }));
  });
});

describe('Ask the team to correct (2.11b)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teams/royal`), {
        name: 'Royal Unique FC', shortName: 'RUFC', categories: ['division'],
        adminUids: ['admin1'], requestUid: 'admin1', updatedAt: Timestamp.now(),
      });
    });
  });

  const ref = (db) => doc(db, `${D}/correctionRequests/royal`);

  /** What the FA sends (pass changes to break it). */
  const askData = (changes = {}) => ({
    teamId: 'royal',
    teamName: 'Royal Unique FC',
    items: ['officials', 'players'],
    message: "The head coach's phone number doesn't work.",
    status: 'asked',
    askedBy: 'fa1',
    askedByName: 'Ama Owusu',
    askedAt: serverTimestamp(),
    round: 1,
    updatedAt: serverTimestamp(),
    ...changes,
  });

  /** Puts a request in place with the rules off. */
  const seed = (changes = {}) => testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(ref(context.firestore()), {
      ...askData(), askedAt: Timestamp.now(), updatedAt: Timestamp.now(), ...changes,
    });
  });

  const sendBack = (db, changes = {}) => updateDoc(ref(db), {
    status: 'sentBack', sentBackBy: 'admin1', sentBackAt: serverTimestamp(), updatedAt: serverTimestamp(), ...changes,
  });

  const markDone = (db, changes = {}) => updateDoc(ref(db), {
    status: 'done', doneBy: 'fa1', doneAt: serverTimestamp(), updatedAt: serverTimestamp(), ...changes,
  });

  it('the FA asks an approved team to correct something', async () => {
    await assertSucceeds(setDoc(ref(dbAs('fa1')), askData()));
  });

  it('the request must be complete; a team admin cannot ask', async () => {
    const db = dbAs('fa1');
    await assertFails(setDoc(ref(db), askData({ message: 'Fix it' })));
    await assertFails(setDoc(ref(db), askData({ items: [] })));
    await assertFails(setDoc(ref(db), askData({ items: ['logo'] })));
    await assertFails(setDoc(ref(db), askData({ teamName: 'Somebody FC' })));
    await assertFails(setDoc(ref(db), askData({ status: 'sentBack' })));
    await assertFails(setDoc(ref(db), askData({ askedBy: 'fa2' })));
    await assertFails(setDoc(ref(db), askData({ round: 2 })));
    await assertFails(setDoc(doc(db, `${D}/correctionRequests/nobody`), askData({ teamId: 'nobody' })));
    await assertFails(setDoc(ref(dbAs('admin1')), askData({ askedBy: 'admin1' })));
  });

  it('the team sends it back; another team cannot', async () => {
    await seed();
    await assertFails(sendBack(dbAs('admin2'), { sentBackBy: 'admin2' }));
    await assertSucceeds(sendBack(dbAs('admin1')));
  });

  it('the team cannot change what was asked, or mark it done', async () => {
    await seed();
    const db = dbAs('admin1');
    await assertFails(sendBack(db, { message: 'Nothing to fix here, sorry.' }));
    await assertFails(sendBack(db, { items: ['players'] }));
    await assertFails(markDone(db, { doneBy: 'admin1' }));
  });

  it('the FA marks it done only after the team sent it back', async () => {
    await seed();
    const db = dbAs('fa1');
    await assertFails(markDone(db));
    await sendBack(dbAs('admin1'));
    await assertSucceeds(markDone(db));
    // Done is done: the team cannot send it again
    await assertFails(sendBack(dbAs('admin1')));
  });

  it('the FA asks again after the team sent it back (or after done), never while the team is on it', async () => {
    await seed();
    const db = dbAs('fa1');
    await assertFails(setDoc(ref(db), askData({ round: 2 })));
    await sendBack(dbAs('admin1'));
    await assertFails(setDoc(ref(db), askData({ round: 1 })));
    await assertSucceeds(setDoc(ref(db), askData({ round: 2, items: ['players'] })));
    await seed({ status: 'done', round: 2 });
    await assertSucceeds(setDoc(ref(db), askData({ round: 3 })));
  });

  it('the team reads its own request, not another team\'s; only the FA lists them', async () => {
    await seed();
    await assertSucceeds(getDoc(ref(dbAs('admin1'))));
    await assertFails(getDoc(ref(dbAs('admin2'))));
    await assertFails(getDocs(collection(dbAs('admin1'), `${D}/correctionRequests`)));
    await assertSucceeds(getDocs(collection(dbAs('fa1'), `${D}/correctionRequests`)));
  });

  it('bell notes: the FA asks and marks done; the team tells the FA it sent it back', async () => {
    await assertSucceeds(notify(dbAs('fa1'), 'team-royal_correctionAsked_royal',
      { audience: 'team:royal', kind: 'correctionAsked', teamId: 'royal' }));
    await assertSucceeds(notify(dbAs('fa1'), 'team-royal_correctionDone_royal',
      { audience: 'team:royal', kind: 'correctionDone', teamId: 'royal' }));
    await assertSucceeds(notify(dbAs('admin1'), 'fa_correctionSentBack_royal',
      { audience: 'fa', kind: 'correctionSentBack', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'fa_correctionSentBack_stars',
      { audience: 'fa', kind: 'correctionSentBack', teamId: 'stars' }));
    await assertFails(notify(dbAs('admin1'), 'team-royal_correctionDone_x',
      { audience: 'team:royal', kind: 'correctionDone', teamId: 'royal' }));
  });
});

describe('Suspensions (2.11c)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teams/royal`), {
        name: 'Royal Unique FC', shortName: 'RUFC', town: 'Gomoa Fetteh',
        homeGround: 'Fetteh Park', categories: ['division'], kits: KITS,
        colours: COLOURS, officials: OFFICIALS, adminUids: ['admin1'],
        requestUid: 'admin1', updatedAt: Timestamp.now(),
      });
    });
  });

  const REASON = 'Fielded an unregistered player against Gomoa Stars on 2 Nov.';
  const inDays = (days) => Timestamp.fromMillis(Date.now() + days * 86400000);

  /** The chairman's suspend batch: the team and its history line. */
  function suspend(db, { uid = 'chair', id = 's1', until = null, team = {}, line = {} } = {}) {
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/teams/royal`), {
      suspension: {
        id, reason: REASON, since: serverTimestamp(), until, byUid: uid, byName: 'Kwesi Arthur', ...team,
      },
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, `${D}/teams/royal/suspensions/${id}`), {
      reason: REASON, since: serverTimestamp(), until, byUid: uid, byName: 'Kwesi Arthur', ...line,
    });
    return batch.commit();
  }

  /** The chairman's lift batch: the team's suspension goes, the line says why. */
  function lift(db, { uid = 'chair', id = 's1', line = {}, clear = true } = {}) {
    const batch = writeBatch(db);
    if (clear) {
      batch.update(doc(db, `${D}/teams/royal`), { suspension: deleteField(), updatedAt: serverTimestamp() });
    }
    batch.update(doc(db, `${D}/teams/royal/suspensions/${id}`), {
      liftedAt: serverTimestamp(), liftedBy: uid, liftReason: 'finePaid',
      liftNote: 'GH₵ 500 paid, receipt GEDFA-2026-0031.', liftedByName: 'Kwesi Arthur', ...line,
    });
    return batch.commit();
  }

  /** Puts a suspension in place with the rules off. */
  const seedSuspension = (until = null) => testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const since = Timestamp.fromMillis(Date.now() - 10 * 86400000);
    await updateDoc(doc(db, `${D}/teams/royal`), {
      suspension: { id: 's0', reason: REASON, since, until, byUid: 'chair' },
    });
    await setDoc(doc(db, `${D}/teams/royal/suspensions/s0`), { reason: REASON, since, until, byUid: 'chair' });
  });

  it('the chairman suspends a team, until lifted or until a date', async () => {
    await assertSucceeds(suspend(dbAs('chair')));
    await lift(dbAs('chair'));
    await assertSucceeds(suspend(dbAs('chair'), { id: 's2', until: inDays(20) }));
  });

  it('only the chairman: not another FA official, not a team admin', async () => {
    await assertFails(suspend(dbAs('fa1'), { uid: 'fa1' }));
    await assertFails(suspend(dbAs('admin1'), { uid: 'admin1' }));
  });

  it('a suspension needs a reason, a history line that matches, and a future end date', async () => {
    const db = dbAs('chair');
    await assertFails(suspend(db, { team: { reason: 'Bad' }, line: { reason: 'Bad' } }));
    await assertFails(suspend(db, { line: { reason: 'Something else entirely.' } }));
    await assertFails(suspend(db, { until: inDays(-1) }));
    await assertFails(suspend(db, { team: { byUid: 'fa1' } }));
    // No history line
    await assertFails(updateDoc(doc(db, `${D}/teams/royal`), {
      suspension: { id: 's1', reason: REASON, since: serverTimestamp(), until: null, byUid: 'chair' },
      updatedAt: serverTimestamp(),
    }));
  });

  it('a suspended team cannot add or edit players, edit its profile or ask for changes', async () => {
    await seedSuspension();
    const db = dbAs('admin1');
    await assertFails(addPlayer(db, 'p9', playerData({ fullName: 'Kojo Arthur', playerKey: 'kojo-arthur_2004-01-01', jerseyNo: 22 })));
    await assertFails(updateDoc(doc(db, `${D}/players/p3`), { position: 'ST', positionGroup: 'FWD', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, `${D}/teams/royal`), { homeGround: 'Afransi Park', updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db, `${D}/teamChanges/royal_shortName`), {
      teamId: 'royal', teamName: 'Royal Unique FC', kind: 'shortName', from: 'RUFC', to: 'RUSF',
      reason: 'The club merged this season.', status: 'pending', askedBy: 'admin1',
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    // It still reads its team
    await assertSucceeds(getDoc(doc(db, `${D}/teams/royal`)));
  });

  it('a dated suspension ends by itself: the team can edit again after the date', async () => {
    await seedSuspension(inDays(-1));
    await assertSucceeds(updateDoc(doc(dbAs('admin1'), `${D}/teams/royal`), { homeGround: 'Afransi Park', updatedAt: serverTimestamp() }));
  });

  it('a team cannot be suspended twice, but can again once a dated one has ended', async () => {
    await seedSuspension();
    await assertFails(suspend(dbAs('chair'), { id: 's2' }));
    await seedSuspension(inDays(-1));
    await assertSucceeds(suspend(dbAs('chair'), { id: 's2' }));
  });

  it('the chairman lifts it with why; "Other" needs a note', async () => {
    await seedSuspension();
    const db = dbAs('chair');
    await assertFails(lift(db, { id: 's0', line: { liftReason: 'other', liftNote: null } }));
    await assertFails(lift(db, { id: 's0', line: { liftReason: 'paidSomeone' } }));
    // The team's suspension must go in the same batch
    await assertFails(lift(db, { id: 's0', clear: false }));
    await assertFails(lift(dbAs('fa1'), { id: 's0', uid: 'fa1' }));
    await assertSucceeds(lift(db, { id: 's0' }));
    // Lifted once only
    await assertFails(updateDoc(doc(db, `${D}/teams/royal/suspensions/s0`), { liftReason: 'bondSigned' }));
  });

  it('the history: the FA and the team read it; nobody deletes it', async () => {
    await seedSuspension();
    await assertSucceeds(getDocs(collection(dbAs('admin1'), `${D}/teams/royal/suspensions`)));
    await assertSucceeds(getDocs(collection(dbAs('fa1'), `${D}/teams/royal/suspensions`)));
    await assertFails(getDocs(collection(dbAs('admin2'), `${D}/teams/royal/suspensions`)));
    await assertFails(deleteDoc(doc(dbAs('chair'), `${D}/teams/royal/suspensions/s0`)));
  });

  it('bell notes for the team: suspended and lifted (FA only)', async () => {
    await assertSucceeds(notify(dbAs('chair'), 'team-royal_teamSuspended_royal',
      { audience: 'team:royal', kind: 'teamSuspended', teamId: 'royal' }));
    await assertSucceeds(notify(dbAs('chair'), 'team-royal_suspensionLifted_royal',
      { audience: 'team:royal', kind: 'suspensionLifted', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'team-royal_suspensionLifted_x',
      { audience: 'team:royal', kind: 'suspensionLifted', teamId: 'royal' }));
  });
});

describe('Notifications', () => {
  it('the FA notifies a team, and the counts add up in one notification', async () => {
    const db = dbAs('fa1');
    const data = { audience: 'team:royal', kind: 'playersApproved', teamId: 'royal' };
    await assertSucceeds(notify(db, 'team-royal_playersApproved_2026-10-24', { ...data, names: ['Kofi Owusu (GE26-0002)'] }));
    await assertSucceeds(notify(db, 'team-royal_playersApproved_2026-10-24', { ...data, names: ['Kwame Asante (GE26-0001)'] }));
  });

  it('the team reads its own notifications, not another team\'s', async () => {
    const data = { audience: 'team:royal', kind: 'playersApproved', teamId: 'royal' };
    await notify(dbAs('fa1'), 'n1', data);
    await assertSucceeds(getDocs(query(collection(dbAs('admin1'), `${D}/notifications`),
      where('audience', '==', 'team:royal'))));
    await assertFails(getDocs(query(collection(dbAs('admin2'), `${D}/notifications`),
      where('audience', '==', 'team:royal'))));
  });

  it('a team cannot write notifications for itself or another team', async () => {
    await assertFails(notify(dbAs('admin1'), 'n1',
      { audience: 'team:royal', kind: 'playersApproved', teamId: 'royal' }));
  });

  it('a team notifies the FA about its own new players only', async () => {
    await assertSucceeds(notify(dbAs('admin1'), 'fa_playersSubmitted_royal',
      { audience: 'fa', kind: 'playersSubmitted', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'fa_playersSubmitted_stars',
      { audience: 'fa', kind: 'playersSubmitted', teamId: 'stars' }));
  });

  it('a team notifies the FA about its own new juvenile players only (2.14b)', async () => {
    await assertSucceeds(notify(dbAs('admin1'), 'fa_juvenileSubmitted_royal',
      { audience: 'fa', kind: 'juvenileSubmitted', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'fa_juvenileSubmitted_stars',
      { audience: 'fa', kind: 'juvenileSubmitted', teamId: 'stars' }));
  });

  it('only the FA reads the FA\'s notifications', async () => {
    await notify(dbAs('admin1'), 'fa_n', { audience: 'fa', kind: 'playersSubmitted', teamId: 'royal' });
    await assertSucceeds(getDocs(query(collection(dbAs('fa1'), `${D}/notifications`),
      where('audience', '==', 'fa'))));
    await assertFails(getDocs(query(collection(dbAs('admin1'), `${D}/notifications`),
      where('audience', '==', 'fa'))));
  });

  it('the FA sends a fee reminder; a team cannot (2.13c)', async () => {
    const data = { audience: 'team:royal', kind: 'feeReminder', teamId: 'royal', names: ['GH₵ 400'] };
    await assertSucceeds(notify(dbAs('fa1'), 'team-royal_feeReminder_royal_d', data));
    await assertFails(notify(dbAs('admin1'), 'team-royal_feeReminder_royal_e', data));
  });

  it('a team tells the FA about its own payment only (2.13c)', async () => {
    await assertSucceeds(notify(dbAs('admin1'), 'fa_paymentSent_royal',
      { audience: 'fa', kind: 'paymentSent', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'fa_paymentSent_stars',
      { audience: 'fa', kind: 'paymentSent', teamId: 'stars' }));
  });

  it('unknown kinds are refused', async () => {
    await assertFails(notify(dbAs('fa1'), 'n1',
      { audience: 'team:royal', kind: 'freeText', teamId: 'royal' }));
  });
});

describe('Read marks', () => {
  it('I can save when I last read my notifications, nobody else can see it', async () => {
    const mine = doc(dbAs('admin1'), `${D}/readMarks/admin1`);
    await assertSucceeds(setDoc(mine, { notificationsSeenAt: serverTimestamp(), hiddenAnnouncements: ['a1'] }));
    await assertSucceeds(getDoc(mine));
    await assertFails(getDoc(doc(dbAs('admin2'), `${D}/readMarks/admin1`)));
    await assertFails(setDoc(doc(dbAs('admin2'), `${D}/readMarks/admin1`), { notificationsSeenAt: serverTimestamp() }));
  });

  it('I can mark one note read, as it was when I read it (3.0f)', async () => {
    const mine = doc(dbAs('admin1'), `${D}/readMarks/admin1`);
    const read = Timestamp.fromDate(new Date('2026-11-09T10:42:00Z'));
    await assertSucceeds(setDoc(mine, { notificationsSeenAt: serverTimestamp() }));
    await assertSucceeds(setDoc(mine,
      { reads: { 'team-royal_playersApproved_royal_2026-11-09': read } }, { mergeFields: ['reads'] }));
    // "Mark all read" empties them again
    await assertSucceeds(setDoc(mine, { notificationsSeenAt: serverTimestamp(), reads: {} },
      { mergeFields: ['notificationsSeenAt', 'reads'] }));
  });

  it('nobody else can mark my notes read', async () => {
    const read = Timestamp.fromDate(new Date('2026-11-09T10:42:00Z'));
    await assertFails(setDoc(doc(dbAs('admin2'), `${D}/readMarks/admin1`), { reads: { n1: read } }));
    await assertFails(setDoc(doc(dbAs('fa1'), `${D}/readMarks/admin1`), { reads: { n1: read } }));
  });

  it('reads must be a map of at most 100 notes, and nothing else is saved', async () => {
    const mine = doc(dbAs('admin1'), `${D}/readMarks/admin1`);
    const read = Timestamp.fromDate(new Date('2026-11-09T10:42:00Z'));
    const many = {};
    for (let i = 0; i < 101; i++) many[`n${i}`] = read;
    await assertFails(setDoc(mine, { reads: many }));
    await assertFails(setDoc(mine, { reads: ['n1'] }));
    await assertFails(setDoc(mine, { reads: { n1: read }, unreadCount: 0 }));
    delete many.n100;
    await assertSucceeds(setDoc(mine, { reads: many }));
  });
});

// ---------- Fixtures (3.0a) ----------

/** Kits on the seeded teams for the fixture tests. */
const ROYAL_KITS = {
  home: { primary: '#7A1F2B' },
  away: { primary: '#FFFFFF' },
  goalkeeper: { primary: '#FFD100' },
};
const STARS_KITS = {
  home: { primary: '#D71920' },
  away: { primary: '#FFFFFF' },
  third: { primary: '#14213D' },
  goalkeeper: { primary: '#009A44' },
};
const COLTS_JUVENILE_KITS = {
  home: { primary: '#1E5BC6' },
  away: { primary: '#FFD100' },
  goalkeeper: { primary: '#111111' },
};

/** A Division league match, Royal (home) v Stars, in 3 days. */
function fixtureData(changes = {}) {
  return {
    season: '2026-27',
    competitionId: '2026-27_division-league',
    category: 'division',
    round: 4,
    teamIds: ['royal', 'stars'],
    home: { id: 'royal', name: 'Royal Unique FC', shortName: 'RUF', logoUrl: null, colour: '#7A1F2B' },
    away: { id: 'stars', name: 'Gomoa Stars', shortName: 'GST', logoUrl: null, colour: '#D71920' },
    kits: {
      home: { slot: 'home', kit: ROYAL_KITS.home },
      away: { slot: 'away', kit: STARS_KITS.away },
      homeGk: { slot: 'goalkeeper', kit: ROYAL_KITS.goalkeeper },
      awayGk: { slot: 'goalkeeper', kit: STARS_KITS.goalkeeper },
    },
    kickoffAt: Timestamp.fromMillis(Date.now() + 3 * 86400000),
    venue: 'Apam Park',
    status: 'scheduled',
    createdBy: 'fa1',
    createdAt: serverTimestamp(),
    updatedBy: 'fa1',
    updatedAt: serverTimestamp(),
    ...changes,
  };
}

/**
 * Adds a match the way the app does: the match, its first history line
 * and a note in each team's bell, in one batch.
 */
function addFixture(db, id, data = fixtureData(), { by = 'fa1' } = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `${D}/fixtures/${id}`), data);
  batch.set(doc(db, `${D}/fixtures/${id}/history/h1`), {
    what: 'Match added', by, byName: 'Ama Boateng', at: serverTimestamp(),
  });
  for (const team of data.teamIds) {
    batch.set(doc(db, `${D}/notifications/team-${team}_fixtureAdded_${team}_2026-11-08`), {
      audience: `team:${team}`, kind: 'fixtureAdded', teamId: team, teamName: 'x',
      names: arrayUnion('v Someone, Sat 14 Nov, 3:00 pm'), count: increment(1),
      day: '2026-11-08', updatedAt: serverTimestamp(),
    }, { merge: true });
  }
  return batch.commit();
}

/** The FA's change to a match: the new fields plus who and when. */
function changeFixture(db, id, changes) {
  return updateDoc(doc(db, `${D}/fixtures/${id}`), {
    ...changes, updatedBy: 'fa1', updatedAt: serverTimestamp(),
  });
}

describe('Fixtures (3.0a)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, `${D}/teams/royal`), { shortName: 'RUF', logoUrl: null, kits: ROYAL_KITS });
      await updateDoc(doc(db, `${D}/teams/stars`), { shortName: 'GST', logoUrl: null, kits: STARS_KITS });
      // A club in both competitions, with separate juvenile kits
      await setDoc(doc(db, `${D}/teams/colts`), {
        name: 'Apam Colts', shortName: 'APC', logoUrl: null, categories: ['division', 'juvenile'],
        kits: STARS_KITS, juvenileKits: COLTS_JUVENILE_KITS,
      });
      await setDoc(doc(db, `${D}/teams/youth`), {
        name: 'Afransi Youth', shortName: 'AFY', logoUrl: null, categories: ['juvenile'], kits: ROYAL_KITS,
      });
    });
  });

  it('the FA adds a match with its history and both teams notes in one batch', async () => {
    await assertSucceeds(addFixture(dbAs('fa1'), 'm1'));
  });

  it('a juvenile match needs an age group and uses the juvenile kits', async () => {
    const juvenile = fixtureData({
      competitionId: '2026-27_juvenile-league', category: 'juvenile', ageGroup: 'U15',
      teamIds: ['colts', 'youth'],
      home: { id: 'colts', name: 'Apam Colts B', shortName: 'APC B', logoUrl: null, colour: '#1E5BC6' },
      away: { id: 'youth', name: 'Afransi Youth', shortName: 'AFY', logoUrl: null, colour: '#7A1F2B' },
      kits: {
        home: { slot: 'home', kit: COLTS_JUVENILE_KITS.home },
        away: { slot: 'away', kit: ROYAL_KITS.away },
        homeGk: { slot: 'goalkeeper', kit: COLTS_JUVENILE_KITS.goalkeeper },
        awayGk: { slot: 'goalkeeper', kit: ROYAL_KITS.goalkeeper },
      },
    });
    await assertSucceeds(addFixture(dbAs('fa1'), 'j1', juvenile));
    await assertFails(addFixture(dbAs('fa1'), 'j2', without(juvenile, 'ageGroup')));
    // The Colts' Division kit in a juvenile match is not their juvenile kit
    await assertFails(addFixture(dbAs('fa1'), 'j3', {
      ...juvenile, kits: { ...juvenile.kits, home: { slot: 'home', kit: STARS_KITS.home } },
    }));
  });

  // Juvenile side names: a club in both plays its juvenile matches as
  // "Apam Colts B" ("APC B"), or under its own juvenile name
  function coltsYouth(colts) {
    return fixtureData({
      competitionId: '2026-27_juvenile-league', category: 'juvenile', ageGroup: 'U13',
      teamIds: ['colts', 'youth'],
      home: { id: 'colts', logoUrl: null, colour: '#1E5BC6', ...colts },
      away: { id: 'youth', name: 'Afransi Youth', shortName: 'AFY', logoUrl: null, colour: '#7A1F2B' },
      kits: {
        home: { slot: 'home', kit: COLTS_JUVENILE_KITS.home },
        away: { slot: 'away', kit: ROYAL_KITS.away },
        homeGk: { slot: 'goalkeeper', kit: COLTS_JUVENILE_KITS.goalkeeper },
        awayGk: { slot: 'goalkeeper', kit: ROYAL_KITS.goalkeeper },
      },
    });
  }

  it('a club in both plays its juvenile matches as "<name> B" ("APC B")', async () => {
    const db = dbAs('fa1');
    await assertSucceeds(addFixture(db, 'b1', coltsYouth({ name: 'Apam Colts B', shortName: 'APC B' })));
    // ...and it can be changed later (stays under the rules' 1000-expression limit)
    await assertSucceeds(changeFixture(db, 'b1', { status: 'postponed', kickoffAt: null, note: 'Pitch waterlogged' }));
    // The club's own name is its Division side, not its juvenile side
    await assertFails(addFixture(db, 'b2', coltsYouth({ name: 'Apam Colts', shortName: 'APC' })));
    // Both the name and the short name carry the B
    await assertFails(addFixture(db, 'b3', coltsYouth({ name: 'Apam Colts B', shortName: 'APC' })));
    await assertFails(addFixture(db, 'b4', coltsYouth({ name: 'Apam Colts', shortName: 'APC B' })));
  });

  it('a juvenile side with its own name plays under that name, not "B"', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/teams/colts`), {
        juvenileName: 'Apam Colts Juniors', juvenileShortName: 'ACJ',
      });
    });
    const db = dbAs('fa1');
    await assertSucceeds(addFixture(db, 'o1', coltsYouth({ name: 'Apam Colts Juniors', shortName: 'ACJ' })));
    await assertFails(addFixture(db, 'o2', coltsYouth({ name: 'Apam Colts B', shortName: 'APC B' })));
  });

  it('a club in one competition never gets a "B", and Division keeps the club name', async () => {
    const db = dbAs('fa1');
    // Afransi Youth is Juvenile only: its own name, no B
    const withB = coltsYouth({ name: 'Apam Colts B', shortName: 'APC B' });
    await assertFails(addFixture(db, 'n1', {
      ...withB, away: { ...withB.away, name: 'Afransi Youth B', shortName: 'AFY B' },
    }));
    // The Colts' Division side plays as Apam Colts
    const division = fixtureData({
      teamIds: ['colts', 'stars'],
      home: { id: 'colts', name: 'Apam Colts', shortName: 'APC', logoUrl: null, colour: '#D71920' },
      kits: {
        home: { slot: 'home', kit: STARS_KITS.home },
        away: { slot: 'away', kit: STARS_KITS.away },
        homeGk: { slot: 'goalkeeper', kit: STARS_KITS.goalkeeper },
        awayGk: { slot: 'goalkeeper', kit: STARS_KITS.goalkeeper },
      },
    });
    await assertSucceeds(addFixture(db, 'n2', division));
    await assertFails(addFixture(db, 'n3', {
      ...division, home: { ...division.home, name: 'Apam Colts B', shortName: 'APC B' },
    }));
  });

  it('a match is refused when the teams or their details are wrong', async () => {
    const db = dbAs('fa1');
    // The same team twice
    await assertFails(addFixture(db, 'x1', fixtureData({
      teamIds: ['royal', 'royal'],
      away: { id: 'royal', name: 'Royal Unique FC', shortName: 'RUF', logoUrl: null, colour: '#7A1F2B' },
    })));
    // A team that doesn't play Division (Afransi Youth is Juvenile only)
    await assertFails(addFixture(db, 'x2', fixtureData({
      teamIds: ['royal', 'youth'],
      away: { id: 'youth', name: 'Afransi Youth', shortName: 'AFY', logoUrl: null, colour: '#7A1F2B' },
    })));
    // A name that isn't the team's real name
    await assertFails(addFixture(db, 'x3', fixtureData({
      away: { id: 'stars', name: 'Stars FC', shortName: 'GST', logoUrl: null, colour: '#D71920' },
    })));
    // A kit the team doesn't have
    await assertFails(addFixture(db, 'x4', fixtureData({
      kits: { ...fixtureData().kits, away: { slot: 'away', kit: { primary: '#000000' } } },
    })));
    // teamIds that don't match the two sides
    await assertFails(addFixture(db, 'x5', fixtureData({ teamIds: ['stars', 'royal'] })));
  });

  it('a new match must be scheduled, in the future, in its own league', async () => {
    const db = dbAs('fa1');
    await assertFails(addFixture(db, 'x1', fixtureData({ kickoffAt: Timestamp.fromMillis(Date.now() - 3600000) })));
    await assertFails(addFixture(db, 'x2', fixtureData({ status: 'postponed', note: 'Rain' })));
    await assertFails(addFixture(db, 'x3', fixtureData({ competitionId: '2026-27_juvenile-league' })));
    await assertFails(addFixture(db, 'x4', fixtureData({ ageGroup: 'U13' })));
    await assertFails(addFixture(db, 'x5', fixtureData({ round: 0 })));
    await assertFails(addFixture(db, 'x6', fixtureData({ venue: '' })));
  });

  it('a team admin cannot add a match; teams and referees can read the schedule', async () => {
    await assertFails(addFixture(dbAs('admin1'), 'm1',
      fixtureData({ createdBy: 'admin1', updatedBy: 'admin1' }), { by: 'admin1' }));
    await addFixture(dbAs('fa1'), 'm1');
    await assertSucceeds(getDoc(doc(dbAs('admin2'), `${D}/fixtures/m1`)));
    await assertSucceeds(getDocs(query(collection(dbAs('admin1'), `${D}/fixtures`),
      where('teamIds', 'array-contains', 'royal'))));
    await assertSucceeds(getDoc(doc(dbAs('ref1'), `${D}/fixtures/m1`)));
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/fixtures/m1`)));
  });

  it('the FA changes a match: teams swapped, new date and venue', async () => {
    await addFixture(dbAs('fa1'), 'm1');
    const f = fixtureData();
    await assertSucceeds(changeFixture(dbAs('fa1'), 'm1', {
      teamIds: ['stars', 'royal'], home: f.away, away: f.home,
      kits: {
        home: { slot: 'home', kit: STARS_KITS.home }, away: { slot: 'away', kit: ROYAL_KITS.away },
        homeGk: f.kits.awayGk, awayGk: f.kits.homeGk,
      },
      kickoffAt: Timestamp.fromMillis(Date.now() + 5 * 86400000),
      venue: 'Gomoa Park', note: 'The ground is booked',
    }));
  });

  it('a change cannot move a match into the past or another season', async () => {
    await addFixture(dbAs('fa1'), 'm1');
    const db = dbAs('fa1');
    await assertFails(changeFixture(db, 'm1', { kickoffAt: Timestamp.fromMillis(Date.now() - 3600000) }));
    await assertFails(changeFixture(db, 'm1', { season: '2027-28', competitionId: '2027-28_division-league' }));
    await assertFails(changeFixture(db, 'm1', { createdBy: 'fa2' }));
    await assertFails(changeFixture(dbAs('admin1'), 'm1', { venue: 'Royal Park' }));
  });

  it('postponing needs a reason; the new date can come now or later', async () => {
    await addFixture(dbAs('fa1'), 'm1');
    const db = dbAs('fa1');
    await assertFails(changeFixture(db, 'm1', { status: 'postponed', kickoffAt: null }));
    await assertSucceeds(changeFixture(db, 'm1', { status: 'postponed', kickoffAt: null, note: 'Pitch waterlogged' }));
    // A scheduled match must have a date
    await assertFails(changeFixture(db, 'm1', { status: 'scheduled', kickoffAt: null, note: null }));
    await assertSucceeds(changeFixture(db, 'm1', {
      status: 'scheduled', kickoffAt: Timestamp.fromMillis(Date.now() + 7 * 86400000), note: null,
    }));
  });

  it('a cancelled match keeps its date and can never be changed again', async () => {
    await addFixture(dbAs('fa1'), 'm1');
    const db = dbAs('fa1');
    await assertFails(changeFixture(db, 'm1', { status: 'cancelled' }));
    await assertFails(changeFixture(db, 'm1', {
      status: 'cancelled', note: 'Club withdrew', kickoffAt: Timestamp.fromMillis(Date.now() + 9 * 86400000),
    }));
    await assertSucceeds(changeFixture(db, 'm1', { status: 'cancelled', note: 'Club withdrew' }));
    await assertFails(changeFixture(db, 'm1', { status: 'scheduled', note: null }));
  });

  it('nobody deletes a match', async () => {
    await addFixture(dbAs('fa1'), 'm1');
    await assertFails(deleteDoc(doc(dbAs('fa1'), `${D}/fixtures/m1`)));
  });

  it('a history line is written by the FA, for a match that exists', async () => {
    await addFixture(dbAs('fa1'), 'm1');
    const line = { what: 'Kick-off moved to 4:00 pm', by: 'fa1', byName: 'Ama Boateng', at: serverTimestamp() };
    await assertSucceeds(setDoc(doc(dbAs('fa1'), `${D}/fixtures/m1/history/h2`), line));
    await assertFails(setDoc(doc(dbAs('fa1'), `${D}/fixtures/nope/history/h1`), line));
    await assertFails(setDoc(doc(dbAs('admin1'), `${D}/fixtures/m1/history/h3`),
      { ...line, by: 'admin1' }));
    await assertSucceeds(getDocs(collection(dbAs('admin1'), `${D}/fixtures/m1/history`)));
  });

  it('only the FA writes match notes for a team bell', async () => {
    await assertSucceeds(notify(dbAs('fa1'), 'team-royal_fixturePostponed_royal_2026-11-08',
      { audience: 'team:royal', kind: 'fixturePostponed', teamId: 'royal' }));
    await assertFails(notify(dbAs('admin1'), 'team-stars_fixtureAdded_stars_2026-11-08',
      { audience: 'team:stars', kind: 'fixtureAdded', teamId: 'stars' }));
    await assertFails(notify(dbAs('admin1'), 'fa_fixtureChanged_royal_2026-11-08',
      { audience: 'fa', kind: 'fixtureChanged', teamId: 'royal' }));
  });
});

describe('Renamed teams in matches (JSc2)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, `${D}/teams/royal`), { shortName: 'RUF', logoUrl: null, kits: ROYAL_KITS });
      await updateDoc(doc(db, `${D}/teams/stars`), { shortName: 'GST', logoUrl: null, kits: STARS_KITS });
      await setDoc(doc(db, `${D}/teams/colts`), {
        name: 'Apam Colts', shortName: 'APC', logoUrl: null, categories: ['division', 'juvenile'],
        kits: STARS_KITS, juvenileKits: COLTS_JUVENILE_KITS,
      });
      await setDoc(doc(db, `${D}/teams/youth`), {
        name: 'Afransi Youth', shortName: 'AFY', logoUrl: null, categories: ['juvenile'], kits: ROYAL_KITS,
      });
    });
    await addFixture(dbAs('fa1'), 'm1');
  });

  /** The FA renamed a team (rules off, like the approved change). */
  const renameTeam = (id, changes) => testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), `${D}/teams/${id}`), changes);
  });

  const HOME = fixtureData().home;
  const until = () => Timestamp.fromMillis(Date.now() - 60000);

  /** The FA's rename of one match, as the app sends it. */
  const rename = (db, id, changes) => updateDoc(doc(db, `${D}/fixtures/${id}`), {
    ...changes, updatedBy: 'fa1', updatedAt: serverTimestamp(),
  });

  it('after a new club name, the FA renames the match with "Previously"', async () => {
    await renameTeam('royal', { name: 'Royal Stars FC' });
    await assertSucceeds(rename(dbAs('fa1'), 'm1', {
      home: { ...HOME, name: 'Royal Stars FC' },
      previousNames: { royal: { name: 'Royal Unique FC', until: until() } },
    }));
  });

  it('only to the name the team has now, and the old name goes in "Previously"', async () => {
    await renameTeam('royal', { name: 'Royal Stars FC' });
    const db = dbAs('fa1');
    await assertFails(rename(db, 'm1', {
      home: { ...HOME, name: 'Royal Something FC' },
      previousNames: { royal: { name: 'Royal Unique FC', until: until() } },
    }));
    // "Previously" must be the name the match had
    await assertFails(rename(db, 'm1', {
      home: { ...HOME, name: 'Royal Stars FC' },
      previousNames: { royal: { name: 'Gomoa United', until: until() } },
    }));
    // ...for a team in the match
    await assertFails(rename(db, 'm1', {
      home: { ...HOME, name: 'Royal Stars FC' },
      previousNames: { royal: { name: 'Royal Unique FC', until: until() }, colts: { name: 'X', until: until() } },
    }));
  });

  it('a rename changes nothing else, and only the FA does it', async () => {
    await renameTeam('royal', { name: 'Royal Stars FC' });
    const renamed = {
      home: { ...HOME, name: 'Royal Stars FC' },
      previousNames: { royal: { name: 'Royal Unique FC', until: until() } },
    };
    await assertFails(rename(dbAs('fa1'), 'm1', { ...renamed, venue: 'Royal Park' }));
    await assertFails(rename(dbAs('fa1'), 'm1', { ...renamed, home: { ...renamed.home, logoUrl: 'https://x.com/l.png' } }));
    await assertFails(updateDoc(doc(dbAs('admin1'), `${D}/fixtures/m1`), {
      ...renamed, updatedBy: 'admin1', updatedAt: serverTimestamp(),
    }));
  });

  it('a new short name alone changes the crest letters, with no "Previously"', async () => {
    await renameTeam('royal', { shortName: 'RSF' });
    await assertSucceeds(rename(dbAs('fa1'), 'm1', { home: { ...HOME, shortName: 'RSF' } }));
    await assertFails(rename(dbAs('fa1'), 'm1', {
      home: { ...HOME, shortName: 'RSF' },
      previousNames: { royal: { name: 'Royal Unique FC', until: until() } },
    }));
  });

  it('played and cancelled matches are renamed too, even if the kits changed since', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/fixtures/m1`), {
        status: 'cancelled', note: 'Club withdrew', kickoffAt: Timestamp.fromMillis(Date.now() - 86400000),
      });
    });
    await renameTeam('royal', { name: 'Royal Stars FC', kits: { ...ROYAL_KITS, home: { primary: '#000000' } } });
    await assertSucceeds(rename(dbAs('fa1'), 'm1', {
      home: { ...HOME, name: 'Royal Stars FC' },
      previousNames: { royal: { name: 'Royal Unique FC', until: until() } },
    }));
  });

  it('a "B" side follows its club: "Apam Colts B" becomes "Apam Rangers B"', async () => {
    const juvenile = fixtureData({
      competitionId: '2026-27_juvenile-league', category: 'juvenile', ageGroup: 'U15',
      teamIds: ['colts', 'youth'],
      home: { id: 'colts', name: 'Apam Colts B', shortName: 'APC B', logoUrl: null, colour: '#1E5BC6' },
      away: { id: 'youth', name: 'Afransi Youth', shortName: 'AFY', logoUrl: null, colour: '#7A1F2B' },
      kits: {
        home: { slot: 'home', kit: COLTS_JUVENILE_KITS.home },
        away: { slot: 'away', kit: ROYAL_KITS.away },
        homeGk: { slot: 'goalkeeper', kit: COLTS_JUVENILE_KITS.goalkeeper },
        awayGk: { slot: 'goalkeeper', kit: ROYAL_KITS.goalkeeper },
      },
    });
    await addFixture(dbAs('fa1'), 'j1', juvenile);
    await renameTeam('colts', { name: 'Apam Rangers' });
    const db = dbAs('fa1');
    // Not the club's Division name
    await assertFails(rename(db, 'j1', {
      home: { ...juvenile.home, name: 'Apam Rangers' },
      previousNames: { colts: { name: 'Apam Colts B', until: until() } },
    }));
    await assertSucceeds(rename(db, 'j1', {
      home: { ...juvenile.home, name: 'Apam Rangers B' },
      previousNames: { colts: { name: 'Apam Colts B', until: until() } },
    }));
  });

  it('a normal change keeps "Previously" as it is, and a new match has none', async () => {
    await renameTeam('royal', { name: 'Royal Stars FC' });
    await rename(dbAs('fa1'), 'm1', {
      home: { ...HOME, name: 'Royal Stars FC' },
      previousNames: { royal: { name: 'Royal Unique FC', until: until() } },
    });
    const db = dbAs('fa1');
    await assertSucceeds(changeFixture(db, 'm1', { venue: 'Gomoa Park' }));
    await assertFails(changeFixture(db, 'm1', { previousNames: {} }));
    await assertFails(addFixture(db, 'm2', fixtureData({
      home: { ...HOME, name: 'Royal Stars FC' },
      previousNames: { royal: { name: 'Royal Unique FC', until: until() } },
    })));
  });
});

describe('Fixtures: a team changes its kit after the match is made (3.0a)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, `${D}/teams/royal`), { shortName: 'RUF', logoUrl: null, kits: ROYAL_KITS });
      await updateDoc(doc(db, `${D}/teams/stars`), { shortName: 'GST', logoUrl: null, kits: STARS_KITS });
    });
  });

  it('the old copy is refused; the app sends a fresh copy with the change', async () => {
    await addFixture(dbAs('fa1'), 'm1');
    const newHome = { primary: '#1E5BC6' };
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/teams/royal`),
        { kits: { ...ROYAL_KITS, home: newHome } });
    });
    const db = dbAs('fa1');
    await assertFails(changeFixture(db, 'm1', { status: 'postponed', kickoffAt: null, note: 'Rain' }));
    await assertSucceeds(changeFixture(db, 'm1', {
      status: 'postponed', kickoffAt: null, note: 'Rain',
      kits: { ...fixtureData().kits, home: { slot: 'home', kit: newHome } },
    }));
  });
});

// ---------- Season drafts (3.0b) ----------

function draftData(changes = {}) {
  return {
    season: '2026-27',
    competitionId: '2026-27_division-league',
    category: 'division',
    settings: { homeAndAway: true, sundayToo: true, firstDay: Timestamp.now() },
    teamIds: ['royal', 'stars'],
    matches: [{ round: 1, homeId: 'royal', awayId: 'stars', kickoffAt: Timestamp.now(), venue: 'Apam Park' }],
    updatedBy: 'fa1',
    updatedAt: serverTimestamp(),
    ...changes,
  };
}

describe('Season drafts (3.0b)', () => {
  it('the FA saves, reads and deletes a draft', async () => {
    const ref = doc(dbAs('fa1'), `${D}/fixtureDrafts/2026-27_division-league`);
    await assertSucceeds(setDoc(ref, draftData()));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(setDoc(ref, draftData({ teamIds: ['royal', 'stars', 'colts'] })));
    await assertSucceeds(deleteDoc(ref));
  });

  it('teams cannot see or write a draft', async () => {
    await setDoc(doc(dbAs('fa1'), `${D}/fixtureDrafts/d1`), draftData());
    await assertFails(getDoc(doc(dbAs('admin1'), `${D}/fixtureDrafts/d1`)));
    await assertFails(setDoc(doc(dbAs('admin1'), `${D}/fixtureDrafts/d2`), draftData({ updatedBy: 'admin1' })));
    await assertFails(deleteDoc(doc(dbAs('admin1'), `${D}/fixtureDrafts/d1`)));
  });

  it('a draft must name its league and keep to the size limit', async () => {
    const ref = doc(dbAs('fa1'), `${D}/fixtureDrafts/d1`);
    await assertFails(setDoc(ref, draftData({ competitionId: '2026-27_juvenile-league' })));
    await assertFails(setDoc(ref, draftData({ extra: true })));
    await assertFails(setDoc(ref, draftData({ teamIds: Array.from({ length: 41 }, (_, i) => `t${i}`) })));
  });
});

// ---------- Cups and galas (3.0c1) ----------

/** A valid cup. Pass changes to make a gala or a broken one. */
function cupData(changes = {}) {
  return {
    season: '2026-27',
    kind: 'cup',
    name: 'GEDFA Cup 2026/27',
    category: 'division',
    entries: [
      { teamId: 'royal', category: 'division' },
      { teamId: 'stars', category: 'division' },
    ],
    format: 'knockout',
    legs: 2,
    level: 'penalties',
    bracketFrom: 8,
    seeded: false,
    stage: 'notDrawn',
    createdBy: 'fa1',
    createdAt: serverTimestamp(),
    updatedBy: 'fa1',
    updatedAt: serverTimestamp(),
    ...changes,
  };
}

function galaData(changes = {}) {
  return cupData({
    kind: 'gala',
    name: 'GEDFA Gala 2026',
    legs: 1,
    bracketFrom: 0,
    gala: {
      ground: 'Apam Park',
      firstDay: Timestamp.fromDate(new Date(Date.UTC(2026, 7, 29))),
      lastDay: Timestamp.fromDate(new Date(Date.UTC(2026, 7, 30))),
      kickoffHour: 9,
      kickoffMinute: 0,
      gapMinutes: 90,
    },
    ...changes,
  });
}

describe('Cups and galas (3.0c1)', () => {
  it('the FA makes a cup, a gala, a juvenile cup and an open cup; everyone with a role reads them', async () => {
    await assertSucceeds(setDoc(doc(dbAs('fa1'), `${D}/cups/c1`), cupData()));
    await assertSucceeds(setDoc(doc(dbAs('fa1'), `${D}/cups/g1`), galaData()));
    await assertSucceeds(setDoc(doc(dbAs('fa1'), `${D}/cups/j1`), cupData({ category: 'juvenile', ageGroup: 'U15', legs: 1, level: 'replay' })));
    await assertSucceeds(setDoc(doc(dbAs('fa1'), `${D}/cups/o1`), cupData({
      category: 'open',
      ageGroup: 'U17',
      entries: [{ teamId: 'royal', category: 'division' }, { teamId: 'royal', category: 'juvenile' }],
    })));
    await assertSucceeds(getDoc(doc(dbAs('admin1'), `${D}/cups/c1`)));
    await assertSucceeds(getDoc(doc(dbAs('ref1'), `${D}/cups/g1`)));
    await assertFails(getDoc(doc(dbAs('newbie'), `${D}/cups/c1`)));
  });

  it('only the FA makes one', async () => {
    await assertFails(setDoc(doc(dbAs('admin1'), `${D}/cups/c2`), cupData({ createdBy: 'admin1', updatedBy: 'admin1' })));
  });

  it('a cup must keep GEDFA\'s rules', async () => {
    const ref = doc(dbAs('fa1'), `${D}/cups/c1`);
    // A replay only with one-match rounds
    await assertFails(setDoc(ref, cupData({ level: 'replay' })));
    // Juvenile and open need an age group; Division has none
    await assertFails(setDoc(ref, cupData({ category: 'juvenile' })));
    await assertFails(setDoc(ref, cupData({ ageGroup: 'U17' })));
    await assertFails(setDoc(ref, cupData({ category: 'open', ageGroup: 'U19' })));
    // 2 to 64 sides
    await assertFails(setDoc(ref, cupData({ entries: [{ teamId: 'royal', category: 'division' }] })));
    await assertFails(setDoc(ref, cupData({ entries: Array.from({ length: 65 }, (_, i) => ({ teamId: `t${i}`, category: 'division' })) })));
    // It starts not drawn; a name; nothing extra; a cup has no gala part
    await assertFails(setDoc(ref, cupData({ stage: 'drawn' })));
    await assertFails(setDoc(ref, cupData({ name: 'GC' })));
    await assertFails(setDoc(ref, cupData({ extra: true })));
    await assertFails(setDoc(ref, cupData({ bracketFrom: 6 })));
    await assertFails(setDoc(ref, cupData({ gala: galaData().gala })));
  });

  it('a gala is one match per tie, at one ground, on days in order', async () => {
    const ref = doc(dbAs('fa1'), `${D}/cups/g1`);
    await assertFails(setDoc(ref, galaData({ legs: 2 })));
    await assertFails(setDoc(ref, galaData({ format: 'groups' })));
    await assertFails(setDoc(ref, galaData({ seeded: true })));
    await assertFails(setDoc(ref, without(galaData(), 'gala')));
    await assertFails(setDoc(ref, galaData({ gala: { ...galaData().gala, ground: '' } })));
    await assertFails(setDoc(ref, galaData({
      gala: { ...galaData().gala, lastDay: Timestamp.fromDate(new Date(Date.UTC(2026, 7, 28))) },
    })));
    await assertFails(setDoc(ref, galaData({ gala: { ...galaData().gala, gapMinutes: 10 } })));
  });
});

// ---------- A cup's page: change, delete, history (3.0c1b) ----------

/** A history line, as the app writes it. */
function cupLine(changes = {}) {
  return { text: 'Cup made', by: 'fa1', byName: 'Kofi Mensah', at: serverTimestamp(), ...changes };
}

describe('Cups: change, delete and history (3.0c1b)', () => {
  beforeEach(async () => {
    // A cup not drawn yet, and one drawn (made by fa1 yesterday)
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const made = Timestamp.fromDate(new Date(Date.now() - 86400000));
      const db = context.firestore();
      await setDoc(doc(db, `${D}/cups/c1`), cupData({ createdAt: made, updatedAt: made }));
      await setDoc(doc(db, `${D}/cups/c1/history/h1`), cupLine({ at: made }));
      await setDoc(doc(db, `${D}/cups/d1`), cupData({ stage: 'drawn', createdAt: made, updatedAt: made }));
    });
  });

  it('the FA makes a cup with its first history line in one batch', async () => {
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.set(doc(db, `${D}/cups/c9`), cupData());
    batch.set(doc(db, `${D}/cups/c9/history/h1`), cupLine());
    await assertSucceeds(batch.commit());
  });

  it('the FA changes a cup before the draw, with a history line; everyone with a role reads the history', async () => {
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/cups/c1`), { legs: 1, level: 'replay', updatedBy: 'fa1', updatedAt: serverTimestamp() });
    batch.set(doc(db, `${D}/cups/c1/history/h2`), cupLine({ text: 'Each round: home and away → one match' }));
    await assertSucceeds(batch.commit());
    // A cup made a gala: the gala part comes in
    await assertSucceeds(updateDoc(doc(db, `${D}/cups/c1`), {
      kind: 'gala', legs: 1, level: 'penalties', bracketFrom: 0, gala: galaData().gala, updatedBy: 'fa1', updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDocs(collection(dbAs('admin1'), `${D}/cups/c1/history`)));
    await assertFails(getDocs(collection(dbAs('newbie'), `${D}/cups/c1/history`)));
  });

  it("nobody else changes a cup, and not after the draw, nor who made it, its season or GEDFA's rules", async () => {
    const ref = (as, id = 'c1') => doc(dbAs(as), `${D}/cups/${id}`);
    const stamp = { updatedBy: 'fa1', updatedAt: serverTimestamp() };
    await assertFails(updateDoc(ref('admin1'), { name: 'Royal Cup', updatedBy: 'admin1', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref('fa1', 'd1'), { name: 'GEDFA Cup', ...stamp }));
    await assertFails(updateDoc(ref('fa1'), { stage: 'drawn', ...stamp }));
    await assertFails(updateDoc(ref('fa1'), { createdBy: 'fa2', ...stamp }));
    await assertFails(updateDoc(ref('fa1'), { createdAt: serverTimestamp(), ...stamp }));
    await assertFails(updateDoc(ref('fa1'), { season: '2027-28', ...stamp }));
    await assertFails(updateDoc(ref('fa1'), { level: 'replay', ...stamp }));
    await assertFails(updateDoc(ref('fa1'), { name: 'GEDFA Cup' }));
  });

  it('the FA deletes a cup with its history, even after the draw; nobody else does', async () => {
    await assertFails(deleteDoc(doc(dbAs('admin1'), `${D}/cups/c1`)));
    await assertFails(deleteDoc(doc(dbAs('admin1'), `${D}/cups/c1/history/h1`)));
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.delete(doc(db, `${D}/cups/c1/history/h1`));
    batch.delete(doc(db, `${D}/cups/c1`));
    await assertSucceeds(batch.commit());
    await assertSucceeds(deleteDoc(doc(db, `${D}/cups/d1`)));
  });

  it("a history line is the FA's own, now, for a cup that is there, and never changed", async () => {
    const line = (as, cup = 'c1') => doc(dbAs(as), `${D}/cups/${cup}/history/h9`);
    await assertSucceeds(setDoc(line('fa1'), cupLine({ text: 'Seeding: off → on' })));
    await assertFails(setDoc(line('admin1'), cupLine({ by: 'admin1' })));
    await assertFails(setDoc(line('fa1'), cupLine({ by: 'fa2' })));
    await assertFails(setDoc(line('fa1'), cupLine({ at: Timestamp.fromDate(new Date(2026, 0, 1)) })));
    await assertFails(setDoc(line('fa1'), cupLine({ text: 'ok' })));
    await assertFails(setDoc(line('fa1'), cupLine({ extra: true })));
    await assertFails(setDoc(line('fa1', 'nope'), cupLine()));
    await assertFails(updateDoc(doc(dbAs('fa1'), `${D}/cups/c1/history/h1`), { text: 'Cup made twice' }));
  });
});

describe('Postpone a league or a Gala (3.0c1c)', () => {
  const DAY = 86400000;
  const later = (days) => Timestamp.fromMillis(Date.now() + days * DAY);
  const teamNote = (team) => ({
    audience: `team:${team}`, kind: 'fixturePostponed', teamId: team, teamName: 'x',
    names: arrayUnion('Division League postponed 2 weeks: v Someone (Matchday 4) now Sat 19 Dec, 3:00 pm.'),
    count: increment(1), day: '2026-11-08', updatedAt: serverTimestamp(),
  });

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, `${D}/teams/royal`), { shortName: 'RUF', logoUrl: null, kits: ROYAL_KITS });
      await updateDoc(doc(db, `${D}/teams/stars`), { shortName: 'GST', logoUrl: null, kits: STARS_KITS });
      await setDoc(doc(db, `${D}/fixtures/m1`), fixtureData({ kickoffAt: later(3) }));
      await setDoc(doc(db, `${D}/fixtures/m2`), fixtureData({ round: 5, kickoffAt: later(10) }));
      await setDoc(doc(db, `${D}/fixtures/off`), fixtureData({ status: 'cancelled', note: 'Club withdrew' }));
      await setDoc(doc(db, `${D}/cups/g1`), galaData());
    });
  });

  it('the FA moves league matches 2 weeks later, each with a history line, then tells each team', async () => {
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    for (const [id, days] of [['m1', 3], ['m2', 10]]) {
      batch.update(doc(db, `${D}/fixtures/${id}`), {
        kickoffAt: later(days + 14), note: "The FA's congress", updatedBy: 'fa1', updatedAt: serverTimestamp(),
      });
      batch.set(doc(db, `${D}/fixtures/${id}/history/p1`), {
        what: 'Division League postponed: Sat 5 Dec, 3:00 pm → Sat 19 Dec, 3:00 pm',
        reason: "The FA's congress", by: 'fa1', byName: 'Kofi Mensah', at: serverTimestamp(),
      });
    }
    await assertSucceeds(batch.commit());
    const notes = writeBatch(db);
    for (const team of ['royal', 'stars']) {
      notes.set(doc(db, `${D}/notifications/team-${team}_fixturePostponed_${team}_2026-11-08`), teamNote(team), { merge: true });
    }
    await assertSucceeds(notes.commit());
  });

  it('a moved match stays in the future and in its league; a cancelled one never moves; only the FA moves them', async () => {
    const db = dbAs('fa1');
    await assertFails(changeFixture(db, 'm1', { kickoffAt: Timestamp.fromMillis(Date.now() - DAY) }));
    await assertFails(changeFixture(db, 'm1', { kickoffAt: later(17), competitionId: '2026-27_juvenile-league' }));
    await assertFails(changeFixture(db, 'off', { kickoffAt: later(14), note: "The FA's congress" }));
    await assertFails(updateDoc(doc(dbAs('admin1'), `${D}/fixtures/m1`), {
      kickoffAt: later(17), updatedBy: 'admin1', updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(dbAs('admin1'), `${D}/notifications/team-stars_fixturePostponed_stars_2026-11-08`),
      teamNote('stars'), { merge: true }));
  });

  it("the FA postpones a Gala before the draw: new days, a history line and every club's note in one batch", async () => {
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/cups/g1`), {
      gala: galaData({
        gala: {
          ...galaData().gala,
          firstDay: Timestamp.fromDate(new Date(Date.UTC(2026, 8, 26))),
          lastDay: Timestamp.fromDate(new Date(Date.UTC(2026, 8, 27))),
        },
      }).gala,
      updatedBy: 'fa1', updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, `${D}/cups/g1/history/p1`), cupLine({
      text: 'Postponed 4 weeks: Sat 29 Aug – Sun 30 Aug → Sat 26 Sep – Sun 27 Sep. The ground is being repaired.',
    }));
    for (const team of ['royal', 'stars']) {
      batch.set(doc(db, `${D}/notifications/team-${team}_fixturePostponed_${team}_2026-11-08`), teamNote(team), { merge: true });
    }
    await assertSucceeds(batch.commit());
  });

  it("nobody else postpones a Gala, and its new days must make sense", async () => {
    const days = (first, last) => ({
      gala: {
        ...galaData().gala,
        firstDay: Timestamp.fromDate(new Date(Date.UTC(2026, 8, first))),
        lastDay: Timestamp.fromDate(new Date(Date.UTC(2026, 8, last))),
      },
    });
    await assertFails(updateDoc(doc(dbAs('admin1'), `${D}/cups/g1`), {
      ...days(26, 27), updatedBy: 'admin1', updatedAt: serverTimestamp(),
    }));
    // The last day before the first
    await assertFails(updateDoc(doc(dbAs('fa1'), `${D}/cups/g1`), {
      ...days(27, 26), updatedBy: 'fa1', updatedAt: serverTimestamp(),
    }));
    // Without who and when
    await assertFails(updateDoc(doc(dbAs('fa1'), `${D}/cups/g1`), days(26, 27)));
  });
});

describe('Finish a stopped postpone: postponeJobs (3.0c1d)', () => {
  const DAY = 86400000;
  const later = (days) => Timestamp.fromMillis(Date.now() + days * DAY);
  const JOB = `${D}/postponeJobs/2026-27_division-league`;
  const jobData = (changes = {}) => ({
    season: '2026-27',
    competitionId: '2026-27_division-league',
    category: 'division',
    name: 'Division League',
    days: 14,
    reason: "The FA's congress",
    moves: [
      { id: 'm1', from: later(3), to: later(17) },
      { id: 'm2', from: later(10), to: later(24) },
    ],
    done: [],
    byName: 'Kofi Mensah',
    startedBy: 'fa1',
    startedAt: serverTimestamp(),
    updatedBy: 'fa1',
    updatedAt: serverTimestamp(),
    ...changes,
  });
  const tick = (db, ids, changes = {}) => updateDoc(doc(db, JOB), {
    done: arrayUnion(...ids), updatedBy: 'fa1', updatedAt: serverTimestamp(), ...changes,
  });

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, `${D}/teams/royal`), { shortName: 'RUF', logoUrl: null, kits: ROYAL_KITS });
      await updateDoc(doc(db, `${D}/teams/stars`), { shortName: 'GST', logoUrl: null, kits: STARS_KITS });
      await setDoc(doc(db, `${D}/fixtures/m1`), fixtureData({ kickoffAt: later(3) }));
      await setDoc(doc(db, `${D}/fixtures/m2`), fixtureData({ round: 5, kickoffAt: later(10) }));
    });
  });

  it('the FA saves the job before anything moves; only the FA reads it', async () => {
    await assertFails(setDoc(doc(dbAs('admin1'), JOB), jobData({ startedBy: 'admin1', updatedBy: 'admin1' })));
    await assertSucceeds(setDoc(doc(dbAs('fa1'), JOB), jobData()));
    await assertSucceeds(getDoc(doc(dbAs('fa1'), JOB)));
    await assertSucceeds(getDocs(query(collection(dbAs('fa1'), `${D}/postponeJobs`), where('season', '==', '2026-27'))));
    await assertFails(getDoc(doc(dbAs('admin1'), JOB)));
  });

  it('a league has one job at a time, and a job must fit its league', async () => {
    const db = dbAs('fa1');
    await assertFails(setDoc(doc(db, `${D}/postponeJobs/2026-27_juvenile-league`), jobData()));
    await assertFails(setDoc(doc(db, JOB), jobData({ done: ['m1'] })));
    await assertFails(setDoc(doc(db, JOB), jobData({ days: 0 })));
    await assertFails(setDoc(doc(db, JOB), jobData({ reason: 'ok' })));
    await assertFails(setDoc(doc(db, JOB), jobData({ moves: [] })));
    await assertFails(setDoc(doc(db, JOB), jobData({ startedBy: 'fa2' })));
    await assertFails(setDoc(doc(db, JOB), jobData({ extra: true })));
    await assertSucceeds(setDoc(doc(db, JOB), jobData()));
    // A second postpone of the same league while this one is there
    await assertFails(setDoc(doc(db, JOB), jobData({ days: 7 })));
  });

  it('each batch moves matches and ticks them off; ticks only grow and nothing else changes', async () => {
    const db = dbAs('fa1');
    await setDoc(doc(db, JOB), jobData());
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/fixtures/m1`), {
      kickoffAt: later(17), note: "The FA's congress", updatedBy: 'fa1', updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, `${D}/fixtures/m1/history/p1`), {
      what: 'Division League postponed: Sat 5 Dec, 3:00 pm → Sat 19 Dec, 3:00 pm',
      reason: "The FA's congress", by: 'fa1', byName: 'Kofi Mensah', at: serverTimestamp(),
    });
    batch.update(doc(db, JOB), { done: arrayUnion('m1'), updatedBy: 'fa1', updatedAt: serverTimestamp() });
    await assertSucceeds(batch.commit());
    await assertFails(tick(db, ['m2'], { days: 7 }));
    await assertFails(tick(db, ['m2'], { reason: 'Something else' }));
    await assertFails(updateDoc(doc(db, JOB), { done: [], updatedBy: 'fa1', updatedAt: serverTimestamp() }));
    await assertFails(tick(db, ['m2', 'x1']));
    await assertFails(tick(dbAs('admin1'), ['m2'], { updatedBy: 'admin1' }));
    await assertSucceeds(tick(db, ['m2']));
  });

  it('the FA removes the finished job with the last notes; nobody else does', async () => {
    const db = dbAs('fa1');
    await setDoc(doc(db, JOB), jobData());
    await assertFails(deleteDoc(doc(dbAs('admin1'), JOB)));
    const batch = writeBatch(db);
    batch.set(doc(db, `${D}/notifications/team-royal_fixturePostponed_royal_2026-11-09`), {
      audience: 'team:royal', kind: 'fixturePostponed', teamId: 'royal', teamName: 'x',
      names: arrayUnion('Division League postponed 2 weeks: v Gomoa Stars (Matchday 4) now Sat 19 Dec, 3:00 pm.'),
      count: increment(1), day: '2026-11-09', updatedAt: serverTimestamp(),
    }, { merge: true });
    batch.delete(doc(db, JOB));
    await assertSucceeds(batch.commit());
  });
});

// ---------- Squad lists (3.1a1) ----------

describe('Squad lists (3.1a1)', () => {
  const list = (db, id = 'royal_division') => doc(db, `${D}/squads/${id}`);
  /** royal_division already holds p1 (approved), with the rules off. */
  async function seedList(players = { p1: true }) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(list(context.firestore()), {
        teamId: 'royal', group: 'division', players, changed: 'p1', updatedAt: Timestamp.now(),
      });
    });
  }
  /** The team edits approved p1's name: p1 goes back to pending. */
  function sendBackP1(db, { removeFromList = true } = {}) {
    const batch = writeBatch(db);
    batch.update(doc(db, `${D}/players/p1`), {
      fullName: 'Kwame Asante Jnr', fullNameLower: 'kwame asante jnr',
      status: 'pending', updatedAt: serverTimestamp(),
    });
    if (removeFromList) {
      batch.update(list(db), {
        'players.p1': deleteField(), changed: 'p1', updatedAt: serverTimestamp(),
      });
    }
    return batch.commit();
  }

  it('approving a player puts them on the squad list', async () => {
    await seedCounter(2);
    await assertSucceeds(approvePlayer(dbAs('fa1'), 'p3', { code: `GE${YY}-0002`, next: 3 }));
    const snap = await getDoc(list(dbAs('admin1')));
    assert(snap.data().players.p3 === true);
  });

  it('an approval without the squad list is refused', async () => {
    await seedCounter(2);
    await assertFails(approvePlayer(dbAs('fa1'), 'p3', { code: `GE${YY}-0002`, next: 3, squad: null }));
  });

  it("the player can't go on another team's list or the wrong competition", async () => {
    await seedCounter(2);
    await assertFails(approvePlayer(dbAs('fa1'), 'p3', { code: `GE${YY}-0002`, next: 3, squad: 'stars_division' }));
    await assertFails(approvePlayer(dbAs('fa1'), 'p3', { code: `GE${YY}-0002`, next: 3, squad: 'royal_U17' }));
  });

  it('the FA can add a player approved before (repairing the list)', async () => {
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    addToSquad(batch, db, 'royal_division', 'p1');
    await assertSucceeds(batch.commit());
  });

  it('a pending player cannot be put on the list', async () => {
    const db = dbAs('fa1');
    const batch = writeBatch(db);
    addToSquad(batch, db, 'royal_division', 'p3');
    await assertFails(batch.commit());
  });

  it('only one player per write, and the write names them', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/players/p3`), { status: 'approved' });
    });
    await assertFails(setDoc(list(dbAs('fa1')), {
      teamId: 'royal', group: 'division', players: { p1: true, p3: true }, changed: 'p1', updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(list(dbAs('fa1')), {
      teamId: 'royal', group: 'division', players: { p1: true }, changed: 'p3', updatedAt: serverTimestamp(),
    }));
  });

  it('a team admin cannot add a player to their own list', async () => {
    const db = dbAs('admin1');
    const batch = writeBatch(db);
    addToSquad(batch, db, 'royal_division', 'p1');
    await assertFails(batch.commit());
  });

  it('the team reads its own list; another team cannot', async () => {
    await seedList();
    await assertSucceeds(getDoc(list(dbAs('admin1'))));
    await assertFails(getDoc(list(dbAs('admin2'))));
    await assertFails(getDoc(list(dbAs('newbie'))));
  });

  it('a team may look for a list that does not exist yet', async () => {
    await assertSucceeds(getDoc(list(dbAs('admin1'), 'royal_U15')));
  });

  it('an approved player sent back to pending leaves the list in the same batch', async () => {
    await seedList();
    await assertSucceeds(sendBackP1(dbAs('admin1')));
  });

  it('sending a listed player back to pending without taking them off is refused', async () => {
    await seedList();
    await assertFails(sendBackP1(dbAs('admin1'), { removeFromList: false }));
  });

  it('a team cannot take an approved player off the list', async () => {
    await seedList();
    await assertFails(updateDoc(list(dbAs('admin1')), {
      'players.p1': deleteField(), changed: 'p1', updatedAt: serverTimestamp(),
    }));
  });

  it("another team cannot touch the team's list", async () => {
    await seedList();
    const db = dbAs('admin2');
    await assertFails(updateDoc(list(db), {
      'players.p1': deleteField(), changed: 'p1', updatedAt: serverTimestamp(),
    }));
  });

  it('a child passed at screening goes on the list of the age group they end in', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/teams/royal`),
        { name: 'Royal Unique FC', categories: ['division', 'juvenile'] });
    });
    await seedDay('day1', 1);
    await addPlayer(dbAs('admin1'), 'j1', juvenileData()); // U13, #9
    await assertFails(passJuvenile(dbAs('fa1'), 'j1', {
      code: `GJ${YY}-0001`, next: 2, group: 'U15', squad: 'royal_U13',
    }));
    await assertFails(passJuvenile(dbAs('fa1'), 'j1', { code: `GJ${YY}-0001`, next: 2, squad: null }));
    await assertSucceeds(passJuvenile(dbAs('fa1'), 'j1', {
      code: `GJ${YY}-0001`, next: 2, group: 'U15',
    }));
  });
});

// ---------- Team sheets (3.1a2) ----------

describe('Team sheets (3.1a2)', () => {
  const ids = (prefix, from, to) => Array.from({ length: to - from + 1 }, (_, i) => `${prefix}${from + i}`);
  const ELEVEN = ids('s', 1, 11);

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const list = (id, players) => setDoc(doc(db, `${D}/squads/${id}`), {
        teamId: id.split('_')[0], group: id.split('_')[1],
        players: Object.fromEntries(players.map((p) => [p, true])),
        changed: players[0], updatedAt: Timestamp.now(),
      });
      // Royal's 20 approved Division players, s1 to s20
      await list('royal_division', ids('s', 1, 20));
      // Royal's children: one U13, eleven U15, one U17
      await list('royal_U13', ['k13']);
      await list('royal_U15', ids('k', 1, 11));
      await list('royal_U17', ['k17']);
      await setDoc(doc(db, `${D}/fixtures/f1`), fixtureData());
      await setDoc(doc(db, `${D}/fixtures/fj`), fixtureData({
        competitionId: '2026-27_juvenile-league', category: 'juvenile', ageGroup: 'U15',
      }));
    });
  });

  function sheet(changes = {}) {
    return {
      fixtureId: 'f1', teamId: 'royal', category: 'division',
      starters: ELEVEN, bench: ids('s', 12, 16),
      savedBy: 'admin1', savedAt: serverTimestamp(), ...changes,
    };
  }
  const save = (db, data = sheet(), id = `${data.fixtureId}_${data.teamId}`) =>
    setDoc(doc(db, `${D}/teamSheets/${id}`), data);

  it('the team saves 11 starting and 5 on the bench', async () => {
    await assertSucceeds(save(dbAs('admin1')));
  });

  it('the team can save it again with changes', async () => {
    await save(dbAs('admin1'));
    await assertSucceeds(save(dbAs('admin1'), sheet({ bench: ids('s', 12, 18) })));
  });

  it('7 starting and no bench is allowed; 6 is not', async () => {
    await assertSucceeds(save(dbAs('admin1'), sheet({ starters: ids('s', 1, 7), bench: [] })));
    await assertFails(save(dbAs('admin1'), sheet({ starters: ids('s', 1, 6), bench: [] })));
  });

  it('never more than 11 starting', async () => {
    await assertFails(save(dbAs('admin1'), sheet({ starters: ids('s', 1, 12), bench: [] })));
  });

  it('the bench opens only when 11 start', async () => {
    await assertFails(save(dbAs('admin1'), sheet({ starters: ids('s', 1, 10), bench: ['s11'] })));
  });

  it('never more than 7 on the bench', async () => {
    await assertFails(save(dbAs('admin1'), sheet({ bench: ids('s', 12, 19) })));
  });

  it('a smaller matchday squad in League settings is respected', async () => {
    await seedLeague({ matchdaySquad: 16 });
    await assertSucceeds(save(dbAs('admin1'), sheet({ bench: ids('s', 12, 16) })));
    await assertFails(save(dbAs('admin1'), sheet({ bench: ids('s', 12, 17) })));
  });

  it('the same player cannot be picked twice', async () => {
    await assertFails(save(dbAs('admin1'), sheet({ bench: ['s1', 's12'] })));
  });

  it('only players on the squad list (approved)', async () => {
    await assertFails(save(dbAs('admin1'), sheet({ bench: ['p3'] })));
    await assertFails(save(dbAs('admin1'), sheet({ starters: [...ids('s', 1, 10), 'k1'] })));
  });

  it('a juvenile U15 sheet takes U15 and U13 children, never U17', async () => {
    const juvenile = (changes) => sheet({
      fixtureId: 'fj', category: 'juvenile', ageGroup: 'U15',
      starters: [...ids('k', 1, 10), 'k13'], bench: ['k11'], ...changes,
    });
    await assertSucceeds(save(dbAs('admin1'), juvenile()));
    await assertSucceeds(save(dbAs('admin1'), juvenile({ bench: [] })));
    await assertFails(save(dbAs('admin1'), juvenile({ starters: [...ids('k', 1, 10), 'k17'], bench: [] })));
    await assertFails(save(dbAs('admin1'), juvenile({ ageGroup: 'U17', bench: [] })));
  });

  it('another team cannot save it, nor a sheet for a match it is not in', async () => {
    await assertFails(save(dbAs('admin2'), sheet({ savedBy: 'admin2' })));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${D}/fixtures/f2`),
        fixtureData({ teamIds: ['stars', 'other'] }));
    });
    await assertFails(save(dbAs('admin1'), sheet({ fixtureId: 'f2' })));
  });

  it('the sheet ID must be the match and the team', async () => {
    await assertFails(save(dbAs('admin1'), sheet(), 'f1_stars'));
  });

  it('locked from 1 hour before kick-off', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/fixtures/f1`),
        { kickoffAt: Timestamp.fromMillis(Date.now() + 50 * 60000) });
    });
    await assertFails(save(dbAs('admin1')));
  });

  it('not for a postponed match', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `${D}/fixtures/f1`),
        { status: 'postponed', kickoffAt: null, note: 'Rain' });
    });
    await assertFails(save(dbAs('admin1')));
  });

  it('signed by the person saving, at server time', async () => {
    await assertFails(save(dbAs('admin1'), sheet({ savedBy: 'fa1' })));
    await assertFails(save(dbAs('admin1'), sheet({ savedAt: Timestamp.now() })));
  });

  it('the FA cannot write a team sheet', async () => {
    await assertFails(save(dbAs('fa1'), sheet({ savedBy: 'fa1' })));
  });

  it('the team and the FA read it; the other team does not (until 3.2)', async () => {
    await save(dbAs('admin1'));
    await assertSucceeds(getDoc(doc(dbAs('admin1'), `${D}/teamSheets/f1_royal`)));
    await assertSucceeds(getDoc(doc(dbAs('fa1'), `${D}/teamSheets/f1_royal`)));
    await assertFails(getDoc(doc(dbAs('admin2'), `${D}/teamSheets/f1_royal`)));
  });

  it('a team may look for its sheet before making it', async () => {
    await assertSucceeds(getDoc(doc(dbAs('admin1'), `${D}/teamSheets/f1_royal`)));
  });
});
