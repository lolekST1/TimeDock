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
2. Uzupełnij `jiraId` na zadaniach, których czas ma trafić do rozliczenia
   (np. `ABS-123`). Pole jest walidowane formatem `^[A-Z][A-Z0-9]+-\d+$`;
   puste zadania są pomijane w eksporcie.
3. Na **ekranie eksportu** ustaw zakres (dzień / tydzień / miesiąc — ten sam
   selektor co w raportach) i wybierz **„Eksportuj worklog (JSON)"**.
4. Powstaje plik `timedock_worklog_<timestamp>.json` w katalogu `exports/`
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
    "workspace": "Absysco"
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

Uwagi dla konsumenta:
- **Idempotencja:** `sessionId` jest stabilny między eksportami — ponowne
  wgranie tej samej sesji ma nadpisywać, nie duplikować.
- **Strefa czasu:** znaczniki są w UTC. Ściana czasu lokalnego (offset w chwili
  zdarzenia) żyje w bazie TimeDock i nie jest częścią tego formatu.
- **Sesje przez północ:** oddawane jako jeden rekord (bez wizualnego dzielenia
  na doby, które robią tylko raporty).

## Punkt wejścia programistyczny

Gdy powstanie warstwa sieciowa, ten sam potok da się wywołać bez UI:

- `WorklogExportBuilder.worklogRows(workspaceId, range)` — pobiera z
  repozytoriów, filtruje regułą wyżej i zwraca `List<WorklogRow>`.
- `WorklogExporter.toJson(rows)` — czysta serializacja do stringa JSON.

Cała logika wpływająca na poprawność danych jest w warstwie `domain`/`data`
i pokryta testami (`test/domain/worklog_export_test.dart`,
`test/data/worklog_export_builder_test.dart`) — bez zależności od Fluttera.

## Ograniczenie: brak tożsamości autora (jeden użytkownik)

TimeDock jest **narzędziem osobistym** (specyfikacja §17). W modelu danych nie
istnieje encja ani pole użytkownika/autora — jedna instalacja przechowuje dane
jednej osoby. **Eksport worklog nie zawiera więc informacji, od kogo pochodzi
czas pracy.**

Ma to znaczenie dla aplikacji zastępującej Tempo, gdzie worklog jest z natury
przypisany do konkretnego pracownika. Autora trzeba ustalić poza tym plikiem —
możliwe podejścia (decyzja na etap integracji, nie ten):

1. **Tożsamość po stronie wgrywającego** — aplikacja rozliczeniowa przypisuje
   wszystkie sesje z pliku do użytkownika, który go przesłał / jest zalogowany.
   Najprostsze, nie wymaga zmian w TimeDock.
2. **Pole autora w eksporcie** — dodać do `WorklogRow` opcjonalne
   `author`/`workerId` (np. e-mail lub identyfikator Jira), konfigurowane raz
   w ustawieniach. Wymaga małej zmiany w TimeDock (nadal offline, bez sieci).

Jeśli docelowo potrzebne jest podejście 2, jest to naturalny kolejny krok —
poza zakresem tej zmiany.
