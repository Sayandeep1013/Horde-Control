extends Node2D
class_name ArenaSpikeTrap
## Spike Trap (Register "v1.0 Arena Interactables", docs/32 section B): a fixed plate on the sand
## that cycles retracted, telegraph (tips peek, plate glows red), raised. While
## raised it hits every enemy and the player once per cycle. Enemies are damaged
## through AbilityDamage (CombatStats "spikes", bosses take half); the player
## through ArenaHits. All timing is SimClock; `phase_offset` staggers the plates.

const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/v1/spike_trap_0.png"),
	preload("res://assets/sprites/v1/spike_trap_1.png"),
	preload("res://assets/sprites/v1/spike_trap_2.png"),
	preload("res://assets/sprites/v1/spike_trap_3.png"),
]

enum Phase { RETRACTED, TELEGRAPH, RAISED }

# Register "v1.0 Arena Interactables": Spike Trap
const RETRACTED_SECONDS: float = 2.2
const TELEGRAPH_SECONDS: float = 0.6
const RAISED_SECONDS: float = 0.5
const DAMAGE: float = 30.0
const HIT_RADIUS_X_PX: float = 36.0 # plate hit ellipse, half-width
const HIT_RADIUS_Y_PX: float = 24.0 # plate hit ellipse, half-height
const CYCLE_SECONDS: float = RETRACTED_SECONDS + TELEGRAPH_SECONDS + RAISED_SECONDS
const BLINK_HZ: float = 8.0

var phase_offset: float = 0.0
var hits_this_cycle: int = 0

var _sprite: Sprite2D = null
var _cycle_index: int = -1
var _hit_ids: Dictionary = {} # instance id -> true, cleared every cycle
var _last_phase: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"arena_spike_trap")
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURES[0]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _cycle_time() -> float:
	return fposmod(SimClock.now + phase_offset, CYCLE_SECONDS)


func current_phase() -> int:
	var t: float = _cycle_time()
	if t < RETRACTED_SECONDS:
		return Phase.RETRACTED
	if t < RETRACTED_SECONDS + TELEGRAPH_SECONDS:
		return Phase.TELEGRAPH
	return Phase.RAISED


func is_raised() -> bool:
	return current_phase() == Phase.RAISED


func in_plate(world_pos: Vector2) -> bool:
	var d: Vector2 = world_pos - global_position
	return (d.x * d.x) / (HIT_RADIUS_X_PX * HIT_RADIUS_X_PX) + (d.y * d.y) / (HIT_RADIUS_Y_PX * HIT_RADIUS_Y_PX) <= 1.0


func _physics_process(_delta: float) -> void:
	step()


## One simulation tick (also called directly by tests).
func step() -> void:
	var cycle: int = int(floor((SimClock.now + phase_offset) / CYCLE_SECONDS))
	if cycle != _cycle_index:
		_cycle_index = cycle
		_hit_ids.clear()
		hits_this_cycle = 0
	var phase: int = current_phase()
	if phase == Phase.RAISED:
		if _last_phase != Phase.RAISED:
			Sfx.play("caltrops", global_position)
		_hit_raised()
	_last_phase = phase


func _hit_raised() -> void:
	for e in AbilityDamage.enemies_in_radius(global_position, HIT_RADIUS_X_PX + 24.0):
		if not in_plate(e.global_position) or _hit_ids.has(e.get_instance_id()):
			continue
		if ArenaHits.hit_enemy(e, DAMAGE, AbilityIds.SOURCE_SPIKES) > 0.0:
			_hit_ids[e.get_instance_id()] = true
			hits_this_cycle += 1
	var player: Node2D = ArenaHits.get_player()
	if player != null and in_plate(player.global_position) and not _hit_ids.has(player.get_instance_id()):
		if ArenaHits.hit_player(player, DAMAGE, &"spikes"):
			_hit_ids[player.get_instance_id()] = true
			hits_this_cycle += 1


func _process(_delta: float) -> void:
	var frame: int = 0
	match current_phase():
		Phase.TELEGRAPH:
			frame = 3 if int(SimClock.now * BLINK_HZ) % 2 == 0 else 1
		Phase.RAISED:
			frame = 2
	_sprite.texture = TEXTURES[frame]
