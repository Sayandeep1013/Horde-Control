# Phase 00 - Ledger

Every finding raised against this phase, carried across review iterations until closed.

Severities: Blocker, Major, Minor.
Statuses: open; fixed; deferred (with owner); withdrawn.

| ID | Finding | Severity | Raised by | Status | Evidence | Resolution |
| --- | --- | --- | --- | --- | --- | --- |
| F-01 | The 26 stubs P0.3 created omitted the trailing two-space line break after `**Version:**`, so the Version and Status lines collapse onto one line when rendered. The five pre-existing drafts (09, 11, 19, 20, 29) carry that break, so the new stubs were inconsistent with the convention already in the repository | Minor | Orchestrator, spot-check of P0.3's output before the review gate | fixed | Before: 26 of 31 files in `docs/` lacked the break, and the 5 that carried it were exactly the pre-existing drafts. After: 31 of 31 carry it and 0 lack it; `git diff --stat` shows 26 files changed with 26 insertions and 26 deletions, one line each, so nothing else was touched; `cat -A` confirms the line now ends `**Version:** 0.1.0  $` | Scripted `sed` pass over only the files missing the break, appending two spaces to the Version line. The Status line needs no break because a blank line already follows it |
