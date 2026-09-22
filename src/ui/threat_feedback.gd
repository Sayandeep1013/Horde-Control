extends Control
class_name ThreatFeedback

## ThreatFeedback (P2.6). MASTER_SDLC.md > Visual Direction & Camera >
## "Directional Threat Feedback" in full; > Provisional Values Register >
## Interfaces > "Threat feedback" row (every number/behaviour below is
## cited from there, never restated as an independent literal, except one
## escalated constant named explicitly below); docs/20_Technical_
## Architecture.md > "Audio Mixing & Dynamic Ducking" > "Tower Cue Player"
## for the audio half (C-TOWERCUE).
##
## ## SimClock, not wall-clock, for the 1 s window and the 0.6 s fade (task
## brief, explicit instruction, not this file's own choice)
## This file lives under src/ui/, which the banned-API check exempts from
## SimClock entirely ("pure UI, which is not bound by SimClock" -- Global
## Simulation Authority). This file's own timings are an exception to that
## exemption by explicit instruction: the 1-second damage window and the
## 0.6-second fade are WORLD-FACING feedback about a gameplay event (Tower
## damage), not cosmetic chrome, so both are measured against `SimClock.now`
## (via an injectable `_clock` reference, mirroring `tower_health.gd`'s own
## `set_sim_clock_for_test()` convention) rather than `_process(delta)`'s
## real per-frame delta. `_process()` itself still drives the per-frame
## redraw -- there is nothing to gain by moving the redraw call itself onto
## SimClock, only the DEADLINE MATH inside `_recompute()` needs to be
## SimClock-based, and it is.
##
## ## The attacker-position seam: read the Tower's Hurtbox directly, not
## EventBus
## `EventBus.tower_damaged(amount, new_health, new_shield, timestamp)`
## (src/core/event_bus.gd, outside this task's write scope) does not carry
## an attacker position, and Register wording requires pointing "at the
## attacker when the Tower is on-screen" -- a real requirement EventBus's
## current three signals cannot satisfy. Rather than escalate a signal this
## task cannot add, this file connects directly to the Tower's own
## `Hurtbox.damage_received(amount, source, hitbox)` signal (P1.5, already
## public, already what `src/tower/tower_health.gd` itself listens to for
## the identical reason -- see that file's header) and resolves the
## attacker's position from `hitbox`/`source` when either is a `Node2D`.
## Named as a cross-task seam in the P2.6 evidence report, not a silent
## workaround: if EventBus later grows a richer `tower_damaged` signal that
## carries attacker position, this file could switch to it without changing
## any other behaviour.
##
## ## One escalated constant: damage-to-full-intensity normalization
## No Provisional Values Register row states how much Tower damage within
## the 1-second window should read as FULL (1.0) vignette intensity --
## Register only says intensity "follows the damage taken in the last 1 s."
## `DAMAGE_TO_FULL_INTENSITY_FRACTION_OF_MAX_HEALTH` below is this task's
## own placeholder, marked `# NO REGISTER ROW -- escalated` per this task's
## own rule 6, and listed in the P2.6 evidence report's "Escalations"
## section for the author to confirm or replace.
##
## ## Not PROCESS_MODE_ALWAYS
## Matches `src/audio/tower_cue_player.gd`'s own reasoning, cited there:
## Tower-damage events fire from gameplay, which does not occur while the
## simulation is paused, so this node pausing along with the gameplay root
## (default PROCESS_MODE_INHERIT/PAUSABLE) costs nothing and needs no
## exemption.
##
## ## Real cue audio (integration task; closes LEDGER F03-18's audio half)
## `cue_stream` now defaults to `assets/third_party/kenney/audio/sfx/
## tower_damage.ogg`, an `@export` (D99: never a hardcoded path in a
## function) so it stays swappable as a data edit. `_build_placeholder_
## cue_stream()` (P2.6's original procedural tone) is kept, unused by
## default, as the fallback for the degenerate case where `cue_stream` is
## explicitly cleared to null on a scene/instance -- so this file never
## hands `TowerCuePlayer.play_tower_damage()` a null stream.
##
## ## UI pass (phases/UI_PASS/BRIEF.md, package A, item 7): palette + polish
## Every drawn `Color(...)` literal is now a `UiPalette` token: the vignette
## wedges and the low-health warning diamond use `UiPalette.DANGER`, the
## normal (not-low-health) indicator uses `UiPalette.ACCENT`, and the
## indicator's rim and the hit arc are drawn over a wider, darker
## `UiPalette.TEXT_OUTLINE` pass first, so they stay legible against any
## background colour underneath (see "UI pass round 2" below for why the
## vignette itself does NOT get this outline treatment).
## `get_indicator_shape()`/`get_indicator_color()`'s call sites and
## branching are unchanged; only the two literal `Color(...)` values
## `get_indicator_color()` returns change (confirmed against
## tests/unit/threat_feedback_indicator_test.gd first: it only asserts the
## two colours DIFFER from each other, never their exact values).
##
## ## UI pass round 2 (LEDGER UR-02, orchestrator direction after reviewing
## the round-1 capture)
## Round 1's vignette (a flat-alpha annulus wedge inset ~45% from the
## screen edge, with a dark outline around each lit wedge) read as a solid
## salmon block with a debug-overlay edge, not a directional glow: opaque
## enough to hide enemies/pickups under it, its inner edge far enough from
## the border to cover real playfield, and its 8 wedges meeting at hard
## seams. `_draw_vignette_segments()` is rewritten below, cosmetically
## only: `SEGMENT_COUNT`, `get_segment_intensities()`,
## `NEIGHBOR_BLEED_FRACTION`, and every timing/Register-cited value feeding
## them are untouched, and every getter a test reads still returns exactly
## what it returned before.
## 1. The wedge's OUTER boundary is now the literal screen edge (a ray from
##    centre to this Control's own rectangle boundary, `_rect_edge_point()`)
##    instead of a circle inset within it -- the vignette now actually hugs
##    the border, per PLAN.md direction item 1 ("the screen centre stays
##    clear").
## 2. The wedge's INNER boundary sits at `INNER_REACH_FRACTION` of the
##    shorter screen side, and alpha fades from 0 there to
##    `VIGNETTE_PEAK_ALPHA` at the outer/screen-edge boundary, via
##    per-vertex colours passed to `draw_polygon()` (Godot interpolates
##    between them across the triangulated wedge) rather than one flat
##    alpha for the whole shape.
## 3. Alpha is also interpolated ACROSS each wedge's own angular span toward
##    its two neighbours' intensities (`_blended_intensity_at_angle()`), so
##    adjacent wedges blend into each other at their shared boundary instead
##    of meeting at a hard seam -- purely a drawing-time smoothing of the
##    same 8 values `get_segment_intensities()` already returns.
## 4. No outline pass on the vignette at all: a dark outline reads as a
##    debug-overlay edge on what is meant to be a soft glow. It stays on the
##    small off-screen indicator below, where a hard edge is exactly what
##    legibility needs.

