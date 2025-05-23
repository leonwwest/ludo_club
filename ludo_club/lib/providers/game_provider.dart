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
    notifyListeners();
    
    // Wenn der aktuelle Spieler eine KI ist, automatischen Zug ausführen
    if (_gameState.isCurrentPlayerAI) {
      _isAiThinking = true;
      notifyListeners(); // Update UI to show AI is thinking

      await Future.delayed(const Duration(milliseconds: 500)); // Simulate AI thinking time
      _gameService.makeAIMove();
      
      _isAiThinking = false;
      // The notifyListeners() below will update the UI after AI move is done
      // and thinking indicator should be gone.
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
    // The actual pawn movement animation is handled in GameScreen.
    // This delay was for a simulated non-visual movement.
    // await Future.delayed(const Duration(milliseconds: 500)); // Keep or remove based on desired pacing
    
    // final currentPlayer = _gameState.currentPlayer; // Not needed here for capture logic
    // final currentPosition = currentPlayer.tokenPositions[tokenIndex]; // Not needed for capture logic
    
    // `result` is true if a capture occurred
    final bool captureOccurred = _gameService.moveToken(_gameState.currentTurnPlayerId, tokenIndex, targetPosition);
    
    // Sound logic & Effect Triggers
    if (targetPosition == GameState.finishedPosition) {
      await _audioService.playFinishSound();
      // Set flags for visual "reached home" effect
      _showReachedHomeEffect = true;
      _reachedHomePlayerId = _gameState.currentTurnPlayerId; // Player who made the move
      _reachedHomeTokenIndex = tokenIndex;                 // Token that reached home

      if (_gameState.winner != null) {
        await _audioService.playVictorySound();
      }
    } else if (captureOccurred) {
      await _audioService.playCaptureSound();
      // Set flags for visual capture effect
      _showCaptureEffect = true;
      _captureEffectBoardIndex = targetPosition;
    } else {
      // Normal move, no capture, not reaching finish
      await _audioService.playMoveSound();
    }
    
    // _isAnimating is set to false by GameScreen's pawn animation completion.
    // If moveToken is called directly without pawn animation (e.g. very fast AI),
    // then _isAnimating might need to be managed here too.
    // However, the current structure has GameScreen manage _isAnimating for pawn moves.
    // If no pawn animation, then this method should manage _isAnimating.
    // For now, assuming pawn animation in GameScreen handles this.
    // If called from GameScreen animation end, _isAnimating is already false there.
    notifyListeners(); // Inform UI about game state changes and potential capture effect
    
    return captureOccurred; // Return capture status
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
      'player1': 0,   // Gelb (oben)
      'player2': 10,  // Blau (rechts)
      'player3': 20,  // Grün (unten)
      'player4': 30,  // Rot (links)
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
  
  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
