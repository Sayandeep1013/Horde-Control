extends GdUnitTestSuite

## Console non-pause test (named acceptance test, P2.13). MASTER_SDLC.md >
## Acceptance Test Matrix > Technical Tests: "with the Console open,
## SimClock.now advances and enemies keep moving." MASTER_SDLC.md > Global
## Simulation Authority: "The Tower Console is the one exception to
## pausing ... it never adds a pause reason."
##
## Uses FRESH SimClock/PauseAuthority instances added to this suite's own
## tree (never the real Autoload singletons -- tests/unit/pause_clock_test.gd's
## own established pattern) and drives REAL engine physics frames
## (`await get_tree().physics_frame`) so `get_tree().paused` reflects genuine
## engine pause state, not a value this suite merely reads back. An "enemy
## stand-in" node (PROCESS_MODE_PAUSABLE, exactly like every real gameplay
## entity in this project) proves the tree never actually paused: if the
## Console pushed ANY pause reason, this stand-in would freeze, exactly as
## pause_clock_test.gd's own SimClock freezes under a real pause.
##
## The Interaction Radius is a lightweight fake (`is_player_inside()` fixed
## true) rather than a real Area2D overlap -- this test's own claim is about
## PAUSING, not about physics overlap detection (the dwell/gate/lifecycle
## rules that DO depend on real conditions are covered by
## console_rules_test.gd).

const ConsoleScript: GDScript = preload("res://src/ui/console.gd")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")

const RAPID_FIRE_RANK_1_COST: int = 30 # Register > Progression & Upgrades > "Console price": 30 x rank (rank 1 -> 30)

class FakeInteractionRadius:
	var inside: bool = true
	func is_player_inside() -> bool:
		return inside


class EnemyStandIn extends Node:
	var ticks: int = 0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
	func _physics_process(_delta: float) -> void:
		ticks += 1


var _clock: Node
var _pause: Node


func before_test() -> void:
	_clock = auto_free(SimClockScript.new()) as Node
	_pause = auto_free(PauseAuthorityScript.new()) as Node
	add_child(_pause)
	add_child(_clock)
	await get_tree().physics_frame


func after_test() -> void:
	# Safety net: an interrupted/failed test must never leave the SHARED
	# scene tree paused for suites that run after it.
	get_tree().paused = false


func _build_console(tower: Tower, player: Player, upgrade_system: UpgradeSystem, inventory: RunInventory) -> Console:
	var console: Console = auto_free(ConsoleScript.new()) as Console
	console.set_sim_clock_for_test(_clock)
	console.set_pause_authority_for_test(_pause)
	console.set_tower_for_test(tower)
	console.set_player_for_test(player)
	console.set_player_weapon_for_test(player.get_node("AutoWeapon") as AutoWeapon)
	console.set_interaction_radius_for_test(FakeInteractionRadius.new())
	console.set_upgrade_system_for_test(upgrade_system)
	console.set_run_inventory(inventory)
	add_child(console)
	return console


func test_console_open_and_purchase_never_pauses_the_tree_and_enemies_keep_moving() -> void:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(tower)
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	add_child(player)
	player.global_position = Vector2(50, 0) # well inside the 160 px Interaction Radius
	player.velocity = Vector2.ZERO

	var upgrade_system: UpgradeSystem = auto_free(UpgradeSystemScript.new()) as UpgradeSystem
	add_child(upgrade_system)

	var inventory: RunInventory = RunInventoryScript.new()
	inventory.scrap_current = 100

	var console: Console = _build_console(tower, player, upgrade_system, inventory)

	var enemy: EnemyStandIn = auto_free(EnemyStandIn.new()) as EnemyStandIn
	add_child(enemy)

	await get_tree().physics_frame # warm-up: settle newly added nodes into the per-frame processing list

	var now_before: float = _clock.now
	var enemy_ticks_before: int = enemy.ticks

	# CHANGE 1 (D107, 2026-09-23): the default control scheme opens via
	# console_open (request_open()), not the old dwell -- see
	# src/ui/console.gd's own class doc, "CHANGE 1." No dwell means no need
	# to wait any frames before it succeeds.
	assert_bool(console.request_open()).append_failure_message("Console did not open via request_open() under the scripted stand-still-inside-radius conditions").is_true()
	var channel_started: bool = console.select_and_start_channel(1) # Rapid Fire (catalogue index 1)
	assert_bool(channel_started).append_failure_message("Failed to start the Rapid Fire purchase channel").is_true()

	# 1.0 s of real engine ticks: comfortably covers the 0.5 s purchase channel with margin.
	for i in range(60):
		await get_tree().physics_frame

	assert_bool(console.is_open()).append_failure_message("Console closed unexpectedly during the purchase channel").is_true()

	assert_bool(get_tree().paused).append_failure_message("The Console must never add a pause reason; the tree paused while it was open/purchasing").is_false()
	assert_int(_pause.get_active_reasons().size()).append_failure_message("PauseAuthority recorded a pause reason while the Console was open/purchasing: %s" % [_pause.get_active_reasons()]).is_equal(0)
	assert_float(_clock.now).append_failure_message("SimClock.now did not advance while the Console was open").is_greater(now_before)
	assert_int(enemy.ticks).append_failure_message("An independent PROCESS_MODE_PAUSABLE entity stopped ticking -- the tree must have paused").is_greater(enemy_ticks_before)

	# The scripted purchase actually completed on SimClock timing while the
	# tree stayed unpaused throughout -- not just that nothing crashed.
	assert_int(upgrade_system.get_current_rank("rapid_fire")).append_failure_message("The 0.5 s purchase channel did not complete while unpaused").is_equal(1)
	assert_int(inventory.scrap_current).append_failure_message("Scrap was not charged exactly once for the completed purchase").is_equal(100 - RAPID_FIRE_RANK_1_COST)
