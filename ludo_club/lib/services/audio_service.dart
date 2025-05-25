import 'package:just_audio/just_audio.dart';

/// Service, der alle Soundeffekte im Spiel verwaltet
class AudioService {
  static final AudioService _instance = AudioService._internal();
  
  factory AudioService() {
    return _instance;
  }
  
  AudioService._internal();
  
  // Audio-Player für verschiedene Soundeffekte
  final AudioPlayer _dicePlayer = AudioPlayer();
  final AudioPlayer _movePlayer = AudioPlayer();
  final AudioPlayer _capturePlayer = AudioPlayer();
  final AudioPlayer _finishPlayer = AudioPlayer();
  final AudioPlayer _victoryPlayer = AudioPlayer();
  
  // Pfade zu den Sounddateien
  static const String _diceSoundPath = 'audio/dice_roll.mp3';
  static const String _moveSoundPath = 'audio/move.mp3';
  static const String _captureSoundPath = 'audio/capture.mp3';
  static const String _finishSoundPath = 'audio/victory.mp3';
  static const String _victorySoundPath = 'audio/victory.mp3';
  
  bool _soundEnabled = true;
  double _volume = 1.0;
  
  /// Initialisiert alle Soundeffekte
  Future<void> init() async {
    try {
      await Future.wait([
        _dicePlayer.setAsset(_diceSoundPath),
        _movePlayer.setAsset(_moveSoundPath),
        _capturePlayer.setAsset(_captureSoundPath),
        _finishPlayer.setAsset(_finishSoundPath),
        _victoryPlayer.setAsset(_victorySoundPath),
      ]);
      
      // Setze das Volume für alle Player
      _setVolumeForAllPlayers();
    } catch (e) {
      // print('Fehler beim Laden der Soundeffekte: $e'); // Removed avoid_print
      // Fehler leise behandeln, damit das Spiel auch ohne Sound funktioniert
    }
  }
  
  /// Ändert die Lautstärke für alle Soundeffekte
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _setVolumeForAllPlayers();
  }
  
  /// Aktiviert oder deaktiviert alle Soundeffekte
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }
  
  /// Überprüft, ob Sound aktiviert ist
  bool get isSoundEnabled => _soundEnabled;
  
  /// Gibt die aktuelle Lautstärke zurück
  double get volume => _volume;
  
  /// Setzt die Lautstärke für alle Player
  void _setVolumeForAllPlayers() {
    _dicePlayer.setVolume(_volume);
    _movePlayer.setVolume(_volume);
    _capturePlayer.setVolume(_volume);
    _finishPlayer.setVolume(_volume);
    _victoryPlayer.setVolume(_volume);
  }
  
  /// Spielt den Würfel-Sound ab
  Future<void> playDiceSound() async {
    if (_dicePlayer.processingState == ProcessingState.ready) {
      await playSound(_diceSoundPath);
    } else {
      // print("AudioPlayer not ready for dice sound, state: ${_dicePlayer.processingState}"); // Removed avoid_print
    }
  }
  
  /// Spielt den Bewegungs-Sound ab
  Future<void> playMoveSound() async {
    if (_movePlayer.processingState == ProcessingState.ready) {
      await playSound(_moveSoundPath);
    } else {
      // print("AudioPlayer not ready for move sound, state: ${_movePlayer.processingState}"); // Removed avoid_print
    }
  }
  
  /// Spielt den Sound ab, wenn eine gegnerische Figur geschlagen wird
  Future<void> playCaptureSound() async {
    if (_capturePlayer.processingState == ProcessingState.ready) {
      await playSound(_captureSoundPath);
    } else {
      // print("AudioPlayer not ready for capture sound, state: ${_capturePlayer.processingState}"); // Removed avoid_print
    }
  }
  
  /// Spielt den Sound ab, wenn eine Figur ins Ziel kommt
  Future<void> playFinishSound() async {
    if (_finishPlayer.processingState == ProcessingState.ready) {
      await playSound(_finishSoundPath);
    } else {
      // print("AudioPlayer not ready for finish sound, state: ${_finishPlayer.processingState}"); // Removed avoid_print
    }
  }
  
  /// Spielt den Sound ab, wenn ein Spieler das Spiel gewinnt
  Future<void> playVictorySound() async {
    if (_victoryPlayer.processingState == ProcessingState.ready) {
      await playSound(_victorySoundPath);
    } else {
      // print("AudioPlayer not ready for victory sound, state: ${_victoryPlayer.processingState}"); // Removed avoid_print
    }
  }
  
  /// Stoppt alle laufenden Sounds und gibt Ressourcen frei
  Future<void> dispose() async {
    await _dicePlayer.dispose();
    await _movePlayer.dispose();
    await _capturePlayer.dispose();
    await _finishPlayer.dispose();
    await _victoryPlayer.dispose();
  }

  Future<void> playSound(String assetPath) async {
    if (!_soundEnabled || _dicePlayer.playing) return;
    try {
      await _dicePlayer.setAsset(assetPath);
      await _dicePlayer.play();
    } catch (e) {
      // print('Error playing sound $assetPath: $e'); // Removed avoid_print
    }
  }
} 