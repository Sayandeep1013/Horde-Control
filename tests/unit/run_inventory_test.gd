extends GdUnitTestSuite

## RunInventory (P2.10; MASTER_SDLC.md > Provisional Values Register >
## "Economy & Pickups"; > "Experience (XP)"; task brief: "On PLAYER death,
## carried Scrap goes to zero"). Uses a fake EventBus double (add_user_signal)
## so this suite never touches the real EventBus Autoload singleton or
## depends on player_died's exact real emitter (src/combat/death_state.gd,
## outside this task's write scope).

const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const HudEconomyStateScript: GDScript = preload("res://src/ui/hud_economy_state.gd")

const REGISTER_SCRAP_CAP: int = 200 # Register > Economy & Pickups > "Scrap": "Cap 200"
const REGISTER_XP_BASE_COST: int = 10
const REGISTER_XP_PER_LEVEL: int = 5


func _make_economy() -> EconomyConfiguration:
	var economy := EconomyConfiguration.new()
	economy.scrap_cap = REGISTER_SCRAP_CAP
	economy.merge_radius_px = 64
	var xp_cost := XpLevelCost.new()
	xp_cost.shard_value = 1
	xp_cost.base_cost = REGISTER_XP_BASE_COST
	xp_cost.per_level_increment = REGISTER_XP_PER_LEVEL
	economy.xp_level_cost = xp_cost
	return economy


func _make_fake_bus_with_player_died() -> Node:
	var bus: Node = auto_free(Node.new())
	bus.add_user_signal("player_died", [
		{"name": "entity", "type": TYPE_OBJECT},
		{"name": "position", "type": TYPE_VECTOR2},
		{"name": "timestamp", "type": TYPE_FLOAT},
	])
	add_child(bus)
	return bus


# --- Scrap: credit, cap, overflow discard, FULL --------------------------------

func test_scrap_credits_up_to_the_register_cap() -> void:
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), _make_fake_bus_with_player_died())
	inventory.credit_scrap(150)
	assert_int(inventory.scrap_current).is_equal(150)
	assert_bool(inventory.is_scrap_full()).is_false()


func test_scrap_overflow_beyond_the_cap_is_discarded_not_queued() -> void:
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), _make_fake_bus_with_player_died())
	inventory.credit_scrap(REGISTER_SCRAP_CAP + 500) # far beyond the cap in one credit
	assert_int(inventory.scrap_current).append_failure_message("Register > Economy & Pickups > Scrap: 'the prototype has no hopper (overflow discarded)' -- scrap_current exceeded the cap").is_equal(REGISTER_SCRAP_CAP)
	assert_bool(inventory.is_scrap_full()).is_true()

	inventory.credit_scrap(50) # further credit past FULL must also just discard
	assert_int(inventory.scrap_current).is_equal(REGISTER_SCRAP_CAP)


# --- XP / level curve: 10 + 5(L+1) -> 15, 20, 25 for the first three levels ---

func test_xp_curve_matches_15_20_25_for_the_first_three_levels() -> void:
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), _make_fake_bus_with_player_died())
	assert_int(inventory.level).append_failure_message("MASTER_SDLC.md > 'Experience (XP)': a run starts at level 0").is_equal(0)
	assert_float(inventory.xp_required_for_next_level).is_equal_approx(15.0, 0.001)

	inventory.credit_xp(15.0)
	assert_int(inventory.level).is_equal(1)
	assert_float(inventory.xp_current).is_equal_approx(0.0, 0.001)
	assert_float(inventory.xp_required_for_next_level).append_failure_message("level 1->2 should cost 20 XP (10 + 5*2)").is_equal_approx(20.0, 0.001)

	inventory.credit_xp(20.0)
	assert_int(inventory.level).is_equal(2)
	assert_float(inventory.xp_required_for_next_level).append_failure_message("level 2->3 should cost 25 XP (10 + 5*3)").is_equal_approx(25.0, 0.001)


