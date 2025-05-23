import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/models/player.dart';
import 'package:ludo_club/providers/game_provider.dart';
import 'package:ludo_club/services/audio_service.dart';
import 'package:ludo_club/services/game_service.dart';
import 'package:ludo_club/services/save_load_service.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Manual Mocks since build_runner is not working in this environment

class MockGameService extends Mock implements GameService {
  @override
  GameState rollDice(GameState currentState) {
    // Return a new state with dice rolled, or as per test needs
    return currentState.copy(diceRoll: 3, currentRollCount: 1); // Example roll
  }

  @override
  GameState moveToken(GameState currentState, PossibleMove move) {
    // Return a new state with token moved
    final newPieces = Map<String, List<int>>.from(currentState.pieces);
    if (newPieces[currentState.currentTurnPlayerId] != null) {
      newPieces[currentState.currentTurnPlayerId]![move.pieceIndex] = move.newPosition;
    }
    return currentState.copy(pieces: newPieces, diceRoll: null, canRollAgain: false, currentTurnPlayerId: currentState.players[(currentState.players.indexWhere((p) => p.id == currentState.currentTurnPlayerId) + 1) % currentState.players.length].id);
  }

  @override
  List<PossibleMove> getPossibleMoves(GameState currentState) {
    if (currentState.diceRoll == null) return [];
    // Return some possible moves based on dice roll for testing
    if (currentState.diceRoll == 3) {
      // Find first movable piece for current player
      final playerPieces = currentState.pieces[currentState.currentTurnPlayerId];
      if (playerPieces != null) {
        for (int i = 0; i < playerPieces.length; i++) {
          if (playerPieces[i] != -1 && playerPieces[i] < GameService.homeIndexP1) { // Simple check: not in base, not home
            return [PossibleMove(pieceIndex: i, newPosition: playerPieces[i] + currentState.diceRoll!)];
          }
        }
      }
    }
     if (currentState.diceRoll == 6) { // For getting out of base
        final playerPieces = currentState.pieces[currentState.currentTurnPlayerId];
        if (playerPieces != null) {
            for (int i = 0; i < playerPieces.length; i++) {
                if (playerPieces[i] == -1) {
                    return [PossibleMove(pieceIndex: i, newPosition: currentState.startIndex[currentState.currentTurnPlayerId]!, isMoveOutOfBase: true)];
                }
            }
        }
    }
    return [];
  }

  @override
  GameState startGame({List<Player>? players, String? firstPlayerId}) {
    return GameState(
      players: players ?? [Player('p1', 'Player 1'), Player('p2', 'Player 2')],
      startIndex: {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39},
      pieces: {'p1': [-1,-1,-1,-1], 'p2': [-1,-1,-1,-1]},
      currentTurnPlayerId: firstPlayerId ?? 'p1',
    );
  }
}

