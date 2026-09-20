extends Node

## SimClock Autoload (MASTER_SDLC.md > Global Simulation Authority, paragraph
## 1; docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards
## > "SimLoop order"). PROCESS_MODE_PAUSABLE, so the engine itself stops
## calling _physics_process on this node while PauseAuthority pauses the
## tree -- no code here has to check the pause state; that is the whole
## point of leaning on the engine's own pause propagation instead of a
## manual flag.
##
## `now` is the one authoritative simulation-time value. Every gameplay
## deadline in this project is a value compared against SimClock.now, never
## a running countdown, and never driven by Timer, SceneTree.create_timer(),
## or SceneTree.create_tween() (master: "none of them scale with
## SimClock.time_scale or reliably pause with the gameplay tree").
##
## `time_scale` exists for later hit-stop/slow-motion effects (master >
## "Game-feel time effects"). It is always 1.0 in the prototype; nothing
## calls this yet. Its clamp is implemented now, not when the first effect
## lands, "so later effects cannot bypass it" (P1.1 task brief). Two
## distinct rules from the master are both time_scale rules, both enforced
## by the property setter below: time_scale itself never drops below 0.25,
## and any single reduction lasts at most 120 ms of REAL time
## (Time.get_ticks_msec, deliberately NOT SimClock.now -- a slow-motion
## window is bounded in wall-clock time even though it is slowing
## simulation time). Hit stop itself (AnimationPlayer.speed_scale, sprite
## effects, also capped at 120 ms) is a separate, purely visual mechanism
## the master explicitly says does not touch time_scale at all; it is not
## implemented here -- see the P1.1 evidence report's contradiction note.

const PHYSICS_STEP: float = 1.0 / 60.0 # pinned 60 Hz physics rate (docs/20 > Version)
const TIME_SCALE_MIN: float = 0.25
const TIME_SCALE_MAX: float = 1.0
const TIME_SCALE_REDUCTION_MAX_MS: float = 120.0

## Authoritative simulation time, in seconds, since this Node instance
## started (LEDGER F03-12: this file previously documented a
## `reset_for_test()` method here that exists nowhere in the codebase --
## corrected; no such method exists, and none is added by this correction).
## SimClock never resets its own `now` at runtime -- a test suite that needs
## a fresh clock value builds its own throwaway instance instead
## (`preload("res://src/core/sim_clock.gd").new()`) and injects it into
## whatever it is testing via that consumer's own `set_sim_clock_for_test()`
## seam, exactly as `tests/unit/leash_test.gd`, `tower_health_recovery_test.
## gd`, `spawn_ring_test.gd`, and others already do -- never by resetting
## the real Autoload singleton's `now` out from under every other system
## sharing it. Compare gameplay deadlines against this value directly; never
## subtract a countdown from it.
var now: float = 0.0

## Clamped to [TIME_SCALE_MIN, TIME_SCALE_MAX] by the setter below. Any
## reduction below TIME_SCALE_MAX auto-reverts to TIME_SCALE_MAX after at
## most TIME_SCALE_REDUCTION_MAX_MS of real time, even if nothing else ever
## sets it back -- the ceiling applies unconditionally, not only when a
## caller remembers to ask for it.
var time_scale: float = TIME_SCALE_MAX:
	set(value):
		time_scale = clampf(value, TIME_SCALE_MIN, TIME_SCALE_MAX)
		if is_equal_approx(time_scale, TIME_SCALE_MAX):
			_scale_revert_at_msec = -1
		else:
			_scale_revert_at_msec = Time.get_ticks_msec() + int(TIME_SCALE_REDUCTION_MAX_MS)

var _scale_revert_at_msec: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(_delta: float) -> void:
	if _scale_revert_at_msec >= 0 and Time.get_ticks_msec() >= _scale_revert_at_msec:
		time_scale = TIME_SCALE_MAX # goes through the setter above; also clears the deadline
	now += PHYSICS_STEP * time_scale


## Typed command (docs/20 > Communication, commands). Requests a temporary
## time_scale reduction for a future hit-stop/slow-motion effect. `scale`
## is clamped to [TIME_SCALE_MIN, TIME_SCALE_MAX]; `duration_ms` lets a
## caller ask for a SHORTER window than the 120 ms ceiling (never a longer
## one -- the property setter's own cap still applies underneath this).
func request_time_scale(scale: float, duration_ms: float = TIME_SCALE_REDUCTION_MAX_MS) -> void:
	time_scale = scale
	if not is_equal_approx(time_scale, TIME_SCALE_MAX):
		var clamped_duration: float = clampf(duration_ms, 0.0, TIME_SCALE_REDUCTION_MAX_MS)
		_scale_revert_at_msec = Time.get_ticks_msec() + int(clamped_duration)
