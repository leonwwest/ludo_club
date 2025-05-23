import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/models/player.dart';
import 'package:ludo_club/providers/game_provider.dart';
import 'package:ludo_club/services/audio_service.dart';
import 'package:ludo_club/services/game_service.dart';
import 'package:ludo_club/services/save_load_service.dart';
import 'package:ludo_club/ui/game_screen.dart';
import 'package:ludo_club/ui/home_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

// --- Mocks ---
// Using manual mocks as used in game_provider_test.dart due to environment issues

class MockGameService extends Mock implements GameService {
  @override
  GameState startGame({List<Player>? players, String? firstPlayerId}) {
    return GameState(
      players: players ?? [Player('p1', 'Player 1'), Player('p2', 'Player 2')],
      startIndex: {'p1': 0, 'p2': 13, 'p3': 26, 'p4': 39},
      pieces: Map.fromEntries((players ?? [Player('p1', 'Player 1'), Player('p2', 'Player 2')])
          .map((p) => MapEntry(p.id, [-1, -1, -1, -1]))),
      currentTurnPlayerId: firstPlayerId ?? (players?.first.id ?? 'p1'),
      gameId: 'mockGame123',
    );
  }
}

class MockAudioService extends Mock implements AudioService {
  bool _soundEnabled = true;
  @override
  bool get soundEnabled => _soundEnabled;
  @override
  Future<void> init() async {}
  @override
  void playDiceRoll() {}
  @override
  void playMove() {}
  @override
  void playCapture() {}
  @override
  void playVictory() {}
  @override
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }
  @override
  void setVolume(double volume) {}
}

class MockSaveLoadService extends Mock implements SaveLoadService {
   @override
  Future<void> saveGame(GameState state, String slotName) async {}

  @override
  Future<GameState?> loadGame(String slotName) async {
    return null;
  }

  @override
  Future<List<String>> getSavedGames() async {
    return [];
  }

  @override
  Future<void> deleteGame(String slotName) async {}
}

// A mock GameProvider that allows us to track method calls if needed
class TestGameProvider extends GameProvider {
  bool newGameStarted = false;
  List<Player>? startedPlayers;

  TestGameProvider({
    required GameService gameService,
    required AudioService audioService,
    required SaveLoadService saveLoadService,
    GameState? initialState,
  }) : super.withServices(
          gameService: gameService,
          audioService: audioService,
          saveLoadService: saveLoadService,
          initialState: initialState ?? gameService.startGame(players: [Player('p1', 'P1')]),
        );

  @override
  Future<void> startNewGame({required List<Player> players, String? firstPlayerId}) async {
    newGameStarted = true;
    startedPlayers = players;
    // Call super to actually change the state, or mock it out if only tracking
    await super.startNewGame(players: players, firstPlayerId: firstPlayerId);
    print("MockGameProvider: startNewGame called with ${players.length} players. Navigating...");
  }
}

void main() {
  late TestGameProvider mockGameProvider;
  late MockGameService mockGameService;
  late MockAudioService mockAudioService;
  late MockSaveLoadService mockSaveLoadService;

  setUp(() {
    mockGameService = MockGameService();
    mockAudioService = MockAudioService();
    mockSaveLoadService = MockSaveLoadService();
    
    // Ensure a default state is provided for GameProvider initialization
    final defaultInitialState = mockGameService.startGame(players: [Player('p1', 'P1')]);

    mockGameProvider = TestGameProvider(
      gameService: mockGameService,
      audioService: mockAudioService,
      saveLoadService: mockSaveLoadService,
      initialState: defaultInitialState,
    );
  });

  Widget createHomeScreen() {
    return ChangeNotifierProvider<GameProvider>.value(
      value: mockGameProvider,
      child: MaterialApp(
        home: HomeScreen(),
        routes: {
          '/game': (context) => GameScreen(), // Mock GameScreen or provide a simple placeholder
        },
      ),
    );
  }

  group('HomeScreen UI Tests', () {
    testWidgets('renders HomeScreen with essential elements', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      expect(find.text('Ludo Club'), findsOneWidget); // App Title
      expect(find.byIcon(Icons.settings), findsOneWidget); // Settings icon
      expect(find.text('Start New Game'), findsOneWidget);
      expect(find.text('Load Game'), findsOneWidget); // Assuming this button exists
      expect(find.text('Number of Players:'), findsOneWidget);
      // Default player count is 2
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Player count selection updates UI', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Default is 2 players
      expect(find.descendant(of: find.byType(DropdownButton<int>), matching: find.text('2')), findsOneWidget);

      // Tap the dropdown to open it
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle(); // Wait for animation

      // Select 3 players
      // Dropdown items are usually Text widgets with the value as data.
      await tester.tap(find.text('3').last); // .last to ensure it's the one in the dropdown menu
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(DropdownButton<int>), matching: find.text('3')), findsOneWidget);

      // Select 4 players
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(DropdownButton<int>), matching: find.text('4')), findsOneWidget);
    });

    testWidgets('"Start New Game" button calls provider and navigates', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Ensure the provider's method hasn't been called yet
      expect(mockGameProvider.newGameStarted, isFalse);

      // Tap the "Start New Game" button
      await tester.tap(find.text('Start New Game'));
      await tester.pumpAndSettle(); // Process taps and navigation

      // Verify GameProvider's startNewGame was called
      expect(mockGameProvider.newGameStarted, isTrue);
      expect(mockGameProvider.startedPlayers?.length, 2); // Default player count

      // Verify navigation to GameScreen
      // This implies GameScreen is pushed onto the navigator stack.
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing); // HomeScreen should be replaced or covered
    });

    testWidgets('"Start New Game" button considers selected player count', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Change player count to 4
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();

      // Tap the "Start New Game" button
      await tester.tap(find.text('Start New Game'));
      await tester.pumpAndSettle();

      expect(mockGameProvider.newGameStarted, isTrue);
      expect(mockGameProvider.startedPlayers?.length, 4); // Selected player count
      expect(find.byType(GameScreen), findsOneWidget);
    });

    // Example of testing settings - if settings were a dialog
    testWidgets('Settings icon opens settings (conceptual)', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // This is a placeholder as settings functionality isn't fully defined for test
      // If settings opened a dialog:
      // await tester.tap(find.byIcon(Icons.settings));
      // await tester.pumpAndSettle();
      // expect(find.text('Sound'), findsOneWidget); // Assuming 'Sound' is a setting
    });

    // Test "Load Game" button navigation (if SavedGamesScreen exists and is wired)
    testWidgets('Load Game button navigates to SavedGamesScreen (conceptual)', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<GameProvider>.value(
          value: mockGameProvider,
          child: HomeScreen(),
        ),
        routes: {
          // '/savedGames': (context) => SavedGamesScreen(), // Assuming SavedGamesScreen
          '/savedGames': (context) => Scaffold(appBar: AppBar(title: Text('Saved Games'))), // Placeholder
        },
      ));

      // Verify the button exists
      expect(find.text('Load Game'), findsOneWidget);

      // Tap the "Load Game" button
      // await tester.tap(find.text('Load Game'));
      // await tester.pumpAndSettle(); // Process taps and navigation

      // Verify navigation
      // expect(find.text('Saved Games'), findsOneWidget); // Check for a title or unique widget on SavedGamesScreen
    });


  });
}
