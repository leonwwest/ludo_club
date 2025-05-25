import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
// import 'package:ludo_club/models/player.dart'; // Removed
import 'package:ludo_club/services/game_service.dart';

// Helper to create a basic GameState
GameState _createBasicGameState({
  Map<String, List<int>>? initialPlayerTokenPositions, // Changed from pieces
  String currentTurnPlayerId = 'p1',
  int? lastDiceVal, // Changed from diceRoll
  int currentRollCount = 0,
  List<Player>? playersList, // Changed from players
  Map<String, int>? startIndicesOverride, // Changed from startIndices
}) {
  final List<Player> effectivePlayers = playersList ??
      [
        Player('p1', 'Player 1'),
        Player('p2', 'Player 2'),
      ];

  // Apply initial token positions if provided
  if (initialPlayerTokenPositions != null) {
    for (var player in effectivePlayers) {
      if (initialPlayerTokenPositions.containsKey(player.id)) {
        player.tokenPositions = initialPlayerTokenPositions[player.id]!;
      }
    }
  }

  return GameState(
    players: effectivePlayers,
    startIndex: startIndicesOverride ?? {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39},
    currentTurnPlayerId: currentTurnPlayerId,
    lastDiceValue: lastDiceVal,
    currentRollCount: currentRollCount,
  );
}

// Mock Random for predictable dice rolls
class MockRandom implements Random {
  final List<int> _sequence;
  int _index = 0;

  MockRandom(this._sequence);

