/// Player colors supported in standard 4-player and extended 6-player Ludo.
enum PlayerColor {
  red(seatIndex: 0, startTrackCell: 0, homeEntranceTrackCell: 50),
  green(seatIndex: 1, startTrackCell: 13, homeEntranceTrackCell: 11),
  yellow(seatIndex: 2, startTrackCell: 26, homeEntranceTrackCell: 24),
  blue(seatIndex: 3, startTrackCell: 39, homeEntranceTrackCell: 37),
  orange(seatIndex: 4, startTrackCell: 48, homeEntranceTrackCell: 46),
  purple(seatIndex: 5, startTrackCell: 60, homeEntranceTrackCell: 58);

  const PlayerColor({
    required this.seatIndex,
    required this.startTrackCell,
    required this.homeEntranceTrackCell,
  });

  final int seatIndex;
  final int startTrackCell;
  final int homeEntranceTrackCell;

  static PlayerColor fromSeat(int seat) {
    return PlayerColor.values.firstWhere(
      (c) => c.seatIndex == seat,
      orElse: () => throw ArgumentError('Invalid seat index: $seat'),
    );
  }

  static PlayerColor fromName(String name) {
    return PlayerColor.values.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown PlayerColor: $name'),
    );
  }
}
