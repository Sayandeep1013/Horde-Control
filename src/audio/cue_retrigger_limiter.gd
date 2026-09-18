extends RefCounted
class_name CueRetriggerLimiter

## P1.6 - retrigger-limit bookkeeping for damage-audio cues.
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Retrigger Limits": "the same damage-audio cue cannot restart
## faster than its retrigger limit, so a stun-locked or swarmed entity does
## not produce a buzz." Values match MASTER_SDLC.md > Provisional Values
## Register > Audio > "Retrigger limits" row: player damage 150 ms, Tower
## damage 250 ms.
##
## Clock-agnostic by design: every call is handed "now" in milliseconds by
## the caller rather than this class reading any clock itself. This keeps
## it usable from a gdUnit4 test with synthetic timestamps (no real
## waiting, no flakiness) and sidesteps picking a clock source on its own -
## `src/core/sim_clock.gd` is being written by another implementer
## concurrently, so this file does not depend on it existing. Once SimClock
## exists, gameplay call sites (player-damage and Tower-damage cue
## triggers) should pass `SimClock.now * 1000.0` so the limit is expressed
## in simulation time like every other gameplay deadline (Global Simulation
## Authority > Timing Rules); this file does not make that wiring choice
## for them.

var _last_trigger_ms: Dictionary = {} # cue_id: String -> float ms


## Returns true (and records the trigger at `now_ms`) if `cue_id` has not
## fired within `limit_ms` of `now_ms`. Returns false, and does not record
## anything, if it has - the caller should skip playing that cue this time.
func try_trigger(cue_id: String, now_ms: float, limit_ms: float) -> bool:
	if _last_trigger_ms.has(cue_id):
		var elapsed: float = now_ms - float(_last_trigger_ms[cue_id])
		if elapsed < limit_ms:
			return false
	_last_trigger_ms[cue_id] = now_ms
	return true


## Time in ms since `cue_id` last triggered, or -1.0 if it never has.
func time_since_last_trigger_ms(cue_id: String, now_ms: float) -> float:
	if not _last_trigger_ms.has(cue_id):
		return -1.0
	return now_ms - float(_last_trigger_ms[cue_id])


func reset(cue_id: String = "") -> void:
	if cue_id == "":
		_last_trigger_ms.clear()
	else:
		_last_trigger_ms.erase(cue_id)
