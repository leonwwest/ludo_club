import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/services/statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  // Ensure Flutter bindings are initialized for SharedPreferences mocking
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerStats Model Tests', () {
    test('fromJson and toJson work correctly', () {
      final originalPlayerName = 'TestPlayer';
      final stats = PlayerStats(
        playerName: originalPlayerName,
        gamesPlayed: 10,
        gamesWon: 5,
        pawnsCaptured: 20,
        pawnsLost: 15,
        sixesRolled: 30,
      );

      final jsonMap = stats.toJson();
      expect(jsonMap['gamesPlayed'], 10);
      expect(jsonMap['gamesWon'], 5);
      expect(jsonMap['pawnsCaptured'], 20);
      expect(jsonMap['pawnsLost'], 15);
      expect(jsonMap['sixesRolled'], 30);
      expect(jsonMap.containsKey('playerName'), isFalse, reason: "playerName should not be in the toJson map");


      // When creating fromJson, the playerName is passed separately as it's not part of the stored map.
      final fromJsonStats = PlayerStats.fromJson(originalPlayerName, jsonMap);
      expect(fromJsonStats.playerName, originalPlayerName);
      expect(fromJsonStats.gamesPlayed, 10);
      expect(fromJsonStats.gamesWon, 5);
      expect(fromJsonStats.pawnsCaptured, 20);
      expect(fromJsonStats.pawnsLost, 15);
      expect(fromJsonStats.sixesRolled, 30);
    });

    test('winRate calculation is correct', () {
      expect(PlayerStats(playerName: 'P1', gamesPlayed: 0, gamesWon: 0).winRate, 0.0);
      expect(PlayerStats(playerName: 'P2', gamesPlayed: 10, gamesWon: 5).winRate, 0.5);
      expect(PlayerStats(playerName: 'P3', gamesPlayed: 10, gamesWon: 0).winRate, 0.0);
      expect(PlayerStats(playerName: 'P4', gamesPlayed: 10, gamesWon: 10).winRate, 1.0);
      expect(PlayerStats(playerName: 'P5', gamesPlayed: 3, gamesWon: 1).winRate, closeTo(0.333, 0.001));
    });
  });

  group('StatisticsService Tests', () {
    late StatisticsService statisticsService;

    setUp(() async {
      // Clear SharedPreferences before each test in this group
      SharedPreferences.setMockInitialValues({});
      statisticsService = StatisticsService();
    });

    test('getPlayerStats for new player returns zeroed stats with correct name', () async {
      final playerName = 'Newbie';
      final stats = await statisticsService.getPlayerStats(playerName);

      expect(stats.playerName, playerName);
      expect(stats.gamesPlayed, 0);
      expect(stats.gamesWon, 0);
      expect(stats.pawnsCaptured, 0);
      expect(stats.pawnsLost, 0);
      expect(stats.sixesRolled, 0);
    });

    test('getAllPlayerStats returns empty list when no stats saved', () async {
      final allStats = await statisticsService.getAllPlayerStats();
      expect(allStats, isEmpty);
    });

    test('increment methods correctly update and save stats for a new player', () async {
      final playerName = 'PlayerOne';
      await statisticsService.incrementGamesPlayed(playerName);
      await statisticsService.incrementGamesWon(playerName, count: 1); // gamesPlayed will be 1, gamesWon will be 1

      final stats = await statisticsService.getPlayerStats(playerName);
      expect(stats.playerName, playerName);
      expect(stats.gamesPlayed, 1);
      expect(stats.gamesWon, 1);
    });

    test('getPlayerStats retrieves previously saved stats accurately', () async {
      final playerName = 'PlayerTwo';
      await statisticsService.incrementGamesPlayed(playerName, count: 5);
      await statisticsService.incrementSixesRolled(playerName, count: 10);

      final stats = await statisticsService.getPlayerStats(playerName);
      expect(stats.playerName, playerName);
      expect(stats.gamesPlayed, 5);
      expect(stats.sixesRolled, 10);
      expect(stats.gamesWon, 0); // Not incremented
    });

    test('stats are case-insensitive for player name keys but preserve original display name', () async {
      final originalName = "PlayerA";
      final lookupNameLowerCase = "playera";
      final lookupNameUpperCase = "PLAYERA";

      await statisticsService.incrementGamesPlayed(originalName, count: 1);
      
      // Retrieve with different casings
      PlayerStats statsLowerCase = await statisticsService.getPlayerStats(lookupNameLowerCase);
      PlayerStats statsUpperCase = await statisticsService.getPlayerStats(lookupNameUpperCase);
      PlayerStats statsOriginalCase = await statisticsService.getPlayerStats(originalName);

      // PlayerName in PlayerStats object should be the originally saved one
      expect(statsLowerCase.playerName, originalName);
      expect(statsUpperCase.playerName, originalName);
      expect(statsOriginalCase.playerName, originalName);

      expect(statsLowerCase.gamesPlayed, 1);
      expect(statsUpperCase.gamesPlayed, 1);
      expect(statsOriginalCase.gamesPlayed, 1);

      // Check the list of player names
      final prefs = await SharedPreferences.getInstance();
      final List<String> playerNamesList = prefs.getStringList(StatisticsService_playerStatsListKey) ?? [];
      expect(playerNamesList, contains(originalName));
      expect(playerNamesList.length, 1); // Should only contain the original casing once
    });
    
    // Expose the private constant for testing only
    const String StatisticsService_playerStatsListKey = 'statPlayerNames';


    test('getAllPlayerStats retrieves all saved player stats with correct display names', () async {
      await statisticsService.incrementGamesPlayed("PlayerAlpha", count: 1);
      await statisticsService.incrementGamesWon("PlayerBeta", count: 1);
      await statisticsService.incrementGamesPlayed("PlayerBeta", count: 1); // Beta played 1 game, won 1 game

      final allStats = await statisticsService.getAllPlayerStats();
      expect(allStats.length, 2);

      final statsAlpha = allStats.firstWhere((s) => s.playerName == "PlayerAlpha");
      final statsBeta = allStats.firstWhere((s) => s.playerName == "PlayerBeta");

      expect(statsAlpha.gamesPlayed, 1);
      expect(statsBeta.gamesPlayed, 1);
      expect(statsBeta.gamesWon, 1);
    });

    test('_playerStatsListKey correctly stores unique display names (respecting first-encountered canonical form)', () async {
      await statisticsService.incrementGamesPlayed("PlayerC", count: 1);
      await statisticsService.incrementGamesPlayed("playerc", count: 1); // Same player, different case
      await statisticsService.incrementGamesPlayed("Player D", count: 1); // Different player

      final prefs = await SharedPreferences.getInstance();
      final List<String> playerNamesList = prefs.getStringList(StatisticsService_playerStatsListKey) ?? [];
      
      expect(playerNamesList.length, 2, reason: "Should only have 'PlayerC' (or the first encountered form like 'playerc') and 'Player D'");
      // The current implementation of _savePlayerStats for the list might add "playerc" if "PlayerC" wasn't found by exact match first.
      // The important part is that the *keys* are normalized. The display list behavior for near-duplicates is secondary but good to observe.
      // The current _savePlayerStats logic for the list:
      // It iterates and checks `playerNames[i].toLowerCase().trim() == normalizedCurrentName`.
      // If it finds a match, it uses that. If not, it adds the new `displayPlayerName`.
      // So, if "PlayerC" is added, then "playerc" is added:
      // "playerc".toLowerCase().trim() == "playerc"
      // "PlayerC".toLowerCase().trim() == "playerc" -> match found, "playerc" is NOT added again. List has "PlayerC".
      // This is correct.
      expect(playerNamesList, contains("PlayerC"));
      expect(playerNamesList, contains("Player D"));
    });

    test('recordGamePlayed increments gamesPlayed for all listed players', () async {
      final p1 = "Alice";
      final p2 = "Bob";
      final p3 = "Charlie";
      await statisticsService.recordGamePlayed([p1, p2, p3]);

      final statsP1 = await statisticsService.getPlayerStats(p1);
      final statsP2 = await statisticsService.getPlayerStats(p2);
      final statsP3 = await statisticsService.getPlayerStats(p3);

      expect(statsP1.gamesPlayed, 1);
      expect(statsP2.gamesPlayed, 1);
      expect(statsP3.gamesPlayed, 1);
    });

    test('resetAllStats clears all player statistics and the list of player names', () async {
      await statisticsService.incrementGamesPlayed("PlayerX", count: 1);
      await statisticsService.incrementGamesPlayed("PlayerY", count: 1);

      await statisticsService.resetAllStats();

      final allStats = await statisticsService.getAllPlayerStats();
      expect(allStats, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(StatisticsService_playerStatsListKey), isNull);
      expect(prefs.getString('stats_playerx'), isNull); // Check a specific player key
    });

    test('incrementPawnsCaptured updates correctly', () async {
      final playerName = "Captor";
      await statisticsService.incrementPawnsCaptured(playerName, count: 3);
      final stats = await statisticsService.getPlayerStats(playerName);
      expect(stats.pawnsCaptured, 3);
    });

    test('incrementSixesRolled updates correctly', () async {
      final playerName = "Lucky";
      await statisticsService.incrementSixesRolled(playerName, count: 7);
      final stats = await statisticsService.getPlayerStats(playerName);
      expect(stats.sixesRolled, 7);
    });
    
    test('incrementPawnsLost updates correctly', () async {
      final playerName = "Unlucky";
      await statisticsService.incrementPawnsLost(playerName, count: 2);
      final stats = await statisticsService.getPlayerStats(playerName);
      expect(stats.pawnsLost, 2);
    });

    test('stats keys are normalized (trimmed, lowercase)', () async {
      final fancyName = "  Player C  ";
      final normalizedLookup = "player c";
      final keyForStats = 'stats_player c'; // This is what _playerStatsKey("  Player C  ") would produce

      await statisticsService.incrementGamesPlayed(fancyName, count: 1);
      
      // Check direct SharedPreferences content
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(keyForStats), isTrue, reason: "Stats should be saved under normalized key");
      
      // Check retrieval via service
      final stats = await statisticsService.getPlayerStats(normalizedLookup);
      expect(stats.playerName, fancyName.trim(), reason: "Display name should be the trimmed original");
      expect(stats.gamesPlayed, 1);

      final List<String> playerNamesList = prefs.getStringList(StatisticsService_playerStatsListKey) ?? [];
      expect(playerNamesList, contains(fancyName.trim()));
    });
  });
}
