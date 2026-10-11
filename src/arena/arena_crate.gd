extends Node2D
class_name ArenaCrate
## Supply Crate (Register "v1.0 Arena Interactables", docs/32 section B). Breaks when
## the player walks or dashes into it (swept body test, so a fast dash cannot
## tunnel through) or when any player-side area damage reaches it
## (`take_area_damage`, called by AbilityDamage.hit_breakables). Not an enemy
## target: it is not in the EntityRegistry and has no hurtbox, so the auto-bow
## and the Tower weapon never see it. Drops are rolled by ArenaInteractables
## (keyed RNG) on the `broken` signal.

signal broken(crate: ArenaCrate, position: Vector2, by: String)

const TEX_INTACT: Texture2D = preload("res://assets/sprites/v1/crate.png")
const TEX_BROKEN: Texture2D = preload("res://assets/sprites/v1/crate_broken.png")
const RUBBLE_SECONDS: float = 1.2

## Group "breakable" members expose this radius to AbilityDamage.hit_breakables.
var breakable_radius: float = 22.0 # Register: Crate radius
var is_broken: bool = false

var _sprite: Sprite2D = null
var _broken_at: float = 0.0
var _sparkle_phase: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"breakable")
	add_to_group(&"arena_crate")
	_sprite = Sprite2D.new()
	_sprite.texture = TEX_INTACT
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -12)
	add_child(_sprite)
	_sparkle_phase = fmod(global_position.x * 0.021 + global_position.y * 0.013, TAU)


## True when the player's body path this tick touched the crate (walking or dashing).
func check_player(player: Node2D, previous_position: Vector2) -> bool:
	if is_broken or player == null:
		return false
	var reach: float = breakable_radius + ArenaHits.player_body_radius(player)
	if ArenaHits.segment_distance(previous_position, player.global_position, global_position) <= reach:
		break_crate("player")
		return true
	return false


func take_area_damage(amount: float, source_id: String) -> void:
	if amount > 0.0:
		break_crate(source_id)


func break_crate(by: String) -> void:
	if is_broken:
		return
	is_broken = true
	remove_from_group(&"breakable")
	_broken_at = SimClock.now
	_sprite.texture = TEX_BROKEN
	CombatStats.add_run_counter("crates_broken")
	Sfx.play("wood_break", global_position)
	var parent: Node = get_parent()
	if parent != null:
		ArenaDustPuff.spawn(parent, global_position)
	broken.emit(self, global_position, by)


func _process(_delta: float) -> void:
	if is_broken:
		var t: float = (SimClock.now - _broken_at) / RUBBLE_SECONDS
		if t >= 1.0:
			queue_free()
			return
		modulate.a = 1.0 - maxf(0.0, t - 0.5) * 2.0
		return
	queue_redraw()


## Idle affordance: a gold glint that twinkles at the crate's top corner, visible on sand and grass.
func _draw() -> void:
	if is_broken:
		return
	var tw: float = 0.5 + 0.5 * sin(SimClock.now * 3.0 + _sparkle_phase)
	if tw > 0.55:
		var c := Color(1.0, 0.95, 0.55, (tw - 0.55) * 2.2)
		var p := Vector2(16, -34)
		draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), c, 2.0)
		draw_line(p + Vector2(0, -4), p + Vector2(0, 4), c, 2.0)
