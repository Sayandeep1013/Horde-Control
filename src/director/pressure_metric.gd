extends RefCounted
class_name PressureMetric

## PressureMetric (P2.9 Wave Director & Pacing). docs/11_Wave_Director.md >
## "Pacing & Escalation Algorithm" in full -- Pressure Calculation,
## Escalation Trigger, De-escalation (bounded), Health quadrant, Overtime --
## which is this task's complete owning section; MASTER_SDLC.md >
## Provisional Values Register > "Pressure & Overtime" for every numeric
## default cited below by row.
##
## Pure RefCounted: no SimClock, no EntityRegistry, no scene tree. Matches
## this project's existing precedent for a stateless-computation-plus-small-
## state-machine helper the Wave Director owns but does not have to be one
## with (src/director/spawn_geometry.gd's own header: "no SimClock, no
## EntityRegistry, no scene tree -- so it is testable in total isolation").
## src/director/wave_director.gd is the only real caller; it resolves live
## enemies, Threat inputs, Capacity, and health fractions from the scene
## tree and pushes the result to the debug overlay -- this class only
## computes and remembers timer state.
##
## ## Scope: quadrant-aware selection is explicitly OUT (task brief; docs/11
## "Health quadrant": "the quadrant has no effect on encounter or spawn
## selection ... Document 11 may define quadrant-aware selection later; this
## remains an open question"). Per the P2.9 evidence report's answer to that
## open question (option (a): telemetry-only, no dormant hook), this class
## computes and exposes the quadrant as a plain value; nothing here or in
## wave_director.gd reads it to change spawn behaviour.

## Register > Pressure & Overtime > "Threat formula": "dps_i is the enemy's
## sheet DPS from its Attack profile ... (dps_i / 10)". NOT a schema field --
## docs/20 > Contract Field Semantics > "Pressure Metric constants" struct
## carries only the escalation/de-escalation timers, no threat or pressure
## reference constant -- so this is a cited script constant, matching
## wave_director.gd's own precedent for Register numbers the schema does not
## carry (e.g. HUNT_CAMERA_TOWER_PROXIMITY_PX).
const THREAT_DPS_REFERENCE: float = 10.0

## Register > Pressure & Overtime > "Pressure formula": "Threat / (Capacity
## x 20 s)". Same "no schema field" reasoning as above.
const PRESSURE_TIME_WINDOW_SECONDS: float = 20.0

## Register > Pressure & Overtime > "Pressure formula": "evaluated every
## 0.5 s". The cadence GATE lives in the caller (wave_director.gd decides
## WHEN to call update()); this constant is exposed so the caller does not
## also have to invent its own literal for the same Register row.
const EVAL_INTERVAL_SECONDS: float = 0.5

## Register > "Health quadrant": Pool Low below 40% max, shield excluded,
## for either pool. "Quadrant" names the 2x2 combination of the two pools'
## Low/Normal state, not a single flag.
enum HealthQuadrant { BOTH_NORMAL, PLAYER_LOW, TOWER_LOW, BOTH_LOW }

## Display labels are this file's OWN naming convention (NOT Register text --
## the Register never names these strings), chosen for an unambiguous debug
## overlay / test string per docs/11's four-way quadrant.
const _QUADRANT_LABEL: Dictionary = {
	HealthQuadrant.BOTH_NORMAL: "BothNormal",
	HealthQuadrant.PLAYER_LOW: "PlayerLow",
	HealthQuadrant.TOWER_LOW: "TowerLow",
	HealthQuadrant.BOTH_LOW: "BothLow",
}

# --- Escalation state: two independent timers -------------------------------
# (1) _below_threshold_since: how long Pressure has been continuously below
#     the escalation threshold (Register: "stays below 0.6 for 3 consecutive
#     seconds").
# (2) _last_escalation_time: the minimum-gap cooldown (Register: "at least
#     4 seconds must pass between escalations"). Deliberately independent of
#     (1) -- once (1) has been satisfied, only (2) gates a repeat firing
#     while Pressure remains continuously low; see update()'s own header.
var _below_threshold_since: float = -1.0
var _last_escalation_time: float = -INF

# --- De-escalation state: two independent timers ----------------------------
# (1) _de_escalation_start_time / the expiry compare against it (Register:
#     "expires on its own after 10 seconds regardless").
# (2) _de_escalation_lockout_until: the re-arm lockout (Register: "a 6 second
#     lockout before it can re-arm"). Deliberately independent of (1) -- a
#     lift via the pressure-below-1.2 branch and a lift via the 10-second
#     expiry branch both start the SAME lockout, but the lockout's own clock
#     runs independently of whichever branch started it.
var _de_escalation_active: bool = false
var _de_escalation_start_time: float = 0.0
var _de_escalation_lockout_until: float = -INF

