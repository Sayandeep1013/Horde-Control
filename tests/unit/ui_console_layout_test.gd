extends GdUnitTestSuite

## Console layout regression test (UI pass, package C). Guards against the
## exact defect a windowed capture of the assembled scene caught mid-pass
## (phases/UI_PASS/screenshots/before_1920/05_console.png): the panel
## collapsing to a near-zero-width sliver and wrapping every entry one
## character per line down its full height, because `Text`'s
## `SIZE_EXPAND_FILL` + `AUTOWRAP_WORD_SMART` label had no minimum width of
## its own (see src/ui/console.gd's own header, "Layout-collapse fix").
##
## Uses the REAL UpgradeSystem (its own default-preloaded definitions --
## console_rules_test.gd's own `_build_upgrade_system()` precedent, no
## `set_upgrade_definitions_for_test()` call), so the catalogue is the true
## 7 fixed entries with their real, data-sourced `effect_description`
## strings (data/upgrades/*.tres) -- the longest of which (Shield Matrix,
## the two fallback cards) are what actually drive row height, not a
## shortened test stand-in.
##
## Drives real engine frames (REAL SimClock/PauseAuthority autoloads,
## exactly like tests/unit/console_ui_scaling_test.gd's own established
## idiom) rather than a manually-advanced clock, because this test's claim
## is about REAL Container layout resolving to a sane size, not about
## lifecycle timing.

const ConsoleScript: GDScript = preload("res://src/ui/console.gd")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")

## Generous ceilings, not tuned to the exact px this session measured --
## they exist to catch the COLLAPSE PATHOLOGY (one character per line,
## panel height in the thousands of px) coming back, not to pin an exact
## pixel design. docs/19 > "UI Layout & Dynamic Container Rules" > "Max
## Dimensions": "Provisional Default 30% of screen height" is 324 px at
## 1080 -- this ceiling (900 px) is deliberately looser than 324 so it
## targets "not collapsed", never "meets the provisional 30% figure".
const PANEL_HEIGHT_SANITY_CEILING_PX: float = 900.0
const PANEL_WIDTH_MIN_PX: float = 300.0
const PANEL_WIDTH_MAX_PX: float = 900.0

## UI pass follow-up (compaction, item 4/5): the orchestrator's own target,
## "panel about 460-520 px wide and no more than about 360 px tall". The
## follow-up evidence report names precisely what still holds the height up:
## 7 one-line rows at the Register's mandatory 24 px floor, plus the
## explicitly-requested 2-line footer reservation, already at the smallest
## UiPalette spacing tokens (SPACE_XS/SPACE_S). This bound catches the
## compaction regressing back toward the pre-follow-up ~770-800 px, not a
## razor's-edge pin to 360.
##
## UI PASS ROUND 2 (UR-11, UR-05, UR-03): "keep a tight regression bound at
## the measured size (as now)" -- re-measured after this round's own
## changes (528x377, up from the follow-up's 512x377; the +16 px width is
## the Glyph column's set_side(24) growing from its old 16 px minimum, plus
## PriceTag's min-width floor growing 40 -> 48 alongside its font-size raise
## -- height is UNCHANGED because Text, at the same 24 px floor, was already
## the row's tallest content). Bound tightened to this measurement plus a
## small margin, not left at the stale pre-round-2 420/560 figures (which
## would no longer be "at the measured size"). The SEPARATE docs/19 30% cap
## assertion below is the one that is meant to fail; this one is not.
const PANEL_HEIGHT_COMPACT_TARGET_PX: float = 400.0
const PANEL_WIDTH_COMPACT_MAX_PX: float = 550.0


class FakeInteractionRadius:
	var inside: bool = true
	func is_player_inside() -> bool:
		return inside


func after_test() -> void:
	if TranslationServer.is_pseudolocalization_enabled():
		TranslationServer.set_pseudolocalization_enabled(false)
		TranslationServer.reload_pseudolocalization()


