extends Node2D
class_name EnemyAnimator

## EnemyAnimator (art session, D102 follow-up). Purely cosmetic driver for an
## enemy's `AnimatedSprite2D`: idle/run/strike state, facing flip, a hit-flash
## on damage, and the death hand-off to a one-shot skull FX
## (`scenes/fx/death_fx.tscn`). Attached to the `Visuals` node that already
## sat under each of `scenes/entities/{tower_seeker,player_hunter,
## opportunist}.tscn` (previously a bare Node2D holding a static Sprite2D).
##
## ## Read-only, matching `src/enemy/telegraph_visual.gd`'s own established
## pattern for this project ("purely cosmetic and read-only... only POLLS
## an existing public typed query... and never mutates gameplay state"). This
## component only reads `EnemyController`'s existing public fields/signals
## (`velocity` -- a stock CharacterBody2D property, `definition`,
## `player_definition_for_speed_reference`, `windup_started`,
## `attack_resolved`) and `DeathState`'s existing public fields/signals
## (`is_dead`, `logical_death`, `damage_applied`). No change was made to
## `src/enemy/enemy_controller.gd` or `src/combat/death_state.gd` -- neither
## needed a hook added, since everything this file needs was already public.
##
## ## Reuse without an explicit reset hook
## The task brief asks that this animator "fully reset on reuse", pointing at
## how `death_state.reset_for_reuse()` is triggered. Rather than requiring a
## new call from outside (which would mean touching a gameplay file this task
## does not need to touch), this component self-heals by polling
## `death_state.is_dead` every frame in `_process()`: the instant that flag
## goes back to false -- exactly what `reset_for_reuse()` does -- `_death_
## played` clears and `_restore_alive_visuals()` runs on the very next frame,
## regardless of *how* the flag was cleared (a fresh `_ready()`, or a future
## real Pool-reuse path). This also means a repeat death on the same instance
## (a real reuse dying again) replays correctly: `logical_death` is a normal
## Godot signal on a still-alive connection, not a one-shot.
##
## ## Facing while attacking
## `EnemyController.physics_step()` zeroes `velocity` the instant an enemy is
## `in_attack_range` (see that file's own `physics_step()`), so velocity alone
## cannot supply a facing direction during a strike. This file instead keeps
## `_facing` pinned to the last non-zero velocity direction and only updates
## it while actually moving -- a standard top-down convention, and one that
## needs no new accessor on EnemyController (a `_for_test`-suffixed method,
## `get_target_for_test()`, is the only other way to reach that direction, and
## the class's own header marks that whole method group "never called by
## gameplay code").

## The child `AnimatedSprite2D` this component drives.
@export var sprite_path: NodePath = NodePath("AnimatedSprite2D")

## The soft ground shadow under the sprite (see scene comments for why a
## drawn/textured ellipse, not a shader, was enough here).
@export var shadow_path: NodePath = NodePath("Shadow")

@export var controller_path: NodePath = NodePath("..")
@export var death_state_path: NodePath = NodePath("../DeathState")

## Tower Seeker only: picks strike_right/strike_down/strike_up by facing and
## flips right for left, instead of playing the single `strike_animation`
## below. Both `player_hunter.tscn` and `opportunist.tscn` leave this false
## and rely on one non-directional `strike` clip, matching the source sheets
## (docs in tools/art/generate_enemy_sprite_frames.py's own header).
@export var directional_strike: bool = false
@export var strike_animation: StringName = &"strike"

## Empty (the Tower Seeker and Player Hunter default) means "no species
## death clip -- hide immediately and let the skull FX carry the whole
## death beat." The Opportunist sets this to `&"death"` (the barrel's own
## explode row) to play first.
@export var death_animation: StringName = &""

@export var death_fx_scene: PackedScene = preload("res://scenes/fx/death_fx.tscn")

const HIT_FLASH_DURATION_SECONDS: float = 0.08
const HIT_FLASH_COLOUR: Color = Color(2.4, 2.4, 2.4, 1.0)
const MOVING_EPSILON_PX_PER_SEC: float = 4.0

var _controller: EnemyController = null
var _death_state: DeathState = null
var _sprite: AnimatedSprite2D = null
var _shadow: CanvasItem = null

var _facing: Vector2 = Vector2.DOWN
var _striking: bool = false
var _death_played: bool = false
var _flash_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE # pauses with the enemy it decorates, matching telegraph_visual.gd's own convention

	_controller = get_node_or_null(controller_path) as EnemyController
	_death_state = get_node_or_null(death_state_path) as DeathState
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	_shadow = get_node_or_null(shadow_path) as CanvasItem

	if _sprite != null:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"idle"):
			_sprite.play(&"idle")

	if _controller != null:
		_controller.windup_started.connect(_on_windup_started)
		_controller.attack_resolved.connect(_on_attack_resolved)

	if _death_state != null:
		_death_state.logical_death.connect(_on_logical_death)
		_death_state.damage_applied.connect(_on_damage_applied)


func _process(_delta: float) -> void:
	if _controller == null or _sprite == null:
		return

	var is_dead: bool = _death_state != null and _death_state.is_dead
	if is_dead:
		if not _death_played:
			_death_played = true
			_on_death_visuals()
		return

	if _death_played:
		_death_played = false
		_restore_alive_visuals()

	_update_facing_and_flip()

	if _striking:
		return # the strike clip owns the sprite until _on_sprite_animation_finished()

	var speed: float = _controller.velocity.length()
	if speed > MOVING_EPSILON_PX_PER_SEC:
		_sprite.speed_scale = clampf(speed / _reference_speed_px_per_sec(), 0.6, 1.8)
		_play_looping(&"run")
	else:
		_sprite.speed_scale = 1.0
		_play_looping(&"idle")


