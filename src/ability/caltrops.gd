extends AbilityNode
class_name CaltropsAbility
## Caltrops (docs/31 §4.2): while moving, drop a spike patch every 0.9-0.5 s.
## Each patch lasts 4 s, deals 10-20 damage per 0.5 s and slows 25%.

const MAX_LIVE_PATCHES: int = 40 # Register: Caltrops live patch cap (performance)
const MOVING_SPEED_PX_PER_S: float = 30.0 # Register: Caltrops "moving" threshold

var _last_pos: Vector2 = Vector2.ZERO
var _have_last: bool = false


func _physics_process(delta: float) -> void:
	var pos: Vector2 = owner_pos()
	global_position = pos
	if not _have_last:
		_last_pos = pos
		_have_last = true
		return
	var speed: float = pos.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = pos
	if speed < MOVING_SPEED_PX_PER_S or SimClock.now < _next_at:
		return
	_next_at = SimClock.now + v("interval")
	var parent: Node = fx_parent()
	var patches: Array = get_tree().get_nodes_in_group(&"caltrop_patch")
	if patches.size() >= MAX_LIVE_PATCHES:
		(patches[0] as Node).queue_free()
	CaltropPatch.spawn(parent, pos, dmg(), v("tick"), v("slow"), v("lifetime"))
	Sfx.play("caltrops", pos)
