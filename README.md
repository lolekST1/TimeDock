# TimeDock

Osobisty system ewidencji czasu pracy — nie „timer", lecz pamięć czasu pracy,
zaprojektowana wokół jednego wymagania: **start pomiaru w jedno kliknięcie**,
a szczegóły uzupełnia się później. Drugie wymaganie równorzędne: **dane muszą
być wiarygodne i łatwe do poprawienia**.

Pełna wizja i decyzje projektowe: [`SPECYFIKACJA.md`](SPECYFIKACJA.md).
Plan wdrożenia: [`PLAN.md`](PLAN.md).

## Stos technologiczny

- Flutter + Material 3
- Riverpod (stan)
- Drift / SQLite (baza, offline-first)
- Pragmatyczna Clean Architecture: `domain` (czysta) / `data` / `features` (UI)
- Android jako pierwsza platforma; kod przygotowany pod iOS

## Architektura

```
lib/
  core/       motyw M3, formatowanie czasu, ticker licznika
  domain/     encje, interfejsy repozytoriów, CZYSTA logika:
                TimeRules            podział doby (północ, DST), sumy
                SessionValidator     wykrywanie kolizji + auto-przycięcie
                SessionAggregator    drzewo raportu Projekt>Podprojekt>Zadanie
                TimerService         reguła jednego timera
                ForgottenTimer       zapomniany timer + przycięcie
                DayTimeline          oś dnia z lukami
                SessionEditing       podział sesji
                ReportRange          zakresy dzień/tydzień/miesiąc
                CsvExporter          serializacja CSV
  data/       Drift (schema, DAO, mappery), implementacje repozytoriów,
              seed, SessionEditor, ExportBuilder, BackupService, FileStore
  features/   home, timer, history, reports, export, app_state (providery)
```

Zasada: cała logika wpływająca na poprawność danych żyje w `domain` i jest w
100% testowalna bez Fluttera. UI to cienka warstwa nad providerami Riverpod.

## Kluczowe decyzje projektowe

- **Aktywny timer = rekord w bazie z `endUtc == null`.** Źródłem prawdy jest
  timestamp, nie proces — timer przeżywa ubicie procesu i restart urządzenia.
- **Czas w UTC + offset** zapisany w chwili zdarzenia — poprawne godziny
  ścienne i czas trwania mimo zmiany DST; sesje przez północ dzielone
  wizualnie, sumy zawsze się zgadzają.
- **Soft delete + UUID** na wszystkich encjach — bezpieczne usuwanie i
  fundament pod przyszłą synchronizację.
- **Jira/nazwa na zadaniu, komentarz na sesji** — sesja referencjonuje zadanie,
  nie duplikuje pól.

## Uruchomienie

### Najszybciej: gotowy APK z GitHub Actions (bez instalacji Fluttera)

Po każdym pushu na gałąź roboczą workflow **Build APK** buduje instalowalny plik:

1. GitHub → zakładka **Actions** → ostatni bieg „Build APK”.
2. Sekcja **Artifacts** → pobierz **timedock-apk** (ZIP z `app-debug.apk`).
3. Rozpakuj i przenieś APK na telefon; zainstaluj (zezwól na „instalację z
   nieznanych źródeł”).

Możesz też odpalić build ręcznie: Actions → Build APK → **Run workflow**.

### Lokalnie (gdy masz Flutter SDK)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generuje kod Drift
flutter run                                                 # Android
```

## Testy

```bash
flutter analyze
flutter test
```

Pokrycie (142 testów): reguły czasowe (północ/DST), migracje bazy v1→v2 i
v2→v3, walidacja kolizji,
agregacja raportów, reguła jednego timera + odtwarzanie po restarcie,
zapomniany timer, oś dnia, podział/edycja sesji (w tym auto-przycięcie i
konflikty), tworzenie zadań „w locie", walidacja formatu Jira ID, zakresy
raportów, statystyki
(Focus Score, przełączenia, czas niezmierzony), format/zaokrąglanie i
serializacja CSV, serializacja i filtrowanie eksportu worklog (JSON),
round-trip i idempotencja backupu, ustawienia
(persystencja, mapowanie na domenę), zakresy custom i cele tygodniowe;
widget-testy: start 1-tap, edycja sesji, grupowanie w raporcie,
statystyki, ustawienia.

## Status wdrożenia

| Etap | Zakres | Status |
|---|---|---|
| 0 | Bootstrap, CI, motyw | ✅ |
| 1 | Model danych + domena | ✅ |
| 2 | Rdzeń timera + ekran główny (1-tap) | ✅ |
| 3 | Ekran timera, zapomniany timer, seam service | ✅ (natywny service odroczony) |
| 4 | Historia + edycja/dodawanie/podział sesji | ✅ |
| 5 | Raporty z drill-downem | ✅ |
| 6 | Eksport CSV + backup JSON | ✅ (share/file-picker odroczone) |
| 7 | Dopracowanie (haptyka, README) | ✅ (natywny widget odroczony) |
| 8 | Przygotowanie eksportu worklog (flaga workspace, walidacja Jira, JSON) | ✅ (bez sieci; §17 nadal poza zakresem) — [`docs/worklog_export.md`](docs/worklog_export.md) |

### Elementy odroczone (wymagają urządzenia/wtyczek)

Logika, od której zależy poprawność danych, jest zaimplementowana i
przetestowana; poniższe to integracje platformowe do wykonania na urządzeniu:

- Natywny foreground service + notyfikacja z licznikiem — [`docs/foreground_service.md`](docs/foreground_service.md)
- Widget ekranu głównego i kafelek Quick Settings
- Share sheet, przywracanie z dowolnego pliku, backup do Google Drive, XLSX — [`docs/export_backup.md`](docs/export_backup.md)
- Wysyłka worklog do aplikacji rozliczeniowej (sieć/endpoint/tożsamość autora) — [`docs/worklog_export.md`](docs/worklog_export.md)

## Kryteria akceptacji UX (§14 specyfikacji)

| Scenariusz | Próg | Realizacja |
|---|---|---|
| Start projektu z aplikacji | 1 tap | `ProjectTile` tap → `TimerService.start` (widget-test) |
| Start ostatniego kontekstu | 1 tap | `RecentContextTile` tap |
| Start nowego podprojektu/zadania | 2 (long-press + tap) | `ProjectSheet` |
| STOP z paska/notyfikacji | 1 tap | `ActiveTimerBar`, seam notyfikacji |
| Poprawa końca ostatniej sesji | ≤ 3 tapy | edytor sesji, chipy ±15 min (widget-test) |
| Ręczne dodanie sesji | ≤ 4 tapy + godziny | „Dodaj sesję" z domyślnym zakresem |
