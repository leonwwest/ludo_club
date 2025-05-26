// ludo_game_logic.dart // // Kernlogik für ein Ludo‑ähnliches Spiel (z. B. Ludo Club) in Dart. // Diese Datei kümmert sich nur um Spiellogik und Spielzustand – keine UI. // ---------------------------------------------------------------

import 'dart:math';

/// Farben bzw. Spieler. enum PlayerColor { red, green, blue, yellow }

/// Art des Pfades, auf dem sich ein Spielstein befindet.
enum PiecePathType {
  YARD,       // Piece is in its starting yard
  MAIN_PATH,  // Piece is on the main 52-field path
  HOME_PATH,  // Piece is on its private home path (6 fields)
  FINISHED    // Piece has reached the final destination
}

/// Ein einzelner Spielstein. class Piece { /// Spielerfarbe. final PlayerColor color; /// Logische Position des Spielsteins. /// * `-1`: Im Startbereich (Yard). /// * `0` bis `mainPathLength - 1`: Auf dem Hauptpfad. /// * `mainPathLength` bis `mainPathLength + homeLength - 1`: Auf dem Heimweg (Zielgerade). /// * `mainPathLength + homeLength`: Im Ziel (Finished). int position = -1; // Standardmäßig im Startbereich.

/// Eindeutige ID des Spielsteins innerhalb seiner Farbe (z.B. 0, 1, 2, 3). final int id;

Piece(this.color, this.id);

/// Ist der Spielstein im Startbereich (Yard)? bool get isInYard => position == -1;

/// Hat der Spielstein das Ziel erreicht? bool get isFinished => position == LudoGame.mainPathLength + LudoGame.homeLength;

/// Ist der Spielstein auf dem Hauptpfad? bool get isOnMainPath => position >= 0 && position < LudoGame.mainPathLength;

/// Ist der Spielstein auf dem Heimweg (Zielgerade)? bool get isOnHomePath => position >= LudoGame.mainPathLength && position < LudoGame.mainPathLength + LudoGame.homeLength;

@override bool operator ==(Object other) => identical(this, other) || other is Piece && runtimeType == other.runtimeType && color == other.color && id == other.id;

@override int get hashCode => color.hashCode ^ id.hashCode;
}

/// Stellt detaillierte Informationen für die UI-Darstellung eines Spielsteins bereit.
class VisualPieceInfo {
  final Piece pieceRef; // Reference to the original piece
  final PiecePathType pathType;
  final int displayIndex; // YARD: 0-3 (which spot); MAIN_PATH: 0-51 (global); HOME_PATH: 0-5; FINISHED: 0 (or specific if multiple finish spots)
  final PlayerColor color;

  VisualPieceInfo({
    required this.pieceRef,
    required this.pathType,
    required this.displayIndex,
    required this.color,
  });
}

/// Enthält die gesamte Spiellogik und den Zustand. class LudoGame { /// Länge des Hauptpfads (Anzahl der Felder). static const int mainPathLength = 52; // Klassisches Ludo hat 52 Felder. /// Länge des Heimwegs (Zielgerade) für jeden Spieler. static const int homeLength = 6; // Klassisches Ludo hat 6 Felder.

/// Globale Indizes der sicheren Felder auf dem Hauptpfad. static const List<int> safeGlobalIndices = [ 0, 8, 13, 21, 26, 34, 39, 47, // Typische sichere Felder (oft Startfelder und zusätzliche) ];

/// Start-Indizes auf dem Hauptpfad für jede Spielerfarbe. static const Map<PlayerColor, int> startIndex = { PlayerColor.red: 0, PlayerColor.green: 13, PlayerColor.blue: 26, PlayerColor.yellow: 39, };

/// Spielsteine für jeden Spieler. late Map<PlayerColor, List<Piece>> pieces;

/// Aktueller Spieler, der am Zug ist. PlayerColor _currentTurn = PlayerColor.red; PlayerColor get currentPlayer => _currentTurn;

/// Aktueller Würfelwert (1-6). Eine `0` bedeutet, dass noch nicht gewürfelt wurde oder der Wurf ungültig war. int _dice = 0; int get diceValue => _dice;

