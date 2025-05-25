import 'package:flutter/foundation.dart'; // For ChangeNotifier & @required
import '../models/game_state.dart' as models;
import '../logic/ludo_game_logic.dart' as logic;
import '../services/save_load_service.dart';
import '../services/audio_service.dart';
import '../services/statistics_service.dart';

class GameProvider extends ChangeNotifier {
  models.GameState _gameState;
  late logic.LudoGame _ludoGame;
  final SaveLoadService _saveLoadService = SaveLoadService();
  final AudioService _audioService = AudioService();
  final StatisticsService _statisticsService = StatisticsService();
  bool _isAnimating = false;

  bool _showCaptureEffect = false;
  int? _captureEffectBoardIndex;

  bool _showReachedHomeEffect = false;
  logic.PlayerColor? _reachedHomePlayerId;
  int? _reachedHomeTokenIndex;

  GameProvider(models.GameState initialState) : _gameState = initialState {
    _ludoGame = logic.LudoGame();
    // Ensure players list from initialState is used for player metadata (name, isAI)
    // LudoGame manages its own pieces internally based on logic.PlayerColor.
    // We need to map UI players (models.Player) to LudoGame's concept if needed for setup,
    // but LudoGame() constructor already initializes pieces for all PlayerColor.values.
    _gameState.players = initialState.players; 
    _gameState.currentTurnPlayerId = _toModelsColor(_ludoGame.currentPlayer); // Sync current player
    _initAudio();
  }

  Future<void> _initAudio() async {
    await _audioService.init();
  }

  // Helper to convert models.PlayerColor to logic.PlayerColor
  logic.PlayerColor _toLogicColor(models.PlayerColor modelsColor) {
    return logic.PlayerColor.values[modelsColor.index];
  }

  // Helper to convert logic.PlayerColor to models.PlayerColor
  models.PlayerColor _toModelsColor(logic.PlayerColor logicColor) {
    return models.PlayerColor.values[logicColor.index];
  }
  
  models.GameState get gameState {
    _gameState.currentTurnPlayerId = _toModelsColor(_ludoGame.currentPlayer);
    _gameState.lastDiceValue = _ludoGame.diceValue;
    return _gameState;
  }
  
  bool get isAnimating => _isAnimating;

  bool get showCaptureEffect => _showCaptureEffect;
  int? get captureEffectBoardIndex => _captureEffectBoardIndex;

  bool get showReachedHomeEffect => _showReachedHomeEffect;
  logic.PlayerColor? get reachedHomePlayerId => _reachedHomePlayerId;
  int? get reachedHomeTokenIndex => _reachedHomeTokenIndex;

  void clearCaptureEffect() {
    _showCaptureEffect = false;
    _captureEffectBoardIndex = null;
  }

  void clearReachedHomeEffect() {
    _showReachedHomeEffect = false;
    _reachedHomePlayerId = null;
    _reachedHomeTokenIndex = null;
  }
  
  set isAnimating(bool value) {
    _isAnimating = value;
  }

