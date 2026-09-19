extends GdUnitTestSuite

## HudEconomyState -> HUD display wiring (P2.6). docs/19_UI_UX.md > "HUD":
## Scrap "n/200" with a FULL badge at the cap and the hopper amount when
## non-empty; a bottom XP bar with level and rerolls remaining.
## MASTER_SDLC.md > Provisional Values Register > Economy & Pickups >
## "Scrap": "Cap 200."
##
## `HudEconomyState` (src/ui/hud_economy_state.gd) is the read interface
## this task owns for the fields Economy (Phase 05) and the Wave Director
## (Phase 04) do not exist yet to drive -- see that file's header and the
## P2.6 evidence report's "Cross-task seams". These tests drive it directly,
## exactly as a future real system would.

func _build_hud() -> Hud:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	return hud


func test_scrap_label_shows_current_over_cap() -> void:
	var hud: Hud = _build_hud()
	hud.economy_state.scrap_current = 42
	hud.economy_state.scrap_cap = 200
	hud._refresh_scrap()

	assert_str(hud.get_scrap_label().text).is_equal("42/200")


func test_full_badge_hidden_below_cap_and_shown_at_cap() -> void:
	var hud: Hud = _build_hud()
	hud.economy_state.scrap_current = 150
	hud.economy_state.scrap_cap = 200
	hud._refresh_scrap()
	assert_bool(hud.get_full_badge_label().visible).is_false()

	hud.economy_state.scrap_current = 200
	hud._refresh_scrap()
	assert_bool(hud.get_full_badge_label().visible).append_failure_message("FULL badge did not appear at the Scrap cap").is_true()


func test_hopper_label_hidden_when_empty_and_shown_when_non_empty() -> void:
	var hud: Hud = _build_hud()
	hud.economy_state.hopper_amount = 0
	hud._refresh_scrap()
	assert_bool(hud.get_hopper_label().visible).is_false()

	hud.economy_state.hopper_amount = 17
	hud._refresh_scrap()
	assert_bool(hud.get_hopper_label().visible).append_failure_message("hopper amount did not appear once the hopper was non-empty").is_true()
	assert_str(hud.get_hopper_label().text).contains("17")


func test_xp_bar_and_level_and_rerolls_labels() -> void:
	var hud: Hud = _build_hud()
	hud.economy_state.xp_current = 30.0
	hud.economy_state.xp_required_for_next_level = 100.0
	hud.economy_state.level = 4
	hud.economy_state.rerolls_remaining = 1
	hud._refresh_xp()

	var bar: HudBar = hud.get_xp_bar()
	assert_float(bar.get_fraction()).is_equal_approx(0.3, 0.001)
	assert_str(hud.get_level_label().text).contains("4")
	assert_str(hud.get_rerolls_label().text).contains("1")


func test_scrap_truncation_full_value_is_recoverable_via_tooltip() -> void:
	var hud: Hud = _build_hud()
	hud.economy_state.scrap_current = 7
	hud.economy_state.scrap_cap = 200
	hud._refresh_scrap()

	var label: HudTruncatableLabel = hud.get_scrap_label()
	assert_str(label.tooltip_text).is_equal("7/200")
	assert_int(label.text_overrun_behavior).is_equal(TextServer.OVERRUN_TRIM_ELLIPSIS)
