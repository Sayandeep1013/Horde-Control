extends Node2D
class_name AudioPool

## P1.6 - 32-voice AudioPool with priority stealing.
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Voice Limit" (binding for P1.6 under decision D95, taken at
## Phase 02 entry, even though MASTER_SDLC.md's task table names document 26,
## which is still a stub). Values match MASTER_SDLC.md > Provisional Values
## Register > Audio > "AudioPool" row: 32 AudioStreamPlayer2D voices, up to
## 8 priority voices, steal lowest-priority then oldest, and once 8 priority
## slots are full a new priority sound steals the oldest priority voice.
##
## Intended to live under the gameplay root (a plain child scene node, not
## an autoload) so its voices inherit PROCESS_MODE_PAUSABLE and pause with
## the tree, per MASTER_SDLC.md > Global Simulation Authority: "the AudioPool
## lives under the gameplay root so it pauses with the tree" and "Nothing
## under the gameplay root may set PROCESS_MODE_ALWAYS." This script never
## sets process_mode, so it inherits whatever its parent (the gameplay root)
## uses. This implementer does not own scenes/main.tscn or project.godot
## (concurrent P1.3/P1.1 work), so actually instancing this under the
## gameplay root, and wiring `ducking_node` below, is left to whichever task
## owns that scene - see phases/PHASE_02_Technical_Foundations/evidence/
## p16_report.md.
##
## UI sounds do not draw from this pool (docs/20: "UI sounds do not draw
## from this pool; they play on their own PROCESS_MODE_ALWAYS players").
##
## Godot exposes no voice age, so this pool tracks it itself with a
## monotonically increasing allocation serial (`_alloc_serial`) rather than
## any wall-clock or SimClock read - "oldest" means "allocated longest ago in
## allocation order", which is exactly what the stealing rule needs and does
## not require picking a clock.

const VOICE_COUNT := 32
const MAX_PRIORITY_VOICES := 8

class _Voice:
	var player: AudioStreamPlayer2D
	var in_use: bool = false
	var priority: int = 0
	var is_priority_voice: bool = false
	var alloc_serial: int = -1

## Optional reference to the ducking node (src/audio/audio_ducking.gd),
## duck-typed via has_method so this file does not need to preload it or
## depend on it existing in the scene tree yet. If unset, allocation and
## stealing still work correctly; ducking simply never triggers.
var ducking_node: Node = null

var _voices: Array = [] # Array[_Voice]
var _alloc_serial: int = 0
var _active_priority_count: int = 0


func _ready() -> void:
	for i in range(VOICE_COUNT):
		var voice := _Voice.new()
		voice.player = AudioStreamPlayer2D.new()
		voice.player.name = "Voice%02d" % i
		voice.player.bus = "SFX"
		add_child(voice.player)
		voice.player.finished.connect(_on_voice_finished.bind(i))
		_voices.append(voice)


## Public playback entry point. Allocates (or steals) a voice via
## `allocate_voice()`, positions and configures the resulting
## AudioStreamPlayer2D, and plays it. Returns the player used.
func play(stream: AudioStream, global_pos: Vector2, priority: int = 0, is_priority_voice: bool = false, bus_name: String = "SFX") -> AudioStreamPlayer2D:
	var index := allocate_voice(priority, is_priority_voice)
	var voice: _Voice = _voices[index]
	voice.player.global_position = global_pos
	voice.player.bus = bus_name
	voice.player.stream = stream
	voice.player.play()
	if is_priority_voice:
		_notify_ducking_started()
	return voice.player


