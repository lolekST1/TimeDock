# TimeDock – Specyfikacja projektu (v2)

> Wersja 2 specyfikacji. Względem v1 domyka decyzje techniczne i produktowe,
> które w v1 były białymi plamami: edycję sesji, cykl życia timera na Androidzie,
> backup danych, semantykę modelu danych, reguły czasowe oraz wybór bazy danych.
> Zmiany względem v1 są oznaczone w tekście jako **[v2]**.

---

## 1. Cel i filozofia

TimeDock **nie jest timerem**. Jest osobistym systemem ewidencji czasu pracy,
używanym codziennie przez lata.

Dwa równorzędne wymagania nadrzędne **[v2 – w v1 było tylko pierwsze]**:

1. **Start pomiaru w maksymalnie jedno kliknięcie.** Szczegóły uzupełnia się później.
2. **Dane muszą być wiarygodne i możliwe do poprawienia.** Użytkownik codziennie
   zapomina włączyć lub wyłączyć timer — jeśli nie może tego łatwo skorygować,
   ewidencja przestaje się zgadzać i aplikacja zostaje porzucona.

Każda decyzja UX odpowiada na pytanie:
*„Czy dzięki temu użytkownik będzie chciał używać TimeDock codziennie przez następne 5 lat?"*

---

## 2. Zakres

### MVP (pierwsze wydanie)

- Workspace'y, projekty, podprojekty, zadania, sesje
- Timer: start jednym kliknięciem, jeden aktywny timer, foreground service
- Ekran główny (ostatnio używane / ulubione / projekty)
- Ekran aktywnego timera
- **Edycja, ręczne dodawanie, dzielenie i usuwanie sesji [v2]**
- Historia jako oś czasu dnia
- Raporty: dzienny / tygodniowy / miesięczny z drill-downem
- Eksport CSV
- **Automatyczny backup lokalny [v2]**
- **Widget na ekran główny + akcje w notyfikacji [v2]**

### Po MVP (architektura przygotowana, implementacja później)

- Kafelek Quick Settings **[v2]**
- Eksport Excel (XLSX)
- Backup do Google Drive **[v2]**
- Statystyki: Focus Score, najdłuższa sesja, średnia długość sesji,
  liczba przełączeń, czas niezmierzony, cele tygodniowe
- Wydanie iOS
- Synchronizacja między urządzeniami (model danych gotowy od dnia 1, patrz §4.1)

---

## 3. Technologia

- Flutter, Material 3
- Riverpod (stan aplikacji)
- **Drift (SQLite) [v2 – zamiana z Isar]**
  Uzasadnienie: Isar 3 jest nieutrzymywany, Isar 4 utknął w becie. Dla aplikacji
  przechowującej wieloletnią ewidencję czasu Drift daje: stabilność, jawne migracje
  schematu, backup jako kopia jednego pliku SQLite, pełne SQL do raportów.
- Clean Architecture **w wariancie pragmatycznym [v2]**: trzy warstwy
  (domena / dane / prezentacja), bez nadmiarowych abstrakcji. Logika raportów,
  agregacji i reguł czasowych żyje w czystej domenie i jest w 100% testowalna
  bez Fluttera.
- Offline first — brak jakiejkolwiek zależności od sieci w MVP
- Android jako pierwsza platforma; kod (poza modułem foreground
  service/widget/tile, izolowanym za interfejsem platformowym) gotowy na iOS

---

## 4. Model danych

```
Workspace
    ↓
Project
    ↓
SubProject (opcjonalny)
    ↓
Task (opcjonalny)
    ↓
TimeSession
```

Każdy poziom poza Project jest opcjonalny. Sesja zawsze wskazuje projekt;
podprojekt i zadanie tylko jeśli istnieją.

### 4.1. Zasady wspólne dla wszystkich encji [v2]

- **Identyfikatory: UUID v4** (nie auto-increment) — przygotowanie pod przyszłą
  synchronizację między urządzeniami.
