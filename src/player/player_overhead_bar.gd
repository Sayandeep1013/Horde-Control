extends Node2D
class_name PlayerOverheadBar

## PlayerOverheadBar (author request, 2026-09-23: "show player healthbar
## and tower healthbar right above them just like enemies but in different
## colours ... the exp bar too"). Reuses src/enemy/enemy_health_bar.gd's
## cheap `_draw()`-only style for the HP segment -- outline, background, a
## delayed white "recent damage" trail that eases down toward the real
## value over time (`TRAIL_CATCHUP_FRACTION_PER_SECOND`, the same constant
## and technique that file already uses) -- but ALWAYS visible: an enemy's
## bar only appears after its first hit and hides again a couple of seconds
## after the last one (enemy_health_bar.gd's own `FADE_DELAY_SECONDS`/
## `FADE_DURATION_SECONDS`), which is right for a disposable mob but wrong
## for the player's own vitals, which matter from frame one. This file has
## no whole-bar fade at all; only the trail sliver itself shrinks away as it
## catches up to the real value, which is what "fade their trail after
## hits" (task instruction) asks for.
##
## Adds a second, thinner XP segment directly beneath the HP bar, filling
## toward the next level -- the task's own "the exp bar too."
##
## ## Draw order: absolute z_index 50
## MASTER_SDLC.md > Provisional Values Register > Interfaces >
## "Readability" (Author decision D119, 2026-09-23): the numeric band the
## player's own OLD fixed z_index occupied (50, when the player was kept
## permanently above every enemy) is repurposed as the "overhead bars always
## draw on top" band, now that the player itself has moved into the shared,
## Y-sorted play-layer band (20) alongside the Tower and every enemy --
## see src/player/player.gd's own header for that half of the change.
## `z_as_relative = false` makes this node's z_index ABSOLUTE regardless of
## how deep its ancestor chain is or what z_index those ancestors carry,
## matching src/enemy/telegraph_visual.gd's and src/fx/blood_fx.gd's own
## established technique for the identical "a relative z_index would
## accumulate through a y_sort-enabled ancestor" problem (see those files'
## headers) -- deliberate, since the whole point of an "always readable"
## bar is that it must stay on top even on a tick where Y-sort draws the
## player's OWN body behind something else.
##
## ## HP source
## This node's own sibling DeathState (`src/combat/death_state.gd`, shared
## unmodified by the player, every enemy, and the Tower) -- the exact same
## `current_hp`/`max_hp`/`damage_applied`/`logical_death` shape
## enemy_health_bar.gd already reads, and the exact same object
## src/ui/hud.gd's own `_refresh_player_health()` reads
## (`_player.death_state.current_hp`/`max_hp`).
##
## ## XP source
## `economy_state` (`HudEconomyState`), read-only, set once by
## src/integration/prototype_integration.gd to the SAME instance
## src/ui/hud.gd already reads for its own XP ribbon (`Hud.economy_state`)
## -- task instruction: "read XP progress from the same source the HUD XP
## ribbon uses ... read-only." Never assumed non-null: every existing unit
## test that instances scenes/player.tscn directly (there is no run/XP
## concept in those fixtures at all) simply never wires this, and the XP
## segment is skipped -- the correct degrade, not a defensive workaround.

@export var death_state_path: NodePath = NodePath("../DeathState")
@export var bar_width: float = 40.0
@export var hp_bar_height: float = 5.0
@export var xp_bar_height: float = 3.0
@export var gap_px: float = 2.0

## Distance above the player's own origin the HP bar's CENTRE sits at
## (negative is up, Godot 2D screen-space Y). scenes/player.tscn's own
## `Shadow` node comment measures Archer_Blue's drawn content at ~64 px
## tall with the feet ~28 px below the player's origin, so the top of the
## head sits around -36; placed with clear headroom above that, matching
## the kind of margin enemy_health_bar.gd's own per-species
## `vertical_offset` already gives the (taller) goblin sprites.
@export var hp_vertical_offset: float = -50.0

## Fraction of max HP the white trail sheds per second while catching up to
## the real fill -- enemy_health_bar.gd's own constant, same value, same
## reasoning (a fixed-time visual, not a Register number).
const TRAIL_CATCHUP_FRACTION_PER_SECOND: float = 1.6

const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.9)
const COLOR_BACKGROUND: Color = Color(0.10, 0.09, 0.09, 0.85)
const COLOR_TRAIL: Color = Color(0.98, 0.98, 0.95, 0.95)

