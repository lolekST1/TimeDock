# Eksport i backup — notatka wdrożeniowa (etap 6)

## Co jest gotowe (i przetestowane)

- **Format godzin i zaokrąglanie** (`ExportConfig`, `ExportRounding`):
  `h:mm` lub dziesiętne, opcjonalny przecinek dziesiętny, zaokrąglanie do
  N minut (w górę / do najbliższych) — wyłącznie w eksporcie, baza zawsze
  trzyma czas rzeczywisty.
- **Serializer CSV** (`CsvExporter`): per-sesja i zagregowany, z escapowaniem
  RFC-4180 (separatory/cudzysłowy/nowe linie) i konfigurowalnym separatorem.
- **Builder wierszy** (`ExportBuilder`): rozwiązuje nazwy workspace/projekt/
  podprojekt/zadanie + Jira z bazy, z cache per id.
- **Backup JSON** (`BackupService`): wersjonowany eksport/import całej bazy,
  round-trip i idempotencja pokryte testami; format to nośnik migracji na iOS
  i fundament przyszłej synchronizacji.
- **Zapis plików** (`FileStore`): eksporty i rotujące kopie (N ostatnich)
  w katalogu dokumentów aplikacji.
- **Systemowy share sheet** (`FileSharer` + `share_plus`): po zapisaniu pliku
  (CSV / worklog JSON / kopia) `ExportScreen` otwiera arkusz udostępniania —
  katalog aplikacji jest prywatny, więc to jest sposób, w jaki plik opuszcza
  urządzenie. Integracja za interfejsem `FileSharer` (Noop dla testów, jak
  `ReminderScheduler`); build Androida weryfikuje workflow **Build APK**.
  Plik jest udostępniany z **ogólnym typem MIME (`*/*`)** celowo: nazwa pliku
  ma już poprawne, pojedyncze rozszerzenie, a przy konkretnym MIME
  (`application/json`, `text/csv`) część odbiorców na Androidzie dokleja
  rozszerzenie zmapowane z tego typu, dając `foo.json.json`. Typ ogólny nie ma
  takiego mapowania — nie zmieniaj tego bez weryfikacji na urządzeniu.
- **UI** (`ExportScreen`): eksport CSV (sesje / podsumowanie), worklog JSON i
  kopia zapasowa dla zakresu raportu, przywracanie z ostatniej kopii.

## Co pozostaje (wymaga wtyczek/urządzenia)

1. **Przywracanie z dowolnego pliku** — wybór pliku kopii przez `file_picker`
   (obecnie: „Przywróć z ostatniej kopii" z katalogu aplikacji). Metoda
   `BackupService.importFromJson` jest gotowa i przetestowana.
2. **Automatyczny backup cykliczny** — wywołanie `FileStore.writeBackup` z
   harmonogramu (np. przy starcie, nie częściej niż raz dziennie) oraz
   opcjonalny upload do Google Drive (po MVP).
3. **XLSX** — po MVP; te same wiersze `ExportRow`/`AggregateRow`, inny zapis.

Powód odroczenia: pozostałe elementy to integracje z wtyczkami platformowymi
(file picker, Drive) lub funkcje po MVP; cała logika generowania i round-trip
danych jest już zaimplementowana i pokryta testami niezależnie od tych warstw.
