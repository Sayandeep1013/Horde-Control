extends AudioStreamPlayer
class_name TowerCuePlayer

## P1.6 - Tower damage cue player.
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Tower Cue Player": "Tower damage audio plays on its own
## AudioStreamPlayer routed to a sixth bus, TowerCue, which sends to
## SFX_Priority and carries an AudioEffectPanner; before each play the
## panner's pan is set to clamp((Tower x - player x) / 960, -1, 1) ... It
## shares the 250 millisecond Tower-damage retrigger limit." Matches
## MASTER_SDLC.md > Provisional Values Register > Interfaces > "Threat
## feedback" row (C-TOWERCUE) and > Audio > "Retrigger limits" row.
##
## The AudioEffectPanner itself lives on the TowerCue bus in the bus layout
## resource (default_bus_layout.tres), not on this node - this script only
## sets that effect's `pan` property before each play, per docs/20's "the
## panner's pan is set" wording.
##
## Not PROCESS_MODE_ALWAYS. MASTER_SDLC.md > Global Simulation Authority
## names only the ducking node and the UI sound players as the
## PROCESS_MODE_ALWAYS set; this player is not in that list. Tower-damage
## cues fire from gameplay damage events, which do not occur while the
## simulation is paused, so pausing this node along with the gameplay root
## (the default PROCESS_MODE_INHERIT/PAUSABLE) is consistent with the rest
## of the audio system and does not need an exemption. It is intended to
## live under the gameplay root alongside the AudioPool; this implementer
## does not own scenes/main.tscn, so actually instancing it there is left to
## whichever task owns that scene (see p16_report.md).

const BUS_NAME := "TowerCue"
const PAN_DIVISOR := 960.0
const RETRIGGER_CUE_ID := "tower_damage"
const RETRIGGER_LIMIT_MS := 250.0

## Optional reference to the ducking node (src/audio/audio_ducking.gd),
## duck-typed via has_method exactly like audio_pool.gd's `ducking_node`.
var ducking_node: Node = null

var _limiter := CueRetriggerLimiter.new()


func _ready() -> void:
	bus = BUS_NAME
	finished.connect(_on_finished)


## docs/20's exact formula: clamp((Tower x - player x) / 960, -1, 1).
static func compute_pan(tower_x: float, player_x: float) -> float:
	return clampf((tower_x - player_x) / PAN_DIVISOR, -1.0, 1.0)


## Sets the TowerCue bus's AudioEffectPanner.pan. Returns false (and leaves
## the bus untouched) if the bus does not exist yet or its first effect is
## not an AudioEffectPanner - defensive against a bus layout that has not
## been applied yet, rather than erroring.
func _apply_pan(tower_x: float, player_x: float) -> bool:
	var bus_idx := AudioServer.get_bus_index(BUS_NAME)
	if bus_idx == -1:
		return false
	if AudioServer.get_bus_effect_count(bus_idx) == 0:
		return false
	var effect := AudioServer.get_bus_effect(bus_idx, 0)
	if not (effect is AudioEffectPanner):
		return false
	(effect as AudioEffectPanner).pan = compute_pan(tower_x, player_x)
	return true


## Attempts to play the Tower-damage cue, honouring the 250 ms retrigger
## limit (shared with any other caller using the same RETRIGGER_CUE_ID).
## Returns true if it played, false if the retrigger limit blocked it.
func play_tower_damage(cue_stream: AudioStream, tower_x: float, player_x: float, now_ms: float) -> bool:
	if not _limiter.try_trigger(RETRIGGER_CUE_ID, now_ms, RETRIGGER_LIMIT_MS):
		return false
	_apply_pan(tower_x, player_x)
	stream = cue_stream
	play()
	if ducking_node and ducking_node.has_method("notify_priority_started"):
		ducking_node.notify_priority_started()
	return true


func _on_finished() -> void:
	if ducking_node and ducking_node.has_method("notify_priority_stopped"):
		ducking_node.notify_priority_stopped()


## Exposes the limiter's bookkeeping for tests without needing real playback
## or wall-clock waits.
func get_limiter() -> CueRetriggerLimiter:
	return _limiter
