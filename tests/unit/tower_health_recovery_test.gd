extends GdUnitTestSuite

## Health recovery check (P2.4 named acceptance test). MASTER_SDLC.md >
## Tower Overview > "Health Recovery Rules": "the base Tower has a shield
## equal to 25% of Tower maximum health. The shield absorbs damage before
## health. It begins regenerating at 10% of its maximum per second after 8
## seconds without the Tower taking any damage to health or shield; every
## hit restarts that 8-second delay, including the hit that breaks the
## shield." Provisional Values Register > Tower row: "regen 10%/s after
## 8 s, delay restarts on every hit including the breaking hit" -- both
## numbers read from data/tower/base.tres via TowerHealth.configure(),
## never restated as literals in assertions below (derived from
## TowerDefinitionResource directly).
##
## Exercises src/tower/tower_health.gd, measured against SimClock (a FRESH
## injected src/core/sim_clock.gd instance, not the real Autoload -- see
## tower_health.gd's own header: the real SimClock's header comment names a
## reset_for_test() that does not actually exist anywhere in the codebase,
## found and flagged as a contradiction in the P2.4 evidence report; this
## suite follows tests/unit/pause_clock_test.gd's own established fresh-
## instance convention instead). Because the fixture is built with no
## Area2D overlap involved (damage is delivered directly via
## Hurtbox.receive_hit(), exactly like every other Hurtbox-based test in
## this suite, e.g. death_state_test.gd), `_clock.now` is advanced by
## direct assignment and TowerHealth._physics_process() is called as an
## ordinary method -- never `await`ed -- so this suite runs in a handful of
## deterministic calls instead of the ~480 real physics frames an 8-second
## delay would otherwise require.
##
## Falsifications, each with its own test below:
##   1. No regen before the 8s delay elapses.
##   2. Regen at the Register's 10%/s rate once the delay has elapsed.
##   3. The delay RESTARTS on every hit -- including a hit that lands after
##      the shield is already broken (pure health damage), matching "without
##      the Tower taking any damage to health OR shield" -- proven by a
##      precise timestamp construction where the naive "measure from the
##      first hit" bug and the correct "measure from the most recent hit"
##      behaviour would disagree.
##   4. Shield clamps at its maximum and never overshoots.

const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EventBusScript: GDScript = preload("res://src/core/event_bus.gd")
const TowerDefinitionResource: TowerDefinition = preload("res://data/tower/base.tres")

var _clock: Node
var _bus: Node


func before_test() -> void:
	_clock = auto_free(SimClockScript.new()) as Node
	_bus = auto_free(EventBusScript.new()) as Node
	add_child(_clock)
	add_child(_bus)


func _build_fixture() -> Dictionary:
	var body := StaticBody2D.new()
	body.add_to_group(&"pool_body")
	body.name = "Body"

	var hurtbox := Hurtbox.new()
	hurtbox.faction = Hurtbox.Faction.TOWER
	hurtbox.name = "Hurtbox"
	var hurtbox_shape := CollisionShape2D.new()
	var hurtbox_circle := CircleShape2D.new()
	hurtbox_circle.radius = float(TowerDefinitionResource.tower_footprint.footprint_radius_px)
	hurtbox_shape.shape = hurtbox_circle
	hurtbox.add_child(hurtbox_shape)
	body.add_child(hurtbox)

	var death_state := DeathState.new()
	death_state.name = "DeathState"
	death_state.body_path = NodePath("..")
	death_state.registry_entity_path = NodePath("..")
	body.add_child(death_state)

	var health := TowerHealth.new()
	health.name = "TowerHealth"
	health.hurtbox_path = NodePath("../Hurtbox")
	health.death_state_path = NodePath("../DeathState")
	body.add_child(health)

	add_child(body)
	auto_free(body)

	health.set_sim_clock_for_test(_clock)
	health.set_event_bus_for_test(_bus)
	health.configure(TowerDefinitionResource)

	return {"body": body, "hurtbox": hurtbox, "death_state": death_state, "health": health}


func _hit(hurtbox: Hurtbox, amount: float) -> void:
	hurtbox.receive_hit(auto_free(Node.new()), amount, "test")


# --- Falsification 1: no regen before the delay elapses --------------------

func test_shield_does_not_regen_before_the_registers_delay_elapses() -> void:
	var f: Dictionary = _build_fixture()
	var health: TowerHealth = f["health"]
	var hurtbox: Hurtbox = f["hurtbox"]
	var delay: float = TowerDefinitionResource.shield_regeneration.delay_seconds

	_hit(hurtbox, 30.0) # partial shield damage only
	var after_hit_shield: float = health.current_shield
	assert_float(after_hit_shield).is_equal_approx(health.max_shield - 30.0, 0.01)

	_clock.now = delay - 0.1 # just under the delay
	health._physics_process(0.0)
	assert_float(health.current_shield).append_failure_message("shield regenerated before the Register's delay had elapsed").is_equal_approx(after_hit_shield, 0.01)


# --- Falsification 2: regen at the Register's rate once past the delay -----

