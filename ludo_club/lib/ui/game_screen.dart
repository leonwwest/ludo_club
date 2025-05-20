import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game_state.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _diceAnimationController;
  late Animation<double> _diceAnimation;
  int _displayDiceValue = 1;

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
      if (_diceAnimationController.value > 0.5 && _diceAnimationController.value < 0.6) {
        setState(() {
          _displayDiceValue = Random().nextInt(6) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _diceAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Club'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          final gameState = gameProvider.gameState;
          final possibleMoves = gameProvider.getPossibleMoves();
          
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
                                gameState.currentPlayer.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (gameState.currentPlayer.isAI)
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
                                gameState.lastDiceValue?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Würfe:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '${gameState.currentRollCount}/3',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
                          child: _buildGameBoard(gameState, possibleMoves, gameProvider),
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
                        onTap: () => _rollDice(gameProvider),
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
                                    gameState.lastDiceValue?.toString() ?? _displayDiceValue.toString(),
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
                        onPressed: gameProvider.isAnimating || gameState.currentPlayer.isAI
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

  Widget _buildGameBoard(GameState gameState, List<int> possibleMoves, GameProvider gameProvider) {
    // Einfaches Spielbrett mit 52 Feldern
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.maxWidth;
        final fieldSize = boardSize / 13; // 13x13 Raster für das Spielbrett
        
        return Stack(
          children: [
            // Spielbrett-Hintergrund
            CustomPaint(
              size: Size(boardSize, boardSize),
              painter: GameBoardPainter(),
            ),
            
            // Spielfelder
            ...List.generate(GameState.totalFields, (index) {
              final position = _calculateFieldPosition(index, boardSize);
              final isHighlighted = possibleMoves.contains(index);
              
              return Positioned(
                left: position.dx - fieldSize / 2,
                top: position.dy - fieldSize / 2,
                child: GestureDetector(
                  onTap: isHighlighted
                      ? () => _moveToken(gameProvider, index)
                      : null,
                  child: Container(
                    width: fieldSize,
                    height: fieldSize,
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? Colors.yellow.withOpacity(0.5)
                          : Colors.transparent,
                      border: Border.all(
                        color: isHighlighted ? Colors.orange : Colors.transparent,
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
            
            // Spielfiguren
            ...gameState.players.map((player) {
              final position = _calculateFieldPosition(player.position, boardSize);
              final playerColor = _getPlayerColor(player.id);
              
              return Positioned(
                left: position.dx - fieldSize / 2,
                top: position.dy - fieldSize / 2,
                child: Container(
                  width: fieldSize,
                  height: fieldSize,
                  decoration: BoxDecoration(
                    color: playerColor,
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
                      player.name.substring(0, 1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            
            // Safe Zones markieren
            ...gameState.players.map((player) {
              final safeIndex = (gameState.startIndex[player.id]! + 4) % GameState.totalFields;
              final position = _calculateFieldPosition(safeIndex, boardSize);
              final playerColor = _getPlayerColor(player.id);
              
              return Positioned(
                left: position.dx - fieldSize / 2,
                top: position.dy - fieldSize / 2,
                child: Container(
                  width: fieldSize,
                  height: fieldSize,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: playerColor,
                      width: 3,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // Berechnet die Position eines Feldes auf dem Spielbrett
  Offset _calculateFieldPosition(int index, double boardSize) {
    final center = boardSize / 2;
    final radius = boardSize * 0.4;
    final angle = 2 * pi * index / GameState.totalFields;
    
    return Offset(
      center + radius * cos(angle),
      center + radius * sin(angle),
    );
  }

  // Gibt die Farbe für einen Spieler zurück
  Color _getPlayerColor(String playerId) {
    switch (playerId) {
      case 'player1':
        return Colors.red;
      case 'player2':
        return Colors.blue;
      case 'player3':
        return Colors.green;
      case 'player4':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  // Würfeln
  Future<void> _rollDice(GameProvider gameProvider) async {
    if (gameProvider.isAnimating) return;
    
    _diceAnimationController.reset();
    _diceAnimationController.forward();
    
    final result = await gameProvider.rollDice();
    setState(() {
      _displayDiceValue = result;
    });
  }

  // Spielfigur bewegen
  Future<void> _moveToken(GameProvider gameProvider, int targetIndex) async {
    await gameProvider.moveToken(targetIndex);
  }
}

// CustomPainter für das Spielbrett
class GameBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    
    // Hintergrund
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, size.width / 2, backgroundPaint);
    
    // Spielfeld-Umriss
    final outlinePaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius, outlinePaint);
    
    // Spielfelder
    final fieldPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    
    final fieldOutlinePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (int i = 0; i < 52; i++) {
      final angle = 2 * pi * i / 52;
      final fieldCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      canvas.drawCircle(fieldCenter, size.width / 30, fieldPaint);
      canvas.drawCircle(fieldCenter, size.width / 30, fieldOutlinePaint);
    }
    
    // Startpositionen markieren
    final startPositions = [0, 13, 26, 39];
    final startColors = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
    
    for (int i = 0; i < startPositions.length; i++) {
      final angle = 2 * pi * startPositions[i] / 52;
      final startCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      final startPaint = Paint()
        ..color = startColors[i]
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(startCenter, size.width / 25, startPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
