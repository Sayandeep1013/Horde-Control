extends RefCounted
class_name StatusEffects
## v1.0 status effects on enemies (docs/31 §4.5; Register "v1.0 Combat &
## Abilities" > Status effects). Static API so enemy_controller.gd needs only
## two tiny hooks and any ability can apply a status without a reference to
## the enemy's scripts.
##
##   burn   dps for a duration; reapplying REFRESHES (keeps the larger dps), it
##          never stacks. Ticks every BURN_TICK_SECONDS through
##          AbilityDamage.hit so it goes through SimLoop.enqueue_hit and is
##          recorded under the applying ability's id.
##   slow   a fraction; the strongest active slow applies; capped at SLOW_CAP.
##   freeze stops movement and attacks. `set_immunities` makes a target immune
##          (bosses) or turns freeze into a slow (Brutes, D-record: docs/31 §5.1
##          wording wins over §4.5's "half duration").
##
## State is keyed by instance id and read against SimClock.now, so the queries
## are correct even before the ticking runner exists. The runner (a PAUSABLE
## node under the scene root) ticks burn, tints sprites and prunes the dead.

const SLOW_CAP: float = 0.70 # Register: Slow cap
const BURN_TICK_SECONDS: float = 0.5 # Register: Burn tick interval
const FREEZE_TO_SLOW_FRACTION: float = 0.50 # Register: Freeze-immune-to-slow strength

static var _state: Dictionary = {} # instance_id -> Dictionary
static var _immunity: Dictionary = {} # instance_id -> {freeze_immune, freeze_to_slow}
static var _runner: Node = null


static func _entry(enemy: Object, create: bool) -> Dictionary:
	var id: int = enemy.get_instance_id()
	if not _state.has(id):
		if not create:
			return {}
		_state[id] = {"enemy": enemy, "burn_dps": 0.0, "burn_until": -1.0, "burn_source": "burn", "burn_next": 0.0, "slow": 0.0, "slow_until": -1.0, "freeze_until": -1.0}
	return _state[id]


static func _now() -> float:
	return SimClock.now


static func apply_burn(enemy: Node, dps: float, duration: float, source_id: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or dps <= 0.0 or duration <= 0.0:
		return
	var e: Dictionary = _entry(enemy, true)
	var now: float = _now()
	var active: bool = float(e["burn_until"]) > now
	e["burn_dps"] = maxf(float(e["burn_dps"]), dps) if active else dps
	e["burn_until"] = now + duration
	e["burn_source"] = source_id
	if not active:
		e["burn_next"] = now + BURN_TICK_SECONDS
	_ensure_runner()


static func apply_slow(enemy: Node, fraction: float, duration: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or fraction <= 0.0 or duration <= 0.0:
		return
	var e: Dictionary = _entry(enemy, true)
	var now: float = _now()
	var f: float = minf(fraction, SLOW_CAP)
	if float(e["slow_until"]) > now and float(e["slow"]) > f:
		# Weaker reapply never replaces a stronger live slow, but may extend it.
		e["slow_until"] = maxf(float(e["slow_until"]), now + duration)
	else:
		e["slow"] = f
		e["slow_until"] = now + duration
	_ensure_runner()


static func apply_freeze(enemy: Node, duration: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or duration <= 0.0:
		return
	var imm: Dictionary = _immunity.get(enemy.get_instance_id(), {})
	if bool(imm.get("freeze_immune", false)):
		return
	if bool(imm.get("freeze_to_slow", false)):
		apply_slow(enemy, FREEZE_TO_SLOW_FRACTION, duration)
		return
	var e: Dictionary = _entry(enemy, true)
	e["freeze_until"] = maxf(float(e["freeze_until"]), _now() + duration)
	_ensure_runner()


## Bosses: set_immunities(e, true, false). Brutes: set_immunities(e, false, true).
static func set_immunities(enemy: Node, freeze_immune: bool, freeze_to_slow: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not freeze_immune and not freeze_to_slow:
		_immunity.erase(enemy.get_instance_id())
		return
	_immunity[enemy.get_instance_id()] = {"enemy": enemy, "freeze_immune": freeze_immune, "freeze_to_slow": freeze_to_slow}


static func speed_multiplier_for(enemy: Object) -> float:
	if enemy == null or _state.is_empty():
		return 1.0
	var e: Dictionary = _entry(enemy, false)
	if e.is_empty() or float(e["slow_until"]) <= _now():
		return 1.0
	return 1.0 - minf(float(e["slow"]), SLOW_CAP)


static func is_frozen(enemy: Object) -> bool:
	if enemy == null or _state.is_empty():
		return false
	var e: Dictionary = _entry(enemy, false)
	return not e.is_empty() and float(e["freeze_until"]) > _now()


static func is_slowed(enemy: Object) -> bool:
	if enemy == null or _state.is_empty():
		return false
	var e: Dictionary = _entry(enemy, false)
	return not e.is_empty() and float(e["slow_until"]) > _now() and float(e["slow"]) > 0.0


static func is_burning(enemy: Object) -> bool:
	if enemy == null or _state.is_empty():
		return false
	var e: Dictionary = _entry(enemy, false)
	return not e.is_empty() and float(e["burn_until"]) > _now()


static func get_burn_info(enemy: Object) -> Dictionary:
	if not is_burning(enemy):
		return {}
	var e: Dictionary = _entry(enemy, false)
	return {"dps": e["burn_dps"], "remaining": float(e["burn_until"]) - _now(), "source": e["burn_source"]}


static func clear(enemy: Object) -> void:
	if enemy == null:
		return
	_state.erase(enemy.get_instance_id())
	_immunity.erase(enemy.get_instance_id())


static func reset() -> void:
	_state.clear()
	_immunity.clear()


static func get_state() -> Dictionary:
	return _state


static func get_runner() -> Node:
	return _runner


static func ensure_runner() -> Node:
	_ensure_runner()
	return _runner


static func _ensure_runner() -> void:
	if _runner != null and is_instance_valid(_runner):
		return # may still be waiting for its deferred add_child
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_runner = StatusEffectsRunner.new()
	_runner.name = "StatusEffectsRunner"
	tree.root.add_child.call_deferred(_runner)