const SEGMENT_COUNT: int = 8
const SEGMENT_ANGLE: float = TAU / float(SEGMENT_COUNT)

## Register > Interfaces > "Threat feedback": "intensity follows damage in
## the last 1 s."
const DAMAGE_WINDOW_SECONDS: float = 1.0

## Register > Interfaces > "Threat feedback": "fades 0.6 s."
const FADE_SECONDS: float = 0.6

## Register > Interfaces > "Threat feedback": "off-screen Tower indicator
## changes shape and colour below 40% health." Same 40% figure as
## `HudBar.TICK_FRACTION` (src/ui/hud_bar.gd), read independently here
## rather than imported from that file, so this file has no load-order
## dependency on the other half of this same task's own deliverable.
const LOW_HEALTH_FRACTION: float = 0.4

## NO REGISTER ROW -- escalated. See header, "One escalated constant."
const DAMAGE_TO_FULL_INTENSITY_FRACTION_OF_MAX_HEALTH: float = 0.15

## Integration task: the real Tower-damage cue, replacing the procedurally
## generated placeholder tone (see header, "Real cue audio").
@export var cue_stream: AudioStream = preload("res://assets/third_party/kenney/audio/sfx/tower_damage.ogg")

## No separate Register timing exists for how long the off-screen
## indicator's "short arc on the side being hit" itself stays visible after
## a hit. Reused from `FADE_SECONDS` (the vignette's own, Register-backed,
## 0.6 s figure) rather than inventing a second undocumented constant for
## the same "how long does a damage indication linger" question. Named as
## an interpretation, not an explicit rule.
const HIT_ARC_DISPLAY_SECONDS: float = FADE_SECONDS

