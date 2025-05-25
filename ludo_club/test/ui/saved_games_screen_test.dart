import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
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
  late GameState _internalState;

  MockGameService(GameState initialState) : _internalState = initialState;

  @override
  GameState get state => _internalState;

  // startGame is NOT part of GameService. GameProvider handles new game setup.

  @override
  int rollDice() {
    final diceResult = (_internalState.lastDiceValue ?? 0) % 6 + 1;
    var newState = _internalState.copy();
    newState.lastDiceValue = diceResult;
    newState.currentRollCount = (_internalState.currentRollCount ?? 0) + 1;
    _internalState = newState;
    return diceResult;
  }

  @override
  String? moveToken(String playerId, int tokenIndex, int targetPosition) {
    // Simplified mock, can be expanded if needed by tests
    var newState = _internalState.copy();
    final playerIndex = newState.players.indexWhere((p) => p.id == playerId);
    if (playerIndex != -1) {
      final newPositions = List<int>.from(newState.players[playerIndex].tokenPositions);
      newPositions[tokenIndex] = targetPosition;
      newState.players[playerIndex] = Player(
        newState.players[playerIndex].id,
        newState.players[playerIndex].name,
        initialPositions: newPositions,
        isAI: newState.players[playerIndex].isAI,
      );
    }
    if (newState.players.isNotEmpty) {
        final currentPlayerIdx = newState.players.indexWhere((p) => p.id == playerId);
        if (currentPlayerIdx != -1) {
            newState.currentTurnPlayerId = newState.players[(currentPlayerIdx + 1) % newState.players.length].id;
        }
    }
    newState.lastDiceValue = null;
    newState.currentRollCount = 0;
    _internalState = newState;
    return null;
  }

  @override
  List<Map<String, int>> getPossibleMoveDetails() {
    return []; // Placeholder
  }

  @override
  List<int> getPossibleMoves() {
    return []; // Placeholder
  }

  @override
  void makeAIMove() {}
}

class MockAudioService extends Mock implements AudioService {
  bool _soundEnabled = true;
  @override
  bool get isSoundEnabled => _soundEnabled; // Corrected name
  @override
  Future<void> init() async {}
  @override
  Future<void> playDiceSound() async {} // Corrected name & return type
  @override
  Future<void> playMoveSound() async {} // Corrected name & return type
  @override
  Future<void> playCaptureSound() async {} // Added & return type
  @override
  Future<void> playVictorySound() async {} // Added & return type
  @override
  Future<void> playFinishSound() async {} // Added
  @override
  void setSoundEnabled(bool enabled) { _soundEnabled = enabled; }
  @override
  void setVolume(double volume) {}
  @override
  double get volume => 1.0; // Added
  @override
  Future<void> dispose() async {} // Added
}

class MockSaveLoadService extends Mock implements SaveLoadService {
  List<Map<String, dynamic>> _savedGamesMetadata = [];
  Map<String, GameState> _savedGameStates = {};
  bool _deleteShouldFail = false; // Add a flag
  int? _failDeleteAtIndex;      // Optionally, make it index-specific

  void setSavedGamesForTest(List<Map<String, dynamic>> metadata, Map<String, GameState> states) {
    _savedGamesMetadata = List.from(metadata);
    _savedGameStates = Map.from(states);
    _deleteShouldFail = false; // Reset flag
    _failDeleteAtIndex = null; // Reset index specific flag
  }

  // Helper to make deleteGame fail for the next call or specific index
  void setDeleteGameToFail({bool fail = true, int? atIndex}){
      _deleteShouldFail = fail;
      _failDeleteAtIndex = atIndex;
  }

  @override
  Future<List<Map<String, dynamic>>> getSavedGames() async {
    print("MockSaveLoadService: getSavedGames called, returning ${_savedGamesMetadata.length} items.");
    return Future.value(List.from(_savedGamesMetadata));
  }

  @override
  Future<GameState?> loadGame(int index) async {
    if (index < 0 || index >= _savedGamesMetadata.length) return null;
    final gameId = _savedGamesMetadata[index]['gameId'] as String?;
    if (gameId == null) return null;
    return Future.value(_savedGameStates[gameId]?.copy());
  }
  
