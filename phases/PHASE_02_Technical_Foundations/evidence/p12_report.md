# P1.2 Evidence Report — EventBus, EntityRegistry, CombatStats

Plan ID: P1.2 (`phases/PHASE_02_Technical_Foundations/PLAN.md` § "P1.2"). This
document records what was built, which document rule each part implements,
the registry's storage design and why it meets (and where it does not meet)
the query-cost bound, the full timing method with iteration counts and
spread, the clustered-versus-uniform result, the Settings check update and
its two falsifications, the acceptance test with commands/exit
codes/falsification log, and every contradiction or ambiguity found in the
source documents. It does not assert that any gate is passed, satisfied, or
ready — that is for reviewers and the author (CLAUDE.md; phases/README.md
loop rule (e)).

## Process note: skills invoked late

CLAUDE.md requires `godot-prompter:event-bus` and `godot-prompter:gdscript-
advanced` to be invoked **before** writing code. They were invoked only
after the implementation, the performance investigation, and most of the
falsification work were already done, once the report-writing step surfaced
the omission. Recorded here rather than silently reordering the narrative.
Both were then read in full and checked against the finished code (see
"GodotPrompter skills consulted" below); one idiom (typed Dictionaries) was
retrofitted as a direct result, and the rest of the finished design already
matched the skills' guidance by independent measurement rather than by
having read the skill first.

## GodotPrompter skills consulted

- **`event-bus`**: confirms the shape already built — a `Node` Autoload
  holding typed signals, producers emitting through it rather than calling
  consumer methods directly, typed parameters (not a raw `Dictionary`
  payload). Two points where this project's own rule goes further, or
  differs, than the skill's generic default, neither a conflict with a
  project document:
  - The skill's producer example calls `EventBus.signal_name.emit(...)`
    directly. `event_bus.gd` instead requires every emission to go through a
    typed `emit_*()` wrapper, because docs/20's own rule ("Timestamps come
    from SimClock.now, not wall clock", P1.2 task brief) has no equivalent
    in the skill's generic model — the wrapper is where that rule is
    enforced in code rather than left to every call site remembering it.
  - The skill recommends a `Resource` payload once a signal passes "more
    than two or three primitives." `tower_damaged` has four (`amount`,
    `new_health`, `new_shield`, `timestamp`). Kept as plain typed
    parameters anyway: docs/20's own worked example (`enemy_died`,
    `tower_damaged`, `draft_opened`) is itself a plain-signal convention
    with no payload Resource anywhere in the documents, and inventing one
    is not grounded in anything the documents ask for. Recorded as a
    judgment call, not resolved silently.
