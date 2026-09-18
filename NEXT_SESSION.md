# Next Session — Start Here

**State on 2026-09-18.** Phase 00 built and reviewed. **Phase 01 built and taken through three review-gate iterations** (P0.4 8/10, P0.6 9/10, P0.7 8/10, phase execution 8/10 at iteration 3); its closure is the designer's decision, as Phase 00's still is. **Phase 02 (Technical Foundations) is in progress**, started at the author's direction. Read `phases/README.md` for the 20-phase table, then this file, then `phases/PHASE_02_Technical_Foundations/PLAN.md` and its EXECUTION_LOG for where the phase actually is.

---

## What exists now

- A Godot 4.7.1 project at `D:\Gamedev` that opens, runs, and exports a Windows release build. `project.godot` carries the pinned settings, the 16 collision layer names, 24 input actions, and a `BootCheck` autoload that asserts the engine is 4.7.1 — and fires inside the exported build, not just the editor.
- `tests/settings_check.gd` — the Settings check, asserting effective values and exact sets. Falsified ten ways; it fails on a rogue autoload, a rogue action, a rebound key, a mutated deadzone, a missing main scene, and a wrong features array.
- 31 design documents (`docs/00..30`). Five are drafts with real content (09, 11, 19, 20, 29); `docs/28` is at 1.0.0; the rest are stubs carrying their remit and Owns list.
- A pinned, locally built agent-to-Godot toolchain, and `phases/` holding the plan, log, ledger, failure points and review record for all 20 phases.
- **From Phase 01**: documents 00, 01 and 02 at 1.0.0; 54 typed `Resource` schemas under `src/data/` covering the eleven prototype contracts and their shared structs, with 11 sample resources; `tests/schema_check.gd`, whose required-field manifests are transcribed from the master and document 20 rather than derived from the scripts, and which has been falsified more than a dozen ways; gdUnit4 6.2.1 vendored at `addons/gdUnit4` and pinned in document 28 by version, file count and a SHA-256 over its contents, protected from line-ending drift by `.gitattributes`; and `tests/run_tests.ps1`, which distinguishes all four gdUnit4 exit codes and refuses to report a pass unless at least one test actually executed.
- **No gameplay code yet.** The engine spine is what Phase 02 is building now; it becomes visible in Phase 03.

## Phase 00's standing

Two review iterations scored it **6/10 against a bar of 8**, with four of six tasks below the task bar of 7. The substance was independently reproduced — pins verified live, the export clean, the Settings check falsified, the Known Limitations re-derived from source — but the phase did not reach its bar. **Closure is the designer's decision under the Gate Approval rule.** See `phases/PHASE_00_Environment_And_Connection/REVIEW.md` for both iterations and every score.

Open findings carried forward, with owners:

| ID | What | Owner |
| --- | --- | --- |
| F-06b | `delete_file` and `export_project` stay on `ask`, which does not intercept a subagent | Phase 01 entry — re-test |
| F-09 | The folder layout has no owning document; doc 23 is still a stub | P3.2b (consider re-owning earlier) |
| F-11 | The installed skill pack's gdUnit4 CLI guidance is wrong for the shipped version | P0.7 |
| F-12 | gdUnit4's upstream repository migrated orgs | P0.7 |

---

## Rules this project learned the hard way

Read `phases/LESSONS.md` in full. These cost real time:

1. **Prove a tooling config change before applying it.** Pinning both MCP servers to git specs looked right and killed both for a session.
2. **A passing test proves nothing until it fails against its own mechanism.** The Settings check passed on a project with its display block deleted.
3. **Never write "root cause" without an experiment.** One was written from reasoning, was wrong, and the rule derived from it would have misdirected Phase 03.
4. **Verify by reading the artifact back.** A tool logged "Save result: 0" while writing nothing.
5. **Spot-check delegated output.** Reading 3 of 26 generated files found a defect the agent's own report called complete.
6. **Cite only paths that exist in the repository.** A 1.0.0 document cited a session temp directory.

---

## Facts later phases must not re-derive

**gdUnit4 harness (P0.7).** Verified twice in the sandbox. Take the command from here, never from the skill pack, whose documented runner file and flag do not exist in v6.2.1 and which never mentions `--ignoreHeadlessMode`:

