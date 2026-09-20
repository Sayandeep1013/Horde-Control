extends GdUnitTestSuite

## Split Assault test (P2.8 named acceptance test, never built as its own
## dedicated suite -- phases/PHASE_03_.../evidence/p28_report.md, Deferred
## item 11: "neither was built as its own dedicated, falsified acceptance
## suite ... Named here so it is not mistaken for done"). MASTER_SDLC.md >
## Acceptance Test Matrix > Encounter Tests > "Split Assault test": "P2.8
## result over 20 generated Split Assaults (lane assignment and centre
## separation)". docs/11_Wave_Director.md > "Directional Weighting" >
## "Split Assault"; MASTER_SDLC.md > Provisional Values Register >
## "Directional weighting" > Split Assault row (C-LANES).
##
## 20 GENERATED scenarios: a fresh WaveDirector, a fresh run_seed, and a
## different group size `n` per scenario (so this is not special-cased to
## one fixed spawn count), driven end to end through the REAL
## src/director/spawn_geometry.gd + wave_director.gd spawn path (not a
## direct SpawnGeometry-only unit call), asserting BOTH named checks: (1)
## lane assignment -- ceil(0.6 x n) land in the heavier lane, the rest in
## the lighter one, matching `SpawnGeometry.split_assault_lane_sequence()`'s
## own alternation, verified by the ACTUAL landed bearing, not by re-calling
## that function; (2) centre separation -- the two lanes' centre bearings
## are exactly 180 degrees apart (this project's own fixed interpretation --
## see wave_director.gd's `_base_angle_for()` header comment).

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")

const LANE_WIDTH_DEGREES: float = 40.0 # Register > Directional weighting > Split Assault: "two 40 degree lanes"
const HEAVY_SHARE: float = 0.6 # Register: "60% heavier lane / 40% lighter" (C-LANES)
const ANGLE_TOLERANCE_DEG: float = 0.5 # float/RNG slack, not a design tolerance

var _spawners: Array[Node] = []


func before_test() -> void:
	_spawners.clear()


func after_test() -> void:
	for s in _spawners:
		if s != null:
			s.clear_all_for_test()


func _build_dummy_scene() -> PackedScene:
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	packed.pack(n)
	n.free()
	return packed


func _build_director(run_seed: int) -> Dictionary:
	var registry: Node = auto_free(EntityRegistryScript.new())
	add_child(registry)
	var clock: Node = auto_free(SimClockScript.new())
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner)
	spawner.set_registry_for_test(registry)
	_spawners.append(spawner)

	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.driven_externally = true
	director.run_seed = run_seed
	add_child(director)
	director.set_registry_for_test(registry)
	director.set_sim_clock_for_test(clock)
	director.set_entity_spawner_for_test(spawner)

	var dummy: PackedScene = _build_dummy_scene()
	director.tower_seeker_scene = dummy
	director.player_hunter_scene = dummy
	director.opportunist_scene = dummy

	return {"registry": registry, "clock": clock, "spawner": spawner, "director": director}


var _heavy_bearings_deg: Array[float] = []
var _light_bearings_deg: Array[float] = []