/// Zähler für Würfe im aktuellen Zug (um z.B. dreimaliges Würfeln bei keiner bewegbaren Figur zu ermöglichen). int _rollCount = 0; int get rollCount => _rollCount;

/// Gibt an, ob der aktuelle Spieler einen Pasch (6) gewürfelt hat und erneut würfeln darf. bool _canRollAgain = false; bool get canRollAgain => _canRollAgain;

/// Initialisiert ein neues Spiel. LudoGame() { resetGame(); }

/// Setzt das Spiel auf den Anfangszustand zurück. void resetGame() { pieces = {}; for (var color in PlayerColor.values) { pieces[color] = List.generate(4, (id) => Piece(color, id)); } _currentTurn = PlayerColor.red; _dice = 0; _rollCount = 0; _canRollAgain = false; }

/// Führt einen Würfelwurf aus. /// Gibt den gewürfelten Wert zurück. int rollDice() { if (_rollCount >= 3 && !_canRollAgain) { // Normalerweise nur 1 Wurf, außer spezielle Regeln (z.B. 3x wenn nichts geht) return 0; // Kein Wurf mehr erlaubt }

_dice = Random().nextInt(6) + 1; _rollCount++; _canRollAgain = _dice == 6;

// Wenn nach 3 Würfen keine 6 dabei war und keine Figur bewegt werden konnte (nicht hier geprüft), // dann ist der nächste Spieler dran. if (_rollCount >= 3 && !_canRollAgain) { _advanceTurn(); } else if (!_canRollAgain && !canAnyPieceMove()) { // Wenn keine 6 und keine Figur bewegbar ist (nach dem ersten oder zweiten Wurf) _advanceTurn(); } return _dice; }

/// Prüft, ob der angegebene Spielstein bewegt werden kann. bool canMovePiece(Piece piece) { if (piece.color != _currentTurn || _dice == 0 || piece.isFinished) { return false; }

