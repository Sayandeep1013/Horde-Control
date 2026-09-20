extends GdUnitTestSuite

## Console rules test (named acceptance test, P2.13): the full lifecycle
## rule from docs/19_UI_UX.md > "Tower Console UI" > "Lifecycle" and
## MASTER_SDLC.md > Provisional Values Register > Interfaces > "Tower
## Console rules" -- the 0.3 s dwell, the speed gate, the affordability gate
## (Repair greyed at 0 Scrap not counting toward opening, C-REPAIR), every
## close condition, the stay-closed-after-Cancel rule, the 0.5 s channel
## cancelling without charge above 10% base speed, and the Movement-only
## sector rearm rule (C-SECTORS).
##
## Every scenario drives Console.physics_step() directly against a fresh,
## manually-advanced SimClock instance (never ticked by its own
## _physics_process -- `.now` is set by hand) so every deadline boundary is
## exact and deterministic, with no dependency on real engine frame timing.
## `driven_externally = true` stops the node's own `_physics_process` from
## ALSO stepping it if a test happens to await a frame, so only the
## explicit physics_step() calls below ever advance state (see
## src/ui/console.gd's own header, "SimLoop registration").
##
## The Interaction Radius and Tower/Player speed are test doubles/direct
## field writes -- this suite's claim is about the CONSOLE's own state
## machine, not about real Area2D overlap physics (P2.4's own scope) or
## real CharacterBody2D movement (P2.1's own scope).

const ConsoleScript: GDScript = preload("res://src/ui/console.gd")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")


## Independent literals, cited to the Register directly -- NOT read back
## from Console's own constants. A first falsification pass (removing the
## 0.3 s dwell by setting Console.OPEN_DWELL_SECONDS to 0.0) exposed that
## `const DWELL: float = Console.OPEN_DWELL_SECONDS` bakes in whatever value
## the mutated class currently holds at compile time, so every assertion
## built from it silently follows the mutation instead of catching it --
## exactly the "test captures the very thing it should police" failure mode
## this project's own convention warns against (upgrade_effect_check_test.gd:
## "never read back from whatever the system under test happens to
## produce"). Fixed by hardcoding the Register's own numbers here instead.
const DWELL: float = 0.3 # Register > Interfaces > "Tower Console rules": "Opens after 0.3 s..."
const SPEED_GATE: float = 0.10 # same row: "player speed < 10% base"
const CHANNEL: float = 0.5 # same row: "every purchase is a 0.5 s channel"
const SECTOR_DWELL: float = 1.0 # docs/19 > Tower Console UI > Input: "Standing still ... for 1.0 second buys one rank"


class FakeInteractionRadius:
	var inside: bool = true
	func is_player_inside() -> bool:
		return inside


var _clock: Node
var _pause: Node


func before_test() -> void:
	# Node (not RefCounted), and Godot Nodes are never garbage-collected by
	# reference count alone -- an un-added, un-freed Node.new() is a
	# guaranteed leak (reproduced: 1 orphan per test before this fix).
	# auto_free() disposes it at teardown without requiring tree membership;
	# .now is still advanced entirely by hand, never by its own _physics_process.
	_clock = auto_free(SimClockScript.new()) as Node
	_pause = auto_free(PauseAuthorityScript.new()) as Node
	add_child(_pause) # needed so PauseAuthority._apply_paused_state() can emit reasons_changed (requires get_tree())


func after_test() -> void:
	get_tree().paused = false


func _advance(console: Console, seconds: float, ticks: int = 4) -> void:
	var step: float = seconds / float(ticks)
	for i in range(ticks):
		_clock.now += step
		console.physics_step(step)


func _build_player(speed_fraction_of_base: float = 0.0, position: Vector2 = Vector2(50, 0)) -> Player:
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	add_child(player)
	player.global_position = position
	var base_speed: float = player.definition.base_speed_px_per_second
	player.velocity = Vector2(base_speed * speed_fraction_of_base, 0.0)
	return player


func _build_tower() -> Tower:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(tower)
	return tower


func _build_console(tower: Tower, player: Player, upgrade_system: UpgradeSystem, inventory: RunInventory, radius: FakeInteractionRadius) -> Console:
	var console: Console = auto_free(ConsoleScript.new()) as Console
	console.driven_externally = true
	console.set_sim_clock_for_test(_clock)
	console.set_pause_authority_for_test(_pause)
	console.set_tower_for_test(tower)
	console.set_player_for_test(player)
	console.set_interaction_radius_for_test(radius)
	console.set_upgrade_system_for_test(upgrade_system)
	console.set_run_inventory(inventory)
	add_child(console)
	return console


