extends AbilityNode
class_name StormBoltAbility
## Storm Bolt (docs/31 §4.2; PT-POWER D351): every 1.8-1.0 s lightning strikes the nearest
## enemy within 420 px and chains to 4-10 more within 220 px of the previous one.

func _physics_process(_delta: float) -> void:
	global_position = owner_pos()
	if SimClock.now < _next_at:
		return
	var first: Node2D = AbilityDamage.nearest_enemy(global_position, v("range"))
	if first == null:
		return
	_next_at = SimRate.reschedule(_next_at, SimClock.now, v("interval"))
	strike(first)


func strike(first: Node2D) -> Array[Node2D]:
	var chains: int = AbilityCatalog.ivalue(ability_id, "chains", level)
	if AbilitySynergy.conduction_active():
		chains += AbilitySynergy.CONDUCTION_EXTRA_CHAINS # Conduction (Frost Ward)
	var hit_list: Array[Node2D] = AbilityDamage.chain_targets(first, chains, v("chain_range") * AbilityDamage.area_scale())
	var pts := PackedVector2Array([global_position])
	for e in hit_list:
		pts.append(e.global_position)
	var amount: float = dmg()
	for e in hit_list:
		AbilityDamage.hit(e, amount * AbilitySynergy.conduction_mult(e), ability_id, &"player", true)
	LightningBolt.spawn(fx_parent(), pts)
	Sfx.play("lightning", first.global_position)
	return hit_list
