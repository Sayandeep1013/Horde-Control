extends AbilityNode
class_name DiagonalArrowsAbility
## Diagonal Arrows (PT-POWER D352, the Archero "Diagonal Arrows" ability): every volley adds
## two arrows at +-45 degrees from the aim line; from level 3 four more fly at +-30 and +-60
## degrees. The arrows are real bow arrows (they pierce, crit, and carry Flame / Frost /
## Ricochet) at 70-100% of the arrow damage, tagged "diagonal_arrows" in the damage report.
## The firing lives in AutoWeapon (set_volley_extras); this node keeps that set current.

var _weapon: AutoWeapon = null


func _ready() -> void:
	super._ready()
	_publish()


func on_level_changed() -> void:
	_publish()


func _find_weapon() -> AutoWeapon:
	if _weapon == null or not is_instance_valid(_weapon):
		var p: Node2D = owner_node()
		_weapon = p.get_node_or_null("AutoWeapon") as AutoWeapon if p != null else null
	return _weapon


## The (angle, fraction) list this level fires, rarity applied to the fraction (a damage key).
func extras() -> Array:
	var out: Array = []
	for angle in AbilityCatalog.diagonal_angles(level):
		out.append(Vector2(angle, v("damage")))
	return out


func _publish() -> void:
	var w: AutoWeapon = _find_weapon()
	if w != null:
		w.set_volley_extras(ability_id, extras())


func _exit_tree() -> void:
	if _weapon != null and is_instance_valid(_weapon):
		_weapon.set_volley_extras(ability_id, [])
