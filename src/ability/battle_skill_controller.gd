extends Node
class_name BattleSkillController
## v1.0 Battle Skill (docs/31 §3.2-§3.3; Register "v1.0 Combat & Abilities" >
## Battle Skills). One skill per run, chosen by RunConfig.battle_skill_id:
## arrow_storm, frost_nova, firebomb, war_horn. Cast with the `battle_skill`
## action (E / Q / right mouse / pad Y or RB / touch button), or automatically
## when GameSettings.is_auto_cast_enabled() and the cast would be useful.
## Damage scales with the player damage multiplier and Skill Power (meta) via
## AbilityManager.get_skill_damage_multiplier(); area with Blast Radius.
## Group "battle_skill".

signal cast(skill_id: String)

# Register: Battle Skill cooldowns (seconds).
const COOLDOWNS: Dictionary = {"arrow_storm": 16.0, "frost_nova": 13.0, "firebomb": 15.0, "war_horn": 28.0}

# Arrow Storm
const STORM_IMPACTS: int = 10
const STORM_DURATION: float = 1.5
const STORM_SEARCH_RANGE: float = 420.0
const STORM_IMPACT_DAMAGE: float = 35.0
const STORM_IMPACT_RADIUS: float = 64.0
const STORM_SCATTER: float = 70.0 # Register: Arrow Storm scatter radius around the cluster
const STORM_CLUSTER_RADIUS: float = 90.0 # Register: radius used to find the "densest cluster"
# Frost Nova
const NOVA_DAMAGE: float = 40.0
const NOVA_RADIUS: float = 230.0
const NOVA_SLOW: float = 0.60
const NOVA_SLOW_SECONDS: float = 3.0
# Firebomb
const FIREBOMB_RANGE: float = 380.0
const FIREBOMB_DAMAGE: float = 90.0
const FIREBOMB_RADIUS: float = 110.0
const FIREBOMB_BURN_DPS: float = 20.0
const FIREBOMB_BURN_SECONDS: float = 4.0
const FIREBOMB_FLIGHT: float = 0.5 # Register: Firebomb flight time
const FIREBOMB_FUSE: float = 0.25 # Register: Firebomb fuse
# War Horn
const HORN_SECONDS: float = 7.0
const HORN_TOWER_RATE: float = 2.0
const HORN_PLAYER_RATE: float = 1.5
const HORN_PULSE_SECONDS: float = 1.0 # Register: War Horn buff pulse interval (visual)
# Auto-cast (docs/31 §3.3)
const AUTO_MIN_ENEMIES: int = 4
const AUTO_TOWER_HIT_WINDOW: float = 2.0
const AUTO_SEEKER_COUNT: int = 6
const AUTO_SEEKER_RADIUS: float = 300.0
const AUTO_CHECK_SECONDS: float = 0.25 # Register: Auto-cast evaluation interval

var skill_id: String = RunConfig.DEFAULT_BATTLE_SKILL_ID
var _ready_at: float = 0.0
var _player: Node2D = null
var _tower: Node2D = null
var _manager: Node = null
var _pending_impacts: Array[Dictionary] = []
var _buff_until: float = -1.0
var _next_pulse: float = 0.0
var _last_tower_hit: float = -INF
var _tower_health_connected: bool = false
var _was_ready: bool = true
var _next_auto_check: float = 0.0
var _press_for_test: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"battle_skill")
	skill_id = RunConfig.battle_skill_id if COOLDOWNS.has(RunConfig.battle_skill_id) else RunConfig.DEFAULT_BATTLE_SKILL_ID
	_rng = AbilityDamage.keyed_rng("battle_skill")
	_ready_at = SimClock.now


func set_skill_id_for_test(id: String) -> void:
	skill_id = id


func set_player_for_test(p: Node2D) -> void:
	_player = p


func set_tower_for_test(t: Node2D) -> void:
	_tower = t


func press_for_test() -> void:
	_press_for_test = true


# --- queries --------------------------------------------------------------------

func _cooldown_total() -> float:
	var mgr: Node = _get_manager()
	var mult: float = mgr.get_skill_cooldown_multiplier() if mgr != null else 1.0
	return float(COOLDOWNS.get(skill_id, 16.0)) * mult


func get_state() -> Dictionary:
	var remaining: float = maxf(0.0, _ready_at - SimClock.now)
	return {"skill_id": skill_id, "cooldown_remaining": remaining, "cooldown_total": _cooldown_total(), "ready": remaining <= 0.0}


func is_buff_active() -> bool:
	return SimClock.now < _buff_until


# --- casting --------------------------------------------------------------------

