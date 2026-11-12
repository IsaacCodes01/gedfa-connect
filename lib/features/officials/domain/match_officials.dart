import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/kit_clash.dart';

/// The five places of a match's officials (3.5, mockup MO1). Must match
/// the rules. Only the referee is required (Isaac, 11 Nov 2026).
enum OfficialPlace {
  referee('Referee', 'Ref'),
  assistant1('Assistant 1', 'A1'),
  assistant2('Assistant 2', 'A2'),
  fourth('4th official', '4th'),
  commissioner('Commissioner', 'Com.');

  const OfficialPlace(this.label, this.short);

  final String label;

  /// "A1", in a short list ("With: E. Owusu (A1)").
  final String short;

  /// The commissioner may be an FA official or a referee (Isaac, 9 Nov
  /// 2026); the other places are referees.
  bool get takesFaOfficials => this == commissioner;

  static OfficialPlace? fromString(String? value) {
    for (final p in values) {
      if (p.name == value) return p;
    }
    return null;
  }
}

/// One appointed person: their account and their name as the FA saw it.
class AppointedOfficial {
  const AppointedOfficial({required this.uid, required this.name});

  final String uid;
  final String name;

  Map<String, dynamic> toMap() => {'uid': uid, 'name': name};

  static AppointedOfficial? fromMap(Object? map) {
    if (map is! Map) return null;
    final uid = map['uid'], name = map['name'];
    if (uid is! String || name is! String) return null;
    return AppointedOfficial(uid: uid, name: name);
  }
}

/// `fixtureOfficials/{fixtureId}`: who officiates a match (3.5a). Its own
/// document, not part of the match: everyone with a role reads matches,
/// but the clubs may know the officials only from 24 hours before kick-off
/// (Isaac, 11 Nov 2026). The FA and the appointed officials read it any
/// time.
class MatchOfficials {
  const MatchOfficials({
    required this.fixtureId,
    this.places = const {},
    this.cantMake = const {},
  });

  /// The clubs see the officials from this long before kick-off.
  static const clubsSeeBefore = Duration(hours: 24);

  /// Two appointments of one person this close are flagged (Isaac).
  static const tooClose = Duration(hours: 3);

  final String fixtureId;
  final Map<OfficialPlace, AppointedOfficial> places;

  /// 3.5b: uid → why they can't make it (they press Can't make it; the FA
  /// is told and appoints someone else). Only people still appointed.
  final Map<String, String> cantMake;

  AppointedOfficial? operator [](OfficialPlace place) => places[place];

  int get count => places.length;
  bool get hasReferee => places.containsKey(OfficialPlace.referee);

  /// The place [uid] holds here, if any.
  OfficialPlace? placeOf(String uid) {
    for (final MapEntry(:key, :value) in places.entries) {
      if (value.uid == uid) return key;
    }
    return null;
  }

  /// A copy with [place] given to [who], or emptied (null). A person
  /// already in another place of this match moves (one place each).
  MatchOfficials withPlace(OfficialPlace place, AppointedOfficial? who) {
    final next = {
      for (final MapEntry(:key, :value) in places.entries)
        if (key != place && value.uid != who?.uid) key: value,
    };
    if (who != null) next[place] = who;
    final ids = {for (final o in next.values) o.uid};
    return MatchOfficials(
      fixtureId: fixtureId,
      places: next,
      cantMake: {
        for (final MapEntry(:key, :value) in cantMake.entries)
          if (ids.contains(key)) key: value,
      },
    );
  }

  /// Whether the clubs of [f] may see the officials at [now].
  static bool clubsMaySee(Fixture f, DateTime now) {
    final kickoff = f.kickoffAt;
    return kickoff != null && !now.add(clubsSeeBefore).isBefore(kickoff);
  }

