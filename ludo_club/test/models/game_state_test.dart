import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';

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
        expect(gameState.isSafeField(0, 'player1'), isTrue);
        expect(gameState.isSafeField(10, 'player1'), isTrue);
        expect(gameState.isSafeField(20, 'player1'), isTrue);
        expect(gameState.isSafeField(30, 'player1'), isTrue);
      });

      test('should return false for a non-start field', () {
        final gameState = GameState(
          startIndex: startIndices,
          players: players,
          currentTurnPlayerId: 'player1',
        );
        expect(gameState.isSafeField(1, 'player1'), isFalse);
        expect(gameState.isSafeField(11, 'player1'), isFalse);
      });
    });

    group('copy', () {
      test('should copy all fields correctly', () {
        final testPlayers = [
          Player('player1', 'Player 1', initialPositions: [0, 1]),
          Player('player2', 'Player 2', initialPositions: [10], isAI: true),
        ];
        final originalState = GameState(
          startIndex: startIndices,
          players: testPlayers, 
          currentTurnPlayerId: 'player1',
          lastDiceValue: 6,
          winnerId: 'player2',
        );
        final copiedState = originalState.copy();

        expect(copiedState.startIndex, originalState.startIndex);
        expect(copiedState.players.length, originalState.players.length);
        for (int i = 0; i < originalState.players.length; i++) {
          expect(copiedState.players[i].id, originalState.players[i].id);
          expect(copiedState.players[i].name, originalState.players[i].name);
          expect(copiedState.players[i].isAI, originalState.players[i].isAI);
          expect(copiedState.players[i].tokenPositions, originalState.players[i].tokenPositions);
        }
        expect(copiedState.currentTurnPlayerId, originalState.currentTurnPlayerId);
        expect(copiedState.lastDiceValue, originalState.lastDiceValue);
        expect(copiedState.winnerId, originalState.winnerId);
      });

      test('modifications to copied state should not affect original state', () {
        final testPlayersForModification = [
          Player('player1', 'Player 1', initialPositions: [0, 1]),
          Player('player2', 'Player 2', isAI: true), // Default token positions (all base)
        ];
        final originalState = GameState(
          startIndex: startIndices,
          players: testPlayersForModification,
          currentTurnPlayerId: 'player1',
        );
        final copiedState = originalState.copy();

        final player1Copied = copiedState.players.firstWhere((p) => p.id == 'player1');
        player1Copied.tokenPositions = [2, 3];
        
        final player1Original = originalState.players.firstWhere((p) => p.id == 'player1');
        expect(player1Original.tokenPositions, [0, 1]); // Verify original is unchanged
        expect(player1Copied.tokenPositions, [2, 3]);

        if (copiedState.players.length > 1) { // Ensure there is a player at index 0 to modify
          copiedState.players[0] = Player('newPlayer', 'New Player'); // This actually replaces player1 in copiedState
           expect(originalState.players[0].id, 'player1'); // Original list's first player should still be 'player1'
        }
       

        copiedState.currentTurnPlayerId = 'player2';
        expect(originalState.currentTurnPlayerId, 'player1');
        expect(copiedState.currentTurnPlayerId, 'player2');

        copiedState.lastDiceValue = 3;
        expect(originalState.lastDiceValue, isNull);
        expect(copiedState.lastDiceValue, 3);

        copiedState.winnerId = 'player1';
        expect(originalState.winnerId, isNull);
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
        expect(gameState.currentPlayer.id, 'player2');
        expect(gameState.currentPlayer.name, 'Player 2');
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
