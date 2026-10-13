extends AbilityNode
class_name MeteorShowerAbility
## Meteor Shower (PT-POWER D355, the Archero "Meteor Shower" ability): every 6-3.5 s, 3-6
## meteors fall on enemy clusters within 520 px of the player. Each is telegraphed by a ground
## ring for 0.9 s (staggered 0.18 s apart), then lands for 180 damage in a 120 px blast (a
## GroundTelegraph, a falling rock and the shared ExplosionFx). Clusters already covered by a
## meteor are skipped so the volley spreads across the swarm; surplus meteors fall on random
## enemies.

const STAGGER_SECONDS: float = 0.18 # Register: Meteor Shower stagger between meteors

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng = AbilityDamage.keyed_rng("meteor")


func _physics_process(_delta: float) -> void:
	global_position = owner_pos()
	if SimClock.now < _next_at:
		return
	if cast() > 0:
		_next_at = SimRate.reschedule(_next_at, SimClock.now, v("interval"))


## Chooses the impact points (densest cluster first, covered enemies dropped, then random
## surplus) and spawns the meteors. Returns the number spawned (0 with no enemy in range).
func cast() -> int:
	var candidates: Array[Node2D] = AbilityDamage.enemies_in_radius(global_position, v("range"))
	if candidates.is_empty():
		return 0
	var radius: float = v("radius") * AbilityDamage.area_scale()
	var amount: float = dmg()
	var parent: Node = fx_parent()
	var pool: Array[Node2D] = candidates.duplicate()
	var count: int = AbilityCatalog.ivalue(ability_id, "meteors", level)
	for i in count:
		var pos: Vector2
		var cluster: Dictionary = AbilityDamage.densest_in(pool, radius)
		if cluster.is_empty():
			pos = candidates[_rng.randi_range(0, candidates.size() - 1)].global_position
		else:
			pos = cluster["position"]
			var rest: Array[Node2D] = []
			for e in pool:
				if is_instance_valid(e) and e.global_position.distance_squared_to(pos) > radius * radius:
					rest.append(e)
			pool = rest
		MeteorStrike.spawn(parent, pos, radius, v("delay") + STAGGER_SECONDS * float(i), func(at: Vector2) -> void:
			AbilityDamage.hit_area(at, radius, amount, ability_id, &"player", true))
	return count