var _last_pressure: float = 0.0


# =============================================================================
# Pure computation: Threat / Capacity / Pressure
# =============================================================================

## `entries`: Array of Dictionary {"current_hp": float, "intent_weight": float,
## "dps": float} -- one per living, non-dying enemy. The caller is
## responsible for filtering to living, non-dying enemies (EntityRegistry's
## own alive flag, per wave_director.gd's own "Completion counting" header:
## "the registry excludes anything Logical Death has already flagged
## not-alive") and for resolving each enemy's current HP, intent weight, and
## sheet DPS (from its Attack profile, via CombatStats.
## sheet_dps_from_attack_profile() -- never a measured/actual damage figure).
## Register > "Threat formula": intent_weight is 1.0 for Player Hunters,
## 1.25 for Tower Seekers, and 1.1 for Opportunists (transcribed into
## data/encounters/director_configuration.tres's
## pressure_metric_intent_weights field, read by the caller, not restated
## here as a literal).
static func compute_threat(entries: Array) -> float:
	var total: float = 0.0
	for entry in entries:
		var hp: float = float(entry.get("current_hp", 0.0))
		var weight: float = float(entry.get("intent_weight", 0.0))
		var dps: float = float(entry.get("dps", 0.0))
		total += hp * weight * (dps / THREAT_DPS_REFERENCE)
	return total


## Register > "Pressure formula": "Threat / (Capacity x 20 s) ... 0 with no
## enemies." threat <= 0 always yields 0.0 regardless of capacity (matches
## "0 with no enemies" literally: Threat is a sum of non-negative terms, so
## threat <= 0 means no living, non-dying enemy contributed anything).
##
## capacity <= 0 with threat > 0 (both the player and the Tower report zero
## sheet DPS while enemies are alive) is an edge case the Register does not
## name -- NO REGISTER ROW, escalated (see the P2.9 evidence report). This
## returns 0.0 rather than dividing by zero or propagating INF into the
## escalation state machine: an undefined Capacity should never itself force
## an escalation decision, and 0.0 is the same "nothing to report yet"
## sentinel CombatStats.get_sheet_dps() already uses for an unreported
## subject, so this keeps that convention rather than inventing a different
## one for the same "no real data yet" situation.
static func compute_pressure(threat: float, capacity: float) -> float:
	if threat <= 0.0:
		return 0.0
	if capacity <= 0.0:
		return 0.0
	return threat / (capacity * PRESSURE_TIME_WINDOW_SECONDS)


# =============================================================================
# Escalation / de-escalation state machine
# =============================================================================

## Advances both independent state machines by one evaluation tick (the
## caller gates cadence and the "combat wave, not teaching, outside the
## grace period" condition -- see wave_director.gd's
## `_process_pressure_metric()`) and returns the decision as
## {"escalate": bool, "de_escalating": bool, "pressure": float}.
##
## This method does NOT itself decide whether "the current encounter's next
## spawn group" exists or pull it forward -- wave_director.gd owns spawn
## groups, this class does not know what one is. Register: "If no spawn
## group remains, escalation does nothing." Interpreted literally as NO
## STATE CHANGE AT ALL (not merely "no visible effect"): the caller must call
## notify_escalated() only once it actually finds and starts a pending
## group, so a tick where none is available leaves the minimum-gap cooldown
## untouched and a group that frees up later can still fire the instant it
## exists, rather than being penalised by a cooldown for an escalation that
## never actually happened.
##
## `constants`: the Wave's own PressureMetricConstants if it authors one,
## else the Director Configuration's (docs/20: "absent fields fall back to
## the Director Configuration defaults" -- read here as "absent RESOURCE",
## whole-resource fallback, matching this schema system's existing
## nullable-Resource-field convention elsewhere (P0.6 convention 4) rather
## than a nonexistent per-field merge over a struct with no per-field
## nullability).
## `is_siege`: docs/11 > "Wave Runtime Model": "In a Siege the Escalation
## Trigger does nothing" (gates escalation); Register > "De-escalation":
## "never applies during a Siege" (gates de-escalation). Both read from the
## SAME flag since both clauses describe the same encounter-type condition.
## `is_overtime`: Register > "De-escalation": "... or Overtime." Overtime
## itself is not implemented by src/director/wave_director.gd yet (P2.8
## deliberately deferred it -- see that file's header, "Scope"), so the real
## caller always passes false today; this class's own test suite exercises
## `is_overtime = true` directly, since nothing here depends on Overtime
## actually existing.
func update(now: float, pressure: float, is_siege: bool, is_overtime: bool, constants: PressureMetricConstants) -> Dictionary:
	_last_pressure = pressure
	var escalate: bool = _update_escalation(now, pressure, is_siege, constants)
	var de_escalating: bool = _update_de_escalation(now, pressure, is_siege, is_overtime, constants)
	return {"escalate": escalate, "de_escalating": de_escalating, "pressure": pressure}


