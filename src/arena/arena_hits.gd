extends RefCounted
class_name ArenaHits
## Damage helpers shared by the arena interactables (Powder Keg, Spike Trap).
## Every hit goes through SimLoop.enqueue_hit (docs/20 step 7); with no SimLoop
## (isolated unit tests) it falls back to Hurtbox.receive_hit. Enemy hits record
## CombatStats under `source_id` through AbilityDamage.hit (once, at resolution);
## side &"hazard" is neutral so an Opportunist does not retarget the player.
## Numbers: Register "v1.0 Arena Interactables".

const BOSS_DAMAGE_FRACTION: float = 0.5 # Register: Boss damage fraction
const SIDE: StringName = &"hazard"


static func is_boss(enemy: Node) -> bool:
	var id: Variant = enemy.get("boss_id")
	return id is String and id != ""


## Hits one enemy (bosses take the Register fraction). Returns the amount queued.
static func hit_enemy(enemy: Node, amount: float, source_id: String) -> float:
	if is_boss(enemy):
		amount *= BOSS_DAMAGE_FRACTION
	return AbilityDamage.hit(enemy, amount, source_id, SIDE, false)


static func get_player() -> Node2D:
	var players: Array[Node2D] = EntityRegistry.get_entities_with_tag(&"player")
	if players.is_empty() or not is_instance_valid(players[0]):
		return null
	return players[0]


static func player_body_radius(player: Node2D) -> float:
	if player is Player and (player as Player).definition != null:
		return float((player as Player).definition.body_radius_px)
	return 14.0


## Hits the player's Hurtbox (dash i-frames and invulnerability are the
## Hurtbox's own rule). `tag` is the damage-source tag, e.g. &"keg".
static func hit_player(player: Node2D, amount: float, tag: StringName) -> bool:
	if player == null or amount <= 0.0:
		return false
	var hurtbox: Variant = player.get("hurtbox")
	if not (hurtbox is Hurtbox) or (hurtbox as Hurtbox).is_dead:
		return false
	var loop: Node = AbilityDamage.get_sim_loop()
	if loop != null and loop.has_method(&"enqueue_hit"):
		loop.enqueue_hit(loop.get_combat_serial(tag), loop.get_combat_serial(player), amount, tag, hurtbox, null)
		return true
	return (hurtbox as Hurtbox).receive_hit(null, amount, tag)


## Shortest distance from `point` to the segment a-b (a swept body path).
static func segment_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
	return closest.distance_to(point)