- Pola `createdAt`, `updatedAt` (UTC) na każdej encji.
- **Soft delete**: encje z historią nigdy nie są usuwane fizycznie.
  - `isArchived` — ukrycie z list wyboru; historia i raporty nadal działają.
  - Fizyczne „Usuń" jest dostępne wyłącznie dla projektów / podprojektów / zadań,
    które **nie mają żadnej sesji**. Jeśli sesje istnieją, UI oferuje tylko archiwizację.

### 4.2. Workspace

Pola: `id`, `name`, `colorSeed`, `sortOrder`, `isArchived`.

- Workspace'y są **danymi startowymi (seed), nie kodem [v2]**. Użytkownik może
  dodawać, edytować nazwę/kolor i archiwizować workspace'y. Seed: `Absysco`, `Prywatne`.
- Każdy workspace ma własne projekty, statystyki, raporty i ustawienia. Dane się nie mieszają.
- Aplikacja zapamiętuje ostatnio wybrany workspace i otwiera się na nim.

### 4.3. Project

Pola: `id`, `workspaceId`, `name`, `color`, `isFavorite`, `isHidden`, `isArchived`, `sortOrder`.

- Operacje: dodaj, edytuj, zmień kolor, oznacz jako ulubiony, ukryj, archiwizuj,
  usuń (tylko bez sesji — patrz §4.1).
- **Rozróżnienie `isHidden` vs `isArchived` [v2]:** ukryty projekt nie pojawia się
  na ekranie głównym, ale można na niego dalej logować czas (np. przez wyszukiwanie);
  zarchiwizowany jest wyłączony z logowania czasu, pozostaje tylko w historii i raportach.

### 4.4. SubProject

Pola: `id`, `projectId`, `name`, `isArchived`, `sortOrder`.

- Projekt może mieć listę podprojektów; są w pełni konfigurowalne.
- Jeżeli projekt nie ma podprojektów, UI nigdzie ich nie pokazuje.

### 4.5. Task

Pola: `id`, `projectId`, `subProjectId?`, `name`, `jiraId?`, `note?`, `isArchived`.

- Zadanie jest opcjonalne. Przykłady: `DAN-1234`, `BUG-887`, `Landing Page`.
- **Numer Jira i opis zadania żyją wyłącznie na Task [v2]** — sesja ich nie
  duplikuje. Jedno zadanie ma wiele sesji.

### 4.6. TimeSession

Pola: `id`, `workspaceId`, `projectId`, `subProjectId?`, `taskId?`,
`startUtc`, `endUtc?` (null = sesja aktywna), `startOffsetMinutes`,
`endOffsetMinutes?`, `comment?`, `isManuallyAdded`, `wasEdited`.

- **Sesja referencjonuje zadanie, nie kopiuje jego pól [v2].** Rozwiązuje to
  niespójność v1, gdzie Jira ID i komentarz istniały równolegle w Task i w sesji.
- `comment` na sesji znaczy co innego niż `note` na zadaniu: *„co konkretnie
  robiłem w tej sesji"*. Oba pola są zasadne, ale mają różną semantykę.
- Czas trwania jest **wyliczany**, nie przechowywany (jedno źródło prawdy).
- `isManuallyAdded` i `wasEdited` pozwalają odróżnić w historii pomiar „na żywo"
  od wpisu z pamięci — istotne dla zaufania do własnych danych.
- Denormalizowane `workspaceId`/`projectId` na sesji są świadome: raporty nie
  wymagają joinów przez całą hierarchię, a sesja przetrwa archiwizację poziomów pośrednich.

### 4.7. Reguły czasowe [v2 – w całości nowe]

- Zapis zawsze w **UTC + offset strefy w chwili zdarzenia**. Wyświetlanie w strefie
  lokalnej. Zmiana czasu letni/zimowy w trakcie sesji nie psuje czasu trwania
  (liczonego z UTC).
- **Sesja przez północ:** przechowywana jako jeden rekord. Raport dzienny i oś
  czasu dnia **dzielą ją wizualnie na granicy doby lokalnej** (23:00–01:00 →
  1h w dniu A, 1h w dniu B). Suma tygodniowa/miesięczna liczona z rekordów, więc
  zawsze się zgadza.
