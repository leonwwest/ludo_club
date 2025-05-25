import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game_state.dart'; // Will be less used directly
import '../logic/ludo_game_logic.dart'; // Added

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _diceAnimationController;
  late Animation<double> _diceAnimation;
  int _displayDiceValue = 1; // Will be driven by provider more
  bool _winnerDialogShown = false;

  // Pawn Animation
  late AnimationController _pawnAnimationController;
  late Animation<Offset> _pawnAnimation;
  Piece? _animatingPiece; // Added
  PlayerColor? _animatingPlayerColor; // Changed from _animatingPlayerId (String?)
  Offset? _animationCurrentOffset;
  // Temporary storage for move details during animation
  PlayerColor? _actualPlayerColorForMove; // Changed from _actualPlayerIdForMove (int?)
  // _actualTokenIndexForMove and _actualTargetLogicalPosition might not be needed here if _animatingPiece is used
  int? _actualTargetLogicalPosition; // Kept for now, might be replaced by targetPiece in animation

  // Capture Animation
  late AnimationController _captureAnimationController;
  late Animation<double> _captureSparkleAnimation;
  Offset? _captureEffectScreenPosition;
  bool _isCaptureAnimating = false;
  Color _effectColor = Colors.orangeAccent; // Default color for sparkle

  // Reached Home Animation
  late AnimationController _reachedHomeAnimationController;
  late Animation<double> _reachedHomeShineAnimation;
  Offset? _reachedHomeEffectScreenPosition;
  bool _isReachedHomeAnimating = false;
  PlayerColor? _reachedHomeAnimatingPlayerColor; // Changed from String?
  int? _reachedHomeAnimatingPieceId; // Changed from _reachedHomeAnimatingTokenIndex
  Color _reachedHomeEffectColor = Colors.amber; // Color for home shine


  @override
  void initState() {
    super.initState();
    _diceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _diceAnimation = CurvedAnimation(
      parent: _diceAnimationController,
      curve: Curves.easeInOut,
    );
    _diceAnimationController.addListener(() {
      // This random dice display during animation might be removed or changed
      // if the GameProvider.currentDiceValue is authoritative.
      if (_diceAnimationController.value > 0.5 && _diceAnimationController.value < 0.6) {
        setState(() {
          _displayDiceValue = Random().nextInt(6) + 1;
        });
      }
    });

    // Pawn Animation Initialization
    _pawnAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500), // Adjust duration as needed
      vsync: this,
    );

    _pawnAnimationController.addListener(() {
      if (_animatingPiece != null) { // Check _animatingPiece
        setState(() {
          _animationCurrentOffset = _pawnAnimation.value;
        });
      }
    });

    _pawnAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        if (_animatingPiece != null) {
          // The actual move is now performed by GameProvider after animation.
          // GameProvider's movePiece will update the state and set flags for effects.
          gameProvider.movePiece(_animatingPiece!); 
        }
        setState(() {
          _animatingPiece = null;
          _animatingPlayerColor = null;
          _animationCurrentOffset = null;
          _actualPlayerColorForMove = null;
          _actualTargetLogicalPosition = null;
          gameProvider.isAnimating = false; 
        });
      } else if (status == AnimationStatus.dismissed) {
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
         setState(() {
          _animatingPiece = null;
          _animatingPlayerColor = null;
          _animationCurrentOffset = null;
          _actualPlayerColorForMove = null;
          _actualTargetLogicalPosition = null;
          if (gameProvider.isAnimating) {
            gameProvider.isAnimating = false;
          }
        });
      }
    });

    // Capture Animation Initialization
    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600), 
      vsync: this,
    );
    _captureSparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _captureAnimationController, curve: Curves.easeOut),
    );
    _captureAnimationController.addListener(() {
      if(_isCaptureAnimating) {
        setState(() {}); 
      }
    });
    _captureAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() { _isCaptureAnimating = false; _captureEffectScreenPosition = null; });
        Provider.of<GameProvider>(context, listen: false).clearCaptureEffect();
      } else if (status == AnimationStatus.dismissed) {
         setState(() { _isCaptureAnimating = false; _captureEffectScreenPosition = null; });
        Provider.of<GameProvider>(context, listen: false).clearCaptureEffect();
      }
    });

    // Reached Home Animation Initialization
    _reachedHomeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700), // Slightly longer for effect
      vsync: this,
    );
    _reachedHomeShineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _reachedHomeAnimationController, curve: Curves.easeInOut),
    );
    _reachedHomeAnimationController.addListener(() {
      if(_isReachedHomeAnimating) {
        setState(() {});
      }
    });
    _reachedHomeAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() { _isReachedHomeAnimating = false; _reachedHomeEffectScreenPosition = null; _reachedHomeAnimatingPlayerColor = null; _reachedHomeAnimatingPieceId = null; }); // Updated fields
        Provider.of<GameProvider>(context, listen: false).clearReachedHomeEffect();
      } else if (status == AnimationStatus.dismissed) {
        setState(() { _isReachedHomeAnimating = false; _reachedHomeEffectScreenPosition = null; _reachedHomeAnimatingPlayerColor = null; _reachedHomeAnimatingPieceId = null; }); // Updated fields
        Provider.of<GameProvider>(context, listen: false).clearReachedHomeEffect();
      }
    });
  }

  @override
  void dispose() {
    _diceAnimationController.dispose();
    _pawnAnimationController.dispose();
    _captureAnimationController.dispose();
    _reachedHomeAnimationController.dispose(); // Dispose reached home animation controller
    super.dispose();
  }

  // _startCaptureAnimation and _startReachedHomeAnimation will be updated later
  // to be triggered from build method based on provider flags.
  // For now, their signatures might need adjustment if called directly.

  void _startCaptureAnimation(GameProvider gameProvider, int boardIndex, double boardSize) {
    // boardIndex is the global index where capture happened
    // This will need _getOffsetForGlobalBoardIndex or similar
    // Placeholder for now:
    // _captureEffectScreenPosition = _getOffsetForGlobalBoardIndex(boardIndex, boardSize); 
    _effectColor = Colors.orangeAccent;
    // Example: Find a piece at that boardIndex to get its screen position for effect
    // This needs LudoGame's method to find piece by global board index.
    // Or, GameProvider could expose the screen position directly.
    // For now, let's assume gameProvider.captureEffectScreenPosition is set.
    // This logic will be moved to build method.
    if (gameProvider.captureEffectBoardIndex != null) {
        // TODO: Calculate _captureEffectScreenPosition based on gameProvider.captureEffectBoardIndex
        // This requires mapping global board index to screen coordinates.
        // For now, this will be triggered by build() method.
    }
  }

  void _startReachedHomeAnimation(GameProvider gameProvider, PlayerColor playerColor, int pieceId, double boardSize) {
    // TODO: Calculate _reachedHomeEffectScreenPosition
    // This logic will be moved to build method.
    _reachedHomeEffectColor = _getDisplayColorForPlayer(playerColor);
    // final finishedPieceForEffect = Piece(playerColor, pieceId, isFinished: true); 
    // _reachedHomeEffectScreenPosition = _getOffsetForLogicalPosition(finishedPieceForEffect, boardSize, gameProvider);
    
    setState(() {
      _isReachedHomeAnimating = true;
      _reachedHomeAnimatingPlayerColor = playerColor;
      _reachedHomeAnimatingPieceId = pieceId;
    });
    _reachedHomeAnimationController.forward(from: 0.0);
  }
  
  Color _getDisplayColorForPlayer(PlayerColor playerColor) {
    switch (playerColor) {
      case PlayerColor.red:
        return Colors.red.shade700; // Using a darker shade for better visibility
      case PlayerColor.green:
        return Colors.green.shade700;
      case PlayerColor.yellow:
        return Colors.yellow.shade600; // Darker yellow
      case PlayerColor.blue:
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700; // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Club'),
        backgroundColor: Colors.blue.shade700, 
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Sound-Einstellungen',
            onPressed: _showSoundSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Spiel speichern',
            onPressed: _showSaveDialog,
          ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          final currentPlayerMeta = gameProvider.getPlayerMeta(gameProvider.currentPlayerColor);
          final bool isGameOver = gameProvider.gameState.isGameOver; 
          final PlayerColor? winnerColor = gameProvider.gameState.winnerId;

          if (isGameOver && winnerColor != null && !_winnerDialogShown) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if(mounted) {
                 _showWinnerDialog(gameProvider, winnerColor);
                 _winnerDialogShown = true; 
              }
            });
          }
          
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade500, Colors.blue.shade900],
              ),
            ),
            child: Column(
              children: [
                // Spielerinformationen
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aktueller Spieler:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                currentPlayerMeta.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (currentPlayerMeta.isAI)
                                const Text(
                                  '(KI-Spieler)',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blue,
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Würfelwert:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                gameProvider.currentDiceValue == 0 ? '-' : gameProvider.currentDiceValue.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          // Removed currentRollCount display
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Spielbrett
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildGameBoard(gameProvider), 
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Würfel und Aktionen
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Würfel
                      GestureDetector(
                        onTap: gameProvider.isAnimating || gameProvider.getPlayerMeta(gameProvider.currentPlayerColor).isAI ? null : () => _rollDice(gameProvider),
                        child: AnimatedBuilder(
                          animation: _diceAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _diceAnimation.value * 2 * pi,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _diceAnimationController.isAnimating 
                                        ? _displayDiceValue.toString() 
                                        : (gameProvider.currentDiceValue == 0 ? "-" : gameProvider.currentDiceValue.toString()),
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Würfeln-Button
                      ElevatedButton(
                        onPressed: gameProvider.isAnimating || gameProvider.getPlayerMeta(gameProvider.currentPlayerColor).isAI
                            ? null
                            : () => _rollDice(gameProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Würfeln',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameBoard(GameProvider gameProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.maxWidth;
        final fieldSize = boardSize / 15.0; // Ensure double for calculations
        
        final List<Piece> allPieces = gameProvider.allBoardPieces;
        final List<Piece> movableGamePieces = gameProvider.getMovablePieces();
        
        // Trigger effect animations post-frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return; // Ensure widget is still in the tree

          if (gameProvider.showCaptureEffect && !_isCaptureAnimating && gameProvider.captureEffectBoardIndex != null) {
            // Assuming captureEffectBoardIndex is a global main path index.
            // We need a way to get the screen coordinates for this global index.
            // This might involve creating a temporary dummy piece if _getOffsetForLogicalPosition can use it.
            // Or, a new helper: _getOffsetForGlobalBoardIndex(index, boardSize).
            // For now, let's assume _calculateMainBoardPosition can be used.
            // The color of the piece causing the capture is gameProvider.currentPlayerColor (before turn changes)
            // or more accurately, the color of the piece that just moved.
            // Let's use a placeholder for the color for the effect if not readily available.
             _captureEffectScreenPosition = _calculateMainBoardPosition(gameProvider.captureEffectBoardIndex!, boardSize, fieldSize, gameProvider.currentPlayerColor);
            if (_captureEffectScreenPosition != null) {
                 setState(() { _isCaptureAnimating = true; });
                 _captureAnimationController.forward(from: 0.0);
            }
          }
          if (gameProvider.showReachedHomeEffect && !_isReachedHomeAnimating && gameProvider.reachedHomePlayerId != null && gameProvider.reachedHomeTokenIndex != null) {
            // Create a dummy piece that is in the finished state for position calculation.
            Piece finishedPieceForEffect = Piece(
                gameProvider.reachedHomePlayerId!, 
                gameProvider.reachedHomeTokenIndex!, // This is piece.id
                PiecePosition(0, isHome: false), // Position doesn't matter as isSafe = true
                isSafe: true
            );
            _reachedHomeEffectScreenPosition = _getOffsetForLogicalPosition(finishedPieceForEffect, boardSize, gameProvider);
            _reachedHomeEffectColor = _getDisplayColorForPlayer(gameProvider.reachedHomePlayerId!);
            if(_reachedHomeEffectScreenPosition != null){
                setState(() { 
                    _isReachedHomeAnimating = true; 
                    _reachedHomeAnimatingPlayerColor = gameProvider.reachedHomePlayerId; // Store for context if needed
                    _reachedHomeAnimatingPieceId = gameProvider.reachedHomeTokenIndex;
                });
                _reachedHomeAnimationController.forward(from: 0.0);
            }
          }
        });

        return Stack(
          children: [
            CustomPaint(
              size: Size(boardSize, boardSize),
              painter: GameBoardPainter(), 
            ),
            
            // Highlight movable pieces
            ...movableGamePieces.map((movablePiece) {
              final Offset pieceScreenPos = _getOffsetForLogicalPosition(movablePiece, boardSize, gameProvider);
              return Positioned(
                left: pieceScreenPos.dx - fieldSize / 2,
                top: pieceScreenPos.dy - fieldSize / 2,
                child: GestureDetector(
                  onTap: () => _initiatePawnAnimation(gameProvider, movablePiece, boardSize),
                  child: Container(
                    width: fieldSize,
                    height: fieldSize,
                    decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.7),
                      border: Border.all(color: Colors.orangeAccent, width: 2.5),
                      shape: BoxShape.circle,
                       boxShadow: [
                        BoxShadow(
                          color: Colors.yellow.withOpacity(0.5),
                          blurRadius: 8.0,
                          spreadRadius: 2.0,
                        )
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            
            // Draw all pieces
            ...allPieces.map((piece) {
              Offset displayPosition;
              if (_animatingPiece != null && _animatingPiece!.color == piece.color && _animatingPiece!.id == piece.id && _animationCurrentOffset != null) {
                displayPosition = _animationCurrentOffset!;
              } else {
                displayPosition = _getOffsetForLogicalPosition(piece, boardSize, gameProvider);
              }
              return _buildToken(piece, displayPosition, fieldSize, gameProvider, boardSize);
            }).toList(),

            // Capture Effect Animation
            if (_isCaptureAnimating && _captureEffectScreenPosition != null)
              Positioned(
                left: _captureEffectScreenPosition!.dx - (fieldSize), 
                top: _captureEffectScreenPosition!.dy - (fieldSize),
                child: SizedBox( 
                  width: fieldSize * 2,
                  height: fieldSize * 2,
                  child: CustomPaint(
                    painter: CaptureEffectPainter(
                      animationValue: _captureSparkleAnimation.value,
                      color: _effectColor, 
                    ),
                    size: Size(fieldSize * 2, fieldSize * 2), 
                  ),
                ),
              ),

            // Reached Home Effect Animation (triggering logic will be refined)
            if (_isReachedHomeAnimating && _reachedHomeEffectScreenPosition != null)
              Positioned(
                left: _reachedHomeEffectScreenPosition!.dx - fieldSize, // Center effect area on token
                top: _reachedHomeEffectScreenPosition!.dy - fieldSize,
                child: SizedBox(
                  width: fieldSize * 2, // Area for painter to draw the glow
                  height: fieldSize * 2,
                  child: CustomPaint(
                    painter: ReachedHomeEffectPainter(
                      animationValue: _reachedHomeShineAnimation.value,
                      color: _reachedHomeEffectColor, // This should be set to the player's color
                    ),
                    size: Size(fieldSize * 2, fieldSize * 2),
                  ),
                ),
              ),
            
            // Safe Zones markieren - This was based on old GameState.startIndex and _getPlayerColor(String)
            // This needs to be re-evaluated if safe zones are to be visually marked based on LudoGame logic.
            // For now, removing the old implementation.
            /*
            ...gameProvider.allBoardPieces.where((p) => LudoGame.isSafeZone(p.position, p.color)).map((piece) {
              final position = _getOffsetForLogicalPosition(piece, boardSize, gameProvider);
              final playerColor = _getDisplayColorForPlayer(piece.color);
              return Positioned(
                left: position.dx - fieldSize / 2,
                top: position.dy - fieldSize / 2,
                child: Container(
                  width: fieldSize,
                  height: fieldSize,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: playerColor.withOpacity(0.5), width: 2, style: BorderStyle.solid),
                  ),
                ),
              );
            }).toList(),
            */
          ],
        );
      },
    );
  }
  
  // _buildHomePiece removed as pieces are now handled uniformly by _buildToken and _getOffsetForLogicalPosition
  // _getHomeFieldPositions removed for the same reason.

  // Baut eine einzelne Spielfigur
  Widget _buildToken(Piece piece, Offset screenPosition, double fieldSize, GameProvider gameProvider, double boardSize) {
    final displayPlayerColor = _getDisplayColorForPlayer(piece.color);
    final bool isCurrentPlayerPiece = piece.color == gameProvider.currentPlayerColor;
    // Check if this piece is in the list of movable pieces from GameProvider
    final bool canBeMoved = isCurrentPlayerPiece && gameProvider.getMovablePieces().any((p) => p.id == piece.id && p.color == piece.color);
    
    return Positioned(
      left: screenPosition.dx - fieldSize / 2, // Use screenPosition passed as argument
      top: screenPosition.dy - fieldSize / 2,  // Use screenPosition passed as argument
      child: GestureDetector(
        onTap: canBeMoved && !gameProvider.isAnimating && gameProvider.currentDiceValue > 0
          ? () => _initiatePawnAnimation(gameProvider, piece, boardSize)
          : null,
        child: Container(
          width: fieldSize,
          height: fieldSize,
          decoration: BoxDecoration(
            color: displayPlayerColor, // Use display color
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              (piece.id + 1).toString(), // Use piece.id
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // _showMoveOptions method removed as per instruction.

  // Helper to get screen offset for any logical game position
  Offset _getOffsetForLogicalPosition(Piece piece, double boardSize, GameProvider gameProvider) {
    final double fieldSize = boardSize / 15.0; // Consistent with GameBoardPainter
    
    // Use piece.position.isHome for yard, piece.isSafe for finished.
    // piece.position.fieldId is the relevant ID.
    if (piece.position.isHome) { // Piece is in the yard
      return _calculateBasePosition(piece.color, piece.id, boardSize, fieldSize);
    } else if (piece.isSafe) { // Piece is finished
      return _calculateFinishPosition(piece.color, piece.id, boardSize, fieldSize);
    } else { 
      // Piece is on the main path or a player's home path (but not finished yet)
      // LudoGameLogic uses fieldId 0-39 for main path, and 0-3 for home path (player specific)
      // This needs a robust way to map these to global screen coordinates.
      // The existing _calculateMainBoardPosition uses a pathMapping that might be compatible if 
      // LudoGame can provide a "global display index" or if we adapt it.
      // For now, we assume piece.position.fieldId is a global-like index if not isHome/isSafe.
      // This part is the most complex and error-prone without exact LudoGame details.
      
      // TODO: Refine this logic based on LudoGame's exact coordinate system.
      // For now, let's assume piece.position.fieldId can be used with _calculateMainBoardPosition
      // if we have a way to know if it's a main path or home path index.
      // The LudoGameLogic PiecePosition has fieldId and isHome. isSafe is on Piece.
      // If !piece.position.isHome and !piece.isSafe, it's on the board or home path (not finished).
      // The current _calculateMainBoardPosition is for the 0-51 main track.
      // Home path positions (0-3 for each player) need separate calculation.
      // LudoGameLogic doesn't have a clear "home path index" separate from "main path index".
      // Let's assume for now: if not isHome and not isSafe, it's on the main path.
      // This is a simplification.
      return _calculateMainBoardPosition(piece.position.fieldId, boardSize, fieldSize, piece.color);
    }
  }

  Offset _calculateBasePosition(PlayerColor playerColor, int pieceId, double boardSize, double fieldSize) {
    // Using a simplified layout for base positions, assuming 4 pieces per player.
    // These coordinates are relative to the top-left of the board.
    // Each player's base is a 2x2 grid of piece positions.
    // Example: Red player (top-left corner of the game board drawing)
    //  (1,1) (2,1)
    //  (1,2) (2,2)  -- in terms of fieldSize units for center of piece.
    
    double  baseX = 0, baseY = 0;
    // These multipliers are for the larger 6x6 player corner area.
    // Inside that, the 4x4 white area, then 2x2 circles for pieces.
    // Let's use the GameBoardPainter's logic for corner positions.
    // Green: top-left, Yellow: top-right, Red: bottom-left, Blue: bottom-right (as per GameBoardPainter)
    // This mapping might differ from PlayerColor enum values.
    // For now, map PlayerColor to GameBoardPainter's color order.
    // Green (0) -> PlayerColor.green, Yellow (1) -> PlayerColor.yellow, Red (2) -> PlayerColor.red, Blue (3) -> PlayerColor.blue

    Map<PlayerColor, Offset> playerCornerOffsets = {
        PlayerColor.green: Offset(0 * fieldSize, 0 * fieldSize), // Top-left
        PlayerColor.yellow: Offset(9 * fieldSize, 0 * fieldSize), // Top-right
        PlayerColor.red: Offset(0 * fieldSize, 9 * fieldSize),   // Bottom-left
        PlayerColor.blue: Offset(9 * fieldSize, 9 * fieldSize),  // Bottom-right
    };
    
    Offset cornerOffset = playerCornerOffsets[playerColor] ?? Offset(0,0);

    // Positions within the 4x4 inner white square of the 6x6 player corner
    List<Offset> pieceRelativeOffsets = [
        Offset(cornerOffset.dx + 2.0 * fieldSize, cornerOffset.dy + 2.0 * fieldSize), // Top-left piece in base
        Offset(cornerOffset.dx + 4.0 * fieldSize, cornerOffset.dy + 2.0 * fieldSize), // Top-right
        Offset(cornerOffset.dx + 2.0 * fieldSize, cornerOffset.dy + 4.0 * fieldSize), // Bottom-left
        Offset(cornerOffset.dx + 4.0 * fieldSize, cornerOffset.dy + 4.0 * fieldSize), // Bottom-right
    ];

    if (pieceId < pieceRelativeOffsets.length) {
        return pieceRelativeOffsets[pieceId];
    }
    return Offset(fieldSize, fieldSize); // Fallback
  }
  
  Offset _calculateFinishPosition(PlayerColor playerColor, int pieceId, double boardSize, double fieldSize) {
    // Center of the board (3x3 area in GameBoardPainter)
    // Each player has a triangular segment pointing inwards.
    // Let's place finished pieces near their triangle tip.
    Map<PlayerColor, Offset> finishAreaCenters = {
      PlayerColor.green: Offset(7.5 * fieldSize, 6.5 * fieldSize), // Tip of green triangle
      PlayerColor.yellow: Offset(8.5 * fieldSize, 7.5 * fieldSize), // Tip of yellow triangle
      PlayerColor.red: Offset(7.5 * fieldSize, 8.5 * fieldSize),   // Tip of red triangle
      PlayerColor.blue: Offset(6.5 * fieldSize, 7.5 * fieldSize),  // Tip of blue triangle
    };
    // Simple stacking for multiple finished pieces of the same color
    double stackOffset = pieceId * (fieldSize * 0.2); // Small offset for stacking
    Offset basePos = finishAreaCenters[playerColor] ?? Offset(boardSize/2, boardSize/2);

    // Adjust offset based on player color to stack inwards or along a line
    switch (playerColor) {
        case PlayerColor.green: return Offset(basePos.dx, basePos.dy + stackOffset);
        case PlayerColor.yellow: return Offset(basePos.dx - stackOffset, basePos.dy);
        case PlayerColor.red: return Offset(basePos.dx, basePos.dy - stackOffset);
        case PlayerColor.blue: return Offset(basePos.dx + stackOffset, basePos.dy);
        default: return basePos;
    }
  }
  
  Offset _calculateHomePathPosition(PlayerColor playerColor, int homePathIndex, double boardSize, double fieldSize) {
    // Based on GameBoardPainter's _drawHomeColumn
    // Green (top-down): col 7, rows 1-5
    // Yellow (left-right): row 7, cols 9-13
    // Red (bottom-up): col 7, rows 9-13 (reversed)
    // Blue (right-left): row 7, cols 1-5 (reversed)

    Map<PlayerColor, List<Offset>> homePathCoords = {
      PlayerColor.green: List.generate(5, (i) => Offset(7.5 * fieldSize, (1.5 + i) * fieldSize)),
      PlayerColor.yellow: List.generate(5, (i) => Offset((9.5 + i) * fieldSize, 7.5 * fieldSize)),
      PlayerColor.red: List.generate(5, (i) => Offset(7.5 * fieldSize, (13.5 - i) * fieldSize)),
      PlayerColor.blue: List.generate(5, (i) => Offset((5.5 - i) * fieldSize, 7.5 * fieldSize)),
    };
    
    if (homePathCoords.containsKey(playerColor) && homePathIndex >= 0 && homePathIndex < homePathCoords[playerColor]!.length) {
      return homePathCoords[playerColor]![homePathIndex];
    }
    return Offset(boardSize/2, boardSize/2); // Fallback
  }

  Offset _calculateMainBoardPosition(int boardIndex, double boardSize, double fieldSize, PlayerColor forPlayerColorIfAmbiguous) {
    // This is a simplified mapping for the main path (0-39 for LudoGameLogic)
    // This needs to align with GameBoardPainter if visual accuracy is paramount.
    // The existing pathMapping in the original _calculateFieldPosition was complex.
    // For now, a very basic circular path.
    // LudoGameLogic uses 40 fields for main path.
    // Let's divide boardSize by ~13 cells for outer track approx.
    final cellSize = boardSize / 15;
    
    // Definiere die Pfade für jede Seite des Bretts - 13 Felder pro Seite, insgesamt 52 Felder
    // Dies entspricht den äußeren beiden Spalten der 3-Zellen-breiten Spur
    final Map<int, List<int>> pathMapping = {};
    
    // Obere Spur: 13 Felder (von links nach rechts)
    for (int i = 0; i < 13; i++) {
      // Wechsle zwischen zwei Reihen (Spur ist 2 Felder breit)
      final row = i % 2 == 0 ? 6 : 7;
      final col = 1 + i ~/ 2;
      pathMapping[i] = [col, row];
    }
    
    // Rechte Spur: 13 Felder (von oben nach unten)
    for (int i = 0; i < 13; i++) {
      // Wechsle zwischen zwei Spalten (Spur ist 2 Felder breit)
      final row = 1 + i ~/ 2;
      final col = i % 2 == 0 ? 8 : 7;
      pathMapping[i + 13] = [col, row];
    }
    
    // Untere Spur: 13 Felder (von rechts nach links)
    for (int i = 0; i < 13; i++) {
      // Wechsle zwischen zwei Reihen (Spur ist 2 Felder breit)
      final row = i % 2 == 0 ? 8 : 7;
      final col = 13 - i ~/ 2;
      pathMapping[i + 26] = [col, row];
    }
    
    // Linke Spur: 13 Felder (von unten nach oben)
    for (int i = 0; i < 13; i++) {
      // Wechsle zwischen zwei Spalten (Spur ist 2 Felder breit)
      final row = 13 - i ~/ 2;
      final col = i % 2 == 0 ? 6 : 7;
      pathMapping[i + 39] = [col, row];
    }
    
    // Heimspalten für die Endphase des Spiels
    // Grün (von oben nach unten)
    for (int i = 0; i < 5; i++) {
      pathMapping[100 + i] = [7, 1 + i];
    }
    
    // Gelb (von links nach rechts)
    for (int i = 0; i < 5; i++) {
      pathMapping[110 + i] = [9 + i, 7];
    }
    
    // Rot (von unten nach oben)
    for (int i = 0; i < 5; i++) {
      pathMapping[120 + i] = [7, 13 - i];
    }
    
    // Blau (von rechts nach links)
    for (int i = 0; i < 5; i++) {
      pathMapping[130 + i] = [5 - i, 7];
    }
    
    // Startpositionen der Spieler
    pathMapping[200] = [1, 7]; // Grün (linke Seite)
    pathMapping[201] = [8, 1]; // Gelb (obere Seite)
    pathMapping[202] = [13, 7]; // Rot (rechte Seite)
    pathMapping[203] = [7, 13]; // Blau (untere Seite)
    
    // Ermittle die Koordinaten für den angegebenen Index
    // The boardIndex from LudoGameLogic is 0-39.
    // The GameBoardPainter has a 15x15 grid.
    // The main path is 3 cells wide. Outer cells are for travel.
    // Example mapping for a 40-step path on a 15x15 grid:
    // Let's map to the middle of the 3-cell wide tracks.
    // Top track (cols 1-13, row 7.5)
    // Right track (col 7.5, rows 1-13)
    // Bottom track (cols 1-13 reversed, row 7.5)
    // Left track (col 7.5, rows 1-13 reversed)
    // This is a gross oversimplification and won't match GameBoardPainter perfectly.
    // A proper solution would require a detailed path definition from LudoGame or GameBoardPainter.

    // Using the GameBoardPainter's outer track for simplicity:
    // Green start: (1,7) -> pathMapping[200]
    // Yellow start: (8,1) -> pathMapping[201]
    // Red start: (13,7) -> pathMapping[202]
    // Blue start: (7,13) -> pathMapping[203]
    
    // A very simplified circular path for now.
    double angle = (boardIndex / 40.0) * 2 * pi; // 40 steps in a circle
    double radius = boardSize * 0.4; // Adjust radius as needed
    Offset center = Offset(boardSize / 2, boardSize / 2);
    if (pathMapping.containsKey(boardIndex)) { // Use old mapping if index matches.
      final pos = pathMapping[boardIndex]!;
      return Offset(
        pos[0] * cellSize + cellSize/2,
        pos[1] * cellSize + cellSize/2
      );
    }
    
    // Fallback: Zentrum des Spielbretts
    return Offset(boardSize / 2, boardSize / 2);
  }

  // _getPlayerColor is renamed to _getDisplayColorForPlayer and takes PlayerColor

  Future<void> _rollDice(GameProvider gameProvider) async {
    if (gameProvider.isAnimating) return;
    
    _diceAnimationController.reset();
    _diceAnimationController.forward();
    
    // rollDice in GameProvider now returns the dice value.
    final result = await gameProvider.rollDice(); 
    // No need to call setState here to update _displayDiceValue if
    // the Text widget for dice directly uses gameProvider.currentDiceValue
    // and the animation part (_displayDiceValue) is handled by _diceAnimationController listener.
    // However, if you want _displayDiceValue to show the final result after animation, then:
    // _diceAnimationController.addStatusListener once here for the final value if needed.
    // For now, the Text widget will update via Consumer once gameProvider notifies.
  }

  Future<void> _initiatePawnAnimation(GameProvider gameProvider, Piece pieceToMove, double boardSize) async {
    if (gameProvider.isAnimating) return;

    _actualPlayerColorForMove = pieceToMove.color; 
    
    // Create a conceptual target piece for animation end offset.
    // The actual game logic is handled by LudoGame.movePiece.
    // This is a simplified calculation for animation purposes only.
    int targetFieldIdDisplay = pieceToMove.position.fieldId;
    bool targetIsSafeDisplay = pieceToMove.isSafe;
    bool targetIsHomeDisplay = pieceToMove.position.isHome;
    int dice = gameProvider.currentDiceValue;

    if (!pieceToMove.position.isHome) { // If not in yard
        targetFieldIdDisplay = pieceToMove.position.fieldId + dice;
        
        const int displayMainPathLength = 40; 
        const int displayHomeLength = 4;    
        
        if (pieceToMove.position.fieldId < displayMainPathLength && 
            targetFieldIdDisplay >= displayMainPathLength) {
            int stepsIntoHome = targetFieldIdDisplay - displayMainPathLength;
            if (stepsIntoHome >= displayHomeLength) {
                targetFieldIdDisplay = displayHomeLength -1; 
                targetIsSafeDisplay = true; 
            } else {
                targetFieldIdDisplay = stepsIntoHome; 
            }
             // When moving to home path, targetIsHomeDisplay should conceptually be false for PiecePosition
             // if PiecePosition's isHome is strictly for the initial yard.
             // LudoGameLogic's PiecePosition.isHome is for the yard.
            targetIsHomeDisplay = false; 
        } else if (pieceToMove.position.fieldId >= displayMainPathLength && pieceToMove.position.fieldId < (displayMainPathLength + displayHomeLength)){
            if (targetFieldIdDisplay >= displayMainPathLength + displayHomeLength) { 
                 targetFieldIdDisplay = displayHomeLength -1; 
                 targetIsSafeDisplay = true; 
            } else {
                targetFieldIdDisplay = targetFieldIdDisplay - displayMainPathLength; 
            }
            targetIsHomeDisplay = false; // On home path, not in yard
        }
         else { 
            targetFieldIdDisplay = targetFieldIdDisplay % displayMainPathLength;
            targetIsHomeDisplay = false;
        }


    } else { 
        // Moving from Yard. Assume LudoGame.getStartFieldId(color) gives the main path index.
        // For animation, we'll use a placeholder if that's not available.
        // Let's assume LudoGameLogic places it on the correct start field via movePiece.
        // For animation target, we need a fieldId on the main path.
        // Placeholder: use 0 or a player-specific start index if known.
        // This part of animation target calculation needs to be robust.
        // For now, assume target is field 0 for simplicity of display logic.
        targetFieldIdDisplay = 0; // Needs actual start field from LudoGame for accuracy
        targetIsHomeDisplay = false; 
    }
    
    PiecePosition targetAnimPosition = PiecePosition(targetFieldIdDisplay, isHome: targetIsHomeDisplay);
    if (targetIsSafeDisplay) { // If finished, isHome for PiecePosition might be false.
      targetAnimPosition = PiecePosition(targetFieldIdDisplay, isHome: false);
    }


    Piece targetPieceStateForAnimation = Piece(
        pieceToMove.color, 
        pieceToMove.id, 
        targetAnimPosition, 
        isSafe: targetIsSafeDisplay
    );


    setState(() {
      gameProvider.isAnimating = true;
      _animatingPiece = pieceToMove;
      _animatingPlayerColor = pieceToMove.color;
      
      Offset startOffset = _getOffsetForLogicalPosition(pieceToMove, boardSize, gameProvider);
      Offset endOffset = _getOffsetForLogicalPosition(targetPieceStateForAnimation, boardSize, gameProvider);

      _pawnAnimation = Tween<Offset>(
        begin: startOffset,
        end: endOffset, 
      ).animate(CurvedAnimation(
        parent: _pawnAnimationController,
        curve: Curves.easeInOut,
      ));
      _animationCurrentOffset = startOffset; 
    });

    _pawnAnimationController.forward(from: 0.0);
  }

  void _showWinnerDialog(GameProvider gameProvider, PlayerColor winnerColor) { 
    final displayPlayerColor = _getDisplayColorForPlayer(winnerColor);
    final winnerMeta = gameProvider.getPlayerMeta(winnerColor);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🎉 Spielende 🎉', 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: displayPlayerColor, // Use display color
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    winnerMeta.name.substring(0, 1).toUpperCase(), // Use metadata
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${winnerMeta.name} hat gewonnen!', // Use metadata
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Herzlichen Glückwunsch!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog schließen
                Navigator.of(context).pop(); // Zum Hauptmenü zurückkehren
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Zurück zum Hauptmenü'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog schließen
                
                // Neues Spiel mit den gleichen Spielern starten
                final gameProvider = Provider.of<GameProvider>(context, listen: false);
                gameProvider.startNewGame(
                  // This needs to map Player (from models/game_state) to PlayerColor for LudoGame if needed,
                  // or ensure GameProvider.startNewGame handles this.
                  // For now, assume GameProvider.startNewGame takes List<Player> (from models/game_state.dart)
                  gameProvider.gameState.players.map((p) =>
                    Player(p.id, p.name, isAI: p.isAI) // Recreate to avoid issues with old state
                  ).toList()
                );
                
                // Dialog-Flag zurücksetzen
                setState(() {
                  _winnerDialogShown = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Neues Spiel'),
            ),
          ],
        );
      },
    );
  }

  // Zeigt einen Dialog zum Speichern des Spiels
  void _showSaveDialog() {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Spiel speichern'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gib einen Namen für deinen Spielstand ein:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name des Spielstands',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final customName = name.isNotEmpty ? name : null;
                
                Navigator.of(context).pop();
                
                final gameProvider = Provider.of<GameProvider>(context, listen: false);
                final success = await gameProvider.saveGame(customName: customName);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? 'Spiel erfolgreich gespeichert!' 
                        : 'Fehler beim Speichern des Spiels.',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    ).then((_) {
      // Controller freigeben, wenn der Dialog geschlossen wird
      nameController.dispose();
    });
  }

  // Zeigt den Dialog für Sound-Einstellungen
  void _showSoundSettingsDialog() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    bool soundEnabled = gameProvider.isSoundEnabled;
    double volume = gameProvider.volume;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Sound-Einstellungen'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sound an/aus
                  SwitchListTile(
                    title: const Text('Sound'),
                    value: soundEnabled,
                    onChanged: (value) {
                      setState(() {
                        soundEnabled = value;
                      });
                      gameProvider.setSoundEnabled(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Lautstärke einstellen
                  Row(
                    children: [
                      const Icon(Icons.volume_down),
                      Expanded(
                        child: Slider(
                          value: volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: soundEnabled
                              ? (value) {
                                  setState(() {
                                    volume = value;
                                  });
                                  gameProvider.setVolume(value);
                                }
                              : null,
                        ),
                      ),
                      const Icon(Icons.volume_up),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Schließen'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// CustomPainter für das Spielbrett
class GameBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = size.width;
    final cellSize = boardSize / 15; // 15×15 Raster
    
    // Hintergrund (weiß)
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    
    // Spielbrett-Umriss
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Definiere die Farben für die vier Spieler
    final colors = [
      Colors.green,   // Oben links
      Colors.yellow,  // Oben rechts
      Colors.red,     // Unten links
      Colors.blue,    // Unten rechts
    ];
    
    // Zeichne das Raster
    for (int i = 0; i <= 15; i++) {
      // Vertikale Linien
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, boardSize),
        outlinePaint
      );
      // Horizontale Linien
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(boardSize, i * cellSize),
        outlinePaint
      );
    }
    
    // Zeichne die 6×6 farbigen Ecken
    final cornerPositions = [
      [0, 0],     // Oben links (grün)
      [9, 0],     // Oben rechts (gelb)
      [0, 9],     // Unten links (rot)
      [9, 9],     // Unten rechts (blau)
    ];
    
    for (int i = 0; i < 4; i++) {
      final pos = cornerPositions[i];
      final color = colors[i];
      
      // 6×6 farbiges Quadrat
      final cornerRect = Rect.fromLTWH(
        pos[0] * cellSize,
        pos[1] * cellSize,
        cellSize * 6,
        cellSize * 6
      );
      
      canvas.drawRect(cornerRect, Paint()..color = color);
      
      // Weißes Quadrat im Inneren (4×4)
      final innerRect = Rect.fromLTWH(
        pos[0] * cellSize + cellSize,
        pos[1] * cellSize + cellSize,
        cellSize * 4,
        cellSize * 4
      );
      
      canvas.drawRect(innerRect, backgroundPaint);
      
      // 2×2 Startkreis in der Mitte des weißen Quadrats
      final centerX = pos[0] * cellSize + 3 * cellSize;
      final centerY = pos[1] * cellSize + 3 * cellSize;
      
      canvas.drawCircle(
        Offset(centerX, centerY),
        cellSize * 1, // 2×2 Kreis (Durchmesser)
        Paint()..color = color.withOpacity(0.3)
      );
    }
    
    // Zeichne die Hauptspur (52 weiße Felder)
    // Obere Spur (links nach rechts)
    for (int x = 0; x < 6; x++) {
      _drawTrackSegment(canvas, 1 + x, 6, cellSize, outlinePaint);
      _drawTrackSegment(canvas, 1 + x, 7, cellSize, outlinePaint);
      _drawTrackSegment(canvas, 1 + x, 8, cellSize, outlinePaint);
    }
    
    // Rechte Spur (oben nach unten)
    for (int y = 0; y < 6; y++) {
      _drawTrackSegment(canvas, 6, 1 + y, cellSize, outlinePaint);
      _drawTrackSegment(canvas, 7, 1 + y, cellSize, outlinePaint);
      _drawTrackSegment(canvas, 8, 1 + y, cellSize, outlinePaint);
    }
    
    // Untere Spur (rechts nach links)
    for (int x = 0; x < 6; x++) {
      _drawTrackSegment(canvas, 14 - x, 6, cellSize, outlinePaint);
      _drawTrackSegment(canvas, 14 - x, 7, cellSize, outlinePaint);
      _drawTrackSegment(canvas, 14 - x, 8, cellSize, outlinePaint);
    }
    
    // Linke Spur (unten nach oben)
    for (int y = 0; y < 6; y++) {
      _drawTrackSegment(canvas, 6, 14 - y, cellSize, outlinePaint);
      _drawTrackSegment(canvas, 7, 14 - y, cellSize, outlinePaint);
      _drawTrackSegment(canvas, 8, 14 - y, cellSize, outlinePaint);
    }
    
    // Zeichne die Heimspalten (je 5 farbige Felder)
    // Grün (oben nach unten)
    _drawHomeColumn(canvas, 7, 1, 5, colors[0], cellSize);
    
    // Gelb (links nach rechts)
    _drawHomeColumn(canvas, 9, 7, 5, colors[1], cellSize, vertical: false);
    
    // Rot (unten nach oben)
    _drawHomeColumn(canvas, 7, 9, 5, colors[2], cellSize, reverse: true);
    
    // Blau (rechts nach links)
    _drawHomeColumn(canvas, 1, 7, 5, colors[3], cellSize, vertical: false, reverse: true);
    
    // Zeichne das Zentrum (3×3 mit diagonaler Teilung)
    final centerRect = Rect.fromLTWH(
      6 * cellSize,
      6 * cellSize,
      cellSize * 3,
      cellSize * 3
    );
    
    canvas.drawRect(centerRect, backgroundPaint);
    canvas.drawRect(centerRect, outlinePaint);
    
    // Diagonale Dreiecke im Zentrum
    final centerPath = Path();
    
    // Grünes Dreieck (oben)
    centerPath.moveTo(7.5 * cellSize, 6 * cellSize);
    centerPath.lineTo(6 * cellSize, 7.5 * cellSize);
    centerPath.lineTo(9 * cellSize, 7.5 * cellSize);
    centerPath.close();
    canvas.drawPath(centerPath, Paint()..color = colors[0]);
    
    // Gelbes Dreieck (rechts)
    centerPath.reset();
    centerPath.moveTo(9 * cellSize, 7.5 * cellSize);
    centerPath.lineTo(7.5 * cellSize, 6 * cellSize);
    centerPath.lineTo(7.5 * cellSize, 9 * cellSize);
    centerPath.close();
    canvas.drawPath(centerPath, Paint()..color = colors[1]);
    
    // Rotes Dreieck (unten)
    centerPath.reset();
    centerPath.moveTo(7.5 * cellSize, 9 * cellSize);
    centerPath.lineTo(6 * cellSize, 7.5 * cellSize);
    centerPath.lineTo(9 * cellSize, 7.5 * cellSize);
    centerPath.close();
    canvas.drawPath(centerPath, Paint()..color = colors[2]);
    
    // Blaues Dreieck (links)
    centerPath.reset();
    centerPath.moveTo(6 * cellSize, 7.5 * cellSize);
    centerPath.lineTo(7.5 * cellSize, 6 * cellSize);
    centerPath.lineTo(7.5 * cellSize, 9 * cellSize);
    centerPath.close();
    canvas.drawPath(centerPath, Paint()..color = colors[3]);
    
    // Zeichne Sternsymbole für sichere Felder (Startfelder und Mittelpunkte)
    // Startfelder
    _drawStar(canvas, 1 * cellSize, 7 * cellSize, cellSize * 0.4, Paint()..color = Colors.black.withOpacity(0.7)); // Grün
    _drawStar(canvas, 8 * cellSize, 1 * cellSize, cellSize * 0.4, Paint()..color = Colors.black.withOpacity(0.7)); // Gelb
    _drawStar(canvas, 13 * cellSize, 7 * cellSize, cellSize * 0.4, Paint()..color = Colors.black.withOpacity(0.7)); // Blau
    _drawStar(canvas, 7 * cellSize, 13 * cellSize, cellSize * 0.4, Paint()..color = Colors.black.withOpacity(0.7)); // Rot
    
    // Mittelpunktfelder in jedem Quadranten
    _drawStar(canvas, 3 * cellSize, 7 * cellSize, cellSize * 0.4, Paint()..color = Colors.black.withOpacity(0.7));
    _drawStar(canvas, 7 * cellSize, 3 * cellSize, cellSize * 0.4, Paint()..color = Colors.black.withOpacity(0.7));
    _drawStar(canvas, 11 * cellSize, 7 * cellSize, cellSize * 0.4, Paint()..color = Colors.black.withOpacity(0.7));
    _drawStar(canvas, 7 * cellSize, 11 * cellSize, cellSize * 0.4, Paint()..color = Colors.black.withOpacity(0.7));
  }
  
  // Hilfsmethode zum Zeichnen eines einzelnen Spurabschnitts
  void _drawTrackSegment(Canvas canvas, int x, int y, double cellSize, Paint outlinePaint) {
    final rect = Rect.fromLTWH(
      x * cellSize,
      y * cellSize,
      cellSize,
      cellSize
    );
    
    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.drawRect(rect, outlinePaint);
  }
  
  // Hilfsmethode zum Zeichnen einer Heimspalte
  void _drawHomeColumn(Canvas canvas, int startX, int startY, int length, Color color, double cellSize, 
                       {bool vertical = true, bool reverse = false}) {
    for (int i = 0; i < length; i++) {
      final pos = reverse ? length - 1 - i : i;
      final x = vertical ? startX : startX + pos;
      final y = vertical ? startY + pos : startY;
      
      final rect = Rect.fromLTWH(
        x * cellSize,
        y * cellSize,
        cellSize,
        cellSize
      );
      
      canvas.drawRect(rect, Paint()..color = color.withOpacity(0.3));
      canvas.drawRect(rect, Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
  }
  
  void _drawStar(Canvas canvas, double x, double y, double radius, Paint paint) {
    final path = Path();
    final double rotation = -pi / 2;
    final int points = 5;
    
    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? radius : radius * 0.4;
      final double angle = (i * pi / points) + rotation;
      final double xPos = x + cos(angle) * r;
      final double yPos = y + sin(angle) * r;
      
      if (i == 0) {
        path.moveTo(xPos, yPos);
      } else {
        path.lineTo(xPos, yPos);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// CustomPainter for the Capture Effect
class CaptureEffectPainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0 (progress)
  final Color color;
  final int particleCount;
  final Random random;

  CaptureEffectPainter({
    required this.animationValue,
    required this.color,
    this.particleCount = 5,
  }) : random = Random();

  @override
  void paint(Canvas canvas, Size size) { // size is the area given to CustomPaint
    final Paint paint = Paint()..style = PaintingStyle.fill;
    
    double progress = Curves.easeOutCubic.transform(animationValue); // Apply easing

    for (int i = 0; i < particleCount; i++) {
      // Each particle can have a slightly different behavior based on its index or a random seed
      final double randomAngle = (random.nextDouble() + i) * (2 * pi / particleCount);
      final double initialRadius = size.width * 0.1; // Initial distance from center
      final double maxTravelDistance = size.width * 0.3; // How far particles travel

      // Particles move outwards
      final double currentDistance = initialRadius + maxTravelDistance * progress;
      
      final Offset center = Offset(size.width / 2, size.height / 2);
      final Offset particleOffset = Offset(
        center.dx + cos(randomAngle) * currentDistance,
        center.dy + sin(randomAngle) * currentDistance,
      );
      
      double particleRadius = (size.width / 15) * (1.0 - progress); // Particles shrink
      if (particleRadius < 0) particleRadius = 0;

      paint.color = color.withOpacity(max(0, 1.0 - progress * 1.5)); // Fade out

      canvas.drawCircle(
        particleOffset,
        particleRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CaptureEffectPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.color != color;
  }
}

// CustomPainter for the Reached Home Effect
class ReachedHomeEffectPainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0 (progress)
  final Color color;

  ReachedHomeEffectPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) { // size is the area of the token
    final Paint paint = Paint();
    final Offset center = Offset(size.width / 2, size.height / 2);
    
    // Create a pulsing glow effect
    double progress = Curves.easeInOutCubic.transform(animationValue); // Apply easing

    // Outer glow: expands and fades
    double maxGlowRadius = size.width * 0.8; // Max glow size relative to token
    paint.color = color.withOpacity(max(0, 0.5 - (progress * 0.5))); // Fades out
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, maxGlowRadius * progress, paint);

    // Inner shine: a smaller, brighter pulse
    double maxShineRadius = size.width * 0.5;
    paint.color = Colors.white.withOpacity(max(0, 0.7 - (progress * 0.7))); // Fades out faster
    canvas.drawCircle(center, maxShineRadius * progress, paint);
  }

  @override
  bool shouldRepaint(covariant ReachedHomeEffectPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.color != color;
  }
}


class PiecePainter extends CustomPainter {
  final Color color;
  
  PiecePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;
    final width = size.width;
    final pieceWidth = width * 0.8;
    final pieceHeight = height * 0.8;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Schatten
    final shadowPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(width/2, height * 0.85),
        width: pieceWidth * 0.8,
        height: pieceWidth * 0.3,
      ));
    
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    
    // Basis der Figur
    final basePath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(width/2, height * 0.8),
        width: pieceWidth,
        height: pieceWidth * 0.4,
      ));
    
    canvas.drawPath(basePath, paint);
    
    // Körper der Figur (Kegel)
    final bodyPath = Path()
      ..moveTo(width/2 - pieceWidth/2, height * 0.8)
      ..lineTo(width/2, height * 0.2)
      ..lineTo(width/2 + pieceWidth/2, height * 0.8)
      ..close();
    
    canvas.drawPath(bodyPath, paint);
    
    // Highlight für 3D-Effekt
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final highlightPath = Path()
      ..moveTo(width/2, height * 0.2)
      ..lineTo(width/2 + pieceWidth/4, height * 0.6)
      ..lineTo(width/2, height * 0.7)
      ..close();
    
    canvas.drawPath(highlightPath, highlightPaint);
    
    // Kopf der Figur
    canvas.drawCircle(
      Offset(width/2, height * 0.2),
      pieceWidth * 0.2,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
