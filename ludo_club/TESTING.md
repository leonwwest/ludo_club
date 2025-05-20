# Ludo Club - Testanleitung

## Voraussetzungen
- Flutter SDK installiert (https://flutter.dev/docs/get-started/install)
- Dart SDK installiert
- Ein Editor wie VS Code oder Android Studio
- Git (optional)

## Projekt einrichten
1. Entpacken Sie die ZIP-Datei in ein Verzeichnis Ihrer Wahl
2. Öffnen Sie ein Terminal und navigieren Sie zum Projektverzeichnis:
   ```
   cd pfad/zu/ludo_club
   ```
3. Installieren Sie die Abhängigkeiten:
   ```
   flutter pub get
   ```

## Testen der Anwendung
### Web-Version testen
```
flutter run -d chrome
```

### Mobile-Version testen
Stellen Sie sicher, dass ein Emulator läuft oder ein physisches Gerät angeschlossen ist:
```
flutter run
```

## Funktionen testen
1. **Spielerauswahl**: Überprüfen Sie, ob Sie die Anzahl der Spieler (2-4) auswählen können
2. **KI-Gegner**: Testen Sie, ob die KI-Gegner automatisch Züge ausführen
3. **Würfeln**: Prüfen Sie, ob die Würfelanimation funktioniert und korrekte Werte liefert
4. **Spielfiguren bewegen**: Testen Sie, ob Spielfiguren korrekt bewegt werden können
5. **Schlaglogik**: Überprüfen Sie, ob gegnerische Figuren korrekt geschlagen werden
6. **Safe Zones**: Testen Sie, ob Figuren in Safe Zones nicht geschlagen werden können
7. **Spielerwechsel**: Prüfen Sie, ob der Spielerwechsel korrekt funktioniert
8. **Dreimaliges Würfeln bei 6**: Testen Sie, ob ein Spieler bei einer 6 bis zu dreimal würfeln darf

## Bekannte Einschränkungen
- Die Anwendung unterstützt derzeit nur den lokalen Mehrspielermodus
- Online-Funktionalität ist nicht implementiert
- Die Spielfiguren werden vereinfacht dargestellt

## Fehlerbehebung
- Falls Probleme mit Abhängigkeiten auftreten, führen Sie `flutter clean` aus und dann erneut `flutter pub get`
- Bei Darstellungsproblemen auf mobilen Geräten, testen Sie die Anwendung im Landscape-Modus
