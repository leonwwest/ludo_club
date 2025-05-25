import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../logic/ludo_game_logic.dart';
import '../services/save_load_service.dart';
import '../services/audio_service.dart';
import '../services/statistics_service.dart';

class GameProvider extends ChangeNotifier {
  GameState _gameState;
  late LudoGame _ludoGame; // Added
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
  PlayerColor? _reachedHomePlayerId; // Changed from String?
  int? _reachedHomeTokenIndex; // This might need to be the piece's original index or some stable ID

  GameProvider(GameState initialState) : _gameState = initialState { // Modified constructor
    _ludoGame = LudoGame(); // Initialize _ludoGame
    _gameState.players = initialState.players; // Store players
    _gameState.currentTurnPlayerId = _ludoGame.currentPlayer; // Sync current player
    _initAudio();
  }
  
  /// Initialisiert den Audio-Service
  Future<void> _initAudio() async {
    await _audioService.init();
  }
  
  // GameState get gameState => _gameState; // Keep for now, will update later
  GameState get gameState {
    // Update _gameState with the latest from _ludoGame before returning
    _gameState.currentTurnPlayerId = _ludoGame.currentPlayer;
    _gameState.lastDiceValue = _ludoGame.diceValue;
    // Note: WinnerId is updated in movePiece
    return _gameState;
  }
  bool get isAnimating => _isAnimating; // For pawn movement

  // Getters for capture effect
  bool get showCaptureEffect => _showCaptureEffect;
  int? get captureEffectBoardIndex => _captureEffectBoardIndex;
  // Color? get capturedPawnColor => _capturedPawnColor; // Optional

  // Getters for Reached Home effect
  bool get showReachedHomeEffect => _showReachedHomeEffect;
  PlayerColor? get reachedHomePlayerId => _reachedHomePlayerId; // Changed
  int? get reachedHomeTokenIndex => _reachedHomeTokenIndex;

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
    
    final result = _ludoGame.rollDice(); // Use _ludoGame
    _gameState.lastDiceValue = _ludoGame.diceValue; // Update GameState
    _gameState.currentTurnPlayerId = _ludoGame.currentPlayer; // Update GameState

    _isAnimating = false;
    
    if (result == 6) {
      // Update statistics call
      await _statisticsService.incrementSixesRolled(_gameState.players.firstWhere((p) => p.id == _ludoGame.currentPlayer).name);
    }
    notifyListeners();
    
    // AI triggering logic removed for now
    
