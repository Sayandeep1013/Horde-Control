extends GdUnitTestSuite

## Rendered-property regression test (UI pass round 2, BRIEF_R2.md package A
## item 4). Every existing HUD layout test (hud_layout_test.gd,
## hud_layout_check_test.gd, hud_economy_display_test.gd,
## tower_cue_audibility_test.gd) measures FIELD rects (generous,
## viewport-relative bounds), label TEXT content, or overrun/autowrap MODE
## flags -- never a Control's own rendered pixel `size` or a Label's own
## `get_line_count()`. Round 1 shipped a HUD where every new glyph/caption
## label rendered one character per line and the health bars stretched to
## roughly 235x160 / 310x125 instead of staying slim (see
## package_reports/A_hud.md's "Follow-up" section), and every one of the 73
## tests in the 8 suites that reference Hud/HudBar/HudTruncatableLabel/
## ThreatFeedback stayed green throughout, because none of them read either
## of those two properties. This suite closes that specific gap: it asserts
## the actual rendered properties the round-1 defect broke, in a real
## SceneTree at the project's pinned 1920x1080 viewport.
##
## Falsified before being relied on, not just written and trusted (see
## package_reports/A_hud.md, "## Round 2"): with `_new_hud_label()`'s
## `custom_minimum_size` line in src/ui/hud.gd temporarily changed to
## `Vector2(0, 0)` (a one-line local edit, reverted immediately after and
## never committed), `test_every_hud_label_renders_on_a_single_line` failed
## on every fixed-text label ("HP", "TOWER", "SCRAP", "XP", "Wave", "Level",
## "Rerolls") with `get_line_count()` returning 5 or more -- reproducing the
## exact round-1 character-wrap defect this test exists to catch. Restoring
## the real minimum widths made it pass again.

const HudScene: PackedScene = preload("res://scenes/ui/hud.tscn")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

## "Sane" is defined against this project's own evidence, not an arbitrary
## number: pills currently measure 64px tall at 1920x1080 (measured,
## package_reports/A_hud.md round 1 "Follow-up" table, against the
## coordinator's own stated 40-70px target range). 100px leaves real
## headroom above that measurement for future tuning while still failing
## outright on the round-1 defect class (a starved label falling back to
## character-wrapping, which inflated a pill's height to roughly 125-235px).
## Not a Provisional Values Register number -- the Register has no HUD pill
## height row; "pill" itself is a UI-pass addition, not a pre-existing
## Register concept. This bound is local to this test.
const MAX_SANE_PILL_HEIGHT_PX: float = 100.0

var _hud: Hud
var _viewport_size_saved: Vector2i


func before_test() -> void:
	_viewport_size_saved = get_tree().root.size
	get_tree().root.size = VIEWPORT_SIZE
	_hud = auto_free(HudScene.instantiate()) as Hud
	add_child(_hud)
	# Drive every optional/conditional label into its populated state (the
	# FULL badge and the hopper amount are hidden by default) so this test
	# checks real rendered content, not an unset default.
	_hud.economy_state.wave_current = 8
	_hud.economy_state.wave_total = 8
	_hud.economy_state.level = 12
	_hud.economy_state.rerolls_remaining = 1
	_hud.economy_state.scrap_current = 200
	_hud.economy_state.scrap_cap = 200
	_hud.economy_state.hopper_amount = 17
	_hud.economy_state.xp_current = 40.0
	_hud.economy_state.xp_required_for_next_level = 100.0
	_hud._refresh_all() # same private-by-convention method this project's own HUD tests already call directly (hud_layout_test.gd, hud_economy_display_test.gd)
	await get_tree().process_frame
	await get_tree().process_frame # Container layout needs at least one full pass; a second is cheap insurance, matching hud_layout_check_test.gd's own documented timing hazard


func after_test() -> void:
	get_tree().root.size = _viewport_size_saved


func _find(node_name: String) -> Node:
	return _hud.find_child(node_name, true, false) # owned=false: this tree is built entirely at runtime via add_child(), so none of it has a scene-file owner


func test_every_hud_label_renders_on_a_single_line() -> void:
	var label_names: Array = [
		"PlayerHealthGlyph", "TowerHealthGlyph", "ScrapGlyph", "XpGlyph",
		"WaveCaptionLabel", "WaveLabel",
		"LevelCaptionLabel", "LevelLabel",
		"RerollsCaptionLabel", "RerollsLabel",
		"ScrapValueLabel", "FullBadgeLabel", "HopperLabel",
	]
	for label_name in label_names:
		var label: Label = _find(label_name) as Label
		assert_object(label).append_failure_message("%s was not found in the built HUD tree" % label_name).is_not_null()
		var line_count: int = label.get_line_count()
		assert_int(line_count).append_failure_message("%s rendered on %d line(s) instead of 1 (text %s) -- the round-1 character-per-line wrap defect" % [label_name, line_count, label.text]).is_equal(1)


func test_every_pill_stays_under_a_sane_height() -> void:
	var pill_names: Array = ["PlayerHealthPill", "TowerHealthPill", "ScrapPill", "XpPill"]
	for pill_name in pill_names:
		var pill: Control = _find(pill_name) as Control
		assert_object(pill).append_failure_message("%s was not found in the built HUD tree" % pill_name).is_not_null()
		var height: float = pill.get_global_rect().size.y
		assert_float(height).append_failure_message("%s rendered %.1fpx tall -- exceeds the %.1fpx sane bound (round-1 measured 64px for a correctly-sized pill; the defect this test exists to catch reached roughly 125-235px)" % [pill_name, height, MAX_SANE_PILL_HEIGHT_PX]).is_less_equal(MAX_SANE_PILL_HEIGHT_PX)
