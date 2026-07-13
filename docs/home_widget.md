# Widget ekranu głównego + Quick Settings — notatka (etap 7)

„Jedno kliknięcie" liczy się od telefonu w kieszeni, nie od otwartej aplikacji
(§6 specyfikacji). Poza aplikacją pomiar startuje z trzech miejsc; wszystkie
wymagają kodu natywnego, więc są odroczone do pracy na urządzeniu. Dane, na
których operują, są już gotowe.

## Co zapewnia gotowa warstwa Dart

- `SessionRepository.watchRecentContexts` — kafelki „ostatnio używane"
  (deduplikowane konteksty) do wyświetlenia w widgecie.
- `SessionRepository.watchActive` — stan aktywnego timera (start, kontekst).
- `TimerService.start/stop` — akcje, które widget/tile/notyfikacja mają wołać.

## Do zrobienia natywnie

1. **Widget ekranu głównego** (Android `AppWidgetProvider` + Glance/RemoteViews):
   - lista ostatnich kontekstów (tap → start bez otwierania aplikacji),
   - stan aktywnego timera z chronometrem + STOP,
   - odświeżanie po zmianie aktywnej sesji (WorkManager / broadcast).
   Most Flutter↔widget: `home_widget` (współdzielony storage + callback).
2. **Kafelek Quick Settings** (`TileService`): wznów ostatni kontekst / STOP.
3. **Wspólny punkt wejścia**: headless Dart entrypoint startujący timer z
   akcji widgetu/kafla, piszący do tej samej bazy Drift.

Powód odroczenia: budowa i weryfikacja wymaga uruchomienia na Androidzie;
logika startu/stopu i dane do wyświetlenia są zaimplementowane i przetestowane.