    return result;
  }
  
  /// Bewegt eine Spielfigur und aktualisiert Statistiken
  Future<void> movePiece(Piece pieceToMove) async { // Renamed and signature changed
    if (_isAnimating) return;
    
    _isAnimating = true;
    // notifyListeners(); // Notifying immediately might be too early

    final movingPlayerColor = _ludoGame.currentPlayer;
    final movingPlayerMeta = getPlayerMeta(movingPlayerColor);

    // Store opponent pieces' states before move for capture detection
    final opponentPiecesBeforeMove = _ludoGame.pieces.values
        .expand((list) => list)
        .where((p) => p.color != movingPlayerColor)
        .map((p) => Piece(p.color, p.id)..position = p.position) // Correctly copy integer position
        .toList();

    final bool moveSuccessful = _ludoGame.movePiece(pieceToMove);

    if (!moveSuccessful) {
      _isAnimating = false;
      // notifyListeners(); // Maybe notify if a move attempt failed?
      return;
    }

    _gameState.lastDiceValue = _ludoGame.diceValue; // Update GameState
    _gameState.currentTurnPlayerId = _ludoGame.currentPlayer; // Update GameState

    bool captureOccurred = false;
    for (var oldOpponentPiece in opponentPiecesBeforeMove) {
      final newOpponentPiece = _ludoGame.pieces[oldOpponentPiece.color]!
          .firstWhere((p) => p.id == oldOpponentPiece.id);
      
      // Use isInYard getter for capture detection
      if (newOpponentPiece.isInYard && !oldOpponentPiece.isInYard) {
        captureOccurred = true;
        _showCaptureEffect = true;
        
        // Use getVisualPieceInfo for capture effect index
        final VisualPieceInfo movingPieceInfo = _ludoGame.getVisualPieceInfo(pieceToMove);
        if (movingPieceInfo.pathType == PiecePathType.MAIN_PATH) {
          _captureEffectBoardIndex = movingPieceInfo.displayIndex;
        } else {
          // Optional: Decide what to do if capture results in piece not being on main path.
          // For now, null means effect might not be shown or shown globally.
          _captureEffectBoardIndex = null; 
        }

        await _audioService.playCaptureSound();
        final capturedPlayerMeta = getPlayerMeta(newOpponentPiece.color);
        await _statisticsService.incrementPawnsCaptured(movingPlayerMeta.name);
        await _statisticsService.incrementPawnsLost(capturedPlayerMeta.name);
        break; 
      }
    }

    if (pieceToMove.isFinished) { // Use new isFinished getter
      _showReachedHomeEffect = true;
      _reachedHomePlayerId = pieceToMove.color;
      _reachedHomeTokenIndex = pieceToMove.id; 

      await _audioService.playFinishSound();

      // Check win condition using isFinished
      final didWin = _ludoGame.pieces[movingPlayerColor]!
          .every((p) => p.isFinished);

      if (didWin) {
        _gameState.winnerId = movingPlayerColor;
        await _audioService.playVictorySound();
        await _statisticsService.incrementGamesWon(movingPlayerMeta.name);
      }
    } else if (!captureOccurred) {
      await _audioService.playMoveSound();
    }
    
    // _isAnimating is set to false by GameScreen's pawn animation completion.
    notifyListeners();
  }

  /// Gibt mögliche Züge für den aktuellen Spieler zurück (movable pieces)
  List<Piece> getMovablePieces() {
    if (_ludoGame.diceValue == 0) return []; 
    return _ludoGame.getMovablePieces(); // Directly call LudoGame method
  }
  
  // Removed getPossibleMoves and getPossibleMoveDetails
  
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

  // Player Information Getters
  PlayerColor get currentPlayerColor => _ludoGame.currentPlayer;
  int get currentDiceValue => _ludoGame.diceValue;
  List<Piece> get allBoardPieces => _ludoGame.allPieces;
  Player getPlayerMeta(PlayerColor color) => 
      _gameState.players.firstWhere((p) => p.id == color, orElse: () {
        // Fallback for safety, though this should ideally not happen if players are set up correctly.
        print("Error: Player metadata not found for color $color. Returning a default Player object.");
        return Player(color, "Unknown Player", isAI: true);
      });

  /// Startet ein neues Spiel mit den angegebenen Spielern
  void startNewGame(List<Player> playersFromUI) {
    _ludoGame = LudoGame(); // Re-initialize LudoGame with its own player/piece setup
    // LudoGame's constructor should set up its own pieces based on PlayerColor.values
    
    _gameState.players = playersFromUI; // Store UI player list (names, AI status)
    _gameState.currentTurnPlayerId = _ludoGame.currentPlayer; // Sync with LudoGame's starting player
    _gameState.winnerId = null;
    _gameState.lastDiceValue = 0;
    _gameState.currentRollCount = 0;

    // Record game played for all players
    final playerNames = playersFromUI.map((p) => p.name).toList();
    _statisticsService.recordGamePlayed(playerNames).catchError((e) {
      print("Error recording game played stats: $e");
    });

    notifyListeners();
  }

  Future<bool> saveGame({String? customName}) async {
    // TODO: Properly serialize _ludoGame state into _gameState for saving.
    // This requires LudoGame and its components (Piece, PiecePosition) to have toJson methods.
    // For now, saving _gameState which might be missing critical LudoGame state.
    // Example: _gameState.gameLogicState = _ludoGame.toJson();
    print("WARN: Game saving is currently incomplete. LudoGame state is not fully serialized.");
    return await _saveLoadService.saveGame(_gameState, customName: customName);
  }

  Future<bool> loadGame(int index) async {
    final loadedState = await _saveLoadService.loadGame(index);
    if (loadedState != null) {
      _gameState = loadedState;
      // TODO: Properly deserialize _ludoGame state from _gameState.
      // This requires LudoGame and its components to have fromJson factory constructors.
      // For now, _ludoGame is reset to its default initial state upon load.
      // Example: _ludoGame = LudoGame.fromJson(_gameState.gameLogicState);
      _ludoGame = LudoGame(); // Resets game logic to initial state.
      // Attempt to sync some state if available and simple, e.g., current player from loaded _gameState
      // This is highly dependent on what LudoGame.fromJson would do.
      // _ludoGame.currentPlayer = _gameState.currentTurnPlayerId; // This might be problematic if pieces aren't set.
      _gameState.currentTurnPlayerId = _ludoGame.currentPlayer; // More robust: reset to LudoGame's default
      _gameState.lastDiceValue = _ludoGame.diceValue; // Reset dice

      print("WARN: Game loading is currently incomplete. LudoGame state is not fully restored and is reset.");
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
