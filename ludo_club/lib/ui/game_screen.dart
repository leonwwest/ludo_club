import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game_state.dart' as models;
import '../logic/ludo_game_logic.dart' as logic;

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
  models.Piece? _animatingPiece; 
  logic.PlayerColor? _animatingPlayerColor; 
  Offset? _animationCurrentOffset;
  // Temporary storage for move details during animation
  logic.PlayerColor? _actualPlayerColorForMove; 
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
  logic.PlayerColor? _reachedHomeAnimatingPlayerColor; 
  int? _reachedHomeAnimatingPieceId; 
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
          gameProvider.movePiece(_animatingPiece!); // _animatingPiece is models.Piece
        }
        setState(() {
          _animatingPiece = null; // models.Piece
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
  // _startCaptureAnimation and _startReachedHomeAnimation are not explicitly called,
  // their logic is incorporated into the build method's postFrameCallback.
  // So, these separate methods might be removed if not used elsewhere.

  Color _getDisplayColorForPlayer(logic.PlayerColor playerColor) {
    switch (playerColor) {
      case logic.PlayerColor.red:
        return Colors.red.shade700;
      case logic.PlayerColor.green:
        return Colors.green.shade700;
      case logic.PlayerColor.yellow:
        return Colors.yellow.shade600; 
      case logic.PlayerColor.blue:
        return Colors.blue.shade700;
      default: // Should not happen with logic.PlayerColor
        return Colors.grey.shade700; 
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
          // Assuming gameProvider.currentPlayerColor is logic.PlayerColor
          final currentPlayerMeta = gameProvider.getPlayerMeta(gameProvider.currentPlayerColor);
          final bool isGameOver = gameProvider.gameState.isGameOver;
          // gameProvider.gameState.winnerId is models.PlayerColor?
          final models.PlayerColor? winnerColorModel = gameProvider.gameState.winnerId;

          if (isGameOver && winnerColorModel != null && !_winnerDialogShown) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if(mounted) {
                 // _showWinnerDialog expects models.PlayerColor as its second argument
                 _showWinnerDialog(gameProvider, winnerColorModel);
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
        final fieldSize = boardSize / 15.0; 
        
        // Assuming gameProvider.allBoardPieces returns List<models.Piece>
        final List<models.Piece> allModelPieces = gameProvider.allBoardPieces;
        // Assuming gameProvider.getMovablePieces() returns List<models.Piece>
        final List<models.Piece> movableModelPieces = gameProvider.getMovablePieces();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (gameProvider.showCaptureEffect && !_isCaptureAnimating && gameProvider.captureEffectBoardIndex != null) {
            // gameProvider.currentPlayerColor is logic.PlayerColor
             _captureEffectScreenPosition = _calculateMainBoardPosition(gameProvider.captureEffectBoardIndex!, boardSize, fieldSize, gameProvider.currentPlayerColor);
            if (_captureEffectScreenPosition != null) {
                 setState(() { _isCaptureAnimating = true; });
                 _captureAnimationController.forward(from: 0.0);
            }
          }
          if (gameProvider.showReachedHomeEffect && !_isReachedHomeAnimating && gameProvider.reachedHomePlayerId != null && gameProvider.reachedHomeTokenIndex != null) {
            // gameProvider.reachedHomePlayerId is logic.PlayerColor
            // gameProvider.reachedHomeTokenIndex is piece.id (int)
            logic.VisualPieceInfo finishedPieceVisualInfo = logic.VisualPieceInfo(
              pieceRef: logic.Piece(gameProvider.reachedHomePlayerId!, gameProvider.reachedHomeTokenIndex!), // Dummy logic.Piece for ref
              pathType: logic.PiecePathType.FINISHED,
              displayIndex: gameProvider.reachedHomeTokenIndex!, // Using pieceId for stacking in _calculateFinishPosition
              color: gameProvider.reachedHomePlayerId!,
            );
            _reachedHomeEffectScreenPosition = _getOffsetForVisualInfo(finishedPieceVisualInfo, boardSize, fieldSize);
            _reachedHomeEffectColor = _getDisplayColorForPlayer(gameProvider.reachedHomePlayerId!);
            if(_reachedHomeEffectScreenPosition != null){
                setState(() { 
                    _isReachedHomeAnimating = true; 
                    _reachedHomeAnimatingPlayerColor = gameProvider.reachedHomePlayerId; 
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
            ...movableModelPieces.map((modelPiece) {
              // ASSUMPTION: gameProvider.getVisualPieceInfo(models.Piece) exists and returns logic.VisualPieceInfo
              final logic.VisualPieceInfo visualInfo = gameProvider.getVisualPieceInfo(modelPiece);
              final Offset pieceScreenPos = _getOffsetForVisualInfo(visualInfo, boardSize, fieldSize);
              return Positioned(
                left: pieceScreenPos.dx - fieldSize / 2,
                top: pieceScreenPos.dy - fieldSize / 2,
                child: GestureDetector(
                  onTap: () => _initiatePawnAnimation(gameProvider, modelPiece, boardSize), // modelPiece is models.Piece
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
            ...allModelPieces.map((modelPiece) {
              Offset displayPosition;
              // _animatingPiece and modelPiece are both models.Piece
              if (_animatingPiece != null && _animatingPiece!.color == modelPiece.color && _animatingPiece!.id == modelPiece.id && _animationCurrentOffset != null) {
                displayPosition = _animationCurrentOffset!;
              } else {
                // ASSUMPTION: gameProvider.getVisualPieceInfo(models.Piece) exists
                final logic.VisualPieceInfo visualInfo = gameProvider.getVisualPieceInfo(modelPiece);
                displayPosition = _getOffsetForVisualInfo(visualInfo, boardSize, fieldSize);
              }
              // _buildToken expects models.Piece
              return _buildToken(modelPiece, displayPosition, fieldSize, gameProvider, boardSize);
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
  
  // _buildHomePiece removed.

  // Baut eine einzelne Spielfigur. Expects models.Piece.
  Widget _buildToken(models.Piece piece, Offset screenPosition, double fieldSize, GameProvider gameProvider, double boardSize) {
    // piece.color is models.PlayerColor. _getDisplayColorForPlayer expects logic.PlayerColor.
    // ASSUMPTION: gameProvider.getVisualPieceInfo(piece).color provides the logic.PlayerColor
    final logic.VisualPieceInfo visualInfo = gameProvider.getVisualPieceInfo(piece);
    final displayPlayerColor = _getDisplayColorForPlayer(visualInfo.color);

    // gameProvider.currentPlayerColor is logic.PlayerColor. visualInfo.color is logic.PlayerColor.
    final bool isCurrentPlayerPiece = visualInfo.color == gameProvider.currentPlayerColor;
    // gameProvider.getMovablePieces() returns List<models.Piece>. piece is models.Piece.
    final bool canBeMoved = isCurrentPlayerPiece && gameProvider.getMovablePieces().any((p) => p.id == piece.id && p.color == piece.color);
    
    return Positioned(
      left: screenPosition.dx - fieldSize / 2, 
      top: screenPosition.dy - fieldSize / 2,  
      child: GestureDetector(
        onTap: canBeMoved && !gameProvider.isAnimating && gameProvider.currentDiceValue > 0
          ? () => _initiatePawnAnimation(gameProvider, piece, boardSize) // piece is models.Piece
          : null,
        child: Container(
          width: fieldSize,
          height: fieldSize,
          decoration: BoxDecoration(
            color: displayPlayerColor, 
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

  // _showMoveOptions method removed.

  // Helper to get screen offset based on VisualPieceInfo
  Offset _getOffsetForVisualInfo(logic.VisualPieceInfo visualInfo, double boardSize, double fieldSize) {
    switch (visualInfo.pathType) {
      case logic.PiecePathType.YARD:
        // visualInfo.displayIndex is pieceId (0-3 for yard spot)
        return _calculateBasePosition(visualInfo.color, visualInfo.displayIndex, boardSize, fieldSize);
      case logic.PiecePathType.MAIN_PATH:
        // visualInfo.displayIndex is global path index (0-51)
        return _calculateMainBoardPosition(visualInfo.displayIndex, boardSize, fieldSize, visualInfo.color);
      case logic.PiecePathType.HOME_PATH:
        // visualInfo.displayIndex is home path index (0 to homeLength-1, e.g., 0-5)
        return _calculateHomePathPosition(visualInfo.color, visualInfo.displayIndex, boardSize, fieldSize);
      case logic.PiecePathType.FINISHED:
        // visualInfo.displayIndex could be piece.id for stacking, or a common index.
        // _calculateFinishPosition expects piece.id (0-3) for stacking.
        return _calculateFinishPosition(visualInfo.color, visualInfo.pieceRef.id, boardSize, fieldSize);
      default: // Should not happen
        return Offset(boardSize / 2, boardSize / 2); 
    }
  }

  // This wrapper is kept for callsites that still have models.Piece, e.g. animation start.
  // Ideally, GameProvider would provide VisualPieceInfo directly, and this wrapper would be removed.
  Offset _getOffsetForLogicalPosition(models.Piece piece, double boardSize, GameProvider gameProvider) {
    final double fieldSize = boardSize / 15.0;
    // ASSUMPTION: gameProvider.getVisualPieceInfo(models.Piece) exists.
    final logic.VisualPieceInfo visualInfo = gameProvider.getVisualPieceInfo(piece);
    return _getOffsetForVisualInfo(visualInfo, boardSize, fieldSize);
  }

  Offset _calculateBasePosition(logic.PlayerColor playerColor, int pieceDisplayIndex, double boardSize, double fieldSize) {
    // pieceDisplayIndex is the yard spot (0-3) from VisualPieceInfo.
    // GameBoardPainter colors: Green (TL), Yellow (TR), Red (BL), Blue (BR)
    // logic.PlayerColor mapping to these visual corners:
    Map<logic.PlayerColor, Offset> playerCornerOffsets = {
        logic.PlayerColor.green:  Offset(0 * fieldSize, 0 * fieldSize),   // Top-left
        logic.PlayerColor.yellow: Offset(9 * fieldSize, 0 * fieldSize), // Top-right
        logic.PlayerColor.red:    Offset(0 * fieldSize, 9 * fieldSize),   // Bottom-left
        logic.PlayerColor.blue:   Offset(9 * fieldSize, 9 * fieldSize),  // Bottom-right
    };
    
    Offset cornerOffset = playerCornerOffsets[playerColor] ?? Offset(0,0); // Default to TL if color not found

    // Positions within the 4x4 inner white square of the 6x6 player corner (centers of pieces)
    List<Offset> pieceRelativeOffsets = [
        Offset(cornerOffset.dx + 2.0 * fieldSize, cornerOffset.dy + 2.0 * fieldSize), // Top-left piece in base
        Offset(cornerOffset.dx + 4.0 * fieldSize, cornerOffset.dy + 2.0 * fieldSize), // Top-right piece in base
        Offset(cornerOffset.dx + 2.0 * fieldSize, cornerOffset.dy + 4.0 * fieldSize), // Bottom-left piece in base
        Offset(cornerOffset.dx + 4.0 * fieldSize, cornerOffset.dy + 4.0 * fieldSize), // Bottom-right piece in base
    ];

    if (pieceDisplayIndex >= 0 && pieceDisplayIndex < pieceRelativeOffsets.length) {
        return pieceRelativeOffsets[pieceDisplayIndex];
    }
    // Fallback if pieceDisplayIndex is out of bounds
    return Offset(fieldSize, fieldSize); 
  }
  
  Offset _calculateFinishPosition(logic.PlayerColor playerColor, int pieceId, double boardSize, double fieldSize) {
    // pieceId is the original piece.id (0-3), used for stacking finished pieces.
    // GameBoardPainter center triangle tips:
    Map<logic.PlayerColor, Offset> finishAreaCenters = {
      logic.PlayerColor.green:  Offset(7.5 * fieldSize, 6.5 * fieldSize), // Green triangle tip (top)
      logic.PlayerColor.yellow: Offset(8.5 * fieldSize, 7.5 * fieldSize), // Yellow triangle tip (right)
      logic.PlayerColor.red:    Offset(7.5 * fieldSize, 8.5 * fieldSize), // Red triangle tip (bottom)
      logic.PlayerColor.blue:   Offset(6.5 * fieldSize, 7.5 * fieldSize), // Blue triangle tip (left)
    };
    
    double stackOffset = pieceId * (fieldSize * 0.25); // Small offset for stacking based on piece's original ID
    Offset basePos = finishAreaCenters[playerColor] ?? Offset(boardSize/2, boardSize/2);

    // Adjust offset based on player color to stack inwards towards board center, or along a line.
    switch (playerColor) {
        case logic.PlayerColor.green:  return Offset(basePos.dx, basePos.dy + stackOffset); // Stack downwards from tip
        case logic.PlayerColor.yellow: return Offset(basePos.dx - stackOffset, basePos.dy); // Stack leftwards from tip
        case logic.PlayerColor.red:    return Offset(basePos.dx, basePos.dy - stackOffset); // Stack upwards from tip
        case logic.PlayerColor.blue:   return Offset(basePos.dx + stackOffset, basePos.dy); // Stack rightwards from tip
        default: return basePos;
    }
  }
  
  Offset _calculateHomePathPosition(logic.PlayerColor playerColor, int homePathDisplayIndex, double boardSize, double fieldSize) {
    // homePathDisplayIndex is 0 to homeLength-1 (e.g. 0-5 if homeLength is 6).
    // GameBoardPainter._drawHomeColumn draws 5 cells for each home path.
    // logic.LudoGame.homeLength is 6. This means the 6th piece (index 5) might not have a visual spot if painter only makes 5.
    // For now, this function maps to the 5 visual cells.
    
    // Mapping logic.PlayerColor to GameBoardPainter's home column drawing:
    // Green (TL corner): Column 7, Rows 1-5 (top to bottom for painter) -> Indices 0-4 -> (7.5, 1.5)...(7.5, 5.5)
    // Yellow (TR corner): Row 7, Cols 9-13 (left to right for painter) -> Indices 0-4 -> (9.5, 7.5)...(13.5, 7.5)
    // Red (BL corner): Column 7, Rows 13-9 (bottom to top for painter) -> Indices 0-4 -> (7.5, 13.5)...(7.5, 9.5)
    // Blue (BR corner): Row 7, Cols 5-1 (right to left for painter)   -> Indices 0-4 -> (5.5, 7.5)...(1.5, 7.5)

    Map<logic.PlayerColor, List<Offset>> homePathCoords = {
      logic.PlayerColor.green:  List.generate(5, (i) => Offset(7.5 * fieldSize, (1.5 + i) * fieldSize)),
      logic.PlayerColor.yellow: List.generate(5, (i) => Offset((9.5 + i) * fieldSize, 7.5 * fieldSize)),
      logic.PlayerColor.red:    List.generate(5, (i) => Offset(7.5 * fieldSize, (13.5 - i) * fieldSize)),
      logic.PlayerColor.blue:   List.generate(5, (i) => Offset((5.5 - i) * fieldSize, 7.5 * fieldSize)),
    };
    
    if (homePathCoords.containsKey(playerColor) && homePathDisplayIndex >= 0 && homePathDisplayIndex < 5 /* number of painted cells */) {
      return homePathCoords[playerColor]![homePathDisplayIndex];
    }
    // Fallback for indices outside the 0-4 range (e.g. if homeLength is 6 and piece is on 6th spot)
    // Could place it near the start of the finish zone or slightly off the last painted cell.
    // For now, center of board.
    if (homePathCoords.containsKey(playerColor) && homePathDisplayIndex == 5) { // Handle 6th piece (index 5)
        // Place it near the entrance of the finish triangle, slightly offset from the last cell.
        Offset lastCell = homePathCoords[playerColor]![4];
        switch (playerColor) {
            case logic.PlayerColor.green: return Offset(lastCell.dx, lastCell.dy + fieldSize*0.7);
            case logic.PlayerColor.yellow: return Offset(lastCell.dx + fieldSize*0.7, lastCell.dy);
            case logic.PlayerColor.red: return Offset(lastCell.dx, lastCell.dy - fieldSize*0.7);
            case logic.PlayerColor.blue: return Offset(lastCell.dx - fieldSize*0.7, lastCell.dy);
            default: break;
        }
    }
    return Offset(boardSize/2, boardSize/2); 
  }

  // Static map for main board positions, calculated once.
  static final Map<int, Offset> _mainPathCellCenters = _createMainPathCellCenters();

  static Map<int, Offset> _createMainPathCellCenters() {
    final Map<int, Offset> centers = {};
    // Path definitions are based on cell centers (col_idx + 0.5, row_idx + 0.5)
    // LudoGame.startIndex: Red:0, Green:13, Blue:26, Yellow:39
    // GameBoardPainter visual corners: Green(TL), Yellow(TR), Red(BL), Blue(BR)

    // Red Path Segment (Indices 0-12) - Visual: Bottom-Left Red player corner
    centers[0] = Offset(7.5, 13.5); centers[1] = Offset(7.5, 12.5); centers[2] = Offset(7.5, 11.5);
    centers[3] = Offset(7.5, 10.5); centers[4] = Offset(7.5, 9.5);
    centers[5] = Offset(6.5, 8.5); // Turn left (relative to Red's view)
    centers[6] = Offset(5.5, 8.5); centers[7] = Offset(4.5, 8.5); centers[8] = Offset(3.5, 8.5);
    centers[9] = Offset(2.5, 8.5); centers[10] = Offset(1.5, 8.5);
    centers[11] = Offset(0.5, 7.5); // Turn up (onto Green's approach)
    centers[12] = Offset(1.5, 7.5); // Field before Green's start

    // Green Path Segment (Indices 13-25) - Visual: Top-Left Green player corner
    centers[13] = Offset(1.5, 6.5); centers[14] = Offset(2.5, 6.5); centers[15] = Offset(3.5, 6.5);
    centers[16] = Offset(4.5, 6.5); centers[17] = Offset(5.5, 6.5);
    centers[18] = Offset(6.5, 5.5); // Turn up
    centers[19] = Offset(6.5, 4.5); centers[20] = Offset(6.5, 3.5); centers[21] = Offset(6.5, 2.5);
    centers[22] = Offset(6.5, 1.5);
    centers[23] = Offset(7.5, 0.5); // Turn right (onto "LudoGame Blue" / "Painter Yellow" approach)
    centers[24] = Offset(7.5, 1.5); // Field before "LudoGame Blue" start

    // "LudoGame Blue" Path Segment (Indices 26-38) - Visual: Top-Right Yellow player corner
    centers[26] = Offset(8.5, 1.5); centers[27] = Offset(8.5, 2.5); centers[28] = Offset(8.5, 3.5);
    centers[29] = Offset(8.5, 4.5); centers[30] = Offset(8.5, 5.5);
    centers[31] = Offset(9.5, 6.5); // Turn right
    centers[32] = Offset(10.5, 6.5); centers[33] = Offset(11.5, 6.5); centers[34] = Offset(12.5, 6.5);
    centers[35] = Offset(13.5, 6.5);
    centers[36] = Offset(14.5, 7.5); // Turn down (onto "LudoGame Yellow" / "Painter Blue" approach)
    centers[37] = Offset(13.5, 7.5); // Field before "LudoGame Yellow" start

    // "LudoGame Yellow" Path Segment (Indices 39-51) - Visual: Bottom-Right Blue player corner
    centers[39] = Offset(13.5, 8.5); centers[40] = Offset(12.5, 8.5); centers[41] = Offset(11.5, 8.5);
    centers[42] = Offset(10.5, 8.5); centers[43] = Offset(9.5, 8.5);
    centers[44] = Offset(8.5, 9.5);  // Turn down
    centers[45] = Offset(8.5, 10.5); centers[46] = Offset(8.5, 11.5); centers[47] = Offset(8.5, 12.5);
    centers[48] = Offset(8.5, 13.5);
    centers[49] = Offset(7.5, 14.5); // Turn left (onto Red's approach)
    centers[50] = Offset(6.5, 14.5); // Penultimate step for Yellow
    centers[51] = Offset(7.5,14.5); //This was the original index 49. Yellow's 13th step (index 51) must be Red's predecessor.
                                    // Red's Start is (7.5, 13.5) [index 0]. Red's predecessor is (7.5, 14.5).
                                    // So centers[51] should be (7.5, 14.5).
                                    // The path before that: (8.5, 14.5) not (6.5, 14.5)
    // Re-correcting Yellow's last few steps for perfect loop:
    // centers[48] = Offset(8.5, 13.5); // Correct
    // centers[49] = Offset(8.5, 14.5); // New point for smoother turn to Red's predecessor
    // centers[50] = Offset(7.5, 14.5); // This is Red's Predecessor (Correct for index 51)
    // centers[51] = Offset(7.5, 14.5); // This is Red's Predecessor
    // This means Yellow's 11th, 12th, 13th steps are:
    // 39+10=49: (8.5, 13.5) -> centers[48]
    // 39+11=50: (8.5, 14.5) -> New
    // 39+12=51: (7.5, 14.5) -> Red's predecessor
    centers[49] = Offset(8.5, 14.5); // Yellow's 11th step (index 49)
    centers[50] = Offset(7.5, 14.5); // Yellow's 12th step (index 50) - THIS IS RED'S PREDECESSOR
    centers[51] = Offset(7.5, 14.5); // Yellow's 13th step (index 51) - Red's Predecessor. This is correct.
                                     // The map key 51 should point to Red's predecessor.
    return centers;
  }

  Offset _calculateMainBoardPosition(int globalPathIndex, double boardSize, double fieldSize, logic.PlayerColor forPlayerColorIfAmbiguous) {
    // globalPathIndex is 0 to LudoGame.mainPathLength - 1 (e.g., 0-51)
    
    if (_mainPathCellCenters.containsKey(globalPathIndex)) {
        Offset cellCenter = _mainPathCellCenters[globalPathIndex]!;
        return Offset(cellCenter.dx * fieldSize, cellCenter.dy * fieldSize);
    }
    
    // Fallback: center of the board (should not happen with correct indices)
    print("Warning: Main board position not found for index $globalPathIndex. Using fallback.");
    return Offset(boardSize / 2, boardSize / 2);
  }

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

  Future<void> _initiatePawnAnimation(GameProvider gameProvider, models.Piece pieceToMove, double boardSize) async {
    if (gameProvider.isAnimating) return;

    // pieceToMove is models.Piece. Get its VisualInfo.
    // ASSUMPTION: gameProvider.getVisualPieceInfo exists.
    final logic.VisualPieceInfo startVisualInfo = gameProvider.getVisualPieceInfo(pieceToMove);
    _actualPlayerColorForMove = startVisualInfo.color; // logic.PlayerColor
    
    // Placeholder for target VisualPieceInfo - THIS IS A MAJOR SIMPLIFICATION
    // A real implementation needs GameProvider to return the VisualPieceInfo of the piece *after* the move.
    logic.VisualPieceInfo targetVisualInfo = gameProvider.getPotentialVisualPieceInfoAfterMove(pieceToMove, gameProvider.currentDiceValue);
    // The above line is hypothetical. If it doesn't exist, the animation target will be less accurate.
    // Fallback to a very simplified calculation if the hypothetical method isn't available:
    // This simplified calculation is error-prone, especially for home entry / finish.
    /*
    logic.PiecePathType targetPathType = startVisualInfo.pathType;
    int targetDisplayIndex = startVisualInfo.displayIndex;
    int dice = gameProvider.currentDiceValue;
    if (startVisualInfo.pathType == logic.PiecePathType.YARD && dice == 6) {
        targetPathType = logic.PiecePathType.MAIN_PATH;
        targetDisplayIndex = logic.LudoGame.startIndex[startVisualInfo.color]!;
    } else if (startVisualInfo.pathType == logic.PiecePathType.MAIN_PATH) {
        targetDisplayIndex = (startVisualInfo.displayIndex + dice) % logic.LudoGame.mainPathLength; // Ignores home entry for simplicity
    } else if (startVisualInfo.pathType == logic.PiecePathType.HOME_PATH) {
        targetDisplayIndex = startVisualInfo.displayIndex + dice;
        if (targetDisplayIndex >= logic.LudoGame.homeLength) {
            targetPathType = logic.PiecePathType.FINISHED;
            targetDisplayIndex = startVisualInfo.pieceRef.id; // For stacking
        }
    }
    targetVisualInfo = logic.VisualPieceInfo(
        pieceRef: startVisualInfo.pieceRef, 
        pathType: targetPathType, 
        displayIndex: targetDisplayIndex, 
        color: startVisualInfo.color
    );
    */


    _animatingPiece = pieceToMove; // models.Piece
    _animatingPlayerColor = startVisualInfo.color; // logic.PlayerColor

    final double fieldSize = boardSize / 15.0;
    Offset startOffset = _getOffsetForVisualInfo(startVisualInfo, boardSize, fieldSize);
    // Use the potentially more accurate targetVisualInfo from GameProvider
    Offset endOffset = _getOffsetForVisualInfo(targetVisualInfo, boardSize, fieldSize);

    _pawnAnimation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _pawnAnimationController,
      curve: Curves.easeInOut,
    ));
    
    setState(() {
      gameProvider.isAnimating = true;
      _animationCurrentOffset = startOffset;
    });

    _pawnAnimationController.forward(from: 0.0);
  }

  void _showWinnerDialog(GameProvider gameProvider, models.PlayerColor winnerColorModel) {
    // winnerColorModel is models.PlayerColor.
    // gameProvider.getPlayerMeta should ideally take models.PlayerColor and its PlayerMeta.color should be logic.PlayerColor
    final winnerMeta = gameProvider.getPlayerMeta(winnerColorModel); 
    final displayPlayerColor = _getDisplayColorForPlayer(winnerMeta.color); // winnerMeta.color is logic.PlayerColor
    
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
                // gameProvider.startNewGame expects List<models.Player>
                gameProvider.startNewGame(
                  gameProvider.gameState.players.map((p_model) => // p_model is models.Player
                    models.Player(p_model.id, p_model.name, isAI: p_model.isAI) 
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
