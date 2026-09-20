extends GdUnitTestSuite

## Movement-only test (P2.14 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Technical Tests > "Movement-only test": "Using
## only movement input, an internal tester resolves every Level-Up Draft of
## a prototype run and, with the Movement-only controls setting on,
## completes at least one Console purchase; with the setting off, standing
## beside the Tower for 60 seconds buys nothing."
##
## Written as the task brief asks -- "a scripted equivalent using this
## project's existing input-injection test seams" -- against the REAL
## src/ui/draft_controller.gd (P2.12) and src/ui/console.gd (P2.13), never
## a stand-in. Two halves:
## 1. The Draft half drives DraftController's own `_use_test_input` double
##    (tests/unit/draft_input_lockout_test.gd's own established pattern)
##    using ONLY `move_left` / `move_right` / `move_up` -- never `confirm`,
##    never `draft_select_1/2/3`, never `reroll`, never `draft_cycle_left/
##    right` -- across THREE separate level-ups, so "every Level-Up Draft
##    of a run" is exercised more than once, not just the first.
## 2. The Console half drives Console.physics_step() directly against a
##    manually-advanced SimClock (tests/unit/console_rules_test.gd's own
##    established pattern, including its `FakeInteractionRadius` shape),
##    proving a Movement-only sector purchase completes from POSITION AND
##    STANDING STILL ALONE -- no discrete input call of any kind, which is
##    the truest "movement only" path docs/19 defines (a sector purchase
##    needs no button at all) -- and that with the setting off, standing in
##    the Interaction Radius for a full 60 (simulated) seconds spends
##    nothing, because no discrete "start a purchase" input was ever sent
##    either.
##
## ## What this script cannot cover (named plainly, per the task brief)
## "An internal tester" names a HUMAN play session across a run whose
## level-ups arise from genuine XP gained through real combat, and whose
## Console approach is genuine, reflexive movement-only play -- neither is
## reproducible by a script. What IS mechanically provable, and is proven
## here, is the RULE: the movement-only cycle-and-hold-to-confirm path
## resolves a Draft with no other input class touched; a Movement-only
## sector purchase requires no button; and the setting being off removes
## the ONLY way a script (or a player) could ever start a purchase without
## a discrete input action. See the P2.14 evidence report for this same
## list.

const DraftTestHelpers: GDScript = preload("res://tests/unit/draft_test_helpers.gd")
const ConsoleScript: GDScript = preload("res://src/ui/console.gd")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")

const STEP: float = 1.0 / 60.0

const DWELL: float = 0.3 # Register > Interfaces > "Tower Console rules" -- independent literal, not read back from Console's own constant (console_rules_test.gd's own established discipline)
const SECTOR_DWELL: float = 1.0 # docs/19 > Tower Console UI > Input


class FakeInteractionRadius:
	var inside: bool = true
	func is_player_inside() -> bool:
		return inside


func after_test() -> void:
	# Safety net (pause_clock_test.gd's own precedent): every PauseAuthority
	# instance in this file is fresh, never the real autoload, but a failed
	# assertion mid-draft-resolution must still never leak a stuck pause
	# into the SHARED tree for a suite that runs after this one.
	get_tree().paused = false


# --- Draft half ---------------------------------------------------------------

func _advance_draft(controller: DraftController, ticks: int) -> void:
	for _i in ticks:
		controller.tick_for_test(STEP)


## Resolves exactly one open Draft using ONLY move_left/move_right/move_up.
## Cycles right once (proves cycling works, not merely "confirm index 0"),
## then holds move_up past the 1.0 s hold-to-confirm threshold.
func _resolve_one_draft_movement_only(controller: DraftController) -> void:
	assert_bool(controller.is_draft_showing_for_test()).append_failure_message("test setup: no Draft is open to resolve").is_true()

	# Past the 0.4 s input lockout, touching no input at all.
	_advance_draft(controller, int(ceil(0.4 / STEP)) + 2)
	assert_bool(controller.is_lockout_elapsed_for_test()).is_true()

	# Cycle right once (movement key, not draft_cycle_right).
	controller.set_action_pressed_for_test(&"move_right", true)
	_advance_draft(controller, 1)
	controller.set_action_pressed_for_test(&"move_right", false)
	_advance_draft(controller, 2)
	assert_int(controller.get_highlighted_index_for_test()).is_equal(1)

	# Hold move_up past the 1.0 s confirm threshold.
	controller.set_action_pressed_for_test(&"move_up", true)
	_advance_draft(controller, int(ceil(1.0 / STEP)) + 2)
	controller.set_action_pressed_for_test(&"move_up", false)
	_advance_draft(controller, 1)


func test_every_level_up_draft_in_a_run_resolves_using_only_movement_input() -> void:
	var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()
	var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(upgrade_system)
	var pause: Node = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(pause)
	var clock: Node = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(clock)

	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(controller)
	controller.set_run_inventory_for_test(run_inventory)
	controller.set_upgrade_system_for_test(upgrade_system)
	controller.set_pause_authority_for_test(pause)
	controller.set_sim_clock_for_test(clock)
	controller.set_test_input_mode_for_test(true)

	# Three separate level-ups -- "every Level-Up Draft of a run", not just
	# the first one.
	for i in 3:
		run_inventory.credit_xp(run_inventory.xp_required_for_next_level + 1.0) # crosses exactly one threshold (RunInventory.credit_xp()'s own while loop)
		controller.physics_step(STEP) # SimLoop step 11 entry point: detects the level-up, opens the Draft

		assert_bool(controller.is_draft_showing_for_test()).append_failure_message("Draft #%d never opened" % (i + 1)).is_true()
		var rank_before: int = upgrade_system.get_current_rank(controller.get_current_card_ids_for_test()[1])
		var chosen_id: String = controller.get_current_card_ids_for_test()[1] # index 1, matching the single move_right cycle in _resolve_one_draft_movement_only()

		_resolve_one_draft_movement_only(controller)

		assert_bool(controller.is_draft_showing_for_test()).append_failure_message("Draft #%d did not close after a movement-only confirm" % (i + 1)).is_false()
		assert_int(upgrade_system.get_current_rank(chosen_id)).append_failure_message("movement-only confirm did not apply a rank to '%s' on Draft #%d" % [chosen_id, i + 1]).is_equal(rank_before + 1)

	assert_bool(controller.is_draft_session_active_for_test()).append_failure_message("Draft session stayed active after the last queued Draft closed").is_false()
	assert_bool(pause.has_reason(PauseAuthority.REASON_DRAFT)).append_failure_message("the draft pause reason was never popped").is_false()