func _build_upgrade_system() -> UpgradeSystem:
	var system: UpgradeSystem = auto_free(UpgradeSystemScript.new()) as UpgradeSystem
	add_child(system)
	return system


func _build_upgrade_system_repair_only() -> UpgradeSystem:
	# An empty pool: every ranked-upgrade lookup returns "unknown", which
	# UpgradeSystem itself resolves to not-maxed/-1-cost/never-affordable
	# (get_console_cost() returns -1 for an unknown id) -- isolating Repair
	# as the ONLY entry that can ever be affordable.
	var system: UpgradeSystem = auto_free(UpgradeSystemScript.new()) as UpgradeSystem
	system.set_upgrade_definitions_for_test([])
	add_child(system)
	return system


func _inventory(scrap: int) -> RunInventory:
	var inv: RunInventory = RunInventoryScript.new()
	inv.scrap_current = scrap
	return inv


func _damage_tower(tower: Tower, amount: float) -> void:
	tower.death_state.current_hp = maxf(0.0, tower.death_state.current_hp - amount)


# --- 0.3 s dwell -------------------------------------------------------------

func test_console_does_not_open_before_0_3_second_dwell() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(100), FakeInteractionRadius.new())

	# Fine ticks (50) so the "dwell start" snapshot -- itself taken on the
	# first qualifying tick, at that tick's own SimClock.now, not at 0 --
	# loses only a negligible fraction of a second to tick granularity,
	# keeping this boundary check tight against the real 0.3 s deadline.
	_advance(console, DWELL - 0.05, 50)
	assert_bool(console.is_open()).append_failure_message("Console opened before its 0.3 s dwell elapsed").is_false()

	_advance(console, 0.10, 50)
	assert_bool(console.is_open()).append_failure_message("Console did not open once the 0.3 s dwell elapsed with an affordable entry").is_true()


func test_console_does_not_open_if_player_speed_is_at_or_above_10_percent_base() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(SPEED_GATE + 0.01) # just over the 10% gate
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(100), FakeInteractionRadius.new())

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).append_failure_message("Console opened while the player was moving at or above 10% base speed").is_false()


# --- Affordability gate / C-REPAIR ------------------------------------------

func test_repair_at_zero_scrap_does_not_open_the_console_even_when_tower_is_damaged() -> void:
	var tower: Tower = _build_tower()
	_damage_tower(tower, 100.0) # plenty of missing health
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system_repair_only()
	var console: Console = _build_console(tower, player, system, _inventory(0), FakeInteractionRadius.new())

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).append_failure_message("At 0 Scrap, Repair must not count toward opening the Console (C-REPAIR)").is_false()

	var repair_entry: Dictionary = console.get_entry_for_test(0)
	assert_bool(bool(repair_entry.get("affordable", true))).append_failure_message("Repair entry reported affordable at 0 Scrap").is_false()


func test_repair_becomes_affordable_and_opens_the_console_once_scrap_is_held() -> void:
	var tower: Tower = _build_tower()
	_damage_tower(tower, 100.0)
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system_repair_only()
	var console: Console = _build_console(tower, player, system, _inventory(1), FakeInteractionRadius.new())

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).append_failure_message("Repair should be affordable (missing >= 2 health, >= 1 Scrap held) and open the Console").is_true()


func test_repair_entry_stays_greyed_while_console_is_open_for_another_reason() -> void:
	var tower: Tower = _build_tower() # full health -- Repair stays unaffordable regardless of Scrap
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(40), FakeInteractionRadius.new()) # enough for Rapid Fire rank 1 (30)

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).append_failure_message("Console should have opened via Rapid Fire's affordability").is_true()
	var repair_entry: Dictionary = console.get_entry_for_test(0)
	assert_bool(bool(repair_entry.get("affordable", true))).append_failure_message("Repair entry must stay greyed (Tower undamaged) even while the Console is open for another entry, and it must never be hidden").is_false()


# --- Close conditions --------------------------------------------------------

func test_console_closes_when_player_leaves_the_radius() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var radius: FakeInteractionRadius = FakeInteractionRadius.new()
	var console: Console = _build_console(tower, player, system, _inventory(100), radius)

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).is_true()

	radius.inside = false
	console.physics_step(0.016)
	assert_bool(console.is_open()).append_failure_message("Console must close on leaving the Interaction Radius").is_false()


