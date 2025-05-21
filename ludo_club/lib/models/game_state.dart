class Player {
  final String id;
  final String name;
  int position;
  List<int> homePositions; // Positionen der Figuren im Heimatfeld (-1 für alle im Haus)
  final bool isAI;
  
  Player(this.id, this.name, {this.position = -1, this.homePositions = const [-1, -1, -1, -1], this.isAI = false});
  
  // Prüft, ob alle Figuren im Ziel sind
  bool get hasWon => homePositions.every((pos) => pos >= 100); // >= 100 bedeutet im Ziel
  
  // Bewegt eine Figur aus dem Heimatfeld
  bool moveFromHome() {
    // Wenn alle Figuren schon draußen sind, kann keine mehr bewegt werden
    if (!homePositions.contains(-1)) return false;
    
    // Finde die erste Figur im Heimatfeld und bewege sie raus
    final index = homePositions.indexOf(-1);
    if (index != -1) {
      homePositions[index] = -2; // -2 bedeutet, die Figur ist auf dem Spielfeld
      return true;
    }
    return false;
  }
}

class GameState {
  final Map<String, int> startIndex;
  List<Player> players;
  String currentTurnPlayerId;
  int? lastDiceValue;
  int currentRollCount;

  static const int totalFields = 52; // 52 Felder auf der äußeren Spur

  GameState({
    required this.startIndex,
    required this.players,
    required this.currentTurnPlayerId,
    this.lastDiceValue,
    this.currentRollCount = 0,
  });

  /// Prüft, ob das Feld eine Safe Zone für den Spieler ist.
  bool isSafeField(int index, String playerId) {
    // Sterne sind sichere Felder (Startfelder und Mittelpunkte jedes Quadranten)
    return [0, 13, 26, 39, // Startfelder
            8, 21, 34, 47   // Mittelpunktfelder
           ].contains(index);
  }
  
  /// Gibt den aktuellen Spieler zurück
  Player get currentPlayer => players.firstWhere((p) => p.id == currentTurnPlayerId);
  
  /// Prüft, ob der aktuelle Spieler eine KI ist
  bool get isCurrentPlayerAI => currentPlayer.isAI;
  
  /// Erstellt eine Kopie des aktuellen GameState
  GameState copy() {
    return GameState(
      startIndex: Map.from(startIndex),
      players: players.map((p) => Player(
        p.id, 
        p.name, 
        position: p.position,
        homePositions: List<int>.from(p.homePositions),
        isAI: p.isAI
      )).toList(),
      currentTurnPlayerId: currentTurnPlayerId,
      lastDiceValue: lastDiceValue,
      currentRollCount: currentRollCount,
    );
  }
}
