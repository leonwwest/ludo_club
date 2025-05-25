import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/providers/game_provider.dart';
import 'package:ludo_club/services/audio_service.dart';
import 'package:ludo_club/services/game_service.dart';
import 'package:ludo_club/services/save_load_service.dart';
import 'package:ludo_club/ui/game_screen.dart';
import 'package:ludo_club/ui/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart' show any, verify, argThat, isA, Mock, NavigatorObserver, captureAny;

// --- Mocks ---

// Replace Mockito mock with a manual mock for NavigatorObserver
class ManualMockNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? pushedRoute;
  Route<dynamic>? previousPushedRoute;
  String? pushedRouteName;
  int pushCallCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoute = route; // This might be null if Flutter calls it with null
    previousPushedRoute = previousRoute;
    pushedRouteName = route.settings.name; // This will fail if route is null
    pushCallCount++;
    print('ManualMockNavigatorObserver.didPush: route = $route, name = ${route.settings.name}, previousRoute = $previousRoute');
    super.didPush(route, previousRoute);
  }

  void reset() {
    pushedRoute = null;
    previousPushedRoute = null;
    pushedRouteName = null;
    pushCallCount = 0;
  }
}

class MockGameService extends Mock implements GameService {
  late GameState _internalState;

  MockGameService(GameState initialState) : _internalState = initialState;

  @override
  GameState get state => _internalState;

  // startGame is NOT part of the actual GameService interface.
  // It's handled by GameProvider creating a new GameState and new GameService.

  @override
  int rollDice() {
    // Simplified mock behavior
    final diceResult = (_internalState.lastDiceValue ?? 0) % 6 + 1;
    var newState = _internalState.copy();
    newState.lastDiceValue = diceResult;
    newState.currentRollCount = (_internalState.currentRollCount ?? 0) + 1;
    _internalState = newState;
    return diceResult;
  }

  @override
  String? moveToken(String playerId, int tokenIndex, int targetPosition) {
    var newState = _internalState.copy();
    final playerIndex = newState.players.indexWhere((p) => p.id == playerId);
    if (playerIndex != -1) {
      final newPositions = List<int>.from(newState.players[playerIndex].tokenPositions);
      newPositions[tokenIndex] = targetPosition;
      // Create a new Player object with updated positions
      newState.players[playerIndex] = Player(
        newState.players[playerIndex].id,
        newState.players[playerIndex].name,
        initialPositions: newPositions,
        isAI: newState.players[playerIndex].isAI,
      );
    }
    // Simplified: advance turn to next player if players list is not empty
    if (newState.players.isNotEmpty) {
        final currentPlayerIdx = newState.players.indexWhere((p) => p.id == playerId);
        if (currentPlayerIdx != -1) {
            newState.currentTurnPlayerId = newState.players[(currentPlayerIdx + 1) % newState.players.length].id;
        }
    }
    newState.lastDiceValue = null; // Reset dice after move
    newState.currentRollCount = 0;
    _internalState = newState;
    return null; // No capture in this simplified mock
  }

  @override
  List<Map<String, int>> getPossibleMoveDetails() {
    // Simplified: return empty list or a fixed move for testing if needed
    return [];
  }
  
  @override
  List<int> getPossibleMoves() { 
      return getPossibleMoveDetails().map((m) => m['targetPosition']!).toList();
  }
  
  @override
  void makeAIMove() {
    // Mock AI move: e.g., pick the first possible move if any
    final moves = getPossibleMoveDetails();
    if (moves.isNotEmpty) {
      final move = moves.first;
      // In a real scenario, this would call moveToken on the current AI player
      // moveToken(_internalState.currentTurnPlayerId, move['tokenIndex']!, move['targetPosition']!);
    }
  }
}

class MockAudioService extends Mock implements AudioService {
  bool _soundEnabled = true;
  @override
  bool get isSoundEnabled => _soundEnabled;
  @override
  Future<void> init() async {}
  @override
  Future<void> playDiceSound() async {}
  @override
  Future<void> playMoveSound() async {}
  @override
  Future<void> playCaptureSound() async {}
  @override
  Future<void> playVictorySound() async {}
  @override
  Future<void> playFinishSound() async {}
  @override
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }
  @override
  void setVolume(double volume) {}
  @override
  double get volume => 1.0;
  @override
  Future<void> dispose() async {}
}

class MockSaveLoadService extends Mock implements SaveLoadService {
 @override
  Future<bool> saveGame(GameState state, {String? customName}) async { return false; }

  @override
  Future<GameState?> loadGame(int index) async {
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getSavedGames() async {
    return [];
  }

  @override
  Future<bool> deleteGame(int index) async { return false; }

  @override
  Future<void> deleteAllGames() async {}
}

class TestGameProvider extends GameProvider {
  bool newGameStarted = false;
  List<Player>? startedPlayersInfo; // Holds the players passed to startNewGame

  // Store the mock GameService instance to interact with its state if needed.
  // GameProvider's _gameService is private, but we can control the one we pass to it
  // if we were to expose GameService for replacement, or we manage the state via this mock.
  MockGameService _testMockGameService;