func test_cancel_closes_the_console_and_blocks_reopening_until_leave_and_reenter() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var radius: FakeInteractionRadius = FakeInteractionRadius.new()
	var console: Console = _build_console(tower, player, system, _inventory(100), radius)

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).is_true()

	console.request_cancel()
	assert_bool(console.is_open()).append_failure_message("Cancel must close the Console").is_false()
	assert_bool(console.get_requires_reentry_for_test()).append_failure_message("Cancel must lock the Console closed until leave-and-reenter").is_true()

	# Still standing still, still affordable, still inside -- must NOT reopen.
	_advance(console, DWELL * 5.0)
	assert_bool(console.is_open()).append_failure_message("Console reopened after Cancel without the player leaving and re-entering the radius").is_false()

	radius.inside = false
	console.physics_step(0.016) # a real exit tick
	assert_bool(console.get_requires_reentry_for_test()).is_true() # leaving alone does not clear the lock

	radius.inside = true
	console.physics_step(0.016) # the fresh entry edge that clears the lock
	assert_bool(console.get_requires_reentry_for_test()).append_failure_message("A fresh entry after leaving must clear the post-Cancel lock").is_false()

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).append_failure_message("Console did not reopen after a genuine leave-and-reenter").is_true()


func test_console_closes_on_player_death() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(100), FakeInteractionRadius.new())

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).is_true()

	console._on_player_died() # this file's own DIRECT listener method, mirroring EventBus.player_died's payload-agnostic handler
	assert_bool(console.is_open()).append_failure_message("Console must close on player death").is_false()

	_advance(console, DWELL * 5.0)
	assert_bool(console.is_open()).append_failure_message("Console must not reopen after player death").is_false()


func test_draft_pause_reason_closes_the_console_without_requiring_reentry() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(100), FakeInteractionRadius.new())

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).is_true()

	_pause.push_reason(PauseAuthority.REASON_DRAFT)
	_pause.flush() # synchronously emits reasons_changed -> Console._on_pause_reasons_changed()

	assert_bool(console.is_open()).append_failure_message("Console must close the instant a Level-Up Draft opens").is_false()
	assert_bool(console.get_requires_reentry_for_test()).append_failure_message("A Draft-triggered close must NOT require leave-and-reenter, unlike Cancel").is_false()

	_pause.pop_reason(PauseAuthority.REASON_DRAFT)
	_pause.flush()

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).append_failure_message("Console should reopen normally (via ordinary dwell) once the Draft closes").is_true()


func test_console_hidden_while_a_non_draft_pause_reason_is_active_but_stays_open_underneath() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(100), FakeInteractionRadius.new())

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).is_true()
	assert_bool(console.get_paused_for_test()).is_false()

	_pause.push_reason(PauseAuthority.REASON_PAUSE_MENU)
	_pause.flush()

	assert_bool(console.get_paused_for_test()).append_failure_message("Console must register as paused/hidden/input-dead while ANY pause reason is active").is_true()
	assert_bool(console.is_open()).append_failure_message("A non-Draft pause reason (pause menu) must not force-close the Console the way Draft does").is_true()

	_pause.pop_reason(PauseAuthority.REASON_PAUSE_MENU)
	_pause.flush()
	assert_bool(console.get_paused_for_test()).is_false()
	assert_bool(console.is_open()).append_failure_message("Console should still be open once the non-Draft pause reason clears -- no re-dwell needed").is_true()


# --- Purchase channel: charges exactly once, cancels without charge --------

func test_purchase_channel_completes_and_charges_scrap_exactly_once() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var inventory: RunInventory = _inventory(100)
	var console: Console = _build_console(tower, player, system, inventory, FakeInteractionRadius.new())

	_advance(console, DWELL * 3.0)
	assert_bool(console.is_open()).is_true()
	assert_bool(console.select_and_start_channel(1)).append_failure_message("Failed to start the Rapid Fire purchase channel").is_true()
	assert_bool(console.is_channel_active()).is_true()

	_advance(console, CHANNEL + 0.05)

	assert_bool(console.is_channel_active()).append_failure_message("Channel did not complete/reset after its 0.5 s duration").is_false()
	assert_int(system.get_current_rank("rapid_fire")).is_equal(1)
	assert_int(inventory.scrap_current).append_failure_message("Scrap was not charged exactly once for Rapid Fire rank 1 (30 Scrap)").is_equal(70)

	# No further, silent charge on later ticks.
	_advance(console, CHANNEL * 2.0)
	assert_int(inventory.scrap_current).append_failure_message("A completed channel charged Scrap more than once").is_equal(70)


