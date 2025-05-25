import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ludo_club/services/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Manual Mocks ---

class MockAudioPlayer extends Fake implements AudioPlayer {
  String? _assetPath;
  bool _playCalled = false;
  bool _disposeCalled = false;
  double _volume = 1.0;
  bool _playing = false; // Simple state to simulate play/pause

  Future<Duration?> setAsset(
    String assetPath, {
    bool preload = true, 
    Duration? initialPosition, 
    int? initialIndex, 
    String? package,
    dynamic tag,
  }) async {
    _assetPath = assetPath;
    // Simulate loading duration
    return Duration(seconds: 1);
  }

  String? get assetPath => _assetPath;

  Future<void> play() async {
    _playCalled = true;
    _playing = true;
  }

  bool get playCalled => _playCalled;

  Future<void> pause() async {
    _playing = false;
  }

  bool get isPlaying => _playing;


  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  double get volume => _volume;

  Future<void> dispose() async {
    _disposeCalled = true;
  }

  bool get disposeCalled => _disposeCalled;

  // Reset mock state for reuse
  void resetMock() {
    _assetPath = null;
    _playCalled = false;
    _disposeCalled = false;
    _playing = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); 

  group('AudioService', () {
    late AudioService audioService;
    // Cannot directly mock internal players without changing AudioService for DI
    // late MockAudioPlayer mockDicePlayer;
    // late MockAudioPlayer mockMovePlayer;
    // late MockAudioPlayer mockCapturePlayer;
    // late MockAudioPlayer mockVictoryPlayer;
    // late MockAudioPlayer mockFinishPlayer; // Was missing from original mocks

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        // AudioService manages its own keys. These won't work.
        // 'audio_sound_enabled': true, 
        // 'audio_volume': 0.5,
      });

      audioService = AudioService();
      // Cannot assign to private fields like _dicePlayer, etc.
      // audioService._dicePlayer = mockDicePlayer; 
      await audioService.init();
    });

    tearDown(() async {
      await audioService.dispose();
    });

    group('Initialization (init)', () {
      test('initializes with default sound enabled and volume', () async {
        SharedPreferences.setMockInitialValues({}); // Ensure no conflicting prefs
        final newAudioService = AudioService(); // Create a fresh instance
        await newAudioService.init(); 
        // Default values are internal to AudioService if not found in SharedPreferences
        expect(newAudioService.isSoundEnabled, isTrue); // Default is true in AudioService
        expect(newAudioService.volume, 1.0);      // Default is 1.0 in AudioService
        await newAudioService.dispose();
      });

      test('init loads preferences if they exist - testing via setters', () async {
        // Because AudioService is a singleton and uses its own keys,
        // directly testing preference loading from init is tricky.
        // Instead, we test that setters work, and assume init uses similar logic for its keys.
        audioService.setSoundEnabled(false);
        audioService.setVolume(0.25);
        // Simulate re-init or new app session by creating new instance that would load from prefs
        // This requires that SharedPreferences mock values are set to what AudioService would save.
        // AudioService uses keys: "soundEnabled", "volume"
        SharedPreferences.setMockInitialValues({
            "soundEnabled": false,
            "volume": 0.25
        });
        
        final newAudioServiceInstance = AudioService(); // Get the singleton instance again
        await newAudioServiceInstance.init(); // This should load the mocked prefs

        expect(newAudioServiceInstance.isSoundEnabled, isFalse); // Changed to isSoundEnabled
        expect(newAudioServiceInstance.volume, 0.25);
      });
    });

    group('Sound Playback Methods', () {
      // Since we cannot inject mock players, we cannot directly verify playCalled or assetPath.
      // We can only test if the methods run without error and respect soundEnabled.

      test('play... methods run without error when sound is enabled', () async {
        audioService.setSoundEnabled(true);
        // These are Future<void>, so just awaiting them is a basic check they don't throw.
        await expectLater(audioService.playDiceSound(), completes);
        await expectLater(audioService.playMoveSound(), completes);
        await expectLater(audioService.playCaptureSound(), completes);
        await expectLater(audioService.playFinishSound(), completes);
        await expectLater(audioService.playVictorySound(), completes);
      });

      test('play... methods do not throw error when sound is disabled', () async {
        audioService.setSoundEnabled(false);
        await expectLater(audioService.playDiceSound(), completes);
        await expectLater(audioService.playMoveSound(), completes);
        await expectLater(audioService.playCaptureSound(), completes);
        await expectLater(audioService.playFinishSound(), completes);
        await expectLater(audioService.playVictorySound(), completes);
        // Further checks (like verifying no sound actually played) are hard without deeper mocking.
      });
    });

    group('Sound Control Methods', () {
      group('setSoundEnabled', () {
        test('updates soundEnabled state', () async {
          audioService.setSoundEnabled(false);
          expect(audioService.isSoundEnabled, isFalse); // Changed to isSoundEnabled
          audioService.setSoundEnabled(true);
          expect(audioService.isSoundEnabled, isTrue); // Changed to isSoundEnabled
        });
      });

      group('setVolume', () {
        test('updates volume state and clamps values', () async {
          audioService.setVolume(0.8);
          expect(audioService.volume, 0.8);
          audioService.setVolume(1.5); // Above max
          expect(audioService.volume, 1.0); // Should be clamped
          audioService.setVolume(-0.5); // Below min
          expect(audioService.volume, 0.0); // Should be clamped
        });
      });
    });

    group('Dispose', () {
      test('dispose runs without error', () async {
        // Test that dispose can be called without throwing an exception.
        // Verifying internal players are disposed is hard without DI.
        await expectLater(audioService.dispose(), completes);
      });
    });
  });
}