const NEIGHBOR_BLEED_FRACTION: float = 0.35

## Cosmetic-only drawing constants (UI pass, phases/UI_PASS/BRIEF.md,
## package A, item 7): none of these change SEGMENT_COUNT, a timing, or a
## value any getter above returns -- only how `_draw()` renders them.
## TODO(ui-pass): promote to UiPalette if a later pass wants a shared
## "indicator geometry" scale.
## UI pass round 2: `SEGMENT_ARC_SUBDIVISIONS` now also sets how many angular
## samples each wedge draws (edge shape + alpha blend resolution), since the
## outer boundary follows the screen's own rectangle instead of a circle.
const SEGMENT_ARC_SUBDIVISIONS: int = 6 ## samples per wedge span, for both the screen-edge boundary shape and the neighbour-blended alpha; SEGMENT_COUNT (the number of wedges) is unchanged
## UI pass round 2 (LEDGER UR-02): how far in from the screen edge the
## vignette's fully-transparent inner boundary sits, as a fraction of the
## shorter screen side -- keeps the screen centre clear (PLAN.md direction
## item 1) no matter the aspect ratio.
## TODO(ui-pass): promote to UiPalette if a later pass wants a shared
## "vignette reach" scale.
const INNER_REACH_FRACTION: float = 0.18
## UI pass round 2 (LEDGER UR-02): alpha at the vignette's outer (screen-
## edge) boundary at full intensity; fades to 0 at `INNER_REACH_FRACTION`.
## Round 1's flat 0.55 read as an opaque block hiding enemies/pickups under
## it; this is the peak of a radial GRADIENT, not a flat fill, so the
## visible average is well under this number even at full intensity.
## TODO(ui-pass): promote to UiPalette if a later pass wants a shared
## "vignette reach" scale.
const VIGNETTE_PEAK_ALPHA: float = 0.4
## Second UI pass (Tiny Swords restyle, task instruction: "make the off-
## screen Tower indicator clearly visible (larger arrow at the screen edge
## with the tower icon and its HP)"): the plain small circle is replaced by
## a directional arrow -- see _arrow_points()/_draw_offscreen_indicator() --
## and every size below grew accordingly. is_showing_offscreen_indicator(),
## get_indicator_shape()/get_indicator_color(), and every other getter a
## test reads are UNCHANGED in behaviour; only what _draw() renders from
## them changed.
const ARROW_LENGTH: float = 30.0
const ARROW_WIDTH: float = 22.0
const DIAMOND_HALF_EXTENT: float = 16.0 ## up from 10.0 -- "larger" applies to the low-health shape too
## The Tower icon's small badge, drawn inboard of the arrow/diamond (toward
## the screen centre) so it never crowds the literal screen edge.
const ICON_BADGE_RADIUS: float = 17.0
const ICON_SIZE: float = 20.0
const ICON_INSET: float = 34.0
## How far inboard of the indicator the HP readout label sits.
const HP_LABEL_INSET: float = 62.0
const HIT_ARC_RADIUS: float = 20.0 ## up from 14.0, matching the bigger indicator it now sits beside
const HIT_ARC_HALF_WIDTH: float = 0.4
const HIT_ARC_SEGMENTS: int = 12 ## up from 8, for a smoother stroke; the arc's angular SPAN (HIT_ARC_HALF_WIDTH) is unchanged
const HIT_ARC_LINE_WIDTH: float = 3.0
const OUTLINE_EXTRA_WIDTH: float = 2.0 ## how much wider the dark outline pass is drawn than the bright stroke it sits under

var _camera: GameCamera = null
var _tower: Tower = null
var _player: Player = null

## Test-injectable SimClock reference (this project's own convention, e.g.
## `tower_health.gd`'s `set_sim_clock_for_test()`); defaults to the real
## Autoload.
var _clock: Node = null

var _recent_damage: Array = [] # Array[Dictionary{amount: float, time: float}]
var _display_intensity: float = 0.0
var _last_intensity_update_sim_time: float = 0.0

