extends Node2D
class_name EnemyHealthBar

## EnemyHealthBar (hit-feedback pass, follow-up to the art session). A
## small, cheap `_draw()`-only health bar shown above an enemy's head once
## it has taken damage. Purely cosmetic and read-only -- matches `src/enemy/
## enemy_animator.gd`'s own established pattern for this project ("this
## component only reads DeathState's existing public fields/signals ...
## No change was made to ... src/combat/death_state.gd"): this file adds no
## new field or signal to DeathState, and reads only `current_hp`, `max_hp`,
## `is_dead`, and the existing `damage_applied` / `logical_death` signals.
##
## ## Why polling `current_hp`/`max_hp` every frame instead of caching them
## `enemy_controller.gd`'s own `_configure_for_intent()` (or equivalent
## respawn path) can change `death_state.max_hp` across a pool reuse --
## enemies are not guaranteed to come back with the same HP band they had
## before. Reading both values live, straight off DeathState, in `_draw()`
## every time it actually redraws (never cached in a field this script
## would then have to remember to invalidate) means a reused instance is
## always drawn correctly with no separate "reset" step required for the
## fill itself.
##
## ## Reuse without an explicit reset hook
## `damage_applied(amount, source, remaining_hp)` always reports the exact
## HP value immediately before AND after a hit (`remaining_hp + amount` is
## the pre-hit HP), so the white "recent damage" trail below is computed
## from that signal alone and is correct after a pool reuse with no special
## case: the first hit landed on a freshly-reused instance naturally carries
## a pre-hit HP of `max_hp` (`reset_for_reuse()`/the respawn path already set
## `current_hp = max_hp` before any new hit can land), so the trail starts
## from the right place even though this script was never told a reuse just
## happened. `logical_death` unconditionally hides the bar and stops this
## node's own `_process`, so a corpse never shows a stale bar; the next
## `damage_applied` after a reuse turns `_process` back on. This mirrors
## `enemy_animator.gd`'s own "self-heals ... regardless of *how* the flag
## was cleared" reasoning, just via signals already fired at the right
## times instead of a per-frame `is_dead` poll (this file only pays the
## per-frame `_process` cost while a bar is actually visible, unlike the
## animator, which must run every frame for every live enemy regardless).
##
## ## Positioning
## `vertical_offset` is authored per enemy scene, not computed here: the
## three sprite sheets do not share a head height (measured against each
## enemy's own `AnimatedSprite2D.offset` and idle frame, tools/art frame
## size accounted for -- Tower Seeker's torch-goblin art reads tallest,
## Opportunist's disguised-barrel art shortest). A single hardcoded default
## would sit wrong on at least one of the three.

@export var death_state_path: NodePath = NodePath("../DeathState")

## Distance above this node's parent origin (the body's feet, per every
## enemy scene's own `AnimatedSprite2D.offset` convention) the bar's CENTER
## sits at. Negative is up (Godot 2D screen-space Y). Tune per scene to
## clear that species' own head.
@export var vertical_offset: float = -86.0

@export var bar_width: float = 32.0
@export var bar_height: float = 4.0

const FADE_DELAY_SECONDS: float = 2.0
const FADE_DURATION_SECONDS: float = 0.4

## Fraction of max HP the white trail sheds per second while catching up to
## the real fill -- a fixed-time visual, not a Register value (no gameplay
## effect either way).
const TRAIL_CATCHUP_FRACTION_PER_SECOND: float = 1.6

const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.9)
const COLOR_BACKGROUND: Color = Color(0.10, 0.09, 0.09, 0.85)
const COLOR_LOW_HP: Color = Color(0.82, 0.14, 0.10, 1.0)
const COLOR_HIGH_HP: Color = Color(0.92, 0.80, 0.18, 1.0)
const COLOR_TRAIL: Color = Color(0.98, 0.98, 0.95, 0.95)

var _death_state: DeathState = null

## Displayed white-trail HP value; only ever eases DOWN toward the real
## `current_hp` (see `_process()`). Initialized to +INF so the very first
## `_draw()` before any signal has fired never shows a trail sliver.
var _trail_hp: float = INF

var _time_since_hit: float = 0.0
var _shown: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE # pauses with the enemy it decorates, matching enemy_animator.gd's own convention
	_death_state = get_node_or_null(death_state_path) as DeathState
	position = Vector2(0.0, vertical_offset)
	visible = false
	set_process(false)
	if _death_state != null:
		_death_state.damage_applied.connect(_on_damage_applied)
		_death_state.logical_death.connect(_on_logical_death)


func _process(delta: float) -> void:
	if _death_state == null or not _shown:
		set_process(false)
		return

	var redraw_needed: bool = false

	if _trail_hp > _death_state.current_hp:
		_trail_hp = maxf(_death_state.current_hp, _trail_hp - _death_state.max_hp * TRAIL_CATCHUP_FRACTION_PER_SECOND * delta)
		redraw_needed = true

	_time_since_hit += delta
	if _time_since_hit >= FADE_DELAY_SECONDS:
		var fade_t: float = clampf((_time_since_hit - FADE_DELAY_SECONDS) / FADE_DURATION_SECONDS, 0.0, 1.0)
		modulate.a = 1.0 - fade_t
		redraw_needed = true
		if fade_t >= 1.0:
			_shown = false
			visible = false
			set_process(false)
	else:
		modulate.a = 1.0

	if redraw_needed:
		queue_redraw()


func _draw() -> void:
	if _death_state == null:
		return
	var max_hp: float = maxf(_death_state.max_hp, 0.001)
	var current_hp: float = clampf(_death_state.current_hp, 0.0, max_hp)
	var frac: float = current_hp / max_hp
	var trail_frac: float = clampf(_trail_hp, 0.0, max_hp) / max_hp

	var half_w: float = bar_width * 0.5
	var half_h: float = bar_height * 0.5

	draw_rect(Rect2(-half_w - 1.0, -half_h - 1.0, bar_width + 2.0, bar_height + 2.0), COLOR_OUTLINE, true)
	draw_rect(Rect2(-half_w, -half_h, bar_width, bar_height), COLOR_BACKGROUND, true)

	if trail_frac > frac:
		draw_rect(Rect2(-half_w, -half_h, bar_width * trail_frac, bar_height), COLOR_TRAIL, true)

	if frac > 0.0:
		var fill_color: Color = COLOR_LOW_HP.lerp(COLOR_HIGH_HP, frac)
		draw_rect(Rect2(-half_w, -half_h, bar_width * frac, bar_height), fill_color, true)


## `DeathState.damage_applied` (src/combat/death_state.gd): fires with the
## exact HP just before (`remaining_hp + amount`) and after (`remaining_hp`)
## this hit -- see header, "Reuse without an explicit reset hook" for why
## this alone is enough to stay correct across a pool reuse with no extra
## reset call.
func _on_damage_applied(amount: float, _source: Variant, remaining_hp: float) -> void:
	_trail_hp = maxf(_trail_hp if is_finite(_trail_hp) else 0.0, remaining_hp + amount)
	_time_since_hit = 0.0
	_shown = true
	visible = true
	modulate.a = 1.0
	set_process(true)
	queue_redraw()


## `DeathState.logical_death`: hides immediately (brief: "hidden on death"),
## synchronous with the same call that may have just shown it (see
## death_state.gd's `apply_damage()` -- `damage_applied` then, if lethal,
## `_enter_logical_death()` in the same call), so a killing blow never
## flashes a bar on a corpse for even one frame.
func _on_logical_death(_entity: Node2D, _position: Vector2) -> void:
	_shown = false
	visible = false
	set_process(false)
