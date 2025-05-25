import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart';
import 'package:ludo_club/screens/game_screen.dart';
import 'package:ludo_club/services/audio_service.dart';
import 'package:ludo_club/services/game_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

// Generate mocks for GameService and AudioService
@GenerateMocks([GameService, AudioService])
import 'game_screen_test.mocks.dart'; // Import generated mocks

void main() {
  late MockGameService mockGameService;
  late MockAudioService mockAudioService;

  setUp(() {
    mockGameService = MockGameService();
    mockAudioService = MockAudioService();

    // Default stub for GameService state
    when(mockGameService.state).thenReturn(
      GameState(
        players: [], // Provide a default or setup-specific player list
        currentPlayerIndex: 0,
        diceRoll: 0,
        isGameOver: false,
        winner: '',
        rolledSix: false,
      ),
    );
    // Default stubs for AudioService methods (to avoid null errors if called)
    when(mockAudioService.playDiceSound()).thenAnswer((_) async => {});
    when(mockAudioService.playMoveSound()).thenAnswer((_) async => {});
    when(mockAudioService.playCaptureSound()).thenAnswer((_) async => {});
    when(mockAudioService.playFinishSound()).thenAnswer((_) async => {});
    when(mockAudioService.playVictorySound()).thenAnswer((_) async => {});
  });

  // Helper function to pump GameScreen with necessary providers
  Future<void> pumpGameScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameService>.value(value: mockGameService),
          Provider<AudioService>.value(value: mockAudioService),
        ],
        child: const MaterialApp(home: GameScreen()), // Added const
      ),
    );
  }

  group('GameScreen Tests', () {
    testWidgets('GameScreen renders correctly', (WidgetTester tester) async {
      await pumpGameScreen(tester);
      // Example: Check for a known UI element
      expect(find.byType(GameScreen), findsOneWidget);
      // Add more specific assertions based on your GameScreen UI
    });

    // Example test for an action, like rolling the dice
    testWidgets('tapping dice roll button calls GameService.rollDice', (WidgetTester tester) async {
      await pumpGameScreen(tester);
      // Assume there's a button/widget that triggers rollDice
      // Example: final diceButton = find.byKey(const Key('dice_roll_button'));
      // await tester.tap(diceButton);
      // await tester.pump();

      // verify(mockGameService.rollDice()).called(1);
      // verify(mockAudioService.playDiceSound()).called(1);
    });
    
    // Add more tests for other UI interactions and GameService/AudioService method calls
    // such as moving a piece, piece animations, sound playback on events, etc.
  });
}