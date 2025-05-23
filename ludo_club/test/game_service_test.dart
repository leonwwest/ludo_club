// This is the content for ludo_club/test/game_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/services/game_service.dart';

// Helper function to create a GameState for tests
GameState _createGameStateForTest({
  required List<Player> players,
  required String currentTurnPlayerId,
  int? lastDiceValue,
  int currentRollCount = 0,
  Map<String, int>? startIndices,
}) {
  final defaultStartIndices = <String, int>{
    'player1': 0,
    'player2': 10,
    'player3': 20,
    'player4': 30,
  };
  return GameState(
    players: players,
    currentTurnPlayerId: currentTurnPlayerId,
    lastDiceValue: lastDiceValue,
    currentRollCount: currentRollCount,
    startIndex: startIndices ?? defaultStartIndices,
  );
}

void main() {
  group('GameService Tests', () {
    late GameState gameState;
    late GameService gameService;

    // Common setup for player start indices
    final Map<String, int> startIndices = {
      'player1': 0,
      'player2': 10,
    };

    group('rollDice() Tests', () {
      test('Dice rolls within 1-6 range', () {
        final player1 = Player('player1', 'Player 1');
        gameState = _createGameStateForTest(
          players: [player1],
          currentTurnPlayerId: 'player1',
          startIndices: startIndices,
        );
        gameService = GameService(gameState);

        for (int i = 0; i < 50; i++) {
          int roll = gameService.rollDice();
          expect(roll, greaterThanOrEqualTo(1));
          expect(roll, lessThanOrEqualTo(6));
        }
      });

      test('Bonus roll on first or second six keeps turn', () {
        final player1 = Player('player1', 'P1', initialPositions: [0, -1, -1, -1]); // Token on board for a possible move
        gameState = _createGameStateForTest(
          players: [player1],
          currentTurnPlayerId: 'player1',
          startIndices: startIndices,
        );
        gameService = GameService(gameState);
        String originalPlayerId = gameState.currentTurnPlayerId;

        // Simulate 1st six
        gameService.debugNextDiceValue = 6;
        gameService.rollDice();
        
        expect(gameState.lastDiceValue, 6);
        expect(gameState.currentTurnPlayerId, originalPlayerId, reason: "Turn should not change on 1st six if moves are possible or can get out.");
        expect(gameService.debugNextDiceValue, isNull); // Should be reset
        expect(gameState.currentRollCount, 1, reason: "currentRollCount should be 1 after 1st six.");

        // Simulate 2nd six
        // A move would typically be made here. For this test, we assume a move was made or not needed,
        // and the turn continues for the second roll.
        // If a piece was moved from base, currentRollCount might be 1 as per current gameService.moveToken logic for 6s.
        // If a piece on board moved, currentRollCount is incremented by rollDice.
        // The key is that _consecutiveSixesCount is 1 internally.
        
        gameService.debugNextDiceValue = 6;
        gameService.rollDice(); // This is the 2nd six roll
        
        expect(gameState.lastDiceValue, 6);
        expect(gameState.currentTurnPlayerId, originalPlayerId, reason: "Turn should not change on 2nd six.");
        expect(gameState.currentRollCount, 2, reason: "currentRollCount should be 2 after 2nd six.");
      });

      test('Three consecutive sixes end turn', () {
        final player1 = Player('player1', 'P1', initialPositions: [0, 1, 2, 3]); // All tokens on board
        final player2 = Player('player2', 'P2');
        gameState = _createGameStateForTest(
          players: [player1, player2],
          currentTurnPlayerId: 'player1',
          startIndices: startIndices,
        );
        gameService = GameService(gameState);
        String originalPlayerId = gameState.currentTurnPlayerId;

        // 1st six
        gameService.debugNextDiceValue = 6;
        gameService.rollDice();
        // Assume player makes a move (not strictly needed for this test if just testing rollDice effect)
        // e.g., gameService.moveToken('player1', 0, 6); // P1 moves 0 to 6

        // 2nd six
        gameService.debugNextDiceValue = 6;
        gameService.rollDice();
        // Assume player makes another move
        // e.g., gameService.moveToken('player1', 0, 12); // P1 moves 6 to 12

        // 3rd six
        gameService.debugNextDiceValue = 6;
        gameService.rollDice();
        
        expect(gameState.lastDiceValue, isNull, reason: "Turn ends, so lastDiceValue should be nullified by _endTurn.");
        expect(gameState.currentTurnPlayerId, isNot(originalPlayerId), reason: "Turn should change after 3rd six.");
        expect(gameState.currentTurnPlayerId, 'player2', reason: "Should be player2's turn.");
        expect(gameState.currentRollCount, 0, reason: "_endTurn resets currentRollCount.");
      });
    });

    group('Moving Pawn Out of Base Tests', () {
      test('Cannot move from base without a 6', () {
        final player1 = Player('player1', 'Player 1'); // All tokens at -1 by default
        gameState = _createGameStateForTest(
          players: [player1],
          currentTurnPlayerId: 'player1',
          lastDiceValue: 5, // Not a 6
          startIndices: startIndices,
        );
        gameService = GameService(gameState);
        
        final moves = gameService.getPossibleMoveDetails();
        expect(moves, isEmpty);
      });

      test('Can move from base with a 6', () {
        final player1 = Player('player1', 'Player 1');
        gameState = _createGameStateForTest(
          players: [player1],
          currentTurnPlayerId: 'player1',
          lastDiceValue: 6,
          startIndices: startIndices,
        );
        gameService = GameService(gameState);

        final moves = gameService.getPossibleMoveDetails();
        expect(moves, isNotEmpty);
        expect(moves.length, greaterThanOrEqualTo(1)); 
        expect(moves.any((move) => move['targetPosition'] == startIndices['player1']!), isTrue);
      });

      test('Successfully moves pawn from base on a 6', () {
        final player1 = Player('player1', 'Player 1', initialPositions: List.filled(GameState.tokensPerPlayer, GameState.basePosition));
        gameState = _createGameStateForTest(
          players: [player1],
          currentTurnPlayerId: 'player1',
          lastDiceValue: 6, // Crucial for getPossibleMoveDetails
          startIndices: startIndices,
        );
        gameService = GameService(gameState);
        
        // Simulate that a 6 was just rolled by rollDice() for this player
        gameState.currentRollCount = 1; // After one roll (the 6)
        // gameService._consecutiveSixesCount would be 1 (private)

        final moves = gameService.getPossibleMoveDetails();
        expect(moves, isNotEmpty, reason: "Should find moves to get out of base with a 6");
        final moveOutOfBase = moves.firstWhere((m) => m['targetPosition'] == startIndices['player1']!, orElse: () => {});
        expect(moveOutOfBase, isNotEmpty, reason: "Should be a move to the start field");
        
        final tokenIndexToMove = moveOutOfBase['tokenIndex']!;
        // moveToken returns bool for capture, not general success.
        final bool captureOccurred = gameService.moveToken('player1', tokenIndexToMove, startIndices['player1']!);
        
        expect(captureOccurred, isFalse); // No capture when moving from base
        expect(gameState.players.firstWhere((p) => p.id == 'player1').tokenPositions[tokenIndexToMove], startIndices['player1']!);
        
        // If a 6 was rolled, and it wasn't the 3rd, turn should not end.
        // rollDice() handles not calling _endTurn.
        // moveToken for "out of base" does not grant an additional bonus turn (like capture does).
        // So _bonusTurnAwarded remains false. currentRollCount remains as set by rollDice (e.g. 1).
        expect(gameState.currentRollCount, 1); 
        expect(gameState.lastDiceValue, 6); 
        // If moving out of base with a 6, _consecutiveSixesCount becomes 1.
        // The turn doesn't end due to the 6.
        // moveToken itself doesn't grant a bonus for this specific action.
        // The next rollDice call will continue from currentRollCount = 1.
      });
    });
    
    group('Basic Movement & Capture Tests', () {
      test('Pawn moves correctly on board', () {
        final player1 = Player('player1', 'Player 1', initialPositions: [5, -1, -1, -1]);
        gameState = _createGameStateForTest(
          players: [player1],
          currentTurnPlayerId: 'player1',
          lastDiceValue: 3,
          startIndices: startIndices,
        );
        gameService = GameService(gameState);
        
        // Simulate that a 3 was just rolled. If it's not a 6, rollDice calls _endTurn if moves are possible.
        // So after this move, currentRollCount should be 0 and lastDiceValue null.
        final bool captureOccurred = gameService.moveToken('player1', 0, 8); // 5 + 3 = 8
        
        expect(captureOccurred, isFalse); 
        expect(gameState.players.first.tokenPositions[0], 8);
        expect(gameState.currentRollCount, 0); // Turn ended as it wasn't a 6
        expect(gameState.lastDiceValue, isNull);
      });

      test('Pawn captures opponent token', () {
        final player1 = Player('player1', 'P1', initialPositions: [5, -1, -1, -1]);
        final player2 = Player('player2', 'P2', initialPositions: [8, -1, -1, -1]); 
        gameState = _createGameStateForTest(
          players: [player1, player2],
          currentTurnPlayerId: 'player1',
          lastDiceValue: 3, 
          startIndices: startIndices,
        );
        // Simulate currentRollCount before this move (e.g., after a non-6 roll)
        // If lastDiceValue was 3, rollDice would have set currentRollCount to 1.
        // This is important because capture should reset it to 0.
        gameState.currentRollCount = 1; 
        gameService = GameService(gameState);

        final bool captureOccurred = gameService.moveToken('player1', 0, 8);
        
        expect(captureOccurred, isTrue);
        expect(gameState.players.firstWhere((p) => p.id == 'player1').tokenPositions[0], 8);
        expect(gameState.players.firstWhere((p) => p.id == 'player2').tokenPositions[0], GameState.basePosition);
        
        expect(gameState.currentRollCount, 0, reason: "Capture should grant a bonus turn, resetting currentRollCount.");
        expect(gameState.lastDiceValue, isNull, reason: "Bonus turn requires a new roll.");
      });

      test('Pawn cannot capture on a safe spot', () {
        final p1Start = startIndices['player1']!; // 0
        final p2Start = startIndices['player2']!; // 10 (safe spot)
        
        // Player 1 at field 7, Player 2 at field 10 (P2's start, a safe spot). Player 1 rolls a 3.
        final player1 = Player('player1', 'P1', initialPositions: [p1Start + 7, -1, -1, -1]); // P1 at 7
        final player2 = Player('player2', 'P2', initialPositions: [p2Start, -1, -1, -1]);      // P2 at 10
        
        gameState = _createGameStateForTest(
          players: [player1, player2],
          currentTurnPlayerId: 'player1',
          lastDiceValue: 3, // To move from 7 to 10
          startIndices: startIndices,
        );
        // If dice was 3, currentRollCount would be 1 before moveToken, then 0 after due to _endTurn.
        gameState.currentRollCount = 1; 
        gameService = GameService(gameState);

        // Verify field 10 is a safe spot
        expect(gameState.isSafeField(p2Start, 'player1'), isTrue);

        final bool captureOccurred = gameService.moveToken('player1', 0, p2Start);
        
        expect(captureOccurred, isFalse); 
        expect(gameState.players.firstWhere((p) => p.id == 'player1').tokenPositions[0], p2Start);
        expect(gameState.players.firstWhere((p) => p.id == 'player2').tokenPositions[0], p2Start); // Still there
        
        // No bonus from capture. Since dice was 3 (not a 6), turn should end.
        // moveToken doesn't call _endTurn. rollDice does.
        // After a non-6 roll that results in a move (no capture), GameService.rollDice calls _endTurn.
        // So, by the time we check, currentRollCount should be 0.
        expect(gameState.currentRollCount, 0, reason: "Turn should end as it was not a 6 and no capture bonus.");
        expect(gameState.lastDiceValue, isNull);
      });
    });

    group('Home Path Logic Tests', () {
      setUp(() {
        // Common setup for home path tests, player1's turn
        final player1 = Player('player1', 'P1');
        gameState = _createGameStateForTest(
          players: [player1],
          currentTurnPlayerId: 'player1',
          startIndices: startIndices, // player1 starts at 0
        );
        gameService = GameService(gameState);
      });

      test('getPossibleMoveDetails - Entering home path correctly', () {
        // Player 'player1' (starts at 0) has a token at field 38.
        // Dice roll is 3. Expected target: home path slot 1 (board index 41).
        gameState.players.first.tokenPositions = [38, -1, -1, -1];
        gameState.lastDiceValue = 3;
        
        final moves = gameService.getPossibleMoveDetails();
        
        expect(moves, isNotEmpty);
        final specificMove = moves.firstWhere((m) => m['tokenIndex'] == 0, orElse: () => {});
        expect(specificMove['targetPosition'], GameState.totalFields + 1, 
          reason: "Token at 38, dice 3. Expected: 38+3=41. stepsTaken=(38-0+40)%40=38. stepsIntoHome=(38+3)-40=1. target=40+1=41.");
      });

      test('getPossibleMoveDetails - Moving within home path correctly', () {
        // Player 'player1' has a token at home path slot 0 (board index 40).
        // Dice roll is 2. Expected target: home path slot 2 (board index 42).
        gameState.players.first.tokenPositions = [GameState.totalFields + 0, -1, -1, -1]; // At 40
        gameState.lastDiceValue = 2;

        final moves = gameService.getPossibleMoveDetails();
        
        expect(moves, isNotEmpty);
        final specificMove = moves.firstWhere((m) => m['tokenIndex'] == 0, orElse: () => {});
        expect(specificMove['targetPosition'], GameState.totalFields + 2); // Expected: 40 + 2 = 42
      });
      
      test('getPossibleMoveDetails - Exact roll to finish token', () {
        // Player 'player1' has a token at home path slot 2 (board index 42).
        // GameState.homePathLength is 4. Dice roll is 2.
        // Expected target: GameState.finishedPosition (99).
        // (Slot 2 means 0, 1, *2*. Needs 2 more to reach slot 4 (finish))
        gameState.players.first.tokenPositions = [GameState.totalFields + 2, -1, -1, -1]; // At 42
        gameState.lastDiceValue = 2; // Needs 2 to finish (slot 2 + 2 = slot 4)

        final moves = gameService.getPossibleMoveDetails();
        
        expect(moves, isNotEmpty);
        final specificMove = moves.firstWhere((m) => m['tokenIndex'] == 0, orElse: () => {});
        expect(specificMove['targetPosition'], GameState.finishedPosition);
      });

      test('getPossibleMoveDetails - Cannot overshoot finish', () {
        // Player 'player1' has a token at home path slot 2 (board index 42).
        // GameState.homePathLength is 4. Dice roll is 3. (Would be slot 2 + 3 = slot 5, which is > 4)
        gameState.players.first.tokenPositions = [GameState.totalFields + 2, -1, -1, -1]; // At 42
        gameState.lastDiceValue = 3;

        final moves = gameService.getPossibleMoveDetails();
        // Expect no move for this token, or that this specific token's move is not present
        final specificTokenMoves = moves.where((m) => m['tokenIndex'] == 0).toList();
        expect(specificTokenMoves, isEmpty, 
          reason: "Should not be able to overshoot the finish line.");
      });

      test('getPossibleMoveDetails - Token before home path entry does not enter with insufficient roll', () {
        // Player 'player1' token at 37. Dice roll is 1. Should move to 38, not home path.
        gameState.players.first.tokenPositions = [37, -1, -1, -1];
        gameState.lastDiceValue = 1;
        
        final moves = gameService.getPossibleMoveDetails();
        expect(moves, isNotEmpty);
        final specificMove = moves.firstWhere((m) => m['tokenIndex'] == 0, orElse: () => {});
        expect(specificMove['targetPosition'], 38);
      });
    });
  });
}