func _update_escalation(now: float, pressure: float, is_siege: bool, constants: PressureMetricConstants) -> bool:
	if is_siege:
		# "The Escalation Trigger does nothing" in a Siege -- no partial hold
		# credit accrues either, so leaving a Siege does not instantly grant
		# an escalation for time spent inside it.
		_below_threshold_since = -1.0
		return false
	if pressure >= constants.escalation_threshold:
		_below_threshold_since = -1.0
		return false
	if _below_threshold_since < 0.0:
		_below_threshold_since = now
	if (now - _below_threshold_since) < constants.escalation_hold_time_seconds:
		return false
	if (now - _last_escalation_time) < constants.minimum_gap_between_escalations_seconds:
		return false
	return true


## Called by the caller ONLY when an update() result with escalate == true
## actually started a spawn group this tick -- see update()'s own header.
func notify_escalated(now: float) -> void:
	_last_escalation_time = now


func _update_de_escalation(now: float, pressure: float, is_siege: bool, is_overtime: bool, constants: PressureMetricConstants) -> bool:
	if is_siege or is_overtime:
		# Suppressed, not "lifted": no re-arm lockout starts from this
		# transition. The Register's "never applies during a Siege or
		# Overtime" reads as a blanket exclusion, not as an early lift that
		# should then be penalised by its own cooldown; once the Siege or
		# Overtime ends, a fresh evaluation is free to trigger immediately if
		# Pressure still warrants it.
		_de_escalation_active = false
		return false
	if _de_escalation_active:
		var elapsed: float = now - _de_escalation_start_time
		if pressure < constants.de_escalation_lift_threshold or elapsed >= constants.de_escalation_expiry_seconds:
			_de_escalation_active = false
			_de_escalation_lockout_until = now + constants.re_arm_lockout_seconds
			return false
		return true
	if pressure > constants.de_escalation_threshold and now >= _de_escalation_lockout_until:
		_de_escalation_active = true
		_de_escalation_start_time = now
		return true
	return false


## Resets ONLY the escalation hold timer. Called by the caller when Pressure
## evaluation resumes after being paused (a teaching wave, or the post-draft
## grace period) -- see wave_director.gd's `_process_pressure_metric()`.
## Deliberately does not touch the minimum-gap cooldown or either
## de-escalation timer: those measure real elapsed sim time correctly
## whether or not evaluation ran in between (a longer-than-required gap is
## still a valid gap), but the hold timer would otherwise silently count
## paused/unobserved time as "held below threshold", which was never
## actually observed.
func reset_escalation_hold_timer() -> void:
	_below_threshold_since = -1.0


func is_de_escalation_active() -> bool:
	return _de_escalation_active


func get_last_pressure() -> float:
	return _last_pressure


# =============================================================================
# Health quadrant (telemetry only -- see class header, "Scope")
# =============================================================================

## `player_fraction` / `tower_fraction`: current / max HP, shield excluded
## (Register: "shield excluded"), already computed by the caller from
## whatever health component it resolved (DeathState for the player,
## TowerHealth for the Tower -- see wave_director.gd's
## `_compute_health_quadrant()`). NAN means "unresolved" (no live player, or
## no Tower wired) and is treated as Normal, never Low: an absent pool
## cannot honestly be reported Low without fabricating a reading.
static func compute_health_quadrant(player_fraction: float, tower_fraction: float, low_threshold: float) -> HealthQuadrant:
	var player_low: bool = not is_nan(player_fraction) and player_fraction < low_threshold
	var tower_low: bool = not is_nan(tower_fraction) and tower_fraction < low_threshold
	if player_low and tower_low:
		return HealthQuadrant.BOTH_LOW
	if player_low:
		return HealthQuadrant.PLAYER_LOW
	if tower_low:
		return HealthQuadrant.TOWER_LOW
	return HealthQuadrant.BOTH_NORMAL


static func quadrant_label(quadrant: HealthQuadrant) -> String:
	return String(_QUADRANT_LABEL.get(quadrant, "BothNormal"))


# =============================================================================
# Test-only introspection (never called by gameplay code)
# =============================================================================

func get_below_threshold_since_for_test() -> float:
	return _below_threshold_since


func get_last_escalation_time_for_test() -> float:
	return _last_escalation_time


func get_de_escalation_lockout_until_for_test() -> float:
	return _de_escalation_lockout_until
