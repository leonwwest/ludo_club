import 'dart:math';
import '../models/game_state.dart';

class GameService {
  final GameState state;
  final Random _rng; // Made non-final to allow potential reassignment for advanced mocking if ever needed
  bool _bonusTurnAwarded = false;
  int _consecutiveSixesCount = 0;
  int? debugNextDiceValue; // Public field for testing

  GameService(this.state, [Random? random]) : _rng = random ?? Random();

  /// Würfelt und steuert die Turn-Logik (max. 3 Würfe bei 6).
  int rollDice() {
    if (_bonusTurnAwarded) {
      _bonusTurnAwarded = false; 
      state.currentRollCount = 0; // Bereits in moveToken, aber zur Sicherheit hier auch für den Wurfablauf
      _consecutiveSixesCount = 0; // Bonus turn resets consecutive sixes count
    } else if (state.currentRollCount >= 3 && state.lastDiceValue != 6 && _consecutiveSixesCount < 3) {
      // This condition handles the case where a player has had 3 or more rolls in their turn sequence,
      // and the last roll was NOT a 6. This means their turn should end if they are not on a 6-rolling streak.
      // If _consecutiveSixesCount is 3, that's handled specifically below.
      _endTurn();
      return 0; 
    }

    final value = debugNextDiceValue ?? _rng.nextInt(6) + 1;
    if (debugNextDiceValue != null) {
      debugNextDiceValue = null; // Reset after use
    }
    state.lastDiceValue = value;
    // state.currentRollCount is incremented by general turn logic, not specifically for sixes.
    // Let's use _consecutiveSixesCount for specific 6-related logic.
    // state.currentRollCount will track total rolls in a turn if multiple 6s are rolled OR a bonus is awarded.

    if (value == 6) {
      _consecutiveSixesCount++;
      state.currentRollCount++; // A roll happened
      if (_consecutiveSixesCount == 3) {
        // Third consecutive 6. Turn ends, no move for this 6.
        _endTurn(); // This will reset _consecutiveSixesCount and currentRollCount
        return value; // Return 6, but turn has ended. getPossibleMoveDetails will be empty.
      }
      // Not the third six, player continues. currentRollCount is already incremented.
      // No call to _endTurn() here. Player gets another roll implicitly.
    } else {
      _consecutiveSixesCount = 0; // Reset if not a 6
      state.currentRollCount++;   // A roll happened

      // Standard turn ending condition if not a 6:
      // (No specific bonus from this roll itself, e.g. capture/home, that's handled by _bonusTurnAwarded from moveToken)
      final possibleMoves = getPossibleMoveDetails();
      if (possibleMoves.isEmpty) {
        _endTurn();
      } else {
        // If moves are possible, but it's not a 6, the turn ends.
        // (The "roll again on 6" is handled by *not* calling _endTurn above if value is 6 and not 3rd six)
        _endTurn();
      }
    }
    
    // If _endTurn() was called, state.lastDiceValue will be null.
    // If the turn continues (due to 1st/2nd six), state.lastDiceValue is the current 'value'.
    return value;
  }

  void _endTurn() {
    state.currentRollCount = 0;
    _consecutiveSixesCount = 0; // Reset for the next player
    state.lastDiceValue = null; 
    final idx = state.players.indexWhere((p) => p.id == state.currentTurnPlayerId);
    final next = (idx + 1) % state.players.length;
    state.currentTurnPlayerId = state.players[next].id;
    _bonusTurnAwarded = false; 
  }

