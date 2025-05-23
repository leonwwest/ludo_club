import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/models/player.dart'; // Player is in game_state.dart
import 'package:ludo_club/providers/game_provider.dart';
import 'package:ludo_club/services/audio_service.dart';
import 'package:ludo_club/services/game_service.dart';
import 'package:ludo_club/services/save_load_service.dart';
import 'package:ludo_club/ui/game_screen.dart';
import 'package:ludo_club/ui/saved_games_screen.dart';
import 'package:mockito/mockito.dart'; // Using mockito for basic mocking structure, even if manual
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';


// --- Mocks ---
// Manual Mocks since build_runner is not consistently working

class MockGameService extends Mock implements GameService {
   @override
  GameState startGame({List<Player>? players, String? firstPlayerId}) {
    return GameState(
      players: players ?? [Player('p1', 'Player 1', color: Colors.red)],
      startIndex: {'p1': 0, 'p2': 13},
      pieces: {'p1': [-1,-1,-1,-1], 'p2': [-1,-1,-1,-1]},
      currentTurnPlayerId: firstPlayerId ?? 'p1',
      gameId: 'mockStartGame'
    );
  }
}

class MockAudioService extends Mock implements AudioService {
  bool _soundEnabled = true;
  @override
  bool get soundEnabled => _soundEnabled;
  @override
  Future<void> init() async {}
  @override
  void playDiceRoll() {}
  @override
  void playMove() {}
  @override
  void playCapture() {}
  @override
  void playVictory() {}
  @override
  void setSoundEnabled(bool enabled) { _soundEnabled = enabled; }
  @override
  void setVolume(double volume) {}
}

class MockSaveLoadService extends Mock implements SaveLoadService {
  List<Map<String, dynamic>> _savedGamesMetadata = [];
  Map<String, GameState> _savedGameStates = {}; // gameId -> GameState

  void setSavedGamesMetadata(List<Map<String, dynamic>> metadata) {
    _savedGamesMetadata = metadata;
  }
  
  void setSavedGameState(String gameId, GameState state) {
    _savedGameStates[gameId] = state;
  }

  @override
  Future<List<Map<String, dynamic>>> getSavedGames() async {
    print("MockSaveLoadService: getSavedGames called, returning ${_savedGamesMetadata.length} items.");
    return _savedGamesMetadata;
  }

  @override
  Future<GameState?> loadGame(int index) async {
    if (index < 0 || index >= _savedGamesMetadata.length) return null;
    final gameId = _savedGamesMetadata[index]['gameId'] as String?;
    if (gameId == null) return null;
    return _savedGameStates[gameId];
  }
  
  @override
  Future<bool> deleteGame(int index) async {
     if (index < 0 || index >= _savedGamesMetadata.length) return false;
    final gameId = _savedGamesMetadata[index]['gameId'] as String?;
    if (gameId != null) {
        _savedGameStates.remove(gameId);
    }
    _savedGamesMetadata.removeAt(index);
    return true;
  }

  @override
  Future<bool> saveGame(GameState state, {String? customName}) async {
    // Not directly used by SavedGamesScreen UI tests, but good to have a basic impl.
    final gameId = state.gameId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final name = customName ?? 'Game ${DateTime.now()}';
    final metadata = {'gameId': gameId, 'name': name, 'timestamp': DateTime.now().millisecondsSinceEpoch};
    
    // Remove if exists, add to top
    _savedGamesMetadata.removeWhere((m) => m['gameId'] == gameId);
    _savedGamesMetadata.insert(0, metadata);
    _savedGameStates[gameId] = state;
    return true;
  }
}

// TestGameProvider to allow spying on method calls or overriding behavior
class TestGameProvider extends GameProvider {
  bool loadGameCalled = false;
  int? loadGameIndex;
  bool deleteGameCalled = false;
  int? deleteGameIndex;
  bool navigateBackCalled = false; // For pop navigation

  final MockSaveLoadService _mockSaveLoadService; // Keep a reference

  TestGameProvider({
    required MockGameService gameService,
    required MockAudioService audioService,
    required MockSaveLoadService saveLoadService,
    GameState? initialState,
  })  : _mockSaveLoadService = saveLoadService, // Store it
        super.withServices(
          gameService: gameService,
          audioService: audioService,
          saveLoadService: saveLoadService,
          initialState: initialState ?? gameService.startGame(players: [Player('p1', 'P1', color: Colors.red)]),
        );
  
