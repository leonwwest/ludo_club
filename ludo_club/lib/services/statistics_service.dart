import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerStats {
  final String playerName; // Display name
  int gamesPlayed;
  int gamesWon;
  int pawnsCaptured; // Pawns captured by this player
  int pawnsLost;     // Pawns of this player captured by others
  int sixesRolled;

  PlayerStats({
    required this.playerName,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.pawnsCaptured = 0,
    this.pawnsLost = 0,
    this.sixesRolled = 0,
  });

  // Factory constructor to create PlayerStats from JSON
  // playerName is passed separately as it's not in the JSON map itself but used as a key.
  factory PlayerStats.fromJson(String playerName, Map<String, dynamic> json) {
    return PlayerStats(
      playerName: playerName, // Use the provided display name
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      gamesWon: json['gamesWon'] as int? ?? 0,
      pawnsCaptured: json['pawnsCaptured'] as int? ?? 0,
      pawnsLost: json['pawnsLost'] as int? ?? 0,
      sixesRolled: json['sixesRolled'] as int? ?? 0,
    );
  }

  // Method to convert PlayerStats to JSON (omitting playerName)
  Map<String, dynamic> toJson() {
    return {
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'pawnsCaptured': pawnsCaptured,
      'pawnsLost': pawnsLost,
      'sixesRolled': sixesRolled,
    };
  }

  double get winRate => (gamesPlayed == 0) ? 0.0 : gamesWon / gamesPlayed;

  @override
  String toString() {
    return 'PlayerStats($playerName: GP:$gamesPlayed, GW:$gamesWon, WinRate:${winRate.toStringAsFixed(2)}, Cap:$pawnsCaptured, Lost:$pawnsLost, Sixes:$sixesRolled)';
  }
}

class StatisticsService {
  static const String _playerStatsListKey = 'statPlayerNames';
  String _playerStatsKey(String playerName) => 'stats_${playerName.toLowerCase().trim()}';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  // Gets stats for a given player.
  // Player names are handled case-insensitively for retrieval.
  Future<PlayerStats> getPlayerStats(String playerName) async {
    final prefs = await _prefs;
    final normalizedName = playerName.toLowerCase().trim();
    final String key = _playerStatsKey(playerName); // uses normalized name for key
    
    final String? statsJson = prefs.getString(key);
    
    if (statsJson != null && statsJson.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(statsJson) as Map<String, dynamic>;
        // When loading, use the original playerName for display, not the normalized one.
        // However, we need to retrieve the *original* display name that was saved.
        // This implies that when we save, we should perhaps store the display name along with the stats,
        // or use the list from _playerStatsListKey to find the canonical display name.
        // For now, let's assume the passed 'playerName' is the desired display name if creating new.
        // If loading, we should try to get the canonical display name.
        
        // Correct approach: The list _playerStatsListKey stores the canonical display names.
        // When getPlayerStats("alice") is called, we should find "Alice" from the list if "alice" matches.
        final displayPlayerName = await _getDisplayPlayerName(playerName) ?? playerName;

        return PlayerStats.fromJson(displayPlayerName, jsonMap);
      } catch (e) {
        // Handle potential parsing errors, corruption etc.
        print("Error decoding stats for $playerName: $e. Returning fresh stats.");
        // Fall through to return new stats, but use the potentially canonical name
        final displayPlayerName = await _getDisplayPlayerName(playerName) ?? playerName;
        return PlayerStats(playerName: displayPlayerName);
      }
    } else {
      // If no stats exist, return new stats, ensuring the passed playerName is used for display.
      // No need to call _getDisplayPlayerName if we are creating new, use the name as provided.
      return PlayerStats(playerName: playerName.trim());
    }
  }

  // Helper to find the canonical (original case) player name
  Future<String?> _getDisplayPlayerName(String queryPlayerName) async {
    final prefs = await _prefs;
    final List<String> playerNames = prefs.getStringList(_playerStatsListKey) ?? [];
    final queryNormalized = queryPlayerName.toLowerCase().trim();
    for (String nameInList in playerNames) {
      if (nameInList.toLowerCase().trim() == queryNormalized) {
        return nameInList;
      }
    }
    return null;
  }

  // Saves PlayerStats. playerName is the display name.
  Future<void> _savePlayerStats(String playerName, PlayerStats stats) async {
    final prefs = await _prefs;
    final displayPlayerName = playerName.trim(); // Use the provided name for display list
    final String key = _playerStatsKey(displayPlayerName); // Key uses normalized name

    await prefs.setString(key, jsonEncode(stats.toJson()));

    // Update the list of player names (stores display names)
    final List<String> playerNames = prefs.getStringList(_playerStatsListKey) ?? [];
    final normalizedCurrentName = displayPlayerName.toLowerCase().trim();
    
    // Check if a name that normalizes to the same thing already exists
    bool foundMatch = false;
    for (int i = 0; i < playerNames.length; i++) {
        if (playerNames[i].toLowerCase().trim() == normalizedCurrentName) {
            // If we want to update the stored display name to the latest casing:
            // playerNames[i] = displayPlayerName; 
            foundMatch = true;
            break;
        }
    }
    if (!foundMatch) {
        playerNames.add(displayPlayerName);
    }
    await prefs.setStringList(_playerStatsListKey, playerNames);
  }

  Future<List<PlayerStats>> getAllPlayerStats() async {
    final prefs = await _prefs;
    final List<String> displayPlayerNames = prefs.getStringList(_playerStatsListKey) ?? [];
    final List<PlayerStats> allStats = [];

    for (String displayName in displayPlayerNames) {
      // getPlayerStats will use the displayName, then normalize for key lookup,
      // and then use the stored display name (which should be this displayName) for PlayerStats.playerName
      allStats.add(await getPlayerStats(displayName));
    }
    return allStats;
  }

  // --- Incrementer Methods ---
  Future<void> _updateStat(String playerName, Function(PlayerStats stats) updater) async {
    PlayerStats stats = await getPlayerStats(playerName);
    updater(stats);
    // When saving, use stats.playerName because getPlayerStats should have returned the canonical display name
    await _savePlayerStats(stats.playerName, stats);
  }

  Future<void> incrementGamesPlayed(String playerName, {int count = 1}) async {
    await _updateStat(playerName, (stats) => stats.gamesPlayed += count);
  }

  Future<void> incrementGamesWon(String playerName, {int count = 1}) async {
    await _updateStat(playerName, (stats) => stats.gamesWon += count);
  }

  Future<void> incrementPawnsCaptured(String playerName, {int count = 1}) async {
    await _updateStat(playerName, (stats) => stats.pawnsCaptured += count);
  }

  Future<void> incrementPawnsLost(String playerName, {int count = 1}) async {
    await _updateStat(playerName, (stats) => stats.pawnsLost += count);
  }

  Future<void> incrementSixesRolled(String playerName, {int count = 1}) async {
    await _updateStat(playerName, (stats) => stats.sixesRolled += count);
  }
  
  Future<void> recordGamePlayed(List<String> playerNames) async {
    for (String name in playerNames) {
      await incrementGamesPlayed(name);
    }
  }

  Future<void> resetAllStats() async {
    final prefs = await _prefs;
    final List<String> playerDisplayNames = prefs.getStringList(_playerStatsListKey) ?? [];

    for (String displayName in playerDisplayNames) {
      await prefs.remove(_playerStatsKey(displayName)); // Key uses normalized name
    }
    await prefs.remove(_playerStatsListKey);
  }
}