## Set once by src/integration/prototype_integration.gd via
## `set_economy_state()` below -- see header, "XP source."
var economy_state: HudEconomyState = null

var _death_state: DeathState = null

## Displayed white-trail HP value; only ever eases DOWN toward the real
## current_hp. INF until the first hit, matching enemy_health_bar.gd's own
## reasoning ("the very first _draw() ... never shows a trail sliver").
var _trail_hp: float = INF

var _xp_vertical_offset: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false # see header, "Draw order"
	z_index = 50
	_xp_vertical_offset = hp_vertical_offset + hp_bar_height * 0.5 + gap_px + xp_bar_height * 0.5
	_death_state = get_node_or_null(death_state_path) as DeathState
	if _death_state != null:
		_death_state.damage_applied.connect(_on_damage_applied)
	set_process(true)
	queue_redraw()


## Typed command (this project's own convention -- e.g. `Hud.set_player_
## ref()`). Called once by src/integration/prototype_integration.gd with
## the SAME `HudEconomyState` instance the HUD's own XP ribbon reads.
func set_economy_state(state: HudEconomyState) -> void:
	economy_state = state


func _process(delta: float) -> void:
	var redraw_needed: bool = false
	if _death_state != null and _trail_hp > _death_state.current_hp:
		_trail_hp = maxf(_death_state.current_hp, _trail_hp - _death_state.max_hp * TRAIL_CATCHUP_FRACTION_PER_SECOND * delta)
		redraw_needed = true
	if economy_state != null:
		# XP can rise on any tick (credit_xp() has no signal this node could
		# subscribe to instead); redrawing unconditionally while wired is as
		# cheap as src/ui/hud_bar.gd's own always-on _process(), which this
		# bar otherwise mirrors.
		redraw_needed = true
	if redraw_needed:
		queue_redraw()


func _draw() -> void:
	_draw_hp_bar()
	if economy_state != null:
		_draw_xp_bar()


func _draw_hp_bar() -> void:
	var max_hp: float = maxf(_death_state.max_hp, 0.001) if _death_state != null else 1.0
	var current_hp: float = clampf(_death_state.current_hp, 0.0, max_hp) if _death_state != null else max_hp
	var frac: float = current_hp / max_hp
	var trail_frac: float = (clampf(_trail_hp, 0.0, max_hp) / max_hp) if is_finite(_trail_hp) else frac

	var half_w: float = bar_width * 0.5
	var half_h: float = hp_bar_height * 0.5
	var top_left: Vector2 = Vector2(-half_w, hp_vertical_offset - half_h)

	draw_rect(Rect2(top_left + Vector2(-1.0, -1.0), Vector2(bar_width + 2.0, hp_bar_height + 2.0)), COLOR_OUTLINE, true)
	draw_rect(Rect2(top_left, Vector2(bar_width, hp_bar_height)), COLOR_BACKGROUND, true)

	if trail_frac > frac:
		draw_rect(Rect2(top_left, Vector2(bar_width * trail_frac, hp_bar_height)), COLOR_TRAIL, true)

	if frac > 0.0:
		draw_rect(Rect2(top_left, Vector2(bar_width * frac, hp_bar_height)), UiPalette.PLAYER, true)


func _draw_xp_bar() -> void:
	var required: float = maxf(economy_state.xp_required_for_next_level, 0.001)
	var frac: float = clampf(economy_state.xp_current / required, 0.0, 1.0)

	var half_w: float = bar_width * 0.5
	var half_h: float = xp_bar_height * 0.5
	var top_left: Vector2 = Vector2(-half_w, _xp_vertical_offset - half_h)

	draw_rect(Rect2(top_left + Vector2(-1.0, -1.0), Vector2(bar_width + 2.0, xp_bar_height + 2.0)), COLOR_OUTLINE, true)
	draw_rect(Rect2(top_left, Vector2(bar_width, xp_bar_height)), COLOR_BACKGROUND, true)

	if frac > 0.0:
		draw_rect(Rect2(top_left, Vector2(bar_width * frac, xp_bar_height)), UiPalette.XP, true)


## DeathState.damage_applied(amount, source, remaining_hp) -- see
## enemy_health_bar.gd's own identical handler for why this alone is enough
## to stay correct with no separate reset step.
func _on_damage_applied(amount: float, _source: Variant, remaining_hp: float) -> void:
	_trail_hp = maxf(_trail_hp if is_finite(_trail_hp) else 0.0, remaining_hp + amount)
	queue_redraw()
