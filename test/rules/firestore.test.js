// Security rules tests for GEDFA Connect (steps 1.7 to 2.13d).
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
function sendTeamRequest(db, uid, changes = {}) {
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
});
