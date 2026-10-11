extends RefCounted
class_name AbilityDamage
## v1.0 one door for every ability / Battle Skill / burn hit on an enemy
## (docs/31 §4.6). Routes through SimLoop.enqueue_hit like every other damage
## source (docs/20 step 7) and records `CombatStats.record_damage(source_id,
## applied)` once, at hit resolution (the on_hit_accepted callback), never at
## fire time. Crits (Keen Eye) double the amount here so no ability repeats the
## roll. Source passed to the hurtbox is &"player" / &"tower" so the
## Opportunist retarget rule (enemy_controller.gd) keeps working.

const ENEMY_TAG: StringName = &"enemy"
const CRIT_MULTIPLIER: float = 2.0 # Register "v1.0 Combat & Abilities": Crit damage

static var _rng: RandomNumberGenerator = null
## Run seed the keyed streams derive from (set by begin_run at run start).
static var _run_seed: int = 0
static var _serials: Dictionary = {} # purpose -> next serial
## Test seam: -1 = roll normally, 0 = never crit, 1 = always crit.
static var forced_crit: int = -1
static var _manager: Node = null


static func _crit_roll(chance: float) -> bool:
	if forced_crit >= 0:
		return forced_crit == 1
	if chance <= 0.0:
		return false
	if _rng == null:
		_rng = KeyedRng.rng_for([_run_seed, "crit", 0])
	return _rng.randf() < chance


## Run start (PrototypeIntegration, Retry included): the crit stream and every
## per-purpose serial restart from the run seed, so no state carries over.
static func begin_run(run_seed: int) -> void:
	_run_seed = run_seed
	_serials.clear()
	_rng = null


## A fresh stream keyed `[run_seed, purpose, serial]` (Register "Keyed RNG"); the
## serial counts requests per purpose within the run, so two Dynamite Satchel
## nodes (or a re-picked ability) never share a sequence.
static func keyed_rng(purpose: String) -> RandomNumberGenerator:
	var serial: int = int(_serials.get(purpose, 0))
	_serials[purpose] = serial + 1
	return KeyedRng.rng_for([_run_seed, purpose, serial])


## One crit roll at the run's current crit chance (Keen Eye + meta).
static func roll_crit() -> bool:
	var mgr: Node = get_manager()
	return _crit_roll(mgr.get_crit_chance() if mgr != null else 0.0)


static func get_manager() -> Node:
	if _manager != null and is_instance_valid(_manager) and _manager.is_inside_tree():
		return _manager
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	_manager = tree.get_first_node_in_group(&"ability_manager") if tree != null else null
	return _manager


static func get_sim_loop() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(&"sim_loop") if tree != null else null


static func enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	return EntityRegistry.get_entities_in_radius(center, radius, ENEMY_TAG)


static func nearest_enemy(center: Vector2, radius: float, exclude: Array = []) -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	for e in enemies_in_radius(center, radius):
		if exclude.has(e) or not is_instance_valid(e):
			continue
		var d2: float = center.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


## Densest cluster centre: the enemy within `search_radius` of `origin` with the
## most enemies inside `cluster_radius`. Returns {} when there are none.
static func densest_cluster(origin: Vector2, search_radius: float, cluster_radius: float) -> Dictionary:
	var candidates: Array[Node2D] = enemies_in_radius(origin, search_radius)
	var best_pos: Vector2 = Vector2.ZERO
	var best_count: int = 0
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var count: int = 0
		for o in candidates:
			if is_instance_valid(o) and o.global_position.distance_squared_to(c.global_position) <= cluster_radius * cluster_radius:
				count += 1
		if count > best_count:
			best_count = count
			best_pos = c.global_position
	if best_count == 0:
		return {}
	return {"position": best_pos, "count": best_count}


static func is_enemy_alive(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var ds: Variant = enemy.get("death_state")
	return not (ds != null and ds.is_dead)


## Queue one hit. Returns the amount queued, crit included (0.0 if the target
## cannot be hit). `allow_crit` is true for player arrows and player abilities
## (docs/31 §4.4 Keen Eye); never for the Tower or burn ticks.
static func hit(enemy: Node, amount: float, source_id: String, side: StringName = &"player", allow_crit: bool = false) -> float:
	if amount <= 0.0 or not is_enemy_alive(enemy):
		return 0.0
	var hurtbox: Variant = enemy.get("hurtbox")
	if hurtbox == null or not is_instance_valid(hurtbox):
		return 0.0
	if allow_crit:
		if roll_crit():
			amount *= CRIT_MULTIPLIER
	var ds: Variant = enemy.get("death_state")
	# No overkill in the damage report: cap by the HP the target had when the hit
	# was queued (DeathState clamps HP at 0, so it cannot be recovered afterwards).
	var applied: float = minf(amount, maxf(0.0, ds.current_hp)) if ds != null else amount
	var record: Callable = func() -> void: CombatStats.record_damage(source_id, applied)
	var loop: Node = get_sim_loop()
	if loop != null:
		loop.enqueue_hit(loop.get_combat_serial(side), loop.get_combat_serial(enemy), amount, side, hurtbox, null, record)
	elif (hurtbox as Hurtbox).receive_hit(null, amount, side):
		record.call()
	return amount


## Area helper: hit every enemy within `radius` of `center`. Returns the number hit.
static func hit_area(center: Vector2, radius: float, amount: float, source_id: String, side: StringName = &"player", allow_crit: bool = false) -> int:
	var n: int = 0
	for e in enemies_in_radius(center, radius):
		if hit(e, amount, source_id, side, allow_crit) > 0.0:
			n += 1
	return n


static func area_scale() -> float:
	var mgr: Node = get_manager()
	return mgr.get_area_multiplier() if mgr != null else 1.0


## Player-side ability damage multiplier: arrows' damage multiplier (Heavy
## Rounds) times War Training and the meta Engineers-style hooks.
static func player_ability_mult() -> float:
	var mgr: Node = get_manager()
	return mgr.get_player_ability_damage_multiplier() if mgr != null else 1.0


static func tower_ability_mult() -> float:
	var mgr: Node = get_manager()
	return mgr.get_tower_ability_damage_multiplier() if mgr != null else 1.0


static func reset() -> void:
	forced_crit = -1
	_manager = null
	_rng = null
	_run_seed = 0
	_serials.clear()
