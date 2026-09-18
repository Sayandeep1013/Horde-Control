extends GdUnitTestSuite

## Cap unit check (P1.3; MASTER_SDLC.md > Acceptance Test Matrix > Technical
## Tests: "a scripted spawner never exceeds any of the six caps"). Six
## independent tests, one per cap -- P1.3's own task brief: "Test each cap
## separately -- one test that only exercises the enemy cap would leave five
## unproven."
##
## Phase 02 carried lesson 2 (PLAN.md): "P1.3's cap check takes the six cap
## values from the Provisional Values Register, not from the spawner's own
## constants." The six REGISTER_MAX_* constants below are transcribed
## directly from MASTER_SDLC.md > Provisional Values Register > Technical
## Caps & Performance > "Entity caps" row -- this file deliberately does NOT
## import src/core/entity_caps.gd, so a wrong value written there cannot
## make this test pass by agreeing with itself (this project has shipped
## that exact defect three times per the carried lesson).

const REGISTER_MAX_ENEMIES: int = 300
const REGISTER_MAX_PICKUPS: int = 150
const REGISTER_MAX_PROJECTILES: int = 400
const REGISTER_MAX_DAMAGE_NUMBERS: int = 30
const REGISTER_MAX_TELEGRAPHS: int = 40
const REGISTER_MAX_HIGH_INTENSITY_VFX: int = 24

const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

var _spawner: Node
var _fresh_registry: Node


func before_test() -> void:
	_spawner = auto_free(EntitySpawnerScript.new()) as Node
	add_child(_spawner)
	# A fresh EntityRegistry instance, not the real Autoload singleton, so
	# one test's 350+ spawn attempts cannot leak into the next test or into
	# any other suite in this run (same isolation entity_registry_test.gd
	# already applies to EntityRegistry itself).
	_fresh_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_fresh_registry)
	_spawner.set_registry_for_test(_fresh_registry)


func after_test() -> void:
	if _spawner != null:
		_spawner.clear_all_for_test()


# --- Enemy cap (300) -------------------------------------------------------

func test_enemy_cap_is_never_exceeded() -> void:
	var observed_max: int = 0
	for i in (REGISTER_MAX_ENEMIES + 50):
		_spawner.spawn_enemy(Vector2(i, 0))
		var count: int = _spawner.get_enemy_count()
		observed_max = maxi(observed_max, count)
		assert_int(count).append_failure_message(
			"enemy count %d exceeded the Register cap of %d after %d spawn attempts" % [count, REGISTER_MAX_ENEMIES, i + 1]
		).is_less_equal(REGISTER_MAX_ENEMIES)
	assert_int(observed_max).append_failure_message("the enemy cap was never actually reached, so this test proves nothing").is_equal(REGISTER_MAX_ENEMIES)


# --- Pickup cap (150) -------------------------------------------------------

func test_pickup_cap_is_never_exceeded() -> void:
	var observed_max: int = 0
	for i in (REGISTER_MAX_PICKUPS + 50):
		_spawner.spawn_pickup(Vector2(i, 0))
		var count: int = _spawner.get_pickup_count()
		observed_max = maxi(observed_max, count)
		assert_int(count).append_failure_message(
			"pickup count %d exceeded the Register cap of %d after %d spawn attempts" % [count, REGISTER_MAX_PICKUPS, i + 1]
		).is_less_equal(REGISTER_MAX_PICKUPS)
	assert_int(observed_max).append_failure_message("the pickup cap was never actually reached, so this test proves nothing").is_equal(REGISTER_MAX_PICKUPS)


# --- Projectile cap (400) ---------------------------------------------------

func test_projectile_cap_is_never_exceeded() -> void:
	var observed_max: int = 0
	for i in (REGISTER_MAX_PROJECTILES + 50):
		_spawner.spawn_projectile(Vector2(i, 0))
		var count: int = _spawner.get_projectile_count()
		observed_max = maxi(observed_max, count)
		assert_int(count).append_failure_message(
			"projectile count %d exceeded the Register cap of %d after %d spawn attempts" % [count, REGISTER_MAX_PROJECTILES, i + 1]
		).is_less_equal(REGISTER_MAX_PROJECTILES)
	assert_int(observed_max).append_failure_message("the projectile cap was never actually reached, so this test proves nothing").is_equal(REGISTER_MAX_PROJECTILES)


