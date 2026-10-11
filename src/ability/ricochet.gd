extends AbilityNode
class_name RicochetAbility
## Ricochet (PT-POWER D353, the Archero "Ricochet" ability): every arrow hit bounces on to
## 2-5 nearby enemies (within 220-300 px of the one before) for 70% of the arrow's damage,
## tagged "ricochet". Each bounce also runs the other arrow-hit hooks, so Flame Arrows ignite
## and Frost Arrows slow the enemies it reaches. The spatial index answers every search.

const TRAIL_GLOW: Color = Color(1.0, 0.82, 0.3, 0.55)
const TRAIL_WIDTH_SCALE: float = 0.55

var _weapon: AutoWeapon = null
var _hook: Callable


func _ready() -> void:
	super._ready()
	_hook = Callable(self, "_on_arrow_hit")
	var p: Node2D = owner_node()
	_weapon = p.get_node_or_null("AutoWeapon") as AutoWeapon if p != null else null
	if _weapon != null and not _weapon.arrow_hit_hooks.has(_hook):
		_weapon.arrow_hit_hooks.append(_hook)


func _exit_tree() -> void:
	if _weapon != null and is_instance_valid(_weapon):
		_weapon.arrow_hit_hooks.erase(_hook)


## Enemies a bounce from `enemy` reaches, in order: each the nearest living, unstruck enemy
## within the bounce range of the one before.
func bounce_targets(enemy: Node2D) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var skip: Array = [enemy]
	var last: Node2D = enemy
	var range_px: float = v("bounce_range") * AbilityDamage.area_scale()
	var want: int = AbilityCatalog.ivalue(ability_id, "bounces", level)
	for attempt in want * 2: # a dead neighbour is skipped without using up a bounce
		if out.size() >= want:
			break
		var nxt: Node2D = AbilityDamage.nearest_enemy(last.global_position, range_px, skip)
		if nxt == null:
			break
		skip.append(nxt)
		if not AbilityDamage.is_enemy_alive(nxt):
			continue
		out.append(nxt)
		last = nxt
	return out


func _on_arrow_hit(enemy: Node, arrow_damage: float) -> void:
	var from: Node2D = enemy as Node2D
	if from == null or not is_instance_valid(from):
		return
	var targets: Array[Node2D] = bounce_targets(from)
	if targets.is_empty():
		return
	var amount: float = arrow_damage * v("fraction") # the arrow's own damage already carries crit and every bow term
	var pts := PackedVector2Array([from.global_position])
	for t in targets:
		pts.append(t.global_position)
		if AbilityDamage.hit(t, amount, ability_id, &"player", false) > 0.0 and _weapon != null:
			for h in _weapon.arrow_hit_hooks: # Flame / Frost Arrows apply their status on the bounce
				if h != _hook and h.is_valid():
					h.call(t, amount)
	LightningBolt.spawn(fx_parent(), pts, TRAIL_GLOW, TRAIL_WIDTH_SCALE)
