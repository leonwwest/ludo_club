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
            'player1': 0,   // Gelb (oben)
            'player2': 10,  // Blau (rechts) 
            'player3': 20,  // Grün (unten)
            'player4': 30,  // Rot (links)
          },
          players: [
            Player('player1', 'Gelb'),
            Player('player2', 'Blau', isAI: true),
            Player('player3', 'Grün', isAI: true),
            Player('player4', 'Rot', isAI: true),
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
