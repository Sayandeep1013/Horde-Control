# Next Session — Start Here

**State on 2026-09-20.** Phases 00 and 01 built and reviewed; both closures are still the author's. Phase 02 is six of seven tasks complete (P1.7 deferred by D97, no gate by D98). **Phases 03, 04 and 05 are all built**: the prototype now has every system the Minimum Playable Prototype calls for. **No review gate has been convened for any of the three.** Read `phases/README.md`, then this file, then the Phase 03, 04 and 05 EXECUTION_LOGs and LEDGERs.


## What exists now

A Godot 4.7.1 project that opens, runs, exports, and **plays a full prototype run**. `scenes/prototype.tscn` is the scene a human launches.

- **The engine spine (Phase 02).** SimClock, PauseAuthority, the fifteen-step SimLoop — which now actually drives gameplay and resolves every hit through its sorted queue — keyed RNG, EventBus, EntityRegistry with a spatial hash, CombatStats, object pools with all six caps, the debug overlay, the Run Recorder, the seven-bus audio layout, and the hitbox/hurtbox/Logical-Visual-death framework.
- **The entities (Phase 03).** Player with input buffering and code-driven animation; arena and camera with lead, shake and clamping; the handgun with auto-targeting; the Tower with shield-then-health, its own weapon, interaction radius and evolution stages; three enemies, one per target intent, with attack slots, leash, the Opportunist event rule and the stuck ladder; the HUD and threat feedback. Art is stand-in CC0 (D101) and gets its own session (D102).
- **Pacing (Phase 04).** The Wave Director with both spawn rings, validation and directional weighting, the eight-wave prototype sequence, the stall check, Overtime with finishers, encounter priority and deferred recovery gaps, the encounter alive cap, the Siege volume formula computed from live Tower DPS, the Pressure Metric with escalation and bounded de-escalation, and pickups with magnet, raycast blocking, merge-at-cap, the Drop Table and the run economy.
- **Interfaces and run flow (Phase 05).** Six upgrades and two fallback cards with ranks shared across both channels; the Level-Up Draft; the Tower Console, which never pauses; the pause menu, settings menu and run-end screens; focus-loss pause with the `--no-focus-pause` harness flag.
- **The record.** 31 design documents, `phases/` holding plan, log, ledger, failure points and review for all 20 phases, and 88 test suites under `tests/unit`.


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

## Where the build actually is

**Every prototype system is built. None of it has been through a review gate, and the author has not played the assembled build since waves landed.**

The 2026-09-20 session built P2.9, P2.10, P2.11, P2.12, P2.13, P2.14, the deferred remainder of P2.8, and an integration pass, plus the core simulation debt D103 names. Roughly 230 new test cases. What it found matters more than what it built:

1. **Melee enemies could not damage the Tower at all** (F05-30). The attack cycle gates on the Register's `reach_or_range_px` — 20 px for a Tower Seeker — so an enemy stops and attacks out to 140 px from the Tower's centre, while its hitbox was hard-coded to `body_radius + 6 px` and could only overlap a 106 px Tower hurtbox within 126 px. A 14 px band where the AI ran its wind-up on schedule and the two `Area2D` shapes never touched. Found by parking one real Seeker at a distance its own code called in-range and counting landed hits: zero, over 240 physics ticks. **The dual-entity tension the whole prototype exists to prove could not occur**, and every test asserting the attack cycle stayed green throughout.
2. **Wave-spawned enemies had no Tower reference** (F05-23, F05-31). Only the three hand-placed enemies were wired. Fixed at the class, not the instance: an enemy with no explicit reference now resolves the Tower through the EntityRegistry `&"tower"` tag.
3. **Eight findings share one shape** — a correct, tested component nothing in the assembled scene ever calls. The integration pass closed them; the assertion suite that would keep them closed was not finished before an API session limit ended that agent (F05-33).

4. **The tuning instrument never put an enemy into the world** (F05-34). `teaching_siege_tuning_test.gd` built an `EntitySpawner` with no container paths, and `Pool` only parents an instance when it has a container - so every enemy it spawned sat outside the scene tree and outside the physics world, and the Tower read exactly 500.0/500.0 in every seed because nothing was there. Three T4 measurements had been taken through it. Found by halving the spawn interval and watching the result not move **at all**. The real game wires all four containers, so this was a broken instrument, not a broken game. Fixing it also took the suite from 200 orphans and 5 leaked-RID engine errors to zero.
5. **Six NodePath exports resolved to nothing** (F05-37), caught on the first run of the assembled-scene suite: `Console` and `RunFlowController` sit BESIDE `Main` and their paths were authored as if they sat inside it. The Console would never have had a Tower, player, upgrade catalogue or camera, and the run would never have ended - with no error and every component suite green.