func _run_one_split_assault(run_seed: int, n: int) -> void:
	var group: SpawnGroup = SpawnGroup.new()
	group.enemy_definition_id = "tower_seeker" # Tower ring -- the lane rule's own primary case (C-LANES)
	group.count = n
	group.start_offset_seconds = 0.0
	group.spawn_interval_seconds = 0.05
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = "sa_encounter_%d" % run_seed
	encounter.encounter_type = ContractEnums.EncounterType.SplitAssault
	encounter.spawn_groups = [group]
	encounter.minimum_recovery_gap_seconds = 8.0
	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "sa_wave_%d" % run_seed
	wave.encounter_sequence = [encounter.unique_id]
	wave.maximum_duration_seconds = 1000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0

	var ctx: Dictionary = _build_director(run_seed)
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	director.waves = [wave]
	director.encounter_definitions = [encounter]
	director.rebuild_lookups_for_test()

	var positions: Array[Vector2] = []
	director.enemy_spawned.connect(func(_i: Node2D, _id: String, position: Vector2) -> void: positions.append(position))

	var iterations: int = 0
	while positions.size() < n and iterations < 2000:
		clock.now += 0.05
		director.physics_step(0.05)
		iterations += 1

	assert_int(positions.size()).append_failure_message("seed=%d n=%d: not all %d spawns landed within the iteration budget" % [run_seed, n, n]).is_equal(n)

	var heavy_count: int = 0
	var light_count: int = 0
	for pos in positions:
		var bearing_deg: float = rad_to_deg(pos.angle()) # Tower ring centred on the Tower, which sits at arena_center = ZERO with no Tower wired
		var dist_from_heavy_centre: float = absf(wrapf(bearing_deg - 0.0, -180.0, 180.0))
		var dist_from_light_centre: float = absf(wrapf(bearing_deg - 180.0, -180.0, 180.0))
		if dist_from_heavy_centre <= LANE_WIDTH_DEGREES * 0.5 + ANGLE_TOLERANCE_DEG:
			heavy_count += 1
			_heavy_bearings_deg.append(bearing_deg)
		elif dist_from_light_centre <= LANE_WIDTH_DEGREES * 0.5 + ANGLE_TOLERANCE_DEG:
			light_count += 1
			_light_bearings_deg.append(bearing_deg)
		else:
			assert_bool(false).append_failure_message("seed=%d n=%d: spawn at bearing %.2f deg fell outside BOTH lane sectors (heavy centre 0, light centre 180, half-width %.1f deg)" % [run_seed, n, bearing_deg, LANE_WIDTH_DEGREES * 0.5]).is_true()

	var expected_heavy: int = int(ceil(HEAVY_SHARE * float(n)))
	assert_int(heavy_count).append_failure_message("seed=%d n=%d: heavy lane got %d, expected ceil(0.6*%d)=%d" % [run_seed, n, heavy_count, n, expected_heavy]).is_equal(expected_heavy)
	assert_int(light_count).append_failure_message("seed=%d n=%d: light lane got %d, expected %d" % [run_seed, n, light_count, n - expected_heavy]).is_equal(n - expected_heavy)


## 20 generated Split Assaults -- varying BOTH the run_seed (RNG draws) and
## the group size n (5 through 24), so this is not special-cased to one
## fixed count or one fixed seed.
func test_20_generated_split_assaults_assign_lanes_correctly_and_keep_centres_180_degrees_apart() -> void:
	for i in 20:
		var run_seed: int = 1000 + i
		var n: int = 5 + i # 5, 6, ..., 24
		_run_one_split_assault(run_seed, n)

	# Centre separation, checked directly against the OBSERVED spawn
	# bearings across all 20 scenarios (not by re-echoing the 0/180
	# constant): the mean heavy bearing and mean light bearing must be
	# ~180 degrees apart. Simple arithmetic means are valid here since every
	# individual bearing is already known to sit within +/-20.5 degrees of
	# its own lane centre (enforced above), so no circular-mean wraparound
	# distortion is possible.
	assert_int(_heavy_bearings_deg.size()).append_failure_message("no heavy-lane spawns recorded across all 20 scenarios").is_greater(0)
	assert_int(_light_bearings_deg.size()).append_failure_message("no light-lane spawns recorded across all 20 scenarios").is_greater(0)
	# CIRCULAR mean (average of unit vectors, then take the angle back out),
	# not a plain arithmetic mean: the light lane is centred exactly ON the
	# +/-180 degree wraparound point, so its own bearings split roughly
	# evenly between "just under +180" and "just over -180"
	# (pos.angle()'s own range is (-180, 180]) -- a plain arithmetic mean of
	# those two clusters would cancel toward 0, not 180, which is a bug in
	# the TEST's own measurement, not in the code under test.
	var heavy_mean: float = rad_to_deg(_circular_mean_rad(_heavy_bearings_deg))
	var light_mean: float = rad_to_deg(_circular_mean_rad(_light_bearings_deg))
	var separation: float = absf(wrapf(light_mean - heavy_mean, -180.0, 180.0))
	# Tolerance of 3 degrees accommodates finite-sample RNG variance around
	# each lane's own uniform +/-20 degree spread (a few hundred draws
	# total, not an infinite population) -- not a design tolerance from the
	# Register, which states the separation as exact.
	assert_float(separation).append_failure_message("lane centre separation across all 20 scenarios was %.2f degrees (heavy mean %.2f, light mean %.2f), expected 180" % [separation, heavy_mean, light_mean]).is_equal_approx(180.0, 3.0)


static func _circular_mean_rad(bearings_deg: Array[float]) -> float:
	var sum_sin: float = 0.0
	var sum_cos: float = 0.0
	for b in bearings_deg:
		var r: float = deg_to_rad(b)
		sum_sin += sin(r)
		sum_cos += cos(r)
	return atan2(sum_sin, sum_cos)