## Core bookkeeping/stealing algorithm, deliberately kept free of any actual
## Godot audio call so it can be unit-tested headless without an audio
## device (see p16_report.md > "What headless testing cannot verify").
## Marks the returned slot in_use and returns its index into `_voices`.
##
## Two independent stealing rules, exactly as docs/20 states them:
## 1. Priority-slot cap (checked first, only for a priority request): once
##    `MAX_PRIORITY_VOICES` priority voices are already active, a new
##    priority sound steals the OLDEST active priority voice - not the
##    lowest-priority one; priority value is not consulted for this rule.
## 2. General 32-voice cap (checked for anything, priority or not, once no
##    free voice remains): steal the lowest-priority voice, then the oldest
##    among ties.
func allocate_voice(priority: int, is_priority_voice: bool) -> int:
	var index: int
	if is_priority_voice and _active_priority_count >= MAX_PRIORITY_VOICES:
		index = _find_oldest_priority_voice_index()
		if index == -1:
			# Bookkeeping should make this unreachable (active_priority_count
			# >= 8 implies at least 8 in-use priority voices exist); fall
			# back to the general rule rather than crash on a -1 index.
			index = _find_steal_candidate_index()
		_release_slot_for_reuse(index)
	else:
		index = _find_free_voice_index()
		if index == -1:
			index = _find_steal_candidate_index()
			_release_slot_for_reuse(index)
	_claim_slot(index, priority, is_priority_voice)
	return index


## Manually marks a voice as finished, exactly as the `finished` signal
## handler would. Exposed so bookkeeping tests can simulate a voice ending
## without waiting on real playback duration.
func release_voice(index: int) -> void:
	_on_voice_finished(index)


func get_voice_count() -> int:
	return VOICE_COUNT


func get_active_priority_count() -> int:
	return _active_priority_count


func get_voice_in_use(index: int) -> bool:
	return _voices[index].in_use


func get_voice_priority(index: int) -> int:
	return _voices[index].priority


func get_voice_is_priority(index: int) -> bool:
	return _voices[index].is_priority_voice


func get_voice_alloc_serial(index: int) -> int:
	return _voices[index].alloc_serial


func get_voice_player(index: int) -> AudioStreamPlayer2D:
	return _voices[index].player


func _find_free_voice_index() -> int:
	for i in range(VOICE_COUNT):
		if not _voices[i].in_use:
			return i
	return -1


## Lowest priority first; ties broken by oldest (lowest alloc_serial).
## Only called once every voice is in_use, so it always returns a valid
## index.
func _find_steal_candidate_index() -> int:
	var best_index := 0
	var best_priority: int = _voices[0].priority
	var best_serial: int = _voices[0].alloc_serial
	for i in range(1, VOICE_COUNT):
		var v: _Voice = _voices[i]
		if v.priority < best_priority or (v.priority == best_priority and v.alloc_serial < best_serial):
			best_index = i
			best_priority = v.priority
			best_serial = v.alloc_serial
	return best_index


## Oldest (lowest alloc_serial) among currently active priority voices,
## ignoring priority value entirely, per docs/20's explicit "steals the
## oldest priority voice" wording for this specific rule. Returns -1 if
## bookkeeping is somehow inconsistent (see the fallback in allocate_voice).
func _find_oldest_priority_voice_index() -> int:
	var best_index := -1
	var best_serial: int = 0
	for i in range(VOICE_COUNT):
		var v: _Voice = _voices[i]
		if v.in_use and v.is_priority_voice:
			if best_index == -1 or v.alloc_serial < best_serial:
				best_index = i
				best_serial = v.alloc_serial
	return best_index


func _release_slot_for_reuse(index: int) -> void:
	var v: _Voice = _voices[index]
	if v.in_use and v.is_priority_voice:
		_active_priority_count -= 1
		_notify_ducking_stopped()
	v.in_use = false


func _claim_slot(index: int, priority: int, is_priority_voice: bool) -> void:
	var v: _Voice = _voices[index]
	v.in_use = true
	v.priority = priority
	v.is_priority_voice = is_priority_voice
	v.alloc_serial = _alloc_serial
	_alloc_serial += 1
	if is_priority_voice:
		_active_priority_count += 1


func _on_voice_finished(index: int) -> void:
	var v: _Voice = _voices[index]
	if v.in_use and v.is_priority_voice:
		_active_priority_count -= 1
		_notify_ducking_stopped()
	v.in_use = false
	v.is_priority_voice = false
	v.priority = 0


func _notify_ducking_started() -> void:
	if ducking_node and ducking_node.has_method("notify_priority_started"):
		ducking_node.notify_priority_started()


func _notify_ducking_stopped() -> void:
	if ducking_node and ducking_node.has_method("notify_priority_stopped"):
		ducking_node.notify_priority_stopped()
