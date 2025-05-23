import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/game_service.dart';
import '../services/save_load_service.dart';
import '../services/audio_service.dart';
import '../services/statistics_service.dart'; // Import StatisticsService

class GameProvider extends ChangeNotifier {
  GameState _gameState;
  GameService _gameService;
  final SaveLoadService _saveLoadService = SaveLoadService();
  final AudioService _audioService = AudioService();
  final StatisticsService _statisticsService = StatisticsService(); // Add StatisticsService instance
  bool _isAnimating = false; // For pawn movement animation primarily

  // Capture effect state
  bool _showCaptureEffect = false;
  int? _captureEffectBoardIndex;
  // Color? _capturedPawnColor; // Optional: for coloring the effect like the captured pawn

  // Reached Home effect state
  bool _showReachedHomeEffect = false;
  String? _reachedHomePlayerId;
  int? _reachedHomeTokenIndex;

  // AI Thinking state
  bool _isAiThinking = false;

  GameProvider(this._gameState) : _gameService = GameService(_gameState) {
    _initAudio();
  }
  
  /// Initialisiert den Audio-Service
  Future<void> _initAudio() async {
    await _audioService.init();
  }
  
  GameState get gameState => _gameState;
  bool get isAnimating => _isAnimating; // For pawn movement

  // Getters for capture effect
  bool get showCaptureEffect => _showCaptureEffect;
  int? get captureEffectBoardIndex => _captureEffectBoardIndex;
  // Color? get capturedPawnColor => _capturedPawnColor; // Optional

  // Getters for Reached Home effect
  bool get showReachedHomeEffect => _showReachedHomeEffect;
  String? get reachedHomePlayerId => _reachedHomePlayerId;
  int? get reachedHomeTokenIndex => _reachedHomeTokenIndex;

  // Getter for AI Thinking state
  bool get isAiThinking => _isAiThinking;

  /// Clears capture effect flags. Called by UI after animation.
  void clearCaptureEffect() {
    _showCaptureEffect = false;
    _captureEffectBoardIndex = null;
    // _capturedPawnColor = null;
  }

  /// Clears reached home effect flags. Called by UI after animation.
  void clearReachedHomeEffect() {
    _showReachedHomeEffect = false;
    _reachedHomePlayerId = null;
    _reachedHomeTokenIndex = null;
  }
  
  set isAnimating(bool value) { // Setter for GameScreen to control general animation blocking
    _isAnimating = value;
    // notifyListeners(); // Avoid notifying if this is set frequently during animation setup
  }

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
    
    if (result == 6) {
      await _statisticsService.incrementSixesRolled(_gameState.currentPlayer.name);
    }
    notifyListeners();
    
    // Wenn der aktuelle Spieler eine KI ist, automatischen Zug ausführen
    if (_gameState.isCurrentPlayerAI) {
      _isAiThinking = true;
      notifyListeners(); // Update UI to show AI is thinking

      await Future.delayed(const Duration(milliseconds: 500)); // Simulate AI thinking time
      _gameService.makeAIMove();
      
      _isAiThinking = false;
      notifyListeners();
    }
    
    return result;
  }
  
  /// Bewegt eine Spielfigur und aktualisiert Statistiken
  Future<void> moveToken(int tokenIndex, int targetPosition) async {
    if (_isAnimating) return;
    
    _isAnimating = true;
    // notifyListeners(); // Notifying immediately might be too early if isAnimating is used to block UI before animation setup.
                        // GameScreen sets isAnimating true again in _initiatePawnAnimation.

    final String currentPlayerId = _gameState.currentTurnPlayerId;
    final String currentPlayerName = _gameState.currentPlayer.name;

    // `capturedOpponentId` is the ID of the player whose pawn was captured, or null.
    final String? capturedOpponentId = _gameService.moveToken(currentPlayerId, tokenIndex, targetPosition);
    
    // Sound logic & Effect Triggers & Statistics
    if (targetPosition == GameState.finishedPosition) {
      await _audioService.playFinishSound();
      _showReachedHomeEffect = true;
      _reachedHomePlayerId = currentPlayerId;
      _reachedHomeTokenIndex = tokenIndex;

      if (_gameState.winnerId != null && _gameState.winnerId == currentPlayerId) {
        await _audioService.playVictorySound();
        await _statisticsService.incrementGamesWon(currentPlayerName);
      }
    } else if (capturedOpponentId != null) {
      await _audioService.playCaptureSound();
      _showCaptureEffect = true;
      _captureEffectBoardIndex = targetPosition;
      
      await _statisticsService.incrementPawnsCaptured(currentPlayerName);
      // Need to find the name of the captured opponent.
      final capturedPlayer = _gameState.players.firstWhere((p) => p.id == capturedOpponentId, orElse: () => Player("unknown","Unknown"));
      if (capturedPlayer.id != "unknown") { // Ensure player was found
           await _statisticsService.incrementPawnsLost(capturedPlayer.name);
      }
    } else {
      await _audioService.playMoveSound();
    }
    
    // _isAnimating is set to false by GameScreen's pawn animation completion.
    notifyListeners();
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
      'player1': 0,
      'player2': 10,
      'player3': 20,
      'player4': 30,
    };
    
    // Setze die Startpositionen der Spieler auf ihre Heimatfelder
    for (var player in players) {
      player.tokenPositions = List.filled(GameState.tokensPerPlayer, GameState.basePosition);
    }
    
    _gameState = GameState(
      startIndex: startIndices,
      players: players,
      currentTurnPlayerId: players.first.id,
      winnerId: null,
    );
    
    _gameService = GameService(_gameState);

    // Record game played for all players
    final playerNames = players.map((p) => p.name).toList();
    _statisticsService.recordGamePlayed(playerNames).catchError((e) {
        print("Error recording game played stats: $e");
    }); // Log error, don't block UI

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