  @override
  int nextInt(int max) {
    if (_index >= _sequence.length) {
      throw StateError('MockRandom sequence exhausted');
    }
    final val = _sequence[_index++];
    if (val < 0 || val >= max) {
      throw ArgumentError('Value in sequence out of bounds for max');
    }
    return val;
  }

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  group('GameService', () {
    late GameService gameService;
    late GameState initialGameState;

    setUp(() {
      initialGameState = _createBasicGameState();
      // GameService constructor: GameService(GameState state, [Random? random])
      gameService = GameService(initialGameState, Random()); 
    });

    group('rollDice', () {
      test('should return a value between 1 and 6 and update state', () {
        // gameService is initialized in setUp with initialGameState
        final int rolledValue = gameService.rollDice(); // rollDice() returns int, takes no args

        expect(rolledValue, allOf(greaterThanOrEqualTo(1), lessThanOrEqualTo(6)));
        expect(gameService.state.lastDiceValue, rolledValue);
        expect(gameService.state.currentRollCount, 1);
        expect(gameService.state.currentTurnPlayerId, initialGameState.currentTurnPlayerId);
      });

      test('rolling a 6 allows another roll (turn does not pass)', () {
        // Re-initialize gameService with a specific state and MockRandom for this test
        var stateForTest = _createBasicGameState(currentTurnPlayerId: 'p1');
        // GameService constructor: GameService(GameState state, [Random? random])
        gameService = GameService(stateForTest, MockRandom([5])); // MockRandom will make nextInt(6) return 5, so roll is 6

        final int rolledValue = gameService.rollDice();

        expect(rolledValue, 6);
        expect(gameService.state.lastDiceValue, 6);
        expect(gameService.state.currentRollCount, 1); // First 6
        expect(gameService.state.currentTurnPlayerId, 'p1'); // Turn should not pass
      });

      test('rolling a 6 three times in a row ends the turn', () {
        var stateForTest = _createBasicGameState(
            currentTurnPlayerId: 'p1',
            playersList: [Player('p1', 'P1'), Player('p2', 'P2')]);
        // GameService constructor: GameService(GameState state, [Random? random])
        gameService = GameService(stateForTest, MockRandom([5, 5, 5])); // Rolls 6, 6, 6

        int roll1 = gameService.rollDice(); // Roll 1
        expect(roll1, 6);
        expect(gameService.state.currentTurnPlayerId, 'p1');
        expect(gameService.state.currentRollCount, 1);
        expect(gameService.state.lastDiceValue, 6);

        int roll2 = gameService.rollDice(); // Roll 2
        expect(roll2, 6);
        expect(gameService.state.currentTurnPlayerId, 'p1');
        expect(gameService.state.currentRollCount, 2);
        expect(gameService.state.lastDiceValue, 6);
        
        int roll3 = gameService.rollDice(); // Roll 3
        expect(roll3, 6);
        // After 3rd six, turn should end, state updated for next player
        expect(gameService.state.currentTurnPlayerId, 'p2');
        expect(gameService.state.currentRollCount, 0); // Reset for next player
        expect(gameService.state.lastDiceValue, isNull); // Reset for next player
      });

      test('if a player rolls non-6 and has no possible moves, the turn should end', () {
        var stateForTest = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          playersList: [Player('p1','P1'), Player('p2','P2')],
          // All p1 tokens at base, so no moves unless a 6 is rolled.
          initialPlayerTokenPositions: {'p1': List.filled(GameState.tokensPerPlayer, GameState.basePosition)},
        );
        gameService = GameService(stateForTest, MockRandom([2])); // Rolls a 3 (2+1)

        final int rolledValue = gameService.rollDice();
        expect(rolledValue, 3);
        // No moves possible with a 3 when all tokens are at base, so turn should end.
        expect(gameService.state.currentTurnPlayerId, 'p2');
        expect(gameService.state.currentRollCount, 0); // Reset for next player
        expect(gameService.state.lastDiceValue, isNull); // Reset for next player
      });

      test('rolling non-6 when no moves possible and tokens in base ends turn', () {
        var stateForTest = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          playersList: [Player('p1', 'P1'), Player('p2', 'P2')],
          initialPlayerTokenPositions: {'p1': List.filled(GameState.tokensPerPlayer, GameState.basePosition)}, 
        );
        gameService = GameService(stateForTest, MockRandom([0])); // Rolls a 1 (0+1)

        final int rolledValue = gameService.rollDice();
        expect(rolledValue, 1);
        expect(gameService.state.currentTurnPlayerId, 'p2'); 
        expect(gameService.state.currentRollCount, 0);
        expect(gameService.state.lastDiceValue, isNull);
      });

      test('rolling 6 when tokens in base allows move, turn does not end automatically', () {
        var stateForTest = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          playersList: [Player('p1', 'P1'), Player('p2', 'P2')],
          initialPlayerTokenPositions: {'p1': List.filled(GameState.tokensPerPlayer, GameState.basePosition)}, 
        );
        gameService = GameService(stateForTest, MockRandom([5])); // Rolls a 6 (5+1)

        final int rolledValue = gameService.rollDice();
        expect(rolledValue, 6);
        // Moves are possible (can bring a token out of base)
        expect(gameService.state.currentTurnPlayerId, 'p1'); // Turn should not pass yet
        expect(gameService.state.currentRollCount, 1); // It was the first 6
        expect(gameService.state.lastDiceValue, 6);
        // Player can roll again (handled by GameService internal logic, not directly by canRollAgain getter)
      });

       test('rolling non-6 with a movable token on board, turn ends if move made (or if auto-turn-end)', () {
        // GameService.rollDice checks if moves are possible. If yes, and not a 6, it ends turn.
        var stateForTest = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          playersList: [Player('p1', 'P1'), Player('p2', 'P2')],
          initialPlayerTokenPositions: {'p1': [0, -1, -1, -1]}, // p1 has one token on board at pos 0
        );
        gameService = GameService(stateForTest, MockRandom([2])); // Rolls a 3

        final int rolledValue = gameService.rollDice();
        expect(rolledValue, 3);
        // A move is possible for token at 0. GameService.rollDice calls _endTurn.
        expect(gameService.state.currentTurnPlayerId, 'p2'); // Turn should pass
        expect(gameService.state.currentRollCount, 0);
        expect(gameService.state.lastDiceValue, isNull);
      });
    });

    group('_endTurn (implicitly tested by rollDice outcomes that change turn)', () {
      // These tests re-verify the state after a turn ends, similar to some rollDice tests.
      test('attributes are reset and turn passes after three 6s', () {
        var stateForTest = _createBasicGameState(currentTurnPlayerId: 'p1', playersList: [Player('p1','P1'), Player('p2','P2')]);
        gameService = GameService(stateForTest, MockRandom([5, 5, 5])); // Rolls 6, 6, 6
        
        gameService.rollDice(); // Roll 1
        gameService.rollDice(); // Roll 2
        final int lastRolled = gameService.rollDice(); // Roll 3 - should end turn

        expect(lastRolled, 6);
        expect(gameService.state.currentTurnPlayerId, 'p2', reason: "Turn should pass to p2");
        expect(gameService.state.currentRollCount, 0, reason: "Roll count should reset for p2");
        expect(gameService.state.lastDiceValue, null, reason: "Dice roll should reset for p2");
      });

      test('attributes are reset when turn ends after non-6 roll with no moves', () {
        var stateForTest = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          playersList: [Player('p1','P1'), Player('p2','P2')],
          initialPlayerTokenPositions: {'p1': List.filled(GameState.tokensPerPlayer, GameState.basePosition)},
        );
        gameService = GameService(stateForTest, MockRandom([2])); // Rolls a 3
        final int rolledValue = gameService.rollDice();

        expect(rolledValue, 3);
        expect(gameService.state.currentTurnPlayerId, 'p2', reason: "Turn should pass to p2");
        expect(gameService.state.currentRollCount, 0, reason: "Roll count should reset");
        expect(gameService.state.lastDiceValue, null, reason: "Dice roll should reset");
      });
    });
    
    group('getPossibleMoveDetails', () {
      final playersListSetup = [
        Player('p1', 'Player 1'), Player('p2', 'Player 2'),
        Player('p3', 'Player 3'), Player('p4', 'Player 4'),
      ];
      const startIndicesSetup = {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39};

      GameState _createStateForMoveTest({
        required String currentPlayerId,
        required int diceValue,
        required Map<String, List<int>> playerTokenPositions,
      }) {
        final List<Player> testPlayers = playersListSetup.map((templatePlayer) {
          final player = Player(templatePlayer.id, templatePlayer.name); // Create new player instance
          if (playerTokenPositions.containsKey(templatePlayer.id)) {
            player.tokenPositions = List<int>.from(playerTokenPositions[templatePlayer.id]!);
          } else {
            // Ensure all players have token positions, even if empty or all at base
            player.tokenPositions = List.filled(GameState.tokensPerPlayer, GameState.basePosition);
          }
          return player;
        }).toList();

        return GameState(
          players: testPlayers,
          startIndex: startIndicesSetup,
          currentTurnPlayerId: currentPlayerId,
          lastDiceValue: diceValue,
          currentRollCount: 1, // Assume a roll has just occurred.
        );
      }

      group('Token in base', () {
        test('needs a 6 to get out, no other moves if not 6', () {
          final state = _createStateForMoveTest(
            currentPlayerId: 'p1',
            diceValue: 5, // Not a 6
            playerTokenPositions: {'p1': [-1, 0, 1, 2], 'p2': []}, // p1 token 0 at base
          );
          gameService = GameService(state);
          final List<Map<String, int>> moveDetails = gameService.getPossibleMoveDetails();
          
          final startPosP1 = state.startIndex['p1']!;
          // No move for pieceIndex 0 (the one at -1) should target startPosP1
          expect(moveDetails.any((m) => m['tokenIndex'] == 0 && m['targetPosition'] == startPosP1), isFalse);
        });

        test('gets out with a 6', () {
          final state = _createStateForMoveTest(
            currentPlayerId: 'p1',
            diceValue: 6,
            playerTokenPositions: {'p1': [-1, 0, 1, 2]}, // p1 token 0 at base
          );
          gameService = GameService(state);
          final List<Map<String, int>> moveDetails = gameService.getPossibleMoveDetails();
          final expectedTarget = state.startIndex['p1']!;
          expect(moveDetails.any((m) => m['tokenIndex'] == 0 && m['targetPosition'] == expectedTarget), isTrue);
        });
      });

      // Add more tests for various scenarios like:
      // - Token on board, normal move
      // - Token on board, blocked by own pieces (stacking not allowed by default)
      // - Token on board, landing on opponent (capture)
      // - Token entering home path
      // - Token moving within home path
      // - Token reaching home (finish)
      // - All tokens at base, rolls 6 -> move out
      // - All tokens finished -> no moves
      // - etc.
    });

    group('moveToken', () {
        test('moves token from base correctly', () {
            final p1 = Player('p1', 'Player 1', initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition));
            final GameState state = _createBasicGameState(
                playersList: [p1, Player('p2', 'Player 2')], // Ensure other players exist for turn passing
                currentTurnPlayerId: 'p1',
                lastDiceVal: 6 // Assumed roll that allows moving from base
            );
            gameService = GameService(state);
            
            final tokenIndexToMove = 0; // First token
            final targetPosition = state.startIndex['p1']!;

            final String? capturedOpponentId = gameService.moveToken('p1', tokenIndexToMove, targetPosition);

            expect(capturedOpponentId, isNull);
            expect(gameService.state.players.firstWhere((p) => p.id == 'p1').tokenPositions[tokenIndexToMove], targetPosition);
            
            // If move from base with 6 (no capture/finish), moveToken calls _endTurn
            expect(gameService.state.lastDiceValue, isNull, reason: "moveToken should call _endTurn if no bonus");
            expect(gameService.state.currentRollCount, 0, reason: "moveToken should call _endTurn if no bonus");
            expect(gameService.state.currentTurnPlayerId, 'p2', reason: "Turn should pass if moveToken called _endTurn");
        });

      test('moves token on board and captures opponent, awards bonus (turn does not change yet)', () {
        final p1 = Player('p1', 'Player 1', initialPositions: [5, -1, -1, -1]); 
        final p2 = Player('p2', 'Player 2', initialPositions: [8, -1, -1, -1]); 
        final GameState state = _createBasicGameState(
            playersList: [p1, p2],
            currentTurnPlayerId: 'p1',
            lastDiceVal: 3 // p1 rolls 3 to move from 5 to 8
        );
        gameService = GameService(state);

        final String? capturedId = gameService.moveToken('p1', 0, 8); // p1's token 0 moves 5+3=8

        expect(capturedId, 'p2');
        expect(gameService.state.players.firstWhere((p) => p.id == 'p1').tokenPositions[0], 8);
        expect(gameService.state.players.firstWhere((p) => p.id == 'p2').tokenPositions[0], GameState.basePosition);
        
        // After a capture, moveToken sets _bonusTurnAwarded. Turn state (lastDiceValue, currentTurnPlayerId, currentRollCount)
        // should NOT be reset by moveToken because a bonus is awarded.
        // The next call to rollDice() will see the bonus and act accordingly (not end turn, allow re-roll).
        expect(gameService.state.currentTurnPlayerId, 'p1', reason: "Turn shouldn't change on bonus");
        expect(gameService.state.lastDiceValue, 3, reason: "Dice value should persist on bonus");
        // currentRollCount is not modified by moveToken itself, it's managed by rollDice.
        // So it should retain the value from the GameState it was constructed with (or from last rollDice call).
        // In this test setup, GameState was made with currentRollCount = 0 by _createBasicGameState
        // And lastDiceVal = 3. GameService.rollDice() was NOT called.
        // So, currentRollCount should still be 0.
        expect(gameService.state.currentRollCount, 0, reason: "currentRollCount from initial state");
      });
      
      test('moves token to home and awards bonus (turn does not change yet)', () {
        // P1 needs to be near home. Start:0. Home path start for P1: value depends on GameService logic, e.g. 51 for a 40-field board. Home: GameState.finishedPosition.
        // Let p1 token 0 be at a position from which it can reach home.
        // Example: if home path is 4 fields (totalFields to totalFields+homePathLength-1), and finishedPosition is 99.
        // If a token is at (GameState.totalFields + GameState.homePathLength - 1) which is the last spot on home path,
        // and rolls a 1, it should move to GameState.finishedPosition.
        // For this test, let's place a token right before the finished state.
        // The exact pre-finish position depends on how GameService calculates home path entry and movement.
        // For simplicity, let's assume a scenario: player needs to roll X to land exactly on finishedPosition.

        final p1 = Player('p1', 'Player 1', initialPositions: [56, -1, -1, -1]); // Position 56, assume this is one step before home for p1
                                                                            // (This specific value 56 might need adjustment based on actual home path logic)
        final GameState state = _createBasicGameState(
            playersList: [p1, Player('p2', 'Player 2')],
            currentTurnPlayerId: 'p1',
            lastDiceVal: 1 // Rolls a 1 to move from 56 to home (57 conceptually, but stored as finishedPosition)
        );
        gameService = GameService(state);

        // We are testing moveToken directly. We assume getPossibleMoveDetails would yield this move.
        // The target for finishing a piece is always GameState.finishedPosition.
        final String? capturedId = gameService.moveToken('p1', 0, GameState.finishedPosition);

        expect(capturedId, isNull);
        expect(gameService.state.players.firstWhere((p) => p.id == 'p1').tokenPositions[0], GameState.finishedPosition);
        
        // Finishing a token awards a bonus.
        expect(gameService.state.currentTurnPlayerId, 'p1', reason: "Turn shouldn't change on bonus");
        expect(gameService.state.lastDiceValue, 1, reason: "Dice value should persist on bonus");
        expect(gameService.state.currentRollCount, 0, reason: "currentRollCount from initial state, not changed by moveToken if bonus");
      });

      test('moveToken correctly ends turn if no bonus is awarded', () {
        // P1 token at 0, rolls 3, moves to 3. No capture, no finish.
        final p1 = Player('p1', 'Player 1', initialPositions: [0, -1, -1, -1]);
        final GameState state = _createBasicGameState(
            playersList: [p1, Player('p2', 'Player 2')],
            currentTurnPlayerId: 'p1',
            lastDiceVal: 3
        );
        gameService = GameService(state);

        final String? capturedId = gameService.moveToken('p1', 0, 3); // Normal move

        expect(capturedId, isNull);
        expect(gameService.state.players.firstWhere((p) => p.id == 'p1').tokenPositions[0], 3);

        // No bonus, so moveToken should call _endTurn.
        expect(gameService.state.currentTurnPlayerId, 'p2', reason: "Turn should pass if no bonus");
        expect(gameService.state.lastDiceValue, isNull, reason: "Dice value should be null after _endTurn");
        expect(gameService.state.currentRollCount, 0, reason: "Roll count should be 0 after _endTurn");
      });
    });
  });
}
