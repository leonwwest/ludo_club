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
  bool _winnerDialogShown = false;

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
        actions: [
          // Sound-Einstellungen-Button
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Sound-Einstellungen',
            onPressed: _showSoundSettingsDialog,
          ),
          // Speichern-Button
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Spiel speichern',
            onPressed: _showSaveDialog,
          ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          final gameState = gameProvider.gameState;
          final possibleMoves = gameProvider.getPossibleMoves();
          
          // Prüfe, ob das Spiel vorbei ist und zeige den Gewinnbildschirm
          if (gameState.isGameOver && !_winnerDialogShown) {
            // Verzögerung für eine bessere Benutzererfahrung
            Future.delayed(const Duration(milliseconds: 500), () {
              _showWinnerDialog(gameState.winner!);
            });
            _winnerDialogShown = true;
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
    // Einfaches Spielbrett mit 40 Feldern im Kreis + Heimatfelder + Zielfelder
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.maxWidth;
        final fieldSize = boardSize / 13; // 13x13 Raster für das Spielbrett
        
        // Hole die detaillierten Zugmöglichkeiten (Token-Index + Zielposition)
        final moveDetails = gameProvider.getPossibleMoveDetails();
        
        return Stack(
          children: [
            // Spielbrett-Hintergrund
            CustomPaint(
              size: Size(boardSize, boardSize),
              painter: GameBoardPainter(),
            ),
            
            // Spielfelder und Zielpositionen hervorheben
            ...moveDetails.map((move) {
              final targetPos = move['targetPosition']!;
              if (targetPos == GameState.finishedPosition) {
                // Zielposition besonders markieren
                return Container(); // Platzhalter, kann später angepasst werden
              }
              
              final position = _calculateFieldPosition(targetPos, boardSize);
              
              return Positioned(
                left: position.dx - fieldSize / 2,
                top: position.dy - fieldSize / 2,
                child: GestureDetector(
                  onTap: () => _moveToken(gameProvider, move['tokenIndex']!, targetPos),
                  child: Container(
                    width: fieldSize,
                    height: fieldSize,
                    decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.5),
                      border: Border.all(
                        color: Colors.orange,
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }).toList(),
            
            // Spielfiguren
            ...gameState.players.expand((player) {
              return player.tokenPositions.asMap().entries.map((entry) {
                final tokenIndex = entry.key;
                final position = entry.value;
                
                // Figur ist in der Basis
                if (position == GameState.basePosition) {
                  // Berechne Position in der Basis des Spielers
                  final basePosition = _calculateBasePosition(player.id, tokenIndex, boardSize);
                  return _buildToken(player, tokenIndex, basePosition, fieldSize);
                }
                
                // Figur ist im Ziel
                if (position == GameState.finishedPosition) {
                  // Berechne Position im Zielbereich
                  final finishPosition = _calculateFinishPosition(player.id, tokenIndex, boardSize);
                  return _buildToken(player, tokenIndex, finishPosition, fieldSize);
                }
                
                // Figur ist auf dem Heimweg
                if (position >= GameState.totalFields) {
                  final homePosition = _calculateHomePathPosition(player.id, position - GameState.totalFields, boardSize);
                  return _buildToken(player, tokenIndex, homePosition, fieldSize);
                }
                
                // Figur ist auf dem Hauptspielfeld
                final boardPosition = _calculateFieldPosition(position, boardSize);
                return _buildToken(player, tokenIndex, boardPosition, fieldSize);
              });
            }).toList(),
            
            // Safe Zones markieren
            ...gameState.players.map((player) {
              final safeIndex = gameState.startIndex[player.id]!;
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

  // Baut eine einzelne Spielfigur
  Widget _buildToken(Player player, int tokenIndex, Offset position, double fieldSize) {
    final playerColor = _getPlayerColor(player.id);
    final canBeMoved = Provider.of<GameProvider>(context, listen: false)
        .getPossibleMoveDetails()
        .any((move) => move['tokenIndex'] == tokenIndex);
    
    return Positioned(
      left: position.dx - fieldSize / 2,
      top: position.dy - fieldSize / 2,
      child: GestureDetector(
        onTap: canBeMoved ? () => _showMoveOptions(player.id, tokenIndex) : null,
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
              (tokenIndex + 1).toString(),
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

  // Zeigt Popup mit möglichen Zügen für diese Figur
  void _showMoveOptions(String playerId, int tokenIndex) {
    if (playerId != Provider.of<GameProvider>(context, listen: false).gameState.currentTurnPlayerId) {
      return;
    }
    
    final moveDetails = Provider.of<GameProvider>(context, listen: false)
        .getPossibleMoveDetails()
        .where((move) => move['tokenIndex'] == tokenIndex)
        .toList();
        
    if (moveDetails.isEmpty) return;
    
    // Wenn nur ein möglicher Zug, direkt ausführen
    if (moveDetails.length == 1) {
      _moveToken(Provider.of<GameProvider>(context, listen: false), 
        tokenIndex, moveDetails[0]['targetPosition']!);
      return;
    }
    
    // Hier könnte ein Dialog angezeigt werden, falls mehrere Ziele möglich sind
    // Aktuell nicht nötig, da immer nur ein Ziel pro Figur möglich ist
  }

  // Berechnet die Position in der Basis eines Spielers
  Offset _calculateBasePosition(String playerId, int tokenIndex, double boardSize) {
    final fieldSize = boardSize / 13;
    final basePositions = {
      'player1': [
        Offset(2 * fieldSize, 2 * fieldSize),
        Offset(4 * fieldSize, 2 * fieldSize),
        Offset(2 * fieldSize, 4 * fieldSize),
        Offset(4 * fieldSize, 4 * fieldSize),
      ],
      'player2': [
        Offset(9 * fieldSize, 2 * fieldSize),
        Offset(11 * fieldSize, 2 * fieldSize),
        Offset(9 * fieldSize, 4 * fieldSize),
        Offset(11 * fieldSize, 4 * fieldSize),
      ],
      'player3': [
        Offset(9 * fieldSize, 9 * fieldSize),
        Offset(11 * fieldSize, 9 * fieldSize),
        Offset(9 * fieldSize, 11 * fieldSize),
        Offset(11 * fieldSize, 11 * fieldSize),
      ],
      'player4': [
        Offset(2 * fieldSize, 9 * fieldSize),
        Offset(4 * fieldSize, 9 * fieldSize),
        Offset(2 * fieldSize, 11 * fieldSize),
        Offset(4 * fieldSize, 11 * fieldSize),
      ],
    };
    
    return basePositions[playerId]![tokenIndex];
  }
  
  // Berechnet die Position im Zielbereich
  Offset _calculateFinishPosition(String playerId, int tokenIndex, double boardSize) {
    final fieldSize = boardSize / 13;
    final finishPositions = {
      'player1': Offset(6 * fieldSize, 6 * fieldSize),
      'player2': Offset(7 * fieldSize, 6 * fieldSize),
      'player3': Offset(7 * fieldSize, 7 * fieldSize),
      'player4': Offset(6 * fieldSize, 7 * fieldSize),
    };
    
    // Im Zielfeld werden die Tokens gestapelt
    return finishPositions[playerId]!;
  }
  
  // Berechnet die Position auf dem Heimweg (Zielgerade)
  Offset _calculateHomePathPosition(String playerId, int homePathIndex, double boardSize) {
    final fieldSize = boardSize / 13;
    
    // Pfadkoordinaten für jeden Spieler
    final homePaths = {
      'player1': [
        Offset(6 * fieldSize, 5 * fieldSize),
        Offset(6 * fieldSize, 4 * fieldSize),
        Offset(6 * fieldSize, 3 * fieldSize),
        Offset(6 * fieldSize, 2 * fieldSize),
      ],
      'player2': [
        Offset(7 * fieldSize, 6 * fieldSize),
        Offset(8 * fieldSize, 6 * fieldSize),
        Offset(9 * fieldSize, 6 * fieldSize),
        Offset(10 * fieldSize, 6 * fieldSize),
      ],
      'player3': [
        Offset(6 * fieldSize, 7 * fieldSize),
        Offset(6 * fieldSize, 8 * fieldSize),
        Offset(6 * fieldSize, 9 * fieldSize),
        Offset(6 * fieldSize, 10 * fieldSize),
      ],
      'player4': [
        Offset(5 * fieldSize, 6 * fieldSize),
        Offset(4 * fieldSize, 6 * fieldSize),
        Offset(3 * fieldSize, 6 * fieldSize),
        Offset(2 * fieldSize, 6 * fieldSize),
      ],
    };
    
    if (homePathIndex >= 0 && homePathIndex < homePaths[playerId]!.length) {
      return homePaths[playerId]![homePathIndex];
    }
    
    // Fallback
    return Offset(6 * fieldSize, 6 * fieldSize);
  }

  // Berechnet die Position eines Feldes auf dem Spielbrett
  Offset _calculateFieldPosition(int index, double boardSize) {
    final fieldSize = boardSize / 11;
    
    // Startpositionen für jede Seite des Bretts
    final positions = <List<int>>[
      // Obere Reihe (links nach rechts)
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      // Rechte Spalte (oben nach unten)
      [11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
      // Untere Reihe (rechts nach links)
      [21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31],
      // Linke Spalte (unten nach oben)
      [32, 33, 34, 35, 36, 37, 38, 39, 40],
    ];
    
    // Finde die Position im Array
    for (int side = 0; side < positions.length; side++) {
      final sideIndex = positions[side].indexOf(index);
      if (sideIndex != -1) {
        switch (side) {
          case 0: // Obere Reihe
            return Offset(sideIndex * fieldSize + fieldSize/2, 5 * fieldSize + fieldSize/2);
          case 1: // Rechte Spalte
            return Offset(5 * fieldSize + fieldSize/2, sideIndex * fieldSize + fieldSize/2);
          case 2: // Untere Reihe
            return Offset((10 - sideIndex) * fieldSize + fieldSize/2, 5 * fieldSize + fieldSize/2);
          case 3: // Linke Spalte
            return Offset(5 * fieldSize + fieldSize/2, (10 - sideIndex) * fieldSize + fieldSize/2);
        }
      }
    }
    
    // Fallback für ungültige Indizes
    return Offset(5 * fieldSize + fieldSize/2, 5 * fieldSize + fieldSize/2);
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
  Future<void> _moveToken(GameProvider gameProvider, int tokenIndex, int targetPosition) async {
    await gameProvider.moveToken(tokenIndex, targetPosition);
  }

  // Zeigt den Gewinnbildschirm als Dialog an
  void _showWinnerDialog(Player winner) {
    final playerColor = _getPlayerColor(winner.id);
    
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
                  color: playerColor,
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
                    winner.name.substring(0, 1).toUpperCase(),
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
                '${winner.name} hat gewonnen!',
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
                  gameProvider.gameState.players.map((p) => 
                    Player(p.id, p.name, isAI: p.isAI)).toList()
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
    final fieldSize = boardSize / 11; // 11x11 Raster für das Spielbrett
    
    // Hintergrund
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    
    // Spielbrett-Umriss
    final outlinePaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Farbfelder für die Spieler
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
    final homePositions = [
      [0, 0], // Rot (oben links)
      [6, 0], // Blau (oben rechts)
      [6, 6], // Grün (unten rechts)
      [0, 6], // Gelb (unten links)
    ];
    
    // Zeichne die Heimatfelder
    for (int i = 0; i < 4; i++) {
      final color = colors[i];
      final pos = homePositions[i];
      final rect = Rect.fromLTWH(
        pos[0] * fieldSize,
        pos[1] * fieldSize,
        fieldSize * 4,
        fieldSize * 4
      );
      
      final homePaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(rect, homePaint);
      canvas.drawRect(rect, outlinePaint);
      
      // Startfelder in den Ecken
      for (int j = 0; j < 4; j++) {
        final startX = pos[0] * fieldSize + (j % 2) * fieldSize * 2 + fieldSize;
        final startY = pos[1] * fieldSize + (j ~/ 2) * fieldSize * 2 + fieldSize;
        
        final startPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(startX, startY),
          fieldSize * 0.4,
          startPaint
        );
      }
    }
    
    // Zielfelder zeichnen
    final zielPaths = [
      [5, 1, 5, 4], // Rot (von oben)
      [6, 5, 9, 5], // Blau (von rechts)
      [5, 6, 5, 9], // Grün (von unten)
      [4, 5, 1, 5], // Gelb (von links)
    ];
    
    for (int i = 0; i < 4; i++) {
      final color = colors[i];
      final path = zielPaths[i];
      final isVertical = path[0] == path[2];
      
      for (int j = 0; j < 4; j++) {
        final x = isVertical ? path[0] : path[0] + j;
        final y = isVertical ? path[1] + j : path[1];
        
        final zielPaint = Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(x * fieldSize + fieldSize/2, y * fieldSize + fieldSize/2),
          fieldSize * 0.4,
          zielPaint
        );
      }
    }
    
    // Spielfeld-Pfad zeichnen
    final pathPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    
    // Obere Reihe
    for (int i = 0; i < 11; i++) {
      if (i != 5) { // Nicht über Zielfelder zeichnen
        canvas.drawCircle(
          Offset(i * fieldSize + fieldSize/2, 5 * fieldSize + fieldSize/2),
          fieldSize * 0.4,
          pathPaint
        );
      }
    }
    
    // Linke Spalte
    for (int i = 0; i < 11; i++) {
      if (i != 5) { // Nicht über Zielfelder zeichnen
        canvas.drawCircle(
          Offset(5 * fieldSize + fieldSize/2, i * fieldSize + fieldSize/2),
          fieldSize * 0.4,
          pathPaint
        );
      }
    }
    
    // Gitterlinien
    final gridPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (int i = 0; i <= 11; i++) {
      canvas.drawLine(
        Offset(i * fieldSize, 0),
        Offset(i * fieldSize, boardSize),
        gridPaint
      );
      canvas.drawLine(
        Offset(0, i * fieldSize),
        Offset(boardSize, i * fieldSize),
        gridPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