  @override
  Future<bool> deleteGame(int index) async {
    if (_deleteShouldFail && (_failDeleteAtIndex == null || _failDeleteAtIndex == index)) {
        print("MockSaveLoadService: deleteGame called for index $index, failing as instructed.");
        return Future.value(false); // Fail as instructed
    }
    print("MockSaveLoadService: deleteGame called for index $index, proceeding with deletion.");
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
    final gameId = state.gameId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final name = customName ?? 'Game ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
    final metadata = {
      'gameId': gameId,
      'saveName': name, // Changed from 'name' to 'saveName' to match SaveLoadService
      'saveDate': DateTime.now().millisecondsSinceEpoch, // Changed from 'timestamp'
      'playerNames': state.players.map((p) => p.name).toList() // Often useful in display
    };
    
    _savedGamesMetadata.removeWhere((m) => m['gameId'] == gameId);
    _savedGamesMetadata.insert(0, metadata);
    _savedGameStates[gameId] = state.copy();
    return true;
  }

  @override
  Future<void> deleteAllGames() async {
    _savedGamesMetadata.clear();
    _savedGameStates.clear();
  }
}

// TestGameProvider to allow spying on method calls or overriding behavior
class TestGameProvider extends GameProvider {
  bool loadGameCalled = false;
  int? loadGameIndex;
  bool deleteGameCalled = false;
  int? deleteGameIndex;

  final MockGameService _testGameService;
  final MockSaveLoadService _testSaveLoadService;

  TestGameProvider({
    required MockGameService gameService,
    required MockSaveLoadService saveLoadService,
    required GameState initialState,
  })  : _testGameService = gameService,
        _testSaveLoadService = saveLoadService,
        super(initialState);

  GameState get currentTestState => _testGameService.state;

  @override
  Future<List<Map<String, dynamic>>> getSavedGames() async {
    return _testSaveLoadService.getSavedGames();
  }

