extends GdUnitTestSuite

## Scrap loss test (P2.14 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Core Tension Tests > "Scrap loss test": "On
## player death, the Scrap counter on the run-end screen is zero and no
## Scrap carries to the next run." Provisional Values Register > "Economy &
## Pickups" > "Scrap": "carried and lost on death ... unspent Scrap
## discarded at run end."
##
## Exercises the REAL src/economy/run_inventory.gd (its own
## `_on_player_died()` zeroes `scrap_current`) and the REAL
## src/run/run_flow_controller.gd / src/ui/run_end.gd this task built --
## never a hand-rolled substitute for either. Both listener-connection
## orders are proven (see class doc on run_flow_controller.gd,
## "Reading Scrap only after it is truly final"): a naive "cache the value
## the instant the death signal fires" implementation would pass under one
## order and fail under the other, which is exactly why both are asserted
## here rather than just the one order that happens to occur in the
## assembled game.

const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const EconomyConfigurationScript: GDScript = preload("res://src/data/economy_configuration.gd")
const XpLevelCostScript: GDScript = preload("res://src/data/xp_level_cost.gd")
const RunFlowControllerScript: GDScript = preload("res://src/run/run_flow_controller.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")


func after_test() -> void:
	# Safety net (pause_clock_test.gd's own precedent): _end_run() below
	# pushes a pause reason on whichever PauseAuthority the controller was
	# given -- every test in this file injects a FRESH instance (never the
	# real autoload), but a failed assertion mid-test must still never leak
	# a stuck pause into the SHARED tree for a suite that runs after this
	# one.
	get_tree().paused = false


func _make_fake_bus() -> Node:
	var bus: Node = auto_free(Node.new())
	bus.add_user_signal("player_died", [
		{"name": "entity", "type": TYPE_OBJECT},
		{"name": "position", "type": TYPE_VECTOR2},
		{"name": "timestamp", "type": TYPE_FLOAT},
	])
	add_child(bus)
	return bus


func _make_economy_configuration() -> Resource:
	var cost: Resource = XpLevelCostScript.new()
	var economy: Resource = EconomyConfigurationScript.new()
	economy.scrap_cap = 200
	economy.xp_level_cost = cost
	economy.xp_cap_during_teaching_waves = 14
	return economy


func _make_controller() -> RunFlowController:
	var controller: RunFlowController = RunFlowControllerScript.new() as RunFlowController
	# A FRESH PauseAuthority, never the real autoload -- _end_run() (reached
	# via player_died below) pushes REASON_RUN_ENDED and never pops it for
	# the rest of that "run"; on the real singleton that would leave the
	# whole shared scene tree paused for every suite that runs afterward in
	# this same gdUnit4 process. Must be set BEFORE add_child(), matching
	# this project's set_*_for_test convention (_ready() connects to
	# whichever PauseAuthority is already assigned).
	var pause: Node = auto_free(PauseAuthorityScript.new())
	add_child(pause)
	controller.set_pause_authority_for_test(pause)
	# No PackedScene assignment needed: the @export defaults already preload
	# the real scenes/ui/*.tscn wrappers this task built.
	auto_free(controller)
	add_child(controller)
	return controller


func test_scrap_reads_zero_on_run_end_screen_when_run_inventory_connects_first() -> void:
	var bus: Node = _make_fake_bus()
	var inventory: RunInventory = RunInventoryScript.new() as RunInventory
	inventory.configure(_make_economy_configuration(), bus) # connects RunInventory's zeroing handler FIRST
	inventory.scrap_current = 150

	var controller: RunFlowController = _make_controller()
	controller.set_event_bus_for_test(bus) # connects the controller's handler SECOND
	controller.set_run_inventory(inventory)

	bus.emit_signal("player_died", auto_free(Node.new()), Vector2.ZERO, 0.0)
	await get_tree().process_frame # let the deferred _end_run() run -- see run_flow_controller.gd's own header

	assert_int(inventory.scrap_current).append_failure_message("RunInventory itself did not zero Scrap on player_died").is_equal(0)
	var run_end: RunEndScreen = controller.run_end_screen
	assert_object(run_end).append_failure_message("RunFlowController never built its RunEndScreen").is_not_null()
	assert_str(run_end.get_scrap_label_for_test().text).append_failure_message("run-end Scrap label did not read zero: '%s'" % run_end.get_scrap_label_for_test().text).contains(": 0")
	assert_str(run_end.get_scrap_label_for_test().text).append_failure_message("run-end Scrap label shows the pre-death cached value (150), not the zeroed one").not_contains("150")
	assert_int(controller.get_summary_for_test()["scrap_held"]).is_equal(0)


## The reverse connection order: RunFlowController connects to `player_died`
## BEFORE RunInventory does. A cache-at-signal-time implementation would
## capture 150 here even though it reads correctly under the other order --
## proving the fix is order-independent, not order-lucky.
func test_scrap_reads_zero_on_run_end_screen_when_controller_connects_first() -> void:
	var bus: Node = _make_fake_bus()
	var controller: RunFlowController = _make_controller()
	controller.set_event_bus_for_test(bus) # connects the controller's handler FIRST

	var inventory: RunInventory = RunInventoryScript.new() as RunInventory
	inventory.configure(_make_economy_configuration(), bus) # connects RunInventory's zeroing handler SECOND
	inventory.scrap_current = 150
	controller.set_run_inventory(inventory)

	bus.emit_signal("player_died", auto_free(Node.new()), Vector2.ZERO, 0.0)
	await get_tree().process_frame

	assert_int(inventory.scrap_current).is_equal(0)
	var run_end: RunEndScreen = controller.run_end_screen
	assert_str(run_end.get_scrap_label_for_test().text).append_failure_message("connection-order dependency: run-end Scrap label did not read zero when the controller connected first: '%s'" % run_end.get_scrap_label_for_test().text).contains(": 0")
	assert_int(controller.get_summary_for_test()["scrap_held"]).is_equal(0)


## "No Scrap carries to the next run": nothing re-credits scrap_current
## after the zeroing, for as long as this RunInventory instance lives, and
## a fresh instance -- which is what any future run-start flow would
## construct -- starts at its own documented default of 0 regardless.
func test_scrap_stays_zero_after_death_and_a_fresh_inventory_also_starts_at_zero() -> void:
	var bus: Node = _make_fake_bus()
	var inventory: RunInventory = RunInventoryScript.new() as RunInventory
	inventory.configure(_make_economy_configuration(), bus)
	inventory.scrap_current = 80

	bus.emit_signal("player_died", auto_free(Node.new()), Vector2.ZERO, 0.0)

	assert_int(inventory.scrap_current).is_equal(0)
	inventory.credit_scrap(0) # a genuine no-op call (amount <= 0); confirms nothing silently re-credits on its own
	assert_int(inventory.scrap_current).is_equal(0)

	var fresh: RunInventory = RunInventoryScript.new() as RunInventory
	assert_int(fresh.scrap_current).append_failure_message("RunInventory.scrap_current's own declared default is not 0 -- 'no Scrap carries to the next run' would not hold for a freshly constructed run").is_equal(0)
