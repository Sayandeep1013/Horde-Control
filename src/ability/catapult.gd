extends AbilityNode
class_name CatapultAbility
## Catapult (docs/31 §4.3): every 5.0-3.0 s the Tower lobs a rock (0.9 s flight,
## telegraphed) at the densest cluster within 620 px: 50-110 damage in 90 px.

func _physics_process(_delta: float) -> void:
	var tower: Node2D = owner_node()
	if tower == null:
		return
	global_position = tower.global_position
	if SimClock.now < _next_at:
		return
	var radius: float = v("radius") * AbilityDamage.area_scale()
	var cluster: Dictionary = AbilityDamage.densest_cluster(global_position, v("range"), radius)
	if cluster.is_empty():
		return
	_next_at = SimClock.now + v("interval")
	var amount: float = dmg()
	var parent: Node = fx_parent()
	LobbedBomb.spawn(parent, "rock", global_position, cluster["position"], v("flight"), 0.0, radius, func(pos: Vector2) -> void:
		ExplosionFx.spawn(parent, pos, radius)
		Sfx.play("explosion", pos)
		blast(pos, radius, amount), Color(0.95, 0.75, 0.3))


## The landing blast. Shatter: a Frozen enemy takes double (Frost Arrows owned).
func blast(pos: Vector2, radius: float, amount: float) -> void:
	for e in AbilityDamage.enemies_in_radius(pos, radius):
		AbilityDamage.hit(e, amount * AbilitySynergy.shatter_mult(e), ability_id, &"tower", false)
