# Phase 02 - Failure Points

## Predetermined

Restated from PLAN.md > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Godot pause traps (SceneTreeTimer, Tween, PROCESS_MODE_ALWAYS leakage) per the Risk Register | `get_tree().create_timer()` and `create_tween()` are the default GDScript idiom for timing, and `PROCESS_MODE_ALWAYS` is a single inspector toggle that silently exempts a node from pause if it lands on a gameplay-root descendant | SimClock and PauseAuthority Autoloads are the only timing and pause writers (MASTER_SDLC.md > Risk Register; > Global Simulation Authority); P1.1's own exit criterion is a grep check banning the two calls under the gameplay root | The P1.1 grep check itself; a manual check during P1.3-P1.7 that nothing under Entities/Projectiles/Pickups/Effects sets PROCESS_MODE_ALWAYS |
| Per-node physics cost of 300 CharacterBody2D enemies exceeding budget, with the Performance Fallback Ladder as the pre-agreed escape | MASTER_SDLC.md > Risk Register: per-node physics overhead in Godot is known to be the limiting factor for survivors-like enemy counts, and it has not been measured on this project yet | P1.7 runs last in this phase, after pools, the recorder, and hitboxes exist, and steps through docs/20 > Performance Fallback Ladder in order, adopting only the first step that passes | Swarm performance test on the reference machine, exported release build, V-Sync off, 60 s CSV log |
| NavigationServer2D asynchronous resolution (the prototype uses no NavigationAgent2D) | A `NavigationAgent2D` node looks like the natural way to move placeholder enemies toward the player or Tower, but its path resolution is asynchronous and can resolve on a different tick than issued, breaking the fixed per-tick resolution order Determinism promises | P1.5 and P1.7 placeholder enemy movement moves directly toward a point with no `NavigationAgent2D` | Critical agent checks P1.5 and P1.7 scripts and scenes for any `NavigationAgent2D` node or `NavigationServer2D` call |
| A pool that leaks monitoring flags or collision layers on acquire | docs/20 > Logical Death requires `Pool.acquire()` to restore every layer, mask, and monitoring flag Logical Death changed; a pool that restores only some of them reintroduces ghost-hit bugs on reuse | P1.3's pool restores every flag Logical Death changes in one acquire() path, and P1.5 is reviewed against the same list | Pool unit check; Ghost hit test exercises a reused, previously-dead instance |
| The Run Recorder schema drifting from the defined columns | docs/20 > Run Recorder defines exact column lists for `ticks.csv` and `events.csv`; adding a convenience column or renaming one during P1.4 drifts the schema with no obvious failure until a later phase reads the CSV | P1.4 implements the header row directly from docs/20's Run Recorder column list, not from memory | Recorder schema check: the scripted run's written headers diffed against the schema docs/20 defines |
| The swarm test being measured on the wrong machine or in the editor instead of an exported release build with vsync off | Running the stress scene directly in the Godot editor is the fastest iteration loop, and it is easy to record that result instead of re-measuring after an export | P1.7 explicitly requires an exported release build on the reference machine, V-Sync off; EXECUTION_LOG.md records the build type and machine for the recorded result | Reviewer checks that the recorded result's metadata names an exported release build and the reference machine, not an editor run |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.