func _reference_speed_px_per_sec() -> float:
	var def: EnemyDefinition = _controller.definition
	var player_ref: PlayerDefinition = _controller.player_definition_for_speed_reference
	if def == null or def.movement_profile == null or player_ref == null:
		return 1.0
	return maxf(player_ref.base_speed_px_per_second * def.movement_profile.speed_multiplier, 1.0)


func _update_facing_and_flip() -> void:
	var v: Vector2 = _controller.velocity
	if v.length_squared() > MOVING_EPSILON_PX_PER_SEC * MOVING_EPSILON_PX_PER_SEC:
		_facing = v.normalized()
	if absf(_facing.x) > 0.05:
		_sprite.flip_h = _facing.x < 0.0
	if _shadow != null and _shadow.has_method(&"set_flip_h"):
		_shadow.call(&"set_flip_h", _sprite.flip_h)


func _play_looping(anim: StringName) -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


## Wind-up enemies (Tower Seeker, Opportunist): cued the instant the wind-up
## begins (docs/09 > "Telegraph minimums": both have a 0.4s wind-up).
func _on_windup_started() -> void:
	if directional_strike:
		_play_directional_strike()
	else:
		_play_strike(strike_animation)


## Contact enemies (Player Hunter): `windup_started` fires on the same tick
## as the hit itself for a zero-duration wind-up (enemy_controller.gd's own
## `_process_attack_cycle()` header: "a Contact enemy's own TelegraphData.
## windup_duration_seconds is authored as 0.0 ... windup_start == next_hit_
## time when the duration is zero"), so this cues from the resolved hit
## instead, matching the brief's own instruction.
func _on_attack_resolved(_target: Node2D, _damage: float) -> void:
	if not directional_strike:
		_play_strike(strike_animation)


func _play_directional_strike() -> void:
	var anim: StringName
	if absf(_facing.y) >= absf(_facing.x):
		anim = &"strike_down" if _facing.y >= 0.0 else &"strike_up"
		_sprite.flip_h = false
	else:
		anim = &"strike_right"
		_sprite.flip_h = _facing.x < 0.0
	_play_strike(anim)


func _play_strike(anim: StringName) -> void:
	if _sprite == null or _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	_striking = true
	_sprite.speed_scale = 1.0
	_sprite.play(anim)


func _on_sprite_animation_finished() -> void:
	if _striking:
		_striking = false
	# The species death clip (e.g. the Opportunist's own barrel "explode") is
	# `loop = false`, so `AnimatedSprite2D` simply freezes on its last frame
	# once finished rather than disappearing on its own -- without this, a
	# dead Opportunist would sit on screen forever showing a frozen explosion
	# frame instead of handing the whole death beat off to the skull FX.
	if death_animation != &"" and _sprite.animation == death_animation and _death_played:
		_sprite.visible = false


func _on_damage_applied(_amount: float, _source: Variant, _remaining_hp: float) -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = HIT_FLASH_COLOUR
	_flash_tween = _sprite.create_tween() # cosmetic-only Node.create_tween(), not gameplay timing (see CLAUDE.md banned-API rule)
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, HIT_FLASH_DURATION_SECONDS)


## `death_state.gd`'s own `logical_death` signal -- fires once, synchronously,
## with the exact death position, and can fire again later on the same
## instance after a real `reset_for_reuse()` + a second death (see header).
func _on_logical_death(_entity: Node2D, position: Vector2) -> void:
	_spawn_death_fx(position)


func _on_death_visuals() -> void:
	_striking = false
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _sprite != null:
		_sprite.modulate = Color.WHITE
		if death_animation != &"" and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(death_animation):
			_sprite.speed_scale = 1.0
			_sprite.play(death_animation)
		else:
			_sprite.visible = false
	if _shadow != null:
		_shadow.visible = false


func _restore_alive_visuals() -> void:
	_striking = false
	if _sprite != null:
		_sprite.visible = true
		_sprite.modulate = Color.WHITE
		_sprite.speed_scale = 1.0
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"idle"):
			_sprite.play(&"idle")
	if _shadow != null:
		_shadow.visible = true


## Spawned into the dying enemy's OWN parent container (the `Entities` node
## the prototype scene already parents every enemy under), not through
## `EntitySpawner`'s pool/cap machinery: that machinery is wired exclusively
## by explicit `@export var entity_spawner_path: NodePath` set by an
## orchestrator (`src/director/wave_director.gd`, `src/pickup/pickup_
## system.gd`), never a group lookup a new cosmetic component could join
## without also editing one of those owning files -- this task's own brief
## names exactly this fallback ("if the cap machinery is gameplay-only,
## parent to the enemy's parent node and note it"). The FX node is cheap
## (one AnimatedSprite2D, no collision, no EntityRegistry registration) and
## frees itself in `src/fx/death_fx.gd`, so it does not need the `high_
## intensity_vfx` budget's cap enforcement to stay bounded.
func _spawn_death_fx(position: Vector2) -> void:
	if death_fx_scene == null or _controller == null:
		return
	var container: Node = _controller.get_parent()
	if container == null:
		return
	var fx: Node2D = death_fx_scene.instantiate() as Node2D
	container.add_child(fx)
	fx.global_position = position