if (piece.isInYard) { return _dice == 6; // Nur mit einer 6 darf man raus. }

// Prüfen, ob der Ziel-Index über das Ende des Heimwegs hinausgeht. int targetPos = piece.position + _dice; if (piece.isOnHomePath && targetPos > mainPathLength + homeLength) { return false; // Darf nicht über das Ziel hinaus } return true; }

/// Bewegt den angegebenen Spielstein gemäß dem aktuellen Würfelwert. /// Gibt `true` zurück, wenn der Zug erfolgreich war, andernfalls `false`. bool movePiece(Piece piece) { if (!canMovePiece(piece)) { return false; }

if (piece.isInYard && _dice == 6) { piece.position = startIndex[piece.color]!; _handleCapture(piece.position, piece); // Startfeld besetzen } else if (!piece.isInYard) { int currentGlobalPos = _toGlobalIndex(piece); int stepsToHomeEntry = 0; bool movingToHomePath = false;

// Ist der Spieler kurz vor seinem Heimweg? final playerStartIndex = startIndex[piece.color]!; int homeEntryPredecessor = (playerStartIndex - 1 + mainPathLength) % mainPathLength;

if (piece.isOnMainPath) {
  // Berechne, ob der Zug auf den Heimweg führt
  int theoreticalMainPathPos = piece.position;
  for(int i=0; i<_dice; ++i) {
    theoreticalMainPathPos = (theoreticalMainPathPos + 1) % mainPathLength;
    if (theoreticalMainPathPos == playerStartIndex && (piece.position + i +1) >= playerStartIndex ) { // piece.position < playerStartIndex implies it passed the full circle
       // Check if it's about to pass or land on its start (which is entry to home)
       // This logic is complex due to wrap-around path.
       // Simplified: if current pos + steps lands on or passes homeEntryPredecessor AND is close to start.
       // A more robust way: track if a piece has completed one full circle.
       // For now, assume if it passes its "start - 1", it can enter home.
       if( (piece.position <= homeEntryPredecessor && (piece.position + _dice) > homeEntryPredecessor) || 
           (piece.position > homeEntryPredecessor && (piece.position + _dice) > homeEntryPredecessor + mainPathLength ) // Wrapped around
        ) {
            stepsToHomeEntry = homeEntryPredecessor - piece.position;
            if (stepsToHomeEntry < 0) stepsToHomeEntry += mainPathLength; // Wrapped
            stepsToHomeEntry +=1; // steps to land ON start/home entry

            if (_dice >= stepsToHomeEntry) {
                movingToHomePath = true;
            }
       }
       break; // Found potential home entry
    }
  }
}


if (movingToHomePath) {
  int stepsIntoHome = _dice - stepsToHomeEntry;
  if (stepsIntoHome < homeLength) { // Muss genau im Heimweg landen
    piece.position = mainPathLength + stepsIntoHome;
    // Keine Kollisionen auf dem Heimweg (eigene Figuren blockieren ggf. aber schlagen nicht)
  } else if (stepsIntoHome == homeLength) { // Genau ins Ziel
    piece.position = mainPathLength + homeLength;
  } else {
    return false; // Ungültiger Zug (über das Ziel hinaus)
  }
} else if (piece.isOnHomePath) {
  int newHomePos = piece.position + _dice;
  if (newHomePos <= mainPathLength + homeLength) {
    piece.position = newHomePos;
  } else {
    return false; // Über das Ziel hinaus
  }
} else { // Bewegung auf dem Hauptpfad
  piece.position = (currentGlobalPos + _dice) % mainPathLength;
  _handleCapture(piece.position, piece);
}
}

// Zug beendet, es sei denn, es war ein Pasch (6) oder alle Figuren des Spielers sind im Ziel. bool playerHasWon = pieces[_currentTurn]!.every((p) => p.isFinished); if (!_canRollAgain || playerHasWon) { _advanceTurn(); } else { _rollCount = 0; // Reset roll count for the bonus turn } return true; }

/// Konvertiert die logische Position eines Spielsteins auf dem Hauptpfad oder Heimweg /// in einen globalen Index (0 bis mainPathLength - 1). /// Für Steine im Yard oder Ziel wird -1 zurückgegeben. int _toGlobalIndex(Piece piece) { if (piece.isInYard || piece.isFinished) { return -1; } if (piece.isOnMainPath) { return piece.position; }

// Für Steine auf dem Heimweg: Ihre "position" ist mainPathLength + lokaler Heimweg-Index. // Dies muss zurück auf einen globalen Index gemappt werden, wenn sie andere schlagen könnten, // was aber typischerweise nicht der Fall ist, da der Heimweg privat ist. // Für die Zwecke der Kollisionserkennung auf dem Hauptpfad ist dies nicht relevant. // Wenn ein Stein den Heimweg betritt, verlässt er den Hauptpfad. return -1; // Nicht auf dem Hauptpfad für Kollisionen relevant. }

/// Behandelt das Schlagen von gegnerischen Figuren. void _handleCapture(int globalTargetIndex, Piece movingPiece) { if (safeGlobalIndices.contains(globalTargetIndex)) { return; // Sicheres Feld }

for (var color in PlayerColor.values) { if (color == movingPiece.color) continue;

pieces[color]!.forEach((opponentPiece) {
  if (!opponentPiece.isInYard && !opponentPiece.isFinished) {
    int opponentGlobalIndex = _toGlobalIndex(opponentPiece);
    if (opponentGlobalIndex == globalTargetIndex) {
      opponentPiece.position = -1; // Zurück in den Startbereich
    }
  }
});
}
}

/// Prüft, ob der aktuelle Spieler überhaupt einen Stein bewegen kann. bool canAnyPieceMove() { return pieces[_currentTurn]!.any((piece) => canMovePiece(piece)); }

/// Prüft, ob alle Figuren eines Spielers blockiert sind (können nicht bewegt werden, auch nicht mit einer 6). bool _allPiecesBlocked(PlayerColor player) { if (_dice != 6 && pieces[player]!.every((p) => p.isInYard)) return true; return !pieces[player]!.any((p) => canMovePiece(p)); }

/// Wechselt zum nächsten Spieler. void _advanceTurn() { _currentTurn = PlayerColor.values[(_currentTurn.index + 1) % PlayerColor.values.length]; _dice = 0; _rollCount = 0; _canRollAgain = false;

