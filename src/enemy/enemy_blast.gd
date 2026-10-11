extends RefCounted
class_name EnemyBlast
## v1.0 (WP-ENEMIES, docs/31 §5): area damage dealt by enemy explosives
## (Bomber dynamite, Volatile elites, boss slams). Damage goes through
## SimLoop.enqueue_hit like every other hit (docs/20 step 7), against the
## player's and the Tower's Hurtbox when their body/footprint overlaps the
## radius. Falls back to Hurtbox.receive_hit() when no SimLoop exists
## (isolated unit tests).

const SOURCE_TAG: StringName = &"enemy_blast"


## Returns {"player": bool, "tower": bool} for what was hit.
static func detonate(registry: Node, center: Vector2, radius: float, damage: float, hit_player: bool = true, hit_tower: bool = true, attacker: Node = null) -> Dictionary:
	var result: Dictionary = {"player": false, "tower": false}
	if registry == null or damage <= 0.0:
		return result
	var loop: Node = null
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		loop = tree.get_first_node_in_group(&"sim_loop")
	if hit_player:
		var players: Array[Node2D] = registry.get_entities_with_tag(&"player")
		if not players.is_empty() and is_instance_valid(players[0]):
			var p: Node2D = players[0]
			var body_r: float = 0.0
			if p is Player and (p as Player).definition != null:
				body_r = float((p as Player).definition.body_radius_px)
			if p.global_position.distance_to(center) <= radius + body_r:
				result["player"] = _hit(loop, p.get("hurtbox"), damage, attacker, p)
	if hit_tower:
		var towers: Array[Node2D] = registry.get_entities_with_tag(&"tower")
		if not towers.is_empty() and is_instance_valid(towers[0]):
			var t: Node2D = towers[0]
			var foot: float = 0.0
			if t is Tower and (t as Tower).definition != null and (t as Tower).definition.tower_footprint != null:
				foot = float((t as Tower).definition.tower_footprint.footprint_radius_px)
			if t.global_position.distance_to(center) <= radius + foot:
				result["tower"] = _hit(loop, t.get("hurtbox"), damage, attacker, t)
	return result


static func _hit(loop: Node, hurtbox: Variant, damage: float, attacker: Node, target: Node) -> bool:
	if not (hurtbox is Hurtbox) or (hurtbox as Hurtbox).is_dead:
		return false
	if loop != null and loop.has_method(&"enqueue_hit"):
		var attacker_serial: int = loop.get_combat_serial(attacker if attacker != null else SOURCE_TAG)
		loop.enqueue_hit(attacker_serial, loop.get_combat_serial(target), damage, SOURCE_TAG, hurtbox, attacker)
		return true
	return (hurtbox as Hurtbox).receive_hit(attacker, damage, SOURCE_TAG)
