class Player {
  final String id;
  final String name;
<<<<<<< HEAD
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
=======
  List<int> tokenPositions; // Jede Figur hat ihre eigene Position
  final bool isAI;

  // -1: in der Basis
  // 0-39: auf dem Hauptspielfeld
  // 40-43: auf dem Heimweg (Zielgerade)
  // 99: im Ziel (finished)
  Player(this.id, this.name, {List<int>? initialPositions, this.isAI = false})
      : tokenPositions = initialPositions ?? List.filled(GameState.tokensPerPlayer, GameState.basePosition);
>>>>>>> ea7bbac21da49f2d140669fcb86aadd27e68f98e
}

class GameState {
  final Map<String, int> startIndex; // Startfeld auf dem Hauptbrett (nach dem Rauskommen)
  List<Player> players;
  String currentTurnPlayerId;
  int? lastDiceValue;
  int currentRollCount;
  String? winnerId; // ID des Spielers, der gewonnen hat (null wenn Spiel läuft)

<<<<<<< HEAD
  static const int totalFields = 52; // 52 Felder auf der äußeren Spur
=======
  static const int tokensPerPlayer = 4;
  static const int basePosition = -1; // Figur in der Basis
  static const int totalFields = 40;    // Felder auf dem Hauptkreis
  static const int homePathLength = 4;  // Länge der Zielgerade
  static const int finishedPosition = 99; // Figur ist im Ziel
>>>>>>> ea7bbac21da49f2d140669fcb86aadd27e68f98e

  GameState({
    required this.startIndex,
    required this.players,
    required this.currentTurnPlayerId,
    this.lastDiceValue,
    this.currentRollCount = 0,
    this.winnerId,
  });

  /// Prüft, ob das Feld eine Safe Zone für den Spieler ist.
<<<<<<< HEAD
  bool isSafeField(int index, String playerId) {
    // Sterne sind sichere Felder (Startfelder und Mittelpunkte jedes Quadranten)
    return [0, 13, 26, 39, // Startfelder
            8, 21, 34, 47   // Mittelpunktfelder
           ].contains(index);
=======
  // Diese Methode muss überarbeitet werden, da Safe Zones relativ zum Startpunkt sind
  // und es auch Startfelder gibt, die sicher sind.
  bool isSafeField(int boardIndex, String playerId) {
    final playerStart = startIndex[playerId]!;
    // Das eigentliche Startfeld des Spielers (nach dem Rauskommen) ist sicher.
    if (boardIndex == playerStart) return true;
    
    // Die allgemeinen sicheren Felder, die oft farbig markiert sind (jedes 8. Feld vom Start des Spielers)
    // Diese Logik ist vereinfacht und muss ggf. an das genaue Ludo-Brett angepasst werden.
    // Typischerweise gibt es 8 sichere Felder auf dem Brett.
    // Beispiel: Wenn Start bei 0, dann 0, 8, 13 (Start anderer Spieler), 21, 26 (Start anderer Spieler), 34, 39 (Start anderer Spieler)
    // Dies ist eine sehr spezifische Regel, die vom Brett abhängt. Fürs Erste nehmen wir nur das Startfeld.
    // Weitere sichere Felder könnten hier hinzugefügt werden.
    return false; 
>>>>>>> ea7bbac21da49f2d140669fcb86aadd27e68f98e
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
<<<<<<< HEAD
      players: players.map((p) => Player(
        p.id, 
        p.name, 
        position: p.position,
        homePositions: List<int>.from(p.homePositions),
        isAI: p.isAI
      )).toList(),
=======
      players: players.map((p) => Player(p.id, p.name, initialPositions: List.from(p.tokenPositions), isAI: p.isAI)).toList(),
>>>>>>> ea7bbac21da49f2d140669fcb86aadd27e68f98e
      currentTurnPlayerId: currentTurnPlayerId,
      lastDiceValue: lastDiceValue,
      currentRollCount: currentRollCount,
      winnerId: winnerId,
    );
  }
}
