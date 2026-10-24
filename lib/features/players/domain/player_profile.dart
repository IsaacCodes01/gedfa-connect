import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';

/// Can the player be picked right now? Set by the team.
/// No medical details are stored: only the status and an expected date.
enum Availability {
  available('Available'),
  injured('Injured'),
  unavailable('Unavailable');

  const Availability(this.label);
  final String label;

  static Availability fromString(String? value) => values.firstWhere(
        (a) => a.name == value,
        orElse: () => Availability.available,
      );
}

enum Foot {
  left('Left'),
  right('Right'),
  both('Both');

  const Foot(this.label);
  final String label;

  static Foot? fromString(String? value) {
    for (final foot in values) {
      if (foot.name == value) return foot;
    }
    return null;
  }
}

/// The strengths a team can pick (up to 3). Must match the rules.
enum Strength {
  pace('Pace'),
  strength('Strength'),
  stamina('Stamina'),
  dribbling('Dribbling'),
  passing('Passing'),
  finishing('Finishing'),
  heading('Heading'),
  tackling('Tackling'),
  setPieces('Set pieces'),
  leadership('Leadership');

  const Strength(this.label);
  final String label;

  static Strength? fromString(String? value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

/// `playerProfiles/{playerId}`: football details, kept by the team.
/// Everything is optional; a player with no document is "Available" with
/// nothing filled in.
class PlayerProfile {
  const PlayerProfile({
    required this.playerId,
    required this.teamId,
    this.heightCm,
    this.weightKg,
    this.foot,
    this.otherPositions = const [],
    this.strengths = const [],
    this.hometown,
    this.clubSince,
    this.previousClub,
    this.availability = Availability.available,
    this.expectedBack,
    this.availabilityAt,
    this.emergencyName,
    this.emergencyPhone,
    this.updatedAt,
  });

  /// An empty profile for a player who has none yet.
  factory PlayerProfile.empty(String playerId, String teamId) =>
      PlayerProfile(playerId: playerId, teamId: teamId);

  final String playerId;
  final String teamId;
  final int? heightCm;
  final int? weightKg;
  final Foot? foot;
  final List<Position> otherPositions; // up to 2
  final List<Strength> strengths; // up to 3
  final String? hometown;
  final int? clubSince;
  final String? previousClub;
  final Availability availability;
  final DateTime? expectedBack;
  final DateTime? availabilityAt; // when the availability was last changed
  final String? emergencyName;
  final String? emergencyPhone;
  final DateTime? updatedAt;

  bool get isAvailable => availability == Availability.available;

  /// "1.82 m", or null when not filled in.
  String? get heightText =>
      heightCm == null ? null : '${(heightCm! / 100).toStringAsFixed(2)} m';

  factory PlayerProfile.fromMap(String playerId, Map<String, dynamic> data) {
    String? text(String key) {
      final value = (data[key] as String?)?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    return PlayerProfile(
      playerId: playerId,
      teamId: data['teamId'] as String? ?? '',
      heightCm: (data['heightCm'] as num?)?.toInt(),
      weightKg: (data['weightKg'] as num?)?.toInt(),
      foot: Foot.fromString(data['foot'] as String?),
      otherPositions: [
        for (final code in data['otherPositions'] as List<dynamic>? ?? const [])
          ?Position.fromCode(code as String?),
      ],
      strengths: [
        for (final name in data['strengths'] as List<dynamic>? ?? const [])
          ?Strength.fromString(name as String?),
      ],
      hometown: text('hometown'),
      clubSince: (data['clubSince'] as num?)?.toInt(),
      previousClub: text('previousClub'),
      availability: Availability.fromString(data['availability'] as String?),
      expectedBack: (data['expectedBack'] as Timestamp?)?.toDate(),
      availabilityAt: (data['availabilityAt'] as Timestamp?)?.toDate(),
      emergencyName: text('emergencyName'),
      emergencyPhone: text('emergencyPhone'),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Who wears the armband in one squad (`teams/{teamId}/armbands/{category}`).
class Armbands {
  const Armbands({this.captainId, this.viceCaptainId});

  final String? captainId;
  final String? viceCaptainId;

  /// 'C', 'VC' or null for one player.
  String? badgeFor(String playerId) => playerId == captainId
      ? 'C'
      : playerId == viceCaptainId
          ? 'VC'
          : null;

  factory Armbands.fromMap(Map<String, dynamic>? data) => Armbands(
        captainId: data?['captainId'] as String?,
        viceCaptainId: data?['viceCaptainId'] as String?,
      );
}

/// The three choices on the Edit profile screen.
enum Armband { none, captain, viceCaptain }
