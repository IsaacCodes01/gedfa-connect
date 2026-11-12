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
  const MatchOfficials({required this.fixtureId, this.places = const {}});

  /// The clubs see the officials from this long before kick-off.
  static const clubsSeeBefore = Duration(hours: 24);

  /// Two appointments of one person this close are flagged (Isaac).
  static const tooClose = Duration(hours: 3);

  final String fixtureId;
  final Map<OfficialPlace, AppointedOfficial> places;

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
    return MatchOfficials(fixtureId: fixtureId, places: next);
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
    'updatedBy': by,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static MatchOfficials fromMap(String id, Map<String, dynamic>? data) {
    final raw = data?['officials'];
    return MatchOfficials(
      fixtureId: id,
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
