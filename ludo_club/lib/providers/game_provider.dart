import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../logic/ludo_game_logic.dart';
import '../services/save_load_service.dart';
import '../services/audio_service.dart';
<<<<<<< HEAD
import '../services/statistics_service.dart'; // Import StatisticsService
import 'dart:math';
=======
import '../services/statistics_service.dart';
>>>>>>> archive-ludo-logic-update

class GameProvider extends ChangeNotifier {
  GameState _gameState;
  late LudoGame _ludoGame; // Added
  final SaveLoadService _saveLoadService = SaveLoadService();
  final AudioService _audioService = AudioService();
  final StatisticsService _statisticsService = StatisticsService(); // Add StatisticsService instance
  bool isAnimating = false; // Made public, removed unnecessary_getters_setters

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
  
<<<<<<< HEAD
  GameState get gameState => _gameState;
  // bool get isAnimating => _isAnimating; // Removed getter
=======
  // GameState get gameState => _gameState; // Keep for now, will update later
  GameState get gameState {
    // Update _gameState with the latest from _ludoGame before returning
    _gameState.currentTurnPlayerId = _ludoGame.currentPlayer;
    _gameState.lastDiceValue = _ludoGame.diceValue;
    // Note: WinnerId is updated in movePiece
    return _gameState;
  }
  bool get isAnimating => _isAnimating; // For pawn movement
>>>>>>> archive-ludo-logic-update

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
  
  /// Würfelt und aktualisiert den Spielzustand
  Future<int> rollDice() async {
    if (isAnimating) return 0; // Use public field
    
    isAnimating = true; // Use public field
    notifyListeners();
    
    // Würfelanimation simulieren
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Würfel-Sound abspielen
    await _audioService.playDiceSound();
    
<<<<<<< HEAD
    final result = _gameService.rollDice();
    isAnimating = false; // Use public field
=======
    final result = _ludoGame.rollDice(); // Use _ludoGame
    _gameState.lastDiceValue = _ludoGame.diceValue; // Update GameState
    _gameState.currentTurnPlayerId = _ludoGame.currentPlayer; // Update GameState

    _isAnimating = false;
>>>>>>> archive-ludo-logic-update
    
    if (result == 6) {
      // Update statistics call
      await _statisticsService.incrementSixesRolled(_gameState.players.firstWhere((p) => p.id == _ludoGame.currentPlayer).name);
    }
    notifyListeners();
    
<<<<<<< HEAD
    // Wenn der aktuelle Spieler eine KI ist, automatischen Zug ausführen
    if (_gameState.isCurrentPlayerAI) {
      _isAiThinking = true;
      notifyListeners(); // Update UI to show AI is thinking

      await Future.delayed(const Duration(milliseconds: 500)); // Simulate AI thinking time
      _gameService.makeAIMove();
      
      _isAiThinking = false;
      notifyListeners();
    }
    _handlePotentialAIMove(); // Call AI move handler after dice roll & notify
=======
    // AI triggering logic removed for now
>>>>>>> archive-ludo-logic-update
    
    return result;
  }
  
  /// Bewegt eine Spielfigur und aktualisiert Statistiken
<<<<<<< HEAD
  Future<void> moveToken(int tokenIndex, int targetPosition) async {
    if (isAnimating) return; // Use public field
    
    isAnimating = true; // Use public field
    // notifyListeners(); // Notifying immediately might be too early if isAnimating is used to block UI before animation setup.
                        // GameScreen sets isAnimating true again in _initiatePawnAnimation.
=======
  Future<void> movePiece(Piece pieceToMove) async { // Renamed and signature changed
    if (_isAnimating) return;
    
    _isAnimating = true;
    // notifyListeners(); // Notifying immediately might be too early
>>>>>>> archive-ludo-logic-update

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
    _handlePotentialAIMove(); // Call AI move handler after token move & notify
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
<<<<<<< HEAD
        // print("Error recording game played stats: $e"); // Removed avoid_print
    }); // Log error, don't block UI
=======
      print("Error recording game played stats: $e");
    });
>>>>>>> archive-ludo-logic-update

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

  void _handlePotentialAIMove() {
    if (gameState.isCurrentPlayerAI && !gameState.isGameOver) {
      // Add a small delay for AI moves to make them feel more natural
      Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1000)), () {
        if (gameState.isCurrentPlayerAI && !gameState.isGameOver && !isAnimating) {
          // print('[GameProvider] AI is making a move for player: ${gameState.currentTurnPlayerId}');
          _gameService.makeAIMove();
          notifyListeners();
          _handlePotentialAIMove(); // Check again in case of consecutive AI turns or sixes
        }
      });
    }
  }
}