- Nakładanie się sesji jest **niemożliwe z definicji** (jeden aktywny timer) —
  z wyjątkiem edycji ręcznej; walidator edycji ostrzega o kolizji i proponuje
  automatyczne przycięcie sąsiada.

---

## 5. Timer

### 5.1. Zasada jednego timera

Może istnieć dokładnie jeden aktywny timer. Uruchomienie nowego:

1. zatrzymuje poprzedni i zapisuje jego sesję,
2. uruchamia nowy.

Bez pytań, bez dialogów potwierdzających.

### 5.2. Cykl życia i odporność na śmierć procesu [v2 – w całości nowe]

- Aktywny timer to **rekord w bazie z `endUtc = null`**, nie ticker w pamięci.
  Licznik na ekranie to tylko renderowanie różnicy `now - startUtc`.
- Ubicie procesu, restart telefonu, crash — po ponownym uruchomieniu aplikacja
  odtwarza aktywny timer z bazy i licznik pokazuje poprawny, ciągły czas.
- **Foreground service z notyfikacją** przez cały czas działania timera:
  - notyfikacja pokazuje projekt/zadanie i bieżący czas (chronometr systemowy),
  - akcje w notyfikacji: **STOP** oraz **przełącz na…** (otwiera szybki wybór),
  - service chroni proces przed agresywnym zabijaniem przez Androida.
- Timer działa poprawnie także wtedy, gdy service jednak zginie — bo źródłem
  prawdy jest timestamp w bazie, a nie działający proces.

### 5.3. Zapomniany timer [v2 – w całości nowe]

- Po przekroczeniu konfigurowalnego progu (domyślnie **4 h**) notyfikacja pyta:
  *„Nadal pracujesz nad [Danone]?"* z akcjami: „Tak" / „Zatrzymaj teraz" /
  „Zatrzymaj i przytnij…".
- Przy zatrzymywaniu sesji dłuższej niż próg ekran STOP proponuje **przycięcie
  końca** (wybór faktycznej godziny zakończenia) zamiast zapisu 14-godzinnej sesji.
- Próg i włączenie/wyłączenie przypomnienia są ustawieniem per workspace.

---

## 6. Szybki start — poza aplikacją [v2 – w całości nowe]

„Jedno kliknięcie" liczy się **od telefonu w kieszeni**, nie od otwartej aplikacji.
Dlatego wejścia w pomiar istnieją na trzech poziomach:

1. **Widget na ekranie głównym** (MVP): kafelki ostatnio używanych kontekstów
   (projekt→podprojekt→zadanie) + stan aktywnego timera ze STOP. Jeden tap
   startuje pomiar bez otwierania aplikacji.
2. **Notyfikacja aktywnego timera** (MVP): STOP i przełączenie bez otwierania aplikacji.
3. **Kafelek Quick Settings** (po MVP): wznawia ostatni kontekst / zatrzymuje bieżący.

---

## 7. Ekran główny

Kolejność sekcji (od góry):

```
Przełącznik Workspace
    ↓
Ostatnio używane
    ↓
Ulubione
    ↓
Wszystkie projekty
```

- **Ostatnio używane**: pełne konteksty, nie same projekty — np.
  `Danone → DAN-1234`, `Carlsberg → TT → CAR-987`. Jeden tap = start timera
  dokładnie w tym kontekście. Limit: 5 pozycji. Lista deduplikowana względem kontekstu.
