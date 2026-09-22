extends GdUnitTestSuite

## Interaction window test, scripted half (named acceptance test, P2.13).
## MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests: "opening
## the Console during an encounter with enemies alive results in measurable
## player damage, and the Console never closes on damage taken." The
## tester-observed half runs later at P2.16; this scripted half asserts the
## Console's own contribution to the core tension mechanically: it does not
## intercept, block, or react to player damage in any way, and it does not
## add itself as a safe corner (MASTER_SDLC.md > Explicit Anti-Patterns >
## "The safe corner"; > Tower Interaction Mechanics > "No Safe Corners": "If
## the player takes damage while the Console is open, the Console does not
## close, but the player must manage their health.").
##
## Damage is applied directly via Player.apply_damage() as the scripted
## stand-in for "an enemy hit landed" -- this isolates the CONSOLE's own
## behaviour (must not close, must not block the damage) from the enemy
## AI/combat resolution pipeline itself (P2.5's own scope, already covered
## by that phase's own tests). A live-enemy-driven version of this same
## claim is the tester-observed half at P2.16.

const ConsoleScript: GDScript = preload("res://src/ui/console.gd")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")

class FakeInteractionRadius:
	var inside: bool = true
	func is_player_inside() -> bool:
		return inside


var _clock: Node
var _pause: Node


func before_test() -> void:
	# Node (not RefCounted): must be auto_free()'d even though it is
	# deliberately never added to a tree (see console_rules_test.gd's own
	# note on this exact leak).
	_clock = auto_free(SimClockScript.new()) as Node
	_pause = auto_free(PauseAuthorityScript.new()) as Node
	add_child(_pause)


func after_test() -> void:
	get_tree().paused = false


func _advance(console: Console, seconds: float, ticks: int = 4) -> void:
	var step: float = seconds / float(ticks)
	for i in range(ticks):
		_clock.now += step
		console.physics_step(step)


func test_opening_the_console_while_taking_damage_results_in_measurable_damage_and_never_closes() -> void:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(tower)
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	add_child(player)
	player.global_position = Vector2(50, 0)
	player.velocity = Vector2.ZERO

	var system: UpgradeSystem = auto_free(UpgradeSystemScript.new()) as UpgradeSystem
	add_child(system)

	var inventory: RunInventory = RunInventoryScript.new()
	inventory.scrap_current = 100

	var console: Console = auto_free(ConsoleScript.new()) as Console
	console.driven_externally = true
	console.set_sim_clock_for_test(_clock)
	console.set_pause_authority_for_test(_pause)
	console.set_tower_for_test(tower)
	console.set_player_for_test(player)
	console.set_interaction_radius_for_test(FakeInteractionRadius.new())
	console.set_upgrade_system_for_test(system)
	console.set_run_inventory(inventory)
	add_child(console)

	# CHANGE 1 (D107, 2026-09-23): the default control scheme opens via
	# console_open (request_open()), not the old dwell -- see
	# src/ui/console.gd's own class doc, "CHANGE 1."
	assert_bool(console.request_open()).append_failure_message("Console did not open under the scripted stand-still conditions -- cannot exercise the interaction window").is_true()

	var health_before: float = player.death_state.current_hp

	# The scripted stand-in for "an enemy hit landed while the Console is
	# open" -- an encounter attacking the player, independent of the
	# Console's own systems.
	player.apply_damage(20.0, "test_enemy")

	assert_float(player.death_state.current_hp).append_failure_message("Opening the Console during an encounter did not result in measurable player damage").is_less(health_before)
	assert_float(health_before - player.death_state.current_hp).is_equal_approx(20.0, 0.01)

	assert_bool(console.is_open()).append_failure_message("The Console must NEVER close on damage taken (MASTER_SDLC.md > Tower Interaction Mechanics > 'No Safe Corners')").is_true()

	# It must keep working normally afterwards too -- damage does not even
	# interrupt an in-progress purchase.
	assert_bool(console.select_and_start_channel(1)).append_failure_message("Console stopped accepting purchases after the player took damage").is_true()
	player.apply_damage(10.0, "test_enemy")
	assert_bool(console.is_open()).is_true()
	assert_bool(console.is_channel_active()).append_failure_message("A second hit while a channel was in progress must not cancel it -- only excess speed or leaving the radius may").is_true()

	_advance(console, Console.CHANNEL_DURATION_SECONDS + 0.05)
	assert_bool(console.is_open()).append_failure_message("Console closed at some point during the interaction window despite never leaving the radius, cancelling, or dying").is_true()
	assert_int(system.get_current_rank("rapid_fire")).append_failure_message("The purchase did not complete despite the player taking damage during its channel").is_equal(1)