func _build_console() -> Console:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(tower)
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	add_child(player)
	player.global_position = Vector2(50, 0)
	player.velocity = Vector2.ZERO

	var system: UpgradeSystem = auto_free(UpgradeSystemScript.new()) as UpgradeSystem
	add_child(system) # real, default-preloaded definitions -- the true 7-entry catalogue

	var inventory: RunInventory = RunInventoryScript.new()
	inventory.scrap_current = 500

	var console: Console = auto_free(ConsoleScript.new()) as Console
	console.set_tower_for_test(tower)
	console.set_player_for_test(player)
	console.set_player_weapon_for_test(player.get_node("AutoWeapon") as AutoWeapon)
	console.set_interaction_radius_for_test(FakeInteractionRadius.new())
	console.set_upgrade_system_for_test(system)
	console.set_run_inventory(inventory)
	add_child(console)
	return console


func test_panel_with_the_real_seven_entry_catalogue_does_not_collapse_or_explode() -> void:
	var console: Console = _build_console()

	# CHANGE 1 (D107, 2026-09-23): the default control scheme opens via
	# console_open (request_open()), not the old dwell -- see
	# src/ui/console.gd's own class doc, "CHANGE 1."
	assert_bool(console.request_open()).append_failure_message("Console did not open via request_open() under the scripted stand-still conditions -- cannot measure its layout").is_true()

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(console.get_catalogue_size_for_test()).append_failure_message("test setup: expected the real, fresh UpgradeSystem's fixed 7-entry catalogue (Repair + 6 upgrades, no fallback yet)").is_equal(7)

	var panel_size: Vector2 = console.get_panel_control_for_test().size
	print("[ui_console_layout_test] panel size, 7 real entries, base resolution (view_scale 1.0): ", panel_size)

	assert_float(panel_size.x).append_failure_message("Panel width %.1f px is narrower than the collapse-pathology floor this test guards against" % panel_size.x).is_greater_equal(PANEL_WIDTH_MIN_PX)
	assert_float(panel_size.x).append_failure_message("Panel width %.1f px is wider than expected for a compact side panel" % panel_size.x).is_less_equal(PANEL_WIDTH_MAX_PX)
	assert_float(panel_size.y).append_failure_message("Panel height %.1f px looks like the collapse pathology (every entry wrapped one character per line) -- see console.gd's header, 'Layout-collapse fix'" % panel_size.y).is_less_equal(PANEL_HEIGHT_SANITY_CEILING_PX)

	# UI pass follow-up (item 4/5): the compaction target itself, not just
	# "did not collapse".
	assert_float(panel_size.x).append_failure_message("Panel width %.1f px exceeds the follow-up's compaction target (%.0f px)" % [panel_size.x, PANEL_WIDTH_COMPACT_MAX_PX]).is_less_equal(PANEL_WIDTH_COMPACT_MAX_PX)
	assert_float(panel_size.y).append_failure_message("Panel height %.1f px exceeds the follow-up's compaction target (%.0f px) -- see this file's own const comment for what the evidence report names as still holding it up" % [panel_size.y, PANEL_HEIGHT_COMPACT_TARGET_PX]).is_less_equal(PANEL_HEIGHT_COMPACT_TARGET_PX)

	# No entry may wrap into anywhere near one line per character -- the
	# literal symptom the coordinator's screenshot showed (a whole column
	# reading "C,O,N,S,O,L,E" one glyph per line). A stable, version-proof
	# proxy: even an absurdly narrow 6 px/character would not need more
	# lines than (text length / 6); the collapse pathology needs roughly
	# (text length) lines (one per character), which is far above that.
	#
	# UI pass follow-up (item 1/5): in English, at base resolution, every
	# row label must be exactly ONE line -- the whole point of moving the
	# price and the effect sentence out of it. Checked as its own hard
	# assertion, not just bounded by the character-count proxy above.
	for i in range(console.get_catalogue_size_for_test()):
		var label: Label = console.get_entry_label_for_test(i)
		var line_count: int = label.get_line_count()
		var text_len: int = label.text.length()
		assert_int(line_count).append_failure_message("Entry %d ('%s') wrapped into %d lines in English at base resolution -- the follow-up's row label must be one line" % [i, label.text, line_count]).is_equal(1)
		if text_len <= 0:
			continue
		var min_reasonable_lines: int = maxi(1, int(ceil(float(text_len) / 6.0)))
		assert_int(line_count).append_failure_message("Entry %d wrapped into %d lines for %d characters of text ('%s') -- consistent with the one-character-per-line collapse" % [i, line_count, text_len, label.text]).is_less_equal(min_reasonable_lines)

	# UI pass round 2 (UR-03): the row glyph is a drawn SHAPE, never text --
	# Shape.TRIANGLE for a Player-pool entry (matching the Draft's own player
	# glyph, draft_card_view.gd's GLYPH_PLAYER = "▲", a triangle, not a
	# circle), Shape.SQUARE for a Tower-pool entry, `text` always empty.
	for i in range(console.get_catalogue_size_for_test()):
		var e: Dictionary = console.get_entry_for_test(i)
		var glyph: UiShapeGlyph = console.get_entry_glyph_for_test(i)
		assert_object(glyph).append_failure_message("Entry %d has no UiShapeGlyph glyph node" % i).is_not_null()
		var is_tower: bool = int(e.get("pool", 0)) == ContractEnums.PoolOwnership.Tower
		var expected_shape: int = UiShapeGlyph.Shape.SQUARE if is_tower else UiShapeGlyph.Shape.TRIANGLE
		assert_int(int(glyph.shape)).append_failure_message("Entry %d ('%s') glyph shape is %d, expected %d (%s)" % [i, e.get("name", ""), glyph.shape, expected_shape, "SQUARE" if is_tower else "TRIANGLE"]).is_equal(expected_shape)
		assert_str(glyph.text).append_failure_message("Entry %d glyph Label.text must stay empty -- UiShapeGlyph draws the shape, never text" % i).is_equal("")

	# UI pass round 2 (UR-05). Author decision 2026-09-20 (UI pass LEDGER
	# UR-25) confirms the 24 px floor covers the price and MAX badge, not
	# just the row label: PriceTag and MaxBadgeLabel must render at
	# ENTRY_FONT_SIZE_PX (24 px), the SAME floor `Text` uses, not the
	# theme's smaller defaults (20 px body / 16 px SMALL) they used before
	# this fix.
	for i in range(console.get_catalogue_size_for_test()):
		var price_tag: RichTextLabel = console.get_entry_price_tag_for_test(i)
		assert_object(price_tag).append_failure_message("Entry %d has no PriceTag node" % i).is_not_null()
		var price_font_size: int = price_tag.get_theme_font_size("normal_font_size")
		assert_int(price_font_size).append_failure_message("Entry %d PriceTag font size is %d px, expected the Register's %d px floor (ENTRY_FONT_SIZE_PX)" % [i, price_font_size, Console.ENTRY_FONT_SIZE_PX]).is_equal(Console.ENTRY_FONT_SIZE_PX)
		var max_label: Label = console.get_entry_max_badge_label_for_test(i)
		assert_object(max_label).append_failure_message("Entry %d has no MaxBadgeLabel node" % i).is_not_null()
		var max_font_size: int = max_label.get_theme_font_size("font_size")
		assert_int(max_font_size).append_failure_message("Entry %d MaxBadgeLabel font size is %d px, expected the Register's %d px floor (ENTRY_FONT_SIZE_PX)" % [i, max_font_size, Console.ENTRY_FONT_SIZE_PX]).is_equal(Console.ENTRY_FONT_SIZE_PX)

	# UI pass follow-up (item 2): the footer shows the HIGHLIGHTED entry's
	# effect sentence.
	# UI PASS ROUND 2 (UR-10): index 0 (Repair) opens highlighted by default
	# (_open_console() resets _highlighted_index to 0). Repair's own "name"
	# has no ':' to split on, so it used to leave the footer EMPTY -- the
	# defect this item fixes -- and is now a real sentence built from the
	# SAME heal/cost values the row and PriceTag already show
	# (REPAIR_FOOTER_FALLBACK_FMT). Cycling to a ranked upgrade must still
	# show its own non-empty effect sentence, unchanged from round 1.
	var footer: Label = console.get_footer_label_for_test()
	assert_object(footer).append_failure_message("Console has no Footer label built").is_not_null()
	assert_str(footer.text).append_failure_message("Footer must be non-empty while Repair is highlighted (UR-10 -- the empty-footer defect) -- got '%s'" % footer.text).is_not_equal("")
	assert_str(footer.text).append_failure_message("Repair's footer must mention HP, got '%s'" % footer.text).contains("HP")
	assert_str(footer.text).append_failure_message("Repair's footer must mention Scrap, got '%s'" % footer.text).contains("Scrap")
	console.set_highlighted_index_for_test(1) # Rapid Fire
	console.force_refresh_for_test()
	assert_str(footer.text).append_failure_message("Footer did not show Rapid Fire's effect sentence once highlighted").contains("fire rate")
	assert_bool(footer.text.begins_with("Rapid Fire")).append_failure_message("Footer must show the sentence AFTER the first ':', not the name itself -- got '%s'" % footer.text).is_false()


