# TimeDock — wskazówki dla Claude

Projekt: osobisty system ewidencji czasu pracy (Flutter, Riverpod, Drift).
Szczegóły w `SPECYFIKACJA.md`, `PLAN.md` i `README.md`.

## Delegation

For small mechanical jobs — renames, simple lookups, one-line fixes, formatting — hand the work to a subagent on a smaller, cheaper model instead of doing it yourself, and review its work before it lands. Save your own effort for the thinking: planning, judgment, and anything ambiguous.

For heavy, exploratory work — reading lots of files, searching the codebase, digging through logs or docs — use a subagent instead of doing it in the main thread. Let it do the reading in its own context and report back just what it found, so the main conversation stays lean.