var _has_attacker_position: bool = false
var _last_attacker_position: Vector2 = Vector2.ZERO
var _last_hit_sim_time: float = -INF

var _cue_player: TowerCuePlayer = null
var _ducking_node: AudioDucking = null
var _cue_stream: AudioStream = null

## Second UI pass: the off-screen indicator's HP readout (task instruction:
## "the tower icon and its HP"). A real child Label, not drawn text --
## `Label` already gives correct outline/legibility through `UiTheme`
## without reimplementing draw_string() layout. Positioned every frame in
## _update_tower_hp_label(), alongside the indicator it labels.
var _tower_hp_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_clock = SimClock
	_cue_stream = cue_stream if cue_stream != null else _build_placeholder_cue_stream()

	_cue_player = TowerCuePlayer.new()
	_cue_player.name = "TowerCuePlayer"
	add_child(_cue_player)

	_ducking_node = AudioDucking.new()
	_ducking_node.name = "AudioDucking"
	add_child(_ducking_node)
	_cue_player.ducking_node = _ducking_node

	# Second UI pass: theme assigned directly (not inherited) since this
	# CanvasLayer overlay sits outside the HUD's own themed Control tree --
	# matches HudTruncatableLabel's own established reason for the same
	# explicit assignment (its _make_custom_tooltip()'s header).
	_tower_hp_label = Label.new()
	_tower_hp_label.name = "TowerHpLabel"
	_tower_hp_label.theme = UiTheme.get_theme()
	_tower_hp_label.theme_type_variation = UiTheme.SMALL
	_tower_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tower_hp_label.visible = false
	add_child(_tower_hp_label)


func _process(_delta: float) -> void:
	recompute(_now())
	_update_tower_hp_label()
	queue_redraw()


func _now() -> float:
	return _clock.now if _clock != null else 0.0


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func set_camera_ref(camera: GameCamera) -> void:
	_camera = camera


func set_player_ref(player: Player) -> void:
	_player = player


## Typed command: wires this feedback to the Tower whose damage it reacts
## to, connecting directly to the Tower's own Hurtbox (see header, "The
## attacker-position seam").
func set_tower_ref(tower: Tower) -> void:
	if _tower != null and _tower.hurtbox != null and _tower.hurtbox.damage_received.is_connected(_on_tower_hurtbox_damage_received):
		_tower.hurtbox.damage_received.disconnect(_on_tower_hurtbox_damage_received)
	_tower = tower
	if _tower != null and _tower.hurtbox != null:
		_tower.hurtbox.damage_received.connect(_on_tower_hurtbox_damage_received)


## Typed command: replaces this feedback's own private AudioDucking node
## with a shared one. `_ready()` creates a private AudioDucking instance so
## the cue mechanism works standalone with no integration step; if a single
## global AudioDucking node is later established for the whole game (so
## AudioPool's own priority voices duck against the SAME node as this cue
## rather than a second, independent ramp), the integration task should
## call this instead of leaving the private default in place. Named as a
## cross-task seam in the P2.6 evidence report.
func set_ducking_node_ref(ducking: AudioDucking) -> void:
	if _ducking_node != null and _ducking_node.get_parent() == self:
		_ducking_node.queue_free()
	_ducking_node = ducking
	if _cue_player != null:
		_cue_player.ducking_node = ducking


func get_cue_player() -> TowerCuePlayer:
	return _cue_player


func get_ducking_node() -> AudioDucking:
	return _ducking_node


func get_cue_stream() -> AudioStream:
	return _cue_stream


func _on_tower_hurtbox_damage_received(amount: float, source: Variant, hitbox: Node) -> void:
	var now: float = _now()
	_recent_damage.append({"amount": amount, "time": now})
	if hitbox is Node2D:
		_last_attacker_position = (hitbox as Node2D).global_position
		_has_attacker_position = true
		_last_hit_sim_time = now
	elif source is Node2D:
		_last_attacker_position = (source as Node2D).global_position
		_has_attacker_position = true
		_last_hit_sim_time = now
	_play_tower_cue(now)


func _play_tower_cue(now_sim_time: float) -> void:
	if _cue_player == null or _tower == null or _player == null or _cue_stream == null:
		return
	_cue_player.play_tower_damage(_cue_stream, _tower.global_position.x, _player.global_position.x, now_sim_time * 1000.0)


