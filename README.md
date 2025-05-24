# Ludo Club

This project is a Flutter-based implementation of the classic Ludo board game, developed for educational purposes.

Ein modernes Flutter-Spiel basierend auf dem klassischen "Mensch ärgere Dich nicht" Brettspiel.

## Features

- Modernes UI-Design
- Lokaler Mehrspielermodus
- KI-Gegner mit normalem Schwierigkeitsgrad
- Würfelanimation
- Spielfigurenbewegung
- Vollständige Implementierung der Spielregeln und Schlaglogik

## Projektstruktur

```
lib/
├── main.dart                 # Haupteinstiegspunkt der App
├── models/
│   └── game_state.dart       # Datenmodelle für Spielzustand und Spieler
├── providers/
│   └── game_provider.dart    # State-Management mit Provider
├── services/
│   ├── audio_service.dart    # Service für Soundeffekte
│   ├── game_service.dart     # Spiellogik-Service
│   ├── save_load_service.dart # Service für Speichern und Laden von Spielständen
│   └── statistics_service.dart # Service für Spielstatistiken
└── ui/
    ├── game_screen.dart      # Hauptspielbildschirm
    ├── home_screen.dart      # Startbildschirm mit Spieleinstellungen
    ├── player_stats_screen.dart # Bildschirm für Spielerstatistiken
    └── saved_games_screen.dart  # Bildschirm für geladene Spiele
```

## Spielregeln

- 2-4 Spieler pro Partie
- Jeder Spieler würfelt und bewegt seine Figur entsprechend
- Bei einer 6 darf der Spieler insgesamt bis zu dreimal würfeln
- Safe Zones: Felder, die sich 4 Positionen vom jeweiligen Start-Index entfernt befinden
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

Dieses Projekt wurde zu Bildungszwecken erstellt.
