extends Node
class_name AudioDucking

## P1.6 - dedicated PROCESS_MODE_ALWAYS ducking node.
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Dynamic Ducking". Values match MASTER_SDLC.md > Provisional
## Values Register > Audio > "Buses" row: SFX & Ambience duck 9 dB (50 ms
## attack, 300 ms release); Music ducks 6 dB, floored at -18 dB.
##
## CLOCK DECISION (see p16_report.md for the full write-up): this node
## ramps on its own per-frame `_process(delta)` - the engine's ordinary,
## real frame delta - not on SimClock. MASTER_SDLC.md > Global Simulation
## Authority explicitly groups this node with the UI CanvasLayer and the UI
## sound players as the PROCESS_MODE_ALWAYS set, and separately states that
## "pure UI, which is not bound by SimClock" may use SceneTree
## timers/tweens/its own per-frame delta. Ducking is presentation (a mix
## ramp), not a gameplay deadline (combat, spawning, hazards, telegraphs,
## pickups, upgrade timers, blackout timers, encounter progression - the
## Timing Rules list this node's job is not on), so the same exemption
## applies. Concretely: SimClock is PROCESS_MODE_PAUSABLE and stops
## advancing exactly when this node most needs to keep ramping (mid-pause,
## with a priority sound still resolving), so using it here would be
## self-defeating even if it were available; and `src/core/sim_clock.gd` is
## being written by another implementer concurrently, so this file does not
## import or reference it, to avoid a load-order dependency on a script that
## does not exist yet in this working tree. If a later revision wants
## ducking to also respect SimClock.time_scale (always 1.0 in the
## prototype - Hit-stop/slow motion row, Provisional Values Register), that
## is a deliberate design change, not something this file decides
## unilaterally; it should be recorded in the phase LEDGER.
##
## DETECTION DECISION (also in p16_report.md, flagged as an ambiguity in
## docs/20 rather than resolved silently): docs/20 says "When a sound plays
## on SFX_Priority" but does not say how that is detected. AudioServer
## exposes no "is this bus currently outputting audio" query - only a
## running peak-volume meter, which is a poor and untestable proxy (silence
## vs. near-silence vs. meter smoothing lag). This node is instead driven by
## an explicit start/stop notification pair
## (`notify_priority_started`/`notify_priority_stopped`) that any
## SFX_Priority-routed player calls - `audio_pool.gd`'s priority voices and
## `tower_cue_player.gd` both call it. A reference-counted "how many
## priority sounds are active right now" integer, not a bus query.

const DUCK_SFX_AMBIENCE_DB := 9.0
const DUCK_MUSIC_DB := 6.0
const MUSIC_FLOOR_DB := -18.0
const ATTACK_SECONDS := 0.05
const RELEASE_SECONDS := 0.3

const BUS_SFX := "SFX"
const BUS_AMBIENCE := "Ambience"
const BUS_MUSIC := "Music"

var _active_priority_count: int = 0

var _base_sfx_db: float = 0.0
var _base_ambience_db: float = 0.0
var _base_music_db: float = 0.0

var _ramp_t: float = 0.0 # 0.0 = fully unducked, 1.0 = fully ducked

var _last_sfx_db: float = 0.0
var _last_ambience_db: float = 0.0
var _last_music_db: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_base_volumes_from_audio_server()


func _process(delta: float) -> void:
	step(delta)


## Called by any player routed to SFX_Priority (or TowerCue, which sends to
## it) immediately before/at the moment it starts playing.
func notify_priority_started() -> void:
	_active_priority_count += 1


## Called when that same sound stops playing, whether by finishing normally
## or by being stolen (see audio_pool.gd's stealing paths).
func notify_priority_stopped() -> void:
	_active_priority_count = maxi(0, _active_priority_count - 1)


## Advances the ramp by `delta` seconds toward fully-ducked (if any priority
## sound is active) or fully-unducked (if none are), then applies the
## result to the real audio buses. Split out from `_process` so a test can
## drive it with synthetic deltas instead of waiting on real frames.
func step(delta: float) -> void:
	var target_t := 1.0 if _active_priority_count > 0 else 0.0
	if _ramp_t != target_t:
		if target_t > _ramp_t:
			var attack_rate := 1.0 / ATTACK_SECONDS
			_ramp_t = minf(_ramp_t + attack_rate * delta, target_t)
		else:
			var release_rate := 1.0 / RELEASE_SECONDS
			_ramp_t = maxf(_ramp_t - release_rate * delta, target_t)
	_apply_ramp()


func _capture_base_volumes_from_audio_server() -> void:
	_base_sfx_db = _get_bus_db(BUS_SFX)
	_base_ambience_db = _get_bus_db(BUS_AMBIENCE)
	_base_music_db = _get_bus_db(BUS_MUSIC)


## Lets a test (or a future settings/volume system) set the base volumes
## this node ducks from/to, without needing "SFX"/"Ambience"/"Music" buses
## to exist in the live AudioServer - keeps ramp-math tests hermetic and
## independent of global engine state other tests might also be touching.
func configure_base_volumes_for_test(sfx_db: float, ambience_db: float, music_db: float) -> void:
	_base_sfx_db = sfx_db
	_base_ambience_db = ambience_db
	_base_music_db = music_db


func _get_bus_db(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(idx)


func _apply_ramp() -> void:
	_last_sfx_db = _base_sfx_db - DUCK_SFX_AMBIENCE_DB * _ramp_t
	_last_ambience_db = _base_ambience_db - DUCK_SFX_AMBIENCE_DB * _ramp_t
	_last_music_db = maxf(_base_music_db - DUCK_MUSIC_DB * _ramp_t, MUSIC_FLOOR_DB)
	_set_bus_db(BUS_SFX, _last_sfx_db)
	_set_bus_db(BUS_AMBIENCE, _last_ambience_db)
	_set_bus_db(BUS_MUSIC, _last_music_db)


func _set_bus_db(bus_name: String, value_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, value_db)


func get_ramp_t() -> float:
	return _ramp_t


func get_active_priority_count() -> int:
	return _active_priority_count


func get_last_sfx_db() -> float:
	return _last_sfx_db


func get_last_ambience_db() -> float:
	return _last_ambience_db


func get_last_music_db() -> float:
	return _last_music_db
