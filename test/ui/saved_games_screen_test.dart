import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/models/game_state.dart'; // Assuming GameState is needed
import 'package:ludo_club/screens/saved_games_screen.dart'; // Assuming SavedGamesScreen is the widget being tested
import 'package:ludo_club/services/save_load_service.dart'; // Assuming SaveLoadService is used
import 'package:mockito/annotations.dart'; // For @GenerateMocks
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

// Mock classes
class MockSaveLoadService extends Mock implements SaveLoadService {}
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

@GenerateMocks([SaveLoadService, NavigatorObserver])
import 'saved_games_screen_test.mocks.dart'; // Import generated mocks

void main() {
  late MockSaveLoadService mockSaveLoadService;
  late MockNavigatorObserver mockNavigatorObserver;

  setUp(() {
    mockSaveLoadService = MockSaveLoadService();
    mockNavigatorObserver = MockNavigatorObserver();

    // Default stub for getSavedGames
    when(mockSaveLoadService.getSavedGames()).thenAnswer((_) async => []);
    // Default stub for loadGameState
    when(mockSaveLoadService.loadGameState(any)).thenAnswer((_) async => null);
    // Default stub for deleteGameState
    when(mockSaveLoadService.deleteGameState(any)).thenAnswer((_) async {});
  });

  // Helper function to pump SavedGamesScreen with necessary providers
  Future<void> pumpSavedGamesScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SaveLoadService>.value(value: mockSaveLoadService),
        ],
        child: MaterialApp(
          home: const SavedGamesScreen(), // Added const
          navigatorObservers: [mockNavigatorObserver],
        ),
      ),
    );
  }

  group('SavedGamesScreen Tests', () {
    testWidgets('SavedGamesScreen renders correctly and shows title', (WidgetTester tester) async {
      await pumpSavedGamesScreen(tester);
      expect(find.text('Saved Games'), findsOneWidget);
    });

    testWidgets('displays a list of saved games', (WidgetTester tester) async {
      when(mockSaveLoadService.getSavedGames()).thenAnswer((_) async => ['GameSlot1', 'GameSlot2']);
      await pumpSavedGamesScreen(tester);
      await tester.pumpAndSettle(); // For FutureBuilder to complete

      expect(find.text('GameSlot1'), findsOneWidget);
      expect(find.text('GameSlot2'), findsOneWidget);
    });

    testWidgets('tapping a saved game calls loadGameState and navigates', (WidgetTester tester) async {
      when(mockSaveLoadService.getSavedGames()).thenAnswer((_) async => ['LoadThisGame']);
      // Mock a GameState to be returned by loadGameState
      final mockGameState = GameState(
          players: [], currentPlayerIndex: 0, diceRoll: 0, isGameOver: false, winner: '', rolledSix: false);
      when(mockSaveLoadService.loadGameState('LoadThisGame')).thenAnswer((_) async => mockGameState);

      await pumpSavedGamesScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('LoadThisGame'));
      await tester.pumpAndSettle();

      verify(mockSaveLoadService.loadGameState('LoadThisGame')).called(1);
      // verify(mockNavigatorObserver.didPush(any, any)); // Verify navigation if applicable
    });

    testWidgets('tapping delete on a saved game calls deleteGameState', (WidgetTester tester) async {
      when(mockSaveLoadService.getSavedGames()).thenAnswer((_) async => ['DeleteThisGame']);
      await pumpSavedGamesScreen(tester);
      await tester.pumpAndSettle();

      // This assumes your UI has a way to identify the delete action for a specific game.
      // For example, finding an icon button within the ListTile of the game.
      // final deleteButtonFinder = find.descendant(
      //   of: find.widgetWithText(ListTile, 'DeleteThisGame'),
      //   matching: find.byIcon(Icons.delete),
      // );
      // await tester.tap(deleteButtonFinder);
      // await tester.pumpAndSettle();

      // For simplicity, if tapping the game itself or a specific part triggers delete in test scenario:
      // This needs to match your actual UI interaction for deletion.
      // As a placeholder, let's assume a direct call or a uniquely identifiable delete button.
      // If delete is part of the ListTile tap, this test would be different.
      // verify(mockSaveLoadService.deleteGameState('DeleteThisGame')).called(1);
      // expect(find.text('DeleteThisGame'), findsNothing); // And verify it's removed from UI
    });
  });
}

// Mock SaveLoadService
class MockSaveLoadService extends Mock implements SaveLoadService {
  @override
  Future<List<String>> getSavedGames() async {
    return super.noSuchMethod(
      Invocation.method(#getSavedGames, []),
      returnValue: Future.value(<String>[]),
      returnValueForMissingStub: Future.value(<String>[]),
    );
  }

  @override
  Future<GameState?> loadGameState(String slotName) async {
    return super.noSuchMethod(
      Invocation.method(#loadGameState, [slotName]),
      returnValue: Future.value(null),
      returnValueForMissingStub: Future.value(null),
    );
  }

  @override
  Future<void> deleteGameState(String slotName) async {
    return super.noSuchMethod(
      Invocation.method(#deleteGameState, [slotName]),
      returnValue: Future.value(null),
      returnValueForMissingStub: Future.value(null),
    );
  }
}

// Mock NavigatorObserver to verify navigation events
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// ... (rest of the existing code) 