  TestGameProvider({
    required MockGameService gameService, // Expect our MockGameService
    required GameState initialState,
  }) : _testMockGameService = gameService,
       super(initialState); // GameProvider constructor takes GameState
                            // and creates its own GameService(initialState).
                            // So, super._gameService will be a REAL GameService.
                            // Our _testMockGameService is separate unless we can inject it.
                            // For testing TestGameProvider's methods, we'll ensure they use _testMockGameService

  // To make TestGameProvider use the _testMockGameService for its operations,
  // we'd ideally inject it or ensure its internal _gameService IS _testMockGameService.
  // Since GameProvider(this._gameState) : _gameService = GameService(_gameState);
  // we cannot directly replace super._gameService after construction.
  // We need to ensure that when TestGameProvider's methods like rollDice, moveToken are called,
  // they operate on _testMockGameService.state (or _testMockGameService updates the GameState instance
  // that was passed to super(initialState)).

  // This means the GameState instance must be shared.
  // MockGameService(initialState) will hold 'initialState'.
  // TestGameProvider(gameService: mockService, initialState: mockService.state)
  //   will pass mockService.state to super(). So super._gameState IS mockService._internalState.
  //   And super._gameService will be a new GameService(mockService.state).
  // This is getting complex.

  // Simpler: TestGameProvider overrides GameProvider methods and uses its _testMockGameService
  // to manipulate the shared state, then calls notifyListeners.

  @override
  void startNewGame(List<Player> players) {
    newGameStarted = true;
    startedPlayersInfo = players; // Store players for verification

    // Mimic GameProvider: create a new GameState for the new game
    Map<String, int> startIndices = {};
    List<Player> newGamePlayers = [];
    for(int i=0; i < players.length; i++){
        String pId = players[i].id; // Use provided player ID if available, or generate
        startIndices[pId] = i * 13; // Example start index
        newGamePlayers.add(Player(
            pId,
            players[i].name,
            initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition),
            isAI: players[i].isAI
        ));
    }

    final newInitialState = GameState(
      players: newGamePlayers,
      startIndex: startIndices, // Make sure this aligns with how GameService expects it
      currentTurnPlayerId: newGamePlayers.first.id,
      gameId: 'testNewGame${DateTime.now().millisecondsSinceEpoch}',
      lastDiceValue: 0,
      currentRollCount: 0,
    );

    // The mock service should now operate on this new state.
    _testMockGameService._internalState = newInitialState;
    
    // GameProvider's actual startNewGame re-assigns _gameState and _gameService.
    // We need to achieve a similar update of the state the provider exposes.
    // The simplest way is if TestGameProvider itself re-initializes its super.gameState
    // or if we rely on tests checking _testMockGameService.state.
    // Since GameProvider._gameState is final, we can't reassign it.
    // What GameProvider actually does: this._gameState = newGameState; this._gameService = new GameService(this._gameState);
    // We need a way for TestGameProvider to tell its superclass (GameProvider) to use this new state.
    // This is a limitation of not being able to reassign _gameState.

    // For testing purposes, we'll assume that GameProvider's state will be updated
    // by virtue of _testMockGameService (which methods like rollDice/moveToken will use)
    // operating on the new state, and then we call notifyListeners.
    // The key is that get gameState in GameProvider returns the _gameState that
    // TestGameProvider methods will effectively be operating on via _testMockGameService.

    // For the purpose of this TestGameProvider, we will assume that any method calls
    // like rollDice(), moveToken() on this provider instance will internally use _testMockGameService,
    // which now has the new state. And after that, we notifyListeners.
    // This means TestGameProvider needs to override rollDice, moveToken, etc.
    
    notifyListeners(); 
    print("TestGameProvider: startNewGame called with ${players.length} players. New state ID: ${newInitialState.gameId}");
  }

  // Override other methods from GameProvider to use _testMockGameService
   @override
  Future<int> rollDice() async {
    final result = _testMockGameService.rollDice();
    // The state in _testMockGameService is updated.
    // GameProvider.gameState should reflect this if the GameState instance is shared.
    notifyListeners();
    return result;
  }

  @override
  Future<void> moveToken(int tokenIndex, int targetPosition) async {
    // Assume currentTurnPlayerId is correctly set in _testMockGameService.state
    _testMockGameService.moveToken(_testMockGameService.state.currentTurnPlayerId, tokenIndex, targetPosition);
    notifyListeners();
  }
  
  @override
  List<Map<String, int>> getPossibleMoveDetails() {
    return _testMockGameService.getPossibleMoveDetails();
  }

  // Expose the current state from the mock service for tests to verify
  GameState get currentMockState => _testMockGameService.state;

}