class MockAudioService extends Mock implements AudioService {
  bool _soundEnabled = true;
  double _volume = 0.5;

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
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  @override
  void setVolume(double volume) {
    _volume = volume;
  }
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

void main() {
  group('GameProvider', () {
    late GameProvider gameProvider;
    late MockGameService mockGameService;
    late MockAudioService mockAudioService;
    late MockSaveLoadService mockSaveLoadService;

    // Helper to create a GameState for tests
    GameState createInitialState({List<Player>? players}) {
      final p = players ?? [Player('p1', 'Player 1'), Player('p2', 'Player 2')];
      return GameState(
        players: p,
        startIndex: {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39},
        pieces: Map.fromEntries(p.map((pl) => MapEntry(pl.id, [-1, -1, -1, -1]))),
        currentTurnPlayerId: p.first.id,
      );
    }

    setUp(() {
      mockGameService = MockGameService();
      mockAudioService = MockAudioService();
      mockSaveLoadService = MockSaveLoadService();
      
      // Initialize GameProvider with a default state and mocked services
      final initialState = createInitialState();
      when(mockGameService.startGame(players: anyNamed('players'), firstPlayerId: anyNamed('firstPlayerId')))
          .thenReturn(initialState);

      gameProvider = GameProvider.withServices(
        initialState: initialState,
        gameService: mockGameService,
        audioService: mockAudioService,
        saveLoadService: mockSaveLoadService,
      );
    });

    testWidgets('rollDice updates gameState and notifies listeners', (WidgetTester tester) async {
      // Mock the GameService's rollDice response
      final testState = gameProvider.gameState.copy();
      final rolledState = testState.copy(diceRoll: 4, currentRollCount: 1, canRollAgain: false);
      when(mockGameService.rollDice(any)).thenReturn(rolledState);

      bool listenerCalled = false;
      gameProvider.addListener(() {
        listenerCalled = true;
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameProvider>.value(
          value: gameProvider,
          child: MaterialApp(
            home: Consumer<GameProvider>(
              builder: (context, provider, child) {
                return Text('Dice: ${provider.gameState.diceRoll}');
              },
            ),
          ),
        ),
      );

      // Initial state check
      expect(find.text('Dice: null'), findsOneWidget);
      
      await gameProvider.rollDice();
      await tester.pump(); // Rebuild widgets

      expect(listenerCalled, isTrue);
      expect(gameProvider.gameState.diceRoll, 4);
      expect(find.text('Dice: 4'), findsOneWidget);
      verify(mockGameService.rollDice(any)).called(1);
      verify(mockAudioService.playDiceRoll()).called(1);
      // isAnimating would ideally be tested by checking a flag that becomes true then false
      // For simplicity here, we assume it's handled if rollDice completes.
    });

    testWidgets('rollDice handles isAnimating state', (WidgetTester tester) async {
      final initialGameState = gameProvider.gameState.copy();
      final rolledGameState = initialGameState.copy(diceRoll: 5, currentRollCount: 1);
      when(mockGameService.rollDice(any)).thenAnswer((_) async {
         // No need to delay here, provider should set isAnimating before and after
        return rolledGameState;
      });

      bool wasAnimating = false;
      gameProvider.addListener(() {
        if (gameProvider.isAnimating) {
          wasAnimating = true;
        }
      });
      
      expect(gameProvider.isAnimating, isFalse);
      final rollFuture = gameProvider.rollDice();
      // Immediately after calling, isAnimating should be true if synchronous part sets it
      // However, if it's set within an async gap that pump hasn't caught, this might be tricky
      // For now, checking wasAnimating in listener is more robust for this manual mock.
      
      await rollFuture; // Wait for rollDice to complete
      await tester.pump();

      expect(wasAnimating, isTrue); // Check if it was set to true at some point
      expect(gameProvider.isAnimating, isFalse); // Should be false after completion
    });
    
    testWidgets('moveToken updates gameState and notifies listeners', (WidgetTester tester) async {
      // Setup initial state with a rolled dice and a possible move
      final initialPlayerId = gameProvider.gameState.currentTurnPlayerId;
      final nextPlayerId = gameProvider.gameState.players[(gameProvider.gameState.players.indexWhere((p) => p.id == initialPlayerId) + 1) % gameProvider.gameState.players.length].id;

      final stateWithDice = gameProvider.gameState.copy(diceRoll: 3, pieces: {'p1': [0,-1,-1,-1], 'p2':[-1,-1,-1,-1]}, currentTurnPlayerId: 'p1');
      gameProvider.gameState = stateWithDice; // Force set state for test

      final move = PossibleMove(pieceIndex: 0, newPosition: 3); // p1 moves token 0 from 0 to 3
      final movedState = stateWithDice.copy(
          pieces: {'p1': [3,-1,-1,-1], 'p2':[-1,-1,-1,-1]},
          diceRoll: null,
          canRollAgain: false,
          currentTurnPlayerId: nextPlayerId // Turn passes to p2
      );
      when(mockGameService.moveToken(any, any)).thenReturn(movedState);
      when(mockGameService.getPossibleMoves(any)).thenReturn([move]); // Make sure a move is available


      bool listenerCalled = false;
      gameProvider.addListener(() {
        listenerCalled = true;
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameProvider>.value(
          value: gameProvider,
          child: MaterialApp(
            home: Consumer<GameProvider>(
              builder: (context, provider, child) {
                return Text('P1_Token0: ${provider.gameState.pieces['p1']?[0]}');
              },
            ),
          ),
        ),
      );
      expect(find.text('P1_Token0: 0'), findsOneWidget);

      await gameProvider.moveToken(move);
      await tester.pump();

      expect(listenerCalled, isTrue);
      expect(gameProvider.gameState.pieces['p1']![0], 3);
      expect(gameProvider.gameState.currentTurnPlayerId, nextPlayerId);
      expect(find.text('P1_Token0: 3'), findsOneWidget);
      verify(mockGameService.moveToken(any, move)).called(1);
      verify(mockAudioService.playMove()).called(1); // Assuming simple move
    });

    testWidgets('startNewGame re-initializes state and notifies listeners', (WidgetTester tester) async {
      final players = [Player('p1', 'Player 1'), Player('p2', 'Player 2')];
      final newInitialState = GameState(
        players: players,
        startIndex: {'p1': 0, 'p2': 13},
        pieces: {'p1': [-1,-1,-1,-1], 'p2': [-1,-1,-1,-1]},
        currentTurnPlayerId: 'p1',
        gameId: 'newGame123',
      );
      when(mockGameService.startGame(players: players, firstPlayerId: 'p1')).thenReturn(newInitialState);

      bool listenerCalled = false;
      gameProvider.addListener(() {
        listenerCalled = true;
      });
      
      // Modify current state to ensure it changes
      gameProvider.gameState = gameProvider.gameState.copy(diceRoll: 5, gameId: "oldGame");

      await gameProvider.startNewGame(players: players, firstPlayerId: 'p1');
      await tester.pump();

      expect(listenerCalled, isTrue);
      expect(gameProvider.gameState.diceRoll, isNull); // Reset from modification
      expect(gameProvider.gameState.gameId, 'newGame123');
      expect(gameProvider.gameState.players.length, 2);
      expect(gameProvider.gameState.currentTurnPlayerId, 'p1');
      verify(mockGameService.startGame(players: players, firstPlayerId: 'p1')).called(1);
    });

    testWidgets('setSoundEnabled calls AudioService and notifies listeners', (WidgetTester tester) async {
      bool listenerCalled = false;
      gameProvider.addListener(() {
        listenerCalled = true;
      });

      gameProvider.setSoundEnabled(false);
      await tester.pump();

      expect(listenerCalled, isTrue);
      verify(mockAudioService.setSoundEnabled(false)).called(1);
      expect(gameProvider.soundEnabled, isFalse);

      listenerCalled = false;
      gameProvider.setSoundEnabled(true);
      await tester.pump();
      
      expect(listenerCalled, isTrue);
      verify(mockAudioService.setSoundEnabled(true)).called(1);
      expect(gameProvider.soundEnabled, isTrue);
    });

    testWidgets('setVolume calls AudioService and notifies listeners', (WidgetTester tester) async {
      bool listenerCalled = false;
      gameProvider.addListener(() {
        listenerCalled = true;
      });

      gameProvider.setVolume(0.8);
      await tester.pump();

      expect(listenerCalled, isTrue);
      verify(mockAudioService.setVolume(0.8)).called(1);
      // No direct getter for volume on provider, relies on AudioService mock state if needed

      listenerCalled = false;
      gameProvider.setVolume(0.3);
      await tester.pump();

      expect(listenerCalled, isTrue);
      verify(mockAudioService.setVolume(0.3)).called(1);
    });

  });
}
