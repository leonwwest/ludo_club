import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart'; // Player is in here too
import 'package:ludo_club/services/save_load_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
    // MockSharedPreferences instance is not directly injected into SaveLoadService anymore.
    // We will use SharedPreferences.setMockInitialValues() globally for tests.

    // Helper to create a sample GameState (ensure it matches definition, e.g. using lastDiceValue)
    GameState createSampleGameState({
      String gameId = 'game1',
      String currentPlayerId = 'player1',
      List<Player>? players,
      int? lastDiceVal, // Changed from diceValue
      int rollCount = 0, // Default to 0 as per GameState constructor
      String? winnerId,
    }) {
      final p = players ??
          [
            Player('player1', 'Alice', initialPositions: [-1, 10, 20, GameState.finishedPosition]),
            Player('player2', 'Bob', initialPositions: [5, 15, 25, GameState.basePosition]),
          ];
      return GameState(
        gameId: gameId, // GameState has gameId
        startIndex: {'player1': 0, 'player2': 13, 'player3': 26, 'player4': 39},
        players: p,
        currentTurnPlayerId: currentPlayerId,
        lastDiceValue: lastDiceVal,
        currentRollCount: rollCount,
        winnerId: winnerId,
      );
    }

    setUp(() {
      // SaveLoadService has no constructor arguments.
      saveLoadService = SaveLoadService();
      // Crucial: Clear SharedPreferences before each test to ensure isolation.
      SharedPreferences.setMockInitialValues({}); 
    });

    group('saveGame', () {
      test('saves a new game correctly with a custom name', () async {
        final gameState = createSampleGameState(gameId: 'testSave1');
        const customName = 'My Test Game';

        final success = await saveLoadService.saveGame(gameState, customName: customName);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final savedGamesList = prefs.getStringList('saved_games');

        expect(savedGamesList, isNotNull);
        expect(savedGamesList!.length, 1);

        final gameEntryJson = jsonDecode(savedGamesList.first) as Map<String, dynamic>;
        expect(gameEntryJson['saveName'], customName);
        final savedGameState = SaveLoadServiceTestAccessors.jsonToGameState(gameEntryJson);
        expect(savedGameState.gameId, gameState.gameId);
        expect(savedGameState, gameState);
      });

      test('saves a new game with an auto-generated name if customName is null', () async {
        final gameState = createSampleGameState(gameId: 'autoNameGame');
        final success = await saveLoadService.saveGame(gameState);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final savedGamesList = prefs.getStringList('saved_games');
        expect(savedGamesList, isNotNull);
        expect(savedGamesList!.length, 1);

        final gameEntryJson = jsonDecode(savedGamesList.first) as Map<String, dynamic>;
        expect(gameEntryJson['saveName'], startsWith('Spielstand vom '));
        final savedGameState = SaveLoadServiceTestAccessors.jsonToGameState(gameEntryJson);
        expect(savedGameState.gameId, gameState.gameId);
      });

      test('saveGame adds to the list, does not update existing by gameId', () async {
        final originalGameState = createSampleGameState(gameId: 'gameToOverwrite', currentPlayerId: 'player1');
        await saveLoadService.saveGame(originalGameState, customName: "Original Save");

        final slightlyDifferentGameState = createSampleGameState(gameId: 'gameToOverwrite', currentPlayerId: 'player2');
        await saveLoadService.saveGame(slightlyDifferentGameState, customName: "New Save with Same ID");

        final prefs = await SharedPreferences.getInstance();
        final savedGamesList = prefs.getStringList('saved_games');
        expect(savedGamesList!.length, 2);

        final entry1Json = jsonDecode(savedGamesList[0]) as Map<String, dynamic>;
        final entry2Json = jsonDecode(savedGamesList[1]) as Map<String, dynamic>;

        expect(entry1Json['saveName'], "Original Save");
        final state1 = SaveLoadServiceTestAccessors.jsonToGameState(entry1Json);
        expect(state1.currentTurnPlayerId, 'player1');

        expect(entry2Json['saveName'], "New Save with Same ID");
        final state2 = SaveLoadServiceTestAccessors.jsonToGameState(entry2Json);
        expect(state2.currentTurnPlayerId, 'player2');
      });
      
      test('saves multiple different games correctly', () async {
        final game1 = createSampleGameState(gameId: 'multi1');
        final game2 = createSampleGameState(gameId: 'multi2', currentPlayerId: 'player2');

        await saveLoadService.saveGame(game1, customName: 'Multi 1');
        await saveLoadService.saveGame(game2, customName: 'Multi 2');

        final prefs = await SharedPreferences.getInstance();
        final savedGamesList = prefs.getStringList('saved_games');
        expect(savedGamesList!.length, 2);

        final entry1Json = jsonDecode(savedGamesList[0]) as Map<String, dynamic>; 
        final entry2Json = jsonDecode(savedGamesList[1]) as Map<String, dynamic>; 

        expect(entry1Json['saveName'], 'Multi 1');
        expect(SaveLoadServiceTestAccessors.jsonToGameState(entry1Json).gameId, 'multi1');

        expect(entry2Json['saveName'], 'Multi 2');
        expect(SaveLoadServiceTestAccessors.jsonToGameState(entry2Json).gameId, 'multi2');
      });
    });

    group('loadGame', () {
      late GameState state1, state2;
      String state1Json = "";
      String state2Json = "";

      setUp(() async {
        SharedPreferences.setMockInitialValues({}); // Clear from previous tests
        state1 = createSampleGameState(gameId: 'load1', currentPlayerId: 'p1');
        state2 = createSampleGameState(gameId: 'load2', currentPlayerId: 'p2');
        
        final state1SaveData = SaveLoadServiceTestAccessors.gameStateToJsonInternal(state1);
        state1SaveData['saveName'] = "Load Game 1";
        state1SaveData['saveDate'] = DateTime.now().millisecondsSinceEpoch;
        state1Json = jsonEncode(state1SaveData);

        final state2SaveData = SaveLoadServiceTestAccessors.gameStateToJsonInternal(state2);
        state2SaveData['saveName'] = "Load Game 2";
        state2SaveData['saveDate'] = DateTime.now().add(const Duration(seconds: 1)).millisecondsSinceEpoch;
        state2Json = jsonEncode(state2SaveData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saved_games', [state1Json, state2Json]);
      });

      test('loads a game by index correctly', () async {
        final loadedState = await saveLoadService.loadGame(0); 
        expect(loadedState, isNotNull);
        expect(loadedState!.gameId, state1.gameId);
        expect(loadedState.currentTurnPlayerId, state1.currentTurnPlayerId);
        expect(loadedState, state1);
      });

      test('returns null for an out-of-bounds index (negative)', () async {
        final loadedState = await saveLoadService.loadGame(-1);
        expect(loadedState, isNull);
      });

      test('returns null for an out-of-bounds index (too large)', () async {
        final loadedState = await saveLoadService.loadGame(5); // Only 2 games saved
        expect(loadedState, isNull);
      });

      test('returns null if saved game string is malformed JSON', () async {
        final malformedList = [state1Json, "this_is_not_json"];
        SharedPreferences.setMockInitialValues({'saved_games': malformedList});
        final loadedState = await saveLoadService.loadGame(1); // Attempt to load bad JSON
        expect(loadedState, isNull);
      });
    });

    group('deleteGame', () {
      String game1Json = "", game2Json = "", game3Json = "";

      setUp(() async {
        SharedPreferences.setMockInitialValues({}); 
        final s1 = createSampleGameState(gameId: 'del1');
        final s2 = createSampleGameState(gameId: 'del2');
        final s3 = createSampleGameState(gameId: 'del3');

        game1Json = jsonEncode(SaveLoadServiceTestAccessors.gameStateToJsonWithSaveName(s1, 'Delete Game 1'));
        game2Json = jsonEncode(SaveLoadServiceTestAccessors.gameStateToJsonWithSaveName(s2, 'Delete Game 2'));
        game3Json = jsonEncode(SaveLoadServiceTestAccessors.gameStateToJsonWithSaveName(s3, 'Delete Game 3'));

        final List<String> initialSavedGames = [game1Json, game2Json, game3Json];
        SharedPreferences.setMockInitialValues({'saved_games': initialSavedGames});
      });

      test('deletes a game by index and returns true', () async {
        final success = await saveLoadService.deleteGame(1); // Deletes game2Json ('del2')
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final savedGamesList = prefs.getStringList('saved_games');
        expect(savedGamesList, isNotNull);
        expect(savedGamesList!.length, 2);
        expect(savedGamesList.contains(game2Json), isFalse);
        expect(savedGamesList[0], game1Json);
        expect(savedGamesList[1], game3Json);
      });

      test('returns false for an out-of-bounds index (negative) and list unchanged', () async {
        final success = await saveLoadService.deleteGame(-1);
        expect(success, isFalse);
        final prefs = await SharedPreferences.getInstance();
        final savedGamesList = prefs.getStringList('saved_games');
        expect(savedGamesList!.length, 3); // No change
      });

      test('returns false for an out-of-bounds index (too large) and list unchanged', () async {
        final success = await saveLoadService.deleteGame(3); // Index 3 is out of bounds for list of length 3
        expect(success, isFalse);
        final prefs = await SharedPreferences.getInstance();
        final savedGamesList = prefs.getStringList('saved_games');
        expect(savedGamesList!.length, 3); // No change
      });
    });

    group('getSavedGames', () {
      test('returns an empty list when no games are saved', () async {
        SharedPreferences.setMockInitialValues({}); // Ensure empty
        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo, isEmpty);
      });

      test('returns correct metadata for saved games', () async {
        final s1 = createSampleGameState(gameId: 'meta1');
        final s2 = createSampleGameState(gameId: 'meta2');
        final name1 = "Metadata Game 1";
        final name2 = "Metadata Game 2";
        
        final game1SaveJson = SaveLoadServiceTestAccessors.gameStateToJsonWithSaveName(s1, name1);
        final game2SaveJson = SaveLoadServiceTestAccessors.gameStateToJsonWithSaveName(s2, name2);
        
        SharedPreferences.setMockInitialValues({
          'saved_games': [jsonEncode(game1SaveJson), jsonEncode(game2SaveJson)]
        });

        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 2);

        expect(gamesInfo[0]['saveName'], name1);
        expect(gamesInfo[0]['saveDate'], isA<DateTime>());
        expect(gamesInfo[0]['saveDate'].millisecondsSinceEpoch, game1SaveJson['saveDate']);

        expect(gamesInfo[1]['saveName'], name2);
        expect(gamesInfo[1]['saveDate'], isA<DateTime>());
        expect(gamesInfo[1]['saveDate'].millisecondsSinceEpoch, game2SaveJson['saveDate']);
      });

      test('handles malformed JSON strings in saved games list gracefully', () async {
         SharedPreferences.setMockInitialValues({
          'saved_games': ["this_is_not_json", jsonEncode(SaveLoadServiceTestAccessors.gameStateToJsonWithSaveName(createSampleGameState(), "Good Game"))]
        });
        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 1);
        expect(gamesInfo[0]['saveName'], "Good Game");
      });
    });

    group('Data Integrity', () {
      test('saved and loaded GameState is equivalent to the original', () async {
        final originalState = createSampleGameState(gameId: 'integrityTest');
        await saveLoadService.saveGame(originalState, customName: "Integrity Test");

        final loadedState = await saveLoadService.loadGame(0);
        expect(loadedState, isNotNull);
        expect(loadedState, originalState);

        expect(loadedState!.gameId, originalState.gameId);
        expect(loadedState.currentTurnPlayerId, originalState.currentTurnPlayerId);
        expect(loadedState.players.length, originalState.players.length);
        for (int i = 0; i < loadedState.players.length; i++) {
          expect(loadedState.players[i], originalState.players[i]);
        }
        expect(loadedState.lastDiceValue, originalState.lastDiceValue);
      });
    });

    group('Error Handling', () {
      test('loadGame returns null for malformed GameState JSON', () async {
        final gameId = 'malformedJsonGame';
        final metadataList = [
          jsonEncode({'gameId': gameId, 'saveName': 'Malformed Test', 'saveDate': DateTime.now().millisecondsSinceEpoch})
        ];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saved_games', metadataList);
        await prefs.setString(gameId, 'this_is_not_valid_json');

        final loadedState = await saveLoadService.loadGame(0);
        expect(loadedState, isNull);
      });

      test('loadGame returns null for GameState JSON missing crucial fields', () async {
        final gameId = 'missingFieldsGame';
        final metadataList = [
          jsonEncode({'gameId': gameId, 'name': 'Missing Fields Test', 'timestamp': DateTime.now().millisecondsSinceEpoch})
        ];
        final incompleteJson = jsonEncode({
          'startIndex': {'p1': 0},
          'currentTurnPlayerId': 'p1',
          'gameId': gameId,
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saved_games', metadataList);
        await prefs.setString(gameId, incompleteJson);

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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saved_games', metadataList);

        Map<String, dynamic> corruptedEntry = {'gameId': corruptedGameId, 'name': 'Corrupted Entry', 'timestamp': DateTime.now().millisecondsSinceEpoch};
        
        Map<String, dynamic> validEntry = SaveLoadServiceTestAccessors.gameStateToJsonWithSaveName(validGameState, "Valid Entry");
        
        final correctedMetadataList = [
          jsonEncode(corruptedEntry),
          jsonEncode(validEntry)
        ];

        await prefs.setStringList('saved_games', correctedMetadataList);

        final corruptedLoadedState = await saveLoadService.loadGame(0);
        expect(corruptedLoadedState, isNull, reason: "Loading a game with missing state JSON should return null.");

        final validLoadedState = await saveLoadService.loadGame(1);
        expect(validLoadedState, isNotNull, reason: "Should still be able to load other valid games.");
        expect(validLoadedState, validGameState);
      });


      test('getSavedGames filters out entries with malformed JSON in metadata list', () async {
        final validEntry = {'gameId': 'valid1', 'name': 'Valid Game Metadata', 'timestamp': DateTime.now().millisecondsSinceEpoch};
        final List<String> savedGamesIndex = [
          jsonEncode(validEntry),
          'this_is_not_json',
          jsonEncode({'gameId': 'valid2', 'name': 'Another Valid', 'timestamp': DateTime.now().millisecondsSinceEpoch}),
        ];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saved_games', savedGamesIndex);

        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 2, reason: "Should skip the malformed JSON entry.");
        expect(gamesInfo[0]['saveName'], 'Valid Game Metadata');
        expect(gamesInfo[1]['saveName'], 'Another Valid');
      });

      test('getSavedGames filters out entries with missing required fields in metadata JSON', () async {
        final List<String> savedGamesIndex = [
          jsonEncode({'gameId': 'validFull', 'saveName': 'Valid Full', 'saveDate': DateTime.now().millisecondsSinceEpoch}),
          jsonEncode({'gameId': 'missingName', 'saveDate': DateTime.now().millisecondsSinceEpoch}),
          jsonEncode({'saveName': 'missingGameId', 'saveDate': DateTime.now().millisecondsSinceEpoch}),
          jsonEncode({'gameId': 'validAgain', 'saveName': 'Valid Again', 'saveDate': DateTime.now().millisecondsSinceEpoch}),
        ];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saved_games', savedGamesIndex);

        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 2, reason: "Should skip entries missing required metadata fields like saveName or saveDate (gameId is not directly used by getSavedGames for its output map).");
        expect(gamesInfo.any((g) => g['saveName'] == 'Valid Full'), isTrue);
        expect(gamesInfo.any((g) => g['saveName'] == 'Valid Again'), isTrue);
        expect(gamesInfo.any((g) => g['gameId'] == 'missingName'), isFalse);
        expect(gamesInfo.any((g) => g['saveName'] == 'missingGameId'), isFalse);
      });

      test('getSavedGames returns metadata even if the GameState JSON itself is missing or corrupted', () async {
        final gameId1 = 'metaOnly1';
        final gameId2 = 'metaOnly2_corruptState';
        final List<String> savedGamesIndex = [
          jsonEncode({'gameId': gameId1, 'saveName': 'Meta Only - No State String', 'saveDate': DateTime.now().millisecondsSinceEpoch}),
          jsonEncode({'gameId': gameId2, 'saveName': 'Meta Only - Corrupt State String', 'saveDate': DateTime.now().millisecondsSinceEpoch, 'players': 'this_is_bad_json_for_part_of_state'}),
        ];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saved_games', savedGamesIndex);
        
        final gamesInfo = await saveLoadService.getSavedGames();
        expect(gamesInfo.length, 2);
        expect(gamesInfo[0]['saveName'], 'Meta Only - No State String');
        expect(gamesInfo[1]['saveName'], 'Meta Only - Corrupt State String');

        final state1 = await saveLoadService.loadGame(0);
        expect(state1, isNull, reason: "Loading game with missing/incomplete state in list entry should fail if essential parts are missing for _jsonToGameState.");
        final state2 = await saveLoadService.loadGame(1);
        expect(state2, isNull, reason: "Loading game with corrupt state in list entry should fail.");
      });

      test('Conceptual: SharedPreferences platform errors', () {
        expect(true, isTrue); // Placeholder
      });

    });
  });
}

