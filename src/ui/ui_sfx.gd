extends Node
class_name UiSfx

## UiSfx (integration task). Wires the three `assets/third_party/kenney/
## audio/ui/*.ogg` cues (docs/25_Asset_Pipeline.md) into the mechanism
## docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic Ducking"
## already names: "UI sounds do not draw from this pool [AudioPool]; they
## play on their own PROCESS_MODE_ALWAYS players so menu audio is
## unaffected by pause."
##
## ## No caller exists yet, named rather than silently invented
## This phase (P2.1-P2.7) builds no menu, Level-Up Draft, or Tower Console
## -- those are Phase 04/05 systems (docs/29 > Milestones and Roadmap).
## Nothing in this codebase today confirms a selection, cancels a screen,
## or cycles a list, so nothing calls `play_confirm()`/`play_cancel()`/
## `play_cycle()` yet. This file builds the ROUTING MECHANISM only (three
## dedicated PROCESS_MODE_ALWAYS `AudioStreamPlayer`s on the `UI` bus, each
## with its real Kenney stream already assigned) -- exactly the same scope
## boundary P1.6/P2.6 already drew for the Tower cue before any Tower
## damage existed to trigger it, and P2.6's own `HudEconomyState` seam for
## systems that do not exist yet. A future UI/menu system calls these
## three methods directly; this integration task does not invent a menu to
## call them from.
##
## ## Not under the gameplay root
## Like `src/ui/hud.gd` and the shared `AudioDucking` node this integration
## scene assembles, this node sets `PROCESS_MODE_ALWAYS` on itself and is
## therefore placed OUTSIDE `scenes/main.tscn`'s gameplay root in the
## prototype scene (docs/20 > Global Simulation Authority: "Nothing under
## the gameplay root may set PROCESS_MODE_ALWAYS").

const BUS_UI: String = "UI"

## Integration task, docs/25_Asset_Pipeline.md: assigned in the prototype
## scene -- never a hardcoded path in this script's logic (D99).
@export var confirm_stream: AudioStream
@export var cancel_stream: AudioStream
@export var cycle_stream: AudioStream

var _confirm_player: AudioStreamPlayer = null
var _cancel_player: AudioStreamPlayer = null
var _cycle_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_player = _make_player("ConfirmPlayer")
	_cancel_player = _make_player("CancelPlayer")
	_cycle_player = _make_player("CyclePlayer")


func _make_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = BUS_UI
	add_child(player)
	return player


func play_confirm() -> void:
	_play(_confirm_player, confirm_stream)


func play_cancel() -> void:
	_play(_cancel_player, cancel_stream)


func play_cycle() -> void:
	_play(_cycle_player, cycle_stream)


func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.play()


func get_confirm_player_for_test() -> AudioStreamPlayer:
	return _confirm_player


func get_cancel_player_for_test() -> AudioStreamPlayer:
	return _cancel_player


func get_cycle_player_for_test() -> AudioStreamPlayer:
	return _cycle_player
