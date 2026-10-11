extends AbilityNode
class_name SpikedPalisadeAbility
## Spiked Palisade (docs/31 §4.3): an enemy striking the Tower takes 10-30 damage
## back, and the Tower takes 5-20% less damage. The numbers live in TowerHealth
## (it sees every hit); this node pushes them there and keeps them fresh when
## the Tower damage multiplier changes. The reflect is rarity-scaled (damage).

const REFRESH_SECONDS: float = 1.0
var _next_refresh: float = 0.0


func on_level_changed() -> void:
	_push()


func _physics_process(_delta: float) -> void:
	if SimClock.now >= _next_refresh:
		_next_refresh = SimClock.now + REFRESH_SECONDS
		_push()


func _push() -> void:
	var tower: Node2D = owner_node()
	if tower == null or tower.get("health") == null:
		return
	tower.health.set_palisade(v("reduction"), dmg("reflect"))


func _exit_tree() -> void:
	var tower: Node2D = owner_node()
	if tower != null and is_instance_valid(tower) and tower.get("health") != null:
		tower.health.set_palisade(0.0, 0.0)
