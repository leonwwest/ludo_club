import 'dart:math';
import '../models/game_state.dart';

class GameService {
  final GameState state;
  final Random _rng = Random();

  GameService(this.state);

  /// Würfelt und steuert die Turn-Logik (max. 3 Würfe bei 6).
  int rollDice() {
    // Bei mehr als 3 Würfen wechselt der Spieler
    if (state.currentRollCount >= 3) {
      _endTurn();
      return 0;
    }
    
    final value = _rng.nextInt(6) + 1;
    state.lastDiceValue = value;
    state.currentRollCount++;

<<<<<<< HEAD
    if (value != 6 && state.currentRollCount >= 1) {
      _endTurn();
    } else if (state.currentRollCount >= 3) {
      _endTurn();
=======
    // Nur zum nächsten Spieler wechseln wenn:
    // 1. Keine 6 gewürfelt wurde ODER
    // 2. Wir bereits zum dritten Mal gewürfelt haben
    if (value != 6 || state.currentRollCount >= 3) {
      // Prüfe zuerst, ob der Spieler mit diesem Würfelwert überhaupt ziehen kann
      final possibleMoves = getPossibleMoveDetails();
      if (possibleMoves.isEmpty) {
        _endTurn();
      }
>>>>>>> ea7bbac21da49f2d140669fcb86aadd27e68f98e
    }
    
    return value;
  }

  void _endTurn() {
    state.currentRollCount = 0;
    state.lastDiceValue = null;
    final idx = state.players.indexWhere((p) => p.id == state.currentTurnPlayerId);
    final next = (idx + 1) % state.players.length;
    state.currentTurnPlayerId = state.players[next].id;
  }

<<<<<<< HEAD
  /// Bewegt eine Figur, wendet Safe- und Schlag-Logik an.
  bool moveToken(String playerId, int targetIndex) {
    final player = state.players.firstWhere((p) => p.id == playerId);
    final diceValue = state.lastDiceValue;
    
    if (diceValue == null) return false;
    
    // Wenn die Figur im Heimatfeld ist und eine 6 gewürfelt wurde
    if (player.position == -1) {
      if (diceValue == 6) {
        // Prüfen, ob noch Figuren im Heimatfeld sind
        if (player.moveFromHome()) {
          // Setze die Figur auf das Startfeld
          player.position = state.startIndex[playerId]!;
          return true;
        }
        return false;
      }
      return false;
    }
    
    // Berechne die neue Position
    int newPos = (player.position + diceValue) % GameState.totalFields;
    
    // Überprüfe, ob die Zielposition mit der erwarteten übereinstimmt
    if (newPos != targetIndex) return false;
    
    // Animation für die Bewegung
    _animateMovement(player.position, newPos);
    
    // Überprüfe auf andere Spieler auf dem Zielfeld
    if (!state.isSafeField(newPos, playerId)) {
      for (var other in state.players.where((p) => p.id != playerId)) {
        if (other.position == newPos) {
          // Schlage die Figur und schicke sie zurück zum Heimatfeld
          _animateMovement(other.position, -1); // Animation zurück ins Haus
          other.position = -1;
          other.homePositions[0] = -1; // Eine Figur zurück ins Heimatfeld
        }
      }
    }
    
    // Bewege die Figur
    player.position = newPos;
    
    // Wenn keine 6 gewürfelt wurde oder 3 Würfe erreicht sind, beende den Zug
    if (diceValue != 6 || state.currentRollCount >= 3) {
      _endTurn();
    }
    
    return true;
  }
  
  // Simuliert eine Animation für die Bewegung
  void _animateMovement(int from, int to) {
    // Diese Methode dient nur als Platzhalter für die Animation
    // In einer realen Implementierung würde hier die Animation gesteuert werden
  }
  
  /// Prüft, ob ein Zug gültig ist
  bool isValidMove(String playerId, int targetIndex) {
    final player = state.players.firstWhere((p) => p.id == playerId);
    final diceValue = state.lastDiceValue;
    
    if (diceValue == null) return false;
    
    // Wenn Figur im Heimatfeld ist, prüfe ob eine 6 gewürfelt wurde
    if (player.position == -1) {
      return diceValue == 6 && player.homePositions.contains(-1) && 
             targetIndex == state.startIndex[playerId];
    }
    
    // Berechne die erwartete Zielposition
    final expectedTarget = (player.position + diceValue) % GameState.totalFields;
    return targetIndex == expectedTarget;
  }
  
  /// Berechnet mögliche Züge für den aktuellen Spieler
  List<int> getPossibleMoves() {
    if (state.lastDiceValue == null) return [];
    
    final player = state.players.firstWhere((p) => p.id == state.currentTurnPlayerId);
    final diceValue = state.lastDiceValue!;
    
    // Wenn die Figur im Heimatfeld ist
    if (player.position == -1) {
      // Nur bei einer 6 kann die Figur herausgesetzt werden
      if (diceValue == 6 && player.homePositions.contains(-1)) {
        return [state.startIndex[player.id]!];
      }
      return [];
    }
    
    // Berechne die mögliche Zielposition
    final targetPos = (player.position + diceValue) % GameState.totalFields;
    return [targetPos];
=======
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
        // Berechne nächste Position auf dem Hauptspielfeld
        int nextPos = (currentPos + diceValue) % GameState.totalFields;
        
        // Prüfe, ob Figur in den Heimweg einbiegen soll
        int playerStartField = state.startIndex[currentPlayer.id]!;
        int distanceFromStart = (currentPos - playerStartField + GameState.totalFields) % GameState.totalFields;
        int distanceAfterMove = (distanceFromStart + diceValue) % GameState.totalFields;
        
        // Wenn die Figur eine volle Runde gedreht hat und am eigenen Startfeld vorbeikommt
        if (distanceFromStart < GameState.totalFields - diceValue && distanceAfterMove >= GameState.totalFields - diceValue) {
          // Figur biegt in den Heimweg ein
          int homePathPosition = GameState.totalFields + (diceValue - (GameState.totalFields - distanceFromStart) - 1);
          if (homePathPosition < GameState.totalFields + GameState.homePathLength) {
            nextPos = homePathPosition;
          }
        }
        
        targetPos = nextPos;
      } 
      // Figur ist auf dem Heimweg
      else if (currentPos < GameState.totalFields + GameState.homePathLength) {
        // Berechne nächste Position auf dem Heimweg
        int homePos = currentPos + diceValue;
        
        // Prüfe, ob die Figur das Ziel erreicht
        if (homePos == GameState.totalFields + GameState.homePathLength - 1 + diceValue) {
          targetPos = GameState.finishedPosition;
        } 
        // Prüfe, ob die Figur über das Ziel hinausschießt (ungültiger Zug)
        else if (homePos >= GameState.totalFields + GameState.homePathLength) {
          continue;
        } 
        else {
          targetPos = homePos;
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
    
    final player = state.players.firstWhere((p) => p.id == playerId);
    
    // Prüfen, ob der Zug gültig ist
    if (!isValidMove(playerId, tokenIndex, targetPosition)) {
      return false;
    }
    
    // Aktuelle Position der Figur
    final currentPosition = player.tokenPositions[tokenIndex];
    
    // Wenn Figur auf das Hauptspielfeld kommt
    if (currentPosition == GameState.basePosition && targetPosition == state.startIndex[playerId]) {
      _setTokenPosition(playerId, tokenIndex, targetPosition);
      
      // Wenn eine 6 gewürfelt wurde und eine Figur aus der Basis geholt wird,
      // darf der Spieler nochmal würfeln, daher keinen Spielerwechsel
      // ist bereits in rollDice() berücksichtigt
      return true;
    }
    
    // Wenn die Figur ins Ziel kommt
    if (targetPosition == GameState.finishedPosition) {
      _setTokenPosition(playerId, tokenIndex, targetPosition);
      
      // Prüfe, ob der Spieler gewonnen hat (alle Figuren im Ziel)
      bool hasWon = player.tokenPositions.every((pos) => pos == GameState.finishedPosition);
      if (hasWon) {
        // Spielgewinn-Logik hier implementieren
        state.winnerId = player.id;
      }
      
      // Nach einem Zug ins Ziel darf der Spieler nochmal würfeln (Bonus-Regel)
      // Alternativ: _endTurn(); // Falls diese Regel nicht gewünscht ist
      return true;
    }
    
    // Wenn targetPosition auf dem Hauptspielfeld ist, prüfe auf gegnerische Figuren
    if (targetPosition < GameState.totalFields) {
      if (!state.isSafeField(targetPosition, playerId)) {
        // Suche nach gegnerischen Figuren auf der Zielposition
        for (var opponent in state.players.where((p) => p.id != playerId)) {
          for (int i = 0; i < opponent.tokenPositions.length; i++) {
            if (opponent.tokenPositions[i] == targetPosition) {
              // Gegnerische Figur zurück zur Basis schicken
              _setTokenPosition(opponent.id, i, GameState.basePosition);
            }
          }
        }
      }
    }
    
    // Figur bewegen
    _setTokenPosition(playerId, tokenIndex, targetPosition);
    
    // Falls keine 6 gewürfelt wurde, ist der nächste Spieler dran
    // Oder falls es der dritte Wurf war
    // Diese Logik ist bereits in rollDice() implementiert
    
    return true;
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
>>>>>>> ea7bbac21da49f2d140669fcb86aadd27e68f98e
  }
  
  /// KI-Logik für automatische Züge
  void makeAIMove() {
    if (!state.isCurrentPlayerAI) return;
    
<<<<<<< HEAD
    // Zuerst würfeln
=======
    // Würfeln
    final diceValue = rollDice();
    
    // Wenn kein Würfelwert mehr vorhanden ist (z.B. nach _endTurn), beenden
>>>>>>> ea7bbac21da49f2d140669fcb86aadd27e68f98e
    if (state.lastDiceValue == null) {
      rollDice();
    }
    
<<<<<<< HEAD
    final moves = getPossibleMoves();
    if (moves.isEmpty) return;
    
    // Einfache KI-Strategie: Führe den ersten möglichen Zug aus
    moveToken(state.currentTurnPlayerId, moves.first);
=======
    // Mögliche Züge ermitteln
    final moves = getPossibleMoveDetails();
    if (moves.isEmpty) {
      _endTurn();
      return;
    }
    
    // Einfache KI-Strategie: Priorität der Züge
    // 1. Figur ins Ziel bringen
    // 2. Gegnerische Figur schlagen
    // 3. Figur aus der Basis herausbringen
    // 4. Figur auf dem Hauptspielfeld vorwärts bewegen
    
    // Suche einen Zug, der eine Figur ins Ziel bringt
    for (var move in moves) {
      if (move['targetPosition'] == GameState.finishedPosition) {
        moveToken(state.currentTurnPlayerId, move['tokenIndex']!, move['targetPosition']!);
        return;
      }
    }
    
    // Suche einen Zug, der eine gegnerische Figur schlägt
    for (var move in moves) {
      final targetPos = move['targetPosition']!;
      if (targetPos < GameState.totalFields && !state.isSafeField(targetPos, state.currentTurnPlayerId)) {
        bool canHitOpponent = false;
        
        for (var opponent in state.players.where((p) => p.id != state.currentTurnPlayerId)) {
          if (opponent.tokenPositions.any((pos) => pos == targetPos)) {
            canHitOpponent = true;
            break;
          }
        }
        
        if (canHitOpponent) {
          moveToken(state.currentTurnPlayerId, move['tokenIndex']!, move['targetPosition']!);
          return;
        }
      }
    }
    
    // Suche einen Zug, der eine Figur aus der Basis herausbringt
    for (var move in moves) {
      final player = state.currentPlayer;
      final tokenIndex = move['tokenIndex']!;
      
      if (player.tokenPositions[tokenIndex] == GameState.basePosition) {
        moveToken(state.currentTurnPlayerId, move['tokenIndex']!, move['targetPosition']!);
        return;
      }
    }
    
    // Fallback: Ersten möglichen Zug ausführen
    if (moves.isNotEmpty) {
      moveToken(state.currentTurnPlayerId, moves[0]['tokenIndex']!, moves[0]['targetPosition']!);
    }
>>>>>>> ea7bbac21da49f2d140669fcb86aadd27e68f98e
  }
}
