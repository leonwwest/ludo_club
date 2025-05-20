# Ludo Club

Ein modernes Flutter-Spiel basierend auf dem klassischen "Mensch ärgere Dich nicht" Brettspiel.

## Features

- Modernes UI-Design
- Lokaler Mehrspielermodus
- KI-Gegner mit normaler Schwierigkeit
- Würfelanimation
- Spielfigurenbewegung
- Vollständige Implementierung der Spielregeln und Schlaglogik

## Projektstruktur

```
lib/
├── main.dart                 # Haupteinstiegspunkt der App
├── models/
│   └── game_state.dart       # Datenmodelle für Spielzustand und Spieler
├── services/
│   └── game_service.dart     # Spiellogik-Service
├── providers/
│   └── game_provider.dart    # State-Management mit Provider
└── ui/
    ├── home_screen.dart      # Startbildschirm mit Spieleinstellungen
    └── game_screen.dart      # Hauptspielbildschirm
```

## Spielregeln

- 2-4 Spieler pro Partie
- Jeder Spieler würfelt und bewegt seine Figur entsprechend
- Bei einer 6 darf der Spieler bis zu dreimal insgesamt würfeln
- Safe Zones: Felder, die 4 Positionen vom jeweiligen Start-Index entfernt sind
- Auf Safe Zones können Figuren nicht geschlagen werden
- Schlaglogik: Landet ein Spieler auf einem Feld mit gegnerischen Figuren (außerhalb einer Safe Zone), werden alle gegnerischen Figuren zurück auf ihre Startposition geschickt

## Installation

Siehe [TESTING.md](TESTING.md) für detaillierte Anweisungen zur Installation und zum Testen.

## Erweiterungsmöglichkeiten

- Online-Mehrspielermodus
- Spielstatistiken
- Anpassbare Spielfiguren und Themes
- Spielstand speichern
- Achievements und Belohnungen

## Lizenz

Dieses Projekt ist für Bildungszwecke erstellt worden.
