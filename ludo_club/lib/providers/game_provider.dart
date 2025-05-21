import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/game_service.dart';
import '../services/save_load_service.dart';

class GameProvider extends ChangeNotifier {
  GameState _gameState;
  GameService _gameService;
  final SaveLoadService _saveLoadService = SaveLoadService();
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
  Future<bool> moveToken(int tokenIndex, int targetPosition) async {
    if (_isAnimating) return false;
    
    _isAnimating = true;
    notifyListeners();
    
    // Bewegungsanimation simulieren
    await Future.delayed(const Duration(milliseconds: 500));
    
    final result = _gameService.moveToken(_gameState.currentTurnPlayerId, tokenIndex, targetPosition);
    _isAnimating = false;
    notifyListeners();
    
    return result;
  }
  
  /// Gibt mögliche Züge für den aktuellen Spieler zurück
  List<int> getPossibleMoves() {
    return _gameService.getPossibleMoves();
  }
  
  /// Gibt detaillierte Informationen zu möglichen Zügen zurück (tokenIndex und targetPosition)
  List<Map<String, int>> getPossibleMoveDetails() {
    return _gameService.getPossibleMoveDetails();
  }
  
  /// Startet ein neues Spiel mit den angegebenen Spielern
  void startNewGame(List<Player> players) {
    final startIndices = <String, int>{
      'player1': 0,    // Rot (oben)
      'player2': 10,   // Blau (rechts)
      'player3': 20,   // Grün (unten)
      'player4': 30,   // Gelb (links)
    };
    
    _gameState = GameState(
      startIndex: startIndices,
      players: players,
      currentTurnPlayerId: players.first.id,
      winnerId: null, // Kein Gewinner bei Spielstart
    );
    
    _gameService = GameService(_gameState);
    notifyListeners();
  }

  /// Speichert das aktuelle Spiel
  Future<bool> saveGame({String? customName}) async {
    return await _saveLoadService.saveGame(_gameState, customName: customName);
  }
  
  /// Lädt ein gespeichertes Spiel nach Index
  Future<bool> loadGame(int index) async {
    final loadedState = await _saveLoadService.loadGame(index);
    if (loadedState != null) {
      _gameState = loadedState;
      _gameService = GameService(_gameState);
      notifyListeners();
      return true;
    }
    return false;
  }
  
  /// Löscht ein gespeichertes Spiel
  Future<bool> deleteGame(int index) async {
    final result = await _saveLoadService.deleteGame(index);
    if (result) {
      notifyListeners(); // Benachrichtige Listener, falls die UI aktualisiert werden muss
    }
    return result;
  }
  
  /// Gibt eine Liste aller gespeicherten Spielstände zurück
  Future<List<Map<String, dynamic>>> getSavedGames() async {
    return await _saveLoadService.getSavedGames();
  }
}
