import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/models/player.dart';
import 'package:ludo_club/providers/game_provider.dart';
import 'package:ludo_club/services/audio_service.dart';
import 'package:ludo_club/services/game_service.dart';
import 'package:ludo_club/services/save_load_service.dart';
import 'package:ludo_club/ui/game_screen.dart';
import 'package:ludo_club/ui/widgets/board_widget.dart';
import 'package:ludo_club/ui/widgets/dice_widget.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

// --- Mocks ---
// Using manual mocks as used in previous test files due to environment issues

class MockGameService extends Mock implements GameService {
  @override
  GameState rollDice(GameState currentState) {
    return currentState.copy(diceRoll: (currentState.diceRoll ?? 0) % 6 + 1, currentRollCount: 1, canRollAgain: false);
  }

  @override
  GameState moveToken(GameState currentState, PossibleMove move) {
    final newPieces = Map<String, List<int>>.from(currentState.pieces);
    String nextPlayerId = currentState.currentTurnPlayerId;
    if (newPieces[currentState.currentTurnPlayerId] != null) {
      newPieces[currentState.currentTurnPlayerId]![move.pieceIndex] = move.newPosition;
      // Simple turn progression for testing purposes
      final currentIndex = currentState.players.indexWhere((p) => p.id == currentState.currentTurnPlayerId);
      nextPlayerId = currentState.players[(currentIndex + 1) % currentState.players.length].id;
    }
    return currentState.copy(pieces: newPieces, diceRoll: null, canRollAgain: false, currentTurnPlayerId: nextPlayerId);
  }
  
  @override
  List<PossibleMove> getPossibleMoves(GameState currentState) {
    if (currentState.diceRoll == null) return [];
    final List<PossibleMove> moves = [];
    final playerPieces = currentState.pieces[currentState.currentTurnPlayerId];
    if (playerPieces != null) {
      for (int i = 0; i < playerPieces.length; i++) {
        if (playerPieces[i] >= 0 && playerPieces[i] < GameService.homeIndexP1) { // Movable if on board and not home
          moves.add(PossibleMove(pieceIndex: i, newPosition: playerPieces[i] + currentState.diceRoll!));
        } else if (playerPieces[i] == -1 && currentState.diceRoll == 6) { // Can move out of base
           moves.add(PossibleMove(pieceIndex: i, newPosition: currentState.startIndex[currentState.currentTurnPlayerId]!, isMoveOutOfBase: true));
        }
      }
    }
    return moves;
  }


  @override
  GameState startGame({List<Player>? players, String? firstPlayerId}) {
    final p = players ?? [Player('p1', 'Player 1', color: Colors.red), Player('p2', 'Player 2', color: Colors.blue)];
    return GameState(
      players: p,
      startIndex: {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39},
      pieces: Map.fromEntries(p.map((player) => MapEntry(player.id, [-1, -1, -1, -1]))),
      currentTurnPlayerId: firstPlayerId ?? p.first.id,
      gameId: 'mockGameScreenInit',
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
  void playDiceRoll() {print("MockAudioService: playDiceRoll called");}
  @override
  void playMove() {print("MockAudioService: playMove called");}
  @override
  void playCapture() {}
  @override
  void playVictory() {}
  @override
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }
  @override
  void setVolume(double volume) {}
}

class MockSaveLoadService extends Mock implements SaveLoadService {
 @override
  Future<void> saveGame(GameState state, String slotName) async {}

  @override
  Future<GameState?> loadGame(String slotName) async {
    return null;
  }

  @override
  Future<List<String>> getSavedGames() async {
    return [];
  }

  @override
  Future<void> deleteGame(String slotName) async {}
}

// TestGameProvider to allow spying on method calls or overriding behavior
class TestGameProvider extends GameProvider {
  bool rollDiceCalled = false;
  bool moveTokenCalled = false;
  PossibleMove? lastMove;

  TestGameProvider({
    required GameService gameService,
    required AudioService audioService,
    required SaveLoadService saveLoadService,
    GameState? initialState,
  }) : super.withServices(
          gameService: gameService,
          audioService: audioService,
          saveLoadService: saveLoadService,
          initialState: initialState ?? gameService.startGame(players: [Player('p1', 'P1', color: Colors.red)]),
        );

  @override
  Future<void> rollDice() async {
    rollDiceCalled = true;
    print("TestGameProvider: rollDice called. Current player: ${gameState.currentTurnPlayerId}, Current dice: ${gameState.diceRoll}");
    await super.rollDice();
    print("TestGameProvider: rollDice finished. Current player: ${gameState.currentTurnPlayerId}, New dice: ${gameState.diceRoll}");
  }

