extends AbilityNode
class_name BallistaAbility
## Ballista (docs/31 §4.3): every 2.4-1.2 s the Tower fires a bolt along the line
## to the FURTHEST enemy in range; the bolt pierces everything for 70-150 (PT-POWER D351).

func _physics_process(_delta: float) -> void:
	var tower: Node2D = owner_node()
	if tower == null:
		return
	global_position = tower.global_position
	if SimClock.now < _next_at:
		return
	var reach: float = tower.weapon.get_effective_range_px() if tower.get("weapon") != null else 480.0
	var far: Node2D = null
	var far_d2: float = -1.0
	for e in AbilityDamage.enemies_in_radius(global_position, reach):
		var d2: float = global_position.distance_squared_to(e.global_position)
		if d2 > far_d2:
			far_d2 = d2
			far = e
	if far == null:
		return
	_next_at = SimClock.now + v("interval")
	fire_at(far.global_position, reach)


func fire_at(target_pos: Vector2, reach: float) -> BallistaBolt:
	return BallistaBolt.spawn(fx_parent(), global_position, target_pos - global_position, reach, dmg())