func try_cast() -> bool:
	var player: Node2D = _get_player()
	if player == null or SimClock.now < _ready_at:
		return false
	if player.has_method("is_dead") and player.is_dead():
		return false
	var ok: bool = false
	match skill_id:
		"arrow_storm":
			ok = _cast_arrow_storm(player)
		"frost_nova":
			ok = _cast_frost_nova(player)
		"firebomb":
			ok = _cast_firebomb(player)
		"war_horn":
			ok = _cast_war_horn(player)
	if not ok:
		return false
	_ready_at = SimClock.now + _cooldown_total()
	_was_ready = false
	CombatStats.add_run_counter("skills_cast")
	EventBus.emit_battle_skill_cast(skill_id)
	cast.emit(skill_id)
	return true


func _skill_damage(base: float) -> float:
	var mgr: Node = _get_manager()
	return base * (mgr.get_skill_damage_multiplier() if mgr != null else 1.0)


func _fx_parent(player: Node2D) -> Node:
	return player.get_parent() if player.get_parent() != null else self


func _cast_arrow_storm(player: Node2D) -> bool:
	var cluster: Dictionary = AbilityDamage.densest_cluster(player.global_position, STORM_SEARCH_RANGE, STORM_CLUSTER_RADIUS)
	if cluster.is_empty():
		return false # nothing to shoot at: do not burn the cooldown
	var center: Vector2 = cluster["position"]
	var now: float = SimClock.now
	for i in STORM_IMPACTS:
		var offset: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * (STORM_SCATTER * sqrt(_rng.randf()))
		_pending_impacts.append({"at": now + STORM_DURATION * float(i) / float(STORM_IMPACTS), "pos": center + offset})
	GroundTelegraph.spawn(_fx_parent(player), center, STORM_SCATTER + STORM_IMPACT_RADIUS * 0.5, STORM_DURATION, Color(0.95, 0.8, 0.35))
	Sfx.play("bow_shot", center)
	return true


func _storm_impact(pos: Vector2, damage: float, radius: float) -> void:
	AbilityDamage.hit_area(pos, radius, damage, AbilityIds.ARROW_STORM, &"player", true)


func _cast_frost_nova(player: Node2D) -> bool:
	var radius: float = NOVA_RADIUS * AbilityDamage.area_scale()
	var amount: float = _skill_damage(NOVA_DAMAGE)
	PulseRing.spawn(_fx_parent(player), player.global_position, radius, 0.5, Color(0.55, 0.85, 1.0), 6.0)
	Sfx.play("frost", player.global_position)
	for e in AbilityDamage.enemies_in_radius(player.global_position, radius):
		if AbilityDamage.hit(e, amount, AbilityIds.FROST_NOVA, &"player", true) > 0.0:
			StatusEffects.apply_slow(e, NOVA_SLOW, NOVA_SLOW_SECONDS)
	return true


func _cast_firebomb(player: Node2D) -> bool:
	var radius: float = FIREBOMB_RADIUS * AbilityDamage.area_scale()
	var cluster: Dictionary = AbilityDamage.densest_cluster(player.global_position, FIREBOMB_RANGE, radius)
	if cluster.is_empty():
		return false
	var amount: float = _skill_damage(FIREBOMB_DAMAGE)
	var burn_dps: float = _skill_damage(FIREBOMB_BURN_DPS)
	var parent: Node = _fx_parent(player)
	LobbedBomb.spawn(parent, "dynamite", player.global_position, cluster["position"], FIREBOMB_FLIGHT, FIREBOMB_FUSE, radius, func(pos: Vector2) -> void:
		ExplosionFx.spawn(parent, pos, radius)
		Sfx.play("explosion", pos)
		AbilityDamage.hit_area(pos, radius, amount, AbilityIds.FIREBOMB, &"player", true)
		BurningGround.spawn(parent, pos, radius, burn_dps, FIREBOMB_BURN_SECONDS, AbilityIds.FIREBOMB), Color(1.0, 0.4, 0.1))
	return true


func _cast_war_horn(player: Node2D) -> bool:
	var tower: Node2D = _get_tower()
	if tower != null and tower.get("health") != null:
		tower.health.restore_shield()
		if tower.get("weapon") != null:
			tower.weapon.set_buff_fire_rate_multiplier(HORN_TOWER_RATE)
	var weapon: Node = player.get_node_or_null("AutoWeapon")
	if weapon != null and weapon.has_method("set_buff_fire_rate_multiplier"):
		weapon.set_buff_fire_rate_multiplier(HORN_PLAYER_RATE)
	_buff_until = SimClock.now + HORN_SECONDS
	_next_pulse = SimClock.now + HORN_PULSE_SECONDS
	_pulse_horn(player, tower, 240.0)
	Sfx.play("wave_horn", player.global_position)
	return true