func test_shield_regenerates_at_the_registers_rate_once_the_delay_has_elapsed() -> void:
	var f: Dictionary = _build_fixture()
	var health: TowerHealth = f["health"]
	var hurtbox: Hurtbox = f["hurtbox"]
	var delay: float = TowerDefinitionResource.shield_regeneration.delay_seconds
	var rate: float = TowerDefinitionResource.shield_regeneration.rate_percent_per_second

	_hit(hurtbox, 30.0)
	var shield_before_regen: float = health.current_shield

	_clock.now = delay + 0.1 # first tick that crosses the delay
	health._physics_process(0.0)
	var dt1: float = delay + 0.1 # elapsed since the configure()-time _last_regen_sim_time of 0.0
	var expected_after_first_tick: float = minf(health.max_shield, shield_before_regen + health.max_shield * (rate / 100.0) * dt1)
	assert_float(health.current_shield).append_failure_message("shield did not regenerate at the Register's rate on the first tick past the delay").is_equal_approx(expected_after_first_tick, 0.05)

	# A second, smaller tick: regen must accrue only for the NEW dt since
	# the previous _physics_process call, not for the full elapsed time
	# again (no "catch-up" double counting).
	var shield_before_second_tick: float = health.current_shield
	_clock.now = delay + 1.1
	health._physics_process(0.0)
	var dt2: float = 1.0
	var expected_after_second_tick: float = minf(health.max_shield, shield_before_second_tick + health.max_shield * (rate / 100.0) * dt2)
	assert_float(health.current_shield).append_failure_message("shield regen double-counted elapsed time across ticks instead of using only the new delta").is_equal_approx(expected_after_second_tick, 0.05)


# --- Falsification 3: the delay restarts on every hit, including a hit that
# lands after the shield is already broken (pure health damage) -----------

func test_shield_regen_delay_restarts_on_every_hit_including_after_the_shield_breaks() -> void:
	var f: Dictionary = _build_fixture()
	var health: TowerHealth = f["health"]
	var hurtbox: Hurtbox = f["hurtbox"]
	var delay: float = TowerDefinitionResource.shield_regeneration.delay_seconds

	# Breaks the shield AND spills into health in one hit.
	_hit(hurtbox, health.max_shield + 25.0)
	assert_float(health.current_shield).is_equal_approx(0.0, 0.01)
	assert_float(health.get_current_health()).is_equal_approx(health.max_health - 25.0, 0.01)

	_clock.now = delay - 1.0 # 1s short of the delay since the breaking hit
	health._physics_process(0.0)
	assert_float(health.current_shield).is_equal_approx(0.0, 0.01)

	# A SECOND hit, after the shield is already at 0 -- pure health damage,
	# nothing left "on the shield" for this hit to land on directly. The
	# Register's own wording is "without the Tower taking any damage to
	# health OR shield" -- this hit must still restart the delay.
	_hit(hurtbox, 10.0)
	assert_float(health.get_current_health()).is_equal_approx(health.max_health - 35.0, 0.01)

	# A naive "measure from the FIRST hit" implementation would have this
	# tick at (delay - 1.0) + (delay - 1.0) worth of elapsed time since the
	# breaking hit, well past the delay, and would incorrectly start
	# regenerating here. The correct implementation measures from the
	# SECOND hit and must not regen yet.
	_clock.now = (delay - 1.0) + (delay - 1.0)
	health._physics_process(0.0)
	assert_float(health.current_shield).append_failure_message("shield regenerated using a stale 'first hit' timestamp instead of restarting the delay on the second hit").is_equal_approx(0.0, 0.01)

	# Now genuinely past the delay SINCE THE SECOND HIT.
	_clock.now = (delay - 1.0) + delay + 0.1
	health._physics_process(0.0)
	assert_float(health.current_shield).append_failure_message("shield did not regenerate once the delay since the most recent hit had genuinely elapsed").is_greater(0.0)


# --- Falsification 4: shield clamps at its maximum, never overshoots ------

func test_shield_clamps_at_maximum_and_never_overshoots() -> void:
	var f: Dictionary = _build_fixture()
	var health: TowerHealth = f["health"]
	var hurtbox: Hurtbox = f["hurtbox"]
	var delay: float = TowerDefinitionResource.shield_regeneration.delay_seconds

	_hit(hurtbox, 5.0) # tiny shield damage
	_clock.now = delay + 1000.0 # a huge dt, well past a full regen
	health._physics_process(0.0)
	assert_float(health.current_shield).append_failure_message("shield regen overshot its maximum").is_equal_approx(health.max_shield, 0.001)


# --- Sanity: a dead Tower's shield does not regenerate ---------------------

func test_a_destroyed_tower_does_not_regenerate_shield() -> void:
	var f: Dictionary = _build_fixture()
	var health: TowerHealth = f["health"]
	var hurtbox: Hurtbox = f["hurtbox"]
	var delay: float = TowerDefinitionResource.shield_regeneration.delay_seconds

	_hit(hurtbox, health.max_health + health.max_shield + 100.0) # kills the Tower outright
	assert_bool(health.is_destroyed()).is_true()
	assert_float(health.current_shield).is_equal_approx(0.0, 0.01)

	_clock.now = delay + 1000.0
	health._physics_process(0.0)
	assert_float(health.current_shield).append_failure_message("a destroyed Tower's shield regenerated").is_equal_approx(0.0, 0.01)
