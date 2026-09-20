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
## normal (not-low-health) indicator uses `UiPalette.ACCENT`, and every
## bright stroke (the indicator's rim, the hit arc) is drawn over a wider,
## darker `UiPalette.TEXT_OUTLINE` pass first, so it stays legible against
## any background colour underneath. `get_indicator_shape()`/
## `get_indicator_color()`'s call sites and branching are unchanged; only
## the two literal `Color(...)` values `get_indicator_color()` returns
## change (confirmed against tests/unit/threat_feedback_indicator_test.gd
## first: it only asserts the two colours DIFFER from each other, never
## their exact values). The vignette wedges gain a few extra vertices along
## their inner/outer arcs (SEGMENT_ARC_SUBDIVISIONS) so the edge follows a
## curve instead of a straight chord -- SEGMENT_COUNT (8 discrete wedges,
## Register-cited) and every intensity/timing value feeding them are
## unchanged; this only smooths how each wedge's own boundary is drawn.

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
const SEGMENT_ARC_SUBDIVISIONS: int = 6 ## smooths each wedge's arc edges; SEGMENT_COUNT (the number of wedges) is unchanged
const INDICATOR_RADIUS: float = 8.0 ## unchanged from the pre-pass circle radius
const DIAMOND_HALF_EXTENT: float = 10.0 ## unchanged from the pre-pass diamond half-extent
const HIT_ARC_RADIUS: float = 14.0
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


func _process(_delta: float) -> void:
	recompute(_now())
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
	return &"warning_diamond" if is_indicator_low_health() else &"pip_circle"


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


## Cosmetic-only (UI pass): builds the points of an elliptical arc from
## `angle_from` to `angle_to`, subdivided into `subdivisions` segments, so a
## wedge's boundary can follow a curve instead of a single straight chord.
## Used only by `_draw_vignette_segments()` -- SEGMENT_COUNT (how many
## wedges exist) and every intensity feeding them are untouched.
func _arc_points(center: Vector2, radius: Vector2, angle_from: float, angle_to: float, subdivisions: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(subdivisions + 1):
		var t: float = float(i) / float(subdivisions)
		var a: float = lerp(angle_from, angle_to, t)
		var dir := Vector2(cos(a), sin(a))
		pts.append(center + Vector2(dir.x * radius.x, dir.y * radius.y))
	return pts


func _draw_vignette_segments() -> void:
	var box_size: Vector2 = size
	if box_size.x <= 0.0 or box_size.y <= 0.0:
		return
	var intensities: Array = get_segment_intensities()
	var center: Vector2 = box_size / 2.0
	var outer: Vector2 = box_size / 2.0
	const INNER_SCALE: float = 0.55
	for i in range(SEGMENT_COUNT):
		var alpha: float = intensities[i]
		if alpha <= 0.0:
			continue
		var mid_angle: float = i * SEGMENT_ANGLE
		var half: float = SEGMENT_ANGLE / 2.0
		# Inner boundary ascending, outer boundary descending, so the two
		# arcs concatenate into one closed, non-self-intersecting loop (an
		# annulus-segment wedge) -- same winding the pre-pass 4-point quad
		# used, just with more vertices per arc so each edge curves.
		var points := PackedVector2Array()
		points.append_array(_arc_points(center, outer * INNER_SCALE, mid_angle - half, mid_angle + half, SEGMENT_ARC_SUBDIVISIONS))
		points.append_array(_arc_points(center, outer, mid_angle + half, mid_angle - half, SEGMENT_ARC_SUBDIVISIONS))
		var color := UiPalette.with_alpha(UiPalette.DANGER, clampf(alpha, 0.0, 1.0) * 0.55)
		draw_colored_polygon(points, color)
		# A thin, consistent-weight dark outline under the bright fill, so
		# the wedge's edge reads against any background colour behind it.
		var outline_points := points.duplicate()
		outline_points.append(points[0])
		draw_polyline(outline_points, UiPalette.with_alpha(UiPalette.TEXT_OUTLINE, clampf(alpha, 0.0, 1.0)), 1.5, true)


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
		# background, matching the circle case below.
		draw_colored_polygon(_diamond_points(pos, DIAMOND_HALF_EXTENT + OUTLINE_EXTRA_WIDTH), outline_color)
		draw_colored_polygon(_diamond_points(pos, DIAMOND_HALF_EXTENT), color)
	else:
		draw_circle(pos, INDICATOR_RADIUS + OUTLINE_EXTRA_WIDTH, outline_color)
		draw_circle(pos, INDICATOR_RADIUS, color)
	if has_recent_hit_arc():
		var bearing: float = get_hit_arc_bearing_from_tower()
		draw_arc(pos, HIT_ARC_RADIUS, bearing - HIT_ARC_HALF_WIDTH, bearing + HIT_ARC_HALF_WIDTH, HIT_ARC_SEGMENTS, outline_color, HIT_ARC_LINE_WIDTH + OUTLINE_EXTRA_WIDTH)
		draw_arc(pos, HIT_ARC_RADIUS, bearing - HIT_ARC_HALF_WIDTH, bearing + HIT_ARC_HALF_WIDTH, HIT_ARC_SEGMENTS, UiPalette.with_alpha(UiPalette.TEXT, 0.9), HIT_ARC_LINE_WIDTH)


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
