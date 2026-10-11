extends Node2D
class_name TowerRepair
## v1.0 Tower repair (docs/31 §3.4; revises D115; Register "v1.0 Combat &
## Abilities" > Tower repair). While the player stands inside the Tower's
## Interaction Radius, carried Scrap drains into the Tower at SCRAP_PER_SECOND;
## each Scrap restores HEALTH_PER_SCRAP Tower health (x Stone Mason and the
## meta Mason's Kit via AbilityManager.get_repair_multiplier()). Repair only runs
## while Tower health is below max and never refills the shield. Group
## "tower_repair". It is a movement verb: no menu, no pause.

const SCRAP_PER_SECOND: float = 8.0
const HEALTH_PER_SCRAP: float = 3.0
const TICK_SFX_MAX_PER_SECOND: float = 6.0
const RING_RADIUS_FALLBACK_PX: float = 160.0

@export var tower_path: NodePath = NodePath("../Tower")
@export var pickup_system_path: NodePath = NodePath("../PickupSystem")

var _tower: Node2D = null
var _inventory: RunInventory = null
var _carry: float = 0.0
var _repairing: bool = false
var _last_sfx_at: float = -INF
var _glow: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"tower_repair")
	z_as_relative = false
	z_index = 39
	top_level = true
	call_deferred("_register_with_sim_loop")


func _register_with_sim_loop() -> void:
	var loop: Node = get_tree().get_first_node_in_group(&"sim_loop") if is_inside_tree() else null
	if loop != null and loop.has_method("register"):
		driven_externally = true
		loop.register(SimLoop.Step.PICKUP_MOVEMENT_AND_COLLECTION, self)


## When true, SimLoop calls physics_step(); otherwise _physics_process does.
var driven_externally: bool = false


func set_tower_for_test(t: Node2D) -> void:
	_tower = t


func set_run_inventory_for_test(inv: RunInventory) -> void:
	_inventory = inv


func is_repairing() -> bool:
	return _repairing


func _get_tower() -> Node2D:
	if _tower == null or not is_instance_valid(_tower):
		_tower = get_node_or_null(tower_path) as Node2D
		if _tower == null and is_inside_tree():
			_tower = get_tree().get_first_node_in_group(&"tower") as Node2D
	return _tower


func _get_inventory() -> RunInventory:
	if _inventory == null:
		var ps: Node = get_node_or_null(pickup_system_path)
		if ps != null and ps.get("run_inventory") != null:
			_inventory = ps.run_inventory
	return _inventory


func _repair_multiplier() -> float:
	var mgr: Node = get_tree().get_first_node_in_group(&"ability_manager") if is_inside_tree() else null
	return mgr.get_repair_multiplier() if mgr != null else 1.0


func _physics_process(delta: float) -> void:
	if not driven_externally:
		physics_step(delta)


func physics_step(delta: float) -> void:
	var tower: Node2D = _get_tower()
	var inv: RunInventory = _get_inventory()
	_repairing = false
	if tower == null or inv == null or tower.get("health") == null or tower.get("interaction_radius") == null:
		return
	var health: TowerHealth = tower.health
	if health.is_destroyed() or health.get_current_health() >= health.max_health or inv.scrap_current <= 0:
		_carry = 0.0
		return
	if not tower.interaction_radius.is_player_inside():
		_carry = 0.0
		return
	var per_scrap: float = HEALTH_PER_SCRAP * _repair_multiplier()
	_carry += SCRAP_PER_SECOND * delta
	var whole: int = int(_carry)
	if whole <= 0:
		_repairing = true
		return
	_carry -= float(whole)
	var missing: float = health.max_health - health.get_current_health()
	whole = mini(whole, mini(inv.scrap_current, ceili(missing / per_scrap)))
	if whole <= 0 or not inv.spend_scrap(whole):
		return
	var before: float = health.get_current_health()
	health.heal(float(whole) * per_scrap)
	var restored: float = health.get_current_health() - before
	_repairing = true
	_glow = 1.0
	CombatStats.add_run_counter("tower_repaired", restored)
	CombatStats.add_run_counter("scrap_repaired", float(whole))
	EventBus.emit_tower_repaired(restored, whole)
	var now: float = SimClock.now
	if now - _last_sfx_at >= 1.0 / TICK_SFX_MAX_PER_SECOND:
		_last_sfx_at = now
		Sfx.play("repair_tick", tower.global_position)


func _process(delta: float) -> void:
	var fade_target: float = 1.0 if _repairing else 0.0
	_glow = move_toward(_glow, fade_target, delta * 4.0)
	var tower: Node2D = _get_tower()
	if tower != null:
		global_position = tower.global_position
	queue_redraw()


func _radius() -> float:
	var tower: Node2D = _get_tower()
	if tower != null and tower.get("interaction_radius") != null:
		var shape: CollisionShape2D = tower.interaction_radius.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape != null and shape.shape is CircleShape2D:
			return (shape.shape as CircleShape2D).radius
	return RING_RADIUS_FALLBACK_PX


## A glowing ring on the radius while repairing (docs/31 §3.4).
func _draw() -> void:
	if _glow <= 0.01:
		return
	var r: float = _radius()
	var pulse: float = 0.5 + 0.5 * sin(SimClock.now * 8.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r, Color(0.45, 1.0, 0.55, 0.07 * _glow))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(0.45, 1.0, 0.55, (0.45 + 0.35 * pulse) * _glow), 6.0, false)
	draw_arc(Vector2.ZERO, r - 8.0, 0.0, TAU, 72, Color(0.85, 1.0, 0.85, 0.35 * _glow), 2.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