func test_purchase_channel_cancels_without_charge_above_10_percent_speed() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0)
	var system: UpgradeSystem = _build_upgrade_system()
	var inventory: RunInventory = _inventory(100)
	var console: Console = _build_console(tower, player, system, inventory, FakeInteractionRadius.new())

	_advance(console, DWELL * 3.0)
	assert_bool(console.select_and_start_channel(1)).is_true()

	# Halfway through the channel, the player moves fast.
	_advance(console, CHANNEL * 0.5)
	assert_bool(console.is_channel_active()).is_true()
	var base_speed: float = player.definition.base_speed_px_per_second
	player.velocity = Vector2(base_speed * (SPEED_GATE + 0.05), 0.0)
	console.physics_step(0.016)

	assert_bool(console.is_channel_active()).append_failure_message("Channel must cancel the instant the player exceeds 10% base speed").is_false()
	assert_int(system.get_current_rank("rapid_fire")).append_failure_message("A cancelled channel must not apply the rank").is_equal(0)
	assert_int(inventory.scrap_current).append_failure_message("A cancelled channel must charge nothing").is_equal(100)

	# Even after the original duration would have elapsed, nothing completes.
	_advance(console, CHANNEL * 2.0)
	assert_int(inventory.scrap_current).is_equal(100)


# --- Movement-only sectors (C-SECTORS) --------------------------------------

func test_sector_purchase_after_1_second_dwell_and_then_rearm_rule() -> void:
	var tower: Tower = _build_tower()
	# North of the Tower (bearing 0) sits sector 0, Repair; Rapid Fire is the
	# NEXT sector clockwise (index 1). A position at 90 degrees / 7 =
	# roughly 12.86 degrees past north lands well inside sector 1's
	# ~51.4-degree span without being near either boundary.
	var bearing_deg: float = Console.SECTOR_WIDTH_DEG * 1.5
	var rad: float = deg_to_rad(bearing_deg)
	var offset: Vector2 = Vector2(sin(rad), -cos(rad)) * 50.0
	var player: Player = _build_player(0.0, offset)
	var system: UpgradeSystem = _build_upgrade_system()
	var inventory: RunInventory = _inventory(100)
	var console: Console = _build_console(tower, player, system, inventory, FakeInteractionRadius.new())
	console.movement_only_controls_enabled = true

	assert_int(console.get_current_sector_index_for_test()).append_failure_message("Test position did not land in sector index 1 (Rapid Fire)").is_equal(1)

	_advance(console, DWELL * 3.0) # open the Console via ordinary dwell first (a sector purchase requires the Console open)
	assert_bool(console.is_open()).is_true()

	_advance(console, SECTOR_DWELL + 0.05, 50)

	assert_int(system.get_current_rank("rapid_fire")).append_failure_message("Standing still in the Rapid Fire sector for 1.0 s should have bought one rank").is_equal(1)
	assert_int(inventory.scrap_current).is_equal(70)
	assert_bool(console.is_sector_armed_for_test(1)).append_failure_message("A sector must disarm immediately after a purchase, so the same window cannot buy twice").is_false()

	# Still standing in the same sector, still slow: must NOT buy again.
	_advance(console, SECTOR_DWELL * 2.0)
	assert_int(inventory.scrap_current).append_failure_message("A disarmed sector bought a second time without the player moving away or leaving it").is_equal(70)

	# Move fast, then return: the sector must re-arm.
	var base_speed: float = player.definition.base_speed_px_per_second
	player.velocity = Vector2(base_speed * (SPEED_GATE + 0.2), 0.0)
	console.physics_step(0.05)
	player.velocity = Vector2.ZERO
	assert_bool(console.is_sector_armed_for_test(1)).append_failure_message("Moving above 10% base speed must re-arm the sector").is_true()

	_advance(console, SECTOR_DWELL + 0.05, 50)
	assert_int(system.get_current_rank("rapid_fire")).append_failure_message("A re-armed sector should be able to buy again").is_equal(2)
	assert_int(inventory.scrap_current).is_equal(70 - 60) # rank 2 costs 30 x 2 = 60


# --- Placement geometry (docs/19 > Tower Console UI > "Placement";
# MASTER_SDLC.md > Interfaces > "Tower Console rules", C-CONSOLE-NODE) ------
# Asserted numerically per this project's own convention (F03-20): a panel
# can pass every content assertion while sitting in the wrong place on
# screen, so its 200 px offset, 30-degree flip hysteresis, and 24 px text
# floor are each checked as GEOMETRY, not merely "the node exists."