func test_xp_remainder_carries_over_toward_the_next_level() -> void:
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), _make_fake_bus_with_player_died())
	inventory.credit_xp(18.0) # 15 to level up, 3 left over
	assert_int(inventory.level).is_equal(1)
	assert_float(inventory.xp_current).append_failure_message("XP beyond a level-up's cost must carry over as the remainder (MASTER_SDLC.md > 'Experience (XP)')").is_equal_approx(3.0, 0.001)


func test_a_single_large_credit_can_carry_through_multiple_level_ups() -> void:
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), _make_fake_bus_with_player_died())
	inventory.credit_xp(15.0 + 20.0 + 5.0) # exactly enough for two level-ups plus 5 remainder
	assert_int(inventory.level).is_equal(2)
	assert_float(inventory.xp_current).is_equal_approx(5.0, 0.001)


func test_consume_level_up_requested_reports_exactly_once_per_level_up() -> void:
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), _make_fake_bus_with_player_died())
	assert_bool(inventory.consume_level_up_requested()).is_false()
	inventory.credit_xp(15.0)
	assert_bool(inventory.consume_level_up_requested()).append_failure_message("a level-up occurred but consume_level_up_requested() did not report it").is_true()
	assert_bool(inventory.consume_level_up_requested()).append_failure_message("consume_level_up_requested() must clear its own flag and not report the same level-up twice").is_false()


# --- Player death: Scrap to zero, guarded EventBus.player_died connection ----

func test_player_death_zeroes_carried_scrap() -> void:
	var bus: Node = _make_fake_bus_with_player_died()
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), bus)
	inventory.credit_scrap(120)
	assert_int(inventory.scrap_current).is_equal(120)

	bus.emit_signal("player_died", null, Vector2.ZERO, 0.0)
	assert_int(inventory.scrap_current).append_failure_message("MASTER_SDLC.md task brief: 'On PLAYER death, carried Scrap goes to zero' -- Scrap survived player_died").is_equal(0)


func test_connection_is_guarded_when_the_bus_has_no_player_died_signal() -> void:
	var bus_without_signal: Node = auto_free(Node.new())
	add_child(bus_without_signal)
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), bus_without_signal)
	assert_bool(inventory.is_player_died_connected()).append_failure_message("configure() must not error against a bus with no player_died signal (task brief: 'if it does not exist yet ... guard the connection')").is_false()

	# Reconnecting later, once a real signal exists, must succeed without
	# rebuilding the RunInventory.
	var bus_with_signal: Node = _make_fake_bus_with_player_died()
	assert_bool(inventory.try_connect_player_died(bus_with_signal)).is_true()
	assert_bool(inventory.is_player_died_connected()).is_true()


func test_double_configure_does_not_double_connect() -> void:
	var bus: Node = _make_fake_bus_with_player_died()
	var inventory: RunInventory = RunInventoryScript.new()
	var economy: EconomyConfiguration = _make_economy()
	inventory.configure(economy, bus)
	inventory.configure(economy, bus) # second call must not raise or double-fire
	inventory.credit_scrap(30)
	bus.emit_signal("player_died", null, Vector2.ZERO, 0.0)
	assert_int(inventory.scrap_current).is_equal(0) # would still be 0 even if double-connected; this call mainly proves no error from a duplicate connect attempt


# --- HUD field-shape wiring ----------------------------------------------------

func test_apply_to_hud_state_copies_the_exact_field_shape() -> void:
	var inventory: RunInventory = RunInventoryScript.new()
	inventory.configure(_make_economy(), _make_fake_bus_with_player_died())
	inventory.credit_scrap(77)
	inventory.credit_xp(15.0)

	var hud_state: HudEconomyState = HudEconomyStateScript.new()
	inventory.apply_to_hud_state(hud_state)

	assert_int(hud_state.scrap_current).is_equal(77)
	assert_int(hud_state.scrap_cap).is_equal(REGISTER_SCRAP_CAP)
	assert_int(hud_state.level).is_equal(1)
	assert_float(hud_state.xp_current).is_equal_approx(0.0, 0.001)
	assert_float(hud_state.xp_required_for_next_level).is_equal_approx(20.0, 0.001)
