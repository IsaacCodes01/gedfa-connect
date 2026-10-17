enum KitSlot {
  home,
  away,
  goalkeeper,
  third,
  goalkeeper2;

  String get label => switch (this) {
        KitSlot.home => 'Home kit',
        KitSlot.away => 'Away kit',
        KitSlot.goalkeeper => 'Goalkeeper kit',
        KitSlot.third => 'Third kit',
        KitSlot.goalkeeper2 => 'Goalkeeper kit 2',
      };

  bool get isRequired =>
      this == KitSlot.home ||
      this == KitSlot.away ||
      this == KitSlot.goalkeeper;
}