func _pulse_horn(player: Node2D, tower: Node2D, radius: float) -> void:
	var gold := Color(1.0, 0.85, 0.3)
	var parent: Node = _fx_parent(player)
	PulseRing.spawn(parent, player.global_position, radius * 0.6, 0.7, gold, 5.0)
	if tower != null:
		PulseRing.spawn(parent, tower.global_position, radius, 0.7, gold, 6.0)


func _end_horn() -> void:
	_buff_until = -1.0
	var tower: Node2D = _get_tower()
	if tower != null and tower.get("weapon") != null:
		tower.weapon.set_buff_fire_rate_multiplier(1.0)
	var player: Node2D = _get_player()
	var weapon: Node = player.get_node_or_null("AutoWeapon") if player != null else null
	if weapon != null and weapon.has_method("set_buff_fire_rate_multiplier"):
		weapon.set_buff_fire_rate_multiplier(1.0)


# --- per-tick -------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	var now: float = SimClock.now
	_connect_tower_health()
	# Scheduled Arrow Storm impacts.
	if not _pending_impacts.is_empty():
		var player: Node2D = _get_player()
		var parent: Node = _fx_parent(player) if player != null else self
		var damage: float = _skill_damage(STORM_IMPACT_DAMAGE)
		var radius: float = STORM_IMPACT_RADIUS * AbilityDamage.area_scale()
		var keep: Array[Dictionary] = []
		for imp in _pending_impacts:
			if now >= float(imp["at"]):
				FallingArrow.spawn(parent, imp["pos"], func(pos: Vector2) -> void: _storm_impact(pos, damage, radius))
			else:
				keep.append(imp)
		_pending_impacts = keep
	# War Horn buff expiry and golden pulses.
	if _buff_until > 0.0:
		if now >= _buff_until:
			_end_horn()
		elif now >= _next_pulse:
			_next_pulse = now + HORN_PULSE_SECONDS
			var p: Node2D = _get_player()
			if p != null:
				_pulse_horn(p, _get_tower(), 200.0)
	# Ready cue.
	if not _was_ready and now >= _ready_at:
		_was_ready = true
		Sfx.play_ui("skill_ready")
	# Input and auto-cast.
	if _press_for_test or Input.is_action_just_pressed(&"battle_skill"):
		_press_for_test = false
		try_cast()
	elif now >= _ready_at and now >= _next_auto_check and GameSettings.is_auto_cast_enabled():
		_next_auto_check = now + AUTO_CHECK_SECONDS
		if auto_cast_is_useful():
			try_cast()


## docs/31 §3.3: damage skills need 4+ enemies in the target area; War Horn needs
## the Tower to have lost health in the last 2 s or 6+ Seekers near the Tower.
func auto_cast_is_useful() -> bool:
	var player: Node2D = _get_player()
	if player == null:
		return false
	match skill_id:
		"arrow_storm":
			var c: Dictionary = AbilityDamage.densest_cluster(player.global_position, STORM_SEARCH_RANGE, STORM_CLUSTER_RADIUS)
			return not c.is_empty() and int(c["count"]) >= AUTO_MIN_ENEMIES
		"frost_nova":
			return AbilityDamage.enemies_in_radius(player.global_position, NOVA_RADIUS * AbilityDamage.area_scale()).size() >= AUTO_MIN_ENEMIES
		"firebomb":
			var c2: Dictionary = AbilityDamage.densest_cluster(player.global_position, FIREBOMB_RANGE, FIREBOMB_RADIUS * AbilityDamage.area_scale())
			return not c2.is_empty() and int(c2["count"]) >= AUTO_MIN_ENEMIES
		"war_horn":
			var tower: Node2D = _get_tower()
			if tower == null:
				return false
			if SimClock.now - _last_tower_hit <= AUTO_TOWER_HIT_WINDOW:
				return true
			return EntityRegistry.get_entities_in_radius(tower.global_position, AUTO_SEEKER_RADIUS, &"tower_seeker").size() >= AUTO_SEEKER_COUNT
	return false


# --- lookups ----------------------------------------------------------------------

func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D if is_inside_tree() else null
	return _player


func _get_tower() -> Node2D:
	if _tower == null or not is_instance_valid(_tower):
		_tower = get_tree().get_first_node_in_group(&"tower") as Node2D if is_inside_tree() else null
	return _tower


func _get_manager() -> Node:
	if _manager == null or not is_instance_valid(_manager):
		_manager = get_tree().get_first_node_in_group(&"ability_manager") if is_inside_tree() else null
	return _manager


func _connect_tower_health() -> void:
	if _tower_health_connected:
		return
	var t: Node2D = _get_tower()
	if t == null or t.get("health") == null:
		return
	_tower_health_connected = true
	var last: Array = [t.health.get_current_health()]
	t.health.health_changed.connect(func(cur: float, _mx: float) -> void:
		if cur < float(last[0]):
			_last_tower_hit = SimClock.now
		last[0] = cur)
