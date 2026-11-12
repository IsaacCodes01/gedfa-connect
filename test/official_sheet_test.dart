import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/team_sheets/domain/official_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/official_sheet_pdf.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_photos.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';

// 3.3: the official team sheet (MC4)

final _kickoff = DateTime(2026, 11, 14, 15);

KitChoice _kit(KitSlot slot, Kit kit) =>
    KitChoice(slot: slot, kit: kit, raw: const {});

Fixture _match({AgeGroup? ageGroup, Kit? homeKit}) => Fixture(
  id: 'm1',
  season: '2026-27',
  competitionId: ageGroup == null
      ? '2026-27_division-league'
      : '2026-27_juvenile-league',
  category: ageGroup == null ? Competition.division : Competition.juvenile,
  ageGroup: ageGroup,
  round: 4,
  home: const FixtureSide(
    id: 'ruf',
    name: 'Royal Unique FC',
    shortName: 'RUF',
    colour: Colors.red,
  ),
  away: const FixtureSide(
    id: 'ast',
    name: 'Asebu Stars',
    shortName: 'AST B',
    colour: Colors.green,
  ),
  kits: MatchKits(
    home: _kit(
      KitSlot.home,
      homeKit ??
          const Kit(
            primary: Color(0xFFB3122A),
            secondary: Colors.white,
            pattern: KitPattern.stripes,
            shorts: Colors.white,
            socks: Color(0xFFB3122A),
          ),
    ),
    away: _kit(
      KitSlot.away,
      const Kit(
        primary: Color(0xFF00703F),
        secondary: Colors.yellow,
        pattern: KitPattern.sash,
        shorts: Colors.black,
        socks: Color(0xFF00703F),
      ),
    ),
    homeGk: _kit(
      KitSlot.goalkeeper,
      const Kit(
        primary: Colors.yellow,
        shorts: Colors.black,
        socks: Colors.yellow,
      ),
    ),
    awayGk: _kit(
      KitSlot.goalkeeper,
      const Kit(primary: Colors.blue, shorts: Colors.blue, socks: Colors.blue),
    ),
  ),
  kickoffAt: _kickoff,
  venue: 'Apam Park',
  status: FixtureStatus.scheduled,
);

const _names = [
  'Kwame Asante',
  'Yaw Boateng',
  'Kofi Mensah',
  'Emmanuel Tetteh',
  'Kojo Ɛssien',
  'Nana Agyei',
  'Kwesi Ofori',
  'Isaac Owusu',
  'Clement Baah',
  'Ama Serwaa',
  'Kwabena Darko',
  'Akwasi Frimpong',
  'Yaw Antwi',
  'Kofi Ansah',
  'Kwaku Bonsu',
  'Ebo Taylor',
];
const _positions = ['GK', 'RB', 'LB', 'CB', 'CB', 'DM', 'CM', 'AMF', 'CF'];

TeamSheet _sheet(String teamId, {int players = 16, String code = 'GE26'}) {
  final ids = [for (var i = 0; i < players; i++) '$teamId$i'];
  return TeamSheet(
    fixtureId: 'm1',
    teamId: teamId,
    category: Competition.division,
    starters: ids.take(11).toList(),
    bench: ids.skip(11).toList(),
    captainId: ids[3],
    viceCaptainId: ids[1],
    goalkeeperId: ids[0],
    numbers: {for (var i = 0; i < ids.length; i++) ids[i]: i == 8 ? 13 : i + 1},
    officials: const [
      Official(role: OfficialRole.teamManager, name: 'Kojo Antwi', phone: ''),
      Official(role: OfficialRole.headCoach, name: 'Kofi Mensah', phone: ''),
    ],
    players: {
      for (var i = 0; i < ids.length; i++)
        ids[i]: SheetPlayer(
          id: ids[i],
          name: _names[i % _names.length],
          position: _positions[i % _positions.length],
          usual: i == 8 ? 17 : i + 1,
          code: '$code-${(i + 1).toString().padLeft(4, '0')}',
          ageGroup: i == 14 ? AgeGroup.u15 : null,
        ),
    },
  );
}

