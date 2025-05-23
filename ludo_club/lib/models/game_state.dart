class Player {
  final String id;
  final String name;
  List<int> tokenPositions; // Jede Figur hat ihre eigene Position
  final bool isAI;

  // -1: in der Basis
  // 0-39: auf dem Hauptspielfeld
  // 40-43: auf dem Heimweg (Zielgerade)
  // 99: im Ziel (finished)
  Player(this.id, this.name, {List<int>? initialPositions, this.isAI = false})
      : tokenPositions = initialPositions ?? List.filled(GameState.tokensPerPlayer, GameState.basePosition);
}

class GameState {
  final Map<String, int> startIndex; // Startfeld auf dem Hauptbrett (nach dem Rauskommen)
  List<Player> players;
  String currentTurnPlayerId;
  int? lastDiceValue;
  int currentRollCount;
  String? winnerId; // ID des Spielers, der gewonnen hat (null wenn Spiel läuft)

  static const int tokensPerPlayer = 4;
  static const int basePosition = -1; // Figur in der Basis
  static const int totalFields = 40;    // Felder auf dem Hauptkreis
  static const int homePathLength = 4;  // Länge der Zielgerade
  static const int finishedPosition = 99; // Figur ist im Ziel

  GameState({
    required this.startIndex,
    required this.players,
    required this.currentTurnPlayerId,
    this.lastDiceValue,
    this.currentRollCount = 0,
    this.winnerId,
  });

  /// Prüft, ob das Feld eine Safe Zone für den Spieler ist.
  bool isSafeField(int boardIndex, String playerId) {
    // A player's own starting square is safe.
    final playerStart = startIndex[playerId]!;
    if (boardIndex == playerStart) return true;

    // Standard shared safe spots.
    // These include all player start fields and fields 8 positions clockwise from each start.
    // Assuming start indices are 0, 10, 20, 30 for a 40-field board.
    const sharedSafeSpots = [
      0, 10, 20, 30, // Start fields
      8, 18, 28, 38  // 8 spaces clockwise from each start field
    ];

    if (sharedSafeSpots.contains(boardIndex)) {
      return true;
    }

    return false;
  }
  
  /// Gibt den aktuellen Spieler zurück
  Player get currentPlayer => players.firstWhere((p) => p.id == currentTurnPlayerId);
  
  /// Prüft, ob der aktuelle Spieler eine KI ist
  bool get isCurrentPlayerAI => currentPlayer.isAI;
  
  /// Gibt den Gewinner zurück, falls es einen gibt
  Player? get winner => winnerId != null 
      ? players.firstWhere((p) => p.id == winnerId)
      : null;
  
  /// Prüft, ob das Spiel beendet ist
  bool get isGameOver => winnerId != null;
  
  /// Erstellt eine Kopie des aktuellen GameState
  GameState copy() {
    return GameState(
      startIndex: Map.from(startIndex),
      players: players.map((p) => Player(p.id, p.name, initialPositions: List.from(p.tokenPositions), isAI: p.isAI)).toList(),
      currentTurnPlayerId: currentTurnPlayerId,
      lastDiceValue: lastDiceValue,
      currentRollCount: currentRollCount,
      winnerId: winnerId,
    );
  }
}