- **Ulubione [v2 – doprecyzowane]**: projekty oznaczone ręcznie gwiazdką
  (long-press → „Ulubiony" lub w edycji projektu). Sekcja znika, gdy pusta.
  Projekt obecny w „Ostatnio używanych" nie jest dublowany w „Ulubionych".
- **Wszystkie projekty**: kolorowe kafelki, bez ukrytych i zarchiwizowanych.

### 7.1. Gesty [v2 – rozstrzygnięcie konfliktu z v1]

| Gest | Działanie |
|---|---|
| **Tap na projekt/kontekst** | Natychmiast startuje timer. Zero pytań. |
| **Long-press na projekt** | Arkusz: wybór podprojektu/zadania przed startem, edycja, kolor, ulubiony, ukryj, archiwizuj |
| **Tap na podprojekt/zadanie w arkuszu** | Startuje timer w tym kontekście |

Start na poziomie podprojektu/zadania pierwszy raz = 2 kliknięcia
(long-press + tap). Każdy kolejny = 1 kliknięcie przez „Ostatnio używane".
To spełnia limit z §14.

---

## 8. Ekran aktywnego timera

Hierarchia wizualna (od najważniejszego):

1. **Duży licznik** — dominuje ekran.
2. Kontekst: Projekt / Podprojekt / Zadanie — każde pole **edytowalne w trakcie
   sesji** (tap otwiera wybór; zmiana nie restartuje pomiaru).
3. Komentarz sesji i Jira ID zadania — do uzupełnienia teraz albo nigdy;
   puste pola nie krzyczą o wypełnienie.
4. **STOP** — duży, na dole, w zasięgu kciuka.

Zasada: wszystko poza licznikiem i STOP może zostać uzupełnione później
(także po zakończeniu sesji, z poziomu historii).

---

## 9. Edycja i ręczne sesje [v2 – w całości nowe, funkcja krytyczna]

Codzienne scenariusze, które MUSZĄ być szybkie:

- **Zapomniałem włączyć** → ręczne dodanie sesji: z ekranu historii, przycisk „+",
  domyślnie podpowiada zakres od końca ostatniej sesji do teraz.
- **Zapomniałem wyłączyć** → edycja godziny końca istniejącej sesji (time picker
  + szybkie chipy: „-15 min", „-1 h", „koniec poprzedniej przerwy").
- **Pracowałem nad czymś innym niż wskazuje sesja** → zmiana kontekstu
  (projekt/podprojekt/zadanie) zapisanej sesji.
- **Jedna sesja, dwa projekty** → **podział sesji** w wybranym punkcie czasu;
  powstają dwa rekordy, drugi od razu otwiera wybór kontekstu.
- **Usunięcie sesji** → dostępne z poziomu szczegółów sesji, z undo (snackbar).

Walidacja: edycja nie może stworzyć nakładających się sesji (patrz §4.7);
start < koniec; sesja edytowana dostaje `wasEdited = true`.

---

## 10. Historia

- Widok dnia jako **oś czasu**: bloki sesji z godzinami, kolorem projektu
  i kontekstem; **luki między sesjami są widoczne** (przygotowanie pod statystykę
  „czas niezmierzony").
- Tap na blok → szczegóły sesji → edycja (§9).
- Nawigacja: swipe między dniami, skok do daty.
- Sesje przechodzące przez północ renderowane zgodnie z §4.7.

```
08:00–09:10  Danone
09:15–10:30  Carlsberg → TT → CAR-987
11:00–11:45  PMI
```

---

## 11. Raporty

Zakresy: dzienny / tygodniowy / miesięczny (+ dowolny zakres dat po MVP).

Drill-down przez rozwijanie:

```
Workspace → Project → SubProject → Task → Sessions
```

Przykład:

```
Carlsberg                42 h
  TT                     18 h
    CAR-123               8 h
    CAR-555              10 h
  LF                     12 h
  CC                      7 h
```

- **Grupowanie**: wiele sesji jednego zadania sumuje się do jednej pozycji
  (`DAN-1234 → 3h 15m`); rozwinięcie pokazuje poszczególne sesje.
- Sesje bez podprojektu/zadania grupują się w wiersz „(bez zadania)" na danym poziomie.
- Raporty liczone w czystej warstwie domenowej (testowalne bez UI), zgodnie
  z regułami czasowymi z §4.7.

---

## 12. Statystyki (po MVP — architektura gotowa)

Focus Score, najdłuższa sesja, średnia długość sesji, liczba przełączeń
projektów w ciągu dnia, czas niezmierzony (luki w osi dnia w zadanych godzinach
pracy), cele tygodniowe per workspace/projekt.

Wymóg architektoniczny: wszystkie statystyki są czystymi funkcjami nad listą
sesji — żadna nie wymaga zmian schematu bazy.

---

## 13. Eksport i backup

### 13.1. Eksport [v2 – zdefiniowany od strony celu]

Główny przypadek użycia: **miesięczne zestawienie czasu dla pracodawcy/klienta**.

- **CSV (MVP)**: jedna linia = jedna sesja; kolumny: data, start, koniec,
  czas trwania, workspace, projekt, podprojekt, zadanie, Jira ID, komentarz.
  Separator i format godzin (dziesiętny `1,25` vs `1:15`) konfigurowalne.
- **Zestawienie zagregowane (MVP)**: eksport widoku raportu (per projekt/zadanie,
  zsumowane) — to jest to, co faktycznie wysyła się klientowi.
- **XLSX (po MVP)**: te same dane, arkusz sformatowany.
- Opcjonalne **zaokrąglanie w eksporcie** (np. do 15 min w górę) — wyłącznie na
  poziomie eksportu; baza zawsze trzyma czas rzeczywisty.

### 13.2. Backup [v2 – w całości nowe]

Utrata telefonu nie może oznaczać utraty 5 lat ewidencji.

- **Backup automatyczny lokalny (MVP)**: cykliczna kopia pliku SQLite +
  eksport JSON do katalogu aplikacji/Download; rotacja N ostatnich kopii.
- **Przywracanie z pliku (MVP)**: import kopii na nowym urządzeniu.
- **Google Drive (po MVP)**: automatyczny upload kopii.
- Format backupu JSON jest wersjonowany — służy też jako format migracji na iOS
  i fundament przyszłej synchronizacji.

---

## 14. Kryteria akceptacji UX

Aplikacja ma być **szybsza od uruchomienia stopera**. Mierzalne progi:

| Scenariusz | Maks. interakcji |
|---|---|
| Start ostatniego kontekstu z widgetu | 1 tap |
| Start dowolnego projektu z otwartej aplikacji | 1 tap |
| Start nowego kontekstu podprojekt/zadanie | 2 (long-press + tap) |
| STOP z notyfikacji | 1 tap |
| Poprawa godziny końca ostatniej sesji | ≤ 3 tapy od otwarcia aplikacji |
| Ręczne dodanie zapomnianej sesji | ≤ 4 tapy + wybór godzin |

Jeżeli którykolwiek próg nie jest spełniony, UX należy przebudować —
to kryteria testów akceptacyjnych, nie wskazówki.

---

## 15. Dane startowe (seed)

Seed wykonywany przy pierwszym uruchomieniu; potem wszystko edytowalne przez UI.

**Workspace'y:** `Absysco`, `Prywatne`.

**Projekty w Absysco:** Danone, Carlsberg, PMI, MSS, KP, XBS, MerService,
Cursor, ProPeople.

**Podprojekty:** Carlsberg → TT, LF, CC, Dyskonty. Danone → (brak).

---

## 16. Jakość i testy [v2 – w całości nowe]

- **Testy jednostkowe (wymagane w MVP)** dla całej domeny: agregacje raportów,
  grupowanie, podział sesji przez północ, DST, walidacja edycji (kolizje),
  logika „zapomnianego timera", statystyki.
- Testy widget dla przepływów krytycznych: start 1-tap, STOP, edycja sesji.
- Test integracyjny persystencji timera: „ubij proces przy aktywnym timerze →
  uruchom ponownie → licznik ciągły".
- Migracje schematu Drift objęte testami migracyjnymi od wersji 1.

---

## 17. Świadomie poza zakresem

- Stawki godzinowe, fakturowanie, flagi „billable" — eksport z zaokrągleniem
  pokrywa obecną potrzebę; model danych nie blokuje dodania tego później.
- Integracja z API Jira (pobieranie zadań) — Jira ID pozostaje polem tekstowym.
- Wykrywanie bezczynności (idle detection) — nierealne na mobile bez ciężkich
  uprawnień; zamiast tego przypomnienie o zapomnianym timerze (§5.3).
- Praca zespołowa / współdzielenie — TimeDock jest narzędziem osobistym.
