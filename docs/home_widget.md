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

1. **Widget ekranu głównego** (`TimerWidgetProvider`, RemoteViews) — ZROBIONE:
   - aktywny timer: kontekst + natywny chronometr + STOP,
   - bezczynny: kafelki do 3 ostatnich kontekstów → **start jednym dotknięciem
     bez otwierania aplikacji** (tap otwiera apkę tylko gdy brak historii).
2. **Kafelek Quick Settings** (`TimerTileService`) — ZROBIONE: tap = STOP gdy
   działa; gdy nie — wznawia ostatni kontekst bez otwierania apki.
3. **Start bez ciężkiego headless silnika** — zamiast tego wzorzec „pending
   start" (analogiczny do „pending stop"): `WidgetStartReceiver` zapisuje
   natywnie zamiar (kontekst + moment) i od razu pokazuje zegar/FGS/aktualizuje
   widget; Dart tworzy sesję w bazie (źródło prawdy) przy najbliższym pchnięciu
   (`startRequested`, gdy proces żyje) albo przy starcie/wznowieniu
   (`applyPendingStart`). Lista ostatnich kontekstów jest wypychana do natywnej
   pamięci przez `widgetSyncProvider` (`updateWidget`).

## Znane ograniczenie

Jeśli timer wystartuje z widgetu/kafla, gdy aplikacja jest całkowicie ubita,
przypomnienie o zapomnianym timerze (tick w izolacie Dart) uzbroi się dopiero
po pierwszym otwarciu aplikacji — natywny zegar/FGS działają od razu, ale bez
żywego Darta nie ma ticku ani zaplanowanego alarmu. Docelowe rozwiązanie:
przenieść sprawdzanie progu do natywnego `TimerService` (postDelayed/Handler),
co uniezależni przypomnienie od izolaty i pozwoli zdjąć wakelock. Na razie
odłożone, żeby nie ruszać działającego mechanizmu.