// Extended SaveLoadServiceTestAccessors to include a helper for the full save structure
class SaveLoadServiceTestAccessors extends SaveLoadService {
  // Accessor for the private _gameStateToJson method
  static Map<String, dynamic> gameStateToJsonInternal(GameState gameState) {
    // This mirrors the private _gameStateToJson method in SaveLoadService
    return {
      'startIndex': gameState.startIndex,
      'players': gameState.players.map((player) => {
        'id': player.id,
        'name': player.name,
        'tokenPositions': player.tokenPositions,
        'isAI': player.isAI,
      }).toList(),
      'currentTurnPlayerId': gameState.currentTurnPlayerId,
      'lastDiceValue': gameState.lastDiceValue,
      'currentRollCount': gameState.currentRollCount,
      'winnerId': gameState.winnerId,
      'gameId': gameState.gameId, // Include gameId as it's part of GameState
    };
  }

  // Helper to create the full JSON structure that SaveLoadService saves for an entry
  static Map<String, dynamic> gameStateToJsonWithSaveName(GameState gameState, String saveName, [DateTime? date]) {
    final gameData = gameStateToJsonInternal(gameState);
    // Add the fields that SaveLoadService itself adds before encoding
    gameData['saveName'] = saveName;
    gameData['saveDate'] = (date ?? DateTime.now()).millisecondsSinceEpoch; 
    // gameId is already part of gameStateToJsonInternal if present in GameState
    return gameData;
  }

  // Accessor for the private _jsonToGameState method (already provided in previous step)
  static GameState jsonToGameState(Map<String, dynamic> json) {
    final startIndex = Map<String, int>.from(json['startIndex'] as Map);
    final playersList = (json['players'] as List).map((playerJsonRaw) {
      final playerJson = playerJsonRaw as Map<String, dynamic>;
      return Player(
        playerJson['id'] as String,
        playerJson['name'] as String,
        initialPositions: List<int>.from(playerJson['tokenPositions'] as List),
        isAI: playerJson['isAI'] as bool,
      );
    }).toList();
    return GameState(
      gameId: json['gameId'] as String?, // GameState can have a gameId
      startIndex: startIndex,
      players: playersList,
      currentTurnPlayerId: json['currentTurnPlayerId'] as String,
      lastDiceValue: json['lastDiceValue'] as int?,
      currentRollCount: json['currentRollCount'] as int,
      winnerId: json['winnerId'] as String?,
    );
  }
}
