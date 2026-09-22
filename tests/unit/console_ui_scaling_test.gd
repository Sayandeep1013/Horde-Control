extends GdUnitTestSuite

## UI scaling test (named acceptance test, P2.13). MASTER_SDLC.md >
## Acceptance Test Matrix > Readability Tests: Console entries do not break
## or truncate when the pseudo-localization toggle adds 30% length. docs/19
## names Godot's built-in pseudolocalization with expansion ratio 0.3; the
## F2 action exists (debug_pseudoloc_toggle). docs/19 > "UI Layout & Dynamic
## Container Rules": "Tower Console entry rows" are named explicitly as
## containers that must use Label/RichTextLabel with autowrap_mode =
## AUTOWRAP_WORD_SMART and size_flags_horizontal = SIZE_EXPAND_FILL, and
## "Truncation Fallback ... Silent truncation is banned."
##
## Mirrors tests/unit/tower_cue_audibility_test.gd's own established
## pseudo-localization idiom exactly (toggle via ProjectSettings +
## TranslationServer, reload, await two process frames), applied to the
## Console's world-space Panel instead of the HUD's CanvasLayer fields.
##
## The Console is added to the real tree and left self-driven (NOT
## `driven_externally`) here, deliberately, so its own `_process()` refresh
## and real Container layout both run through the ENGINE's normal per-frame
## path -- this is the one test in this task's suite that wants real layout
## timing rather than a manually-advanced clock.

const ConsoleScript: GDScript = preload("res://src/ui/console.gd")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")


class FakeInteractionRadius:
	var inside: bool = true
	func is_player_inside() -> bool:
		return inside


func _build_console() -> Dictionary:
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
	console.set_tower_for_test(tower)
	console.set_player_for_test(player)
	console.set_player_weapon_for_test(player.get_node("AutoWeapon") as AutoWeapon)
	console.set_interaction_radius_for_test(FakeInteractionRadius.new())
	console.set_upgrade_system_for_test(system)
	console.set_run_inventory(inventory)
	add_child(console)

	return {"console": console, "tower": tower, "player": player, "system": system, "inventory": inventory}


func after_test() -> void:
	# Never leave pseudo-localization on for a later suite in the same run.
	if TranslationServer.is_pseudolocalization_enabled():
		TranslationServer.set_pseudolocalization_enabled(false)
		TranslationServer.reload_pseudolocalization()


func test_console_entries_survive_pseudolocalizations_30_percent_expansion_without_truncating() -> void:
	var built: Dictionary = _build_console()
	var console: Console = built["console"]

	# CHANGE 1 (D107, 2026-09-23): the default control scheme opens via
	# console_open (request_open()), not the old dwell -- see
	# src/ui/console.gd's own class doc, "CHANGE 1." This test's own claim
	# is about layout survival, not lifecycle timing, so opening it directly
	# is fine here; real SimClock/PauseAuthority autoloads are still used so
	# the subsequent `_process()` refresh runs through the engine's normal
	# per-frame path.
	assert_bool(console.request_open()).append_failure_message("Console did not open via request_open() under the scripted stand-still conditions -- cannot exercise its UI").is_true()

	await get_tree().process_frame
	await get_tree().process_frame

	var count_before: int = console.get_catalogue_size_for_test()
	assert_int(count_before).is_greater(0)

	var texts_before: Array = []
	for i in range(count_before):
		var label: Label = console.get_entry_label_for_test(i)
		assert_object(label).append_failure_message("Entry %d's row Label was not built" % i).is_not_null()
		# The structural guarantee against silent truncation (docs/19 > UI
		# Layout & Dynamic Container Rules): every Console entry row must
		# wrap and grow, never trim.
		assert_int(label.autowrap_mode).append_failure_message("Entry %d must be able to wrap; AUTOWRAP_OFF would silently clip pseudo-localized text" % i).is_not_equal(TextServer.AUTOWRAP_OFF)
		assert_int(label.text_overrun_behavior).append_failure_message("Entry %d is configured to trim/truncate instead of growing" % i).is_equal(TextServer.OVERRUN_NO_TRIMMING)
		assert_int(label.get_theme_font_size("font_size")).append_failure_message("Entry %d's font size drifted from the Register's 24 px floor" % i).is_equal(Console.ENTRY_FONT_SIZE_PX)
		texts_before.append(label.text)

	var panel_before: Vector2 = console.get_panel_control_for_test().size

	var was_enabled: bool = TranslationServer.is_pseudolocalization_enabled()
	ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", 0.3)
	TranslationServer.set_pseudolocalization_enabled(true)
	TranslationServer.reload_pseudolocalization()

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var count_after: int = console.get_catalogue_size_for_test()
	assert_int(count_after).append_failure_message("The catalogue's own entry count must not change under pseudo-localization").is_equal(count_before)

	var any_grew: bool = false
	for i in range(count_after):
		var label: Label = console.get_entry_label_for_test(i)
		# Re-assert the SAME structural guarantee still holds post-toggle --
		# not just that it held before the text got longer.
		assert_int(label.autowrap_mode).append_failure_message("Entry %d lost its autowrap under pseudo-localization" % i).is_not_equal(TextServer.AUTOWRAP_OFF)
		assert_int(label.text_overrun_behavior).append_failure_message("Entry %d started trimming under pseudo-localization" % i).is_equal(TextServer.OVERRUN_NO_TRIMMING)
		assert_int(label.get_theme_font_size("font_size")).append_failure_message("Entry %d's font size changed under pseudo-localization -- text must grow by wrapping, never by shrinking the 24 px floor" % i).is_equal(Console.ENTRY_FONT_SIZE_PX)
		if label.text.length() > String(texts_before[i]).length():
			any_grew = true
	assert_bool(any_grew).append_failure_message("Pseudo-localization's 30% expansion did not lengthen any entry's text -- the toggle is not reaching the Console's labels").is_true()

	var panel_after: Vector2 = console.get_panel_control_for_test().size
	assert_float(panel_after.y).append_failure_message("The panel's height shrank under pseudo-localization's longer text (%s -> %s) -- content is being clipped, not grown" % [panel_before, panel_after]).is_greater_equal(panel_before.y - 0.5)

	TranslationServer.set_pseudolocalization_enabled(was_enabled)
	TranslationServer.reload_pseudolocalization()
