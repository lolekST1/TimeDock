# TimeDock – Plan implementacji MVP

Plan realizuje `SPECYFIKACJA.md` (v2). Podzielony na etapy, z których każdy
kończy się działającą, testowalną aplikacją — kolejność jest tak dobrana, żeby
najwcześniej powstał rdzeń decydujący o sensie projektu (timer 1-tap +
wiarygodna persystencja), a rzeczy „doklejane" (raporty, eksport, widget)
przyszły później.

## Zasada przewodnia kolejności

Ryzyko projektu nie leży w UI, tylko w trzech miejscach:
persystencja timera na Androidzie (foreground service), poprawność reguł
czasowych (północ/DST/kolizje) i model danych, którego nie da się później
tanio zmienić. Dlatego etapy 1–3 budują te fundamenty, zanim powstanie
jakikolwiek „ładny" ekran.

---

## Etap 0 — Bootstrap projektu

**Cel:** kompilujący się szkielet z CI, na którym każdy kolejny etap ma testy.

- `flutter create` (Android minSdk 26, docelowo iOS bez konfiguracji na razie)
- Zależności: `flutter_riverpod`, `drift`, `drift_flutter`, `uuid`,
  `intl`, `flutter_local_notifications` (etap 3), `build_runner`
- Struktura katalogów (pragmatyczna Clean Architecture, per feature):

```
lib/
  core/            # motyw M3, formatowanie czasu, Result, stałe
  domain/          # encje, interfejsy repozytoriów, logika czysta
    entities/
    repositories/
    services/      # reguły czasowe, agregacje, walidatory
  data/            # Drift: schema, DAO, implementacje repozytoriów, seed
  features/
    home/          # ekran główny
    timer/         # aktywny timer + foreground service
    history/       # oś czasu dnia + edycja sesji
    reports/
    settings/
  app.dart
  main.dart
```

- Lint (`flutter_lints` + zaostrzenia), formatter, GitHub Actions:
  `analyze` + `test` na każdy push
- Motyw Material 3 (light/dark, kolor seed per workspace)

**Wyjście:** pusta aplikacja z motywem, zielone CI.

---

## Etap 1 — Model danych i warstwa domenowa

**Cel:** kompletny, przetestowany fundament — najdroższa rzecz do zmiany później.

- Schema Drift: `workspaces`, `projects`, `sub_projects`, `tasks`,
  `time_sessions` — zgodnie z §4 specyfikacji (UUID, soft delete,
  `createdAt/updatedAt`, czasy jako UTC + offset)
- Encje domenowe (czysty Dart, bez zależności od Drift)
- Repozytoria: interfejsy w domenie, implementacje na DAO Drift,
  strumienie (watch) pod reaktywne UI Riverpod
- Seed pierwszego uruchomienia (§15): Absysco/Prywatne + projekty + podprojekty
- Logika czysta w `domain/services`:
  - `TimeRules` — podział sesji na granicy doby lokalnej, obsługa DST
  - `SessionValidator` — kolizje przy edycji, start < koniec, propozycja przycięcia sąsiada
  - `SessionAggregator` — drzewo Workspace→Project→SubProject→Task→Sessions z sumami
- Migracje: baza od `schemaVersion = 1` + szkielet testów migracyjnych

**Testy (rdzeń projektu):** północ, DST, kolizje, agregacje, seed-idempotencja.

**Wyjście:** brak nowego UI; `flutter test` pokrywa całą domenę.

---

## Etap 2 — Rdzeń timera + ekran główny

**Cel:** wymaganie nr 1 — start pomiaru jednym tapnięciem, jeden aktywny timer.

- `TimerService` (domena): start(kontekst) = zamknij aktywną sesję → otwórz nową
  (rekord z `endUtc = null`); stop; przełączenie kontekstu bez restartu pomiaru
- Odtwarzanie aktywnego timera z bazy przy starcie aplikacji (proces mógł zginąć)
- Ekran główny (§7): przełącznik workspace (zapamiętywany), sekcje
  Ostatnio używane (konteksty, max 5, deduplikacja) / Ulubione / Wszystkie projekty
- Gesty (§7.1): tap = natychmiastowy start; long-press = arkusz
  (podprojekty, zadania, edycja, kolor, ulubiony, ukryj, archiwizuj)