```
Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Run `--import` first. Four exit codes, and CI must distinguish all four: **0** pass, **100** assertion failure, **103** `--ignoreHeadlessMode` missing, **1** import pass not run. gdUnit4 v6.2.1, now at `godot-gdunit-labs/gdUnit4` — a human should eyeball that org migration before P0.7 pins it.

**Pin verification, at phase entry.** `tools/mcp/**` is gitignored and the MCP config stores a path, not a sha, so this is the only thing standing between the project and an unpinned server:

```
git -C tools/mcp/coding-solo   rev-parse HEAD   # 1209744fad78f3998f98c7394fd0f6ef50da5281
git -C tools/mcp/comprehensive rev-parse HEAD   # fcbc29e03297900b9a1fcc6c7cbae116fe9d532a
```

Both `tools/.gdignore` and `sandbox/.gdignore` must exist — they are not in the repository (they live inside gitignored directories), and without them the next export packs 11 MB of MCP server into the game.

**Permissions.** The `ask` gate does **not** intercept subagents. `run_project` is now confined to the sandbox by `GODOT_MCP_ALLOWED_DIRS`, which tool-enforces the sandbox-only rule for the whole `game_*` surface — verify it actually refuses `D:/Gamedev` at Phase 01 entry. `delete_file` remains reachable by a subagent unprompted, so every delegation prompt carries the no-delete, no-export constraint explicitly.

**Review pace (decision D83).** Code phases and gate phases: one critical agent per task plus a phase reviewer. Documentation-only phases: a spot-check. A narrowing is legitimate only when decided in advance and recorded — iteration 2 of Phase 00 cut the panel without recording it and the phase reviewer named five defects that slipped through.

---

## Phase 02 — where it stands

**Entry is done and recorded.** Both MCP pins verified against their shas, both `.gdignore` files present, gdUnit4 still 6.2.1 with its tree hash unchanged, and the full Phase 01 regression green (Settings check 0, Schema check 0, harness 0). Loop rule (a) satisfied: the placeholder "Carried lessons" section in `PHASE_02.../PLAN.md` is filled with eight patterns drawn from Phases 00 and 01, each naming the task it changes.

**Three decisions were taken at entry** rather than mid-flight, because a Phase 01 delegation was once written that contradicted a decision taken hours earlier:
- **D94** — the review gate groups Phase 02's seven tasks into four critical agents by coupled subsystem (P1.1+P1.2, P1.3+P1.5, P1.4, P1.6) plus the phase reviewer, who also covers P1.7. Five reviewers per iteration rather than eight. This narrows D83 and is recorded in advance, as D83 requires.
- **D95** — P1.6 implements from document 20's audio section; document 26 stays a stub and is not read.
- **D96** — the six entity caps change under the ordinary Provisional Default rule, with no separate sign-off gate. A Performance Fallback Ladder step 4 outcome still comes to the author, because that means the design is being revised rather than tuned.

**Dependency order**, which is why this phase cannot be parallelised far: P1.1 → P1.2 → P1.3 → P1.5 → P1.7, with P1.4 needing P1.1 and P1.2, and P1.6 needing only the project skeleton.

| Task | State |
| --- | --- |
| P1.1 SimClock, PauseAuthority, SimLoop, keyed RNG, banned-API check | delegated |
| P1.6 audio buses, ducking node, 32-voice AudioPool | delegated |
| P1.2 EventBus, EntityRegistry, CombatStats | waits on P1.1 |
| P1.3 pools and the six caps, gameplay root scene | waits on P1.2 |
| P1.4 debug overlay, Run Recorder, pseudo-localization | waits on P1.1, P1.2 |
| P1.5 collision layers, hitbox/hurtbox, death state | waits on P1.3 |
| P1.7 swarm stress test | waits on P1.3, P1.4, P1.5 |

**Two traps in this phase that are already known:**
1. `tests/settings_check.gd` asserts an **exact** autoload set. Registering SimClock and PauseAuthority breaks Phase 00's regression guard unless that check is updated — and it must stay falsifiable, since a version of it that could not fail was Phase 00's worst defect.
2. P1.7 must be measured on an **exported release build** on the reference machine with V-Sync off and 60 s of CSV frame data. An editor run is the fast path and is not the test. The plan names this as a predetermined failure point precisely because it is the tempting shortcut.

## Prompt — resuming Phase 02

```text
Act as the supervising orchestrator continuing this project in Phase 02.

Read first: D:\Gamedev\CLAUDE.md; phases/README.md; phases/LESSONS.md; this file;
then phases/PHASE_02_Technical_Foundations/PLAN.md, EXECUTION_LOG.md and LEDGER.md
to see which of P1.1-P1.7 are done, and Phase 01's REVIEW.md for what its gate found.

Re-run the phase-entry checks before continuing: both MCP pins, both .gdignore files,
the gdUnit4 tree hash against docs/28, and the Phase 01 regression (settings_check,
schema_check, and the gdUnit4 pass suite).

Continue the dependency chain from wherever EXECUTION_LOG.md says it stopped. Sonnet
subagents implement; every delegation prompt carries the no-delete, no-export,
sandbox-only constraints explicitly, because the ask gate does not intercept subagents.
Every acceptance test is falsified before its result is recorded - Phase 01 shipped
three checks that could not fail.

Review at the pace D94 fixes: four critical agents grouped by subsystem plus a phase
reviewer, on a TAGGED, FROZEN tree, with reviewers told to falsify against git archive
copies rather than the shared working directory. Do not edit anything while the gate
is open.

Send genuine design contradictions to the author as short multiple-choice questions.
Never write that a gate is passed, satisfied, or ready. Commit documentation and
implementation together.
```

## Prompt — Phase 01 (executed; kept for reference)

```text
Act as the supervising orchestrator continuing this project at Phase 01.

Read first: D:\Gamedev\CLAUDE.md; phases/README.md; phases/LESSONS.md; NEXT_SESSION.md;
then phases/PHASE_01_Contracts_Docs_Harness/PLAN.md, and Phase 00's EXECUTION_LOG.md,
FAILURE_POINTS.md, LEDGER.md and REVIEW.md. Loop rule (a) requires this before any
implementation, and Phase 01's PLAN.md still carries a placeholder "Carried lessons"
section: fill it from LESSONS.md and Phase 00's record before starting work.

AT PHASE ENTRY, before any task:
1. Run the pin verification above and confirm both shas and both .gdignore files.
2. Re-test F-06b: confirm from a Sonnet subagent whether the ask gate still fails to
   intercept it, and whether GODOT_MCP_ALLOWED_DIRS now makes run_project refuse
   D:/Gamedev. Record the result either way.
3. Confirm the Settings check still passes: it is the regression guard for everything
   Phase 00 pinned.

THE PHASE: P0.4 (documents 00, 01, 02 to stable), P0.6 (the eleven typed data-contract
Resource schemas under src/data/), P0.7 (the gdUnit4 harness, using the command above).

Follow the loop in phases/README.md. Log every action in EXECUTION_LOG.md and write the
FAILURE_POINTS row at the same moment as the LEDGER row - Phase 00 left both blank and a
reviewer called it a contradiction. Sonnet subagents write and implement; Opus runs the
critical agents and the phase reviewer.

Review pace for this phase, per decision D83: P0.4 is documentation - spot-check it
rather than convening a panel. P0.6 and P0.7 are code and get one critical agent each
plus a phase reviewer.

Send genuine design contradictions or scope changes to the author as short
multiple-choice questions. Never write that a gate is passed, satisfied, or ready.
Commit documentation and implementation together, and push to origin/main.
```

---

## What needs the author, and when

### Open from Phase 01, with nothing blocked on them

These are the ledger rows whose owner is the author. None blocks Phase 02; each is a judgement that is not an agent's to make. Full text in `phases/PHASE_01_Contracts_Docs_Harness/LEDGER.md`.

| Ledger row | The question | Why it is yours |
| --- | --- | --- |
| F01-02 | The `ask` permission gate does not intercept a subagent. `deny` is the only setting that does, and you declined it twice (D81, D84) to keep the export path. **Untested option**: a PreToolUse hook runs in the harness rather than the permission layer and might gate the two tools for subagents. Nobody has tried it | It changes the tooling configuration, and this project's own rule is to prove a tooling change before applying it |
| F01-06 | The moment-to-moment loop scale is the only one of four with no Provisional Values Register row. Add a row, or state that it is a reference frame the way Session Shape's ranges are | Either answer changes what the Register contains |
| F01-32 | The Schema check does not compare field types against document 20 - only that required fields exist and are populated. Build the type check, narrow the risk row's wording to match what the check does, or defer it with an owner | The phase's own top predetermined risk lists the Schema check as a type-mismatch detector, so this decides whether that row is accurate |
| F01-33 | `console_price_per_rank` is authored independently of the Economy Configuration's price formula that document 20 says it resolves from. Weaker than the merge-radius case that was fixed, and no drift is demonstrated | It is a contract-shape question, not a defect |
| F01-21 | No document under `docs/` has a Change Log section at all, so D86's "a Change Log row" was satisfied in the master instead. Should working documents carry their own Change Logs? | It sets a convention for all 31 documents |

### Still open from before Phase 01



- **Now, if you want it closed:** the Change Log row recording Phase 00's gate. Only the designer writes it; an agent may propose the text but must never write it into the Change Log. Proposed wording is in the Phase 00 execution log.
- **Phase 03 (P2.7):** the feel check. You play it with hand-placed enemies and record go or adjust. This cannot be delegated — it is the point of the prototype.
- **Phase 06 (P2.16):** five external testers who have never seen the game.
- **Phase 06 (P2.18):** the prototype gate rows.
- **Open question worth revisiting:** the skill pack was chosen partly because it covered gdUnit4 for P0.7. Finding F-11 falsified that justification. The pack is not harmful and the working commands are recorded independently, but the choice was never re-decided.

---

## The original prompts

Prompts 1 to 3 from the 2026-09-14 session (phase split, connection test, skill install) have all been executed. They are preserved in git history at commit `a2db130` if the original wording is ever needed.