- **`gdscript-advanced`**: `entity_registry.gd`'s storage already used
  `PackedVector2Array`, `PackedByteArray`, `PackedInt64Array`, and
  `PackedInt32Array` (§2, "PackedArray* over generic Array ... skip Variant
  boxing") and `Vector2i` cell coordinates (§2, "Vector2i vs Vector2 ...
  30-40% faster") before this skill was read, arrived at by direct
  measurement (see "Timing method" below), not by having read the skill
  first. One idiom was missing and was added after reading the skill:
  §2 "Typed Dictionary access ... skip the Variant unbox per read" — applied
  to `_entity_to_slot`, `_grid`, and `_tag_bit`, each now `Dictionary[K, V]`
  rather than a bare `Dictionary`. Re-measured after the change: no
  meaningful timing difference at this scale (dictionary lookups are not
  the dominant cost once the tag bitmask replaced the earlier array scan —
  see "Timing method"), kept anyway since it is a real, applicable,
  zero-cost idiom the skill names directly. One genuine tension with a
  project document, not a document conflict but worth recording: §2 also
  says "Avoid singletons-as-autoloads when a static method on a class would
  do." `EventBus`/`EntityRegistry`/`CombatStats` are exactly such
  singletons, but MASTER_SDLC.md > Global Simulation Authority requires
  each to run at a **specific, different** `PROCESS_MODE` (`EventBus`
  `ALWAYS`; `EntityRegistry`/`CombatStats` `PAUSABLE`) so they start and
  stop with the simulation correctly — a property only a `Node` instance in
  the scene tree has, which a static class method cannot provide. The
  project's explicit requirement governs (CLAUDE.md: "Where a skill
  conflicts with docs/20 ... this project wins").

## What was built

| File | Document rule it implements |
| --- | --- |
| `src/core/event_bus.gd` | Autoload, `PROCESS_MODE_ALWAYS` (MASTER_SDLC.md > Global Simulation Authority, process-mode paragraph). Three typed signals — `enemy_died`, `tower_damaged`, `draft_opened` — matching docs/20 > "Communication, events" verbatim. Each has a typed `emit_*()` wrapper that stamps `SimClock.now`. |
| `src/core/entity_registry.gd` | Autoload, `PROCESS_MODE_PAUSABLE`. The read-only query interface docs/20 names (`get_enemies_in_radius(origin, radius)`), plus `get_entities_in_radius`, `get_entities_with_tag`, `get_live_enemy_count`, `get_entity_count`, `get_tags`, `is_registered` — all pull, no per-tick broadcast. Registration/position/liveness are typed commands (`register_entity`, `deregister_entity`, `update_position`, `set_entity_alive`), each validated and able to refuse. |
| `src/core/combat_stats.gd` | Autoload, `PROCESS_MODE_PAUSABLE`. `sheet_dps(damage, interval_seconds)` — the docs/20-named computation — plus convenience readers over the existing Attack Profile and Weapon Definition contracts, and a typed report/query pair (`report_sheet_dps`/`get_sheet_dps`) for the Pressure Metric's per-subject need (see "Contradictions," item 2). |
| `project.godot` | Autoload section only: added `EventBus`, `EntityRegistry`, `CombatStats` after the existing `BootCheck`/`SimClock`/`PauseAuthority` lines. |
| `tests/settings_check.gd` | `AUTOLOADS` widened to all six; `AUTOLOAD_PATHS` given three new entries. See "Settings check" below. |
| `tests/unit/event_bus_test.gd`, `entity_registry_test.gd`, `entity_registry_query_perf_test.gd`, `combat_stats_test.gd` | gdUnit4 suites — see "Acceptance test" and "Supplementary tests" below. |

## Commands, made real

Per the task brief ("Where you expose a command, make the validation real"),
every command below has at least one dedicated test asserting the refusal,
not just the happy path:

- `EntityRegistry.register_entity`: refuses `null`, refuses a duplicate
  registration of the same entity (`entity_registry_test.gd:
  test_register_refuses_null_and_duplicate`).
- `EntityRegistry.deregister_entity` / `update_position` / `set_entity_alive`:
  each refuses an entity that was never registered
  (`test_deregister_refuses_unknown_entity`,
  `test_update_position_refuses_unregistered_entity`,
  `test_set_entity_alive_refuses_unregistered_entity`).
- `CombatStats.report_sheet_dps`: refuses a negative DPS value and stores
  nothing (`combat_stats_test.gd: test_report_sheet_dps_refuses_negative_values`).

## Registry storage design and why it meets the bound (where it does)

Full design reasoning lives as comments at the top of `entity_registry.gd`
(read there for the complete version); summarized here with the measured
numbers behind each decision.

**Structure of arrays.** Every registered entity occupies one dense integer
"slot." Positions live in `PackedVector2Array`, liveness in
`PackedByteArray`, tag membership in a `PackedInt64Array` bitmask (one bit
per distinct tag, assigned the first time that tag is registered) — not
scattered across `Node2D.global_position` look-ups or a per-slot
`Array[StringName]` scanned with `.has()`. A freed slot is recycled from a
free list, not left as a permanent hole.

**Spatial hash grid.** `_grid: Dictionary[Vector2i, PackedInt32Array]`
buckets every slot by `floor(position / cell_size)` (default cell size
200px). A radius query visits only the cells overlapping the query circle's
bounding box, not every registered entity. Maintained incrementally
(register/move/deregister touch at most two cells), never rebuilt per query.

**The bitmask was not the first design, and the reason it changed is
measured, not guessed.** The first working version stored tags as
`Array[StringName]` per slot, filtered with `.has(tag)`. A timing probe
built to investigate the clustered case (below) showed the tag check alone
accounted for roughly half the per-candidate cost: the same clustered
300-entity query ran at 154.7us mean with the tag filter active and 79.5us
mean with no tag filter at all, same candidate set. Replacing the
`Array[StringName]`/`.has()` check with a `PackedInt64Array` bitmask and an
integer `AND` cut the clustered mean further, to ~72-90us across
measurement runs (see "Timing method"), and cut the uniform mean roughly in
half as well (28.4us → ~15-21us across runs). This is the single largest
performance change made in this task, and it was found by measuring, not by
reading a general performance guide first (the guide was read afterward —
see the process note above).

**Honest limit, stated plainly:** the grid's benefit depends on the queried
entities NOT all sharing the query's own neighbourhood. When they do — 300
enemies converging on the Tower, the Swarm Crush / Siege case this game will
actually produce — the grid degrades toward the same per-candidate cost a
brute-force scan pays, applied to nearly the full entity cap instead of a
small local subset. See "Clustered vs uniform" below for the actual number,
not a claim that the grid protects this case.

## Timing method

**Why a single call proves nothing.** `Time.get_ticks_usec()` has roughly
1us practical resolution, and a single 300-entity query is measured in the
tens of microseconds — comparable to or below scheduler noise on a shared
development machine. Every measurement below therefore:

1. Runs 300 **warm-up** calls (`WARMUP_ITERATIONS`), un-timed, so any
   one-time cost (cold memory, first-call GDScript VM warm-up) settles
   before anything is recorded.
2. Runs 5000 **measured** calls (`MEASURED_ITERATIONS`), each timed
   individually with `Time.get_ticks_usec()` immediately before and after.
3. Reports **mean, worst, best, standard deviation, p50, and p99** over the
   full 5000-sample set — never a single best-case or cherry-picked number.

**The bound is asserted against the MEAN**, stated explicitly as a mean, not
a worst case. Individual samples spike far above the mean occasionally
(observed worst-case samples up to ~700-3300us on isolated calls across
different runs, most likely OS scheduler jitter on a shared dev machine
rather than the algorithm — the same population's p99 stays two to three
orders of magnitude below those spikes). A worst-case assertion on this
population would be dominated by scheduler noise, not by the registry; a
mean over 5000 samples is not.

**Final measured figures** (`entity_registry_query_perf_test.gd`, seed
918273645, arena 4800×3200px per MASTER_SDLC.md > Provisional Values
Register > Arena & Camera, Tower at origin, query radius 480px per
MASTER_SDLC.md > Tower Targeting Rule):

| Distribution | Mean | Worst | Best | Stddev | p50 | p99 | n | Warmup |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Uniform (300 entities scattered across the full arena) | 15.43us | 124.00us | 14.00us | 2.30us | 15.00us | 22.00us | 5000 | 300 |
| Clustered (300 entities within 250px of the Tower, radius 480 query) | 71.42us | 155.00us | 69.00us | 4.48us | 71.00us | 94.00us | 5000 | 300 |

(Run-to-run variance is real and expected on a shared dev machine — repeated
runs during development measured uniform mean in the 15-21us range and
clustered mean in the 71-90us range; the table above is the final run
recorded alongside this report. Every run's uniform mean stayed at least
~2.3x under the 50us bound; no run's clustered mean came under it.)

## Clustered vs uniform — the load-bearing result

**Uniform meets the bound comfortably.** 15.43us mean against a 50us bound,
p99 at 22us — margin holds even at the tail, not just the mean.

**Clustered does not meet the bound, and this is not a defect in the grid
specifically.** 71.42us mean, about 1.4x over the bound. To find out whether
a better data structure would close this gap, a pure brute-force baseline
(`Node2D.global_position` read directly, no grid, no bitmask, implemented
standalone in a throwaway timing probe — see "How this was investigated"
below) was measured against the same clustered population: **66.4-69.0us
mean across runs — also over the bound, and close to the grid's own
number.** Tuning the grid's cell size (tried 200, 480, 1000px) moved the
clustered mean by at most a few percent; it did not close the gap, because
cell size only helps when the grid can exclude candidates, and in the fully
clustered case almost nothing gets excluded — the query has ~300 true
positives out of an entity cap of 300. Returning ~300 live `Node2D`
references through an interpreted GDScript loop, each with an alive check,
a tag check, and a distance check, costs what it costs; no spatial index
structure removes that cost when nearly the whole registered population is
a genuine positive.

**This is reported, not silently resolved.** The acceptance test
(`test_clustered_distribution_does_not_meet_the_bound`) does **not** assert
the 0.05ms bound for this case. It asserts (a) the result set is still
exactly correct under clustering (same wrong-set guard as the uniform test)
and (b) a much looser, explicitly-labeled sanity ceiling (1000us) that would
still catch a genuine regression. The 0.05ms gap on the realistic
full-convergence case is an **open finding for the author/reviewers**, named
here rather than hidden by only testing the easy case — see "Contradictions
and ambiguities," item 3, for the multiple-choice question this raises.

## How this was investigated

A throwaway timing probe (`tests/unit/_tmp_perf_probe.gd`, run via
`--headless --path . -s res://tests/unit/_tmp_perf_probe.gd`, moved out of
the repository with `mv` once its numbers were captured — never deleted, per
the project's no-delete constraint, and following the same pattern Phase 02
carried lesson / LEDGER F02-07 recorded for exactly this situation) was used
to:

1. Get first honest numbers for the initial (`Array[StringName]` tag)
   design: uniform 28.4us mean / clustered 154.4us mean — over budget on
   clustered by more than 3x.
2. Isolate the tag-check cost specifically (154.7us with the tag filter vs
   79.5us without, same candidate set) — the finding that motivated the
   bitmask redesign.
3. Compare the redesigned grid against a from-scratch brute-force baseline
   with no index at all, confirming the clustered cost is inherent to the
   workload rather than a fixable grid inefficiency (grid 154.1us vs brute
   45.8us on the *first* design; after the bitmask, grid ~72-90us vs brute
   ~66-69us — much closer, brute-force even edges ahead in some runs since
   it has zero indexing overhead once nearly everything is a true positive).
4. Sweep cell size (200/480/1000px) to confirm it does not close the
   clustered gap.

## Settings check

Widened `AUTOLOADS` to `["BootCheck", "SimClock", "PauseAuthority",
"EventBus", "EntityRegistry", "CombatStats"]` and added three entries to the
`AUTOLOAD_PATHS` manifest (`EventBus` → `res://src/core/event_bus.gd`,
`EntityRegistry` → `res://src/core/entity_registry.gd`, `CombatStats` →
`res://src/core/combat_stats.gd`). Nothing else in the file changed.

**Falsification 1 — rogue extra autoload.** Added
`RogueAutoload="*res://src/core/boot_check.gd"` to `project.godot`'s
`[autoload]` section, re-ran `--import`, then:

```
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://tests/settings_check.gd
```

Exit 1. Verbatim failure line:
`Settings check FAILURE: unexpected autoload/* entry(ies) present: ["RogueAutoload"]`

Restored `project.godot` to the golden six-autoload state, re-imported,
re-ran: exit 0, `Settings check: PASS (... 6 autoload(s) ...)`.

**Falsification 2 — missing expected autoload.** Removed the
`CombatStats="*res://src/core/combat_stats.gd"` line from `project.godot`,
re-imported, re-ran the same command. Exit 1. Verbatim failure line:
`Settings check FAILURE: expected autoload/* entry(ies) missing: ["CombatStats"]`

Restored, re-imported, re-ran: exit 0, PASS, 6 autoloads. `diff` against the
pre-falsification backup confirmed byte-identical restoration both times.

## Acceptance test — Registry query check

Suite: `tests/unit/entity_registry_query_perf_test.gd` (3 tests:
`test_uniform_distribution_meets_the_bound`,
`test_clustered_distribution_does_not_meet_the_bound`,
`test_wrong_set_guard_small_hand_checkable_scenario`). Supplementary
correctness coverage: `tests/unit/entity_registry_test.gd` (15 tests),
`tests/unit/event_bus_test.gd` (5 tests), `tests/unit/combat_stats_test.gd`
(10 tests).

Command:
```
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode
```

Result: exit 0, 90 test cases, 0 errors, 0 failures, 0 flaky, 0 skipped.
Registry query check lines from that run:
```
Registry query check (uniform): uniform: mean=15.43us worst=124.00us best=14.00us stddev=2.30us p50=15.00us p99=22.00us (n=5000, warmup=300)
Registry query check (clustered, informational only): clustered: mean=71.42us worst=155.00us best=69.00us stddev=4.48us p50=71.00us p99=94.00us (n=5000, warmup=300)
```

### Falsification 1 — make the query O(n) where it should be better

**First attempt (literal, no extra padding):** the grid bounding-box loop
was replaced with a full scan over every registered slot (`for slot in
_slot_entity.size(): ...`), ignoring the grid entirely. Re-ran the suite:
**stayed green.** Uniform mean rose from ~15us to 45.70us — still under the
50us bound, by a margin of about 4.3us. Recorded honestly as a near-miss
rather than silently strengthened without saying so: it shows the bound has
very little headroom against even a realistic, non-pathological O(n)
regression on this project's own reference machine, which is itself a
finding worth carrying forward, not something to paper over by picking a
guaranteed-red mutation from the start.

**Escalated mutation, to get an unambiguous red result** (per the task's
explicit requirement to confirm the check *does* go red): added a
deliberate O(n²) busy-loop per candidate on top of the O(n) scan (an inner
`for _other in _slot_entity.size(): _busy += _other` that does nothing but
waste time, clearly marked `FALSIFICATION MUTATION 1b` in the diff). Re-ran:

```
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/entity_registry_query_perf_test.gd --ignoreHeadlessMode
```

Exit 100. Verbatim failure:
```
Registry query check (uniform): uniform: mean=1608.06us worst=3308.00us best=1550.00us stddev=122.58us p50=1578.00us p99=2350.00us (n=5000, warmup=300)
res://tests/unit/entity_registry_query_perf_test.gd > test_uniform_distribution_meets_the_bound FAILED 8s 541ms
  Report:
  Expecting to be less than:
 50.000000 but was 1608.056600
Additional info:
 uniform: mean=1608.06us ... -- mean exceeds the 0.05 ms (50us) bound	at 'test_uniform_distribution_meets_the_bound' in res://tests/unit/entity_registry_query_perf_test.gd:200
```

Restored `entity_registry.gd` from a pre-falsification backup (`diff`
confirmed byte-identical), re-imported, re-ran the full `tests/unit` suite:
exit 0, 90/90 passing again, uniform mean back to 15.43us.

### Falsification 2 — break the radius filter so it returns everything

Replaced the query body with a scan over every registered slot that applies
the alive and tag filters but **drops the `distance_squared_to(...) <= r2`
check entirely** (marked `FALSIFICATION MUTATION 2` in the diff), so every
alive, correctly-tagged entity is returned regardless of distance from
`origin`.

```
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/entity_registry_query_perf_test.gd --ignoreHeadlessMode
```

Exit 100. Verbatim failure (from `test_uniform_distribution_meets_the_bound`,
which runs first in the file):
```
  Report:
  Expecting:
 13
 but was
 300
Additional info:
 uniform: registry returned 300 entities, an independent brute-force reference over the same 300 spawned nodes expects 13	at '_assert_matches_expected_set' in res://tests/unit/entity_registry_query_perf_test.gd:131
```

This is caught by the **wrong-set guard specifically** — the test's
independent, registry-internals-free reference computation
(`_expected_set()`, a plain loop over the Node2D references the test itself
created, with their known positions) — not by the timing assertion, which
runs afterward and never got the chance to (289 total assertion failures
recorded from this one test method: the size mismatch plus one
per-wrongly-included-entity check). Note: gdUnit4's CLI runner stopped
running the suite's remaining two tests after this failure — a documented,
previously-observed behavior (this phase's LEDGER, finding F02-08: "after a
test fails, gdUnit4's CLI runner stops executing the remaining tests in that
same suite file, while still running every other suite file fully"), not a
defect in this test file. The other two tests' own wrong-set protection is
independently exercised by their own runs in the green baseline before and
after this falsification, and by `entity_registry_test.gd`'s dedicated
`test_radius_query_returns_exactly_the_entities_inside_the_circle` and
`test_radius_query_filters_by_tag`, which cover the same property in
isolation from the 300-entity timing tests.

Restored `entity_registry.gd` from the pre-falsification backup (`diff`
confirmed byte-identical), re-imported, re-ran the full `tests/unit` suite:
exit 0, 90/90 passing again.

## A real bug this task's own tests caught

`CombatStats.sheet_dps_from_weapon()` was first implemented as
`sheet_dps(damage, engagement_rhythm.fire_rate_per_second)`, reusing the
`sheet_dps(damage, interval_seconds)` division. `fire_rate_per_second` is a
**rate** (shots per second), the inverse of `AttackProfile`'s
`cycle_or_tick_interval_seconds` (an **interval**, seconds per hit) —
dividing by a rate instead of multiplying by it is wrong. Caught immediately
by `combat_stats_test.gd`'s own coverage: a weapon with 10 damage at 2
shots/s computed as 5.0 DPS instead of the correct 20.0 DPS. Fixed by
computing `damage * fire_rate_per_second` directly instead of routing
through `sheet_dps()`, with a code comment recording why the two functions
are not the same one dressed up differently.

## Contradictions and ambiguities

Named here rather than silently resolved, per CLAUDE.md's rule that genuine
design contradictions go to the author.

1. **docs/20's "Communication, events" bullet names exactly three signals,
   introduced with "for example," not an exhaustive list.** The P1.2 task
   brief's phrasing ("`enemy_died`, `tower_damaged`, `draft_opened` and the
   others docs/20 names") reads as if docs/20 names more; it was re-read in
   full and no fourth signal name appears anywhere in the document.
   Implemented exactly the three named signals. Later phases add signals to
   `event_bus.gd` as the systems that own that state are built (P1.5
   death/hit systems, P2.x Wave Director/draft/Console systems), rather
   than this task inventing signal shapes — payload fields, exact meaning —
   for systems that do not exist yet and whose design is not this task's to
   set.
2. **docs/20's `CombatStats.sheet_dps()` example is written with zero
   arguments, and a zero-arg value cannot literally serve the documented
   use.** MASTER_SDLC.md's Pressure Metric needs the **player's** sheet DPS
   and the **Tower's** separately (Capacity formula) and a **different**
   sheet DPS per living enemy (Threat formula: "dps_i is the enemy's sheet
   DPS from its Attack profile") — three-plus distinct values, not one.
   Read as an illustrative method name, not a literal signature. Implemented
   as a pure computation (`sheet_dps(damage, interval_seconds)`) plus a
   per-subject report/query pair (`report_sheet_dps(subject, dps)` /
   `get_sheet_dps(subject)`) so later systems can publish "player", "tower",
   or an individual enemy's figure once they exist, without `CombatStats`
   needing to know what a player, Tower, or enemy even is at this phase.
3. **The Registry query check's 0.05ms bound does not state an entity
   distribution, and the realistic worst case does not meet it.** This is
   the single most load-bearing finding of this task (see "Clustered vs
   uniform" above): 300 enemies converging on the Tower — the Swarm Crush /
   Siege case, at the entity cap — measured at 71.42us mean against the
   50us bound, and neither the shipped grid+bitmask design nor a
   from-scratch brute-force baseline meets it for that case. This is a
   genuine, unresolved question for the author, not decided here:
   a. The 0.05ms bound applies to a typical/spread-out query (this task's
      reading, used for the acceptance assertion); the clustered case is
      accepted as a known, separately-tracked cost, not a bound violation.
   b. The 0.05ms bound must hold for the full-convergence case too, which
      means either the bound needs revising in the Provisional Values
      Register, or the game design needs a mitigation this task was not
      scoped to build (e.g., querying only a capped subset of candidates,
      or restructuring what Tower targeting/Wave-completion queries actually
      ask for during a Swarm Crush).
   c. Other (please specify).
4. **A real GDScript 4.7.1 pitfall, not a documents contradiction but worth
   recording for later implementers:** a strictly-typed `Array[StringName]`
   function parameter rejects an inline array literal (e.g. `[&"enemy"]`)
   at **runtime**, not compile time, when the callee is reached through a
   weakly-typed `Node` reference — exactly the pattern every test file in
   this project uses for an Autoload script under test (`var _registry:
   Node`, matching `pause_clock_test.gd`'s own `var _pause: Node`).
   Discovered building the P1.2 timing probe. Worked around by typing
   `register_entity`'s `tags` parameter as a bare `Array` (converted
   internally), matching the existing `KeyedRng.rng_for(parts: Array)`
   precedent for the same underlying reason. Any future Autoload command
   with an `Array[X]`-typed parameter should expect the same issue if a
   caller might hold it as `Node`.
5. **`EntityRegistry.set_entity_alive()` is an interpretation, not a directly
   sourced requirement.** docs/20's Logical Death rule says a `dead` flag is
   set on the entity itself; it does not say how (or whether) `EntityRegistry`
   learns about it. Since docs/20 also bans a per-tick broadcast, and P1.5
   (which owns Logical Death) has not been built yet, this task added
   `set_entity_alive()` as a typed command for whichever system sets that
   flag to call, so `get_enemies_in_radius` and `get_live_enemy_count` can
   exclude dead entities without polling arbitrary node properties. P1.5
   could reasonably choose a different channel; this is recorded so a
   reviewer can hold this design against docs/20 directly rather than
   assume it was sourced from a passage that does not exist.