- CRUD projektów/podprojektów/zadań z arkusza (formularze proste, bez osobnego
  modułu „zarządzanie")
- Pasek aktywnego timera na dole ekranu głównego (kontekst + licznik + STOP)

**Testy:** jednostkowe `TimerService` (auto-zamykanie poprzedniej sesji),
widget-test „tap na projekt startuje timer w ≤1 interakcji".

**Wyjście:** aplikacją da się już realnie mierzyć czas — bez ozdób.

---

## Etap 3 — Ekran aktywnego timera + foreground service

**Cel:** wiarygodność pomiaru (§5.2–5.3) — najbardziej androidowy etap.

- Ekran aktywnego timera (§8): duży licznik (render z `now - startUtc`),
  edytowalny kontekst w trakcie sesji, komentarz, STOP
- Foreground service (Kotlin, za interfejsem platformowym w Darcie —
  izolacja pod przyszły iOS):
  - notyfikacja z chronometrem systemowym, akcje STOP i „Przełącz na…"
  - start/stop service sprzężony z cyklem życia sesji w bazie
- Zapomniany timer (§5.3): próg (domyślnie 4 h) → notyfikacja
  „Nadal pracujesz nad X?"; przy STOP długiej sesji propozycja przycięcia końca
- Ustawienia per workspace: próg przypomnienia, wł./wył.

**Testy:** integracyjny „ubij proces przy aktywnym timerze → restart → licznik
ciągły"; jednostkowe logiki progu.

**Wyjście:** timer przeżywa śmierć procesu i restart telefonu; STOP z notyfikacji.

---

## Etap 4 — Historia + edycja sesji

**Cel:** drugie wymaganie nadrzędne — dane da się poprawić (§9–10).

- Oś czasu dnia: bloki sesji z kolorem projektu, widoczne luki,
  swipe między dniami, skok do daty, podział wizualny sesji przez północ
- Szczegóły sesji → edycja: czasy (picker + chipy „-15 min", „-1 h",
  „koniec poprzedniej"), kontekst, komentarz
- Ręczne dodanie sesji („+", domyślny zakres: od końca ostatniej sesji do teraz)
- Podział sesji w punkcie czasu; usuwanie z undo (snackbar)
- Walidacja przez `SessionValidator` z etapu 1; flagi `wasEdited` / `isManuallyAdded`

**Testy:** widget-testy przepływów edycji, kryteria z §14
(poprawa końca ≤3 tapy, dodanie sesji ≤4 tapy).

**Wyjście:** pełny cykl życia danych — zmierz, obejrzyj, popraw.

---

## Etap 5 — Raporty

**Cel:** §11 — z danych robi się ewidencja.

- Zakresy dzienny/tygodniowy/miesięczny z nawigacją okresami
- Drzewo rozwijane Workspace→Project→SubProject→Task→Sessions z sumami
  (rendering na `SessionAggregator` z etapu 1 — tu głównie UI)
- Wiersz „(bez zadania)" dla sesji bez niższych poziomów
- Grupowanie sesji zadania do jednej pozycji z sumą

**Testy:** golden/widget dla drzewa; agregacje już pokryte w etapie 1.

---

## Etap 6 — Eksport CSV + backup

**Cel:** §13 — dane wychodzą na zewnątrz i są bezpieczne.

- Eksport CSV per sesja + eksport zagregowany (widok raportu); konfiguracja
  separatora i formatu godzin (dziesiętny/`h:mm`), opcjonalne zaokrąglanie
  tylko w eksporcie; share sheet systemowy
- Backup automatyczny lokalny: kopia pliku SQLite + wersjonowany JSON,
  rotacja N kopii; przywracanie z pliku (import na nowym urządzeniu)

**Testy:** round-trip backupu (eksport → import → identyczne dane),
jednostkowe formatów CSV i zaokrągleń.

---

## Etap 7 — Widget + wykończenie

**Cel:** „jedno kliknięcie od telefonu w kieszeni" (§6) i domknięcie MVP.

- Widget ekranu głównego (Glance/RemoteViews przez `home_widget` lub natywnie):
  kafelki ostatnich kontekstów + stan timera ze STOP
- Przegląd całości względem tabeli kryteriów §14 — każdy wiersz jako test
  akceptacyjny; przebudowa UX tam, gdzie próg nie jest spełniony
- Puste stany, haptyka przy starcie/stopie, ikona, splash
- Przygotowanie release: podpisywanie, `--obfuscate`, wersjonowanie

**Wyjście:** MVP kompletne wg §2.

---

## Po MVP (kolejność sugerowana)

1. Kafelek Quick Settings
2. Backup do Google Drive
3. Statystyki (§12) — czyste funkcje nad sesjami, bez zmian schematu
4. Eksport XLSX
5. Dowolny zakres dat w raportach
6. iOS (Live Activities zamiast foreground service)

---

## Ryzyka i decyzje otwarte

| Ryzyko | Mitygacja |
|---|---|
| Foreground service vs oszczędzanie baterii (OEM-y typu Xiaomi/Samsung agresywnie ubijają) | Źródłem prawdy jest timestamp w bazie (§5.2) — nawet ubity service nie psuje pomiaru; service tylko poprawia widoczność i STOP z notyfikacji |
| Widget wymaga kodu natywnego per platforma | Trzymany w izolowanym module platformowym; MVP tylko Android |
| Drift codegen spowalnia iterację | Codegen tylko w `data/`; domena czysta, testowana bez build_runnera |
| Zakres etapu 4 (edycja) bywa niedoszacowany | Walidator i reguły czasowe powstają w etapie 1 z testami — etap 4 to głównie UI |

## Definicja ukończenia MVP

Wszystkie progi z §14 spełnione i pokryte testami; timer przeżywa ubicie
procesu i restart urządzenia; backup odtwarza dane na czystej instalacji;
CI zielone (analyze + testy domeny, widgetów i migracji).
