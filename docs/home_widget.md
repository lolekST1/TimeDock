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

## Stan

1. **Widget ekranu głównego** (`TimerWidgetProvider`, RemoteViews) — ZROBIONE
   w wersji podstawowej: pokazuje stan aktywnego timera (kontekst + natywny
   chronometr) z przyciskiem STOP, a w stanie bezczynności otwiera aplikację.
   Stan czytany z `TimerState` (współdzielone prefs), odświeżany przy
   starcie/stopie. TODO: kafelki ostatnich kontekstów z „tap → start bez
   otwierania aplikacji" (wymaga mostka `home_widget` + headless Dart
   entrypointu piszącego do bazy Drift).
2. **Kafelek Quick Settings** (`TimerTileService`) — ZROBIONE: aktywny gdy
   timer działa (tap = STOP), bezczynny gdy nie (tap = otwórz aplikację).
3. **Wspólny punkt wejścia** (headless Dart start z widgetu/kafla) — TODO;
   dopóki go nie ma, start spoza aplikacji otwiera UI do wyboru kontekstu.
