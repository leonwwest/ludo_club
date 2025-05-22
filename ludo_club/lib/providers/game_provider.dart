import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/game_service.dart';
import '../services/save_load_service.dart';
import '../services/audio_service.dart';

class GameProvider extends ChangeNotifier {
  GameState _gameState;
  GameService _gameService;
  final SaveLoadService _saveLoadService = SaveLoadService();
  final AudioService _audioService = AudioService();
  bool _isAnimating = false;
  
  GameProvider(this._gameState) : _gameService = GameService(_gameState) {
    _initAudio();
  }
  
  /// Initialisiert den Audio-Service
  Future<void> _initAudio() async {
    await _audioService.init();
  }
  
  GameState get gameState => _gameState;
  bool get isAnimating => _isAnimating;
  
  /// Würfelt und aktualisiert den Spielzustand
  Future<int> rollDice() async {
    if (_isAnimating) return 0;
    
    _isAnimating = true;
    notifyListeners();
    
    // Würfelanimation simulieren
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Würfel-Sound abspielen
    await _audioService.playDiceSound();
    
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
    
    final currentPlayer = _gameState.currentPlayer;
    final currentPosition = currentPlayer.tokenPositions[tokenIndex];
    
    final result = _gameService.moveToken(_gameState.currentTurnPlayerId, tokenIndex, targetPosition);
    
    if (result) {
      // Verschiedene Sounds basierend auf der Art des Zuges
      if (targetPosition == GameState.finishedPosition) {
        // Figur hat das Ziel erreicht
        await _audioService.playFinishSound();
        
        // Wenn Spieler gewonnen hat
        if (_gameState.winner != null) {
          await _audioService.playVictorySound();
        }
      } else {
        // Prüfe, ob eine gegnerische Figur geschlagen wurde
        bool hasCapture = false;
        for (var player in _gameState.players) {
          if (player.id != currentPlayer.id) {
            for (int i = 0; i < player.tokenPositions.length; i++) {
              if (player.tokenPositions[i] == GameState.basePosition &&
                  player.tokenPositions[i] != currentPosition) {
                hasCapture = true;
                break;
              }
            }
          }
          if (hasCapture) break;
        }
        
        if (hasCapture) {
          // Gegnerische Figur geschlagen
          await _audioService.playCaptureSound();
        } else {
          // Normale Bewegung
          await _audioService.playMoveSound();
        }
      }
    }
    
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
  
  /// Aktiviert oder deaktiviert alle Soundeffekte
  void setSoundEnabled(bool enabled) {
    _audioService.setSoundEnabled(enabled);
    notifyListeners();
  }
  
  /// Gibt zurück, ob Sound aktiviert ist
  bool get isSoundEnabled => _audioService.isSoundEnabled;
  
  /// Setzt die Lautstärke der Soundeffekte
  void setVolume(double volume) {
    _audioService.setVolume(volume);
    notifyListeners();
  }
  
  /// Gibt die aktuelle Lautstärke zurück
  double get volume => _audioService.volume;
  
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
  
  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
