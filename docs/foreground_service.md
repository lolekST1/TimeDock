# Powiadomienie timera — notatka wdrożeniowa

> STATUS: wersja 4 — foreground service przywrócony jako mechanizm
> anty-zamrożeniowy. Powiadomienie z zegarem jest publikowane bezpośrednio
> (TimerNotification.show) natywnym chronometrem (setUsesChronometer+setWhen),
> więc pojawia się od razu i tyka bez CPU; następnie TimerService (foreground
> service, typ specialUse) „przejmuje" to samo powiadomienie (ID 256), żeby
> proces nie został zamrożony przez OEM-y (ColorOS/Oppo). Bez tego zamrożony
> proces wstrzymuje dostarczenie przypomnienia do czasu otwarcia aplikacji —
> to była regresja po usunięciu FGS w wersji 3.
>
> Przypomnienie o zapomnianym timerze ma teraz DWIE drogi dostarczenia:
> 1. tick w procesie (ForgottenReminderWatchdog) — co 30 s sprawdza próg i
>    publikuje przypomnienie bezpośrednio (showNow); działa, bo FGS trzyma
>    proces przy życiu, a TimerService trzyma partial wake lock (CPU nie śpi
>    przy zgaszonym ekranie). To odtwarza mechanizm z pierwszej działającej
>    wersji;
> 2. alarm systemowy (zonedSchedule alarmClock) jako zapas, gdyby proces mimo
>    wszystko zginął. Obie drogi używają tego samego ID powiadomienia (1001),
>    więc pokaże się co najwyżej jedno.
>
> STOP: TimerStopReceiver zapisuje dokładny moment (pending stop), chowa
> powiadomienie, zatrzymuje FGS i budzi Dart; pending stop jest aplikowany przy
> starcie/wznowieniu. Uwaga: na Androidzie 14+ użytkownik może zsunąć przypięte
> powiadomienie — przy powrocie do aplikacji jest ono ponownie publikowane.


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