  // Override to use the mock's data
  @override
  Future<List<Map<String, dynamic>>> getSavedGames() async {
    return _mockSaveLoadService.getSavedGames();
  }

  @override
  Future<bool> loadGame(int index) async {
    loadGameCalled = true;
    loadGameIndex = index;
    final gameState = await _mockSaveLoadService.loadGame(index);
    if (gameState != null) {
      this.gameState = gameState; // Update provider's state
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  Future<bool> deleteGame(int index) async {
    deleteGameCalled = true;
    deleteGameIndex = index;
    final success = await _mockSaveLoadService.deleteGame(index);
    if (success) {
      notifyListeners(); // Important to trigger UI rebuild
    }
    return success;
  }

  // Mock navigation pop
  void mockPop() {
    navigateBackCalled = true;
  }
}

// Mock NavigatorObserver to track navigation events
class MockNavigatorObserver extends NavigatorObserver {
  bool popCalled = false;
  Route<dynamic>? pushedRoute;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCalled = true;
  }
   @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoute = route;
  }

  void reset() {
    popCalled = false;
    pushedRoute = null;
  }
}


void main() {
  late TestGameProvider gameProvider;
  late MockGameService mockGameService;
  late MockAudioService mockAudioService;
  late MockSaveLoadService mockSaveLoadService;
  late MockNavigatorObserver mockNavigatorObserver;

  final List<Map<String, dynamic>> sampleSavedGamesMetadata = [
    {'gameId': 'game1', 'name': 'First Game', 'timestamp': DateTime(2023, 1, 1, 10, 0).millisecondsSinceEpoch},
    {'gameId': 'game2', 'name': 'Second Game', 'timestamp': DateTime(2023, 1, 2, 12, 30).millisecondsSinceEpoch},
    {'gameId': 'game3', 'name': 'Third Game', 'timestamp': DateTime(2023, 1, 3, 15, 45).millisecondsSinceEpoch},
  ];

  // Sample GameState for loading
  final sampleGameState1 = GameState(
      gameId: 'game1', players: [Player('p1', 'P1', color: Colors.red)], startIndex: {'p1':0}, currentTurnPlayerId: 'p1');
  final sampleGameState2 = GameState(
      gameId: 'game2', players: [Player('p1', 'P1', color: Colors.blue)], startIndex: {'p1':0}, currentTurnPlayerId: 'p1');


  setUp(() {
    mockGameService = MockGameService();
    mockAudioService = MockAudioService();
    mockSaveLoadService = MockSaveLoadService();
    mockNavigatorObserver = MockNavigatorObserver();

    // Initialize GameProvider with mock services
    gameProvider = TestGameProvider(
      gameService: mockGameService,
      audioService: mockAudioService,
      saveLoadService: mockSaveLoadService,
      initialState: mockGameService.startGame(), // Provide a default initial state
    );
  });

  Widget createSavedGamesScreen() {
    return ChangeNotifierProvider<GameProvider>.value(
      value: gameProvider,
      child: MaterialApp(
        home: SavedGamesScreen(),
        navigatorObservers: [mockNavigatorObserver],
        routes: { // For navigation testing if loading pushes to GameScreen
          '/game': (context) => GameScreen(),
        },
      ),
    );
  }

  group('SavedGamesScreen', () {
    group('Display Saved Games', () {
      testWidgets('displays list of saved games with correct data', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesMetadata(List.from(sampleSavedGamesMetadata));
        await tester.pumpWidget(createSavedGamesScreen());
        await tester.pumpAndSettle(); // Allow FutureBuilder in SavedGamesScreen to complete

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(sampleSavedGamesMetadata.length));

        for (int i = 0; i < sampleSavedGamesMetadata.length; i++) {
          final item = sampleSavedGamesMetadata[i];
          expect(find.text(item['name'] as String), findsOneWidget);
          // Format timestamp as it's displayed in the app (assuming 'dd.MM.yyyy HH:mm')
          final formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int));
          expect(find.text(formattedDate), findsOneWidget);
          expect(find.byIcon(Icons.delete), findsNWidgets(sampleSavedGamesMetadata.length));
        }
      });

      testWidgets('displays "No saved games" message when list is empty', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesMetadata([]); // Empty list
        await tester.pumpWidget(createSavedGamesScreen());
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsNothing);
        expect(find.text('No saved games found.'), findsOneWidget);
      });

      testWidgets('displays loading indicator initially', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesMetadata([]); // Does not matter for this test
        await tester.pumpWidget(createSavedGamesScreen());
        // Don't call pumpAndSettle immediately, check for loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle(); // Now let it complete
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('Load Game Functionality', () {
      testWidgets('tapping a game item calls GameProvider.loadGame and navigates back', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesMetadata(List.from(sampleSavedGamesMetadata));
        mockSaveLoadService.setSavedGameState('game2', sampleGameState2); // Game to be loaded

        await tester.pumpWidget(createSavedGamesScreen());
        await tester.pumpAndSettle();

        expect(gameProvider.loadGameCalled, isFalse);
        mockNavigatorObserver.reset();

        // Tap the second game item ("Second Game")
        await tester.tap(find.text('Second Game'));
        await tester.pumpAndSettle(); // Process tap and potential navigation/state changes

        expect(gameProvider.loadGameCalled, isTrue);
        expect(gameProvider.loadGameIndex, 1); // "Second Game" is at index 1 in sampleSavedGamesMetadata
        
        // Check if Navigator.pop was called (SavedGamesScreen should pop after loading)
        expect(mockNavigatorObserver.popCalled, isTrue);
        // Optionally, if it navigates to GameScreen instead of just popping:
        // expect(mockNavigatorObserver.pushedRoute?.settings.name, '/game');
      });

      testWidgets('shows error if loading fails (e.g., game state not found)', (WidgetTester tester) async {
        // Game metadata exists, but GameState itself won't be found by mock SaveLoadService
        mockSaveLoadService.setSavedGamesMetadata([sampleSavedGamesMetadata.first]);
        // Do NOT call setSavedGameState for 'game1'

        await tester.pumpWidget(createSavedGamesScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('First Game'));
        await tester.pumpAndSettle(); // For SnackBar or dialog

        expect(gameProvider.loadGameCalled, isTrue);
        expect(gameProvider.loadGameIndex, 0);
        expect(mockNavigatorObserver.popCalled, isFalse); // Should not pop if load failed
        
        // Check for an error message (e.g., SnackBar)
        // This depends on how SavedGamesScreen handles load failure.
        // Assuming a SnackBar:
        expect(find.text('Failed to load game.'), findsOneWidget);
        await tester.pumpAndSettle(); // Ensure SnackBar is gone if it auto-dismisses
      });
    });

    group('Delete Game Functionality', () {
      testWidgets('tapping delete icon calls GameProvider.deleteGame and removes item', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesMetadata(List.from(sampleSavedGamesMetadata));
        await tester.pumpWidget(createSavedGamesScreen());
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsNWidgets(3));
        expect(gameProvider.deleteGameCalled, isFalse);

        // Tap the delete icon for the first game ("First Game")
        // Find the first delete icon
        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle(); // Process tap, dialog, and potential list update

        expect(gameProvider.deleteGameCalled, isTrue);
        expect(gameProvider.deleteGameIndex, 0); // Deleting the first item

        // Item should be removed from UI
        expect(find.byType(ListTile), findsNWidgets(2));
        expect(find.text('First Game'), findsNothing);
        expect(find.text('Second Game'), findsOneWidget); // Others remain
      });

      testWidgets('deleting the only item results in "No saved games"', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesMetadata([sampleSavedGamesMetadata.first]); // Only one game
        await tester.pumpWidget(createSavedGamesScreen());
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsOneWidget);

        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        expect(gameProvider.deleteGameCalled, isTrue);
        expect(find.byType(ListTile), findsNothing);
        expect(find.text('No saved games found.'), findsOneWidget);
      });

      testWidgets('item is not removed if GameProvider.deleteGame returns false', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesMetadata(List.from(sampleSavedGamesMetadata));
        await tester.pumpWidget(createSavedGamesScreen());
        await tester.pumpAndSettle();

        // Make deleteGame return false for the specific call
        gameProvider.deleteGame = (index) async { // Temporarily override provider's method
          gameProvider.deleteGameCalled = true;
          gameProvider.deleteGameIndex = index;
          return false; // Simulate deletion failure
        };
        
        expect(find.byType(ListTile), findsNWidgets(3));
        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        expect(gameProvider.deleteGameCalled, isTrue);
        expect(gameProvider.deleteGameIndex, 0);
        expect(find.byType(ListTile), findsNWidgets(3)); // Item should still be there
        expect(find.text('First Game'), findsOneWidget);
        
        // Check for an error message (e.g., SnackBar)
        expect(find.text('Failed to delete game.'), findsOneWidget);
      });
    });
  });
}