  @override
  Future<bool> loadGame(int index) async {
    loadGameCalled = true;
    loadGameIndex = index;
    final loadedState = await _testSaveLoadService.loadGame(index);
    if (loadedState != null) {
      _testGameService._internalState = loadedState;
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  Future<bool> deleteGame(int index) async {
    deleteGameCalled = true;
    deleteGameIndex = index;
    final success = await _testSaveLoadService.deleteGame(index);
    if (success) {
      notifyListeners();
    }
    return success;
  }

  @override
  void startNewGame(List<Player> players) {
    Map<String, int> startIndices = {};
    List<Player> newGamePlayers = [];
    for(int i=0; i < players.length; i++){
        String pId = players[i].id;
        startIndices[pId] = i * 13;
        newGamePlayers.add(Player(
            pId,
            players[i].name,
            initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition),
            isAI: players[i].isAI
        ));
    }
    final newInitialState = GameState(
      players: newGamePlayers,
      startIndex: startIndices,
      currentTurnPlayerId: newGamePlayers.first.id,
      gameId: 'newGameFromTestProv${DateTime.now().millisecondsSinceEpoch}',
      lastDiceValue: 0,
      currentRollCount: 0,
    );
    _testGameService._internalState = newInitialState;
    notifyListeners();
  }

  @override
  Future<int> rollDice() async {
    final result = _testGameService.rollDice();
    notifyListeners();
    return result;
  }

  @override
  Future<void> moveToken(int tokenIndex, int targetPosition) async {
    _testGameService.moveToken(_testGameService.state.currentTurnPlayerId, tokenIndex, targetPosition);
    notifyListeners();
  }

  @override
  List<Map<String, int>> getPossibleMoveDetails() {
    return _testGameService.getPossibleMoveDetails();
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

// Helper function to create a default GameState for initializing mocks if needed
GameState createInitialTestStateForProvider() {
  return GameState(
    players: [Player('pInitProv', 'Initial Provider Player', isAI: false, initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition))],
    startIndex: {'pInitProv': 0},
    currentTurnPlayerId: 'pInitProv',
    gameId: 'defaultInitialStateForProviderSavedGames',
  );
}

// Helper function to create the widget tree for SavedGamesScreen tests
Widget createSavedGamesScreenWrapped(TestGameProvider provider, MockNavigatorObserver navigatorObserver) {
  return ChangeNotifierProvider<GameProvider>.value(
    value: provider,
    child: MaterialApp(
      home: SavedGamesScreen(),
      navigatorObservers: [navigatorObserver],
      routes: { // For navigation testing if loading pushes to GameScreen
        '/game': (context) => GameScreen(),
      },
    ),
  );
}

void main() {
  late TestGameProvider gameProvider;
  late MockGameService mockGameService;
  late MockSaveLoadService mockSaveLoadService;
  late MockNavigatorObserver mockNavigatorObserver;

  final List<Map<String, dynamic>> sampleSavedGamesMetadata = [
    {'gameId': 'game1', 'saveName': 'First Game', 'saveDate': DateTime(2023, 1, 1, 10, 0).millisecondsSinceEpoch, 'playerNames': ['P1']},
    {'gameId': 'game2', 'saveName': 'Second Game', 'saveDate': DateTime(2023, 1, 2, 12, 30).millisecondsSinceEpoch, 'playerNames': ['P1']},
    {'gameId': 'game3', 'saveName': 'Third Game', 'saveDate': DateTime(2023, 1, 3, 15, 45).millisecondsSinceEpoch, 'playerNames': ['P1']},
  ];

  final sampleGameState1 = GameState(
      gameId: 'game1', 
      players: [Player('p1', 'P1', isAI: false, initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition))],
      startIndex: {'p1':0}, 
      currentTurnPlayerId: 'p1'
  );
  final sampleGameState2 = GameState(
      gameId: 'game2', 
      players: [Player('p1', 'P1', isAI: false, initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition))],
      startIndex: {'p1':0}, 
      currentTurnPlayerId: 'p1'
  );
  final sampleGameState3 = GameState(
      gameId: 'game3', 
      players: [Player('p1', 'P1', isAI: false, initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition))],
      startIndex: {'p1':0}, 
      currentTurnPlayerId: 'p1'
  );

  final Map<String, GameState> sampleSavedStates = {
    'game1': sampleGameState1,
    'game2': sampleGameState2,
    'game3': sampleGameState3,
  };

  setUp(() {
    final initialProviderState = createInitialTestStateForProvider();
    mockGameService = MockGameService(initialProviderState);
    mockSaveLoadService = MockSaveLoadService();
    mockNavigatorObserver = MockNavigatorObserver();

    gameProvider = TestGameProvider(
      gameService: mockGameService,
      saveLoadService: mockSaveLoadService,
      initialState: mockGameService.state, // Use state from the mockGameService
    );
  });

  group('SavedGamesScreen', () {
    group('Display Saved Games', () {
      testWidgets('displays list of saved games with correct data', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesForTest(sampleSavedGamesMetadata, sampleSavedStates);
        await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
        await tester.pumpAndSettle(); // Allow FutureBuilder in SavedGamesScreen to complete

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(sampleSavedGamesMetadata.length));

        for (int i = 0; i < sampleSavedGamesMetadata.length; i++) {
          final item = sampleSavedGamesMetadata[i];
          expect(find.text(item['saveName'] as String), findsOneWidget);
          final formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(item['saveDate'] as int));
          expect(find.text(formattedDate), findsOneWidget);
          expect(find.byIcon(Icons.delete), findsNWidgets(sampleSavedGamesMetadata.length));
        }
      });

      testWidgets('displays "No saved games" message when list is empty', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesForTest([], {}); // No games
        await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsNothing);
        expect(find.text('Keine gespeicherten Spiele gefunden.'), findsOneWidget);
      });

      testWidgets('displays loading indicator initially', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesForTest([], {}); // No games
        await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
        // Don't call pumpAndSettle immediately, check for loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle(); // Now let it complete
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('Load Game Functionality', () {
      testWidgets('tapping a game item calls GameProvider.loadGame and navigates back', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesForTest(sampleSavedGamesMetadata, sampleSavedStates);
        await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
        await tester.pumpAndSettle();

        expect(gameProvider.loadGameCalled, isFalse);
        mockNavigatorObserver.reset();

        // Tap the first game item ("First Game")
        await tester.tap(find.text('First Game'));
        await tester.pumpAndSettle(); // Process tap and potential navigation/state changes

        expect(gameProvider.loadGameCalled, isTrue);
        expect(gameProvider.loadGameIndex, 0); // "First Game" is at index 0 in sampleSavedGamesMetadata
        
        // Check if Navigator.pop was called (SavedGamesScreen should pop after loading)
        expect(mockNavigatorObserver.popCalled, isTrue);
        // Optionally, if it navigates to GameScreen instead of just popping:
        // expect(mockNavigatorObserver.pushedRoute?.settings.name, '/game');
      });

      testWidgets('shows error if loading fails (e.g., game state not found)', (WidgetTester tester) async {
        // Game metadata exists, but GameState itself won't be found by mock SaveLoadService
        mockSaveLoadService.setSavedGamesForTest([], {}); // No games

        await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
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
        mockSaveLoadService.setSavedGamesForTest(sampleSavedGamesMetadata, sampleSavedStates);
        await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
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
        mockSaveLoadService.setSavedGamesForTest([], {}); // No games
        await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsNothing);
        expect(find.text('Keine gespeicherten Spiele gefunden.'), findsOneWidget);
      });

      testWidgets('item is not removed if GameProvider.deleteGame returns false', (WidgetTester tester) async {
        mockSaveLoadService.setSavedGamesForTest(List.from(sampleSavedGamesMetadata), Map.from(sampleSavedStates));
        
        // Instruct the mock SaveLoadService to make the deleteGame call fail for index 0
        mockSaveLoadService.setDeleteGameToFail(fail: true, atIndex: 0);

        await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
        await tester.pumpAndSettle();
        
        expect(find.byType(ListTile), findsNWidgets(3));
        await tester.tap(find.byIcon(Icons.delete).first); // Taps delete for the first item (index 0)
        await tester.pumpAndSettle();

        expect(gameProvider.deleteGameCalled, isTrue);
        expect(gameProvider.deleteGameIndex, 0);
        expect(find.byType(ListTile), findsNWidgets(3)); // Item should still be there
        expect(find.text('First Game'), findsOneWidget);
        
        // Check for an error message (e.g., SnackBar displayed by SavedGamesScreen)
        // This depends on how SavedGamesScreen handles the delete failure from GameProvider
        expect(find.text('Failed to delete game.'), findsOneWidget); // Assuming SavedGamesScreen shows this
      });
    });

    testWidgets('loads a game and navigates to GameScreen', (WidgetTester tester) async {
      mockSaveLoadService.setSavedGamesForTest(sampleSavedGamesMetadata, sampleSavedStates);
      await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
      await tester.pumpAndSettle();

      expect(find.text('First Game'), findsOneWidget);
      await tester.tap(find.text('First Game'));
      await tester.pumpAndSettle(); // Allow navigation to process

      expect(gameProvider.loadGameCalled, isTrue);
      expect(gameProvider.loadGameIndex, 0);
      expect(mockNavigatorObserver.pushedRoute, isNotNull);
      expect(mockNavigatorObserver.pushedRoute!.settings.name, '/game');
      expect(find.byType(GameScreen), findsOneWidget);
      // Verify that the game state in the provider was updated
      expect(gameProvider.currentTestState.gameId, 'game1');
    });

    testWidgets('Delete button removes a game and updates UI', (WidgetTester tester) async {
      mockSaveLoadService.setSavedGamesForTest(List.from(sampleSavedGamesMetadata), Map.from(sampleSavedStates)); // Use copies
      await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
      await tester.pumpAndSettle();

      expect(find.text('Second Game'), findsOneWidget);
      // Find delete icon for the second game (index 1)
      final deleteIcons = find.byIcon(Icons.delete);
      expect(deleteIcons, findsNWidgets(sampleSavedGamesMetadata.length));
      await tester.tap(deleteIcons.at(1)); // Tap delete for 'Second Game'
      await tester.pumpAndSettle(); // Rebuild after delete

      expect(gameProvider.deleteGameCalled, isTrue);
      expect(gameProvider.deleteGameIndex, 1);
      expect(find.text('Second Game'), findsNothing); // Game should be gone from UI
      expect(find.byType(ListTile), findsNWidgets(sampleSavedGamesMetadata.length - 1));
      // Verify it's gone from the mock service too
      final gamesAfterDelete = await mockSaveLoadService.getSavedGames();
      expect(gamesAfterDelete.any((g) => g['gameId'] == 'game2'), isFalse);
    });

    testWidgets('Back button navigates back (conceptual - actual pop)', (WidgetTester tester) async {
      await tester.pumpWidget(createSavedGamesScreenWrapped(gameProvider, mockNavigatorObserver));
      await tester.pumpAndSettle();

      // Find the back button (usually a leading IconButton in AppBar)
      final backButton = find.byTooltip('Back'); // Or find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(mockNavigatorObserver.popCalled, isTrue);
    });
  });
}
