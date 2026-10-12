import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/leaderboard_screen.dart';
import 'package:mobile/src/screens/season_screen.dart';
import 'package:mobile/src/screens/tournament_screen.dart';
import 'package:mobile/src/services/api_client.dart';

class MockTournamentsSeasonsApiClient extends ApiClient {
  bool tournamentJoined = false;
  bool seasonRewardClaimed = false;

  @override
  Future<List<TournamentModel>> getTournaments() async {
    return [
      TournamentModel(
        id: 'tourn_royal_crown',
        title: 'Royal Crown Championship',
        description: '8-Player standard knockout bracket. 2 Semifinals boards, top 2 advance to Grand Final!',
        entryFeeCoins: 500,
        prizePoolCoins: 3000,
        prizePoolGems: 25,
        maxParticipants: 8,
        currentParticipants: tournamentJoined ? 5 : 4,
        status: 'REGISTRATION',
        isJoined: tournamentJoined,
      ),
      TournamentModel(
        id: 'tourn_grand_masters',
        title: 'Grand Masters Blitz',
        description: 'High stakes 8-Player championship with massive gem rewards!',
        entryFeeCoins: 1500,
        prizePoolCoins: 10000,
        prizePoolGems: 100,
        maxParticipants: 8,
        currentParticipants: 2,
        status: 'REGISTRATION',
        isJoined: false,
      ),
    ];
  }

  @override
  Future<TournamentDetailModel> getTournamentDetails(String tournamentId) async {
    return TournamentDetailModel(
      tournament: TournamentModel(
        id: tournamentId,
        title: 'Royal Crown Championship',
        description: '8-Player standard knockout bracket.',
        entryFeeCoins: 500,
        prizePoolCoins: 3000,
        prizePoolGems: 25,
        maxParticipants: 8,
        currentParticipants: tournamentJoined ? 5 : 4,
        status: 'REGISTRATION',
        isJoined: tournamentJoined,
      ),
      participants: [
        TournamentParticipantModel(
          id: 'part_1',
          userId: 'user_1',
          displayName: 'KingLudo',
          avatarId: 'avatar_1',
          seed: 1,
          prizeCoins: 0,
          prizeGems: 0,
        ),
        TournamentParticipantModel(
          id: 'part_2',
          userId: 'user_2',
          displayName: 'QueenDice',
          avatarId: 'avatar_2',
          seed: 2,
          prizeCoins: 0,
          prizeGems: 0,
        ),
      ],
      matches: [
        TournamentMatchModel(
          id: 'match_semi_1',
          roundNumber: 1,
          matchIndex: 0,
          status: 'PENDING',
          participantIds: ['user_1'],
          winnerIds: [],
        ),
        TournamentMatchModel(
          id: 'match_semi_2',
          roundNumber: 1,
          matchIndex: 1,
          status: 'PENDING',
          participantIds: ['user_2'],
          winnerIds: [],
        ),
        TournamentMatchModel(
          id: 'match_final',
          roundNumber: 2,
          matchIndex: 0,
          status: 'PENDING',
          participantIds: [],
          winnerIds: [],
        ),
      ],
    );
  }

  @override
  Future<TournamentJoinModel> joinTournament(String tournamentId) async {
    tournamentJoined = true;
    return TournamentJoinModel(
      message: 'Successfully registered for tournament!',
      tournamentId: tournamentId,
      currentParticipants: 5,
      status: 'REGISTRATION',
      seed: 5,
    );
  }

  @override
  Future<SeasonDetailModel> getCurrentSeason() async {
    return SeasonDetailModel(
      id: 'season_1',
      seasonNumber: 1,
      title: 'Season 1: Royal Arena',
      themeName: 'Royal Gold',
      startsAt: '2026-10-01T00:00:00Z',
      endsAt: '2026-10-31T23:59:59Z',
      isActive: true,
      currentXp: 500,
      currentTier: 3,
      hasPremiumPass: false,
      tiers: [
        SeasonTierModel(
          id: 'tier_1',
          tierNumber: 1,
          xpRequired: 100,
          freeRewardCoins: 200,
          freeRewardGems: 2,
          premiumRewardCoins: 500,
          premiumRewardGems: 10,
          isUnlocked: true,
          isFreeClaimed: seasonRewardClaimed,
          isPremiumClaimed: false,
        ),
        SeasonTierModel(
          id: 'tier_2',
          tierNumber: 2,
          xpRequired: 250,
          freeRewardCoins: 400,
          freeRewardGems: 4,
          premiumRewardCoins: 1000,
          premiumRewardGems: 20,
          isUnlocked: true,
          isFreeClaimed: false,
          isPremiumClaimed: false,
        ),
        SeasonTierModel(
          id: 'tier_3',
          tierNumber: 3,
          xpRequired: 450,
          freeRewardCoins: 600,
          freeRewardGems: 6,
          premiumRewardCoins: 1500,
          premiumRewardGems: 30,
          isUnlocked: true,
          isFreeClaimed: false,
          isPremiumClaimed: false,
        ),
      ],
    );
  }

  @override
  Future<ClaimSeasonRewardModel> claimSeasonReward(int tierNumber, {bool isPremium = false}) async {
    seasonRewardClaimed = true;
    return ClaimSeasonRewardModel(
      tierNumber: tierNumber,
      coinsAwarded: 200,
      gemsAwarded: 2,
      newBalanceCoins: 3200,
      newBalanceGems: 52,
    );
  }

