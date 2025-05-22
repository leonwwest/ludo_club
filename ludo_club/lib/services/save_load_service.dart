import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/game_state.dart';

class SaveLoadService {
  static const String _savedGamesKey = 'saved_games';
  
  /// Speichert ein Spiel mit einem automatisch generierten Namen (Datum und Uhrzeit)
  Future<bool> saveGame(GameState gameState, {String? customName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Erstelle einen Namen für den Spielstand basierend auf Datum und Uhrzeit
      final now = DateTime.now();
      final formatter = DateFormat('dd.MM.yyyy HH:mm');
      final saveName = customName ?? 'Spielstand vom ${formatter.format(now)}';
      
      // Konvertiere den GameState in ein JSON-Objekt
      final gameJson = _gameStateToJson(gameState);
      gameJson['saveName'] = saveName;
      gameJson['saveDate'] = now.millisecondsSinceEpoch;
      
      // Hole die bestehende Liste der gespeicherten Spiele
      final List<String> savedGames = prefs.getStringList(_savedGamesKey) ?? [];
      
      // Füge den neuen Spielstand hinzu
      savedGames.add(jsonEncode(gameJson));
      
      // Speichere die aktualisierte Liste
      return await prefs.setStringList(_savedGamesKey, savedGames);
    } catch (e) {
      print('Fehler beim Speichern des Spiels: $e');
      return false;
    }
  }
  
  /// Lädt ein gespeichertes Spiel nach Index
  Future<GameState?> loadGame(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedGames = prefs.getStringList(_savedGamesKey) ?? [];
      
      if (index < 0 || index >= savedGames.length) {
        return null;
      }
      
      final gameJson = jsonDecode(savedGames[index]) as Map<String, dynamic>;
      return _jsonToGameState(gameJson);
    } catch (e) {
      print('Fehler beim Laden des Spiels: $e');
      return null;
    }
  }
  
  /// Löscht ein gespeichertes Spiel
  Future<bool> deleteGame(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedGames = prefs.getStringList(_savedGamesKey) ?? [];
      
      if (index < 0 || index >= savedGames.length) {
        return false;
      }
      
      savedGames.removeAt(index);
      return await prefs.setStringList(_savedGamesKey, savedGames);
    } catch (e) {
      print('Fehler beim Löschen des Spiels: $e');
      return false;
    }
  }
  
  /// Gibt eine Liste aller gespeicherten Spielstände zurück
  Future<List<Map<String, dynamic>>> getSavedGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedGames = prefs.getStringList(_savedGamesKey) ?? [];
      
      return savedGames.map((gameString) {
        final gameJson = jsonDecode(gameString) as Map<String, dynamic>;
        return {
          'saveName': gameJson['saveName'] as String,
          'saveDate': DateTime.fromMillisecondsSinceEpoch(gameJson['saveDate'] as int),
        };
      }).toList();
    } catch (e) {
      print('Fehler beim Abrufen der gespeicherten Spiele: $e');
      return [];
    }
  }
  
  /// Konvertiert einen GameState in ein JSON-Objekt
  Map<String, dynamic> _gameStateToJson(GameState gameState) {
    return {
      'startIndex': gameState.startIndex,
      'players': gameState.players.map((player) => {
        'id': player.id,
        'name': player.name,
        'tokenPositions': player.tokenPositions,
        'isAI': player.isAI,
      }).toList(),
      'currentTurnPlayerId': gameState.currentTurnPlayerId,
      'lastDiceValue': gameState.lastDiceValue,
      'currentRollCount': gameState.currentRollCount,
      'winnerId': gameState.winnerId,
    };
  }
  
  /// Konvertiert ein JSON-Objekt in einen GameState
  GameState _jsonToGameState(Map<String, dynamic> json) {
    // Konvertiere die startIndex-Map
    final startIndex = Map<String, int>.from(json['startIndex'] as Map);
    
    // Konvertiere die Player-Liste
    final playersList = (json['players'] as List).map((playerJson) {
      return Player(
        playerJson['id'] as String,
        playerJson['name'] as String,
        initialPositions: List<int>.from(playerJson['tokenPositions'] as List),
        isAI: playerJson['isAI'] as bool,
      );
    }).toList();
    
    // Erstelle den GameState
    return GameState(
      startIndex: startIndex,
      players: playersList,
      currentTurnPlayerId: json['currentTurnPlayerId'] as String,
      lastDiceValue: json['lastDiceValue'] != null ? json['lastDiceValue'] as int : null,
      currentRollCount: json['currentRollCount'] as int,
      winnerId: json['winnerId'] != null ? json['winnerId'] as String : null,
    );
  }
} 