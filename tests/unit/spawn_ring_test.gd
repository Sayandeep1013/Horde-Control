extends GdUnitTestSuite

## Spawn ring test (P2.8 named acceptance test; MASTER_SDLC.md > Acceptance
## Test Matrix > Encounter Tests > "Spawn ring test": "In 1000 scripted
## spawns, no enemy instantiates inside the camera view margin or the
## Interaction Radius"). docs/11_Wave_Director.md > "Spawn Rings &
## Placement" in full.
##
## Two layers, deliberately kept separate:
##   1. src/director/spawn_geometry.gd's pure functions, tested directly and
##      statistically (1000 candidates) -- this is where the "no enemy
##      instantiates inside the margin or the Interaction Radius" claim is
##      actually falsifiable, and where the alternating-shift and
##      arena-inset rules are tested deterministically against controlled
##      scenarios.
##   2. src/director/wave_director.gd end to end, with a real EntitySpawner
##      and a real EntityRegistry, confirming a Tower Seeker actually lands
##      on the Tower ring and a Player Hunter actually lands on the view
##      ring -- "spawns land on the correct ring for their intent" cannot be
##      proven at the geometry layer alone, since ring SELECTION by intent
##      is wave_director.gd's own logic, not spawn_geometry.gd's.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")

const TOWER_RING_INNER_PX: float = 1331.0
const TOWER_RING_WIDTH_PX: float = 128.0
const CAMERA_MARGIN_PX: float = 64.0
const ARENA_INSET_PX: float = 32.0
const ARENA_HALF_SIZE: Vector2 = Vector2(2400.0, 1600.0) # Register > Arena size: 4800x3200 / 2

var _ring: RingDefinition
var _spawners: Array[Node] = [] # every EntitySpawner _build_director() creates, freed in after_test()


func before_test() -> void:
	_ring = RingDefinition.new()
	_ring.inner_radius_px = int(TOWER_RING_INNER_PX)
	_ring.width_px = int(TOWER_RING_WIDTH_PX)
	_spawners.clear()


## Pool-acquired dummy enemy instances are never parented (these tests wire
## no pool container) and are not tracked by `auto_free()`, so they orphan
## at test teardown unless the owning EntitySpawner is told to release them
## -- matching tests/unit/entity_cap_test.gd's own `after_test()` pattern.
func after_test() -> void:
	for spawner in _spawners:
		if spawner != null:
			spawner.clear_all_for_test()


# --- Layer 1: SpawnGeometry, statistical and deterministic -----------------

## The named test's own literal pass condition, at the geometry layer: 1000
## deterministic candidates (varied ring centre / camera position / arena
## centre so the sample is not degenerate), every VALID result strictly
## outside the camera margin, strictly outside the Interaction Radius, and
## strictly inside the arena inset.
func test_1000_scripted_spawns_that_validate_never_land_in_the_camera_margin_or_interaction_radius_or_outside_the_arena_inset() -> void:
	var tower_center: Vector2 = Vector2.ZERO
	var interaction_radius: float = 160.0
	var arena_center: Vector2 = Vector2.ZERO
	var view_half_size: Vector2 = Vector2(1104.0, 621.0) # half of the Register's largest view, 2208x1242 @ view scale 1.15

	var valid_count: int = 0
	for i in 1000:
		var rng: RandomNumberGenerator = KeyedRng.rng_for(["spawn_ring_test_seed", "spawn", i])
		var angle: float = rng.randf() * TAU
		var radius_fraction: float = rng.randf()
		# Vary the camera position across the arena so the sample exercises
		# many different view-rect placements relative to the (fixed) Tower
		# ring, not just one.
		var camera_offset: Vector2 = Vector2(rng.randf_range(-1800.0, 1800.0), rng.randf_range(-1200.0, 1200.0))
		var view_center: Vector2 = tower_center + camera_offset

		var result: Dictionary = SpawnGeometry.validate_and_shift(
			angle, radius_fraction, _ring, tower_center,
			tower_center, interaction_radius,
			view_center, view_half_size, CAMERA_MARGIN_PX,
			arena_center, ARENA_HALF_SIZE, ARENA_INSET_PX,
			8, 10.0
		)
		if not result.get("valid", false):
			continue
		valid_count += 1
		var pos: Vector2 = result["position"]
		assert_float(pos.distance_to(tower_center)).append_failure_message("spawn %d landed inside the %.1f px Interaction Radius: distance=%.2f" % [i, interaction_radius, pos.distance_to(tower_center)]).is_greater(interaction_radius)
		var dx: float = absf(pos.x - view_center.x)
		var dy: float = absf(pos.y - view_center.y)
		var inside_view_margin: bool = dx <= view_half_size.x + CAMERA_MARGIN_PX and dy <= view_half_size.y + CAMERA_MARGIN_PX
		assert_bool(inside_view_margin).append_failure_message("spawn %d landed inside the camera view + %.0f px margin: pos=%s view_center=%s" % [i, CAMERA_MARGIN_PX, pos, view_center]).is_false()
		var adx: float = absf(pos.x - arena_center.x)
		var ady: float = absf(pos.y - arena_center.y)
		assert_bool(adx <= ARENA_HALF_SIZE.x - ARENA_INSET_PX and ady <= ARENA_HALF_SIZE.y - ARENA_INSET_PX).append_failure_message("spawn %d landed outside the arena inset: pos=%s" % [i, pos]).is_true()

	# Sanity: the ring/view geometry chosen here must actually let SOME
	# candidates validate, or the loop above would be vacuously true.
	assert_int(valid_count).append_failure_message("no candidate validated at all across 1000 draws -- the test's own geometry is degenerate, not proof of correctness").is_greater(500)