func test_panel_grows_taller_not_narrower_under_pseudolocalizations_30_percent_expansion() -> void:
	var console: Console = _build_console()

	# CHANGE 1 (D107, 2026-09-23): opens via console_open (request_open()),
	# not the old dwell -- see src/ui/console.gd's own class doc, "CHANGE 1."
	assert_bool(console.request_open()).is_true()
	await get_tree().process_frame
	await get_tree().process_frame

	var size_before: Vector2 = console.get_panel_control_for_test().size

	ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", 0.3)
	TranslationServer.set_pseudolocalization_enabled(true)
	TranslationServer.reload_pseudolocalization()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var size_after: Vector2 = console.get_panel_control_for_test().size
	print("[ui_console_layout_test] panel size, 7 real entries, pseudo-localized (+30%%): ", size_after, " (was ", size_before, ")")

	# Width should NOT stay pixel-identical: Header/Glyph/Title/ScrapValue
	# are deliberately non-wrapping single-word labels (wrapping "PLAYER"
	# mid-word would look worse than a few extra px of width), so their
	# longer pseudo-localized single token legitimately needs a little more
	# room -- that is docs/19's "expand ... to fit text" working as
	# intended, not a bug. What WOULD be a bug (and is exactly what this
	# test caught mid-pass, before the PriceTag auto-translate fix below):
	# the width nearly DOUBLING because a decoration's markup got mangled
	# into one unbreakable literal line. Bounded, not exact, growth.
	assert_float(size_after.x).append_failure_message("Panel width shrank under pseudo-localization (%.1f -> %.1f) -- content is being clipped" % [size_before.x, size_after.x]).is_greater_equal(size_before.x - 0.5)
	assert_float(size_after.x).append_failure_message("Panel width grew from %.1f to %.1f (%.0f%%) under pseudo-localization -- looks like the markup-mangling collapse this test caught mid-pass (PriceTag's BBCode being auto-translated/pseudo-localized; see console.gd's PriceTag `auto_translate_mode`)" % [size_before.x, size_after.x, 100.0 * (size_after.x / size_before.x - 1.0)]).is_less_equal(size_before.x * 1.4)
	assert_float(size_after.y).append_failure_message("Panel height shrank under pseudo-localization's longer text -- content is being clipped, not grown").is_greater_equal(size_before.y - 0.5)
	assert_float(size_after.y).append_failure_message("Pseudo-localized panel height %.1f px looks like the collapse pathology" % size_after.y).is_less_equal(PANEL_HEIGHT_SANITY_CEILING_PX * 1.5)


