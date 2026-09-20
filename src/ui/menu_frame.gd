extends RefCounted
class_name MenuFrame

## Shared chrome for the three paused-menu surfaces this package restyles
## (PauseMenu, SettingsMenu, RunEndScreen) -- phases/UI_PASS/BRIEF.md,
## package D: "a shared src/ui/menu_frame.gd helper the three menus use, so
## they are one design and not three copies." Builds the common Root / Dim
## / Center / Card / Column chain, the title label, the separator, and the
## two hard-boundary carve-outs the brief allows for styling
## src/run/paused_choice_bar.gd from the outside (that file is NOT in this
## package's write scope -- see its own header and this file's callers for
## the citation).
##
## Stateless, like UiPalette/UiTheme: a RefCounted of static builder
## functions only, so a gdUnit4 test can call these with no scene load.
## Behaviour stays with the caller (PauseMenu/SettingsMenu/RunEndScreen
## keep every signal, public method, and `_for_test` seam exactly as it
## was) -- this file only assembles Control nodes and applies theme/
## palette tokens.
##
## ## TODO(ui-pass): promote to UiPalette
## `CARD_MIN_WIDTH` has no home in `UiPalette`: its `SPACE_*` tokens run
## 4-32 px, sized for padding and separation, not a modal card's own
## minimum width. Reported in phases/UI_PASS/reports/D_menus.md.

const CARD_MIN_WIDTH: float = 420.0 ## TODO(ui-pass): promote to UiPalette as a shared modal-card width token


## The five nodes every one of the three menus builds, in the same shape,
## so `pause_menu.gd`/`settings_menu.gd`/`run_end.gd` can add their own
## title/content/bar into `column` without repeating this scaffold.
class Parts extends RefCounted:
	var root: Control
	var dim: ColorRect
	var center: CenterContainer
	var card: PanelContainer
	var column: VBoxContainer
	var motion_tween: Tween = null ## tracked so animate_in() can kill a still-running fade before starting another (tower_visuals.gd's own `_flash_tween`/`is_running()` convention)


## Builds Root -> Dim -> Center -> Card(UiTheme.CARD) -> Column under
## `layer` and applies the shared theme once, at the root Control (task
## brief, rule 1: "Apply the shared theme once at the surface's root
## Control"). `dim_alpha` is the CALLER's own existing, Register-cited or
## interpreted figure -- never invented here; only the dim's RGB is
## retinted, from `UiPalette.DIM_TINT`, since no test in this package's
## covering suites asserts the dim's colour (see the package report).
## `column_separation` replaces each file's own literal (28 for Pause and
## Settings, 16 for Run End) with the nearest `UiPalette.SPACE_*` token, per
## rule 2.
static func build(layer: CanvasLayer, dim_alpha: float, column_separation: int) -> Parts:
	var parts := Parts.new()

	parts.root = Control.new()
	parts.root.name = "Root"
	parts.root.theme = UiTheme.get_theme()
	parts.root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parts.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(parts.root)

	parts.dim = ColorRect.new()
	parts.dim.name = "Dim"
	parts.dim.color = UiPalette.with_alpha(UiPalette.DIM_TINT, dim_alpha)
	parts.dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parts.dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parts.root.add_child(parts.dim)

	parts.center = CenterContainer.new()
	parts.center.name = "Center"
	parts.center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parts.center.mouse_filter = Control.MOUSE_FILTER_PASS
	parts.root.add_child(parts.center)

	parts.card = PanelContainer.new()
	parts.card.name = "Card"
	parts.card.theme_type_variation = UiTheme.CARD
	parts.card.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0.0)
	parts.card.mouse_filter = Control.MOUSE_FILTER_PASS
	parts.center.add_child(parts.card)

	parts.column = VBoxContainer.new()
	parts.column.name = "Column"
	parts.column.mouse_filter = Control.MOUSE_FILTER_PASS
	parts.column.add_theme_constant_override("separation", column_separation)
	parts.card.add_child(parts.column)

	return parts


## A title Label matching every existing menu's own convention (autowrap,
## no truncation, expand-fill), styled with a `UiTheme` Label variation
## instead of the theme's bare default. `parent` is usually `parts.column`
## directly, but Run End nests it in its own outcome-glyph row instead
## (see run_end.gd's `_build_ui()`).
static func build_title(parent: Container, text: String, variation: StringName, min_width: float) -> Label:
	var lbl := Label.new()
	lbl.name = "Title"
	lbl.text = text
	lbl.theme_type_variation = variation
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(min_width, 0.0)
	parent.add_child(lbl)
	return lbl