## "the validation shift behaves as the Ring validation row specifies when
## the first candidate is rejected" -- a controlled scenario: the original
## candidate (bearing 0) sits inside the camera view; bearing +10 degrees
## does not. The shift must find it on the SECOND attempt, alternating
## direction as specified.
func test_shift_rescues_a_first_candidate_rejected_by_the_camera_view() -> void:
	var tower_center: Vector2 = Vector2.ZERO
	var interaction_radius: float = 160.0
	var arena_center: Vector2 = Vector2.ZERO
	var arena_half: Vector2 = Vector2(10000.0, 10000.0) # generous -- arena inset is not what this test is about
	var radius_fraction: float = 0.5
	var candidate_point: Vector2 = SpawnGeometry.sample_ring_point(_ring, tower_center, 0.0, radius_fraction)

	# A camera view rectangle that covers the original candidate point but
	# not the +10 degree shifted point (which lies further along the ring's
	# circumference at the same radius).
	var view_center: Vector2 = candidate_point
	var view_half_size: Vector2 = Vector2(20.0, 20.0) # tiny -- covers only the immediate vicinity of the original candidate

	var shifted_point: Vector2 = SpawnGeometry.sample_ring_point(_ring, tower_center, deg_to_rad(10.0), radius_fraction)
	assert_float(shifted_point.distance_to(view_center)).append_failure_message("test setup invalid: the +10 degree shifted point must fall OUTSIDE the tiny camera view for this test to prove anything").is_greater(view_half_size.length())

	var result: Dictionary = SpawnGeometry.validate_and_shift(
		0.0, radius_fraction, _ring, tower_center,
		tower_center, interaction_radius,
		view_center, view_half_size, CAMERA_MARGIN_PX,
		arena_center, arena_half, ARENA_INSET_PX,
		8, 10.0
	)

	assert_bool(result.get("valid", false)).append_failure_message("the shift did not rescue a candidate that should have been valid at +10 degrees").is_true()
	assert_bool(result.get("shifted", false)).append_failure_message("result reported as unshifted, but the original candidate was inside the camera view and must have been rejected").is_true()
	assert_int(result.get("attempts", 0)).append_failure_message("expected the SECOND attempt (original, then +10 degrees) to succeed").is_equal(2)
	assert_vector(result["position"]).append_failure_message("shift did not land at the expected +10 degree point").is_equal_approx(shifted_point, Vector2(0.5, 0.5))


