# Powiadomienie timera — notatka wdrożeniowa

> STATUS: wersja 3 — bez foreground service. Powiadomienie z licznikiem jest
> zwykłym, przypiętym powiadomieniem systemowym publikowanym bezpośrednio
> (TimerNotification.kt): czas renderuje chronometr systemowy
> (setUsesChronometer+setWhen), więc tyka bez żadnego procesu i przeżywa
> nawet śmierć aplikacji — odporne na Doze i OEM-y (ColorOS ubijał FGS,
> stąd zmiana architektury). STOP: TimerStopReceiver zapisuje dokładny
> moment naciśnięcia (pending stop), chowa powiadomienie i budzi Dart;
> pending stop jest aplikowany przy starcie/wznowieniu aplikacji
> (TimerService.stopAt), więc czas sesji się nie przekłamuje.
> Przypomnienie o zapomnianym timerze: alarm systemowy
> (zonedSchedule exactAllowWhileIdle) planowany przy starcie sesji.
> Uwaga: na Androidzie 14+ użytkownik może zsunąć przypięte powiadomienie —
> przy powrocie do aplikacji jest ono ponownie publikowane.


Warstwa Dart timera jest kompletna i nie zależy od żywego procesu:
źródłem prawdy jest rekord sesji w bazie z `endUtc == null` (patrz
`TimerService`, `SessionRepository.watchActive`). Timer odtwarza się po
ubiciu procesu i restarcie urządzenia — pokrywa to test
`timer_service_test.dart` („active timer is recovered from the database").

## Co jest gotowe

- Interfejs `TimerForegroundService` (domena) + zaślepka
  `NoopTimerForegroundService`.
- Provider `timerForegroundServiceProvider` (domyślnie Noop).
- Podłączenie w `TimeDockApp`: `ref.listen(activeSessionProvider)` woła
  `show()` przy starcie/zmianie i `hide()` przy zatrzymaniu, z rozwiązaną
  nazwą kontekstu.
- Logika zapomnianego timera (`ForgottenTimer`) + propozycja przycięcia
  przy STOP (ekran aktywnego timera).

## Co pozostaje (wymaga urządzenia/emulatora)

Natywna implementacja `TimerForegroundService` na Androida:

1. Started **foreground service** (Kotlin) z kanałem notyfikacji.
2. Notyfikacja z `setUsesChronometer(true)` + `setWhen(startMillis)` — licznik
   liczy system, bez budzenia Dart co sekundę.
3. Akcje w notyfikacji: **STOP** i **Przełącz na…** (PendingIntent → metoda
   platformowa → `TimerService.stop()` / szybki wybór kontekstu).
4. Uprawnienia: `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS` (API 33+),
   `FOREGROUND_SERVICE_SPECIAL_USE` lub typ `dataSync`.
5. Rejestracja implementacji przez override `timerForegroundServiceProvider`
   w `main()` pod `Platform.isAndroid`.

Przypomnienie „zapomnianego timera" (§5.3) wyślemy jako zaplanowaną
notyfikację (`flutter_local_notifications`, `zonedSchedule`) na
`start + threshold`, anulowaną przy STOP.

Powód odroczenia: budowa i weryfikacja foreground service wymaga
uruchomienia na Androidzie; logika, od której zależy poprawność pomiaru,
jest już zaimplementowana i przetestowana niezależnie od tej warstwy.
