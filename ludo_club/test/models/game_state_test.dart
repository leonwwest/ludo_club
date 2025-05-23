import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/models/player.dart';

void main() {
  group('GameState', () {
    // Test data
    final startIndices = <String, int>{
      'player1': 0,
      'player2': 10,
      'player3': 20,
      'player4': 30,
    };
    final players = [
      Player('player1', 'Player 1'),
      Player('player2', 'Player 2', isAI: true),
      Player('player3', 'Player 3'),
      Player('player4', 'Player 4', isAI: true),
    ];

    group('isSafeField', () {
      test('should return true for a player\'s start field', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
        );
        expect(gameState.isSafeField(0), isTrue);
        expect(gameState.isSafeField(10), isTrue);
        expect(gameState.isSafeField(20), isTrue);
        expect(gameState.isSafeField(30), isTrue);
      });

      test('should return false for a non-start field', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
        );
        expect(gameState.isSafeField(1), isFalse);
        expect(gameState.isSafeField(11), isFalse);
      });
    });

    group('copy', () {
      test('should copy all fields correctly', () {
        final originalState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
          pieces: {'player1': [0, 1], 'player2': [10]},
          diceRoll: 6,
          winnerId: 'player2',
        );
        final copiedState = originalState.copy();

        expect(copiedState.startIndex, originalState.startIndex);
        expect(copiedState.players.length, originalState.players.length);
        for (int i = 0; i < originalState.players.length; i++) {
          expect(copiedState.players[i].id, originalState.players[i].id);
          expect(copiedState.players[i].name, originalState.players[i].name);
          expect(copiedState.players[i].isAI, originalState.players[i].isAI);
        }
        expect(copiedState.currentTurnPlayerId, originalState.currentTurnPlayerId);
        expect(copiedState.pieces, originalState.pieces);
        expect(copiedState.diceRoll, originalState.diceRoll);
        expect(copiedState.winnerId, originalState.winnerId);
      });

      test('modifications to copied state should not affect original state', () {
        final originalState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
          pieces: {'player1': [0, 1], 'player2': [10]},
        );
        final copiedState = originalState.copy();

        // Modify pieces in copied state
        copiedState.pieces['player1'] = [2, 3];
        expect(originalState.pieces['player1'], [0, 1]);
        expect(copiedState.pieces['player1'], [2, 3]);

        // Modify players list in copied state (e.g., change a player's AI status)
        // Note: Player objects themselves are copied by reference if not handled,
        // but the list itself should be a new instance.
        // For a true deep copy of players, Player.copy() would be needed if Player was mutable.
        // Assuming Player is immutable or copy is handled within GameState.copy if necessary.
        // If Player has mutable fields that GameState.copy doesn't deep copy, this test might need adjustment.
        if (copiedState.players.isNotEmpty) {
          copiedState.players[0] = Player('newPlayer', 'New Player');
        }
        expect(originalState.players[0].id, 'player1');


        // Modify currentTurnPlayerId in copied state
        copiedState.currentTurnPlayerId = 'player2';
        expect(originalState.currentTurnPlayerId, 'player1');
        expect(copiedState.currentTurnPlayerId, 'player2');

        // Modify dice roll
        copiedState.diceRoll = 3;
        expect(originalState.diceRoll, isNull); // Assuming it was null initially
        expect(copiedState.diceRoll, 3);

        // Modify winner
        copiedState.winnerId = 'player1';
        expect(originalState.winnerId, isNull);  // Assuming it was null initially
        expect(copiedState.winnerId, 'player1');

      });
    });

    group('getters', () {
      test('currentPlayer should return the correct player object', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player2',
        );
        expect(gameState.currentPlayer?.id, 'player2');
        expect(gameState.currentPlayer?.name, 'Player 2');
      });

      test('isCurrentPlayerAI should return true for AI player', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player2', // Player 2 is AI
        );
        expect(gameState.isCurrentPlayerAI, isTrue);
      });

      test('isCurrentPlayerAI should return false for human player', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1', // Player 1 is human
        );
        expect(gameState.isCurrentPlayerAI, isFalse);
      });

      test('winner should return the correct player object when there is a winner', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
          winnerId: 'player4',
        );
        expect(gameState.winner?.id, 'player4');
        expect(gameState.winner?.name, 'Player 4');
      });

      test('winner should return null when there is no winner', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
        );
        expect(gameState.winner, isNull);
      });

      test('isGameOver should return true when there is a winner', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
          winnerId: 'player3',
        );
        expect(gameState.isGameOver, isTrue);
      });

      test('isGameOver should return false when there is no winner', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
        );
        expect(gameState.isGameOver, isFalse);
      });
    });
  });
}
