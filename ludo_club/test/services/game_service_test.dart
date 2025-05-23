import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/models/player.dart';
import 'package:ludo_club/services/game_service.dart';

// Helper to create a basic GameState
GameState _createBasicGameState({
  Map<String, List<int>>? pieces,
  String currentTurnPlayerId = 'p1',
  int? diceRoll,
  int currentRollCount = 0,
  List<Player>? players,
  Map<String, int>? startIndices,
}) {
  return GameState(
    players: players ??
        [
          Player('p1', 'Player 1'),
          Player('p2', 'Player 2'),
        ],
    startIndex: startIndices ?? {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39},
    pieces: pieces ?? {'p1': [], 'p2': []},
    currentTurnPlayerId: currentTurnPlayerId,
    diceRoll: diceRoll,
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

    setUp(() {
      // Default Random for most tests, can be overridden
      gameService = GameService(random: Random());
    });

    group('rollDice', () {
      test('should return a value between 1 and 6', () {
        final state = _createBasicGameState();
        final newState = gameService.rollDice(state);
        expect(newState.diceRoll, isNotNull);
        expect(newState.diceRoll, greaterThanOrEqualTo(1));
        expect(newState.diceRoll, lessThanOrEqualTo(6));
        expect(newState.currentRollCount, 1);
        expect(newState.currentTurnPlayerId, state.currentTurnPlayerId); // Turn shouldn't change yet
      });

      test('rolling a 6 allows another roll', () {
        gameService = GameService(random: MockRandom([5])); // Rolls a 6 (5+1)
        final state = _createBasicGameState(currentTurnPlayerId: 'p1');
        final newState = gameService.rollDice(state);

        expect(newState.diceRoll, 6);
        expect(newState.currentRollCount, 1); // It's the first 6
        expect(newState.currentTurnPlayerId, 'p1'); // Same player's turn
        expect(newState.canRollAgain, isTrue);
      });

      test('rolling a 6 three times in a row ends the turn', () {
        gameService = GameService(random: MockRandom([5, 5, 5])); // Rolls 6, 6, 6
        var state = _createBasicGameState(currentTurnPlayerId: 'p1', players: [Player('p1','P1'), Player('p2','P2')]);

        state = gameService.rollDice(state); // Roll 1 (6)
        expect(state.diceRoll, 6);
        expect(state.currentRollCount, 1);
        expect(state.canRollAgain, isTrue);
        expect(state.currentTurnPlayerId, 'p1');

        state = gameService.rollDice(state); // Roll 2 (6)
        expect(state.diceRoll, 6);
        expect(state.currentRollCount, 2);
        expect(state.canRollAgain, isTrue);
        expect(state.currentTurnPlayerId, 'p1');

        state = gameService.rollDice(state); // Roll 3 (6)
        expect(state.diceRoll, 6); // Last roll was 6
        expect(state.currentRollCount, 3); // Counted three 6s
        expect(state.canRollAgain, isFalse); // Turn should end
        expect(state.currentTurnPlayerId, 'p2'); // Turn passes to next player
        expect(state.currentRollCount, 0); // Roll count resets for next player
        expect(state.diceRoll, isNull); // Dice roll resets for next player
      });
      
      test('if a player rolls and has no possible moves, the turn should end', () {
        gameService = GameService(random: MockRandom([2])); // Rolls a 3
        final state = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          players: [Player('p1','P1'), Player('p2','P2')],
          // p1 has one token, far from home, cannot move with a 3 if it's blocked or similar
          // For this test, easier to assume no tokens can move (e.g., all at base, not rolling 6)
          pieces: {'p1': [-1, -1, -1, -1], 'p2': []}, // All p1 tokens at base
        );

        final newState = gameService.rollDice(state);
        expect(newState.diceRoll, 3);
        // Since no moves are possible (can't get out of base with a 3)
        expect(newState.currentTurnPlayerId, 'p2'); // Turn should pass
        expect(newState.currentRollCount, 0);
        expect(newState.diceRoll, isNull);
      });

      test('rolling non-6 when no moves possible and tokens in base ends turn', () {
        gameService = GameService(random: MockRandom([0])); // Rolls a 1
        final state = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          players: [Player('p1', 'P1'), Player('p2', 'P2')],
          pieces: {'p1': [-1, -1, -1, -1], 'p2': []}, // All p1 tokens at base
        );

        final newState = gameService.rollDice(state);
        expect(newState.diceRoll, 1); // Rolled a 1
        // No moves possible (all tokens at base, didn't roll a 6)
        expect(newState.currentTurnPlayerId, 'p2'); // Turn ends
        expect(newState.currentRollCount, 0);
        expect(newState.diceRoll, isNull);
      });

      test('rolling 6 when tokens in base allows move, turn does not end automatically', () {
        gameService = GameService(random: MockRandom([5])); // Rolls a 6
        final state = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          players: [Player('p1', 'P1'), Player('p2', 'P2')],
          pieces: {'p1': [-1, -1, -1, -1], 'p2': []}, // All p1 tokens at base
        );

        final newState = gameService.rollDice(state);
        expect(newState.diceRoll, 6);
        // Moves are possible (can bring a token out of base)
        expect(newState.currentTurnPlayerId, 'p1'); // Turn should not pass yet
        expect(newState.canRollAgain, isTrue); // Player can roll again after moving or if no other moves
      });

       test('rolling non-6 with a movable token on board, turn does not end automatically', () {
        gameService = GameService(random: MockRandom([2])); // Rolls a 3
        final state = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          players: [Player('p1', 'P1'), Player('p2', 'P2')],
          pieces: {'p1': [0, -1, -1, -1], 'p2': []}, // p1 has one token on board
        );

        final newState = gameService.rollDice(state);
        expect(newState.diceRoll, 3);
        // A move is possible for token at 0
        expect(newState.currentTurnPlayerId, 'p1'); // Turn should not pass
        expect(newState.canRollAgain, isFalse); // Not a 6, so no automatic re-roll
      });
    });

    group('_endTurn (implicitly tested)', () {
      test('attributes are reset and turn passes when turn ends after non-6 roll with no moves', () {
        gameService = GameService(random: MockRandom([2])); // Rolls a 3
        final state = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          players: [Player('p1','P1'), Player('p2','P2')],
          pieces: {'p1': [-1,-1,-1,-1], 'p2': []}, // p1 has no movable pieces
        );
        final newState = gameService.rollDice(state);

        expect(newState.currentTurnPlayerId, 'p2', reason: "Turn should pass to p2");
        expect(newState.currentRollCount, 0, reason: "Roll count should reset");
        expect(newState.diceRoll, null, reason: "Dice roll should reset");
      });

      test('attributes are reset and turn passes after three 6s', () {
        gameService = GameService(random: MockRandom([5, 5, 5])); // Rolls 6, 6, 6
        var state = _createBasicGameState(currentTurnPlayerId: 'p1', players: [Player('p1','P1'), Player('p2','P2')]);
        state = gameService.rollDice(state); // Roll 1
        state = gameService.rollDice(state); // Roll 2
        state = gameService.rollDice(state); // Roll 3 - should end turn

        expect(state.currentTurnPlayerId, 'p2', reason: "Turn should pass to p2");
        expect(state.currentRollCount, 0, reason: "Roll count should reset for p2");
        expect(state.diceRoll, null, reason: "Dice roll should reset for p2");
      });
    });
    
    group('getPossibleMoveDetails and getPossibleMoves', () {
      final players = [
        Player('p1', 'Player 1'), // Start 0, Home Path 51-56, Home 57
        Player('p2', 'Player 2'), // Start 13, Home Path 58-63, Home 64
        Player('p3', 'Player 3'), // Start 26, Home Path 65-70, Home 71
        Player('p4', 'Player 4'), // Start 39, Home Path 72-77, Home 78
      ];
      final startIndices = {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39};

      // Basic state for move tests
      GameState createMoveTestState({
        required String currentPlayerId,
        required int diceRoll,
        required Map<String, List<int>> pieces,
      }) {
        return GameState(
          players: players,
          startIndex: startIndices,
          currentTurnPlayerId: currentPlayerId,
          diceRoll: diceRoll,
          pieces: pieces,
        );
      }

      group('Token in base', () {
        test('needs a 6 to get out, no other moves possible', () {
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 5, // Not a 6
            pieces: {'p1': [-1, 0, 1, 2], 'p2': []},
          );
          final moves = gameService.getPossibleMoves(state);
          final moveDetails = gameService.getPossibleMoveDetails(state);
          
          // No move for token at -1
          expect(moves.where((m) => m.pieceIndex == 0 && m.isMoveOutOfBase).toList(), isEmpty);
          expect(moveDetails.where((m) => m.pieceIndex == 0 && m.isMoveOutOfBase).toList(), isEmpty);
        });

        test('gets out with a 6', () {
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 6,
            pieces: {'p1': [-1, 0, 1, 2], 'p2': []}, // Token 0 is at base
          );
          final moves = gameService.getPossibleMoves(state);
          final moveDetails = gameService.getPossibleMoveDetails(state);

          final baseExitMove = moves.firstWhere((m) => m.pieceIndex == 0 && m.isMoveOutOfBase);
          expect(baseExitMove.newPosition, startIndices['p1']);

          final baseExitDetail = moveDetails.firstWhere((m) => m.pieceIndex == 0 && m.isMoveOutOfBase);
          expect(baseExitDetail.newPosition, startIndices['p1']);
          expect(baseExitDetail.isMoveOutOfBase, isTrue);
        });

        test('does not need a 6 if already out (regular move)', () {
          // This test is more about tokens on board, but confirms non-base tokens don't need 6
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 3,
            pieces: {'p1': [0, -1, -1, -1], 'p2': []}, // Token 0 is at field 0
          );
          final moves = gameService.getPossibleMoves(state);
          expect(moves.any((m) => m.pieceIndex == 0 && m.newPosition == 3), isTrue);
        });
      });

      group('Token on board', () {
        test('normal move', () {
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 4,
            pieces: {'p1': [5, -1, -1, -1], 'p2': []},
          );
          final moves = gameService.getPossibleMoves(state);
          final moveDetails = gameService.getPossibleMoveDetails(state);

          expect(moves.any((m) => m.pieceIndex == 0 && m.newPosition == 9), isTrue);
          final detail = moveDetails.firstWhere((d) => d.pieceIndex == 0);
          expect(detail.newPosition, 9);
          expect(detail.isEnteringHomeStretch, isFalse);
        });

        test('moving onto the home path (p1)', () {
          // P1's last common field is 50. Home path starts at 51. Start index is 0.
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 3,
            pieces: {'p1': [49, -1, -1, -1], 'p2': []}, // p1 token at field 49
          );
          final moves = gameService.getPossibleMoves(state); // 49 + 3 = 52. P1 entry is 50. So 50 then 2 steps on home path = 51+1 = 52
          final moveDetails = gameService.getPossibleMoveDetails(state);
          
          // Common path length is 52. Player 1 (id 'p1') start index is 0.
          // Entry to home path is field 50.
          // Target for token at 49 with dice 3: 49 -> 50 (1) -> 51 (2) -> 52 (3)
          // So newPosition should be 52 (representing the 2nd field in home path for p1)
          expect(moves.any((m) => m.pieceIndex == 0 && m.newPosition == 51 + 1), isTrue); // 51 is first home path field
          final detail = moveDetails.firstWhere((d) => d.pieceIndex == 0);
          expect(detail.newPosition, 51 + 1); // 51 (home path 0) + 1 = 52 (home path 1)
          expect(detail.isEnteringHomeStretch, isTrue);
        });

        test('moving onto the home path (p2)', () {
          // P2's start is 13. Last common field before home path is (13-1+52)%52 = 11. Home path starts 58.
          final state = createMoveTestState(
            currentPlayerId: 'p2',
            diceRoll: 2,
            pieces: {'p1': [], 'p2': [10, -1, -1, -1]}, // p2 token at field 10, relative to p1 start. Actual field is 10.
                                                        // P2 entry to home path is field 11.
                                                        // Roll 2: 10 -> 11 (1) -> 58 (2) (first field in p2 home path)
          );
          final moves = gameService.getPossibleMoves(state);
          final moveDetails = gameService.getPossibleMoveDetails(state);

          expect(moves.any((m) => m.pieceIndex == 0 && m.newPosition == GameService.homePathBaseIndexP2 + 0), isTrue);
          final detail = moveDetails.firstWhere((d) => d.pieceIndex == 0);
          expect(detail.newPosition, GameService.homePathBaseIndexP2 + 0);
          expect(detail.isEnteringHomeStretch, isTrue);
        });
      });

      group('Token on home path', () {
        test('moving towards home (p1)', () {
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 2,
            pieces: {'p1': [52, -1, -1, -1], 'p2': []}, // p1 token at home path field 1 (51 is 0)
          );
          final moves = gameService.getPossibleMoves(state);
          // 52 (home path field 1) + 2 = 54 (home path field 3)
          expect(moves.any((m) => m.pieceIndex == 0 && m.newPosition == 51 + 3), isTrue);
          final detail = gameService.getPossibleMoveDetails(state).firstWhere((d) => d.pieceIndex == 0);
          expect(detail.newPosition, 51 + 3);
          expect(detail.isMovingToHome, isFalse); // Not yet in final home spot
        });

        test('moving exactly into home (p1)', () {
          // P1 home path 51-56. Home is 57.
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 3,
            pieces: {'p1': [54, -1, -1, -1], 'p2': []}, // p1 token at home path field 3 (51+3)
          );
          // 54 (hp 3) + 3 = 57 (hp 6, which is HOME_INDEX_P1)
          final moves = gameService.getPossibleMoves(state);
          expect(moves.any((m) => m.pieceIndex == 0 && m.newPosition == GameService.homeIndexP1), isTrue);
          final detail = gameService.getPossibleMoveDetails(state).firstWhere((d) => d.pieceIndex == 0);
          expect(detail.newPosition, GameService.homeIndexP1);
          expect(detail.isMovingToHome, isTrue);
        });

        test('cannot overshoot home (p1)', () {
          // P1 home path 51-56. Home is 57.
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 4,
            pieces: {'p1': [54, -1, -1, -1], 'p2': []}, // p1 token at home path field 3 (51+3)
          );
          // 54 (hp 3) + 4 = hp 7. Max is hp 6 (HOME_INDEX_P1). So no move.
          final moves = gameService.getPossibleMoves(state);
          expect(moves.where((m) => m.pieceIndex == 0).toList(), isEmpty);
        });
      });

      group('Token in home (finished)', () {
        test('no moves possible', () {
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 5,
            pieces: {'p1': [GameService.homeIndexP1, 0, 1, 2], 'p2': []}, // Token 0 is at home
          );
          final moves = gameService.getPossibleMoves(state);
          expect(moves.where((m) => m.pieceIndex == 0).toList(), isEmpty);
        });
      });

      group('Blocked by own token', () {
        test('cannot land on field occupied by own token', () {
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 3,
            pieces: {'p1': [0, 3, -1, -1], 'p2': []}, // Token 0 wants to move to 3, where Token 1 is
          );
          final moves = gameService.getPossibleMoves(state);
          expect(moves.where((m) => m.pieceIndex == 0).toList(), isEmpty);
        });

         test('can move if target is not occupied by own token', () {
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 3,
            pieces: {'p1': [0, 4, -1, -1], 'p2': []}, // Token 0 wants to move to 3, Token 1 is at 4
          );
          final moves = gameService.getPossibleMoves(state);
          expect(moves.any((m) => m.pieceIndex == 0 && m.newPosition == 3), isTrue);
        });
      });
      
      group('getPossibleMoveDetails specific properties', () {
        test('isCapture is true when landing on opponent', () {
          final state = createMoveTestState(
            currentPlayerId: 'p1',
            diceRoll: 3,
            pieces: {'p1': [0], 'p2': [3]}, // p1 at 0, p2 at 3. p1 rolls 3.
          );
          final details = gameService.getPossibleMoveDetails(state);
          final moveDetail = details.firstWhere((d) => d.pieceIndex == 0 && d.newPosition == 3);
          expect(moveDetail.isCapture, isTrue);
          expect(moveDetail.capturedPiecePlayerId, 'p2');
          expect(moveDetail.capturedPieceIndexOnBoard, 3); // The actual board field index
        });

        test('isCapture is false when landing on empty safe field', () {
           final p1Start = startIndices['p1']!; // 0
           final state = createMoveTestState(
            currentPlayerId: 'p2', // p2's turn
            diceRoll: 3,
            pieces: {'p1': [], 'p2': [p1Start-3]}, // p2 piece at (0-3+52)%52 = 49
                                                  // p1 start (0) is a safe field
          );
          // p2 at 49, rolls 3, lands on 0 (p1's start field, which is safe)
          final details = gameService.getPossibleMoveDetails(state);
          final moveDetail = details.firstWhere((d) => d.pieceIndex == 0 && d.newPosition == p1Start);
          expect(moveDetail.isCapture, isFalse);
        });

        test('isCapture is false when landing on occupied safe field (no capture)', () {
           final p1Start = startIndices['p1']!; // 0
           final state = createMoveTestState(
            currentPlayerId: 'p2', // p2's turn
            diceRoll: 3,
            pieces: {'p1': [p1Start], 'p2': [p1Start-3]}, // p1 at 0, p2 at (0-3+52)%52 = 49
                                                        // p1 start (0) is a safe field
          );
          // p2 at 49, rolls 3, lands on 0 (p1's start field, which is safe and occupied by p1)
          final details = gameService.getPossibleMoveDetails(state);
          final moveDetail = details.firstWhere((d) => d.pieceIndex == 0 && d.newPosition == p1Start);
          expect(moveDetail.isCapture, isFalse); // Cannot capture on safe field
        });
      });

    });

    group('moveToken', () {
      final players = [
        Player('p1', 'Player 1'), Player('p2', 'Player 2'),
        Player('p3', 'Player 3'), Player('p4', 'Player 4'),
      ];
      final startIndices = {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39};

      GameState createMoveTokenTestState({
        String currentPlayerId = 'p1',
        int? diceRoll,
        required Map<String, List<int>> pieces,
        String? winnerId,
        int currentRollCount = 0,
        bool canRollAgain = false,
      }) {
        return GameState(
          players: players,
          startIndex: startIndices,
          currentTurnPlayerId: currentPlayerId,
          diceRoll: diceRoll,
          pieces: Map.from(pieces), // Ensure mutable copy
          winnerId: winnerId,
          currentRollCount: currentRollCount,
          canRollAgain: canRollAgain,
        );
      }

      test('moving token from base (with a 6)', () {
        final state = createMoveTokenTestState(
          diceRoll: 6,
          pieces: {'p1': [-1, 1, 2, 3], 'p2': []},
        );
        final move = PossibleMove(pieceIndex: 0, newPosition: startIndices['p1']!, isMoveOutOfBase: true);
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![0], startIndices['p1']);
        expect(newState.diceRoll, 6); // Dice roll should remain
        expect(newState.canRollAgain, isTrue); // Player rolls again after moving out of base with 6
        expect(newState.currentTurnPlayerId, 'p1'); // Same player's turn
      });

      test('moving token on main board', () {
        final state = createMoveTokenTestState(
          diceRoll: 3,
          pieces: {'p1': [5, -1, -1, -1], 'p2': []},
        );
        final move = PossibleMove(pieceIndex: 0, newPosition: 8);
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![0], 8);
        expect(newState.diceRoll, isNull); // Dice roll consumed
        expect(newState.canRollAgain, isFalse);
        expect(newState.currentTurnPlayerId, 'p2'); // Turn passes
        expect(newState.currentRollCount, 0);
      });

      test('moving token onto home path (p1)', () {
        // P1 entry to home path is field 50. Home path starts 51.
        final state = createMoveTokenTestState(
          diceRoll: 3, // e.g. from 49 to 51 (hp index 0)
          pieces: {'p1': [49, -1, -1, -1], 'p2': []},
        );
        // newPosition is 50 (field before home path) + 1 (step) + 1 (step into home path) = 51+0
        final move = PossibleMove(pieceIndex: 0, newPosition: GameService.homePathBaseIndexP1 + 1); // 49->50->hp0->hp1
        final newState = gameService.moveToken(state, move);
        
        expect(newState.pieces['p1']![0], GameService.homePathBaseIndexP1 + 1);
        expect(newState.currentTurnPlayerId, 'p2'); // Turn passes
      });

      test('moving token into home (finished) position (p1)', () {
        final state = createMoveTokenTestState(
          diceRoll: 2, // e.g. from HP field 5 (51+4) to Home (57 or homeIndexP1)
          pieces: {'p1': [GameService.homePathBaseIndexP1 + 4, -1, -1, -1], 'p2': []},
        );
        final move = PossibleMove(pieceIndex: 0, newPosition: GameService.homeIndexP1);
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![0], GameService.homeIndexP1);
        expect(newState.canRollAgain, isTrue); // Player rolls again after moving a piece home
        expect(newState.currentTurnPlayerId, 'p1'); // Same player's turn
        expect(newState.diceRoll, isNull); // Dice roll is consumed before re-roll
      });

      test('capturing an opponent\'s token', () {
        final state = createMoveTokenTestState(
          diceRoll: 3,
          pieces: {'p1': [0, -1, -1, -1], 'p2': [3, -1, -1, -1]}, // p1 at 0, p2 at 3
        );
        final move = PossibleMove(pieceIndex: 0, newPosition: 3, isCapture: true, capturedPiecePlayerId: 'p2', capturedPieceIndexOnBoard: 3);
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![0], 3);
        expect(newState.pieces['p2']![0], -1); // p2's token sent to base
        expect(newState.canRollAgain, isTrue); // Player rolls again after capture
        expect(newState.currentTurnPlayerId, 'p1'); // Same player's turn
      });

      test('landing on a safe field with opponent token (no capture)', () {
        final p2StartIndex = startIndices['p2']!; // 13 (safe field)
        final state = createMoveTokenTestState(
          diceRoll: 3,
          // p1 token at 10, p2 token at 13 (p2's start, a safe field)
          pieces: {'p1': [10, -1, -1, -1], 'p2': [p2StartIndex, -1, -1, -1]},
        );
        // p1 moves from 10 to 13
        final move = PossibleMove(pieceIndex: 0, newPosition: p2StartIndex, isCapture: false); // isCapture should be false
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![0], p2StartIndex);
        expect(newState.pieces['p2']![0], p2StartIndex); // p2's token remains
        expect(newState.currentTurnPlayerId, 'p2'); // Turn passes (no capture, no 6, no home)
        expect(newState.canRollAgain, isFalse);
      });
      
      test('moving token when dice roll was not 6, turn ends', () {
        final state = createMoveTokenTestState(
          diceRoll: 3, // Not a 6
          pieces: {'p1': [0, -1, -1, -1], 'p2': []},
          canRollAgain: false, // Explicitly false
        );
        final move = PossibleMove(pieceIndex: 0, newPosition: 3);
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![0], 3);
        expect(newState.currentTurnPlayerId, 'p2'); // Turn passes
        expect(newState.canRollAgain, isFalse);
        expect(newState.diceRoll, isNull);
        expect(newState.currentRollCount, 0);
      });

      test('moving token after rolling 6 (but not out of base, not capture, not home), gets re-roll', () {
        final state = createMoveTokenTestState(
          diceRoll: 6,
          pieces: {'p1': [0, -1, -1, -1], 'p2': []},
          currentRollCount: 1, // It's the first 6
          canRollAgain: true, // GameService.rollDice would set this
        );
        final move = PossibleMove(pieceIndex: 0, newPosition: 6); // Regular move with a 6
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![0], 6);
        expect(newState.currentTurnPlayerId, 'p1'); // Same player
        expect(newState.canRollAgain, isTrue);    // Gets to roll again
        expect(newState.diceRoll, 6); // Dice roll value should persist for UI, but a new roll is pending
                                          // Or it could be reset to null, then game controller initiates new roll.
                                          // Current GameService resets it to null in _endTurnOrPrepareReRoll
                                          // Let's assume it's reset if re-roll is true
                                          // No, _endTurnOrPrepareReRoll does not reset diceRoll if canRollAgain is true.
                                          // It's up to rollDice to generate a new one.
        expect(newState.currentRollCount, 1); // Remains 1, as it's for the *next* roll
      });


      test('winning the game (all tokens in home, winnerId is set)', () {
        final p1Home = GameService.homeIndexP1;
        final state = createMoveTokenTestState(
          diceRoll: 1, // Needs 1 to move last piece home
          pieces: {
            'p1': [p1Home, p1Home, p1Home, p1Home - 1], // Last piece is 1 step away
            'p2': [-1, -1, -1, -1]
          },
        );
        final move = PossibleMove(pieceIndex: 3, newPosition: p1Home, isMovingToHome: true);
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![3], p1Home);
        expect(newState.winnerId, 'p1');
        expect(newState.isGameOver, isTrue);
        // Game ends, current turn might not matter or could be the winner's
        // expect(newState.currentTurnPlayerId, 'p1'); // Or could be null, or next player if game didn't auto-stop
      });

       test('moving a token does not affect other players pieces', () {
        final state = createMoveTokenTestState(
          diceRoll: 3,
          pieces: {'p1': [0, -1, -1, -1], 'p2': [15, 16, -1, -1], 'p3': [28], 'p4': [-1]},
        );
        final originalP2Pieces = List.from(state.pieces['p2']!);
        final originalP3Pieces = List.from(state.pieces['p3']!);
        final originalP4Pieces = List.from(state.pieces['p4']!);

        final move = PossibleMove(pieceIndex: 0, newPosition: 3);
        final newState = gameService.moveToken(state, move);

        expect(newState.pieces['p1']![0], 3);
        expect(newState.pieces['p2'], originalP2Pieces);
        expect(newState.pieces['p3'], originalP3Pieces);
        expect(newState.pieces['p4'], originalP4Pieces);
      });

      test('turn ends if player moves a normal piece with non-6 and no other special conditions', () {
        final state = createMoveTokenTestState(
          diceRoll: 3,
          pieces: {'p1': [0], 'p2': []},
          currentTurnPlayerId: 'p1',
          canRollAgain: false, // Explicitly set, though dice roll implies it
        );
        final move = PossibleMove(pieceIndex: 0, newPosition: 3);
        final newState = gameService.moveToken(state, move);

        expect(newState.currentTurnPlayerId, 'p2');
        expect(newState.diceRoll, isNull);
        expect(newState.currentRollCount, 0);
        expect(newState.canRollAgain, isFalse);
      });

    });

    group('isValidMove (implicitly tested by getPossibleMoves)', () {
      // isValidMove is largely an internal helper for getPossibleMoves.
      // Its core logic (like not overshooting home, not landing on own piece)
      // is tested via getPossibleMoves not returning such moves.
      // We can add a few direct tests if specific edge cases for isValidMove itself are needed.

      test('returns true for a valid normal move', () {
        final state = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          diceRoll: 3,
          pieces: {'p1': [0, -1, -1, -1], 'p2': []},
        );
        // This is a conceptual test, as isValidMove is not public.
        // We rely on getPossibleMoves to use it correctly.
        final moves = gameService.getPossibleMoves(state);
        expect(moves.any((m) => m.pieceIndex == 0 && m.newPosition == 3), isTrue);
      });

      test('returns false if trying to land on own piece', () {
        final state = _createBasicGameState(
          currentTurnPlayerId: 'p1',
          diceRoll: 3,
          pieces: {'p1': [0, 3, -1, -1], 'p2': []},
        );
        final moves = gameService.getPossibleMoves(state);
        // Piece 0 cannot move to 3 because piece 1 is there.
        expect(moves.where((m) => m.pieceIndex == 0 && m.newPosition == 3).toList(), isEmpty);
      });
    });

    group('makeAIMove', () {
      final players = [
        Player('p1', 'Player 1', isAI: true), // AI Player
        Player('p2', 'Player 2'),
      ];
      final startIndices = {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39}; // p3, p4 for completeness if needed

      GameState createAIMoveTestState({
        required String currentTurnPlayerId, // Should be AI player's ID
        required int diceRoll,
        required Map<String, List<int>> pieces,
        List<Player>? customPlayers,
      }) {
        return GameState(
          players: customPlayers ?? players,
          startIndex: startIndices,
          currentTurnPlayerId: currentTurnPlayerId,
          diceRoll: diceRoll,
          pieces: Map.from(pieces),
        );
      }

      test('AI should select a valid move if one exists', () {
        // AI (p1) has a token at 0, rolls 3. Only one move: 0 -> 3.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 3,
          pieces: {'p1': [0, -1, -1, -1], 'p2': []},
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 0);
        expect(aiMove.newPosition, 3);
      });

      test('AI prioritizes getting a token out of base with a 6', () {
        // AI (p1) has all tokens at base, rolls 6.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 6,
          pieces: {'p1': [-1, -1, -1, -1], 'p2': [15, 16, 17, 18]},
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.isMoveOutOfBase, isTrue);
        expect(aiMove.newPosition, startIndices['p1']);
        // Check it picked one of the base tokens (could be any index from 0-3)
        expect(state.pieces['p1']![aiMove.pieceIndex], -1);
      });
      
      test('AI prioritizes moving a token into home', () {
        final p1Home = GameService.homeIndexP1;
        // AI (p1) has one token 2 steps from home (at p1Home-2), another token further away. Rolls 2.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 2,
          pieces: {'p1': [p1Home - 2, 10, -1, -1], 'p2': []},
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 0); // The token that can move home
        expect(aiMove.newPosition, p1Home);
        expect(aiMove.isMovingToHome, isTrue);
      });

      test('AI prioritizes capture if available', () {
        // AI (p1) at 0, opponent (p2) at 3. AI rolls 3.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 3,
          pieces: {'p1': [0, 10, -1, -1], 'p2': [3, 15, -1, -1]},
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 0); // Token at 0 moves
        expect(aiMove.newPosition, 3);
        expect(aiMove.isCapture, isTrue);
      });
      
      test('AI prefers moving out of base over a simple forward move if both available with a 6', () {
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 6,
          pieces: {'p1': [-1, 5, -1, -1], 'p2': [15]}, // Token at base, token at 5
        );
        // Possible moves: -1 -> 0 (out of base), 5 -> 11 (forward)
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.isMoveOutOfBase, isTrue); // Prefers getting out
        expect(aiMove.pieceIndex, 0); // Assuming token at index 0 is -1
        expect(aiMove.newPosition, startIndices['p1']);
      });

      test('AI makes a regular move if no higher priority moves exist', () {
        // AI (p1) has token at 5 and 10. Rolls 3. No capture, no home, no base exit.
        // Should pick one of the moves. The logic might pick the furthest or closest.
        // For this test, just ensure it picks *a* valid move.
        // Let's say it moves the piece at 10 (index 1) to 13.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 3,
          pieces: {'p1': [5, 10, -1, -1], 'p2': []},
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        // The AI might choose to move piece at 5 to 8, or piece at 10 to 13.
        // The current AI logic: furthest piece first. 10 is further than 5.
        expect(aiMove!.pieceIndex, 1); // Piece at 10
        expect(aiMove.newPosition, 13);
      });
      
      test('AI returns null if no moves are possible', () {
        // AI (p1) has all tokens at base, rolls 3 (cannot get out).
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 3,
          pieces: {'p1': [-1, -1, -1, -1], 'p2': []},
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNull);
      });

      test('AI considers all its pieces for moves', () {
        // AI (p1) has piece 0 at 49 (can go to home path with 2 -> 51+0), piece 1 at 10 (can move to 12). Rolls 2.
        // Moving to home path is preferred over normal move according to current AI priorities.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 2,
          pieces: {'p1': [49, 10, -1, -1], 'p2': []},
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 0); // Piece at 49
        expect(aiMove.newPosition, GameService.homePathBaseIndexP1 + 0); // Enters home path
      });

      test('AI returns null if all pieces are blocked or home and no valid move exists', () {
        // P1 (AI) has 2 pieces home, 2 pieces on board but blocked by each other.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 2, // Any roll that wouldn't unblock them
          pieces: {
            'p1': [GameService.homeIndexP1, GameService.homeIndexP1, 5, 7], // Piece at 5 is blocked by piece at 7 if dice is 2
            'p2': []
          },
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNull, reason: "AI should have no move if all pieces are home or blocked.");
      });

      test('AI prefers moving into home over capturing an opponent', () {
        // P1 (AI) can move piece 0 into home (55 with roll 2 -> 57)
        // OR P1 can move piece 1 (at 10) to capture p2's piece at 12 with roll 2.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 2,
          pieces: {
            'p1': [GameService.homePathBaseIndexP1 + 4, 10, -1, -1], // Piece 0 is at home path 4 (needs 2 to get home)
            'p2': [12, -1, -1, -1]  // P2 piece at 12
          },
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 0, reason: "AI should prioritize moving piece 0 home.");
        expect(aiMove.isMovingToHome, isTrue);
        expect(aiMove.newPosition, GameService.homeIndexP1);
      });

      test('AI prefers capturing over getting a piece out of base', () {
        // P1 (AI) can move piece 0 (at 2) to capture p2's piece at 5 with roll 3.
        // OR P1 can move piece 1 (at -1, base) out to field 0 with roll 6 (if dice was 6).
        // Let's adjust: dice is 3. P1 can capture or make a regular move with another piece.
        // New scenario: Dice is 6. P1 can get piece 0 out of base OR capture with piece 1.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 6,
          pieces: {
            'p1': [-1, 5, -1, -1], // Piece 0 at base, Piece 1 at 5
            'p2': [11, -1, -1, -1] // P2 piece at 11. P1 piece at 5 can capture with roll 6.
          },
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 1, reason: "AI should prioritize capturing with piece 1.");
        expect(aiMove.isCapture, isTrue);
        expect(aiMove.newPosition, 11);
      });
      
      test('AI prefers getting piece out of base over a less valuable regular move', () {
        // P1 (AI) rolls a 6.
        // Piece 0 is at base (-1). Can move to start (0).
        // Piece 1 is at field 20. Can move to 26.
        // Getting out of base is higher priority.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 6,
          pieces: {
            'p1': [-1, 20, -1, -1],
            'p2': []
          },
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 0, reason: "AI should prioritize getting piece 0 out of base.");
        expect(aiMove.isMoveOutOfBase, isTrue);
        expect(aiMove.newPosition, startIndices['p1']);
      });

      test('AI chooses furthest valid regular move if no other priorities', () {
        // P1 (AI) rolls 3.
        // Piece 0 at 1. Can move to 4.
        // Piece 1 at 10. Can move to 13. (Furthest piece)
        // Piece 2 at 5. Can move to 8.
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 3,
          pieces: {
            'p1': [1, 10, 5, -1],
            'p2': []
          },
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 1, reason: "AI should choose to move the furthest piece (piece 1 at 10).");
        expect(aiMove.newPosition, 13);
      });

      test('Complex: Home > Capture > OutOfBase > Furthest. Scenario: Home available.', () {
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 2,
          pieces: {
            'p1': [
              GameService.homePathBaseIndexP1 + 4, // Piece 0: Can go home (55 -> 57)
              10,                                  // Piece 1: Can capture p2_piece0 (10 -> 12)
              -1,                                  // Piece 2: Can go out of base (if dice was 6)
              20                                   // Piece 3: Regular move (20 -> 22)
            ],
            'p2': [12, -1, -1, -1] // p2_piece0 at 12
          },
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 0, reason: "AI should prioritize HOME.");
        expect(aiMove.isMovingToHome, isTrue);
      });

      test('Complex: Home > Capture > OutOfBase > Furthest. Scenario: Capture available, Home not.', () {
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 2, // Dice roll is 2
          pieces: {
            'p1': [
              GameService.homePathBaseIndexP1 + 3, // Piece 0: Needs 3 to go home, cannot move.
              10,                                  // Piece 1: Can capture p2_piece0 (10 -> 12)
              -1,                                  // Piece 2: Can go out of base (if dice was 6)
              20                                   // Piece 3: Regular move (20 -> 22)
            ],
            'p2': [12, -1, -1, -1] // p2_piece0 at 12
          },
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 1, reason: "AI should prioritize CAPTURE.");
        expect(aiMove.isCapture, isTrue);
      });
      
      test('Complex: Home > Capture > OutOfBase > Furthest. Scenario: OutOfBase available, Home/Capture not.', () {
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 6, // Dice roll is 6
          pieces: {
            'p1': [
              GameService.homePathBaseIndexP1 + 3, // Piece 0: Needs 3 to go home, cannot move.
              10,                                  // Piece 1: Can move to 16 (no capture)
              -1,                                  // Piece 2: Can go out of base
              20                                   // Piece 3: Regular move (20 -> 26)
            ],
            'p2': [18, -1, -1, -1] // p2_piece0 at 18 (not reachable for capture)
          },
        );
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 2, reason: "AI should prioritize OUTOFBASE.");
        expect(aiMove.isMoveOutOfBase, isTrue);
      });

      test('Complex: Home > Capture > OutOfBase > Furthest. Scenario: Only Regular move available.', () {
        final state = createAIMoveTestState(
          currentTurnPlayerId: 'p1',
          diceRoll: 3, // Dice roll is 3
          pieces: {
            'p1': [
              GameService.homePathBaseIndexP1 + 2, // Piece 0: Needs 4 to go home, cannot move
              1,                                   // Piece 1: Can move to 4 (Regular furthest)
              5,                                   // Piece 2: Can move to 8 (Regular)
              GameService.homeIndexP1             // Piece 3: Already home
            ],
            'p2': [15, -1, -1, -1] // p2_piece0 at 15 (not reachable for capture)
          },
        );
        // AI logic should pick piece 2 (at pos 5) to move to 8, as it's "further" than piece 1 (at pos 1)
        // according to the current _getFurthestPieceMove logic if it iterates from end of pieces list.
        // Let's be more specific: piece at 5 is "further" along the board in terms of progress.
        // The AI's "furthest" logic is: `(b.currentPosition > a.currentPosition) ? b : a;` for pieces not in base.
        // So, 5 is greater than 1.
        final aiMove = gameService.makeAIMove(state);
        expect(aiMove, isNotNull);
        expect(aiMove!.pieceIndex, 2, reason: "AI should prioritize FURTHEST regular move (piece at pos 5).");
        expect(aiMove.newPosition, 8);
      });

    });
  });
}
