extends AbilityNode
class_name DynamiteSatchelAbility
## Dynamite Satchel (docs/31 §4.2; PT-POWER D351): every 2.4-1.4 s throw 2-4 dynamite at random
## enemies within 420 px (2 at levels 1-2, 3 at 3-4, 4 at 5). Fuse 0.5 s, then 70-140 damage
## in a 130-170 px radius. The explosion is the shared ExplosionFx.

const FLIGHT_SECONDS: float = 0.45 # Register: Dynamite Satchel flight time
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng = AbilityDamage.keyed_rng("dynamite")


func _physics_process(_delta: float) -> void:
	global_position = owner_pos()
	if SimClock.now < _next_at:
		return
	var candidates: Array[Node2D] = AbilityDamage.enemies_in_radius(global_position, v("range"))
	if candidates.is_empty():
		return
	_next_at = SimRate.reschedule(_next_at, SimClock.now, v("interval"))
	var throws: int = AbilityCatalog.dynamite_count(level)
	for i in throws:
		if candidates.is_empty():
			break
		var target: Node2D = candidates[_rng.randi_range(0, candidates.size() - 1)]
		candidates.erase(target)
		_throw(target.global_position)


func _throw(target_pos: Vector2) -> void:
	var radius: float = v("radius") * AbilityDamage.area_scale()
	var amount: float = dmg()
	var parent: Node = fx_parent()
	LobbedBomb.spawn(parent, "dynamite", global_position, target_pos, FLIGHT_SECONDS, v("fuse"), radius, func(pos: Vector2) -> void:
		ExplosionFx.spawn(parent, pos, radius)
		Sfx.play("explosion", pos)
		AbilityDamage.hit_area(pos, radius, amount, ability_id, &"player", true))
