extends GdUnitTestSuite

## Pickup cap and C-MERGE (P2.10; MASTER_SDLC.md > "Pickup Physics & Magnet
## Rules" > "Merging"; > Provisional Values Register > "Economy & Pickups"
## > "Pickup merge (C-MERGE)"; > Technical Caps & Performance > "Entity
## caps": "pickups 150"). Exercises PickupSystem's cap/merge cascade in
## isolation, with a real (but tiny) EntitySpawner/EntityRegistry pair so
## the cap is genuinely enforced by the same pool this task must use
## (task brief: "acquired from the EXISTING pickup pool ... never
## instantiated ad hoc"), not a fake.
##
## The cap itself is exercised at a REDUCED size for test speed: PickupSystem
## hard-codes 150 (Register), so these tests bring the pool to exactly the
## Register's cap by pre-filling it, they do not lower the cap.

const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PickupSystemScript: GDScript = preload("res://src/pickup/pickup_system.gd")
const XpShardDefinition: PickupDefinition = preload("res://data/pickups/xp_shard.tres")
const ScrapDefinition: PickupDefinition = preload("res://data/pickups/scrap.tres")
const PICKUP_CAP: int = 150 # Register > Technical Caps & Performance > Entity caps -- matches PickupSystem.PICKUP_CAP, independently re-stated per this project's convention (entity_cap_test.gd's own header)

