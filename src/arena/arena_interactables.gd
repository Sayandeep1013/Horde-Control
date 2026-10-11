extends Node2D
class_name ArenaInteractables
## Arena interactables manager (Register "v1.0 Arena Interactables", docs/32 section B). Group
## "arena_interactables". On EventBus.wave_started it spawns Supply Crates, Powder
## Kegs and a Shrine within the caps, at positions sampled with KeyedRng on the run
## seed (`[run_seed, "arena", wave, serial]`) on walkable ground, and it owns the four
## fixed Spike Traps (data/arena/spike_traps.tres). It drives player contact for
## crates, kegs and the shrine, rolls crate drops, and owns the active Shrine
## boons: they multiply with Draft / meta values (separate boon terms on the
## weapon, player and Tower health) and expire on SimClock.
##
## Crates, kegs and the shrine are children of the Entities container (y-sorted
## with units); traps are children of this node, whose z_index puts them on the
## ground under the entities.

const CRATE_FIRST_WAVE: int = 2 # Register "v1.0 Arena Interactables": every spawn rule below
const CRATES_PER_WAVE: int = 3
const CRATE_CAP: int = 6
const KEG_FIRST_WAVE: int = 3
const KEG_LATE_WAVE: int = 9
const KEGS_PER_WAVE: int = 1
const KEGS_PER_WAVE_LATE: int = 2
const KEG_CAP: int = 3
const SHRINE_FIRST_WAVE: int = 2
const MIN_TOWER_DISTANCE_PX: float = 180.0
const MIN_PLAYER_DISTANCE_PX: float = 120.0
const MIN_SPACING_PX: float = 90.0
const FIELD_MAX_RADIUS_PX: float = 1100.0 # crates and kegs sample within this of the Tower
const SHRINE_MIN_RADIUS_PX: float = 400.0
const SHRINE_MAX_RADIUS_PX: float = 850.0
const PLACEMENT_ATTEMPTS: int = 40
const DROP_SCRAP_CHANCE: float = 0.55
const DROP_MEAT_CHANCE: float = 0.25 # the remaining 0.20 is XP
const DROP_SCRAP_AMOUNT: int = 8
const DROP_XP_AMOUNT: int = 5
const GROUND_Z_INDEX: int = 5 # above the arena floor (0) and below pickups (10) and entities (20)

@export var pickup_system_path: NodePath = ^"../PickupSystem"
@export var entities_path: NodePath = ^"../Entities"
@export var arena_path: NodePath = ^"../Environment/ArenaInstance"
@export var spike_layout: ArenaSpikeLayout = preload("res://data/arena/spike_traps.tres")
var run_seed: int = 0
var tower_position: Vector2 = Vector2.ZERO

var _map: ArenaSpawnMap = null
var _crates: Array[ArenaCrate] = []
var _kegs: Array[ArenaKeg] = []
var _traps: Array[ArenaSpikeTrap] = []
var _shrine: ArenaShrine = null
var _serial: int = 0
var _drop_serial: int = 0
var _boons: Dictionary = {} # boon id -> {"expires": float, "total": float} or {"kills_left": int}
var _prev_player_pos: Vector2 = Vector2.INF
var _pickup_system: Node = null
var _entities: Node = null


func _ready() -> void:
	z_index = GROUND_Z_INDEX
	add_to_group(&"arena_interactables")
	_entities = get_node_or_null(entities_path)
	_pickup_system = get_node_or_null(pickup_system_path)
	if _pickup_system != null and "scrap_multiplier_provider" in _pickup_system:
		_pickup_system.scrap_multiplier_provider = Callable(self, "_consume_bounty_kill")
	EventBus.wave_started.connect(_on_wave_started)
	spawn_traps()


func _exit_tree() -> void:
	if EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.disconnect(_on_wave_started)
	if _pickup_system != null and is_instance_valid(_pickup_system) and "scrap_multiplier_provider" in _pickup_system:
		var provider: Callable = _pickup_system.scrap_multiplier_provider
		if provider.is_valid() and provider.get_object() == self:
			_pickup_system.scrap_multiplier_provider = Callable()


