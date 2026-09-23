extends Node2D
class_name TowerOverheadBar

## TowerOverheadBar (author request, 2026-09-23: "show ... tower healthbar
## right above them just like enemies but in different colours"). Same
## cheap `_draw()`-only, always-visible style as
## src/player/player_overhead_bar.gd (see that file's header for the fuller
## reasoning this one does not repeat), sized to the task's own "~120x7"
## instruction, and carrying the Tower's TWO pools: a thin blue shield
## segment along the top and the health fill below it, matching
## src/ui/hud_bar.gd's own `SHIELD_SEGMENT_HEIGHT_FRACTION` convention --
## "the shield absorbs damage before health," drawn as a distinct
## sub-region rather than a second colour smeared over the same rectangle
## (MASTER_SDLC.md > Visual Edge Cases > "Colour-only distinctions"), in the
## SAME two colours (`UiPalette.SHIELD`, `UiPalette.TOWER`) the HUD's own
## Tower bar already uses -- task instruction: "matching the HUD's Tower
## colours."
##
## Draw order: absolute z_index 50, `z_as_relative = false` -- see
## player_overhead_bar.gd's header, "Draw order," for the full reasoning
## (Author decision D119); identical here.
##
## Health/shield source: this node's own sibling TowerHealth
## (src/tower/tower_health.gd) -- `get_current_health()`/`max_health`/
## `current_shield`/`max_shield`, the exact same read src/ui/hud.gd's own
## `_refresh_tower_health()` already performs, refreshed on that
## component's own `health_changed`/`shield_changed` signals rather than
## polled every frame.
##
## Trail source: this node's own sibling DeathState. `TowerHealth` forwards
## only the POST-SHIELD remainder to its own wired DeathState (see
## tower_health.gd's header, "the double-damage problem"), so
## `damage_applied`'s `amount` here is the real HEALTH loss for a hit, not
## the raw pre-shield amount -- correct for a HEALTH-segment trail.

@export var tower_health_path: NodePath = NodePath("../TowerHealth")
@export var death_state_path: NodePath = NodePath("../DeathState")
@export var bar_width: float = 120.0
@export var bar_height: float = 7.0

## Above the tallest stage's roofline with clear headroom. tower_visuals.gd's
## own `Sprite` sits at local y=-64 within its ~256 px-tall canvas (see
## scenes/tower.tscn's own comment), so the canvas top edge is already
## around -192; the Castle_Blue stage (stage 2) reads taller still.
@export var vertical_offset: float = -215.0

## Matches src/ui/hud_bar.gd's own constant of the same name/value.
const SHIELD_SEGMENT_HEIGHT_FRACTION: float = 0.35
const TRAIL_CATCHUP_FRACTION_PER_SECOND: float = 1.6

const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.9)
const COLOR_BACKGROUND: Color = Color(0.10, 0.09, 0.09, 0.85)
const COLOR_TRAIL: Color = Color(0.98, 0.98, 0.95, 0.95)

var _tower_health: TowerHealth = null
var _death_state: DeathState = null

## Displayed white-trail HEALTH value; only ever eases DOWN toward the real
## current health. INF until the first hit (see player_overhead_bar.gd's
## identical field for why).
var _trail_hp: float = INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false # see header, "Draw order"
	z_index = 50
	_tower_health = get_node_or_null(tower_health_path) as TowerHealth
	_death_state = get_node_or_null(death_state_path) as DeathState
	if _death_state != null:
		_death_state.damage_applied.connect(_on_damage_applied)
	if _tower_health != null:
		_tower_health.shield_changed.connect(_on_pool_changed)
		_tower_health.health_changed.connect(_on_pool_changed)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _death_state == null:
		set_process(false)
		return
	if _trail_hp > _death_state.current_hp:
		_trail_hp = maxf(_death_state.current_hp, _trail_hp - _death_state.max_hp * TRAIL_CATCHUP_FRACTION_PER_SECOND * delta)
		queue_redraw()


## TowerHealth.shield_changed(current, max) / health_changed(current, max)
## -- a rank change (Shield Matrix) or shield regen redraws immediately
## instead of waiting for the next damage tick, unlike the trail (which has
## no meaning for a RISE and stays purely _process()-driven).
func _on_pool_changed(_current: float, _max_v: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _tower_health == null:
		return
	var max_health: float = maxf(_tower_health.max_health, 0.001)
	var current_health: float = clampf(_tower_health.get_current_health(), 0.0, max_health)
	var frac: float = current_health / max_health
	var trail_frac: float = (clampf(_trail_hp, 0.0, max_health) / max_health) if is_finite(_trail_hp) else frac
	# Register > Tower: shield is a fraction of Tower MAX HEALTH (matching
	# hud_bar.gd's own header: "the two pools share one visual scale, per
	# 'overlaid ... on the health bar'"), not of its own max_shield.
	var shield_frac: float = clampf(_tower_health.current_shield / max_health, 0.0, 1.0)

	var half_w: float = bar_width * 0.5
	var half_h: float = bar_height * 0.5
	var top_left: Vector2 = Vector2(-half_w, vertical_offset - half_h)

	draw_rect(Rect2(top_left + Vector2(-1.0, -1.0), Vector2(bar_width + 2.0, bar_height + 2.0)), COLOR_OUTLINE, true)
	draw_rect(Rect2(top_left, Vector2(bar_width, bar_height)), COLOR_BACKGROUND, true)

	var shield_h: float = bar_height * SHIELD_SEGMENT_HEIGHT_FRACTION
	var health_top_left: Vector2 = Vector2(top_left.x, top_left.y + shield_h)
	var health_h: float = bar_height - shield_h

	if trail_frac > frac:
		draw_rect(Rect2(health_top_left, Vector2(bar_width * trail_frac, health_h)), COLOR_TRAIL, true)
	if frac > 0.0:
		draw_rect(Rect2(health_top_left, Vector2(bar_width * frac, health_h)), UiPalette.TOWER, true)
	if shield_frac > 0.0:
		draw_rect(Rect2(top_left, Vector2(bar_width * shield_frac, shield_h)), UiPalette.SHIELD, true)


## DeathState.damage_applied(amount, source, remaining_hp) -- see header,
## "Trail source," for why `amount` here is already the post-shield HEALTH
## loss.
func _on_damage_applied(amount: float, _source: Variant, remaining_hp: float) -> void:
	_trail_hp = maxf(_trail_hp if is_finite(_trail_hp) else 0.0, remaining_hp + amount)
	set_process(true)
	queue_redraw()