## UI pass round 2 (UR-03). BRIEF_R2 item 3: "Check with Font.has_char()
## against the shipped font (UiPalette.FONT_PATH) before you put
## any non-ASCII character on screen, and quote the result." Checked
## directly here (not assumed from shape_glyph.gd's or outcome_glyph.gd's
## own header comments) against the exact two codepoints the old
## CONSOLE_GLYPH_PLAYER ("●") / CONSOLE_GLYPH_TOWER ("■") keys
## held -- see the report, "UR-03", for the quoted result.
func test_shipped_font_lacks_the_old_console_glyph_characters() -> void:
	var font: Font = load(UiPalette.FONT_PATH) as Font
	assert_object(font).append_failure_message("Font resource failed to load -- cannot check Font.has_char()").is_not_null()
	if font == null:
		return
	var has_circle: bool = font.has_char(0x25CF) # U+25CF, the old CONSOLE_GLYPH_PLAYER character "●"
	var has_square: bool = font.has_char(0x25A0) # U+25A0, the old CONSOLE_GLYPH_TOWER character "■"
	print("[ui_console_layout_test] Font.has_char(U+25CF) = %s ; Font.has_char(U+25A0) = %s (%s)" % [has_circle, has_square, UiPalette.FONT_PATH])
	# Not a design requirement of the font -- a recorded fact backing why
	# UiShapeGlyph (a drawn shape, never these text characters) is correct.
	assert_bool(has_circle).append_failure_message("Font.has_char(U+25CF) is unexpectedly true -- the font DOES contain the old glyph character after all; recorded here because it changes UR-03's own justification, not because a shape glyph would stop being correct").is_false()
	assert_bool(has_square).append_failure_message("Font.has_char(U+25A0) is unexpectedly true -- the font DOES contain the old glyph character after all; see the comment above").is_false()


