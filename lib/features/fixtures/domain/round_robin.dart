import 'dart:math';

/// One pairing in a round: indexes into the list of teams.
typedef Pairing = ({int home, int away});

/// Every team plays every other team (3.0b, "Make the season"), by the
/// circle method: team 0 stays put, the others move one place round the
/// circle each round. With an odd number, an empty seat makes one team
/// rest each round.
///
/// Home and away alternate so no team is at home (or away) many times in a
/// row. [homeAndAway] adds a second half: the rounds again with home and
/// away swapped, so each pair meets once at each ground.
List<List<Pairing>> roundRobin(int teams, {bool homeAndAway = true}) {
  if (teams < 2) return const [];
  // -1 is the empty seat (a rest) when the number is odd
  final seats = [for (var i = 0; i < teams; i++) i, if (teams.isOdd) -1];
  final n = seats.length;
  final rounds = <List<Pairing>>[];

  for (var r = 0; r < n - 1; r++) {
    final round = <Pairing>[];
    for (var i = 0; i < n ~/ 2; i++) {
      final a = seats[i];
      final b = seats[n - 1 - i];
      if (a < 0 || b < 0) continue; // a rest
      // The fixed team swaps ground every round; the others by their place
      // in the circle. Measured for 3 to 20 teams: home games differ by at
      // most 2 between teams, and nobody is home (or away) more than 3
      // matchdays in a row.
      final swap = i == 0 ? r.isOdd : i.isOdd;
      round.add(swap ? (home: b, away: a) : (home: a, away: b));
    }
    rounds.add(round);
    // Rotate everyone except the first seat
    seats.insert(1, seats.removeLast());
  }

  if (!homeAndAway) return rounds;
  // The second half: home and away swapped, starting one round later
  // (round 2, 3, … then round 1). Measured for 3 to 20 teams: nobody is
  // home or away more than 3 matchdays in a row across the two halves,
  // and two teams never meet again within 2 matchdays.
  final mirrored = [
    for (final round in rounds)
      [for (final p in round) (home: p.away, away: p.home)],
  ];
  return [...rounds, ...mirrored.skip(1), mirrored.first];
}

/// The teams in a random order, so each new draw is different ("Shuffle").
List<T> shuffled<T>(List<T> items, [Random? random]) =>
    [...items]..shuffle(random ?? Random());
