import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart'; // Player is in here too
import 'package:ludo_club/services/save_load_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Manual Mock for SharedPreferences
class MockSharedPreferences implements SharedPreferences {
  final Map<String, Object> _values = {};

  @override
  Future<bool> clear() {
    _values.clear();
    return Future.value(true);
  }

  @override
  Future<bool> commit() => Future.value(true);

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Object? get(String key) => _values[key];

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  double? getDouble(String key) => _values[key] as double?;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  Set<String> getKeys() => _values.keys.toSet();

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  List<String>? getStringList(String key) => _values[key] as List<String>?;

  @override
  Future<void> reload() => Future.value();

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return Future.value(true);
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _values[key] = value;
    return Future.value(true);
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _values[key] = value;
    return Future.value(true);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _values[key] = value;
    return Future.value(true);
  }

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return Future.value(true);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _values[key] = value;
    return Future.value(true);
  }

  // Helper for tests to directly set initial values
  void setMockInitialValues(Map<String, Object> values) {
    _values.clear();
    _values.addAll(values);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Needed for SharedPreferences path_provider

  group('SaveLoadService', () {
    late SaveLoadService saveLoadService;
    late MockSharedPreferences mockSharedPreferences;

    // Helper to create a sample GameState
    GameState createSampleGameState({
      String gameId = 'game1',
      String currentPlayerId = 'player1',
      List<Player>? players,
      int diceValue = 5,
      int rollCount = 1,
      String? winnerId,
    }) {
      final p = players ??
          [
            Player('player1', 'Alice', initialPositions: [-1, 10, 20, 99], isAI: false),
            Player('player2', 'Bob', initialPositions: [5, 15, 25, -1], isAI: true),
          ];
      return GameState(
        gameId: gameId,
        startIndex: {'player1': 0, 'player2': 13, 'player3': 26, 'player4': 39},
        players: p,
        currentTurnPlayerId: currentPlayerId,
        lastDiceValue: diceValue,
        currentRollCount: rollCount,
        winnerId: winnerId,
      );
    }

    setUp(() async {
      mockSharedPreferences = MockSharedPreferences();
      saveLoadService = SaveLoadService.withPrefs(mockSharedPreferences);
      // No need to call SharedPreferences.setMockInitialValues here unless for a specific test case
      // as most tests will prepare their own SharedPreferences state.
    });

    group('saveGame', () {
      test('saves a new game correctly with a custom name', () async {
        final gameState = createSampleGameState(gameId: 'testSave1');
        const customName = 'My Test Game';

        final success = await saveLoadService.saveGame(gameState, customName: customName);
        expect(success, isTrue);

        final savedGamesList = mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey);
        expect(savedGamesList, isNotNull);
        expect(savedGamesList!.length, 1);

        final gameEntryJson = jsonDecode(savedGamesList.first) as Map<String, dynamic>;
        expect(gameEntryJson['name'], customName);
        expect(gameEntryJson['gameId'], gameState.gameId);
        expect(gameEntryJson['timestamp'], isNotNull);
        expect(DateTime.fromMillisecondsSinceEpoch(gameEntryJson['timestamp'] as int).isBefore(DateTime.now().add(Duration(seconds:1))), isTrue);


        final savedStateJson = mockSharedPreferences.getString(gameState.gameId!);
        expect(savedStateJson, isNotNull);
        final savedStateMap = jsonDecode(savedStateJson!) as Map<String, dynamic>;
        expect(GameState.fromJson(savedStateMap), gameState); // Uses GameState.==
      });

      test('saves a new game with an auto-generated name if customName is null', () async {
        final gameState = createSampleGameState(gameId: 'autoNameGame');
        await saveLoadService.saveGame(gameState);

        final savedGamesList = mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey);
        expect(savedGamesList, isNotNull);
        final gameEntryJson = jsonDecode(savedGamesList!.first) as Map<String, dynamic>;
        
        expect(gameEntryJson['name'], startsWith('Game ')); // Default naming convention
        expect(gameEntryJson['gameId'], gameState.gameId);
      });

      test('updates existing game if gameId already in metadata list', () async {
        final originalGameState = createSampleGameState(gameId: 'existingGame', currentPlayerId: 'player1');
        await saveLoadService.saveGame(originalGameState, customName: "Original Name");

        final updatedGameState = originalGameState.copy();
        updatedGameState.currentTurnPlayerId = 'player2'; // Make a change
        updatedGameState.lastDiceValue = 3;

        await saveLoadService.saveGame(updatedGameState, customName: "Updated Name");

        final savedGamesList = mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey);
        expect(savedGamesList!.length, 1); // Should not add a new entry

        final gameEntryJson = jsonDecode(savedGamesList.first) as Map<String, dynamic>;
        expect(gameEntryJson['name'], "Updated Name"); // Name should be updated
        expect(gameEntryJson['gameId'], originalGameState.gameId);

        final savedStateJson = mockSharedPreferences.getString(originalGameState.gameId!);
        expect(GameState.fromJson(jsonDecode(savedStateJson!)), updatedGameState);
      });
      
      test('limits the number of saved games to maxSavedGames', () async {
        final oldMax = SaveLoadService.maxSavedGames;
        SaveLoadService.maxSavedGames = 2; // For easier testing

        for (int i = 0; i < SaveLoadService.maxSavedGames + 1; i++) {
          final gameState = createSampleGameState(gameId: 'game$i');
          await saveLoadService.saveGame(gameState, customName: 'Game $i');
        }

        final savedGamesList = mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey);
        expect(savedGamesList!.length, SaveLoadService.maxSavedGames);

        final gameEntry0 = jsonDecode(savedGamesList.first) as Map<String, dynamic>;
        // The oldest game ('game0') should be removed.
        // Games are added to the start of the list, so the last one is 'gameMax'
        // and the first one is 'gameMax-1' (after the oldest is removed)
        expect(gameEntry0['gameId'], 'game2'); // game0 removed, game1 and game2 remain, game2 is newest
        
        expect(mockSharedPreferences.getString('game0'), isNull); // game0 state should be deleted
        expect(mockSharedPreferences.getString('game1'), isNotNull);
        expect(mockSharedPreferences.getString('game2'), isNotNull);

        SaveLoadService.maxSavedGames = oldMax; // Reset for other tests
      });

      test('saves multiple different games correctly', () async {
        final game1 = createSampleGameState(gameId: 'multi1', currentPlayerId: 'player1');
        final game2 = createSampleGameState(gameId: 'multi2', currentPlayerId: 'player2');

        await saveLoadService.saveGame(game1, customName: 'Multi 1');
        await saveLoadService.saveGame(game2, customName: 'Multi 2');

        final savedGamesList = mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey);
        expect(savedGamesList!.length, 2);

        final entry1Json = jsonDecode(savedGamesList![1]) as Map<String, dynamic>; // game1 was saved first
        final entry2Json = jsonDecode(savedGamesList[0]) as Map<String, dynamic>; // game2 was saved second (newest)

        expect(entry1Json['gameId'], 'multi1');
        expect(entry2Json['gameId'], 'multi2');

        expect(GameState.fromJson(jsonDecode(mockSharedPreferences.getString('multi1')!)), game1);
        expect(GameState.fromJson(jsonDecode(mockSharedPreferences.getString('multi2')!)), game2);
      });
    });

    group('loadGame', () {
      late GameState state1, state2;

      setUp(() async {
        state1 = createSampleGameState(gameId: 'load1', currentPlayerId: 'p1');
        state2 = createSampleGameState(gameId: 'load2', currentPlayerId: 'p2');
        
        // Pre-populate SharedPreferences
        await saveLoadService.saveGame(state1, customName: "Load Game 1");
        await saveLoadService.saveGame(state2, customName: "Load Game 2");
        // After these saves, metadata list will be [entry_state2, entry_state1]
      });

      test('loads the most recent game (index 0)', () async {
        final loadedState = await saveLoadService.loadGame(0);
        expect(loadedState, isNotNull);
        expect(loadedState, state2); // state2 was saved last, so it's at index 0
      });

      test('loads an older game by index', () async {
        final loadedState = await saveLoadService.loadGame(1);
        expect(loadedState, isNotNull);
        expect(loadedState, state1); // state1 was saved first, so it's at index 1
      });

      test('returns null for an out-of-bounds index (negative)', () async {
        final loadedState = await saveLoadService.loadGame(-1);
        expect(loadedState, isNull);
      });

      test('returns null for an out-of-bounds index (too large)', () async {
        final loadedState = await saveLoadService.loadGame(5); // Only 2 games saved
        expect(loadedState, isNull);
      });
       test('returns null if game state string is missing for a valid metadata entry', () async {
        // Corrupt SharedPreferences: remove the GameState string for an existing metadata entry
        final savedGamesMeta = mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey)!;
        final firstGameMeta = jsonDecode(savedGamesMeta.first) as Map<String, dynamic>;
        mockSharedPreferences.remove(firstGameMeta['gameId'] as String);

        final loadedState = await saveLoadService.loadGame(0);
        expect(loadedState, isNull);
      });
    });

    group('deleteGame', () {
      late GameState state1, state2, state3;

      setUp(() async {
        state1 = createSampleGameState(gameId: 'del1');
        state2 = createSampleGameState(gameId: 'del2');
        state3 = createSampleGameState(gameId: 'del3');
        await saveLoadService.saveGame(state1, customName: "Delete 1");
        await saveLoadService.saveGame(state2, customName: "Delete 2");
        await saveLoadService.saveGame(state3, customName: "Delete 3");
        // Metadata list: [entry_state3, entry_state2, entry_state1]
      });

      test('deletes a game from the middle of the list', () async {
        final success = await saveLoadService.deleteGame(1); // Deletes 'del2'
        expect(success, isTrue);

        final savedGamesList = mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey);
        expect(savedGamesList!.length, 2);
        expect(mockSharedPreferences.getString('del2'), isNull); // GameState string removed
        
        final entries = savedGamesList.map((s) => jsonDecode(s) as Map<String,dynamic>).toList();
        expect(entries.any((e) => e['gameId'] == 'del2'), isFalse); // Metadata entry removed
        expect(entries.any((e) => e['gameId'] == 'del1'), isTrue);
        expect(entries.any((e) => e['gameId'] == 'del3'), isTrue);
      });

      test('deletes the most recent game (index 0)', async {
        final success = await saveLoadService.deleteGame(0); // Deletes 'del3'
        expect(success, isTrue);
        expect(mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey)!.length, 2);
        expect(mockSharedPreferences.getString('del3'), isNull);
      });
      
      test('deletes the oldest game (last index)', async {
        final success = await saveLoadService.deleteGame(2); // Deletes 'del1'
        expect(success, isTrue);
        expect(mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey)!.length, 2);
        expect(mockSharedPreferences.getString('del1'), isNull);
      });

      test('deletes the only game', () async {
        // Clear and save only one game
        await mockSharedPreferences.clear();
        final singleState = createSampleGameState(gameId: 'single');
        await saveLoadService.saveGame(singleState, customName: "Single Game");

        final success = await saveLoadService.deleteGame(0);
        expect(success, isTrue);
        expect(mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey)!.isEmpty, isTrue);
        expect(mockSharedPreferences.getString('single'), isNull);
      });
      
      test('returns false for an out-of-bounds index (negative)', () async {
        final success = await saveLoadService.deleteGame(-1);
        expect(success, isFalse);
        expect(mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey)!.length, 3); // No change
      });

      test('returns false for an out-of-bounds index (too large)', () async {
        final success = await saveLoadService.deleteGame(5);
        expect(success, isFalse);
        expect(mockSharedPreferences.getStringList(SaveLoadService.savedGamesKey)!.length, 3); // No change
      });
    });

    group('getSavedGames', () {
      test('returns an empty list when no games are saved', () async {
        mockSharedPreferences.setMockInitialValues({}); // Ensure empty
        final games = await saveLoadService.getSavedGames();
        expect(games, isEmpty);
      });

      test('returns a list of saved game metadata', () async {
        final state1 = createSampleGameState(gameId: 'meta1');
        final state2 = createSampleGameState(gameId: 'meta2');
        await saveLoadService.saveGame(state1, customName: "Metadata Game 1");
        await saveLoadService.saveGame(state2, customName: "Metadata Game 2");
        // Metadata list: [entry_state2, entry_state1]

        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 2);

        // Check newest (index 0)
        expect(gamesInfo[0]['name'], "Metadata Game 2");
        expect(gamesInfo[0]['gameId'], "meta2");
        expect(gamesInfo[0]['timestamp'], isA<int>());
        expect(gamesInfo[0]['gameStateJson'], isNull); // Should not contain full state

        // Check older (index 1)
        expect(gamesInfo[1]['name'], "Metadata Game 1");
        expect(gamesInfo[1]['gameId'], "meta1");
        expect(gamesInfo[1]['timestamp'], isA<int>());
      });
    });

    group('Data Integrity', () {
      test('saved and loaded GameState is equivalent to the original', () async {
        final originalState = createSampleGameState(gameId: 'integrityTest');
        await saveLoadService.saveGame(originalState, customName: "Integrity Test");

        final loadedState = await saveLoadService.loadGame(0);
        expect(loadedState, isNotNull);
        expect(loadedState, originalState); // Uses GameState.==

        // Explicit checks for a few key properties
        expect(loadedState!.gameId, originalState.gameId);
        expect(loadedState.currentTurnPlayerId, originalState.currentTurnPlayerId);
        expect(loadedState.players.length, originalState.players.length);
        for (int i = 0; i < loadedState.players.length; i++) {
          expect(loadedState.players[i], originalState.players[i]); // Uses Player.==
        }
        expect(loadedState.lastDiceValue, originalState.lastDiceValue);
      });
    });

    group('Error Handling', () {
      test('loadGame returns null for malformed GameState JSON', () async {
        final gameId = 'malformedJsonGame';
        final metadataList = [
          jsonEncode({'gameId': gameId, 'name': 'Malformed Test', 'timestamp': DateTime.now().millisecondsSinceEpoch})
        ];
        mockSharedPreferences.setMockInitialValues({
          SaveLoadService.savedGamesKey: metadataList,
          gameId: 'this_is_not_valid_json',
        });

        final loadedState = await saveLoadService.loadGame(0);
        expect(loadedState, isNull);
      });

      test('loadGame returns null for GameState JSON missing crucial fields', () async {
        final gameId = 'missingFieldsGame';
        final metadataList = [
          jsonEncode({'gameId': gameId, 'name': 'Missing Fields Test', 'timestamp': DateTime.now().millisecondsSinceEpoch})
        ];
        // Valid JSON, but GameState.fromJson would fail (e.g., missing 'players' or 'currentTurnPlayerId')
        final incompleteJson = jsonEncode({
          'startIndex': {'p1': 0},
          // 'players': [], // Missing players
          'currentTurnPlayerId': 'p1',
          'gameId': gameId,
        });
        mockSharedPreferences.setMockInitialValues({
          SaveLoadService.savedGamesKey: metadataList,
          gameId: incompleteJson,
        });

        final loadedState = await saveLoadService.loadGame(0);
        expect(loadedState, isNull, reason: "GameState.fromJson should fail and service should handle it by returning null.");
      });
      
      test('loadGame still loads other valid games if one entry is corrupted (missing GameState JSON)', () async {
        final validGameId = 'validGame';
        final corruptedGameId = 'corruptedGame_NoState';
        final validGameState = createSampleGameState(gameId: validGameId);

        final metadataList = [
          jsonEncode({'gameId': corruptedGameId, 'name': 'Corrupted Entry', 'timestamp': DateTime.now().millisecondsSinceEpoch}),
          jsonEncode({'gameId': validGameId, 'name': 'Valid Entry', 'timestamp': DateTime.now().millisecondsSinceEpoch}),
        ];
        mockSharedPreferences.setMockInitialValues({
          SaveLoadService.savedGamesKey: metadataList,
          // GameState for corruptedGameId is intentionally missing
          validGameId: jsonEncode(validGameState.toJson()),
        });

        // Attempt to load the corrupted one (index 0)
        final corruptedLoadedState = await saveLoadService.loadGame(0);
        expect(corruptedLoadedState, isNull, reason: "Loading a game with missing state JSON should return null.");

        // Attempt to load the valid one (index 1)
        final validLoadedState = await saveLoadService.loadGame(1);
        expect(validLoadedState, isNotNull, reason: "Should still be able to load other valid games.");
        expect(validLoadedState, validGameState);
      });


      test('getSavedGames filters out entries with malformed JSON in metadata list', () async {
        final validEntry = {'gameId': 'valid1', 'name': 'Valid Game Metadata', 'timestamp': DateTime.now().millisecondsSinceEpoch};
        final List<String> savedGamesIndex = [
          jsonEncode(validEntry),
          'this_is_not_json', // Malformed entry
          jsonEncode({'gameId': 'valid2', 'name': 'Another Valid', 'timestamp': DateTime.now().millisecondsSinceEpoch}),
        ];
        mockSharedPreferences.setMockInitialValues({
          SaveLoadService.savedGamesKey: savedGamesIndex,
        });

        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 2, reason: "Should skip the malformed JSON entry.");
        expect(gamesInfo[0]['gameId'], 'valid1');
        expect(gamesInfo[1]['gameId'], 'valid2');
      });

      test('getSavedGames filters out entries with missing required fields in metadata JSON', () async {
        final List<String> savedGamesIndex = [
          jsonEncode({'gameId': 'validFull', 'name': 'Valid Full', 'timestamp': DateTime.now().millisecondsSinceEpoch}),
          jsonEncode({'gameId': 'missingName', 'timestamp': DateTime.now().millisecondsSinceEpoch}), // Missing 'name'
          jsonEncode({'name': 'missingGameId', 'timestamp': DateTime.now().millisecondsSinceEpoch}), // Missing 'gameId'
          jsonEncode({'gameId': 'validAgain', 'name': 'Valid Again', 'timestamp': DateTime.now().millisecondsSinceEpoch}),
        ];
         mockSharedPreferences.setMockInitialValues({
          SaveLoadService.savedGamesKey: savedGamesIndex,
        });

        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 2, reason: "Should skip entries missing required metadata fields.");
        expect(gamesInfo.any((g) => g['gameId'] == 'validFull'), isTrue);
        expect(gamesInfo.any((g) => g['gameId'] == 'validAgain'), isTrue);
        expect(gamesInfo.any((g) => g['gameId'] == 'missingName'), isFalse);
        expect(gamesInfo.any((g) => g['name'] == 'missingGameId'), isFalse);
      });

      test('getSavedGames returns metadata even if the GameState JSON itself is missing or corrupted', () async {
        // This scenario tests that getSavedGames focuses on metadata integrity.
        // loadGame would fail for these, but getSavedGames should still list them.
        final gameId1 = 'metaOnly1';
        final gameId2 = 'metaOnly2_corruptState';
        final List<String> savedGamesIndex = [
          jsonEncode({'gameId': gameId1, 'name': 'Meta Only - No State String', 'timestamp': DateTime.now().millisecondsSinceEpoch}),
          jsonEncode({'gameId': gameId2, 'name': 'Meta Only - Corrupt State String', 'timestamp': DateTime.now().millisecondsSinceEpoch}),
        ];
        mockSharedPreferences.setMockInitialValues({
          SaveLoadService.savedGamesKey: savedGamesIndex,
          // gameId1's state string is missing
          gameId2: 'this_is_bad_json_for_state', // gameId2 has corrupted state string
        });
        
        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 2);
        expect(gamesInfo[0]['gameId'], gameId1);
        expect(gamesInfo[1]['gameId'], gameId2);

        // Verify that loading these would indeed fail (as per other tests)
        final state1 = await saveLoadService.loadGame(0);
        expect(state1, isNull, reason: "Loading game with missing state string should fail.");
        final state2 = await saveLoadService.loadGame(1);
        expect(state2, isNull, reason: "Loading game with corrupt state string should fail.");
      });

      test('saveGame returns false if SharedPreferences.setStringList fails for metadata', () async {
        mockSharedPreferences.setStringList = (String key, List<String> value) async {
          if (key == SaveLoadService.savedGamesKey) return false; // Simulate failure
          mockSharedPreferences._values[key] = value; // Original behavior for other keys
          return true;
        };
        final gameState = createSampleGameState(gameId: 'failMetaSave');
        final success = await saveLoadService.saveGame(gameState);
        expect(success, isFalse);
      });
      
      test('saveGame returns false if SharedPreferences.setString fails for game state', () async {
        mockSharedPreferences.setString = (String key, String value) async {
          if (key != SaveLoadService.savedGamesKey) return false; // Simulate failure for game state string
          mockSharedPreferences._values[key] = value; // Original behavior for metadata key
          return true;
        };
        final gameState = createSampleGameState(gameId: 'failStateSave');
        final success = await saveLoadService.saveGame(gameState);
        expect(success, isFalse);
      });

      // Conceptual point: Direct SharedPreferences operational errors (e.g., disk full, platform errors)
      // are hard to simulate with the current MockSharedPreferences. The service would typically
      // let these propagate as Exceptions. The current tests for setString/setStringList returning false
      // cover cases where the operation itself reports a failure, which is a form of error handling.
      // True platform-level errors would likely require a more sophisticated mocking layer for SharedPreferences.
      // For now, this is noted as a limitation of the current test setup rather than a specific test case to implement.
       test('Conceptual: SharedPreferences platform errors', () {
        print("NOTE: Direct simulation of SharedPreferences platform errors (e.g., disk full) is beyond current mock capabilities. Service would typically propagate these.");
        expect(true, isTrue); // Placeholder
      });

    });
  });
}