// Wenn der neue Spieler keine Züge machen kann (z.B. alle Figuren im Yard und keine 6 gewürfelt), // dann direkt nochmal weitergeben (optional, je nach Regelwerk). // Diese Logik kann komplex werden, wenn z.B. 3x Würfeln erlaubt ist. }

/// Gibt eine Liste aller bewegbaren Figuren für den aktuellen Spieler und Würfelwurf zurück. List<Piece> getMovablePieces() { if (_dice == 0) return []; return pieces[_currentTurn]?.where((p) => canMovePiece(p)).toList() ?? []; }

  VisualPieceInfo getVisualPieceInfo(Piece piece) {
    if (piece.isInYard) {
      // For YARD, displayIndex could be piece.id (0-3) if they are visually distinct spots.
      return VisualPieceInfo(
        pieceRef: piece,
        pathType: PiecePathType.YARD,
        displayIndex: piece.id, // Assuming yard spots are 0,1,2,3
        color: piece.color,
      );
    } else if (piece.isFinished) {
      return VisualPieceInfo(
        pieceRef: piece,
        pathType: PiecePathType.FINISHED,
        displayIndex: 0, // Or piece.id if finished pieces are stacked/distinct visually
        color: piece.color,
      );
    } else if (piece.isOnHomePath) {
      // piece.position is mainPathLength to mainPathLength + homeLength - 1
      // displayIndex should be 0 to homeLength - 1
      return VisualPieceInfo(
        pieceRef: piece,
        pathType: PiecePathType.HOME_PATH,
        displayIndex: piece.position - LudoGame.mainPathLength,
        color: piece.color,
      );
    } else if (piece.isOnMainPath) {
      // piece.position is 0 to mainPathLength - 1 (relative to player start for some interpretations)
      // OR it's already a global index if _toGlobalIndex was part of its setting.
      // The LudoGame._toGlobalIndex(piece) method should be used here.
      // The existing _toGlobalIndex returns -1 if not on main path, but piece.isOnMainPath already checks this.
      // The current _toGlobalIndex in the file returns piece.position directly if isOnMainPath.
      // This assumes piece.position on main path IS ALREADY the global index.
      return VisualPieceInfo(
        pieceRef: piece,
        pathType: PiecePathType.MAIN_PATH,
        displayIndex: _toGlobalIndex(piece), // Use the existing _toGlobalIndex
        color: piece.color,
      );
    } else {
      // Should not happen if piece states are consistent
      // Defaulting to YARD as a fallback.
      print('Warning: Could not determine path type for piece ${piece.id} of color ${piece.color} at position ${piece.position}');
      return VisualPieceInfo(
        pieceRef: piece,
        pathType: PiecePathType.YARD,
        displayIndex: piece.id,
        color: piece.color,
      );
    }
  }
}

// Beispielverwendung: // // void main() { // LudoGame game = LudoGame(); // // print('Current player: ${game.currentPlayer}'); // int diceRoll = game.rollDice(); // print('Rolled a $diceRoll'); // // List<Piece> movable = game.getMovablePieces(); // if (movable.isNotEmpty) { // print('Movable pieces:'); // movable.forEach((p) => print(' Piece ${p.id} of ${p.color} at ${p.position}')); // game.movePiece(movable.first); // Beispiel: ersten bewegbaren Stein bewegen // print('Moved piece. New position: ${movable.first.position}'); // } else { // print('No movable pieces.'); // } // // print('Next player: ${game.currentPlayer}'); // // // Test Schlagen: // // game.pieces[PlayerColor.red]![0].position = 5; // Roter Stein auf Feld 5 // game.pieces[PlayerColor.green]![0].position = 10; // Grüner Stein auf Feld 10 // // game._currentTurn = PlayerColor.red; // Rot ist dran // game._dice = 5; // Rot würfelt eine 5, um auf Feld 10 zu landen // // Piece redPieceToMove = game.pieces[PlayerColor.red]![0]; // if (game.canMovePiece(redPieceToMove)) { // game.movePiece(redPieceToMove); // print('Red piece moved to ${redPieceToMove.position}'); // print('Green piece 0 is at ${game.pieces[PlayerColor.green]![0].position}'); // Sollte -1 sein (geschlagen) // } // }