  Map<String, dynamic> toMap({required String season, required String by}) => {
    'fixtureId': fixtureId,
    'season': season,
    'officials': {
      for (final MapEntry(:key, :value) in places.entries)
        key.name: value.toMap(),
    },
    'officialIds': [for (final o in places.values) o.uid],
    if (cantMake.isNotEmpty)
      'cantMake': {
        for (final MapEntry(:key, :value) in cantMake.entries)
          key: {'reason': value},
      },
    'updatedBy': by,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static MatchOfficials fromMap(String id, Map<String, dynamic>? data) {
    final raw = data?['officials'];
    final cant = data?['cantMake'];
    return MatchOfficials(
      fixtureId: id,
      cantMake: {
        if (cant is Map)
          for (final e in cant.entries)
            if (e.value is Map && (e.value as Map)['reason'] is String)
              e.key.toString(): (e.value as Map)['reason'] as String,
      },
      places: {
        if (raw is Map)
          for (final e in raw.entries)
            ?OfficialPlace.fromString(e.key as String?):
                ?AppointedOfficial.fromMap(e.value),
      },
    );
  }
}

/// [uid]'s other appointment on the same day as [f] (MO2: "Also Assistant
/// 2 · Nyanyano, 3:00 pm"), and whether the kick-offs are less than 3
/// hours apart (allowed, with a warning; Isaac, 11 Nov 2026).
({Fixture match, OfficialPlace place, bool near})? busyElsewhere(
  String uid,
  Fixture f,
  Map<String, MatchOfficials> all,
  List<Fixture> fixtures,
) {
  final when = f.kickoffAt;
  if (when == null) return null;
  for (final g in fixtures) {
    final other = g.kickoffAt;
    if (g.id == f.id || !g.isScheduled || other == null) continue;
    final local = when.toLocal(), otherLocal = other.toLocal();
    if (local.year != otherLocal.year ||
        local.month != otherLocal.month ||
        local.day != otherLocal.day) {
      continue;
    }
    final place = all[g.id]?.placeOf(uid);
    if (place == null) continue;
    return (
      match: g,
      place: place,
      near: other.difference(when).abs() < MatchOfficials.tooClose,
    );
  }
  return null;
}

/// The usual referee shirt colours.
const refereeColours = <(String, Color)>[
  ('black', Color(0xFF111111)),
  ('yellow', Color(0xFFFCD116)),
  ('red', Color(0xFFCE1126)),
  ('green', Color(0xFF006B3F)),
  ('blue', Color(0xFF1E88E5)),
];

/// The referee colours that clash with none of the four kits of [f]
/// (MO1: "wear black or yellow"; Law 4, as the kit clash check).
List<(String, Color)> refereeColoursFor(Fixture f) {
  final shirts = [
    f.kits.home.kit.primary,
    f.kits.away.kit.primary,
    f.kits.homeGk.kit.primary,
    f.kits.awayGk.kit.primary,
  ];
  return [
    for (final c in refereeColours)
      if (!shirts.any((s) => coloursClash(s, c.$2))) c,
  ];
}

/// "Royal Unique FC v Asebu Stars, Sat 14 Nov, 3:00 pm, Apam Park"
String appointmentLine(Fixture f) {
  final when = f.kickoffAt;
  return [
    '${f.home.name} v ${f.away.name}',
    if (when != null) '${formatShortDate(when)}, ${formatTime(when)}',
    f.venue,
  ].join(', ');
}

/// One of my appointments (3.5b): the match, my place, everyone in it.
typedef Appointment = ({
  Fixture match,
  OfficialPlace place,
  MatchOfficials officials,
});

/// [uid]'s appointments ([mine], by match ID) with their matches: coming
/// up (in kick-off order, postponed ones without a date last) and played
/// (newest first). Cancelled matches are left out.
({List<Appointment> upcoming, List<Appointment> played}) appointmentsOf(
  String uid,
  Map<String, MatchOfficials> mine,
  List<Fixture> fixtures,
  DateTime now,
) {
  final upcoming = <Appointment>[];
  final played = <Appointment>[];
  for (final f in fixtures) {
    final o = mine[f.id];
    final place = o?.placeOf(uid);
    if (o == null || place == null || f.isCancelled) continue;
    (f.isPlayed(now) ? played : upcoming).add((
      match: f,
      place: place,
      officials: o,
    ));
  }
  int byKickoff(Appointment a, Appointment b) {
    final ta = a.match.kickoffAt, tb = b.match.kickoffAt;
    if (ta == null || tb == null) return ta == null ? 1 : -1;
    return ta.compareTo(tb);
  }

  upcoming.sort(byKickoff);
  played.sort((a, b) => byKickoff(b, a));
  return (upcoming: upcoming, played: played);
}

/// "E. Owusu (A1), P. Quaye (4th), K. Arthur (Com.)": the others in the
/// match.
String othersLine(MatchOfficials o, String uid) => [
  for (final place in OfficialPlace.values)
    if (o[place] case final who? when who.uid != uid)
      '${shortName(who.name)} (${place.short})',
].join(', ');

/// "Esi Owusu" → "E. Owusu"
String shortName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return name.trim();
  return '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
}