## Recomputes the damage window and the displayed intensity against `now`.
## Public (not `_recompute`) so a test can drive it directly with a fresh,
## injected SimClock's `.now` instead of waiting on real `_process()` frames
## (matching this project's established "call the per-tick method directly"
## test convention, e.g. `player.gd`'s `physics_step()`).
func recompute(now: float) -> void:
	_prune_old_damage(now)
	_update_intensity(now)


func _prune_old_damage(now: float) -> void:
	var kept: Array = []
	for entry in _recent_damage:
		if now - float(entry["time"]) <= DAMAGE_WINDOW_SECONDS:
			kept.append(entry)
	_recent_damage = kept


func _update_intensity(now: float) -> void:
	var dt: float = maxf(0.0, now - _last_intensity_update_sim_time)
	_last_intensity_update_sim_time = now

	var windowed_sum: float = 0.0
	for entry in _recent_damage:
		windowed_sum += float(entry["amount"])

	var normalization: float = 1.0
	if _tower != null and _tower.health != null and _tower.health.max_health > 0.0:
		normalization = _tower.health.max_health * DAMAGE_TO_FULL_INTENSITY_FRACTION_OF_MAX_HEALTH

	var raw: float = 0.0
	if normalization > 0.0:
		raw = clampf(windowed_sum / normalization, 0.0, 1.0)

	if raw >= _display_intensity:
		_display_intensity = raw # rises immediately with fresh damage
	else:
		var max_drop: float = dt / FADE_SECONDS
		_display_intensity = maxf(raw, _display_intensity - max_drop)


func get_display_intensity() -> float:
	return _display_intensity


func get_recent_damage_count_for_test() -> int:
	return _recent_damage.size()


## True while the Tower's world position falls within the camera's current
## visible rectangle (`GameCamera.get_visible_world_size()`, already
## exposed by P2.2 for exactly this kind of consumer).
func is_tower_on_screen() -> bool:
	if _camera == null or _tower == null:
		return false
	var half_extent: Vector2 = _camera.get_visible_world_size() / 2.0
	var rel: Vector2 = _tower.global_position - _camera.global_position
	return absf(rel.x) <= half_extent.x and absf(rel.y) <= half_extent.y


## Register > Interfaces > "Threat feedback": "points at the Tower when
## off-screen, at the attacker when on-screen." Degrades to pointing at the
## Tower itself if it is on-screen but no attacker position has ever been
## recorded (or none is fresh) -- named interpretation, not an explicit
## rule, since the Register does not state a fallback for that case.
func get_pointing_direction() -> Vector2:
	if _camera == null or _tower == null:
		return Vector2.ZERO
	if not is_tower_on_screen():
		var to_tower: Vector2 = _tower.global_position - _camera.global_position
		return to_tower.normalized() if to_tower != Vector2.ZERO else Vector2.ZERO
	if _has_attacker_position:
		var to_attacker: Vector2 = _last_attacker_position - _camera.global_position
		if to_attacker != Vector2.ZERO:
			return to_attacker.normalized()
	return Vector2.ZERO


func get_active_segment_index() -> int:
	var dir: Vector2 = get_pointing_direction()
	if dir == Vector2.ZERO:
		return -1
	var angle: float = wrapf(dir.angle(), 0.0, TAU)
	return int(round(angle / SEGMENT_ANGLE)) % SEGMENT_COUNT


## The 8 discrete edge segments (Register: "vignette drawn as 8 edge
## segments"), each 0..1. Only the active segment and its two immediate
## neighbours (a small bleed, stylistic, no Register row) are ever
## non-zero.
func get_segment_intensities() -> Array:
	var result: Array = []
	result.resize(SEGMENT_COUNT)
	for i in range(SEGMENT_COUNT):
		result[i] = 0.0
	var active: int = get_active_segment_index()
	if active == -1 or _display_intensity <= 0.0:
		return result
	result[active] = _display_intensity
	result[(active + 1) % SEGMENT_COUNT] = _display_intensity * NEIGHBOR_BLEED_FRACTION
	result[(active - 1 + SEGMENT_COUNT) % SEGMENT_COUNT] = _display_intensity * NEIGHBOR_BLEED_FRACTION
	return result