  /// Gibt mögliche Züge mit Token-Index und Zielposition zurück
  List<Map<String, int>> getPossibleMoveDetails() {
    final List<Map<String, int>> moves = [];
    final Player currentPlayer = state.currentPlayer;
    final int? diceValue = state.lastDiceValue;
    
    if (diceValue == null) {
      return [];
    }
    
    for (int tokenIndex = 0; tokenIndex < currentPlayer.tokenPositions.length; tokenIndex++) {
      final int currentPos = currentPlayer.tokenPositions[tokenIndex];
      
      // Wenn Figur in der Basis ist, benötigen wir eine 6, um sie herauszubewegen
      if (currentPos == GameState.basePosition) {
        if (diceValue == 6) {
          moves.add({
            'tokenIndex': tokenIndex,
            'targetPosition': state.startIndex[currentPlayer.id]!,
          });
        }
        continue;
      }
      
      // Figur ist im Ziel - kann nicht bewegt werden
      if (currentPos == GameState.finishedPosition) {
        continue;
      }
      
      // Berechne Zielposition
      int targetPos;
      
      // Figur ist auf dem Hauptspielfeld
      if (currentPos < GameState.totalFields) {
        int playerStartField = state.startIndex[currentPlayer.id]!;
        int stepsTakenOnBoard = (currentPos - playerStartField + GameState.totalFields) % GameState.totalFields;

        if (stepsTakenOnBoard + diceValue >= GameState.totalFields) {
            // Token is eligible to enter the home path
            int stepsIntoHomePath = (stepsTakenOnBoard + diceValue) - GameState.totalFields;

            if (stepsIntoHomePath < GameState.homePathLength) {
                targetPos = GameState.totalFields + stepsIntoHomePath; // e.g., 40, 41, 42, 43
            } else {
                // Overshot the home path, invalid move for this token
                continue; 
            }
        } else {
            // Stays on main board
            targetPos = (currentPos + diceValue) % GameState.totalFields;
        }
      }
      // Figur ist auf dem Heimweg
      else if (currentPos >= GameState.totalFields && currentPos < GameState.totalFields + GameState.homePathLength) {
        // currentPos is already like 40, 41, 42, 43
        // diceValue is, e.g., 1, 2, 3, 4, 5, 6
        
        // Position within the home path (0, 1, 2, 3)
        int currentHomePathSlot = currentPos - GameState.totalFields;
        int targetHomePathSlot = currentHomePathSlot + diceValue;

        if (targetHomePathSlot == GameState.homePathLength) { // Exact landing on finish spot
             targetPos = GameState.finishedPosition;
        } else if (targetHomePathSlot < GameState.homePathLength) { // Moves within home path
            targetPos = GameState.totalFields + targetHomePathSlot;
        } else { // Overshot finish
            continue; // Invalid move
        }
      }
      else {
        // Sollte nicht vorkommen, aber zur Sicherheit
        continue;
      }
      
      // Prüfe, ob Zielposition von eigener Figur besetzt ist
      bool isSelfBlocked = currentPlayer.tokenPositions.any((pos) => 
        pos != currentPos && pos == targetPos && pos != GameState.finishedPosition);
      
      if (!isSelfBlocked) {
        moves.add({
          'tokenIndex': tokenIndex,
          'targetPosition': targetPos,
        });
      }
    }
    
    return moves;
  }

  /// Vereinfachte Methode, die nur die Zielpositionen zurückgibt
  List<int> getPossibleMoves() {
    return getPossibleMoveDetails().map((move) => move['targetPosition']!).toList();
  }

