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

    if (value != 6 || state.currentRollCount >= 3) {
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
    // Prüfen, ob der Zug gültig ist
    if (!isValidMove(playerId, targetIndex)) {
      return false;
    }
    
    if (state.isSafeField(targetIndex, playerId)) {
      _setPosition(playerId, targetIndex);
      return true;
    }
    
    // Gegner schlagen
    for (var opp in state.players.where((p) =>
        p.position == targetIndex && p.id != playerId)) {
      opp.position = state.startIndex[opp.id]!;
    }
    
    _setPosition(playerId, targetIndex);
    return true;
  }

  void _setPosition(String playerId, int pos) {
    state.players.firstWhere((p) => p.id == playerId).position = pos;
  }
  
  /// Prüft, ob ein Zug gültig ist
  bool isValidMove(String playerId, int targetIndex) {
    final player = state.players.firstWhere((p) => p.id == playerId);
    final diceValue = state.lastDiceValue;
    
    // Kein Würfelwert vorhanden
    if (diceValue == null) {
      return false;
    }
    
    // Prüfen, ob der Zug der Würfelzahl entspricht
    final expectedTarget = (player.position + diceValue) % GameState.totalFields;
    return targetIndex == expectedTarget;
  }
  
  /// Berechnet mögliche Züge für den aktuellen Spieler
  List<int> getPossibleMoves() {
    if (state.lastDiceValue == null) {
      return [];
    }
    
    final player = state.players.firstWhere((p) => p.id == state.currentTurnPlayerId);
    final targetPos = (player.position + state.lastDiceValue!) % GameState.totalFields;
    
    return [targetPos];
  }
  
  /// KI-Logik für automatische Züge
  void makeAIMove() {
    if (!state.isCurrentPlayerAI) {
      return;
    }
    
    // Würfeln
    rollDice();
    
    // Wenn kein Würfelwert mehr vorhanden ist (z.B. nach _endTurn), beenden
    if (state.lastDiceValue == null) {
      return;
    }
    
    // Mögliche Züge ermitteln
    final moves = getPossibleMoves();
    if (moves.isEmpty) {
      return;
    }
    
    // Einfache KI-Strategie: Ersten möglichen Zug ausführen
    moveToken(state.currentTurnPlayerId, moves.first);
  }
}