func is_showing_offscreen_indicator() -> bool:
	return _tower != null and _camera != null and not is_tower_on_screen()


func is_indicator_low_health() -> bool:
	if _tower == null or _tower.health == null or _tower.health.max_health <= 0.0:
		return false
	return (_tower.health.get_current_health() / _tower.health.max_health) < LOW_HEALTH_FRACTION


## Register: "changes both shape and colour below 40% health" -- shape via
## this getter, colour via `get_indicator_color()` below, never colour
## alone (MASTER_SDLC.md > Visual Edge Cases > "Colour-only distinctions").
func get_indicator_shape() -> StringName:
	return &"warning_diamond" if is_indicator_low_health() else &"arrow"


func get_indicator_color() -> Color:
	return UiPalette.DANGER if is_indicator_low_health() else UiPalette.ACCENT


## Register: "shows a short arc on the side of the Tower currently being
## hit." True only while a recorded hit is still within its display window.
func has_recent_hit_arc() -> bool:
	return _has_attacker_position and (_now() - _last_hit_sim_time) <= HIT_ARC_DISPLAY_SECONDS


## Bearing of the last known attacker FROM THE TOWER'S OWN CENTRE (not from
## the camera/player) -- "the side of the Tower being hit" is a property of
## the Tower's own silhouette, matching the same quantity docs/20's Run
## Recorder already records as "source bearing from the Tower."
func get_hit_arc_bearing_from_tower() -> float:
	if _tower == null or not _has_attacker_position:
		return 0.0
	return (_last_attacker_position - _tower.global_position).angle()


func _draw() -> void:
	_draw_vignette_segments()
	if is_showing_offscreen_indicator():
		_draw_offscreen_indicator()


