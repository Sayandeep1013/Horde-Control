## Phase 02, LEDGER F02-13.
##
## P1.3 and P1.4 were implemented in parallel and each made a defensible choice
## that, taken together, broke at the seam. P1.3 registers only enemies,
## pickups and projectiles with EntityRegistry, reading docs/20 as requiring a
## *spatial* index only for things something queries spatially. P1.4's debug
## overlay read all six of its required counts from that same registry, using
## tag names it invented because no spawner existed yet to agree with.
##
## The result: damage numbers, telegraphs and high-intensity VFX - three of the
## six counts docs/20's Debug Overlay field list explicitly requires - reported
## zero, silently, forever. P1.4's own header comment predicted exactly this
## failure mode for exactly this reason.
##
## These tests exist so the seam cannot re-open unnoticed. They spawn through
## the real EntitySpawner and assert the overlay reports what was actually
## spawned, with the three previously-broken categories named in the failure
## messages so a future failure says what it means.
extends GdUnitTestSuite

## The overlay is instantiated from its SCENE, not from the bare script:
## `_ready()` touches an `@onready` label that only exists in the scene, so
## `OverlayScript.new()` errors on the first frame. This matches the pattern
## already used in `debug_overlay_test.gd`.
const OverlayScene: PackedScene = preload("res://src/debug/overlay.tscn")
const OverlayScript: GDScript = preload("res://src/debug/overlay.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")

var _overlay: DebugOverlay
var _spawner: Node
## Spawned instances are owned by the spawner's pools rather than by the scene
## tree, so `auto_free` does not reach them; they are despawned explicitly in
## `after_test` or gdUnit4 reports them as orphan nodes.
var _spawned: Array = []


func before_test() -> void:
	_spawned.clear()
	_spawner = auto_free(EntitySpawnerScript.new())
	add_child(_spawner)
	_overlay = auto_free(OverlayScene.instantiate()) as DebugOverlay
	add_child(_overlay)
	# The overlay repaints every frame; nothing here needs that, and leaving it
	# running makes a failure surface as a _process error rather than as a
	# readable assertion.
	_overlay.process_mode = Node.PROCESS_MODE_DISABLED
	_overlay.set_entity_source(_spawner)


func after_test() -> void:
	# A pool deliberately keeps instances alive and out of the scene tree, so
	# despawning only returns them to the free list - gdUnit4 still counts them
	# as orphans. EntitySpawner exposes clear_all_for_test() for exactly this,
	# and pool_test.gd uses the same teardown for the same reason.
	_spawner.clear_all_for_test()
	_spawned.clear()


func _spawn(kind: String, n: int) -> void:
	for i in n:
		var made: Node = _spawner.call("spawn_" + kind)
		if made != null:
			_spawned.append([kind, made])


## The three categories that silently read zero before F02-13 was fixed.
func test_counts_that_the_registry_never_carried_are_reported() -> void:
	_spawn("damage_number", 7)
	_spawn("telegraph", 5)
	_spawn("high_intensity_vfx", 3)

	assert_int(_overlay._count_tag(OverlayScript.TAG_DAMAGE_NUMBER)).override_failure_message(
		"damage-number count did not reach the overlay; this is F02-13 re-opening"
	).is_equal(7)
	assert_int(_overlay._count_tag(OverlayScript.TAG_TELEGRAPH)).override_failure_message(
		"telegraph count did not reach the overlay; this is F02-13 re-opening"
	).is_equal(5)
	assert_int(_overlay._count_tag(OverlayScript.TAG_VFX_HIGH_INTENSITY)).override_failure_message(
		"high-intensity VFX count did not reach the overlay; this is F02-13 re-opening"
	).is_equal(3)


## The three the registry did carry must not regress while the other three are fixed.
func test_counts_the_registry_already_carried_still_work() -> void:
	_spawn("enemy", 4)
	_spawn("pickup", 6)
	_spawn("projectile", 9)

	assert_int(_overlay._count_tag(OverlayScript.TAG_ENEMY)).is_equal(4)
	assert_int(_overlay._count_tag(OverlayScript.TAG_PICKUP)).is_equal(6)
	assert_int(_overlay._count_tag(OverlayScript.TAG_PROJECTILE)).is_equal(9)


## Counts must fall as well as rise. A count that only ever increments would
## pass every assertion above while being wrong the moment anything despawns.
func test_counts_follow_despawn_as_well_as_spawn() -> void:
	_spawn("telegraph", 2)
	assert_int(_overlay._count_tag(OverlayScript.TAG_TELEGRAPH)).is_equal(2)

	var entry: Array = _spawned.pop_back()
	_spawner.despawn_telegraph(entry[1])

	assert_int(_overlay._count_tag(OverlayScript.TAG_TELEGRAPH)).override_failure_message(
		"the overlay count did not fall on despawn, so it reports spawns rather than live instances"
	).is_equal(1)


## The tag-to-method mapping is kept as data so a reviewer can diff it against
## the spawner without reading either implementation. Assert it actually
## resolves, rather than trusting that it was typed correctly.
func test_every_mapped_count_method_exists_on_the_spawner() -> void:
	for tag in OverlayScript._SPAWNER_COUNT_METHODS.keys():
		var method: String = OverlayScript._SPAWNER_COUNT_METHODS[tag]
		assert_bool(_spawner.has_method(method)).override_failure_message(
			"overlay maps tag '%s' to spawner method '%s()', which does not exist" % [tag, method]
		).is_true()