  Future<int> rollDice() async {
    if (_isAnimating) return 0;
    
    _isAnimating = true;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 800));
    await _audioService.playDiceSound();
    
    final result = _ludoGame.rollDice();
    _gameState.lastDiceValue = _ludoGame.diceValue;
    _gameState.currentTurnPlayerId = _toModelsColor(_ludoGame.currentPlayer);

    _isAnimating = false;
    
    if (result == 6) {
      // Find player name by logic.PlayerColor
      final currentPlayerModel = _gameState.players.firstWhere((p) => p.id == _toModelsColor(_ludoGame.currentPlayer));
      await _statisticsService.incrementSixesRolled(currentPlayerModel.name);
    }
    notifyListeners();
    return result;
  }
  
  Future<void> movePiece(models.Piece pieceToMoveModel) async {
    if (_isAnimating) return;
    
    _isAnimating = true;

    final movingPlayerLogicColor = _ludoGame.currentPlayer;
    final movingPlayerMeta = getPlayerMeta(_toModelsColor(movingPlayerLogicColor)); // getPlayerMeta expects models.PlayerColor

    // Find the corresponding logic.Piece
    final logicPieceToMove = _ludoGame.pieces[movingPlayerLogicColor]?.firstWhere(
        (p) => p.id == pieceToMoveModel.id,
        orElse: () => throw Exception("Logic piece not found for model piece ${pieceToMoveModel.id} of color ${pieceToMoveModel.color}")
    );
    if (logicPieceToMove == null) {
        _isAnimating = false;
        notifyListeners();
        print("Error: Corresponding logic piece not found during movePiece.");
        return;
    }

    final opponentPiecesBeforeMove = _ludoGame.pieces.values
        .expand((list) => list)
        .where((p) => p.color != movingPlayerLogicColor)
        .map((p) => logic.Piece(p.color, p.id)..position = p.position)
        .toList();

    final bool moveSuccessful = _ludoGame.movePiece(logicPieceToMove);

    if (!moveSuccessful) {
      _isAnimating = false;
      return;
    }

    _gameState.lastDiceValue = _ludoGame.diceValue;
    _gameState.currentTurnPlayerId = _toModelsColor(_ludoGame.currentPlayer);

    bool captureOccurred = false;
    for (var oldOpponentPiece in opponentPiecesBeforeMove) {
      final newOpponentPiece = _ludoGame.pieces[oldOpponentPiece.color]!
          .firstWhere((p) => p.id == oldOpponentPiece.id);
      
      if (newOpponentPiece.isInYard && !oldOpponentPiece.isInYard) {
        captureOccurred = true;
        _showCaptureEffect = true;
        
        final logic.VisualPieceInfo movingPieceInfo = _ludoGame.getVisualPieceInfo(logicPieceToMove);
        if (movingPieceInfo.pathType == logic.PiecePathType.MAIN_PATH) {
          _captureEffectBoardIndex = movingPieceInfo.displayIndex;
        } else {
          _captureEffectBoardIndex = null; 
        }

        await _audioService.playCaptureSound();
        final capturedPlayerMeta = getPlayerMeta(_toModelsColor(newOpponentPiece.color));
        await _statisticsService.incrementPawnsCaptured(movingPlayerMeta.name);
        await _statisticsService.incrementPawnsLost(capturedPlayerMeta.name);
        break; 
      }
    }

    if (logicPieceToMove.isFinished) {
      _showReachedHomeEffect = true;
      _reachedHomePlayerId = logicPieceToMove.color;
      _reachedHomeTokenIndex = logicPieceToMove.id; 

      await _audioService.playFinishSound();

      final didWin = _ludoGame.pieces[movingPlayerLogicColor]!
          .every((p) => p.isFinished);

      if (didWin) {
        _gameState.winnerId = _toModelsColor(movingPlayerLogicColor);
        await _audioService.playVictorySound();
        await _statisticsService.incrementGamesWon(movingPlayerMeta.name);
      }
    } else if (!captureOccurred) {
      await _audioService.playMoveSound();
    }
    
    notifyListeners();
  }

  List<models.Piece> getMovablePieces() {
    if (_ludoGame.diceValue == 0) return [];
    
    List<logic.Piece> logicMovablePieces = _ludoGame.getMovablePieces();
    // Convert List<logic.Piece> to List<models.Piece>
    // This requires knowing the current state of these pieces (position, isSafe, etc.)
    // to construct models.Piece correctly. VisualPieceInfo is helpful here.
    return logicMovablePieces.map((lp) {
      final visualInfo = _ludoGame.getVisualPieceInfo(lp);
      bool isSafe = visualInfo.pathType == logic.PiecePathType.FINISHED || 
                    (visualInfo.pathType == logic.PiecePathType.MAIN_PATH && 
                     logic.LudoGame.safeGlobalIndices.contains(visualInfo.displayIndex));
      
      models.PiecePosition modelPos;
      if (visualInfo.pathType == logic.PiecePathType.YARD) {
        modelPos = models.PiecePosition(lp.id, isHome: true); // Using piece.id as fieldId for yard
      } else if (visualInfo.pathType == logic.PiecePathType.FINISHED) {
        modelPos = models.PiecePosition(lp.id, isHome: false); // Using piece.id as fieldId for finished
      } else { // MAIN_PATH or HOME_PATH
        modelPos = models.PiecePosition(visualInfo.displayIndex, isHome: false);
      }
      
      return models.Piece(
        _toModelsColor(lp.color), 
        lp.id, 
        modelPos, 
        isSafe: isSafe
      );
    }).toList();
  }

  void setSoundEnabled(bool enabled) {
    _audioService.setSoundEnabled(enabled);
    notifyListeners();
  }
  
  bool get isSoundEnabled => _audioService.isSoundEnabled;
  
  void setVolume(double volume) {
    _audioService.setVolume(volume);
    notifyListeners();
  }
  
  double get volume => _audioService.volume;

  logic.PlayerColor get currentPlayerColor => _ludoGame.currentPlayer;
  int get currentDiceValue => _ludoGame.diceValue;
  
  // This getter is problematic if GameScreen expects List<models.Piece> directly from here.
  // LudoGame stores List<logic.Piece>. UI needs models.Piece.
  // The conversion should happen just before UI consumption, or UI should consume VisualPieceInfo.
  // For now, providing a conversion, similar to getMovablePieces.
  List<models.Piece> get allBoardPieces {
     List<models.Piece> modelPieces = [];
    _ludoGame.pieces.forEach((playerColor, logicPieces) {
      for (var lp in logicPieces) {
        final visualInfo = _ludoGame.getVisualPieceInfo(lp);
        bool isSafe = visualInfo.pathType == logic.PiecePathType.FINISHED ||
                      (visualInfo.pathType == logic.PiecePathType.MAIN_PATH &&
                       logic.LudoGame.safeGlobalIndices.contains(visualInfo.displayIndex));
        
        models.PiecePosition modelPos;
        if (visualInfo.pathType == logic.PiecePathType.YARD) {
          modelPos = models.PiecePosition(lp.id, isHome: true);
        } else if (visualInfo.pathType == logic.PiecePathType.FINISHED) {
          modelPos = models.PiecePosition(lp.id, isHome: false);
        } else {
          modelPos = models.PiecePosition(visualInfo.displayIndex, isHome: false);
        }

        modelPieces.add(models.Piece(
          _toModelsColor(lp.color),
          lp.id,
          modelPos,
          isSafe: isSafe,
        ));
      }
    });
    return modelPieces;
  }

  models.Player getPlayerMeta(models.PlayerColor color) => 
      _gameState.players.firstWhere((p) => p.id == color, orElse: () {
        print("Error: Player metadata not found for color $color. Returning a default Player object.");
        return models.Player(_toModelsColor(logic.PlayerColor.red), "Unknown Player", isAI: true); // Default, should not happen
      });

  void startNewGame(List<models.Player> playersFromUI) {
    _ludoGame = logic.LudoGame(); 
    
    _gameState.players = playersFromUI; 
    _gameState.currentTurnPlayerId = _toModelsColor(_ludoGame.currentPlayer); 
    _gameState.winnerId = null;
    _gameState.lastDiceValue = 0;
    // _gameState.currentRollCount = 0; // LudoGame handles its own rollCount

    final playerNames = playersFromUI.map((p) => p.name).toList();
    _statisticsService.recordGamePlayed(playerNames).catchError((e) {
      print("Error recording game played stats: $e");
    });

    notifyListeners();
  }

  Future<bool> saveGame({String? customName}) async {
    // TODO: Serialize _ludoGame state into _gameState.gameLogicData (new field in GameState)
    // _gameState.gameLogicData = _ludoGame.toJson(); // Assuming LudoGame has toJson
    print("WARN: Game saving is currently incomplete. LudoGame state is not fully serialized.");
    return await _saveLoadService.saveGame(_gameState, customName: customName);
  }

  Future<bool> loadGame(int index) async {
    final loadedState = await _saveLoadService.loadGame(index);
    if (loadedState != null) {
      _gameState = loadedState;
      // TODO: Deserialize _ludoGame from _gameState.gameLogicData
      // _ludoGame = LudoGame.fromJson(_gameState.gameLogicData); // Assuming LudoGame has fromJson
      _ludoGame = logic.LudoGame(); // Resets game logic.
      _gameState.currentTurnPlayerId = _toModelsColor(_ludoGame.currentPlayer);
      _gameState.lastDiceValue = _ludoGame.diceValue;

      print("WARN: Game loading is currently incomplete. LudoGame state is reset.");
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteGame(int index) async {
    final result = await _saveLoadService.deleteGame(index);
    if (result) {
      notifyListeners();
    }
    return result;
  }
  
  Future<List<Map<String, dynamic>>> getSavedGames() async {
    return await _saveLoadService.getSavedGames();
  }
  
  // --- Methods for VisualPieceInfo ---

  logic.VisualPieceInfo getVisualPieceInfo(models.Piece modelsPiece) {
    final logicColor = _toLogicColor(modelsPiece.color);
    final logicPiece = _ludoGame.pieces[logicColor]?.firstWhere(
      (p) => p.id == modelsPiece.id,
      // orElse: () => throw Exception('Logic piece not found in getVisualPieceInfo') // More robust error
    );
    if (logicPiece == null) {
      // Fallback or error: This should ideally not happen if modelsPiece is valid.
      print('Error: Logic piece not found for models.Piece id: ${modelsPiece.id}, color: ${modelsPiece.color}');
      // Return a default/dummy VisualPieceInfo for the yard
      return logic.VisualPieceInfo(
          pieceRef: logic.Piece(logicColor, modelsPiece.id), // Dummy piece ref
          pathType: logic.PiecePathType.YARD, 
          displayIndex: modelsPiece.id, 
          color: logicColor
      );
    }
    return _ludoGame.getVisualPieceInfo(logicPiece);
  }

  logic.VisualPieceInfo getPotentialVisualPieceInfoAfterMove(models.Piece modelsPiece, int diceValue) {
    final originalLogicColor = _toLogicColor(modelsPiece.color);
    final originalLogicPiece = _ludoGame.pieces[originalLogicColor]?.firstWhere(
      (p) => p.id == modelsPiece.id,
      // orElse: () => throw Exception('Logic piece not found in getPotentialVisualPieceInfoAfterMove')
    );

    if (originalLogicPiece == null) {
      print('Error: Original logic piece not found for potential move calculation.');
      return getVisualPieceInfo(modelsPiece); // Return current info as fallback
    }

    // Create a temporary copy to simulate the move
    logic.Piece tempPiece = logic.Piece(originalLogicPiece.color, originalLogicPiece.id);
    tempPiece.position = originalLogicPiece.position;

    // --- Simulate move logic (simplified from LudoGame.movePiece, no side effects) ---
    if (tempPiece.isInYard) {
      if (diceValue == 6) {
        tempPiece.position = logic.LudoGame.startIndex[tempPiece.color]!;
      }
      // If not 6, it stays in yard, position remains -1.
    } else if (tempPiece.isOnMainPath) {
      final playerStartIndex = logic.LudoGame.startIndex[tempPiece.color]!;
      int homeEntryPredecessor = (playerStartIndex - 1 + logic.LudoGame.mainPathLength) % logic.LudoGame.mainPathLength;
      bool potentiallyMovingToHomePath = false;
      int stepsToReachHomeEntry = 0;

      // Check if the move would cross the home entry predecessor
      // This logic needs to be robust for wrap-around path
      int currentPos = tempPiece.position;
      int finalPosIfStaysOnMain = (currentPos + diceValue) % logic.LudoGame.mainPathLength;

      // Simplified check: Has it passed or landed on its home entry route?
      // A piece is on its home entry route if its current position is on the segment leading to its start index,
      // and the move takes it onto or past its start index.
      for (int i = 1; i <= diceValue; i++) {
          int nextStepPos = (currentPos + i) % logic.LudoGame.mainPathLength;
          if (nextStepPos == playerStartIndex) { // Reached player's own start square (entry to home path)
              // Check if it has completed at least half the board or is near its start
              // This is to differentiate passing start vs starting a new lap
              bool isApproachingHomeEntry = false;
              if (playerStartIndex == 0 && currentPos > logic.LudoGame.mainPathLength / 2) isApproachingHomeEntry = true; // Red
              else if (playerStartIndex > 0 && currentPos >= (playerStartIndex - logic.LudoGame.mainPathLength / 4 + logic.LudoGame.mainPathLength) % logic.LudoGame.mainPathLength ) isApproachingHomeEntry = true;
              
              if(isApproachingHomeEntry || currentPos == homeEntryPredecessor ) { // A more direct check for being on the predecessor
                 stepsToReachHomeEntry = i;
                 potentiallyMovingToHomePath = true;
                 break;
              }
          }
      }
       // More accurate check for moving to home path
      if (!potentiallyMovingToHomePath && currentPos <= homeEntryPredecessor && (currentPos + diceValue) > homeEntryPredecessor) {
           int distToPredecessor = homeEntryPredecessor - currentPos;
           stepsToReachHomeEntry = distToPredecessor + 1;
           if (diceValue >= stepsToReachHomeEntry) potentiallyMovingToHomePath = true;

      } else if (!potentiallyMovingToHomePath && currentPos > homeEntryPredecessor && (currentPos + diceValue) > (homeEntryPredecessor + logic.LudoGame.mainPathLength) ) { // Wrapped around
           int distToPredecessor = (homeEntryPredecessor + logic.LudoGame.mainPathLength) - currentPos;
           stepsToReachHomeEntry = distToPredecessor + 1;
           if (diceValue >= stepsToReachHomeEntry) potentiallyMovingToHomePath = true;
      }


      if (potentiallyMovingToHomePath) {
        int stepsIntoHome = diceValue - stepsToReachHomeEntry;
        if (stepsIntoHome < logic.LudoGame.homeLength) {
          tempPiece.position = logic.LudoGame.mainPathLength + stepsIntoHome;
        } else if (stepsIntoHome == logic.LudoGame.homeLength) { // Exactly into finish
          tempPiece.position = logic.LudoGame.mainPathLength + logic.LudoGame.homeLength;
        } else { // Overshot
          // For animation, we might want to show it trying to move, then snapping back.
          // Or just cap at finish. For now, cap at finish for target.
          tempPiece.position = logic.LudoGame.mainPathLength + logic.LudoGame.homeLength;
        }
      } else { // Stays on main path
        tempPiece.position = finalPosIfStaysOnMain;
      }
    } else if (tempPiece.isOnHomePath) {
      int newHomePos = tempPiece.position + diceValue;
      if (newHomePos < logic.LudoGame.mainPathLength + logic.LudoGame.homeLength) {
        tempPiece.position = newHomePos;
      } else if (newHomePos == logic.LudoGame.mainPathLength + logic.LudoGame.homeLength) { // Exactly into finish
        tempPiece.position = newHomePos;
      } else { // Overshot
        // Cap at finish for animation target
        tempPiece.position = logic.LudoGame.mainPathLength + logic.LudoGame.homeLength;
      }
    }
    // If piece is already finished, its position doesn't change.
    // The getVisualPieceInfo will correctly return FINISHED path type.

    return _ludoGame.getVisualPieceInfo(tempPiece);
  }

  // --- End of Methods for VisualPieceInfo ---

  @override
  void dispose() {
    _audioService.dispose();
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