## UI pass round 2 (UR-11). This started as docs/19 > "UI Layout & Dynamic
## Container Rules" > "Max Dimensions": "Provisional Default 30% of screen
## height" (324 px at 1080p), deliberately left FAILING as a named, honest
## gap rather than loosened or skipped.
##
## RESOLVED by Author decision 2026-09-20 (UI pass LEDGER UR-25): the
## Console gets its OWN height allowance of ~35% of screen height (378 px
## at 1080p) instead of docs/19's general 30% -- docs/19 itself is to be
## updated by its owner through HANDOFF H-05, not by this package. This is
## now a REAL requirement-level assertion, not a "known gap" placeholder: it
## is expected to PASS, and a future change that pushes the panel over it is
## a real regression to fix, not a gap to re-document.
##
## Deliberately SEPARATE from PANEL_HEIGHT_COMPACT_TARGET_PX above (a tight
## regression bound at this session's real measurement) so the two claims
## never get conflated: "did not regress" versus "meets the author's own
## allowance". The font changed project-wide from Pixelify Sans to
## Jersey 10 after every package returned (Pixelify's digits misread at small
## sizes -- see the report, "digit legibility"); Jersey 10 is narrower, so
## this const is the one place to update the number once that re-measurement
## happens -- this test deliberately does not chase the current font's exact
## last pixel.
const PANEL_HEIGHT_AUTHOR_CAP_PX: float = 1080.0 * 0.35 # 378 px at 1080p -- Author decision 2026-09-20, UI pass LEDGER UR-25; docs/19 change requested in HANDOFF H-05


func test_panel_height_stays_within_the_authors_35_percent_screen_height_allowance() -> void:
	var console: Console = _build_console()

	# CHANGE 1 (D107, 2026-09-23): opens via console_open (request_open()),
	# not the old dwell -- see src/ui/console.gd's own class doc, "CHANGE 1."
	assert_bool(console.request_open()).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var panel_size: Vector2 = console.get_panel_control_for_test().size
	var margin_px: float = PANEL_HEIGHT_AUTHOR_CAP_PX - panel_size.y
	print("[ui_console_layout_test] panel height %.1f px vs the author's 35%% allowance %.1f px (margin %.1f px, UR-25)" % [panel_size.y, PANEL_HEIGHT_AUTHOR_CAP_PX, margin_px])
	assert_float(panel_size.y).append_failure_message("Panel height %.1f px exceeds the author's 35%% screen-height allowance (%.1f px at 1080p, Author decision 2026-09-20, UR-25) -- see console.gd's own header and the report, 'UR-11', for what holds the height up" % [panel_size.y, PANEL_HEIGHT_AUTHOR_CAP_PX]).is_less_equal(PANEL_HEIGHT_AUTHOR_CAP_PX)