# --- Damage number cap (30) -------------------------------------------------

func test_damage_number_cap_is_never_exceeded() -> void:
	var observed_max: int = 0
	for i in (REGISTER_MAX_DAMAGE_NUMBERS + 50):
		_spawner.spawn_damage_number()
		var count: int = _spawner.get_damage_number_count()
		observed_max = maxi(observed_max, count)
		assert_int(count).append_failure_message(
			"damage number count %d exceeded the Register cap of %d after %d spawn attempts" % [count, REGISTER_MAX_DAMAGE_NUMBERS, i + 1]
		).is_less_equal(REGISTER_MAX_DAMAGE_NUMBERS)
	assert_int(observed_max).append_failure_message("the damage number cap was never actually reached, so this test proves nothing").is_equal(REGISTER_MAX_DAMAGE_NUMBERS)


# --- Telegraph cap (40) ------------------------------------------------------

func test_telegraph_cap_is_never_exceeded() -> void:
	var observed_max: int = 0
	for i in (REGISTER_MAX_TELEGRAPHS + 50):
		_spawner.spawn_telegraph()
		var count: int = _spawner.get_telegraph_count()
		observed_max = maxi(observed_max, count)
		assert_int(count).append_failure_message(
			"telegraph count %d exceeded the Register cap of %d after %d spawn attempts" % [count, REGISTER_MAX_TELEGRAPHS, i + 1]
		).is_less_equal(REGISTER_MAX_TELEGRAPHS)
	assert_int(observed_max).append_failure_message("the telegraph cap was never actually reached, so this test proves nothing").is_equal(REGISTER_MAX_TELEGRAPHS)


# --- High-intensity VFX cap (24) --------------------------------------------

func test_high_intensity_vfx_cap_is_never_exceeded() -> void:
	var observed_max: int = 0
	for i in (REGISTER_MAX_HIGH_INTENSITY_VFX + 50):
		_spawner.spawn_high_intensity_vfx()
		var count: int = _spawner.get_high_intensity_vfx_count()
		observed_max = maxi(observed_max, count)
		assert_int(count).append_failure_message(
			"high-intensity VFX count %d exceeded the Register cap of %d after %d spawn attempts" % [count, REGISTER_MAX_HIGH_INTENSITY_VFX, i + 1]
		).is_less_equal(REGISTER_MAX_HIGH_INTENSITY_VFX)
	assert_int(observed_max).append_failure_message("the high-intensity VFX cap was never actually reached, so this test proves nothing").is_equal(REGISTER_MAX_HIGH_INTENSITY_VFX)


# --- EntityRegistry wiring (register at spawn, deregister at despawn) -----

func test_spawn_enemy_registers_and_despawn_deregisters() -> void:
	var e: Node2D = _spawner.spawn_enemy(Vector2(42, 7))
	assert_bool(_fresh_registry.is_registered(e)).append_failure_message("spawn_enemy() did not register the instance with EntityRegistry").is_true()
	assert_int(_fresh_registry.get_live_enemy_count()).is_equal(1)

	assert_bool(_spawner.despawn_enemy(e)).is_true()
	assert_bool(_fresh_registry.is_registered(e)).append_failure_message("despawn_enemy() did not deregister the instance from EntityRegistry").is_false()


func test_damage_number_spawn_does_not_touch_entity_registry() -> void:
	# P1.3 interpretation (see evidence report): no documented system
	# queries damage numbers/telegraphs/VFX spatially, so these three
	# categories are not registered at all.
	var before: int = _fresh_registry.get_entity_count()
	_spawner.spawn_damage_number()
	assert_int(_fresh_registry.get_entity_count()).append_failure_message("spawn_damage_number() unexpectedly registered with EntityRegistry").is_equal(before)
