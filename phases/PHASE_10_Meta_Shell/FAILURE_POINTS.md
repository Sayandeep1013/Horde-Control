# Phase 10 - Failure Points

## Predetermined

Restated from PLAN.md > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A save write interrupted mid-write | P3.14 introduces the project's first persistent file write; an interruption mid-write is exactly the failure mode a single JSON save file is vulnerable to without atomic-write discipline | Atomic write and corrupt-file fallback are required; the write path is designed so a partial write never overwrites the last complete file | Save atomicity test (scripted kill-mid-write) |
| Tester-probe pass conditions embedded in a build-task exit criterion rather than the dedicated external-playtest task (deferred finding P13, named example P3.13) | P3.13's own exit criterion in docs/29 is a tester-probe threshold sitting inside a build task | This phase records P3.13's own local check using internal testers only; the external-tester version of this criterion belongs to Slice Exit Criterion 4 at P3.18 | Reviewer confirms this phase's evidence for P3.13 names internal testers only |
| The Settlement test's crash clause (deferred finding P7b) cannot be checked without the save profile existing first | P3.4 (Phase 08) implemented Run-End Settlement including its crash clause, but the clause could not be checked against a real save file before P3.14 existed | This phase re-runs the Settlement test's crash clause specifically against the save profile P3.14 produces | Settlement test (crash clause), cross-checked against P3.14's save file |
| Onboarding compression removes a teaching wave, contradicting Author decision A1 | A compression implementation that skips a beat rather than shortening it would violate the onboarding compression rule | The compression setting is implemented as a duration/budget multiplier only, never a beat-skip | Onboarding compression test |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.
