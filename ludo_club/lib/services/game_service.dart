import 'dart:math';
import '../models/game_state.dart';

class GameService {
  final GameState state;
  final Random _rng = Random();

  GameService(this.state);

  /// Würfelt und steuert die Turn-Logik (max. 3 Würfe bei 6).
  int rollDice() {
    if (state.currentRollCount >= 3) {
      _endTurn();
      return 0;
    }
    
    final value = _rng.nextInt(6) + 1;
    state.lastDiceValue = value;
    state.currentRollCount++;

    if (value != 6 && state.currentRollCount >= 1) {
      _endTurn();
    } else if (state.currentRollCount >= 3) {
      _endTurn();
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
  }
  
  /// KI-Logik für automatische Züge
  void makeAIMove() {
    if (!state.isCurrentPlayerAI) return;
    
    // Zuerst würfeln
    if (state.lastDiceValue == null) {
      rollDice();
    }
    
    final moves = getPossibleMoves();
    if (moves.isEmpty) return;
    
    // Einfache KI-Strategie: Führe den ersten möglichen Zug aus
    moveToken(state.currentTurnPlayerId, moves.first);
  }
}
