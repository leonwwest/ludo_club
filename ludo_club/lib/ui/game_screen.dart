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
        final fieldSize = boardSize / 15;
        
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
            }),
          ],
        );
      },
    );
  }
  
  // Erzeugt eine Spielfigur im Heimatfeld
  Widget _buildHomePiece(Player player, int pieceIndex, double boardSize, double fieldSize, 
                         GameProvider gameProvider, List<int> possibleMoves, GameState gameState) {
    final playerColor = _getPlayerColor(player.id);
    final positions = _getHomeFieldPositions(player.id, boardSize, fieldSize);
    final pos = positions[pieceIndex];
    final isHighlighted = possibleMoves.contains(gameState.startIndex[player.id]) && 
                          gameProvider.gameState.lastDiceValue == 6;
    
    return Positioned(
      left: pos.dx - fieldSize / 2,
      top: pos.dy - fieldSize / 2,
      child: GestureDetector(
        onTap: isHighlighted ? () => _moveToken(gameProvider, pieceIndex, gameState.startIndex[player.id]!) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: fieldSize,
          height: fieldSize,
          decoration: BoxDecoration(
            color: isHighlighted ? Colors.yellow.withOpacity(0.3) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isHighlighted ? Colors.orange : Colors.transparent,
              width: 2,
            ),
          ),
          child: CustomPaint(
            painter: PiecePainter(color: playerColor),
          ),
        ),
      ),
    );
  }
  
  // Berechnet die Positionen für die 4 Figuren im Heimatfeld eines Spielers
  List<Offset> _getHomeFieldPositions(String playerId, double boardSize, double fieldSize) {
    final positions = <Offset>[];
    final spacing = fieldSize * 2;
    
    switch (playerId) {
      case 'player1': // Gelb (oben links)
        positions.add(Offset(2 * fieldSize, 2 * fieldSize));
        positions.add(Offset(2 * fieldSize + spacing, 2 * fieldSize));
        positions.add(Offset(2 * fieldSize, 2 * fieldSize + spacing));
        positions.add(Offset(2 * fieldSize + spacing, 2 * fieldSize + spacing));
        break;
      case 'player2': // Blau (oben rechts)
        positions.add(Offset(11 * fieldSize, 2 * fieldSize));
        positions.add(Offset(11 * fieldSize + spacing, 2 * fieldSize));
        positions.add(Offset(11 * fieldSize, 2 * fieldSize + spacing));
        positions.add(Offset(11 * fieldSize + spacing, 2 * fieldSize + spacing));
        break;
      case 'player3': // Grün (unten links)
        positions.add(Offset(2 * fieldSize, 11 * fieldSize));
        positions.add(Offset(2 * fieldSize + spacing, 11 * fieldSize));
        positions.add(Offset(2 * fieldSize, 11 * fieldSize + spacing));
        positions.add(Offset(2 * fieldSize + spacing, 11 * fieldSize + spacing));
        break;
      case 'player4': // Rot (unten rechts)
        positions.add(Offset(11 * fieldSize, 11 * fieldSize));
        positions.add(Offset(11 * fieldSize + spacing, 11 * fieldSize));
        positions.add(Offset(11 * fieldSize, 11 * fieldSize + spacing));
        positions.add(Offset(11 * fieldSize + spacing, 11 * fieldSize + spacing));
        break;
    }
    
    return positions;
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
    if (pathMapping.containsKey(index)) {
      final pos = pathMapping[index]!;
      return Offset(
        pos[0] * cellSize + cellSize/2,
        pos[1] * cellSize + cellSize/2
      );
    }
    
    // Fallback: Zentrum des Spielbretts
    return Offset(boardSize / 2, boardSize / 2);
  }

  // Gibt die Farbe für einen Spieler zurück
  Color _getPlayerColor(String playerId) {
    switch (playerId) {
      case 'player1':
        return Colors.green;
      case 'player2':
        return Colors.yellow;
      case 'player3':
        return Colors.red;
      case 'player4':
        return Colors.blue;
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
