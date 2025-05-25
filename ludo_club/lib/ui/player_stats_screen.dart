import 'package:flutter/material.dart';
import 'package:ludo_club/services/statistics_service.dart'; // Assuming this path is correct

class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({Key? key}) : super(key: key);

  @override
  _PlayerStatsScreenState createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  late Future<List<PlayerStats>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      _statsFuture = _statisticsService.getAllPlayerStats();
    });
  }

  Future<void> _resetStats() async {
    bool confirmReset = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Statistics'),
          content: const Text('Are you sure you want to reset all player statistics? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // User cancelled
              },
            ),
            TextButton(
              child: const Text('Reset', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true); // User confirmed
              },
            ),
          ],
        );
      },
    ) ?? false; // If dialog is dismissed, consider it as false

    if (confirmReset) {
      await _statisticsService.resetAllStatistics();
      _loadStats(); // Refresh the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Statistics'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Statistics',
            onPressed: _loadStats,
          ),
        ],
      ),
      body: FutureBuilder<List<PlayerStats>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final List<PlayerStats> statsList = snapshot.data!;
            if (statsList.isEmpty) {
              return const Center(child: Text('Noch keine Statistiken vorhanden.'));
            }
            return ListView.builder(
              itemCount: statsList.length,
              itemBuilder: (context, index) {
                final stats = statsList[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats.playerName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 8),
                        Text('Games Played: ${stats.gamesPlayed}'),
                        Text('Games Won: ${stats.gamesWon}'),
                        Text('Win Rate: ${(stats.winRate * 100).toStringAsFixed(1)}%'),
                        Text('Pawns Captured: ${stats.pawnsCaptured}'),
                        Text('Pawns Lost: ${stats.pawnsLost}'),
                        Text('Sixes Rolled: ${stats.sixesRolled}'),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            // Should not happen if future is always set, but as a fallback
            return const Center(child: Text('No statistics found.'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _resetStats,
        icon: const Icon(Icons.delete_sweep),
        label: const Text('Reset All Stats'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
