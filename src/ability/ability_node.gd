extends Node2D
class_name AbilityNode
## Base for every v1.0 Draft ability (docs/31 §4.2-§4.3). One script per
## ability under src/ability/; the AbilityManager creates, levels and frees
## them. Numbers come from AbilityCatalog (Register "v1.0 Combat & Abilities"),
## never literals here. Timing is SimClock-based (never SceneTree timers) and
## the node is PAUSABLE so abilities freeze under the Draft and pause.
##
## `top_level = true`: ability nodes are children of the manager (a plain Node),
## so they keep explicit world positions instead of inheriting a transform.

var ability_id: String = ""
var level: int = 1
var rarity_mult: float = 1.0
var is_tower: bool = false
var manager: Node = null
var _next_at: float = 0.0


func setup(p_id: String, p_level: int, p_rarity: float, p_manager: Node, p_is_tower: bool) -> void:
	ability_id = p_id
	level = p_level
	rarity_mult = p_rarity
	manager = p_manager
	is_tower = p_is_tower
	name = "Ability_" + p_id


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	z_as_relative = false
	z_index = 25
	_next_at = SimClock.now + 0.4 # a short grace so a fresh pick does not fire inside the Draft close
	on_level_changed()


func set_level(p_level: int, p_rarity: float) -> void:
	level = p_level
	rarity_mult = p_rarity
	on_level_changed()


## Override: re-read numbers after a level-up.
func on_level_changed() -> void:
	pass


## Catalog value at the current level (rarity applied to damage keys only).
func v(key: String) -> float:
	return AbilityCatalog.value(ability_id, key, level, rarity_mult)


## Damage after the player's / Tower's ability multiplier (Heavy Rounds,
## War Training, meta hooks for the player; Caliber and Engineers for the Tower).
func dmg(key: String = "damage") -> float:
	return v(key) * (AbilityDamage.tower_ability_mult() if is_tower else AbilityDamage.player_ability_mult())


func side() -> StringName:
	return &"tower" if is_tower else &"player"


func owner_node() -> Node2D:
	if manager == null:
		return null
	return manager.get_tower() if is_tower else manager.get_player()


func owner_pos() -> Vector2:
	var n: Node2D = owner_node()
	return n.global_position if n != null and is_instance_valid(n) else global_position


## Parent for world FX (explosions, rings): the gameplay root the player lives in.
func fx_parent() -> Node:
	var n: Node2D = owner_node()
	return n.get_parent() if n != null and n.get_parent() != null else get_parent()


## True once per `interval` of SimClock time; reschedules itself.
func due(interval: float) -> bool:
	var now: float = SimClock.now
	if now < _next_at:
		return false
	_next_at = now + interval
	return true


static func load_v1_texture(file_name: String) -> Texture2D:
	var path: String = "res://assets/sprites/v1/%s.png" % file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