void main() {
  late TestGameProvider mockGameProvider;
  late MockGameService mockGameService;
  late ManualMockNavigatorObserver manualNavigatorObserver; // Use ManualMockNavigatorObserver

  GameState createDefaultTestInitialState() {
    return GameState(
      players: [Player('p1', 'Player 1', initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition),isAI: false)],
      startIndex: {'p1': 0},
      currentTurnPlayerId: 'p1',
      gameId: 'defaultHomeTestState',
      lastDiceValue: 0,
      currentRollCount: 0,
    );
  }

  setUp(() {
    final initialState = createDefaultTestInitialState();
    mockGameService = MockGameService(initialState);
    manualNavigatorObserver = ManualMockNavigatorObserver(); // Instantiate manual mock

    mockGameProvider = TestGameProvider(
      gameService: mockGameService,
      initialState: mockGameService.state,
    );
  });

  Widget createHomeScreenWrapped(TestGameProvider provider, {ManualMockNavigatorObserver? navObserver}) {
    return ChangeNotifierProvider<GameProvider>.value(
      value: provider,
      child: MaterialApp(
        home: HomeScreen(),
        navigatorObservers: navObserver != null ? [navObserver] : [],
        routes: {
          '/game': (context) => Scaffold(appBar: AppBar(title: Text('Game Screen Placeholder'))),
        },
      ),
    );
  }

  group('HomeScreen UI Tests', () {
    testWidgets('renders HomeScreen with essential elements', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreenWrapped(mockGameProvider));

      expect(find.text('Ludo Club'), findsOneWidget); 
      expect(find.byIcon(Icons.settings), findsOneWidget); 
      expect(find.text('Start New Game'), findsOneWidget);
      expect(find.text('Load Game'), findsOneWidget); 
      expect(find.text('Number of Players:'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Player count selection updates UI', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreenWrapped(mockGameProvider));
      expect(find.descendant(of: find.byType(DropdownButton<int>), matching: find.text('2')), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle(); 
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(DropdownButton<int>), matching: find.text('3')), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(DropdownButton<int>), matching: find.text('4')), findsOneWidget);
    });

    testWidgets('"Start New Game" button calls provider and navigates', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreenWrapped(mockGameProvider, navObserver: manualNavigatorObserver));
      manualNavigatorObserver.reset(); // Reset before action
      
      expect(mockGameProvider.newGameStarted, isFalse);

      await tester.tap(find.text('Start New Game'));
      await tester.pumpAndSettle(); 

      expect(mockGameProvider.newGameStarted, isTrue);
      expect(mockGameProvider.startedPlayersInfo?.length, 2);

      expect(manualNavigatorObserver.pushCallCount, 1, reason: "didPush should be called once.");
      // If the error persists, manualNavigatorObserver.pushedRoute would be null.
      // The print statement in didPush will be crucial.
      expect(manualNavigatorObserver.pushedRoute, isNotNull, reason: "Pushed route should not be null.");
      expect(manualNavigatorObserver.pushedRoute, isA<Route<dynamic>>());
      expect(manualNavigatorObserver.pushedRouteName, '/game');
      
      expect(find.text('Game Screen Placeholder'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('"Start New Game" button considers selected player count', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreenWrapped(mockGameProvider, navObserver: manualNavigatorObserver));
      manualNavigatorObserver.reset();

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start New Game'));
      await tester.pumpAndSettle();

      expect(mockGameProvider.newGameStarted, isTrue);
      expect(mockGameProvider.startedPlayersInfo?.length, 4);
      
      expect(manualNavigatorObserver.pushCallCount, 1);
      expect(manualNavigatorObserver.pushedRoute, isNotNull, reason: "Pushed route for 4 players should not be null.");
      expect(manualNavigatorObserver.pushedRoute, isA<Route<dynamic>>());
      expect(manualNavigatorObserver.pushedRouteName, '/game');
      
      expect(find.text('Game Screen Placeholder'), findsOneWidget);
    });

    testWidgets('Settings icon opens settings (conceptual)', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreenWrapped(mockGameProvider));
      // Conceptual, no actual settings dialog to test yet.
    });

    testWidgets('Load Game button navigates to SavedGamesScreen (conceptual)', (WidgetTester tester) async {
      final localNavObserver = ManualMockNavigatorObserver(); // Use manual mock locally
      await tester.pumpWidget(ChangeNotifierProvider<GameProvider>.value(
          value: mockGameProvider,
          child: MaterialApp(
            home: HomeScreen(),
            navigatorObservers: [localNavObserver], 
            routes: {
              '/game': (context) => GameScreen(),
              '/savedGames': (context) => Scaffold(appBar: AppBar(title: Text('Saved Games Screen Placeholder'))),
            },
          ),
        ));
      localNavObserver.reset();

      expect(find.text('Load Game'), findsOneWidget);
      await tester.tap(find.text('Load Game'));
      await tester.pumpAndSettle();
      
      expect(localNavObserver.pushCallCount, 1);
      expect(localNavObserver.pushedRoute, isNotNull, reason: "Pushed route to saved games should not be null.");
      expect(localNavObserver.pushedRoute, isA<Route<dynamic>>());
      expect(localNavObserver.pushedRouteName, '/savedGames');
      expect(find.text('Saved Games Screen Placeholder'), findsOneWidget);
    });
  });
}