func test_placement_puts_the_panels_nearest_edge_exactly_200px_from_the_tower_along_the_opposite_bearing() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0, Vector2(0, -50)) # due north of the Tower
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(100), FakeInteractionRadius.new())
	console.set_panel_size_override_for_test(Vector2(200, 100)) # exact, known half-extent (100, 50)

	console.force_refresh_for_test()

	# Player is due north (bearing 0) -> the panel sits due SOUTH of the
	# Tower (the bearing opposite the player).
	var placement: Vector2 = console.get_placement_position_for_test()
	assert_float(placement.x).append_failure_message("Panel should sit directly south of the Tower on the X axis").is_equal_approx(0.0, 0.01)
	assert_bool(placement.y > 0.0).append_failure_message("Panel should sit SOUTH (+Y) of the Tower, opposite the player to the north").is_true()

	# The NEAREST edge (half the known panel height back toward the Tower)
	# must sit exactly 200 px from the Tower's centre.
	var half_extent: Vector2 = Vector2(100.0, 50.0)
	var dir_to_panel: Vector2 = placement.normalized()
	var nearest_edge: Vector2 = placement - dir_to_panel * half_extent.y
	assert_float(nearest_edge.distance_to(tower.global_position)).append_failure_message("The panel's nearest edge must sit exactly 200 px from the Tower's centre (C-CONSOLE-NODE)").is_equal_approx(200.0, 0.5)


func test_placement_does_not_flip_side_until_a_30_degree_bearing_change() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0, Vector2(0, -50)) # bearing 0 (north)
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(100), FakeInteractionRadius.new())
	console.set_panel_size_override_for_test(Vector2(200, 100))

	console.force_refresh_for_test()
	assert_float(console.get_committed_bearing_for_test()).is_equal_approx(0.0, 0.01)

	# Move the player to bearing ~20 degrees (well under the 30 degree
	# threshold) -- the committed placement bearing must NOT move.
	var small_rad: float = deg_to_rad(20.0)
	player.global_position = Vector2(sin(small_rad), -cos(small_rad)) * 50.0
	console.force_refresh_for_test()
	assert_float(console.get_committed_bearing_for_test()).append_failure_message("The panel flipped before the player's bearing changed by more than 30 degrees -- it must not flicker").is_equal_approx(0.0, 0.01)

	# Now move past the 30 degree threshold -- it MUST commit to the new bearing.
	var big_rad: float = deg_to_rad(40.0)
	player.global_position = Vector2(sin(big_rad), -cos(big_rad)) * 50.0
	console.force_refresh_for_test()
	assert_float(console.get_committed_bearing_for_test()).append_failure_message("The panel did not flip after a bearing change of more than 30 degrees").is_equal_approx(40.0, 0.01)


func test_placement_scale_follows_camera_view_scale_to_keep_entry_text_at_least_24px_tall() -> void:
	var tower: Tower = _build_tower()
	var player: Player = _build_player(0.0, Vector2(0, -50))
	var system: UpgradeSystem = _build_upgrade_system()
	var console: Console = _build_console(tower, player, system, _inventory(100), FakeInteractionRadius.new())
	console.set_panel_size_override_for_test(Vector2(200, 100))

	console.force_refresh_for_test()
	assert_float(console.scale.y).append_failure_message("With no camera wired, scale must default to 1.0 (view scale 1.0 = 1920x1080 world px, Register > Arena & Camera)").is_equal_approx(1.0, 0.001)
	assert_float(console.scale.y * Console.ENTRY_FONT_SIZE_PX).is_greater_equal(24.0)

	var camera := auto_free(GameCamera.new()) as GameCamera
	camera.set_view_scale(1.15, false) # Register > Arena & Camera > "View scale": VIEW_SCALE_MAX, camera zoomed OUT
	console.set_camera_for_test(camera)
	console.force_refresh_for_test()

	assert_float(console.scale.y).append_failure_message("Console.scale must track GameCamera.get_view_scale() every frame (C-CONSOLE-NODE: 'scale set each frame to the view scale')").is_equal_approx(1.15, 0.01)
	# The invariant this whole mechanism exists for: on-screen text height
	# (local font size / view_scale, since screen_size = world_size / view_scale
	# for a Node2D scaled by view_scale = world_size_at_scale_1 unchanged)
	# stays at exactly the Register's 24 px floor at every legal view scale.
	var effective_on_screen_px: float = (Console.ENTRY_FONT_SIZE_PX * console.scale.y) / camera.get_view_scale()
	assert_float(effective_on_screen_px).append_failure_message("Entry text dropped below the 24 px on-screen floor at the camera's maximum zoom-out").is_greater_equal(24.0 - 0.01)
