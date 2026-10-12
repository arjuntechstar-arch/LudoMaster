import 'package:meta/meta.dart';

/// Configuration ruleset versioning for Classic, Quick, and custom tournament modes.
@immutable
class RulesetConfig {
  const RulesetConfig({
    this.version = 'v1.0.0',
    this.name = 'Classic',
    this.tokensPerPlayer = 4,
    this.maxConsecutiveSixes = 3,
    this.captureGrantsBonusTurn = true,
    this.homeEntryGrantsBonusTurn = true,
    this.exactRollRequiredForHome = true,
    this.safeCells = const [0, 8, 13, 21, 26, 34, 39, 47],
    this.allowSameColorStacking = true,
    this.autoMoveSingleLegalMove = true,
    this.turnTimeoutSeconds = 15,
    this.requireCaptureForHomeEntry = false,
    this.isTeamMode = false,
    this.teammateCaptureAllowed = false,
    this.partnerControlWhenFinished = true,
  });

  final String version;
  final String name;
  final int tokensPerPlayer;

  /// Max consecutive sixes allowed before the turn is cancelled/forfeited.
  /// Standard Ludo: 3 consecutive sixes cancels the roll/turn.
  final int maxConsecutiveSixes;

  /// Whether capturing an opponent token awards an extra roll.
  final bool captureGrantsBonusTurn;

  /// Whether moving a token into HOME awards an extra roll.
  final bool homeEntryGrantsBonusTurn;

  /// Whether an exact die roll is required to land in HOME (step 6 of home lane).
  final bool exactRollRequiredForHome;

  /// Track cell indices on the 52-cell board that are safe from capture.
  final List<int> safeCells;

  /// Whether tokens of the same color can stack on the same track cell.
  final bool allowSameColorStacking;

  /// Whether single legal move should be automatically selected/applied.
  final bool autoMoveSingleLegalMove;

  /// Turn timer duration in seconds.
  final int turnTimeoutSeconds;

  /// In Quick Mode, players must capture at least 1 opponent token before
  /// any of their tokens can enter their colored home lane.
  final bool requireCaptureForHomeEntry;

  /// Whether this match is 2v2 Team Mode.
  final bool isTeamMode;

  /// In Team Mode, whether teammates can capture each other (typically false).
  final bool teammateCaptureAllowed;

  /// In Team Mode, when a player has all their tokens in home, on their turn
  /// they can roll and move their active teammate's tokens.
  final bool partnerControlWhenFinished;

  static const RulesetConfig classic = RulesetConfig(
    version: 'v1.0.0',
    name: 'Classic',
    tokensPerPlayer: 4,
  );

  static const RulesetConfig quick = RulesetConfig(
    version: 'v1.0.0-quick',
    name: 'Quick',
    tokensPerPlayer: 2,
    homeEntryGrantsBonusTurn: false,
    requireCaptureForHomeEntry: true,
    turnTimeoutSeconds: 12,
  );

  static const RulesetConfig team = RulesetConfig(
    version: 'v1.0.0-team',
    name: 'Team 2v2',
    tokensPerPlayer: 4,
    isTeamMode: true,
    teammateCaptureAllowed: false,
    partnerControlWhenFinished: true,
  );

  bool isSafeCell(int cell) => safeCells.contains(cell);

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'name': name,
      'tokensPerPlayer': tokensPerPlayer,
      'maxConsecutiveSixes': maxConsecutiveSixes,
      'captureGrantsBonusTurn': captureGrantsBonusTurn,
      'homeEntryGrantsBonusTurn': homeEntryGrantsBonusTurn,
      'exactRollRequiredForHome': exactRollRequiredForHome,
      'safeCells': safeCells,
      'allowSameColorStacking': allowSameColorStacking,
      'autoMoveSingleLegalMove': autoMoveSingleLegalMove,
      'turnTimeoutSeconds': turnTimeoutSeconds,
      'requireCaptureForHomeEntry': requireCaptureForHomeEntry,
      'isTeamMode': isTeamMode,
      'teammateCaptureAllowed': teammateCaptureAllowed,
      'partnerControlWhenFinished': partnerControlWhenFinished,
    };
  }

  factory RulesetConfig.fromJson(Map<String, dynamic> json) {
    return RulesetConfig(
      version: json['version'] as String? ?? 'v1.0.0',
      name: json['name'] as String? ?? 'Classic',
      tokensPerPlayer: json['tokensPerPlayer'] as int? ?? 4,
      maxConsecutiveSixes: json['maxConsecutiveSixes'] as int? ?? 3,
      captureGrantsBonusTurn: json['captureGrantsBonusTurn'] as bool? ?? true,
      homeEntryGrantsBonusTurn: json['homeEntryGrantsBonusTurn'] as bool? ?? true,
      exactRollRequiredForHome: json['exactRollRequiredForHome'] as bool? ?? true,
      safeCells: (json['safeCells'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [0, 8, 13, 21, 26, 34, 39, 47],
      allowSameColorStacking: json['allowSameColorStacking'] as bool? ?? true,
      autoMoveSingleLegalMove: json['autoMoveSingleLegalMove'] as bool? ?? true,
      turnTimeoutSeconds: json['turnTimeoutSeconds'] as int? ?? 15,
      requireCaptureForHomeEntry: json['requireCaptureForHomeEntry'] as bool? ?? false,
      isTeamMode: json['isTeamMode'] as bool? ?? false,
      teammateCaptureAllowed: json['teammateCaptureAllowed'] as bool? ?? false,
      partnerControlWhenFinished: json['partnerControlWhenFinished'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RulesetConfig &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          name == other.name &&
          tokensPerPlayer == other.tokensPerPlayer &&
          maxConsecutiveSixes == other.maxConsecutiveSixes &&
          captureGrantsBonusTurn == other.captureGrantsBonusTurn &&
          homeEntryGrantsBonusTurn == other.homeEntryGrantsBonusTurn &&
          exactRollRequiredForHome == other.exactRollRequiredForHome &&
          allowSameColorStacking == other.allowSameColorStacking &&
          autoMoveSingleLegalMove == other.autoMoveSingleLegalMove &&
          turnTimeoutSeconds == other.turnTimeoutSeconds &&
          requireCaptureForHomeEntry == other.requireCaptureForHomeEntry &&
          isTeamMode == other.isTeamMode &&
          teammateCaptureAllowed == other.teammateCaptureAllowed &&
          partnerControlWhenFinished == other.partnerControlWhenFinished;

  @override
  int get hashCode => Object.hash(
        version,
        name,
        tokensPerPlayer,
        maxConsecutiveSixes,
        captureGrantsBonusTurn,
        homeEntryGrantsBonusTurn,
        exactRollRequiredForHome,
        allowSameColorStacking,
        autoMoveSingleLegalMove,
        turnTimeoutSeconds,
        requireCaptureForHomeEntry,
        isTeamMode,
        teammateCaptureAllowed,
        partnerControlWhenFinished,
      );
}