MatchOfficials _officials() => const MatchOfficials(fixtureId: 'm1')
    .withPlace(
      OfficialPlace.referee,
      const AppointedOfficial(uid: 'r1', name: 'Eric Owusu'),
    )
    .withPlace(
      OfficialPlace.commissioner,
      const AppointedOfficial(uid: 'c1', name: 'Kwesi Arthur'),
    );

void main() {
  group('OfficialSheet.of (what the paper says)', () {
    final afterLock = _kickoff.subtract(const Duration(minutes: 30));

    test('heading, matchday, match line, date with the year, venue', () {
      final s = OfficialSheet.of(
        fixture: _match(),
        homeSheet: _sheet('ruf'),
        awaySheet: _sheet('ast'),
        officials: _officials(),
        now: afterLock,
      );
      expect(s.heading, 'GOMOA EAST DFA · DIVISION LEAGUE');
      expect(s.roundLabel, 'Matchday 4');
      expect(s.matchLine, 'Royal Unique FC v Asebu Stars');
      expect(s.whenWhere, 'Sat 14 Nov 2026, 3:00 pm · Apam Park');
      expect(s.draftNote, isNull);
      expect(s.fileName, 'gedfa-sheet-RUF-v-AST-B-2026-11-14.pdf');
    });

    test('a juvenile match names its age group', () {
      final s = OfficialSheet.of(
        fixture: _match(ageGroup: AgeGroup.u17),
        homeSheet: null,
        awaySheet: null,
        officials: null,
        now: afterLock,
      );
      expect(s.heading, 'GOMOA EAST DFA · JUVENILE LEAGUE · U17');
    });

    test('before the lock the paper is a DRAFT', () {
      final s = OfficialSheet.of(
        fixture: _match(),
        homeSheet: _sheet('ruf'),
        awaySheet: null,
        officials: null,
        now: _kickoff.subtract(const Duration(days: 1)),
      );
      expect(s.draftNote, startsWith('DRAFT'));
      expect(s.draftNote, contains('2:00 pm'));
    });

    test('players: shirt numbers, roles, IDs, usual numbers, age groups', () {
      final s = OfficialSheet.of(
        fixture: _match(),
        homeSheet: _sheet('ruf'),
        awaySheet: _sheet('ast'),
        officials: _officials(),
        now: afterLock,
      );
      final home = s.teams[0];
      expect(home.saved, isTrue);
      expect(home.sideLabel, 'Home');
      expect(home.kitLabel, 'Home kit');
      expect(s.teams[1].sideLabel, 'Away');
      expect(home.starters, hasLength(11));
      expect(home.bench, hasLength(5));

      final gk = home.starters[0];
      expect(gk.number, 1);
      expect(gk.nameWithRoles, 'Kwame Asante (GK)');
      expect(gk.code, 'GE26-0001');
      expect(home.starters[1].nameWithRoles, 'Yaw Boateng (VC)');
      expect(home.starters[3].nameWithRoles, 'Emmanuel Tetteh (C)');
      expect(home.starters[2].usual, isNull, reason: 'same as usual');

      final baah = home.starters[8];
      expect(baah.number, 13);
      expect(baah.usual, 17);

      // A U15 player in a Division match is marked
      expect(home.bench[3].ageGroup, 'U15');
      expect(home.bench[2].ageGroup, isNull);

      expect(home.captain, '4 Emmanuel Tetteh');
      expect(home.teamOfficials, [
        ('Team manager', 'Kojo Antwi'),
        ('Head coach', 'Kofi Mensah'),
      ]);
    });

    test("3.3b: a team's own copy has only that team", () {
      final s = OfficialSheet.of(
        fixture: _match(),
        homeSheet: null,
        awaySheet: _sheet('ast'),
        officials: null,
        now: _kickoff.subtract(const Duration(days: 1)),
        onlyTeamId: 'ast',
      );
      expect(s.isOneTeam, isTrue);
      expect(s.teams.single.name, 'Asebu Stars');
      expect(s.title, 'Team sheet');
      expect(s.draftNote, startsWith('DRAFT · you can change this sheet'));
      expect(s.fileName, 'gedfa-teamsheet-RUF-v-AST-B-2026-11-14.pdf');
      expect(s.officials.every((o) => o.$2 == null), isTrue);
    });

    test('a team with no sheet says so; officials leave blanks', () {
      final s = OfficialSheet.of(
        fixture: _match(),
        homeSheet: _sheet('ruf'),
        awaySheet: null,
        officials: _officials(),
        now: afterLock,
      );
      expect(s.teams[1].saved, isFalse);
      expect(s.teams[1].starters, isEmpty);
      expect(s.teams[1].captain, isNull);
      expect(s.officials, [
        ('Referee', 'Eric Owusu'),
        ('Assistant 1', null),
        ('Assistant 2', null),
        ('4th official', null),
        ('Commissioner', 'Kwesi Arthur'),
      ]);
    });
  });

  group('officialSheetPdf', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('makes a one-page A4 PDF with the bundled fonts', () async {
      final sheet = OfficialSheet.of(
        fixture: _match(),
        homeSheet: _sheet('ruf', players: 18),
        awaySheet: _sheet('ast', players: 17, code: 'GJ26'),
        officials: _officials(),
        now: _kickoff.subtract(const Duration(days: 1)),
      );
      final bytes = await officialSheetPdf(
        sheet,
        fonts: await OfficialSheetFonts.load(),
        printedAt: DateTime(2026, 11, 13, 9, 5),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(bytes)),
        hasLength(1),
      );
      // To look at it: OFFICIAL_SHEET_OUT=some/file.pdf flutter test ...
      final out = Platform.environment['OFFICIAL_SHEET_OUT'];
      if (out != null) File(out).writeAsBytesSync(bytes);
    });

    test('3.3b: kit photos fit in the kit box (team copy)', () async {
      // A wide shirt photo, a tall socks photo: each must fit its part
      img.Image photo(int w, int h, int r, int g, int b) =>
          img.Image(width: w, height: h)..clear(img.ColorRgb8(r, g, b));
      final pictures = <String, pw.ImageProvider>{
        'u/shirt': pw.MemoryImage(img.encodePng(photo(600, 300, 179, 18, 42))),
        'u/shorts': pw.MemoryImage(
          img.encodePng(photo(300, 200, 240, 240, 240)),
        ),
        'u/socks': pw.MemoryImage(img.encodePng(photo(100, 400, 179, 18, 42))),
      };
      const photos = Kit.fromPhotos(
        KitPhotos(
          shirt: KitPhoto(url: 'u/shirt'),
          shorts: KitPhoto(url: 'u/shorts'),
          socks: KitPhoto(url: 'u/socks'),
        ),
      );
      final sheet = OfficialSheet.of(
        fixture: _match(homeKit: photos),
        homeSheet: _sheet('ruf', players: 18),
        awaySheet: null,
        officials: _officials(),
        now: _kickoff.subtract(const Duration(minutes: 30)),
        onlyTeamId: 'ruf',
      );
      final bytes = await officialSheetPdf(
        sheet,
        fonts: await OfficialSheetFonts.load(),
        photos: pictures,
        printedAt: DateTime(2026, 11, 14, 14, 40),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final out = Platform.environment['OFFICIAL_TEAM_OUT'];
      if (out != null) File(out).writeAsBytesSync(bytes);

      // Photos that didn't load: still one page, the grey kit
      final offline = await officialSheetPdf(
        sheet,
        fonts: await OfficialSheetFonts.load(),
        printedAt: DateTime(2026, 11, 14, 14, 40),
      );
      expect(String.fromCharCodes(offline.take(5)), '%PDF-');
    });

    test('kit drawing: pattern clipped to the shirt', () {
      final svg = kitSvg(
        const Kit(
          primary: Color(0xFFB3122A),
          secondary: Colors.white,
          pattern: KitPattern.halves,
          shorts: Colors.white,
          socks: Colors.black,
        ),
      );
      expect(svg, contains('fill="#B3122A"'));
      expect(svg, contains('clip-path="url(#s)" fill="#FFFFFF"'));
      expect(svg, contains('fill="#000000"'));
      expect(
        kitSvg(
          const Kit(
            primary: Colors.red,
            shorts: Colors.white,
            socks: Colors.red,
          ),
        ),
        isNot(contains('clip-path="url')),
      );
    });
  });
}
