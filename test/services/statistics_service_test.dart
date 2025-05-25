import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:ludo_club/models/player.dart';
import 'package:ludo_club/models/player_stats.dart';
import 'package:ludo_club/services/statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Key for storing player stats list in SharedPreferences
const String playerStatsListKey = 'player_stats_list';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatisticsService', () {
    late StatisticsService statisticsService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      // Initialize SharedPreferences with mock values for testing
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      statisticsService = StatisticsService(sharedPreferences);
    });

    // Helper to create a sample PlayerStats
    PlayerStats createSamplePlayerStats({
      String name = 'TestPlayer',
      int gamesWon = 0,
      int totalGamesPlayed = 0,
      double winRate = 0.0,
      double averageMovesPerGame = 0.0,
      int totalPiecesCaptured = 0,
    }) {
      return PlayerStats(
        playerName: name,
        gamesWon: gamesWon,
        totalGamesPlayed: totalGamesPlayed,
        winRate: winRate,
        averageMovesPerGame: averageMovesPerGame,
        totalPiecesCaptured: totalPiecesCaptured,
      );
    }

    test('initializes with empty list if no data in SharedPreferences', () {
      expect(statisticsService.playerStatsList, isEmpty);
    });

    test('loadPlayerStats loads data from SharedPreferences', () async {
      final stats = [createSamplePlayerStats(name: 'Player1')];
      final jsonStats = stats.map((s) => s.toJson()).toList();
      await sharedPreferences.setString(playerStatsListKey, jsonEncode(jsonStats));

      await statisticsService.loadPlayerStats();
      expect(statisticsService.playerStatsList.first.playerName, 'Player1');
    });

    test('savePlayerStats saves data to SharedPreferences', () async {
      statisticsService.playerStatsList = [createSamplePlayerStats(name: 'PlayerToSave')];
      await statisticsService.savePlayerStats();

      final savedData = sharedPreferences.getString(playerStatsListKey);
      expect(savedData, isNotNull);
      // Further validation can be done by decoding and comparing
    });

    test('updatePlayerStats updates existing player or adds new one', () {
      statisticsService.updatePlayerStats('NewPlayer', true, 10, 5); // Win
      expect(statisticsService.playerStatsList.first.playerName, 'NewPlayer');
      expect(statisticsService.playerStatsList.first.gamesWon, 1);
      expect(statisticsService.playerStatsList.first.totalGamesPlayed, 1);

      statisticsService.updatePlayerStats('NewPlayer', false, 15, 3); // Loss
      expect(statisticsService.playerStatsList.first.gamesWon, 1);
      expect(statisticsService.playerStatsList.first.totalGamesPlayed, 2);
    });

    test('calculateWinRate calculates correctly', () {
      final stats = createSamplePlayerStats(gamesWon: 5, totalGamesPlayed: 10);
      final winRate = statisticsService.calculateWinRate(stats);
      expect(winRate, 50.0);

      final statsNoGames = createSamplePlayerStats();
      final winRateNoGames = statisticsService.calculateWinRate(statsNoGames);
      expect(winRateNoGames, 0.0);
    });

    test('getPlayerStats returns correct stats or default for new player', () {
      statisticsService.playerStatsList = [createSamplePlayerStats(name: 'ExistingPlayer')];
      final existingPlayerStats = statisticsService.getPlayerStats('ExistingPlayer');
      expect(existingPlayerStats.playerName, 'ExistingPlayer');

      final newPlayerStats = statisticsService.getPlayerStats('NonExistentPlayer');
      expect(newPlayerStats.playerName, 'NonExistentPlayer');
      expect(newPlayerStats.gamesWon, 0); // Default value
    });

    test('resetPlayerStats resets stats for a specific player', () async {
      statisticsService.playerStatsList = [createSamplePlayerStats(name: 'PlayerToReset', gamesWon: 5)];
      await statisticsService.resetPlayerStats('PlayerToReset');
      final resetStats = statisticsService.getPlayerStats('PlayerToReset');
      expect(resetStats.gamesWon, 0);
      expect(resetStats.totalGamesPlayed, 0);
    });

    test('resetAllStats clears all player stats', () async {
      statisticsService.playerStatsList = [createSamplePlayerStats(name: 'P1'), createSamplePlayerStats(name: 'P2')];
      await statisticsService.resetAllStats();
      expect(statisticsService.playerStatsList, isEmpty);
      expect(sharedPreferences.getString(playerStatsListKey), isNull); // Check SharedPreferences cleared
    });

    // Example for prefer_const_declarations with list/map literals for tests
    test('uses const for lists in test setup where appropriate', () {
      const constPlayerNames = ['PlayerA', 'PlayerB']; // Example of const list
      // Use constPlayerNames in test logic
      expect(constPlayerNames.length, 2);
    });
  });
} 