## Same mechanism, rejected by the Tower Interaction Radius instead of the
## camera view. Unlike the camera-view case, this needs a ring NOT centred
## on the Tower (the view ring, near the Tower) -- a ring centred ON the
## Tower samples every bearing at the SAME fixed radius from the Tower by
## construction, so no angular shift could ever change whether it is inside
## the Interaction Radius. This is the real, in-scope scenario the rule
## actually matters for: a camera close enough to the Tower that part of
## its view ring dips inside the Interaction Radius.
func test_shift_rescues_a_first_candidate_rejected_by_the_interaction_radius() -> void:
	var tower_center: Vector2 = Vector2.ZERO
	var ring_center: Vector2 = Vector2(500.0, 0.0) # a camera 500 px from the Tower -- close enough that its own ring dips near the Tower on the near side
	var arena_center: Vector2 = Vector2.ZERO
	var arena_half: Vector2 = Vector2(10000.0, 10000.0)
	var radius_fraction: float = 0.5
	var bearing: float = PI # pointing back toward the Tower from the ring's own centre -- the near side of the ring

	var candidate_point: Vector2 = SpawnGeometry.sample_ring_point(_ring, ring_center, bearing, radius_fraction)
	var interaction_radius: float = candidate_point.distance_to(tower_center) + 1.0 # swallows the original bearing by construction
	var shifted_point: Vector2 = SpawnGeometry.sample_ring_point(_ring, ring_center, bearing + deg_to_rad(10.0), radius_fraction)
	assert_float(shifted_point.distance_to(tower_center)).append_failure_message("test setup invalid: +10 degrees off the near side must move measurably further from the Tower").is_greater(interaction_radius)

	var view_center: Vector2 = Vector2(999999.0, 999999.0) # camera-view rectangle placed elsewhere -- isolates the interaction-radius rule from camera exclusion
	var view_half_size: Vector2 = Vector2(10.0, 10.0)

	var result: Dictionary = SpawnGeometry.validate_and_shift(
		bearing, radius_fraction, _ring, ring_center,
		tower_center, interaction_radius,
		view_center, view_half_size, CAMERA_MARGIN_PX,
		arena_center, arena_half, ARENA_INSET_PX,
		8, 10.0
	)

	assert_bool(result.get("valid", false)).append_failure_message("the shift did not rescue a candidate rejected by the Interaction Radius").is_true()
	assert_int(result.get("attempts", 0)).is_equal(2)
	assert_vector(result["position"]).is_equal_approx(shifted_point, Vector2(0.5, 0.5))


## Register > Spawn Rings: "clipped to the arena inset by 32 pixels." A ring
## point that falls past the inset must be rejected even with nothing else
## wrong about it.
func test_candidate_outside_the_arena_inset_is_rejected() -> void:
	var tower_center: Vector2 = Vector2.ZERO
	var arena_center: Vector2 = Vector2.ZERO
	# A tiny arena, smaller than the ring itself, so every ring point falls
	# outside the inset -- isolates the arena-inset rule from the other two.
	var arena_half: Vector2 = Vector2(100.0, 100.0)
	var view_center: Vector2 = Vector2(999999.0, 999999.0)
	var view_half_size: Vector2 = Vector2(1.0, 1.0)
	var interaction_radius: float = 1.0

	var result: Dictionary = SpawnGeometry.validate_and_shift(
		0.0, 0.5, _ring, tower_center,
		tower_center, interaction_radius,
		view_center, view_half_size, CAMERA_MARGIN_PX,
		arena_center, arena_half, ARENA_INSET_PX,
		8, 10.0
	)
	assert_bool(result.get("valid", false)).append_failure_message("a ring far outside a tiny arena's inset must never validate").is_false()


## "if none valid, the spawn is re-queued for the next tick" -- a fully
## blocked ring (the camera view covers everywhere the ring can reach) must
## report invalid rather than picking a bad point.
func test_no_valid_point_after_every_shift_reports_invalid() -> void:
	var tower_center: Vector2 = Vector2.ZERO
	var arena_center: Vector2 = Vector2.ZERO
	var arena_half: Vector2 = Vector2(10000.0, 10000.0)
	# A camera view centred on the Tower, large enough to swallow the whole
	# ring (outer radius ~1459 px) at every bearing.
	var view_center: Vector2 = tower_center
	var view_half_size: Vector2 = Vector2(2000.0, 2000.0)
	var interaction_radius: float = 1.0

	var result: Dictionary = SpawnGeometry.validate_and_shift(
		0.0, 0.5, _ring, tower_center,
		tower_center, interaction_radius,
		view_center, view_half_size, CAMERA_MARGIN_PX,
		arena_center, arena_half, ARENA_INSET_PX,
		8, 10.0
	)
	assert_bool(result.get("valid", false)).append_failure_message("a ring entirely inside the camera view at every bearing must never validate").is_false()
	assert_int(result.get("attempts", 0)).append_failure_message("must have exhausted all 9 checks (the original candidate plus all 8 shifts)").is_equal(9)


