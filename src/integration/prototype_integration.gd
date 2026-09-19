extends Node2D
class_name PrototypeIntegration

## PrototypeIntegration (P2.7 integration task). Attached to
## scenes/prototype.tscn's own root. This is the "whichever future task
## next owns scenes/main.tscn" / "the integration task" every P2.1-P2.6
## evidence report named and deferred, for exactly the typed-command wiring
## each of those tasks already built a seam for and could not call itself:
## `EnemyController.set_tower_reference()`, `Hud.set_player_ref()`/
## `set_tower_ref()`, `ThreatFeedback.set_player_ref()`/`set_tower_ref()`/
## `set_camera_ref()`/`set_ducking_node_ref()`, and the new
## `set_audio_pool_ref()` seams this task added to `AutoWeapon`,
## `TowerWeapon`, `EnemyController`, and `Player`.
##
## This script performs ONLY wiring (typed-command calls on already-built
## public seams) -- it contains no gameplay logic of its own and does not
## touch any file on this task's do-not-touch list
## (src/core/sim_loop.gd, src/core/event_bus.gd, src/combat/death_state.gd,
## src/combat/hitbox.gd, src/tower/tower_projectile.gd).
##
## ## The AudioDucking placement (see NEXT_SESSION.md's open contradiction
## row, and this task's own evidence report for the full reasoning): this
## script does NOT parent a PROCESS_MODE_ALWAYS AudioDucking node under
## Main (scenes/main.tscn's own gameplay root) -- it only hands the
## already-instanced AudioPool (living under Main, per docs/20 > Scene
## Tree) a plain object REFERENCE to a shared AudioDucking node that lives
## as this wrapper scene's own sibling, outside Main entirely. Docs/20's
## "Nothing under the gameplay root may set PROCESS_MODE_ALWAYS" is about
## what is PARENTED there, not about what a node under it is allowed to
## hold a reference to -- so this does not touch, let alone resolve, the
## open author decision; it simply avoids the conflict for this
## integration scene by never nesting the ducking node inside the
## gameplay root at all.

@export var main_path: NodePath = NodePath("Main")
@export var player_path: NodePath = NodePath("Main/Player")
@export var tower_path: NodePath = NodePath("Main/Tower")
@export var camera_path: NodePath = NodePath("Main/Player/GameCamera")
@export var hud_path: NodePath = NodePath("Hud")
@export var threat_feedback_path: NodePath = NodePath("ThreatFeedbackLayer/Overlay")
@export var ui_sfx_path: NodePath = NodePath("UiSfx")
@export var shared_ducking_path: NodePath = NodePath("SharedAudioDucking")
@export var enemy_paths: Array[NodePath] = []

var _main: Node = null
var _player: Player = null
var _tower: Tower = null
var _camera: GameCamera = null
var _hud: Hud = null
var _threat_feedback: ThreatFeedback = null
var _ui_sfx: UiSfx = null
var _shared_ducking: AudioDucking = null
var _audio_pool: Node = null
var _enemies: Array[EnemyController] = []


func _ready() -> void:
	_main = get_node_or_null(main_path)
	_player = get_node_or_null(player_path) as Player
	_tower = get_node_or_null(tower_path) as Tower
	_camera = get_node_or_null(camera_path) as GameCamera
	_hud = get_node_or_null(hud_path) as Hud
	_threat_feedback = get_node_or_null(threat_feedback_path) as ThreatFeedback
	_ui_sfx = get_node_or_null(ui_sfx_path) as UiSfx
	_shared_ducking = get_node_or_null(shared_ducking_path) as AudioDucking
	_audio_pool = _main.get_node_or_null("Audio") if _main != null else null

	for path in enemy_paths:
		var enemy: EnemyController = get_node_or_null(path) as EnemyController
		if enemy != null:
			_enemies.append(enemy)

	_wire_hud()
	_wire_threat_feedback()
	_wire_audio_ducking()
	_wire_audio_pool()
	_wire_enemies()


func _wire_hud() -> void:
	if _hud == null:
		return
	if _player != null:
		_hud.set_player_ref(_player)
	if _tower != null:
		_hud.set_tower_ref(_tower)


func _wire_threat_feedback() -> void:
	if _threat_feedback == null:
		return
	if _player != null:
		_threat_feedback.set_player_ref(_player)
	if _tower != null:
		_threat_feedback.set_tower_ref(_tower)
	if _camera != null:
		_threat_feedback.set_camera_ref(_camera)


## See header, "The AudioDucking placement". `AudioPool.ducking_node` and
## `TowerCuePlayer.ducking_node` are both plain, duck-typed `Node`
## references (audio_pool.gd's and tower_cue_player.gd's own header
## comments: "duck-typed via has_method") -- neither requires the ducking
## node to be its child, only reachable. `ThreatFeedback.set_ducking_node_
## ref()` already exists precisely for this (its own header: "if a single
## global AudioDucking node is later established ... the integration task
## should call this instead of leaving the private default in place").
func _wire_audio_ducking() -> void:
	if _shared_ducking == null:
		return
	if _threat_feedback != null:
		_threat_feedback.set_ducking_node_ref(_shared_ducking)
	if _audio_pool != null:
		_audio_pool.ducking_node = _shared_ducking


func _wire_audio_pool() -> void:
	if _audio_pool == null:
		return
	if _player != null:
		_player.set_audio_pool_ref(_audio_pool)
	if _tower != null and _tower.weapon != null:
		_tower.weapon.set_audio_pool_ref(_audio_pool)
	if _player != null:
		var auto_weapon: Node = _player.get_node_or_null("AutoWeapon")
		if auto_weapon != null and auto_weapon.has_method("set_audio_pool_ref"):
			auto_weapon.set_audio_pool_ref(_audio_pool)
	for enemy in _enemies:
		enemy.set_audio_pool_ref(_audio_pool)


## LEDGER F03-15/F03-26: every enemy tags itself with EntityRegistry on its
## own `_ready()` (already built by P2.5); the one seam an integration task
## must still close is handing each enemy the real Tower it cannot find
## through EntityRegistry (F03-26 -- the Tower is not registered there).
func _wire_enemies() -> void:
	if _tower == null:
		return
	for enemy in _enemies:
		enemy.set_tower_reference(_tower)


func get_player() -> Player:
	return _player


func get_tower() -> Tower:
	return _tower


func get_camera() -> GameCamera:
	return _camera


func get_hud() -> Hud:
	return _hud


func get_threat_feedback() -> ThreatFeedback:
	return _threat_feedback


func get_ui_sfx() -> UiSfx:
	return _ui_sfx


func get_shared_ducking() -> AudioDucking:
	return _shared_ducking


func get_audio_pool() -> Node:
	return _audio_pool


func get_enemies() -> Array[EnemyController]:
	return _enemies