  @override
  Future<void> moveToken(PossibleMove move) async {
    moveTokenCalled = true;
    lastMove = move;
    print("TestGameProvider: moveToken called with piece ${move.pieceIndex} to ${move.newPosition}");
    await super.moveToken(move);
     print("TestGameProvider: moveToken finished. Current player: ${gameState.currentTurnPlayerId}");
  }
}


void main() {
  late TestGameProvider gameProvider;
  late MockGameService mockGameService;
  late MockAudioService mockAudioService;
  late MockSaveLoadService mockSaveLoadService;

  // Helper to create a GameState for tests
  GameState createInitialTestState() {
    final players = [
      Player('p1', 'Player 1', color: Colors.red, isAI: false),
      Player('p2', 'Player 2', color: Colors.green, isAI: false),
    ];
    return GameState(
      players: players,
      startIndex: {'p1': 0, 'p2': 13},
      pieces: {'p1': [-1, 5, 10, GameService.homeIndexP1], 'p2': [-1, -1, -1, -1]}, // p1 has pieces at base, on board, and home
      currentTurnPlayerId: 'p1',
      gameId: 'testGame1',
    );
  }

  setUp(() {
    mockGameService = MockGameService();
    mockAudioService = MockAudioService();
    mockSaveLoadService = MockSaveLoadService();
    
    final initialState = createInitialTestState();
    // Ensure GameService's startGame returns this specific state for consistency if provider calls it.
    when(mockGameService.startGame(players: anyNamed('players'), firstPlayerId: anyNamed('firstPlayerId')))
        .thenReturn(initialState);

    gameProvider = TestGameProvider(
      gameService: mockGameService,
      audioService: mockAudioService,
      saveLoadService: mockSaveLoadService,
      initialState: initialState,
    );
  });

  Widget createGameScreen() {
    return ChangeNotifierProvider<GameProvider>.value(
      value: gameProvider,
      child: MaterialApp(
        home: GameScreen(),
      ),
    );
  }

  group('GameScreen UI Tests', () {
    testWidgets('renders GameScreen with initial elements', (WidgetTester tester) async {
      await tester.pumpWidget(createGameScreen());

      expect(find.byType(BoardWidget), findsOneWidget);
      expect(find.byType(DiceWidget), findsOneWidget);
      expect(find.textContaining('Player 1\'s Turn'), findsOneWidget); // Assuming current player indication
      // Check for player pieces - this is tricky without keys.
      // For now, just check that the board is there, which implies pieces are rendered by BoardWidget.
    });

    testWidgets('tapping dice area calls GameProvider.rollDice()', (WidgetTester tester) async {
      await tester.pumpWidget(createGameScreen());
      
      expect(gameProvider.rollDiceCalled, isFalse);
      
      // Assuming DiceWidget has a tappable area (e.g., the DiceWidget itself or a button within it)
      // If DiceWidget is a simple container, its parent in GameScreen might handle the tap.
      // Let's assume the DiceWidget is the tappable area.
      await tester.tap(find.byType(DiceWidget));
      await tester.pumpAndSettle(); // Allow time for state changes and animations

      expect(gameProvider.rollDiceCalled, isTrue);
      // The dice value should change, check for a text representation if available
      // e.g. if DiceWidget shows "Dice: 3"
      // expect(find.text('Dice: ${gameProvider.gameState.diceRoll}'), findsOneWidget);
    });

    testWidgets('dice value is displayed after roll', (WidgetTester tester) async {
      await tester.pumpWidget(createGameScreen());
      
      // Set a specific return value for rollDice in the mock service for predictable outcome
      final initialGameState = gameProvider.gameState;
      when(mockGameService.rollDice(any))
          .thenReturn(initialGameState.copy(diceRoll: 5, currentRollCount: 1));
      
      await tester.tap(find.byType(DiceWidget));
      await tester.pumpAndSettle();

      // GameProvider's state will be updated. Check if DiceWidget reflects this.
      // This depends on how DiceWidget displays the number. Let's assume it finds text.
      expect(find.text('5'), findsOneWidget); // Assuming DiceWidget displays the number directly
    });

    testWidgets('current player is highlighted or indicated', (WidgetTester tester) async {
      await tester.pumpWidget(createGameScreen());
      expect(find.textContaining('Player 1\'s Turn'), findsOneWidget);

      // Simulate a turn change by directly manipulating provider state for simplicity
      // or by mocking service calls that lead to turn change
      final nextPlayer = gameProvider.gameState.players[1];
      gameProvider.gameState = gameProvider.gameState.copy(currentTurnPlayerId: nextPlayer.id, diceRoll: null);
      await tester.pumpAndSettle(); // Re-render with new state

      expect(find.textContaining('Player 2\'s Turn'), findsOneWidget);
    });

    // Token interaction tests are complex without specific Keys or more details on BoardWidget's rendering.
    // Conceptual test for tapping a piece:
    testWidgets('tapping a movable piece shows options or calls moveToken (conceptual)', (WidgetTester tester) async {
      await tester.pumpWidget(createGameScreen());

      // 1. Roll dice to get a dice value
      gameProvider.gameState = gameProvider.gameState.copy(diceRoll: 3, currentTurnPlayerId: 'p1');
      // P1 has a piece at 5. With dice 3, can move to 8.
      // P1 also has piece at 10. With dice 3, can move to 13.
      // Mock getPossibleMoves to return a specific move for piece at index 1 (value 5)
      final pieceToMove = gameProvider.gameState.pieces['p1']![1]; // piece at field 5
      final expectedNewPos = pieceToMove + 3;
      final possibleMove = PossibleMove(pieceIndex: 1, newPosition: expectedNewPos);
      
      // Update provider's internal state to simulate a dice roll having occurred.
      gameProvider.gameState = gameProvider.gameState.copy(diceRoll: 3, currentTurnPlayerId: 'p1');
      await tester.pumpAndSettle();


      // At this point, GameScreen should react to the dice roll.
      // If it highlights movable pieces, we'd look for that.
      // If tapping a piece directly calls moveToken (if only one move for that piece),
      // we need a way to tap that specific piece.
      // This requires BoardWidget to render pieces as individual, identifiable widgets.

      // Example: If pieces were rendered with Keys:
      // await tester.tap(find.byKey(Key('player_p1_piece_1')));
      // await tester.pumpAndSettle();
      // expect(gameProvider.moveTokenCalled, isTrue);
      // expect(gameProvider.lastMove?.pieceIndex, 1);
      // expect(gameProvider.lastMove?.newPosition, expectedNewPos);
      
      // Since we cannot tap specific pieces without more info, this test remains conceptual.
      // A simpler check: if a dice is rolled, and provider has possible moves,
      // then some UI element related to making a move should be present.
      // This is still too vague. Let's assume a "Make AI Move" button for AI for now if that was simpler.
      // But this is a human player.
      
      // For now, we'll verify that if GameProvider has possible moves,
      // some indication might appear. This is hard to test without UI specifics.
      // We'll assume that the BoardWidget itself might change appearance,
      // or individual pieces might become "highlighted" (which we can't detect easily).
      
      // Instead, let's test that if a player has rolled, and they have a piece that *could* move,
      // then calling moveToken through some other mechanism (e.g. if UI automatically selects the only move) works.
      // This is more a provider test than a UI test in that case.
      
      // The most direct UI test here is to ensure the provider's moveToken is callable.
      // The actual tapping requires knowledge of how BoardWidget exposes its pieces for interaction.
      // Given the current tools and info, I cannot write a more specific piece tapping test.
      print("NOTE: Specific token tapping test is conceptual due to lack of Key/interaction details in BoardWidget.");
    });

    testWidgets('Game Over dialog or display appears when game ends', (WidgetTester tester) async {
      await tester.pumpWidget(createGameScreen());

      // Simulate game over by setting a winner in the provider
      final winner = gameProvider.gameState.players.first;
      gameProvider.gameState = gameProvider.gameState.copy(winnerId: winner.id);
      await tester.pumpAndSettle(); // Re-render

      // Check for a "Game Over" text or dialog and winner announcement
      expect(find.textContaining('Game Over!'), findsOneWidget);
      expect(find.textContaining('${winner.name} wins!'), findsOneWidget);
      // Also check for a "Play Again" or "Back to Home" button
      expect(find.text('Play Again'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
    });
    
    testWidgets('Play Again button on Game Over dialog starts a new game', (WidgetTester tester) async {
      await tester.pumpWidget(createGameScreen());

      // 1. Set game to over state
      final winner = gameProvider.gameState.players.first;
      gameProvider.gameState = gameProvider.gameState.copy(winnerId: winner.id);
      await tester.pumpAndSettle();

      expect(find.text('Play Again'), findsOneWidget);

      // 2. Mock the GameService's startGame for the "Play Again" functionality
      final newPlayersForRestart = gameProvider.gameState.players.map((p) => Player(p.id, p.name, color: p.color, isAI: p.isAI)).toList();
      final freshState = mockGameService.startGame(players: newPlayersForRestart, firstPlayerId: newPlayersForRestart.first.id);
      when(mockGameService.startGame(players: anyNamed('players'), firstPlayerId: anyNamed('firstPlayerId')))
          .thenReturn(freshState.copy(gameId: "restartedGame"));


      // 3. Tap "Play Again"
      await tester.tap(find.text('Play Again'));
      await tester.pumpAndSettle(); // Allow for state change and UI rebuild

      // Verify GameProvider's startNewGame was called (implicitly via its own method)
      // And that the game state is reset (no winnerId, new gameId perhaps)
      expect(gameProvider.gameState.winnerId, isNull);
      expect(gameProvider.gameState.gameId, "restartedGame"); // Check against the mocked new gameId
      expect(find.textContaining('Game Over!'), findsNothing); // Dialog should be gone
      expect(find.textContaining('Player 1\'s Turn'), findsOneWidget); // Back to game start
    });


  });
}
