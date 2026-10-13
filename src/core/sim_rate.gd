class_name SimRate
extends RefCounted

## PT-PHONE (D395): the simulation tick rate and the rules that count ticks.
##
## The game is authored at 60 Hz (docs/20 > Version, SimClock.PHYSICS_STEP's old value). On a phone the
## project runs physics at 30 Hz (project.godot `physics/common/physics_ticks_per_second.mobile`)
## so a slow frame costs half the simulation and the catch-up spiral is shorter. Every gameplay
## deadline already compares against SimClock.now (seconds), so only the rules that COUNT ticks
## need translating, and they all go through this class:
##
## - `ticks(n60)`: "n ticks at 60 Hz" -> the same wall time in current ticks (at least 1). The
##   think / sync / retry intervals of the swarm LOD use it.
## - `per_tick(budget60)`: a per-tick budget (spawns, hit effects) -> the budget for a tick of the
##   current rate, so the per-SECOND budget is unchanged (30 Hz ticks are twice as long, so a tick
##   gets twice the budget).
## - `step()`: the length of one tick in seconds.
##
## Dev flag `--sim-hz=N` (any user arg, any scene) forces the rate on a desktop run so the 30 Hz
## behaviour can be tested and measured without a phone; `--sim-max-steps=N` caps the catch-up.

const REFERENCE_HZ: int = 60


static func hz() -> int:
	return maxi(1, Engine.physics_ticks_per_second)


static func step() -> float:
	return 1.0 / float(hz())


## `ticks_at_60` ticks of the 60 Hz design, as ticks of the running rate (never below 1).
static func ticks(ticks_at_60: int) -> int:
	return maxi(1, roundi(float(ticks_at_60) * float(hz()) / float(REFERENCE_HZ)))


## A budget stated per 60 Hz tick, as the budget of one running tick (never below 1).
static func per_tick(budget_at_60: int) -> int:
	return maxi(1, roundi(float(budget_at_60) * float(REFERENCE_HZ) / float(hz())))


## The next due time of a repeating timer (weapon cooldown, ability interval, attack cycle).
## At the 60 Hz design rate this is exactly `now + interval`, bit for bit what the game always did.
## At any other rate that formula would stretch the period by up to one (longer) tick every shot,
## so the timer is carried instead: when it fires on its first chance (`now` less than one tick
## past `prev_due`) the new due time is `prev_due + interval`, with `interval` rounded up to the
## 60 Hz grid first, which is the period the 60 Hz build effectively had. A 0.25 s weapon fires
## every 0.25 s at 30 Hz and not every 0.267 s. A timer that was ready long before it fired
## (waiting for a target) restarts from `now`, as before.
static func reschedule(prev_due: float, now: float, interval: float) -> float:
	if hz() == REFERENCE_HZ:
		return now + interval
	var period: float = ceilf(interval * float(REFERENCE_HZ) - 0.001) / float(REFERENCE_HZ)
	var late: float = now - prev_due
	if late >= 0.0 and late < step() * 1.01:
		return prev_due + period
	return now + period


## Applies the dev flags. Called once from the BootCheck autoload.
static func apply_cmdline(user_args: PackedStringArray) -> void:
	for a: String in user_args:
		if a.begins_with("--sim-hz="):
			var requested: int = int(a.trim_prefix("--sim-hz="))
			if requested >= 10 and requested <= 240:
				Engine.physics_ticks_per_second = requested
		elif a.begins_with("--sim-max-steps="):
			var steps: int = int(a.trim_prefix("--sim-max-steps="))
			if steps >= 1:
				Engine.max_physics_steps_per_frame = steps
