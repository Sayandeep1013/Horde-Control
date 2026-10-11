extends AbilityNode
class_name StormBoltAbility
## Storm Bolt (docs/31 §4.2): every 2.6-1.6 s lightning strikes the nearest enemy
## within 300 px and chains to 2-6 more within 140 px of the previous one.

func _physics_process(_delta: float) -> void:
	global_position = owner_pos()
	if SimClock.now < _next_at:
		return
	var first: Node2D = AbilityDamage.nearest_enemy(global_position, v("range"))
	if first == null:
		return
	_next_at = SimClock.now + v("interval")
	strike(first)


func strike(first: Node2D) -> Array[Node2D]:
	var hit_list: Array[Node2D] = [first]
	var pts := PackedVector2Array([global_position, first.global_position])
	var last: Node2D = first
	var chain_range: float = v("chain_range") * AbilityDamage.area_scale()
	var chains: int = AbilityCatalog.ivalue(ability_id, "chains", level)
	if AbilitySynergy.conduction_active():
		chains += AbilitySynergy.CONDUCTION_EXTRA_CHAINS # Conduction (Frost Ward)
	for i in chains:
		var nxt: Node2D = AbilityDamage.nearest_enemy(last.global_position, chain_range, hit_list)
		if nxt == null:
			break
		hit_list.append(nxt)
		pts.append(nxt.global_position)
		last = nxt
	var amount: float = dmg()
	for e in hit_list:
		AbilityDamage.hit(e, amount * AbilitySynergy.conduction_mult(e), ability_id, &"player", true)
	LightningBolt.spawn(fx_parent(), pts)
	Sfx.play("lightning", first.global_position)
	return hit_list
