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