## UI pass round 2 (LEDGER UR-02): the point on this Control's own
## rectangle boundary reached by a ray from `center` at `angle` -- literally
## the screen edge, not a circle inset within it (see the header, "UI pass
## round 2," point 1).
func _rect_edge_point(center: Vector2, half_extent: Vector2, angle: float) -> Vector2:
	var dir := Vector2(cos(angle), sin(angle))
	var t: float = INF
	if absf(dir.x) > 0.0001:
		t = minf(t, half_extent.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		t = minf(t, half_extent.y / absf(dir.y))
	if not is_finite(t):
		t = 0.0
	return center + dir * t


## UI pass round 2 (LEDGER UR-02): smoothly interpolates between a wedge's
## own intensity and its neighbours' as `angle` moves across the circle, so
## the drawn vignette has no hard seam between segments (see the header,
## "UI pass round 2," point 3). Purely a drawing-time smoothing --
## `get_segment_intensities()` and `get_active_segment_index()` (the values
## and the index this samples) are untouched.
func _blended_intensity_at_angle(angle: float, intensities: Array) -> float:
	var normalized: float = wrapf(angle, 0.0, TAU)
	var raw_index: float = normalized / SEGMENT_ANGLE
	var i0: int = int(floor(raw_index)) % SEGMENT_COUNT
	var i1: int = (i0 + 1) % SEGMENT_COUNT
	var t: float = raw_index - floor(raw_index)
	return lerpf(float(intensities[i0]), float(intensities[i1]), t)


## UI pass round 2 (LEDGER UR-02): see the header, "UI pass round 2," for
## the full rationale. Draws each of the SEGMENT_COUNT wedges as an annulus
## segment whose outer boundary is the literal screen edge and whose alpha
## fades radially (per-vertex colours) from 0 at the inner boundary to the
## neighbour-blended intensity at the outer one -- SEGMENT_COUNT,
## `get_segment_intensities()`, `NEIGHBOR_BLEED_FRACTION`, and every
## timing/Register-cited value feeding them are untouched; this only
## changes how the same 8 values are drawn.
func _draw_vignette_segments() -> void:
	var box_size: Vector2 = size
	if box_size.x <= 0.0 or box_size.y <= 0.0:
		return
	var intensities: Array = get_segment_intensities()
	var has_any: bool = false
	for value in intensities:
		if float(value) > 0.0:
			has_any = true
			break
	if not has_any:
		return

	var center: Vector2 = box_size / 2.0
	var half_extent: Vector2 = box_size / 2.0
	var inner_radius: float = minf(box_size.x, box_size.y) * INNER_REACH_FRACTION

	for i in range(SEGMENT_COUNT):
		var mid_angle: float = i * SEGMENT_ANGLE
		var half: float = SEGMENT_ANGLE / 2.0
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		# Inner boundary, ascending angle, alpha 0 -- the screen centre stays
		# clear no matter how intense the hit.
		for s in range(SEGMENT_ARC_SUBDIVISIONS + 1):
			var t: float = float(s) / float(SEGMENT_ARC_SUBDIVISIONS)
			var a: float = lerp(mid_angle - half, mid_angle + half, t)
			var dir := Vector2(cos(a), sin(a))
			points.append(center + dir * inner_radius)
			colors.append(UiPalette.with_alpha(UiPalette.DANGER, 0.0))
		# Outer boundary (the screen edge itself), descending angle, alpha
		# from the neighbour-blended intensity at that angle.
		for s in range(SEGMENT_ARC_SUBDIVISIONS, -1, -1):
			var t: float = float(s) / float(SEGMENT_ARC_SUBDIVISIONS)
			var a: float = lerp(mid_angle - half, mid_angle + half, t)
			var blended: float = _blended_intensity_at_angle(a, intensities)
			points.append(_rect_edge_point(center, half_extent, a))
			colors.append(UiPalette.with_alpha(UiPalette.DANGER, clampf(blended, 0.0, 1.0) * VIGNETTE_PEAK_ALPHA))
		draw_polygon(points, colors)


func _draw_offscreen_indicator() -> void:
	var box_size: Vector2 = size
	if box_size.x <= 0.0 or box_size.y <= 0.0:
		return
	var dir: Vector2 = get_pointing_direction()
	if dir == Vector2.ZERO:
		return
	var center: Vector2 = box_size / 2.0
	var radius: Vector2 = box_size / 2.0 * 0.85
	var pos: Vector2 = center + Vector2(dir.x * radius.x, dir.y * radius.y)
	var color: Color = get_indicator_color()
	var outline_color: Color = UiPalette.TEXT_OUTLINE
	if is_indicator_low_health():
		# A slightly larger dark diamond drawn first, then the bright one on
		# top, gives the bright shape a dark rim -- legible over any
		# background, matching the arrow case below.
		draw_colored_polygon(_diamond_points(pos, DIAMOND_HALF_EXTENT + OUTLINE_EXTRA_WIDTH), outline_color)
		draw_colored_polygon(_diamond_points(pos, DIAMOND_HALF_EXTENT), color)
	else:
		# Second UI pass: a directional arrow, not a plain circle -- task
		# instruction: "larger arrow at the screen edge". Points along `dir`,
		# the exact same vector the vignette and the old circle already used.
		draw_colored_polygon(_arrow_points(pos, dir, ARROW_LENGTH + OUTLINE_EXTRA_WIDTH * 2.0, ARROW_WIDTH + OUTLINE_EXTRA_WIDTH * 2.0), outline_color)
		draw_colored_polygon(_arrow_points(pos, dir, ARROW_LENGTH, ARROW_WIDTH), color)
	# Second UI pass: the Tower icon, in a small dark badge so it reads
	# clearly over any background (task instruction: "with the tower icon").
	# Sits INBOARD of the arrow/diamond (toward the screen centre), never
	# past the screen edge.
	var icon_pos: Vector2 = pos - dir * ICON_INSET
	draw_circle(icon_pos, ICON_BADGE_RADIUS + 1.0, outline_color)
	draw_circle(icon_pos, ICON_BADGE_RADIUS, UiPalette.with_alpha(UiPalette.INK, 0.85))
	UiShapeGlyph.draw_shape(self, UiShapeGlyph.Shape.TOWER, Rect2(icon_pos - Vector2(ICON_SIZE, ICON_SIZE) * 0.5, Vector2(ICON_SIZE, ICON_SIZE)), color)
	if has_recent_hit_arc():
		var bearing: float = get_hit_arc_bearing_from_tower()
		draw_arc(pos, HIT_ARC_RADIUS, bearing - HIT_ARC_HALF_WIDTH, bearing + HIT_ARC_HALF_WIDTH, HIT_ARC_SEGMENTS, outline_color, HIT_ARC_LINE_WIDTH + OUTLINE_EXTRA_WIDTH)
		draw_arc(pos, HIT_ARC_RADIUS, bearing - HIT_ARC_HALF_WIDTH, bearing + HIT_ARC_HALF_WIDTH, HIT_ARC_SEGMENTS, UiPalette.with_alpha(UiPalette.TEXT, 0.9), HIT_ARC_LINE_WIDTH)


## Second UI pass: the arrow's three points, `length` long and `width` wide
## at its back edge, rotated to point along `dir` (a unit vector) from
## `pos`. `pos` is the SHAPE's own centre (matching _diamond_points()'s own
## convention), not its tip, so the arrow occupies the same footprint the
## old circle/diamond did.
func _arrow_points(pos: Vector2, dir: Vector2, length: float, width: float) -> PackedVector2Array:
	var forward: Vector2 = dir.normalized()
	var side: Vector2 = Vector2(-forward.y, forward.x)
	var tip: Vector2 = pos + forward * length * 0.5
	var back_center: Vector2 = pos - forward * length * 0.5
	var back_left: Vector2 = back_center + side * width * 0.5
	var back_right: Vector2 = back_center - side * width * 0.5
	return PackedVector2Array([tip, back_left, back_right])


## Second UI pass: positions and fills the Tower HP readout beside the
## off-screen indicator (task instruction: "its HP"). Recomputes the same
## `pos` _draw_offscreen_indicator() derives from get_pointing_direction()
## -- a small duplication, matching this project's own tolerance for it
## elsewhere (e.g. is_tower_on_screen()'s repeated half-extent check) rather
## than reworking the existing, already-tested draw method's own layout.
func _update_tower_hp_label() -> void:
	if _tower_hp_label == null:
		return
	if not is_showing_offscreen_indicator() or _tower == null or _tower.health == null or _tower.health.max_health <= 0.0:
		_tower_hp_label.visible = false
		return
	var box_size: Vector2 = size
	if box_size.x <= 0.0 or box_size.y <= 0.0:
		_tower_hp_label.visible = false
		return
	var dir: Vector2 = get_pointing_direction()
	if dir == Vector2.ZERO:
		_tower_hp_label.visible = false
		return
	_tower_hp_label.visible = true
	var current: float = _tower.health.get_current_health()
	var max_v: float = _tower.health.max_health
	_tower_hp_label.text = "%d/%d" % [int(round(current)), int(round(max_v))]
	_tower_hp_label.add_theme_color_override("font_color", get_indicator_color())
	var center: Vector2 = box_size / 2.0
	var radius: Vector2 = box_size / 2.0 * 0.85
	var pos: Vector2 = center + Vector2(dir.x * radius.x, dir.y * radius.y)
	var label_pos: Vector2 = pos - dir * HP_LABEL_INSET
	# This Label is a free child of a plain Control (no Container manages
	# it), so its own `size` never auto-updates from a text change --
	# get_combined_minimum_size() reads the font metrics directly and is
	# always current, unlike `size` itself.
	_tower_hp_label.size = _tower_hp_label.get_combined_minimum_size()
	_tower_hp_label.position = label_pos - _tower_hp_label.size * 0.5


## The low-health warning diamond's four points at the given half-extent
## (used both for the bright diamond and, at a larger extent, its dark
## outline -- see _draw_offscreen_indicator()).
func _diamond_points(pos: Vector2, half_extent: float) -> PackedVector2Array:
	return PackedVector2Array([pos + Vector2(0, -half_extent), pos + Vector2(half_extent, 0), pos + Vector2(0, half_extent), pos + Vector2(-half_extent, 0)])


## See header, "Placeholder cue audio". A short, procedurally generated,
## decaying low-frequency tone -- no audio asset of any kind exists in this
## repository yet.
func _build_placeholder_cue_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration_seconds := 0.18
	var frequency_hz := 220.0
	var sample_count := int(sample_rate * duration_seconds)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var envelope: float = 1.0 - (float(i) / float(sample_count))
		var sample: float = sin(TAU * frequency_hz * t) * envelope
		data[i] = int(clampf(sample * 100.0 + 128.0, 0.0, 255.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
