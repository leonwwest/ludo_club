class Player {
  final String id;
  final String name;
  int position;
  final bool isAI;
  
  Player(this.id, this.name, {this.position = 0, this.isAI = false});
}

class GameState {
  final Map<String, int> startIndex;
  List<Player> players;
  String currentTurnPlayerId;
  int? lastDiceValue;
  int currentRollCount;

  static const int totalFields = 40;

  GameState({
    required this.startIndex,
    required this.players,
    required this.currentTurnPlayerId,
    this.lastDiceValue,
    this.currentRollCount = 0,
  });

  /// Prüft, ob das Feld eine Safe Zone für den Spieler ist.
  bool isSafeField(int index, String playerId) {
    final start = startIndex[playerId]!;
    final safePos = (start + 4) % totalFields;
    return index == safePos;
  }
  
  /// Gibt den aktuellen Spieler zurück
  Player get currentPlayer => players.firstWhere((p) => p.id == currentTurnPlayerId);
  
  /// Prüft, ob der aktuelle Spieler eine KI ist
  bool get isCurrentPlayerAI => currentPlayer.isAI;
  
  /// Erstellt eine Kopie des aktuellen GameState
  GameState copy() {
    return GameState(
      startIndex: Map.from(startIndex),
      players: players.map((p) => Player(p.id, p.name, position: p.position, isAI: p.isAI)).toList(),
      currentTurnPlayerId: currentTurnPlayerId,
      lastDiceValue: lastDiceValue,
      currentRollCount: currentRollCount,
    );
  }
}