# --- map and placement -------------------------------------------------------

func set_map_for_test(map: ArenaSpawnMap) -> void:
	_map = map


func set_pickup_system_for_test(node: Node) -> void:
	_pickup_system = node


func get_map() -> ArenaSpawnMap:
	if _map == null:
		var arena: Node = get_node_or_null(arena_path)
		if arena != null:
			_map = ArenaSpawnMap.from_arena(arena)
	return _map


func _container() -> Node:
	return _entities if _entities != null else self


## Builds the four plates from the layout (positions are world coordinates; the arena sits at the origin).
func spawn_traps() -> void:
	if spike_layout == null or not _traps.is_empty():
		return
	for i in spike_layout.positions.size():
		var trap := ArenaSpikeTrap.new()
		if i < spike_layout.phase_offsets.size():
			trap.phase_offset = spike_layout.phase_offsets[i]
		add_child(trap)
		trap.global_position = spike_layout.positions[i]
		_traps.append(trap)


func get_traps() -> Array[ArenaSpikeTrap]:
	return _traps


func _player_position() -> Vector2:
	var p: Node2D = ArenaHits.get_player()
	return p.global_position if p != null else Vector2.INF


func _all_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c in _crates:
		out.append(c.global_position)
	for k in _kegs:
		out.append(k.global_position)
	if _shrine != null and is_instance_valid(_shrine) and not _shrine.is_claimed and not _shrine.is_expired:
		out.append(_shrine.global_position)
	for t in _traps:
		out.append(t.global_position)
	return out


## Samples one valid position. `rng` is advanced, so the caller can keep drawing from it.
## Returns Vector2.INF when no valid point was found in PLACEMENT_ATTEMPTS.
func sample_position(rng: RandomNumberGenerator, min_radius: float, max_radius: float) -> Vector2:
	var map: ArenaSpawnMap = get_map()
	if map == null:
		return Vector2.INF
	var player_pos: Vector2 = _player_position()
	var others: Array[Vector2] = _all_positions()
	for _i in PLACEMENT_ATTEMPTS:
		var angle: float = rng.randf() * TAU
		var radius: float = lerpf(min_radius, max_radius, sqrt(rng.randf()))
		var p: Vector2 = tower_position + Vector2.from_angle(angle) * radius
		if not map.is_walkable(p):
			continue
		if player_pos != Vector2.INF and p.distance_to(player_pos) < MIN_PLAYER_DISTANCE_PX:
			continue
		var ok: bool = true
		for o in others:
			if p.distance_to(o) < MIN_SPACING_PX:
				ok = false
				break
		if ok:
			return p
	return Vector2.INF