  @override
  Future<LeaderboardModel> getLeaderboard({
    String scope = 'ALL_TIME',
    int limit = 50,
    int offset = 0,
  }) async {
    return LeaderboardModel(
      scope: scope,
      totalPlayers: 4,
      entries: [
        LeaderboardEntryModel(
          rank: 1,
          userId: 'user_top_1',
          playerId: 'P1001',
          displayName: 'ApexLegend',
          avatarId: 'avatar_1',
          countryCode: 'IN',
          level: 15,
          score: 9500,
          matchesPlayed: 120,
          matchesWon: 95,
          winRate: 79.2,
        ),
        LeaderboardEntryModel(
          rank: 2,
          userId: 'user_top_2',
          playerId: 'P1002',
          displayName: 'SilverKnight',
          avatarId: 'avatar_2',
          countryCode: 'IN',
          level: 12,
          score: 8200,
          matchesPlayed: 110,
          matchesWon: 82,
          winRate: 74.5,
        ),
        LeaderboardEntryModel(
          rank: 3,
          userId: 'user_top_3',
          playerId: 'P1003',
          displayName: 'BronzeHero',
          avatarId: 'avatar_3',
          countryCode: 'IN',
          level: 10,
          score: 7100,
          matchesPlayed: 100,
          matchesWon: 71,
          winRate: 71.0,
        ),
        LeaderboardEntryModel(
          rank: 4,
          userId: 'user_top_4',
          playerId: 'P1004',
          displayName: 'MasterRoller',
          avatarId: 'avatar_4',
          countryCode: 'IN',
          level: 9,
          score: 6500,
          matchesPlayed: 90,
          matchesWon: 65,
          winRate: 72.2,
        ),
      ],
    );
  }

  @override
  Future<MyLeaderboardRankModel> getMyLeaderboardRank({String scope = 'ALL_TIME'}) async {
    return MyLeaderboardRankModel(
      scope: scope,
      rank: 4,
      score: 6500,
      matchesPlayed: 90,
      matchesWon: 65,
    );
  }
}

void main() {
  testWidgets('TournamentScreen renders tournament list, visual bracket, and handles join flow', (tester) async {
    final mockClient = MockTournamentsSeasonsApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: TournamentScreen(apiClient: mockClient),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and tournament titles
    expect(find.text('Tournaments'), findsOneWidget);
    expect(find.text('Royal Crown Championship'), findsAtLeastNWidgets(1));
    expect(find.text('500 Coins'), findsOneWidget);
    expect(find.text('3000 C / 25 G'), findsOneWidget);

    // Verify visual bracket section
    expect(find.text('TOURNAMENT BRACKET'), findsOneWidget);
    expect(find.text('Semifinal Board A (Seeds 1, 3, 5, 7)'), findsOneWidget);
    expect(find.text('Semifinal Board B (Seeds 2, 4, 6, 8)'), findsOneWidget);
    expect(find.text('Championship Board'), findsOneWidget);

    // Tap REGISTER button -> Shows dialog
    final registerBtn = find.text('REGISTER (500 COINS)');
    expect(registerBtn, findsOneWidget);
    await tester.tap(registerBtn);
    await tester.pumpAndSettle();

    // Verify dialog contents
    expect(find.text('Join Royal Crown Championship?'), findsOneWidget);
    expect(find.text('JOIN NOW'), findsOneWidget);

    // Confirm Join
    await tester.tap(find.text('JOIN NOW'));
    await tester.pumpAndSettle();

    // Verify registered status
    expect(mockClient.tournamentJoined, isTrue);
    expect(find.text('You are Registered in this Tournament!'), findsOneWidget);
  });

  testWidgets('SeasonScreen renders season roadmap and claims tier reward', (tester) async {
    final mockClient = MockTournamentsSeasonsApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: SeasonScreen(apiClient: mockClient),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Season header
    expect(find.text('Season Pass'), findsOneWidget);
    expect(find.text('Season 1: Royal Arena'), findsOneWidget);
    expect(find.text('ROYAL GOLD'), findsOneWidget);
    expect(find.text('ACTIVE SEASON'), findsOneWidget);
    expect(find.text('TIER 3'), findsOneWidget);
    expect(find.text('500 XP Total'), findsOneWidget);

    // Verify Tier Roadmap
    expect(find.text('TIER ROADMAP'), findsOneWidget);
    expect(find.text('Tier 1'), findsOneWidget);
    expect(find.text('Tier 2'), findsOneWidget);
    expect(find.text('Tier 3'), findsOneWidget);

    // Verify Claim button on unlocked Tier 1
    final claimBtn = find.text('CLAIM').first;
    expect(claimBtn, findsOneWidget);
    await tester.tap(claimBtn);
    await tester.pumpAndSettle();

    // Verify claim succeeded and updated state
    expect(mockClient.seasonRewardClaimed, isTrue);
    expect(find.text('Claimed'), findsAtLeastNWidgets(1));
  });

  testWidgets('LeaderboardScreen renders Top 3 Podium and sticky user rank bar', (tester) async {
    final mockClient = MockTournamentsSeasonsApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(apiClient: mockClient),
      ),
    );
    await tester.pumpAndSettle();

    // Verify tabs
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Seasonal'), findsOneWidget);
    expect(find.text('All-Time'), findsOneWidget);

    // Verify Top 3 Podium Players
    expect(find.text('ApexLegend'), findsOneWidget);
    expect(find.text('SilverKnight'), findsOneWidget);
    expect(find.text('BronzeHero'), findsOneWidget);
    expect(find.text('9500 pts'), findsOneWidget);

    // Verify remaining list contender
    expect(find.text('TOP CONTENDERS'), findsOneWidget);
    expect(find.text('MasterRoller'), findsOneWidget);
    expect(find.text('6500'), findsOneWidget);

    // Verify sticky bottom user rank
    expect(find.text('Your Rank This Period'), findsOneWidget);
    expect(find.text('65 wins / 90 matches'), findsOneWidget);
    expect(find.text('6500 PTS'), findsOneWidget);
  });
}