# --- Console half --------------------------------------------------------------

func _advance_console(console: Console, clock: Node, ticks: int) -> void:
	for _i in ticks:
		clock.now += STEP
		console.physics_step(STEP)


func _build_console_harness(clock: Node, pause: Node, movement_only: bool, scrap: int, bearing_deg: float) -> Dictionary:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(tower)

	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	add_child(player)
	var dir: Vector2 = Console._direction_from_bearing(bearing_deg)
	player.global_position = tower.global_position + dir * 150.0
	player.velocity = Vector2.ZERO # below the 10% speed gate -- "standing beside the Tower"

	var upgrade_system: UpgradeSystem = auto_free(UpgradeSystemScript.new()) as UpgradeSystem
	add_child(upgrade_system)

	var inventory: RunInventory = RunInventoryScript.new()
	inventory.scrap_current = scrap

	var console: Console = auto_free(ConsoleScript.new()) as Console
	console.driven_externally = true
	console.movement_only_controls_enabled = movement_only
	console.set_sim_clock_for_test(clock)
	console.set_pause_authority_for_test(pause)
	console.set_tower_for_test(tower)
	console.set_player_for_test(player)
	console.set_interaction_radius_for_test(FakeInteractionRadius.new())
	console.set_upgrade_system_for_test(upgrade_system)
	console.set_run_inventory(inventory)
	add_child(console)

	return {"console": console, "inventory": inventory, "upgrade_system": upgrade_system, "player": player, "tower": tower}


func test_movement_only_on_completes_a_console_purchase_from_position_and_standing_still_alone() -> void:
	var clock: Node = auto_free(SimClockScript.new()) as Node
	var pause: Node = auto_free(PauseAuthorityScript.new()) as Node

	# Sector 1's own centre bearing (SECTOR_IDS[1] = "rapid_fire") -- computed
	# from the Console's own public sector-width constant, not hardcoded, so
	# this test does not silently drift if that geometry ever changes.
	var bearing: float = 1.5 * Console.SECTOR_WIDTH_DEG
	var h: Dictionary = _build_console_harness(clock, pause, true, 500, bearing)
	var console: Console = h["console"]
	var upgrade_system: UpgradeSystem = h["upgrade_system"]
	var inventory: RunInventory = h["inventory"]

	assert_int(console.get_current_sector_index_for_test()).append_failure_message("test setup: player is not standing in sector 1").is_equal(1)
	var sector_id: String = Console.SECTOR_IDS[1]
	assert_int(upgrade_system.get_current_rank(sector_id)).is_equal(0)

	# Open dwell (0.3 s) then the sector's own 1.0 s dwell -- NOT ONE discrete
	# input call anywhere in this test: no _unhandled_input(), no
	# start_channel_for_highlighted(), no select_and_start_channel(). Only
	# physics_step() ticks against a fixed position and zero velocity.
	_advance_console(console, clock, int(ceil(DWELL / STEP)) + 2)
	assert_bool(console.is_open()).append_failure_message("Console did not open with an affordable pool at 500 Scrap").is_true()

	_advance_console(console, clock, int(ceil(SECTOR_DWELL / STEP)) + 2)

	assert_int(upgrade_system.get_current_rank(sector_id)).append_failure_message("standing in the Movement-only sector for its full dwell did not buy a rank of '%s'" % sector_id).is_equal(1)
	assert_int(inventory.scrap_current).append_failure_message("a Movement-only sector purchase completed but no Scrap was spent").is_less(500)


func test_movement_only_off_standing_beside_the_tower_for_sixty_seconds_buys_nothing() -> void:
	var clock: Node = auto_free(SimClockScript.new()) as Node
	var pause: Node = auto_free(PauseAuthorityScript.new()) as Node

	var bearing: float = 1.5 * Console.SECTOR_WIDTH_DEG # same physical spot as the ON case above
	var h: Dictionary = _build_console_harness(clock, pause, false, 500, bearing)
	var console: Console = h["console"]
	var upgrade_system: UpgradeSystem = h["upgrade_system"]
	var inventory: RunInventory = h["inventory"]

	_advance_console(console, clock, int(60.0 / STEP)) # a full 60 simulated seconds, standing still, no discrete input ever sent

	assert_bool(console.is_open()).append_failure_message("test setup: the Console should still have opened (opening itself needs no Movement-only setting)").is_true()
	assert_bool(console.is_channel_active()).append_failure_message("a purchase channel started with the Movement-only setting off and no discrete input ever sent").is_false()
	assert_int(inventory.scrap_current).append_failure_message("Scrap was spent with the Movement-only setting off and no discrete input ever sent").is_equal(500)
	for id in Console.SECTOR_IDS:
		if id != "":
			assert_int(upgrade_system.get_current_rank(id)).append_failure_message("'%s' gained a rank with the Movement-only setting off and no discrete input ever sent" % id).is_equal(0)
