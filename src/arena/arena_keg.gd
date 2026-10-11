extends Node2D
class_name ArenaKeg
## Powder Keg (Register "v1.0 Arena Interactables", docs/32 section B). Lit by a player
## dash into it or by any player-side explosion / area damage (including another
## keg: chain detonation). Enemies never light it. A lit keg shows a 170 px
## GroundTelegraph for the 0.8 s fuse, then ExplosionFx: damage to enemies in the
## radius (bosses take half), a little damage to the player when inside, none to
## the Tower. Recorded in CombatStats under "keg".

signal detonated(keg: ArenaKeg, position: Vector2)

const TEX_UNLIT: Texture2D = preload("res://assets/sprites/v1/powder_keg.png")
const TEX_LIT: Texture2D = preload("res://assets/sprites/v1/powder_keg_lit.png")
const TELEGRAPH_COLOR: Color = Color(0.95, 0.3, 0.12)

# Register "v1.0 Arena Interactables": Powder Keg
const FUSE_SECONDS: float = 0.8
const BLAST_RADIUS_PX: float = 170.0
const ENEMY_DAMAGE: float = 260.0
const SPRITE_SCALE: float = 1.6
const PLAYER_DAMAGE: float = 15.0
var breakable_radius: float = 32.0 # Register: Keg radius (20 px x 1.6)

var is_lit: bool = false
var has_exploded: bool = false

var _sprite: Sprite2D = null
var _fuse_ends_at: float = 0.0
var _telegraph: GroundTelegraph = null
var _phase: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"breakable")
	add_to_group(&"arena_keg")
	_sprite = Sprite2D.new()
	_sprite.texture = TEX_UNLIT
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -16)
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(_sprite)
	_phase = fmod(global_position.x * 0.017 + global_position.y * 0.011, TAU)


## A player dash whose swept path touches the keg lights it. Walking does not.
func check_player(player: Node2D, previous_position: Vector2) -> bool:
	if is_lit or has_exploded or player == null:
		return false
	if not (player is Player and (player as Player).is_dashing()):
		return false
	var reach: float = breakable_radius + ArenaHits.player_body_radius(player)
	if ArenaHits.segment_distance(previous_position, player.global_position, global_position) <= reach:
		light("dash")
		return true
	return false


## Called by AbilityDamage.hit_breakables for player-side area damage and by another keg's blast.
func take_area_damage(amount: float, source_id: String) -> void:
	if amount > 0.0:
		light(source_id)


func light(_by: String) -> void:
	if is_lit or has_exploded:
		return
	is_lit = true
	_fuse_ends_at = SimClock.now + FUSE_SECONDS
	_sprite.texture = TEX_LIT
	Sfx.play("fuse", global_position)
	var parent: Node = get_parent()
	if parent != null:
		_telegraph = GroundTelegraph.spawn(parent, global_position, BLAST_RADIUS_PX, FUSE_SECONDS, TELEGRAPH_COLOR, false)


func fuse_time_left() -> float:
	return maxf(0.0, _fuse_ends_at - SimClock.now) if is_lit else FUSE_SECONDS


func _physics_process(_delta: float) -> void:
	if is_lit and not has_exploded and SimClock.now >= _fuse_ends_at:
		detonate()


func _process(_delta: float) -> void:
	if has_exploded:
		return
	if is_lit:
		# Fuse flicker: the lit sprite pulses faster as the blast nears.
		var left: float = fuse_time_left() / FUSE_SECONDS
		var rate: float = 10.0 + 20.0 * (1.0 - left)
		modulate = Color(1, 1, 1).lerp(Color(1.6, 1.3, 1.0), 0.5 + 0.5 * sin(SimClock.now * rate))
	else:
		queue_redraw()


## Idle affordance: a slow red pulse ring on the ground under an unlit keg.
func _draw() -> void:
	if is_lit or has_exploded:
		return
	var a: float = 0.25 + 0.2 * (0.5 + 0.5 * sin(SimClock.now * 2.4 + _phase))
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, 30.0 * SPRITE_SCALE, 0.0, TAU, 24, Color(0.95, 0.3, 0.2, a), 2.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func detonate() -> void:
	if has_exploded:
		return
	has_exploded = true
	remove_from_group(&"breakable")
	var center: Vector2 = global_position
	var parent: Node = get_parent()
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	if parent != null:
		ExplosionFx.spawn(parent, center, BLAST_RADIUS_PX)
	Sfx.play("explosion", center)
	CombatStats.add_run_counter("kegs_detonated")
	for e in AbilityDamage.enemies_in_radius(center, BLAST_RADIUS_PX):
		ArenaHits.hit_enemy(e, ENEMY_DAMAGE, AbilityIds.SOURCE_KEG)
	var player: Node2D = ArenaHits.get_player()
	if player != null and player.global_position.distance_to(center) <= BLAST_RADIUS_PX + ArenaHits.player_body_radius(player):
		ArenaHits.hit_player(player, PLAYER_DAMAGE, &"keg")
	# Chain: neighbouring kegs light, crates break (this keg has left the group above).
	AbilityDamage.hit_breakables(center, BLAST_RADIUS_PX, ENEMY_DAMAGE, AbilityIds.SOURCE_KEG)
	detonated.emit(self, center)
	queue_free()