## Register > Ring validation, the 8-consecutive-failed-tick escalation:
## "ignore direction weighting and take the nearest valid point on the ring
## instead." Verified directly against nearest_valid_point_on_ring(): a
## blocked arc around the preferred bearing must not prevent a valid point
## elsewhere on the same ring from being found.
func test_nearest_valid_point_on_ring_finds_a_point_outside_a_blocked_arc() -> void:
	var tower_center: Vector2 = Vector2.ZERO
	var arena_center: Vector2 = Vector2.ZERO
	var arena_half: Vector2 = Vector2(10000.0, 10000.0)
	var interaction_radius: float = 1.0
	# Blocks roughly bearings -60..+60 degrees (a camera view east of the
	# Tower, wide enough to cover more than validate_and_shift's own +/-40
	# degree bounded search from bearing 0).
	var blocked_point: Vector2 = SpawnGeometry.sample_ring_point(_ring, tower_center, 0.0, 0.5)
	var view_center: Vector2 = blocked_point
	var view_half_size: Vector2 = Vector2(1200.0, 1200.0)

	# validate_and_shift's OWN bounded search must fail here -- otherwise
	# this test would not be exercising the escalation path at all.
	var bounded: Dictionary = SpawnGeometry.validate_and_shift(0.0, 0.5, _ring, tower_center, tower_center, interaction_radius, view_center, view_half_size, CAMERA_MARGIN_PX, arena_center, arena_half, ARENA_INSET_PX, 8, 10.0)
	assert_bool(bounded.get("valid", false)).append_failure_message("test setup invalid: the bounded +/-40 degree shift must ALSO fail here, or this is not testing the escalation path").is_false()

	var nearest: Variant = SpawnGeometry.nearest_valid_point_on_ring(0.0, _ring, tower_center, tower_center, interaction_radius, view_center, view_half_size, CAMERA_MARGIN_PX, arena_center, arena_half, ARENA_INSET_PX)
	assert_bool(nearest != null).append_failure_message("nearest_valid_point_on_ring found nothing, even though most of the ring (bearings past +/-60 degrees) is unblocked").is_true()
	var nearest_pos: Vector2 = nearest
	var dx: float = absf(nearest_pos.x - view_center.x)
	var dy: float = absf(nearest_pos.y - view_center.y)
	assert_bool(dx <= view_half_size.x + CAMERA_MARGIN_PX and dy <= view_half_size.y + CAMERA_MARGIN_PX).append_failure_message("nearest_valid_point_on_ring returned a point still inside the blocked view").is_false()


func test_nearest_valid_point_on_ring_returns_null_when_the_whole_ring_is_blocked() -> void:
	var tower_center: Vector2 = Vector2.ZERO
	var arena_center: Vector2 = Vector2.ZERO
	var arena_half: Vector2 = Vector2(10000.0, 10000.0)
	var view_center: Vector2 = tower_center
	var view_half_size: Vector2 = Vector2(2000.0, 2000.0) # swallows the whole ring
	var nearest: Variant = SpawnGeometry.nearest_valid_point_on_ring(0.0, _ring, tower_center, tower_center, 1.0, view_center, view_half_size, CAMERA_MARGIN_PX, arena_center, arena_half, ARENA_INSET_PX)
	assert_bool(nearest == null).append_failure_message("a fully blocked ring must report null, so wave_director.gd knows to fall back to the OTHER ring").is_true()


# --- Layer 2: WaveDirector end to end, real EntitySpawner/EntityRegistry ---

var _registry: Node
var _clock: Node
var _spawner: Node
var _director: WaveDirector
var _dummy_scene: PackedScene


func _build_dummy_scene() -> PackedScene:
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	packed.pack(n)
	n.free() # pack() copies the subtree into the resource; it does not take ownership of `n` itself, which would otherwise orphan
	return packed


func _build_director() -> Dictionary:
	var registry: Node = auto_free(EntityRegistryScript.new())
	add_child(registry)
	var clock: Node = auto_free(SimClockScript.new())
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner)
	spawner.set_registry_for_test(registry)
	_spawners.append(spawner)

	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.driven_externally = true
	director.run_seed = 777
	add_child(director)
	director.set_registry_for_test(registry)
	director.set_sim_clock_for_test(clock)
	director.set_entity_spawner_for_test(spawner)

	var dummy: PackedScene = _build_dummy_scene()
	director.tower_seeker_scene = dummy
	director.player_hunter_scene = dummy
	director.opportunist_scene = dummy

	return {"registry": registry, "clock": clock, "spawner": spawner, "director": director}


