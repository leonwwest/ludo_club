import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/home_screen.dart';
import 'providers/game_provider.dart';
import 'models/game_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameProvider(
        GameState(
          startIndex: {
            'player1': 0,
            'player2': 13,
            'player3': 26,
            'player4': 39,
          },
          players: [
            Player('player1', 'Spieler 1'),
            Player('player2', 'Spieler 2', isAI: true),
          ],
          currentTurnPlayerId: 'player1',
        ),
      ),
      child: MaterialApp(
        title: 'Ludo Club',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