## A thin rule between the title and the content below it. Picks up
## `UiTheme`'s own `HSeparator` stylebox (`UiPalette.LINE`,
## `UiPalette.BORDER_THIN`) through inheritance -- no per-node override
## needed.
static func build_separator(parent: Container) -> HSeparator:
	var sep := HSeparator.new()
	sep.name = "Separator"
	parent.add_child(sep)
	return sep


## Hard-boundary carve-out #1 (phases/UI_PASS/BRIEF.md, package D): "after
## the menu calls set_options() you may set theme_type_variation on its
## [PausedChoiceBar's] Label children via get_children() (not via the
## _for_test seam)." Called once, right after the menu's own one-time
## `bar.set_options()` call -- every caller in this package only calls
## `set_options()` once, so there is no later rebuild to re-style.
static func style_choice_labels(bar: PausedChoiceBar) -> void:
	for child in bar.get_children():
		if child is Label:
			(child as Label).theme_type_variation = UiTheme.VALUE


## Tight footer for the hold-to-confirm ring (coordinator follow-up,
## package D: "the ring floats alone under the highlight underline with a
## lot of empty space -- tighten the spacing"). A nested `VBoxContainer`
## with `UiPalette.SPACE_XS` separation, added as ONE child of `column` --
## the column's own, larger separation (`UiPalette.SPACE_XL`/`SPACE_L`)
## still applies once, between the choice bar and this footer, matching
## every other gap in the column; only the ring's OWN distance from the
## highlight row directly above it tightens. No hint text is added here or
## anywhere else in this footer -- none of the three menus had one before
## this follow-up, and the brief said not to invent one.
static func build_hold_footer(column: Container) -> VBoxContainer:
	var footer := VBoxContainer.new()
	footer.name = "HoldFooter"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	column.add_child(footer)
	return footer


## Hard-boundary carve-out #2: the colour-only-distinctions rule applies to
## `PausedChoiceBar`'s own highlight, which is `modulate`-only (that file's
## `_refresh_highlight()`) and out of this package's write scope. This adds
## a SHAPE cue -- a sibling strip that draws an accent underline beneath the
## highlighted option only -- driven by the bar's own public
## `highlighted_changed` signal (fires on cycle and on hover alike, which is
## exactly the coverage a shape cue needs). See `ChoiceHighlightRow`'s own
## header for how it tracks the option's real rectangle, and
## phases/UI_PASS/HANDOFF.md H-04 for the fix proposed at the source.
static func build_highlight_row(parent: Container, bar: PausedChoiceBar) -> ChoiceHighlightRow:
	var row := ChoiceHighlightRow.new()
	row.name = "HighlightRow"
	parent.add_child(row)
	row.configure(bar)
	return row


## `DraftFillRing`'s two colour exports, restyled from `UiPalette` instead
## of that file's own hardcoded defaults -- its public surface only
## (`progress`, `ring_color`, `track_color`; DraftFillRing itself is owned
## by another implementer and stays untouched).
static func style_fill_ring(ring: DraftFillRing) -> void:
	ring.ring_color = UiPalette.ACCENT
	ring.track_color = UiPalette.with_alpha(UiPalette.LINE, 0.6)


## Cosmetic fade/scale-in of `parts.card` (rule 6: "a bare create_tween()
## on the node itself"; never `get_tree().create_tween()`). Guarded by
## `is_inside_tree()` (some suites instance these menus outside the tree)
## and safe to call more than once in a row (kills a still-running fade
## first, matching tower_visuals.gd's own `is_running()` convention).
## Purely visual: never touches `visible`, never delays the caller's own
## `_bar.set_active()` call, which the menu's `set_active()` still makes
## first, synchronously, exactly as before this package's change.
static func animate_in(parts: Parts) -> void:
	var card: PanelContainer = parts.card
	if parts.motion_tween != null and parts.motion_tween.is_running():
		parts.motion_tween.kill()
	if not card.is_inside_tree():
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	var tween: Tween = card.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # runs while the tree is paused -- the owning CanvasLayer is PROCESS_MODE_ALWAYS (rule 6)
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, UiPalette.MOTION_BASE)
	tween.tween_property(card, "modulate:a", 1.0, UiPalette.MOTION_BASE)
	parts.motion_tween = tween


## `set_active(false)` hides immediately (rule 6: "On set_active(false)
## hide immediately") -- kills any in-flight fade and snaps the card back
## to its resting scale/opacity so the NEXT `animate_in()` starts clean.
static func reset_motion(parts: Parts) -> void:
	if parts.motion_tween != null and parts.motion_tween.is_running():
		parts.motion_tween.kill()
	parts.motion_tween = null
	var card: PanelContainer = parts.card
	if not card.is_inside_tree():
		return
	card.scale = Vector2.ONE
	card.modulate.a = 1.0
