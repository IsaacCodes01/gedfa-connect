/// The four position groups. Set by the app from the detailed position,
/// never chosen by the user.
enum PositionGroup {
  gk('GK', 'Goalkeeper'),
  def('DEF', 'Defender'),
  mid('MID', 'Midfielder'),
  fwd('FWD', 'Forward');

  const PositionGroup(this.code, this.label);

  /// Stored in Firestore, e.g. 'DEF'.
  final String code;

  /// Shown to people, e.g. 'Defender'.
  final String label;

  static PositionGroup? fromCode(String? code) {
    for (final group in values) {
      if (group.code == code) return group;
    }
    return null;
  }
}

/// The 23 GEDFA positions.
enum Position {
  gk('GK', 'Goalkeeper', PositionGroup.gk),

  cb('CB', 'Centre-back', PositionGroup.def),
  rcb('RCB', 'Right centre-back', PositionGroup.def),
  lcb('LCB', 'Left centre-back', PositionGroup.def),
  rb('RB', 'Right-back', PositionGroup.def),
  lb('LB', 'Left-back', PositionGroup.def),
  rwb('RWB', 'Right wing-back', PositionGroup.def),
  lwb('LWB', 'Left wing-back', PositionGroup.def),
  lfb('LFB', 'Left full-back', PositionGroup.def),
  rfb('RFB', 'Right full-back', PositionGroup.def),
  

  dm('DM', 'Defensive midfielder', PositionGroup.mid),
  rdm('RDM', 'Right defensive midfielder', PositionGroup.mid),
  lm('LM', 'Left midfielder', PositionGroup.mid),
  rm('RM', 'Right midfielder', PositionGroup.mid),
  ldm('LDM', 'Left defensive midfielder', PositionGroup.mid),
  cm('CM', 'Central midfielder', PositionGroup.mid),
  amf('AMF', 'Attacking midfielder', PositionGroup.mid),

  lw('LW', 'Left winger', PositionGroup.fwd),
  rw('RW', 'Right winger', PositionGroup.fwd),
  lwf('LWF', 'Left wing-forward', PositionGroup.fwd),
  rwf('RWF', 'Right wing-forward', PositionGroup.fwd),
  cf('CF', 'Centre-forward', PositionGroup.fwd),
  st('ST', 'Striker', PositionGroup.fwd);

  const Position(this.code, this.label, this.group);

  /// Stored in Firestore, e.g. 'RCB'.
  final String code;

  /// Shown to people, e.g. 'Right centre-back'.
  final String label;

  /// GK / DEF / MID / FWD, worked out from the position.
  final PositionGroup group;

  /// 'RCB · Right centre-back'
  String get display => '$code · $label';

  static Position? fromCode(String? code) {
    for (final position in values) {
      if (position.code == code) return position;
    }
    return null;
  }

  /// All positions of one group, in the order above.
  static List<Position> inGroup(PositionGroup group) =>
      values.where((position) => position.group == group).toList();
}
