extends Node
class_name MusicPlayer

## Loops the run's background music on the `Music` bus (art pass, D102;
## default_bus_layout.tres already defines `Music` -> `Master`, unrelated to
## this task). Looping is configured on the AudioStream resource itself
## (`battle_theme_a.ogg.import`'s `loop=true` param), not in code, per
## godot-prompter:audio-system's own rule ("Looping is configured on the
## AudioStream resource, not the player node").
##
## PAUSE BEHAVIOUR. `process_mode = PROCESS_MODE_ALWAYS` so this node (and
## the AudioStreamPlayer it owns) keeps running when RunFlowController
## pauses the gameplay tree -- ambient music continuing under a pause menu
## reads better than it cutting out. Ducking is already handled for free:
## `AudioDucking` (src/audio/audio_ducking.gd) manipulates the live `Music`
## bus's own volume_db directly whenever a priority SFX plays, with no
## knowledge of which player(s) are routed to that bus, so this player gets
## that ducking automatically just by setting `bus = "Music"`.
##
## RUN END. Rather than editing src/run/run_flow_controller.gd (outside
## this task's write scope -- other work is in flight there), this file
## takes the same seam that controller documents as available to anyone:
## `PauseAuthority`'s reason set is "any StringName ... the five constants
## ... are just typo-proof names for the canonical ones"
## (pause_authority.gd's own header), and RunFlowController pushes exactly
## one non-canonical reason, `&"run_ended"`, at the moment a run ends. This
## file listens for that same reason on the shared PauseAuthority autoload
## and fades the music out once, rather than cutting it abruptly.

const MUSIC_BUS: StringName = &"Music"
const RUN_ENDED_REASON: StringName = &"run_ended"

@export var stream: AudioStream
@export var volume_db: float = -8.0
@export var fade_out_seconds: float = 1.5

var _player: AudioStreamPlayer = null
var _faded_out: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "Stream"
	_player.bus = MUSIC_BUS
	_player.volume_db = volume_db
	add_child(_player)
	if stream != null:
		_player.stream = stream
		_player.play()
	if PauseAuthority != null and PauseAuthority.has_signal(&"reasons_changed"):
		PauseAuthority.reasons_changed.connect(_on_pause_reasons_changed)


func _on_pause_reasons_changed(reasons: Array) -> void:
	if _faded_out or _player == null:
		return
	if reasons.has(RUN_ENDED_REASON):
		_faded_out = true
		var t: Tween = create_tween()
		t.tween_property(_player, "volume_db", -60.0, fade_out_seconds)
		t.tween_callback(_player.stop)