  /// Bewegt eine Figur, wendet Safe- und Schlag-Logik an.
  bool moveToken(String playerId, int tokenIndex, int targetPosition) {
    if (playerId != state.currentTurnPlayerId) return false;
    // Prevent move if it's the third six penalty
    if (_consecutiveSixesCount == 3 && state.lastDiceValue == 6) {
        // Although rollDice should have ended the turn, this is a safeguard.
        // _endTurn() would have set lastDiceValue to null, so this path might not be hit often.
        return false;
    }

    final player = state.players.firstWhere((p) => p.id == playerId);

    if (!isValidMove(playerId, tokenIndex, targetPosition)) {
      return false;
    }

    final currentPosition = player.tokenPositions[tokenIndex];
    bool tokenCapturedOpponent = false;

    if (currentPosition == GameState.basePosition && targetPosition == state.startIndex[playerId]) {
      // Normal move out of base. If it was a 6, _consecutiveSixesCount is handled in rollDice.
    }

    _setTokenPosition(playerId, tokenIndex, targetPosition);

    if (targetPosition < GameState.totalFields && targetPosition != GameState.basePosition) {
      if (!state.isSafeField(targetPosition, playerId)) {
        for (var opponent in state.players.where((p) => p.id != playerId)) {
          for (int i = 0; i < opponent.tokenPositions.length; i++) {
            if (opponent.tokenPositions[i] == targetPosition) {
              _setTokenPosition(opponent.id, i, GameState.basePosition);
              tokenCapturedOpponent = true;
            }
          }
        }
      }
    }
    
    if (targetPosition == GameState.finishedPosition) {
      _bonusTurnAwarded = true;
      bool hasWon = player.tokenPositions.every((pos) => pos == GameState.finishedPosition);
      if (hasWon) {
        state.winnerId = player.id;
      }
    } else if (tokenCapturedOpponent) {
      _bonusTurnAwarded = true;
    }

    if (_bonusTurnAwarded) {
      state.currentRollCount = 0; 
      state.lastDiceValue = null;
      _consecutiveSixesCount = 0; // Crucial: Bonus turn resets consecutive sixes sequence.
    }
    // The decision to end the turn or continue (e.g. after a 6) is handled by rollDice()
    // based on _bonusTurnAwarded, _consecutiveSixesCount, and the dice value.
    return tokenCapturedOpponent; // Return whether a capture occurred
  }

  void _setTokenPosition(String playerId, int tokenIndex, int pos) {
    state.players.firstWhere((p) => p.id == playerId).tokenPositions[tokenIndex] = pos;
  }
  
  /// Prüft, ob ein Zug gültig ist
  bool isValidMove(String playerId, int tokenIndex, int targetPosition) {
    final moves = getPossibleMoveDetails();
    
    // Suche nach einem Zug für den angegebenen tokenIndex mit der entsprechenden Zielposition
    return moves.any((move) => 
        move['tokenIndex'] == tokenIndex && 
        move['targetPosition'] == targetPosition);
  }
  
