# Eksport worklog (JSON) — zasilanie przyszłej aplikacji rozliczeniowej

Notatka opisuje, jak TimeDock oddaje dane czasu pracy do przyszłej wewnętrznej
aplikacji zastępującej Tempo dla Jiry. To **krok 1**: TimeDock produkuje plik
w uzgodnionym formacie, ale **nie łączy się z żadnym API** — integracja
sieciowa (upload, tokeny, endpoint) to świadomie kolejny etap. Integracja
z API Jiry pozostaje poza zakresem (specyfikacja §17); `jiraId` to nadal pole
tekstowe wpisywane ręcznie.

## Jak wyeksportować (z aplikacji)

1. Oznacz przestrzeń (workspace) do eksportu: **Ustawienia → Przestrzenie →
   menu przestrzeni → „Eksportuj do rozliczenia czasu"**. Flaga jest per
   workspace i domyślnie wyłączona.
2. (Opcjonalnie, zalecane) Ustaw **autora worklog**: **Ustawienia → Domyślne
   eksportu → „Autor worklog"** — e-mail lub identyfikator osoby. Trafia do
   każdego wiersza eksportu (pole `author`), żeby aplikacja rozliczeniowa
   wiedziała, od kogo pochodzi czas. Puste = pole `author` będzie `null`.
3. Uzupełnij `jiraId` na zadaniach, których czas ma trafić do rozliczenia
   (np. `ABS-123`). Pole jest walidowane formatem `^[A-Z][A-Z0-9]+-\d+$`;
   puste zadania są pomijane w eksporcie.
4. Na **ekranie eksportu** ustaw zakres (dzień / tydzień / miesiąc — ten sam
   selektor co w raportach) i wybierz **„Eksportuj worklog (JSON)"**.
5. Powstaje plik `timedock_worklog_<timestamp>.json` w katalogu `exports/`
   aplikacji (systemowy share sheet jest odroczony — patrz
   [`export_backup.md`](export_backup.md)). Ten plik jest wejściem dla
   aplikacji rozliczeniowej.

## Co trafia do eksportu (reguły filtrowania)

Wiersz powstaje **tylko** gdy spełnione są wszystkie warunki naraz:

- sesja jest **zakończona** (`endUtc != null` — aktywny timer jest pomijany),
- należy do przestrzeni z włączoną flagą `exportsToTimesheet`,
- jej zadanie ma **niepusty `jiraId`**.

Reguła żyje jako czysta, testowalna funkcja `WorklogExportBuilder.shouldExport`;
sam serializer (`WorklogExporter`) jest jej nieświadomy.

## Format pliku

Lista obiektów JSON, jeden na sesję:

```json
[
  {
    "sessionId": "1f0c9e2a-…",
    "issueKey": "ABS-123",
    "startUtc": "2026-07-16T08:00:00.000Z",
    "endUtc": "2026-07-16T09:30:00.000Z",
    "durationSeconds": 5400,
    "description": "Analiza wymagań",
    "workspace": "Absysco",
    "author": "jan.kowalski@absysco.com"
  }
]
```

| Pole | Typ | Znaczenie |
|---|---|---|
| `sessionId` | string (UUID) | Identyfikator sesji — **klucz idempotencji** po stronie konsumenta. |
| `issueKey` | string | `jiraId` zadania (np. `ABS-123`); zawsze niepusty. |
| `startUtc` | string (ISO-8601, UTC, `Z`) | Początek sesji w UTC. |
| `endUtc` | string (ISO-8601, UTC, `Z`) | Koniec sesji w UTC. |
| `durationSeconds` | int | Czas trwania w sekundach (liczony z UTC, odporny na DST). |
| `description` | string \| null | Komentarz sesji; może być `null` lub pusty. |
| `workspace` | string | Nazwa przestrzeni, informacyjnie. |
| `author` | string \| null | Autor czasu pracy (e-mail/identyfikator) skonfigurowany w ustawieniach; `null` gdy nie ustawiony. |

Uwagi dla konsumenta:
- **Idempotencja:** `sessionId` jest stabilny między eksportami — ponowne
  wgranie tej samej sesji ma nadpisywać, nie duplikować.
- **Strefa czasu:** znaczniki są w UTC. Ściana czasu lokalnego (offset w chwili
  zdarzenia) żyje w bazie TimeDock i nie jest częścią tego formatu.
- **Sesje przez północ:** oddawane jako jeden rekord (bez wizualnego dzielenia
  na doby, które robią tylko raporty).

## Punkt wejścia programistyczny

Gdy powstanie warstwa sieciowa, ten sam potok da się wywołać bez UI:

- `WorklogExportBuilder.worklogRows(workspaceId, range, {author})` — pobiera
  z repozytoriów, filtruje regułą wyżej, stempluje `author` i zwraca
  `List<WorklogRow>`.
- `WorklogExporter.toJson(rows)` — czysta serializacja do stringa JSON.

Cała logika wpływająca na poprawność danych jest w warstwie `domain`/`data`
i pokryta testami (`test/domain/worklog_export_test.dart`,
`test/data/worklog_export_builder_test.dart`) — bez zależności od Fluttera.

## Tożsamość autora (jeden użytkownik na instalację)

TimeDock jest **narzędziem osobistym** (specyfikacja §17): w modelu danych nie
istnieje encja użytkownika, a jedna instalacja przechowuje dane jednej osoby.
Nie ma więc obsługi wielu użytkowników w obrębie aplikacji.

Żeby aplikacja zastępująca Tempo wiedziała, **od kogo** pochodzi czas pracy,
autor jest konfigurowany raz na instalację (**Ustawienia → Domyślne eksportu →
„Autor worklog"**) i stemplowany na każdy wiersz eksportu w polu `author`
(e-mail lub identyfikator). To celowo proste rozwiązanie — offline, bez sieci
i bez modelu wielu użytkowników:

- Wartość jest przycinana; puste ustawienie daje `author: null`.
- Autor jest ustawieniem globalnym aplikacji (SharedPreferences), nie polem na
  sesji ani encji — spójne z „jedna instalacja = jedna osoba".

Aplikacja rozliczeniowa może użyć `author` wprost albo — jeśli i tak
uwierzytelnia wgrywającego — potraktować pole jako informację pomocniczą i
przypisać sesje do zalogowanego użytkownika.