**T4 is now tuned**, on a working instrument and derived rather than guessed: Seekers 16 at 3 s with a 1.5 s interval destroys the Tower in 5 of 5 seeds at 36-38 s of a 40 s wave, and a responding bot holds it at 100% in 5 of 5. Both halves of the Register's own target. Master at 0.8.10.

**Settled verification, on a still tree:** 594 test cases across 89 suites, 0 errors, 0 failures, 0 orphans, exit 0, engine-error guard clean; banned-API check exit 0; Settings check PASS; and a 600-frame headless run of `scenes/prototype.tscn` with no errors, no warnings and no leak lines - F03-30's standing leak is gone.


## Two things that bite, carried from Phase 02

1. **A green gdUnit4 summary is not evidence the engine was happy.** gdUnit4's error count excludes Godot engine errors — measured: five `push_error` calls gave `0 errors` at exit 0. That blind spot hid a real dangling-reference bug in `EntityRegistry` for the whole phase. `tests/run_tests.ps1` now reads the engine's channel and fails on it; **run tests through that script, not the raw gdUnit4 command**.
2. **Named acceptance tests keep being unable to catch their own defect class** — three times in two phases (F01-15, F02-02, F02-16). When a task's named test passes, that is not yet evidence; falsify it.

## Open, and whose

| Item | Whose |
| --- | --- |
| Phase 00 and Phase 01 closure | author |
| **No review gate has run for Phases 02, 03, 04 or 05.** D98 deferred it to one gate on the finished prototype. The prototype is now finished | author, to call |
| **T4's tuned numbers** (Seekers 16 @ 1.5 s), changed under the Register's own "tuned in P2.14" instruction. Worth the author's eye, since it is the first gameplay number an agent has moved | author, to confirm |
| **F04-16, a numeric inconsistency inside the master**: the Siege volume formula yields six accompanying Hunters where the same Register row states seven | author |
| **F04-20**: off-screen spawn markers unbuilt, because docs/11 never states what a marker renders | author |
| **Five contracts under-specify what implementation needs** (F03-25 enemy AI defaults, F04-01 Pressure constants, F04-08 pickup motion, F05-04 upgrade effect routing, F05-14 card name/icon). One decision, not five | author |
| Roughly twenty numbers escalated with `NO REGISTER ROW` across six tasks, each marked in place rather than invented | author |
| Interpretations awaiting a ruling: fallback Console price flat 90 vs 30×rank (F05-01); Shield Matrix capacity arriving filled (F05-02); finisher HP rounding (F04-17); sector width 360/7 vs 51.4 and the docs/19-vs-Register auto-fire conflict (F05-21); Pressure with zero capacity (F04-06) | author |
| F02-09 clustered query bound; F02-16 Ghost hit test blind spot; F03-41 the Tower's own death still emitting `enemy_died` | author |
| The art and asset session (D102) | author, before P2.16 |
| P2.16's five external testers, P2.17's grappling spike, P2.18's gate rows | author |


## Prompt — next session

```text
Act as the supervising orchestrator continuing this project.

Read first: D:\Gamedev\CLAUDE.md; phases/README.md; phases/LESSONS.md; this file;
then the Phase 03, 04 and 05 EXECUTION_LOG.md and LEDGER.md files. The ledgers are
the work list: F05-33 names the three items the interrupted integration agent did
not reach.

Re-run the phase-entry checks before anything else: both MCP pins, both .gdignore
files, the gdUnit4 tree hash against docs/28, and a full `tests\run_tests.ps1`
baseline so a later failure is attributable.

The prototype is functionally complete and verified on a still tree (594 cases,
0 failures, 0 orphans, clean headless run). Phases 02, 03, 04 and 05 have had
NO review gate; D98 deferred it to a single gate on the finished prototype,
and the prototype is now finished.

THEN the author's call: the prototype is functionally complete and no gate has
run for Phases 02-05. The author chose to stop at the prototype gate rather than
carry on into slice systems. P2.15 (the scripted bot acceptance pass) and the
deferred P1.7 swarm test are next, then the art session (D102), then P2.16.

Sonnet subagents implement; every delegation prompt carries the no-delete,
no-export, sandbox-only constraints explicitly, because the ask gate does not
intercept subagents. Every acceptance test is falsified before its result is
recorded. Send genuine design contradictions to the author as short
multiple-choice questions. Never write that a gate is passed, satisfied or ready.
Commit documentation and implementation together.
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