## "spawns land on the correct ring for their intent": a Tower Seeker must
## land on the Tower ring (centred on the Tower, which sits at the world
## origin -- see wave_director.gd's own fallback) and a Player Hunter must
## land on the view ring (centred on the camera, wired here to a fixed
## position away from the Tower so the two rings are distinguishable).
func test_wave_director_places_tower_seeker_on_the_tower_ring_and_hunter_on_the_view_ring() -> void:
	var ctx: Dictionary = _build_director()
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	var camera: Node2D = auto_free(Node2D.new())
	add_child(camera)
	# Offset far enough from the Tower (world origin) that the two rings are
	# clearly distinguishable, but small enough that the camera's ENTIRE
	# view ring (outer radius ~1459 px) still fits inside the arena inset
	# regardless of angle (arena half-extent 2400x1600, inset 32 -- 700 +
	# 1459 = 2159 < 2368 on X; 0 + 1459 = 1459 < 1568 on Y). This keeps the
	# test's own geometry simple: no candidate ever needs a shift or the
	# 8-tick escalation (both covered directly by the geometry-level tests
	# above), so a spawn landing off its expected ring can only mean ring
	# ROUTING by intent is wrong, not an artifact of this test's own setup.
	camera.global_position = Vector2(700.0, 0.0)
	director.set_camera_reference(camera)

	var seeker_group: SpawnGroup = SpawnGroup.new()
	seeker_group.enemy_definition_id = "tower_seeker"
	seeker_group.count = 1
	seeker_group.start_offset_seconds = 0.0
	seeker_group.spawn_interval_seconds = 1.0

	var hunter_group: SpawnGroup = SpawnGroup.new()
	hunter_group.enemy_definition_id = "player_hunter"
	hunter_group.count = 1
	hunter_group.start_offset_seconds = 0.0
	hunter_group.spawn_interval_seconds = 1.0

	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = "test_ring_encounter"
	encounter.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter.spawn_groups = [seeker_group, hunter_group]
	encounter.minimum_recovery_gap_seconds = 5.0

	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "test_ring_wave"
	wave.encounter_sequence = ["test_ring_encounter"]
	wave.maximum_duration_seconds = 1000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0

	director.waves = [wave]
	director.encounter_definitions = [encounter]
	director.rebuild_lookups_for_test()

	var spawned: Array = []
	director.enemy_spawned.connect(func(instance: Node2D, enemy_id: String, position: Vector2) -> void: spawned.append({"id": enemy_id, "position": position}))

	for _i in 5:
		clock.now += 0.1
		director.physics_step(0.1)

	assert_int(spawned.size()).append_failure_message("expected exactly 2 spawns (one Seeker, one Hunter), got %d" % spawned.size()).is_equal(2)

	var seeker_entry: Dictionary = spawned.filter(func(e: Dictionary) -> bool: return e["id"] == "tower_seeker")[0]
	var hunter_entry: Dictionary = spawned.filter(func(e: Dictionary) -> bool: return e["id"] == "player_hunter")[0]

	var seeker_dist_from_tower: float = (seeker_entry["position"] as Vector2).distance_to(Vector2.ZERO)
	assert_float(seeker_dist_from_tower).append_failure_message("Tower Seeker landed at %s, %.1f px from the Tower -- expected within the Tower ring [%.0f, %.0f]" % [seeker_entry["position"], seeker_dist_from_tower, TOWER_RING_INNER_PX, TOWER_RING_INNER_PX + TOWER_RING_WIDTH_PX]).is_between(TOWER_RING_INNER_PX - 1.0, TOWER_RING_INNER_PX + TOWER_RING_WIDTH_PX + 1.0)

	var hunter_dist_from_camera: float = (hunter_entry["position"] as Vector2).distance_to(camera.global_position)
	assert_float(hunter_dist_from_camera).append_failure_message("Player Hunter landed at %s, %.1f px from the camera -- expected within the view ring [%.0f, %.0f]" % [hunter_entry["position"], hunter_dist_from_camera, TOWER_RING_INNER_PX, TOWER_RING_INNER_PX + TOWER_RING_WIDTH_PX]).is_between(TOWER_RING_INNER_PX - 1.0, TOWER_RING_INNER_PX + TOWER_RING_WIDTH_PX + 1.0)

	# Not also asserted: "hunter is not on the Tower ring by distance from
	# the Tower." At this arena's real dimensions the two rings' possible
	# distances-from-Tower bands can genuinely overlap for some camera
	# offsets and angles (the Tower ring band is only 128 px wide against a
	# ring displaced by a few hundred px), so that check would be
	# geometry-dependent and occasionally flaky through no fault of the
	# code. The positive check above (correct distance from the CAMERA,
	# which a bug using the wrong centre would not incidentally reproduce)
	# is the reliable signal that ring routing used the right centre.
