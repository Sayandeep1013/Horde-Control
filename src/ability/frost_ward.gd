extends AbilityNode
class_name FrostWardAbility
## Frost Ward (docs/31 §4.3; PT-POWER D351): every 3.2-2.0 s the Tower pulses within 300-400 px:
## 30-64 damage and a 35-50% slow for 2 s.

func _physics_process(_delta: float) -> void:
	var tower: Node2D = owner_node()
	if tower == null:
		return
	global_position = tower.global_position
	if SimClock.now < _next_at:
		return
	var radius: float = v("radius") * AbilityDamage.area_scale()
	if AbilityDamage.enemies_in_radius(global_position, radius).is_empty():
		return # no enemy in the ward: hold the pulse, consume nothing
	_next_at = SimClock.now + v("interval")
	pulse(radius)


func pulse(radius: float) -> void:
	PulseRing.spawn(fx_parent(), global_position, radius, 0.55, Color(0.6, 0.85, 1.0), 9.0)
	Sfx.play("frost", global_position)
	var amount: float = dmg()
	for e in AbilityDamage.enemies_in_radius(global_position, radius):
		if AbilityDamage.hit(e, amount, ability_id, &"tower", false) > 0.0:
			StatusEffects.apply_slow(e, v("slow"), v("duration"))
