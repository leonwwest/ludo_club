import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game_state.dart';
import 'game_screen.dart';
import 'saved_games_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Player> _players = [];
  final List<bool> _isAI = [false, true, true, true];
  final List<TextEditingController> _nameControllers = List.generate(
    4, 
    (index) => TextEditingController(text: 'Spieler ${index + 1}')
  );
  int _playerCount = 2;

  @override
  void dispose() {
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Club'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade500, Colors.blue.shade900],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spieleinstellungen',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Anzahl der Spieler:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Slider(
                        value: _playerCount.toDouble(),
                        min: 2,
                        max: 4,
                        divisions: 2,
                        label: _playerCount.toString(),
                        onChanged: (value) {
                          setState(() {
                            _playerCount = value.toInt();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Spieler:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_playerCount, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Spieler ${index + 1}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (index > 0) // Erster Spieler ist immer menschlich
                                Row(
                                  children: [
                                    const Text('KI:'),
                                    Switch(
                                      value: _isAI[index],
                                      onChanged: (value) {
                                        setState(() {
                                          _isAI[index] = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Neues Spiel',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openSavedGames,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Gespeicherte Spiele',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame() {
    // Spielerliste erstellen
    _players.clear();
    for (int i = 0; i < _playerCount; i++) {
      _players.add(Player(
        'player${i + 1}',
        _nameControllers[i].text.isNotEmpty ? _nameControllers[i].text : 'Spieler ${i + 1}',
        isAI: i > 0 && _isAI[i], // Erster Spieler ist immer menschlich
      ));
    }

    // Spiel starten
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.startNewGame(_players);

    // Zum Spielbildschirm navigieren
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GameScreen(),
      ),
    );
  }

  void _openSavedGames() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SavedGamesScreen(),
      ),
    );
  }
}
