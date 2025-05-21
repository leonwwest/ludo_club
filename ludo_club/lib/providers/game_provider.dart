import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/game_service.dart';

class GameProvider extends ChangeNotifier {
  GameState _gameState;
  GameService _gameService;
  bool _isAnimating = false;
  
  GameProvider(this._gameState) : _gameService = GameService(_gameState);
  
  GameState get gameState => _gameState;
  bool get isAnimating => _isAnimating;
  
  /// Würfelt und aktualisiert den Spielzustand
  Future<int> rollDice() async {
    if (_isAnimating) return 0;
    
    _isAnimating = true;
    notifyListeners();
    
    // Würfelanimation simulieren
    await Future.delayed(const Duration(milliseconds: 800));
    
    final result = _gameService.rollDice();
    _isAnimating = false;
    notifyListeners();
    
    // Wenn der aktuelle Spieler eine KI ist, automatischen Zug ausführen
    if (_gameState.isCurrentPlayerAI) {
      await Future.delayed(const Duration(milliseconds: 500));
      _gameService.makeAIMove();
      notifyListeners();
    }
    
    return result;
  }
  
  /// Bewegt eine Spielfigur
  Future<bool> moveToken(int targetIndex) async {
    if (_isAnimating) return false;
    
    _isAnimating = true;
    notifyListeners();
    
    // Bewegungsanimation simulieren
    await Future.delayed(const Duration(milliseconds: 500));
    
    final result = _gameService.moveToken(_gameState.currentTurnPlayerId, targetIndex);
    _isAnimating = false;
    notifyListeners();
    
    return result;
  }
  
  /// Gibt mögliche Züge für den aktuellen Spieler zurück
  List<int> getPossibleMoves() {
    return _gameService.getPossibleMoves();
  }
  
  /// Startet ein neues Spiel mit den angegebenen Spielern
  void startNewGame(List<Player> players) {
    final startIndices = <String, int>{
      'player1': 0,    // Gelb (oben)
      'player2': 5,    // Blau (rechts)
      'player3': 10,   // Grün (unten)
      'player4': 15,   // Rot (links)
    };
    
    // Setze die Startpositionen der Spieler auf ihre Heimatfelder
    for (var player in players) {
      player.position = -1; // -1 bedeutet, dass die Figur im Heimatfeld ist
      player.homePositions = [-1, -1, -1, -1]; // Alle 4 Figuren im Heimatfeld
    }
    
    _gameState = GameState(
      startIndex: startIndices,
      players: players,
      currentTurnPlayerId: players.first.id,
    );
    
    _gameService = GameService(_gameState);
    notifyListeners();
  }
}
