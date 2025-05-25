import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/home_screen.dart';
import 'providers/game_provider.dart';
import 'models/game_state.dart';
import 'logic/ludo_game_logic.dart';

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
          players: [
            Player(PlayerColor.red, 'Red', isAI: false), // Human player
            Player(PlayerColor.green, 'Green', isAI: true),
            Player(PlayerColor.blue, 'Blue', isAI: true),
            Player(PlayerColor.yellow, 'Yellow', isAI: true),
          ],
          currentTurnPlayerId: PlayerColor.red,
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