func _rng_for(wave: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = KeyedRng.rng_for([run_seed, "arena", wave, _serial])
	_serial += 1
	return rng


func _prune() -> void:
	var crates: Array[ArenaCrate] = []
	for c in _crates:
		if is_instance_valid(c) and not c.is_broken:
			crates.append(c)
	_crates = crates
	var kegs: Array[ArenaKeg] = []
	for k in _kegs:
		if is_instance_valid(k) and not k.has_exploded:
			kegs.append(k)
	_kegs = kegs
	if _shrine != null and not is_instance_valid(_shrine):
		_shrine = null


func get_crates() -> Array[ArenaCrate]:
	_prune()
	return _crates


func get_kegs() -> Array[ArenaKeg]:
	_prune()
	return _kegs


func get_shrine() -> ArenaShrine:
	_prune()
	return _shrine


# --- wave spawning -----------------------------------------------------------

func _on_wave_started(wave_number: int, _wave_count: int, _wave_type: String, _is_boss: bool, _timestamp: float) -> void:
	spawn_for_wave(wave_number)


## Spawns this wave's objects within the caps. Crates and kegs stay until used; the
## previous Shrine (if still unclaimed) is replaced.
func spawn_for_wave(wave: int) -> void:
	_prune()
	if tower_position == Vector2.ZERO:
		var towers: Array[Node2D] = EntityRegistry.get_entities_with_tag(&"tower")
		if not towers.is_empty() and is_instance_valid(towers[0]):
			tower_position = towers[0].global_position
	if wave >= CRATE_FIRST_WAVE:
		for _i in mini(CRATES_PER_WAVE, CRATE_CAP - _crates.size()):
			var rng: RandomNumberGenerator = _rng_for(wave)
			var p: Vector2 = sample_position(rng, MIN_TOWER_DISTANCE_PX, FIELD_MAX_RADIUS_PX)
			if p != Vector2.INF:
				add_crate(p)
	if wave >= KEG_FIRST_WAVE:
		var per_wave: int = KEGS_PER_WAVE_LATE if wave >= KEG_LATE_WAVE else KEGS_PER_WAVE
		for _i in mini(per_wave, KEG_CAP - _kegs.size()):
			var rng: RandomNumberGenerator = _rng_for(wave)
			var p: Vector2 = sample_position(rng, MIN_TOWER_DISTANCE_PX, FIELD_MAX_RADIUS_PX)
			if p != Vector2.INF:
				add_keg(p)
	if wave >= SHRINE_FIRST_WAVE:
		if _shrine != null and is_instance_valid(_shrine) and not _shrine.is_claimed:
			_shrine.queue_free()
			_shrine = null
		var rng: RandomNumberGenerator = _rng_for(wave)
		var p: Vector2 = sample_position(rng, SHRINE_MIN_RADIUS_PX, SHRINE_MAX_RADIUS_PX)
		if p != Vector2.INF:
			add_shrine(p, ArenaBoon.IDS[rng.randi_range(0, ArenaBoon.IDS.size() - 1)])


func add_crate(world_position: Vector2) -> ArenaCrate:
	var c := ArenaCrate.new()
	_container().add_child(c)
	c.global_position = world_position
	c.broken.connect(_on_crate_broken)
	_crates.append(c)
	return c


func add_keg(world_position: Vector2) -> ArenaKeg:
	var k := ArenaKeg.new()
	_container().add_child(k)
	k.global_position = world_position
	_kegs.append(k)
	return k


func add_shrine(world_position: Vector2, boon_id: String) -> ArenaShrine:
	var s := ArenaShrine.new()
	s.boon_id = boon_id
	_container().add_child(s)
	s.global_position = world_position
	s.claimed.connect(_on_shrine_claimed)
	_shrine = s
	return s


## Capture/dev helper: one of each object in a ring around `center`, ignoring the spawn rules.
func dev_spawn_showcase(center: Vector2, boon_id: String = ArenaBoon.WAR) -> void:
	add_crate(center + Vector2(-190, 90))
	add_crate(center + Vector2(-120, 150))
	add_keg(center + Vector2(190, 90))
	add_shrine(center + Vector2(0, 200), boon_id)


# --- drops -------------------------------------------------------------------

func _on_crate_broken(_crate: ArenaCrate, pos: Vector2, _by: String) -> void:
	var kind: String = drop_kind_for(_drop_serial)
	_drop_serial += 1
	if _pickup_system == null or not _pickup_system.has_method(&"spawn_crate_drop"):
		return
	_pickup_system.spawn_crate_drop(kind, DROP_XP_AMOUNT if kind == "xp" else (DROP_SCRAP_AMOUNT if kind == "scrap" else 0), pos)


## The drop the crate broken as roll number `serial` gives: "scrap", "meat" or "xp".
func drop_kind_for(serial: int) -> String:
	var roll: float = KeyedRng.rng_for([run_seed, "arena_drop", serial]).randf()
	if roll < DROP_SCRAP_CHANCE:
		return "scrap"
	if roll < DROP_SCRAP_CHANCE + DROP_MEAT_CHANCE:
		return "meat"
	return "xp"


# --- per-tick contact --------------------------------------------------------

func _physics_process(_delta: float) -> void:
	step()


## One tick: crate/keg contact along the player's swept path, shrine fill, boon expiry.
func step() -> void:
	var player: Node2D = ArenaHits.get_player()
	if player != null:
		var prev: Vector2 = _prev_player_pos if _prev_player_pos != Vector2.INF else player.global_position
		for c in _crates.duplicate():
			if is_instance_valid(c):
				c.check_player(player, prev)
		for k in _kegs.duplicate():
			if is_instance_valid(k):
				k.check_player(player, prev)
		if _shrine != null and is_instance_valid(_shrine):
			_shrine.check_player(player)
		_prev_player_pos = player.global_position
	update_boons()


# --- boons -------------------------------------------------------------------

func _on_shrine_claimed(_shrine_node: ArenaShrine, boon_id: String) -> void:
	claim_boon(boon_id)


func claim_boon(id: String) -> void:
	if not ArenaBoon.IDS.has(id):
		return
	if id == ArenaBoon.BOUNTY:
		_boons[id] = {"kills_left": ArenaBoon.BOUNTY_KILLS}
	else:
		_boons[id] = {"expires": SimClock.now + ArenaBoon.DURATION_SECONDS, "total": ArenaBoon.DURATION_SECONDS}
	if id == ArenaBoon.WARD:
		var tower: Node = get_tree().get_first_node_in_group(&"tower")
		var health: Variant = tower.get("health") if tower != null else null
		if health != null:
			health.restore_shield()
	_apply_boons()


func has_boon(id: String) -> bool:
	return _boons.has(id)


## [{id, remaining (seconds, 0 for Bounty), total, kills_left (Bounty only)}], oldest claim first.
func get_active_boons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _boons.keys():
		var b: Dictionary = _boons[id]
		if id == ArenaBoon.BOUNTY:
			out.append({"id": id, "remaining": 0.0, "total": 0.0, "kills_left": int(b["kills_left"])})
		else:
			out.append({"id": id, "remaining": maxf(0.0, float(b["expires"]) - SimClock.now), "total": float(b["total"]), "kills_left": 0})
	return out


func update_boons() -> void:
	var changed: bool = false
	for id in _boons.keys():
		if id != ArenaBoon.BOUNTY and SimClock.now >= float(_boons[id]["expires"]):
			_boons.erase(id)
			changed = true
	if changed:
		_apply_boons()


## Called by PickupSystem once per enemy kill; returns the Scrap multiplier for that kill's drop.
func _consume_bounty_kill() -> int:
	if not _boons.has(ArenaBoon.BOUNTY):
		return 1
	var left: int = int(_boons[ArenaBoon.BOUNTY]["kills_left"]) - 1
	if left <= 0:
		_boons.erase(ArenaBoon.BOUNTY)
	else:
		_boons[ArenaBoon.BOUNTY]["kills_left"] = left
	return ArenaBoon.BOUNTY_SCRAP_MULTIPLIER


## Pushes the active boons into the separate boon terms (1.0 = off). Draft and meta
## setters are untouched, so the two layers multiply.
func _apply_boons() -> void:
	var tree: SceneTree = get_tree()
	var player: Node = tree.get_first_node_in_group(&"player")
	if player != null:
		var weapon: Node = player.get_node_or_null("AutoWeapon")
		if weapon != null and weapon.has_method(&"set_boon_damage_multiplier"):
			weapon.set_boon_damage_multiplier(ArenaBoon.WAR_DAMAGE_MULTIPLIER if _boons.has(ArenaBoon.WAR) else 1.0)
		if player.has_method(&"set_boon_haste"):
			var haste: bool = _boons.has(ArenaBoon.HASTE)
			player.set_boon_haste(ArenaBoon.HASTE_SPEED_MULTIPLIER if haste else 1.0, ArenaBoon.HASTE_DASH_RECHARGE_MULTIPLIER if haste else 1.0)
	var tower: Node = tree.get_first_node_in_group(&"tower")
	var health: Variant = tower.get("health") if tower != null else null
	if health != null:
		health.set_boon_damage_taken_multiplier(ArenaBoon.WARD_TOWER_DAMAGE_TAKEN_MULTIPLIER if _boons.has(ArenaBoon.WARD) else 1.0)
