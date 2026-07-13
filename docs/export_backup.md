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
- **UI** (`ExportScreen`): eksport CSV (sesje / podsumowanie) dla zakresu
  raportu, tworzenie kopii, przywracanie z ostatniej kopii.

## Co pozostaje (wymaga wtyczek/urządzenia)

1. **Systemowy share sheet** — po zapisaniu pliku udostępnić go przez OS
   (`share_plus`). Teraz `ExportScreen` pokazuje ścieżkę pliku; wystarczy
   dołożyć `Share.shareXFiles([file.path])`.
2. **Przywracanie z dowolnego pliku** — wybór pliku kopii przez `file_picker`
   (obecnie: „Przywróć z ostatniej kopii" z katalogu aplikacji). Metoda
   `BackupService.importFromJson` jest gotowa i przetestowana.
3. **Automatyczny backup cykliczny** — wywołanie `FileStore.writeBackup` z
   harmonogramu (np. przy starcie, nie częściej niż raz dziennie) oraz
   opcjonalny upload do Google Drive (po MVP).
4. **XLSX** — po MVP; te same wiersze `ExportRow`/`AggregateRow`, inny zapis.

Powód odroczenia: pozostałe elementy to integracje z wtyczkami platformowymi
(share, file picker, Drive), których nie da się zweryfikować bez urządzenia;
cała logika generowania i round-trip danych jest już zaimplementowana i
pokryta testami niezależnie od tych warstw.