  /// KI-Logik für automatische Züge
  void makeAIMove() {
    if (!state.isCurrentPlayerAI || state.isGameOver) return;

    String aiPlayerId = state.currentTurnPlayerId; // Merken, wer dran ist
    bool firstIteration = true;

    do {
      if (!firstIteration) {
        // Wenn dies nicht die erste Iteration ist (d.h. AI hat einen Bonus-Zug oder eine 6 gewürfelt),
        // dann muss die AI erneut würfeln.
        // _bonusTurnAwarded wird in rollDice() konsumiert.
        // currentRollCount wurde ggf. in moveToken oder durch 6er-Serie in rollDice gehandhabt.
      }
      firstIteration = false;
      
      // 1. Würfeln
      // rollDice() handhabt jetzt _bonusTurnAwarded (konsumiert es, wenn true)
      // und entscheidet, ob der Zug potenziell endet.
      rollDice();

      // Wenn lastDiceValue null ist, wurde der Zug in rollDice() beendet (z.B. keine Züge, 3x gewürfelt ohne 6).
      // Oder currentTurnPlayerId hat sich geändert.
      if (state.lastDiceValue == null || state.currentTurnPlayerId != aiPlayerId) {
        break; 
      }
      
      // 2. Mögliche Züge ermitteln
      final possibleMoves = getPossibleMoveDetails();
      if (possibleMoves.isEmpty) {
        // Wenn keine Züge möglich sind, hat rollDice() _endTurn() bereits aufgerufen (oder sollte es tun).
        // Der Zug der KI ist hier definitiv vorbei.
        if(state.currentTurnPlayerId == aiPlayerId) { // Nur wenn der Zug nicht schon durch rollDice beendet wurde
             _endTurn(); // Sicherstellen, dass der Zug beendet wird
        }
        break;
      }

      // 3. KI-Strategie für Zugauswahl (bleibt im Wesentlichen gleich)
      Map<String, int>? chosenMove;
      // Priorität 1: Figur ins Ziel bringen
      chosenMove = possibleMoves.firstWhere((move) => move['targetPosition'] == GameState.finishedPosition, orElse: () => {});
      if (chosenMove.isEmpty) chosenMove = null;

      // Priorität 2: Gegnerische Figur schlagen
      if (chosenMove == null) {
        chosenMove = possibleMoves.firstWhere((move) {
          final targetPos = move['targetPosition']!;
          if (targetPos < GameState.totalFields && !state.isSafeField(targetPos, aiPlayerId)) {
            for (var opponent in state.players.where((p) => p.id != aiPlayerId)) {
              if (opponent.tokenPositions.any((pos) => pos == targetPos)) return true;
            }
          }
          return false;
        }, orElse: () => {});
        if (chosenMove.isEmpty) chosenMove = null;
      }
      
      // Priorität 3: Figur aus der Basis herausbringen (nur mit 6, was getPossibleMoveDetails sicherstellt)
      if (chosenMove == null) {
         chosenMove = possibleMoves.firstWhere((move) {
            final player = state.players.firstWhere((p) => p.id == aiPlayerId);
            return player.tokenPositions[move['tokenIndex']!] == GameState.basePosition;
         }, orElse: () => {});
         if (chosenMove.isEmpty) chosenMove = null;
      }

      // Fallback: Ersten möglichen Zug ausführen
      chosenMove ??= possibleMoves.first;

      // 4. Zug ausführen
      moveToken(aiPlayerId, chosenMove['tokenIndex']!, chosenMove['targetPosition']!);

      // 5. Prüfung für Weitermachen:
      // - _bonusTurnAwarded wurde in moveToken gesetzt (Schlagen/Ziel).
      // - ODER: Letzter Wurf war eine 6 und currentRollCount < 3 (oder unbegrenzte 6er).
      //   rollDice() beendet den Zug nicht, wenn eine 6 gewürfelt wurde und currentRollCount < 3.
      //   Wenn currentRollCount >= 3 ist und eine 6 gewürfelt wurde, geht es auch weiter.
      //   Die Hauptsache ist, dass _endTurn() nicht aufgerufen wurde.

      // Die Schleife geht weiter, wenn:
      // a) _bonusTurnAwarded (durch moveToken) -> wird am Anfang von rollDice() konsumiert.
      // b) state.lastDiceValue == 6 (und Zug wurde nicht durch 3x Würfeln beendet)
      // c) Der currentTurnPlayerId immer noch die AI ist.
      
      // Wenn ein Bonus durch Schlagen/Ziel gewährt wurde, ist _bonusTurnAwarded = true.
      // Wenn eine 6 gewürfelt wurde, die keinen expliziten Bonus-Reset macht,
      // dann ist state.lastDiceValue == 6 und state.currentRollCount relevant.
      // rollDice() wird den Zug nicht beenden, wenn eine 6 gewürfelt wurde (es sei denn, es gibt keine Züge).

      if (state.currentTurnPlayerId != aiPlayerId || state.isGameOver) {
        // Spieler hat gewechselt (Zug wurde in moveToken oder rollDice beendet) oder Spiel ist vorbei
        break;
      }
      
      // Wenn wir hier sind, ist die AI immer noch dran.
      // Wenn _bonusTurnAwarded true ist, wird die Schleife fortgesetzt und rollDice() wird es konsumieren.
      // Wenn state.lastDiceValue == 6, wird die Schleife fortgesetzt und rollDice() wird einen neuen Wurf erlauben.
      // Wenn keines von beiden zutrifft, sollte der Zug bereits beendet sein (currentTurnPlayerId hätte sich geändert).
      // Die Bedingung der do-while Schleife prüft dies.

    } while (state.currentTurnPlayerId == aiPlayerId && !state.isGameOver);
     _bonusTurnAwarded = false; // Ensure reset if AI loop is exited for other reasons
  }
}
