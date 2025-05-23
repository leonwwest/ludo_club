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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tokenPositions': tokenPositions,
      'isAI': isAI,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      json['id'] as String,
      json['name'] as String,
      initialPositions: List<int>.from(json['tokenPositions'] as List),
      isAI: json['isAI'] as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isAI == other.isAI &&
          _listEquals(tokenPositions, other.tokenPositions);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      isAI.hashCode ^
      tokenPositions.fold(0, (prev, item) => prev ^ item.hashCode);

  // Helper for list equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class GameState {
  final Map<String, int> startIndex; // Startfeld auf dem Hauptbrett (nach dem Rauskommen)
  List<Player> players;
  String currentTurnPlayerId;
  int? lastDiceValue;
  int currentRollCount;
  String? winnerId; // ID des Spielers, der gewonnen hat (null wenn Spiel läuft)
  String? gameId; // Unique ID for the game instance, useful for save slots

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
    this.gameId,
  });

  Map<String, dynamic> toJson() {
    return {
      'startIndex': startIndex,
      'players': players.map((p) => p.toJson()).toList(),
      'currentTurnPlayerId': currentTurnPlayerId,
      'lastDiceValue': lastDiceValue,
      'currentRollCount': currentRollCount,
      'winnerId': winnerId,
      'gameId': gameId,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      startIndex: Map<String, int>.from(json['startIndex'] as Map),
      players: (json['players'] as List<dynamic>)
          .map((playerJson) => Player.fromJson(playerJson as Map<String, dynamic>))
          .toList(),
      currentTurnPlayerId: json['currentTurnPlayerId'] as String,
      lastDiceValue: json['lastDiceValue'] as int?,
      currentRollCount: json['currentRollCount'] as int,
      winnerId: json['winnerId'] as String?,
      gameId: json['gameId'] as String?,
    );
  }

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
      gameId: gameId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          runtimeType == other.runtimeType &&
          mapEquals(startIndex, other.startIndex) &&
          listEquals(players, other.players) &&
          currentTurnPlayerId == other.currentTurnPlayerId &&
          lastDiceValue == other.lastDiceValue &&
          currentRollCount == other.currentRollCount &&
          winnerId == other.winnerId &&
          gameId == other.gameId;
          // Note: hashCode needs to be consistent with this.

  @override
  int get hashCode =>
      mapHashCode(startIndex) ^
      players.fold(0, (prev, player) => prev ^ player.hashCode) ^
      currentTurnPlayerId.hashCode ^
      lastDiceValue.hashCode ^
      currentRollCount.hashCode ^
      winnerId.hashCode ^
      gameId.hashCode;

  // Helper for map equality
  bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || a[k] != b[k]) return false;
    }
    return true;
  }
   // Helper for list equality (already present in Player, but good for standalone GameState too)
  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
   // Helper for map hash code
  int mapHashCode<K,V>(Map<K,V> map) {
    int hash = 0;
    map.forEach((key, value) {
      hash = hash ^ key.hashCode ^ value.hashCode;
    });
    return hash;
  }
}
