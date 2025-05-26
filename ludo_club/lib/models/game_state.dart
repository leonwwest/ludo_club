import '../logic/ludo_game_logic.dart';

class Player {
  final PlayerColor id;
  final String name;
  final bool isAI;

  // -1: in der Basis
  // 0-39: auf dem Hauptspielfeld
  // 40-43: auf dem Heimweg (Zielgerade)
  // 99: im Ziel (finished)
  Player(this.id, this.name, {this.isAI = false});

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'isAI': isAI,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      PlayerColor.values.firstWhere((e) => e.toString() == json['id'] as String, orElse: () => PlayerColor.red),
      json['name'] as String,
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
          isAI == other.isAI;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      isAI.hashCode;

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
  List<Player> players;
  PlayerColor currentTurnPlayerId;
  int? lastDiceValue;
  int currentRollCount;
  PlayerColor? winnerId; // ID des Spielers, der gewonnen hat (null wenn Spiel läuft)
  String? gameId; // Unique ID for the game instance, useful for save slots

  GameState({
    required this.players,
    required this.currentTurnPlayerId,
    this.lastDiceValue,
    this.currentRollCount = 0,
    this.winnerId,
    this.gameId,
  });

  Map<String, dynamic> toJson() {
    return {
      'players': players.map((p) => p.toJson()).toList(),
      'currentTurnPlayerId': currentTurnPlayerId.toString(),
      'lastDiceValue': lastDiceValue,
      'currentRollCount': currentRollCount,
      'winnerId': winnerId?.toString(),
      'gameId': gameId,
    };
  }

  PlayerColor _parsePlayerColor(String? colorString) {
    if (colorString == null) return PlayerColor.red; // Fallback oder Fehlerbehandlung
    return PlayerColor.values.firstWhere((e) => e.toString() == colorString, orElse: () => PlayerColor.red); // Default fallback
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      players: (json['players'] as List<dynamic>)
          .map((playerJson) => Player.fromJson(playerJson as Map<String, dynamic>))
          .toList(),
      currentTurnPlayerId: PlayerColor.values.firstWhere((e) => e.toString() == json['currentTurnPlayerId'] as String, orElse: () => PlayerColor.red),
      lastDiceValue: json['lastDiceValue'] as int?,
      currentRollCount: json['currentRollCount'] as int,
      winnerId: json['winnerId'] == null ? null : PlayerColor.values.firstWhere((e) => e.toString() == json['winnerId'] as String, orElse: () => PlayerColor.red),
      gameId: json['gameId'] as String?,
    );
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
      players: players.map((p) => Player(p.id, p.name, isAI: p.isAI)).toList(),
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
          listEquals(players, other.players) &&
          currentTurnPlayerId == other.currentTurnPlayerId &&
          lastDiceValue == other.lastDiceValue &&
          currentRollCount == other.currentRollCount &&
          winnerId == other.winnerId &&
          gameId == other.gameId;
          // Note: hashCode needs to be consistent with this.

  @override
  int get hashCode =>
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
