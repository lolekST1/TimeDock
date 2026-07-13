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

Pokrycie (91 testów): reguły czasowe (północ/DST), walidacja kolizji,
agregacja raportów, reguła jednego timera + odtwarzanie po restarcie,
zapomniany timer, oś dnia, podział/edycja sesji (w tym auto-przycięcie i
konflikty), zakresy raportów, format/zaokrąglanie i serializacja CSV,
round-trip i idempotencja backupu; widget-testy: start 1-tap, edycja sesji,
grupowanie w raporcie.

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

### Elementy odroczone (wymagają urządzenia/wtyczek)

Logika, od której zależy poprawność danych, jest zaimplementowana i
przetestowana; poniższe to integracje platformowe do wykonania na urządzeniu:

- Natywny foreground service + notyfikacja z licznikiem — [`docs/foreground_service.md`](docs/foreground_service.md)
- Widget ekranu głównego i kafelek Quick Settings
- Share sheet, przywracanie z dowolnego pliku, backup do Google Drive, XLSX — [`docs/export_backup.md`](docs/export_backup.md)

## Kryteria akceptacji UX (§14 specyfikacji)

| Scenariusz | Próg | Realizacja |
|---|---|---|
| Start projektu z aplikacji | 1 tap | `ProjectTile` tap → `TimerService.start` (widget-test) |
| Start ostatniego kontekstu | 1 tap | `RecentContextTile` tap |
| Start nowego podprojektu/zadania | 2 (long-press + tap) | `ProjectSheet` |
| STOP z paska/notyfikacji | 1 tap | `ActiveTimerBar`, seam notyfikacji |
| Poprawa końca ostatniej sesji | ≤ 3 tapy | edytor sesji, chipy ±15 min (widget-test) |
| Ręczne dodanie sesji | ≤ 4 tapy + godziny | „Dodaj sesję" z domyślnym zakresem |
