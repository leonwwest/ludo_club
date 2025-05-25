import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/models/player.dart';
import 'package:ludo_club/services/save_load_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Needed for SharedPreferences

  group('SaveLoadService', () {
    late SaveLoadService saveLoadService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      // Use mock values for SharedPreferences
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      saveLoadService = SaveLoadService(prefs: sharedPreferences);
    });

    // Helper to create a simple GameState for testing
    GameState createSampleGameState() {
      return GameState(
        players: [Player(PlayerColor.red, 'Test Player')],
        currentPlayerIndex: 0,
        diceRoll: 0,
        isGameOver: false,
        winner: '',
        rolledSix: false,
      );
    }

    test('saveGameState saves the game state correctly', () async {
      final gameState = createSampleGameState();
      const slotName = 'test_slot_save';

      await saveLoadService.saveGameState(gameState, slotName);

      final savedData = sharedPreferences.getString('gameState_$slotName');
      expect(savedData, isNotNull);
      // Optionally, deserialize and compare with the original gameState
    });

    test('loadGameState loads a saved game state correctly', () async {
      final gameState = createSampleGameState();
      const slotName = 'test_slot_load';
      await saveLoadService.saveGameState(gameState, slotName); // Save a game first

      final loadedGameState = await saveLoadService.loadGameState(slotName);

      expect(loadedGameState, isNotNull);
      expect(loadedGameState!.players.first.name, 'Test Player');
    });

    test('loadGameState returns null for a non-existent slot', () async {
      const slotName = 'non_existent_slot';
      final loadedGameState = await saveLoadService.loadGameState(slotName);
      expect(loadedGameState, isNull);
    });

    test('getSavedGames returns a list of saved game slots', () async {
      await saveLoadService.saveGameState(createSampleGameState(), 'slot1');
      await saveLoadService.saveGameState(createSampleGameState(), 'slot2');

      final savedGames = await saveLoadService.getSavedGames();

      expect(savedGames, contains('slot1'));
      expect(savedGames, contains('slot2'));
      expect(savedGames.length, 2);
    });

    test('deleteGameState removes a game state', () async {
      const slotName = 'test_slot_delete';
      await saveLoadService.saveGameState(createSampleGameState(), slotName); // Save a game first

      await saveLoadService.deleteGameState(slotName);

      final savedData = sharedPreferences.getString('gameState_$slotName');
      expect(savedData, isNull);
      final savedGames = await saveLoadService.getSavedGames();
      expect(savedGames, isNot(contains(slotName)));
    });

    // Test for prefer_const_declarations with map/list literals
    test('uses const for SharedPreferences mock values where possible', () async {
      // Example of setting mock values with a const map
      const initialValues = {'testKey': 'testValue'};
      SharedPreferences.setMockInitialValues(initialValues);
      sharedPreferences = await SharedPreferences.getInstance();
      expect(sharedPreferences.getString('testKey'), 'testValue');
    });
  });
}