var _spawner: Node
var _registry: Node
var _clock: Node
var _system: PickupSystem


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)
	_spawner = auto_free(EntitySpawnerScript.new()) as Node
	add_child(_spawner)
	_spawner.set_registry_for_test(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	add_child(_clock)

	_system = auto_free(PickupSystemScript.new()) as PickupSystem
	add_child(_system)
	_system.set_entity_spawner_for_test(_spawner)
	_system.set_registry_for_test(_registry)
	_system.set_sim_clock_for_test(_clock)


func after_test() -> void:
	if _system != null:
		_system.clear_all_for_test()
	if _spawner != null:
		_spawner.clear_all_for_test()


func _drop_at(definition: PickupDefinition, amount: int, position: Vector2) -> void:
	var table := DropTable.new()
	if definition == XpShardDefinition:
		table.xp_shards = amount
	else:
		table.scrap = amount
	_system.handle_enemy_removed_while_stuck(position, table)
	_system.step_drops()


# --- Cap holds ----------------------------------------------------------------

func test_cap_never_exceeds_150_across_many_widely_spaced_drops() -> void:
	# Widely spaced (5000 px apart, far beyond any merge radius) so every
	# drop past the cap must EXPIRE something rather than merge -- exercises
	# the "no such pair exists" branch of C-MERGE on every drop past 150.
	for i in (PICKUP_CAP + 30):
		_drop_at(ScrapDefinition, 1, Vector2(i * 5000, 0))
		assert_int(_spawner.get_pickup_count()).append_failure_message(
			"pickup pool exceeded the Register cap of %d after %d drops" % [PICKUP_CAP, i + 1]
		).is_less_equal(PICKUP_CAP)
		assert_int(_system.get_active_pickup_count()).append_failure_message(
			"PickupSystem's own bookkeeping (%d) drifted from the pool's real count (%d) -- the cap cascade left an untracked or double-tracked pickup" % [_system.get_active_pickup_count(), _spawner.get_pickup_count()]
		).is_equal(_spawner.get_pickup_count())
	assert_int(_spawner.get_pickup_count()).append_failure_message("the cap was never actually reached, so this test proves nothing").is_equal(PICKUP_CAP)


func test_at_cap_the_oldest_of_the_incoming_type_expires_when_no_merge_partner_exists() -> void:
	for i in PICKUP_CAP:
		_drop_at(ScrapDefinition, 1, Vector2(i * 5000, 0))
	var oldest_before: int = _system.get_active_pickup_count()
	assert_int(oldest_before).is_equal(PICKUP_CAP)

	_drop_at(ScrapDefinition, 1, Vector2(999999, 0)) # far from every existing Scrap -- no merge partner
	assert_int(_spawner.get_pickup_count()).append_failure_message("cap not held after a same-type drop with no merge partner").is_equal(PICKUP_CAP)
	assert_int(_system.get_active_pickup_count()).is_equal(PICKUP_CAP)


# --- C-MERGE: sum into nearest same-type neighbour -----------------------------

func test_merge_sums_value_into_the_nearest_same_type_neighbour_and_keeps_its_position() -> void:
	# Fill the cap with Scrap pickups in same-type pairs close together
	# (well inside the 64 px default merge radius, Register > Economy &
	# Pickups > "Merge radius"), so the oldest Scrap always has a mergeable
	# neighbour.
	var pair_count: int = PICKUP_CAP / 2
	for i in pair_count:
		var base: Vector2 = Vector2(i * 1000, 0)
		_drop_at(ScrapDefinition, 1, base)
		_drop_at(ScrapDefinition, 1, base + Vector2(10, 0)) # 10 px away, inside the 64 px merge radius

	assert_int(_system.get_active_pickup_count()).is_equal(PICKUP_CAP)

	# The very first pair (spawn order 0 and 1) are the two oldest Scrap
	# pickups; pickup #1 (spawn_serial 1) is the NEAREST same-type neighbour
	# to pickup #0 (spawn_serial 0, the oldest, sitting at Vector2.ZERO).
	var pickups_before: Array = _system.get_active_pickups_for_test()
	var oldest: Pickup = pickups_before[0]
	var neighbour: Pickup = pickups_before[1]
	assert_int(oldest.spawn_serial).is_equal(0)
	var oldest_original_position: Vector2 = oldest.global_position
	var neighbour_value_before: int = neighbour.value
	var neighbour_position_before: Vector2 = neighbour.global_position

	_drop_at(ScrapDefinition, 1, Vector2(999999, 999999)) # triggers the cap cascade for an incoming Scrap drop

	assert_int(_spawner.get_pickup_count()).is_equal(PICKUP_CAP)

	# NOT checked by Node-reference absence: EntitySpawner.despawn_pickup()
	# returns `oldest`'s instance straight to the pool's free list, and this
	# same call immediately spawns the incoming drop, so Pool.acquire() can
	# (and here, does) hand back that EXACT freed instance, reconfigured, as
	# the NEW pickup -- the reference stays "in" _active_pickups the whole
	# time, now representing something else entirely. The only reliable
	# observations are DATA: the neighbour's value/position, and that
	# nothing remains at the merged-away pickup's OLD position.
	assert_int(neighbour.value).append_failure_message("the surviving neighbour's value did not absorb the merged-away pickup's value (C-MERGE: 'takes the summed value')").is_equal(neighbour_value_before + 1)
	assert_vector(neighbour.global_position).append_failure_message("the surviving neighbour must keep ITS OWN position after a merge (C-MERGE: 'keeps its position and lifetime')").is_equal_approx(neighbour_position_before, Vector2(0.01, 0.01))

	var still_at_old_position: bool = false
	for p in _system.get_active_pickups_for_test():
		if p != neighbour and (p as Pickup).global_position.distance_to(oldest_original_position) < 1.0:
			still_at_old_position = true
	assert_bool(still_at_old_position).append_failure_message("a pickup is still sitting at the merged-away pickup's original position -- it should have been evicted, not left behind as a duplicate").is_false()


# --- C-MERGE cascade: incoming type absent -> oldest XP, then oldest Scrap ----

func test_when_no_pickup_of_the_incoming_type_exists_the_oldest_xp_shard_expires_first() -> void:
	# Fill the cap with a mix: a handful of XP shards first (oldest), then
	# Scrap to fill the rest -- an incoming Scrap drop's own type (Scrap)
	# DOES exist, so this proves the cascade checks the INCOMING type first
	# and only reaches for the oldest-XP/oldest-Scrap fallback when that
	# fails; the companion test below drives the fallback itself.
	for i in 5:
		_drop_at(XpShardDefinition, 1, Vector2(i * 5000, 0))
	for i in (PICKUP_CAP - 5):
		_drop_at(ScrapDefinition, 1, Vector2((i + 5) * 5000, 0))
	assert_int(_system.get_active_pickup_count()).is_equal(PICKUP_CAP)

	var pickups: Array = _system.get_active_pickups_for_test()
	var oldest_xp: Pickup = pickups[0]
	assert_int(int(oldest_xp.get_pickup_type())).is_equal(int(ContractEnums.PickupType.XP))
	var oldest_xp_position: Vector2 = oldest_xp.global_position

	# Drop an XP shard far from every existing XP shard (no merge partner):
	# per C-MERGE this expires the oldest pickup OF THE INCOMING TYPE (XP),
	# which is exactly oldest_xp -- this is the ordinary "no partner" branch,
	# not the "type absent" fallback (there IS an XP shard present).
	_drop_at(XpShardDefinition, 1, Vector2(999999, 0))

	# Checked by DATA (position), not Node-reference absence -- see
	# test_merge_sums_value_into_the_nearest_same_type_neighbour_and_keeps_
	# its_position's own comment: EntitySpawner can (and often does) hand
	# the just-freed instance straight back for the very next spawn, so the
	# reference itself staying "in" _active_pickups proves nothing.
	assert_int(_spawner.get_pickup_count()).is_equal(PICKUP_CAP)
	var xp_count_at_old_position: int = 0
	for p in _system.get_active_pickups_for_test():
		if (p as Pickup).get_pickup_type() == ContractEnums.PickupType.XP and (p as Pickup).global_position.distance_to(oldest_xp_position) < 1.0:
			xp_count_at_old_position += 1
	assert_int(xp_count_at_old_position).append_failure_message("the oldest XP shard should have expired (no merge partner) before the type-absent fallback ever applies").is_equal(0)


func test_when_the_incoming_type_is_entirely_absent_the_oldest_xp_expires_before_any_scrap() -> void:
	# Cap filled ENTIRELY with Scrap; the incoming drop is XP, which does not
	# exist on the field at all -- C-MERGE: "if none of that type exists,
	# the oldest XP shard expires, then the oldest Scrap." With zero XP
	# shards present, the very first fallback tier (oldest XP) is also
	# empty, so this must fall through to the oldest Scrap.
	for i in PICKUP_CAP:
		_drop_at(ScrapDefinition, 1, Vector2(i * 5000, 0))
	var pickups: Array = _system.get_active_pickups_for_test()
	var oldest_scrap: Pickup = pickups[0]
	var oldest_scrap_position: Vector2 = oldest_scrap.global_position

	_drop_at(XpShardDefinition, 1, Vector2(999999, 0))

	# Checked by DATA (position), not Node-reference absence -- see
	# test_merge_sums_value_into_the_nearest_same_type_neighbour_and_keeps_
	# its_position's own comment.
	assert_int(_spawner.get_pickup_count()).is_equal(PICKUP_CAP)
	var scrap_count_at_old_position: int = 0
	for p in _system.get_active_pickups_for_test():
		if (p as Pickup).get_pickup_type() == ContractEnums.PickupType.Scrap and (p as Pickup).global_position.distance_to(oldest_scrap_position) < 1.0:
			scrap_count_at_old_position += 1
	assert_int(scrap_count_at_old_position).append_failure_message("with no XP shard on the field at all, the oldest Scrap pickup must expire to make room for the incoming XP drop (C-MERGE's final fallback tier)").is_equal(0)
	var has_xp: bool = false
	for p in _system.get_active_pickups_for_test():
		if (p as Pickup).get_pickup_type() == ContractEnums.PickupType.XP:
			has_xp = true
	assert_bool(has_xp).append_failure_message("the incoming XP drop never actually got spawned").is_true()
