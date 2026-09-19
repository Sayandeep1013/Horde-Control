extends RefCounted
class_name RunTerminationRecorder

## RunTerminationRecorder (P2.4). MASTER_SDLC.md > "Edge Cases and Failure
## States" > "Run Termination": "Player and Tower reach zero on the same
## frame -> Deterministic order from the Determinism rule: the Tower's
## depletion resolves first. Run ends, cause recorded as Tower." Also >
## "Tower Specific": docs/20_Technical_Architecture.md > "SimLoop order",
## step 8: "death resolution in order Tower, bosses, player, other
## enemies."
##
## ## Why this lives in src/tower/ instead of SimLoop step 8
## docs/20's own SimLoop order names step 8 ("death resolution in order
## Tower, bosses, player, other enemies") as the real integration point, and
## src/core/sim_loop.gd's _step_08_death_resolution() is exactly that hook
## -- but it is still an empty stub today ("# P1.5 death_state.gd.", not
## actually implemented), and src/core/ is outside this task's write scope
## (P2.4 HARD CONSTRAINTS). This class is this task's self-contained,
## independently testable implementation of the documented category order,
## built so scenes/tower.tscn has a real, falsifiable answer to "who gets
## credited when the Tower and something else die on the same tick" without
## editing a forbidden file. Wiring this AS (or into) SimLoop's actual step
## 8 body is left to whichever future task next owns src/core/sim_loop.gd --
## named here rather than silently left unstated, per this task's own
## instruction to name contradictions rather than resolve them silently.
##
## ## Design: order-independent input, not "whoever calls first wins"
## record_tick_deaths() takes the SET of categories that reached zero on a
## given tick (order the caller supplies them in does not matter -- see
## RESOLUTION_ORDER below) rather than relying on which of two calls
## happens to run first in a test or in real code. This directly answers
## the acceptance test's own falsification instruction: "try reversing the
## resolution order ... confirm the test distinguishes them" -- reversing
## which entity is damaged FIRST in calling code must not change the
## recorded cause, only the CATEGORY membership of what reached zero on a
## given tick should. A "one tick apart" case is handled by _run_ended
## latching after the first non-empty call: a later tick's death cannot
## retroactively change an already-recorded cause (Run Termination table:
## "the current run immediately ends" the instant either pool reaches
## zero -- there is no second chance for a different cause to compete).
##
## Only Tower and Player deaths end a run on their own (Run Termination
## table only names those two pools); a boss or an ordinary enemy reaching
## zero never ends the run by itself (a same-tick boss-and-player death is
## its own edge case per the Boss edge case test row: "the boss kill is
## credited ... and the run still fails" -- the cause there is still the
## player, not the boss). RESOLUTION_ORDER nonetheless carries all four
## docs/20 category names, both for future reuse once bosses exist and so
## the ordering constant is a literal transcription of the cited sentence,
## not a narrowed paraphrase of it.

enum Category { TOWER, BOSS, PLAYER, ENEMY }

## Verbatim transcription of docs/20 > "SimLoop order" step 8's stated
## order: "Tower, bosses, player, other enemies".
const RESOLUTION_ORDER: Array = [Category.TOWER, Category.BOSS, Category.PLAYER, Category.ENEMY]

## Only these two categories can end a run on their own (Run Termination
## table names only the player's and the Tower's pools).
const RUN_ENDING_CATEGORIES: Array = [Category.TOWER, Category.PLAYER]

var _run_ended: bool = false
var _cause: Variant = null # a Category, or null while the run has not ended
var _ended_at_sim_time: float = -1.0


func is_run_ended() -> bool:
	return _run_ended


## The Category that ended the run, or null if it has not ended yet.
func get_cause() -> Variant:
	return _cause


func get_ended_at_sim_time() -> float:
	return _ended_at_sim_time


## Typed command. `categories_reached_zero_this_tick` is every Category
## that reached zero HP on this SAME tick (any order; a plain Array so a
## caller can pass e.g. [Category.PLAYER, Category.TOWER] or
## [Category.TOWER, Category.PLAYER] and get the identical result -- see
## header). `sim_time` should be SimClock.now at the tick being resolved.
##
## Returns the newly-recorded cause (a Category) the first time this is
## called with at least one run-ending category present, or null on every
## call after that (the run already ended; a later tick cannot change the
## recorded cause) and on any call whose set contains no run-ending
## category at all (e.g. only ordinary enemies died this tick).
func record_tick_deaths(categories_reached_zero_this_tick: Array, sim_time: float) -> Variant:
	if _run_ended:
		return null
	var present: Dictionary = {}
	for c in categories_reached_zero_this_tick:
		present[c] = true
	var any_run_ending: bool = false
	for c in RUN_ENDING_CATEGORIES:
		if present.has(c):
			any_run_ending = true
			break
	if not any_run_ending:
		return null
	for candidate in RESOLUTION_ORDER:
		if present.has(candidate) and RUN_ENDING_CATEGORIES.has(candidate):
			_run_ended = true
			_cause = candidate
			_ended_at_sim_time = sim_time
			return candidate
	return null # unreachable: any_run_ending guarantees a RUN_ENDING_CATEGORIES hit


## Test-only teardown, matching this project's set_*_for_test()/clear_*_
## for_test() naming convention (e.g. pool.gd's clear_for_test()). Never
## called by gameplay code.
func reset_for_test() -> void:
	_run_ended = false
	_cause = null
	_ended_at_sim_time = -1.0
