extends Node2D
class_name ArenaShrine
## Shrine (Register "v1.0 Arena Interactables", docs/32 section B): a stone obelisk with a boon icon
## floating above it. Stand within the claim radius for the claim time in total
## (a progress ring fills; leaving pauses the fill but keeps it). It lasts a fixed
## time and blinks for the last 5 s. The boon is rolled by ArenaInteractables
## (keyed RNG) when the shrine spawns and applied on `claimed`.

signal claimed(shrine: ArenaShrine, boon_id: String)
signal expired(shrine: ArenaShrine)

const TEX: Texture2D = preload("res://assets/sprites/v1/shrine.png")

# Register "v1.0 Arena Interactables": Shrine
const SPRITE_SCALE: float = 1.5 # Register "v1.0 Arena Interactables": Shrine size
const CLAIM_RADIUS_PX: float = 78.0 # 52 px x 1.5
const CLAIM_SECONDS: float = 2.5
const LIFETIME_SECONDS: float = 25.0
const BLINK_SECONDS: float = 5.0
const ICON_FLOAT_PX: float = 156.0 # 104 px x 1.5
const PILLAR_HEIGHT_PX: float = 360.0 # idle pillar of light
const FADE_SECONDS: float = 0.5

var boon_id: String = ArenaBoon.WAR
var progress_seconds: float = 0.0
var is_claimed: bool = false
var is_expired: bool = false

var _spawned_at: float = 0.0
var _last_now: float = 0.0
var _ended_at: float = 0.0
var _sprite: Sprite2D = null
var _icon: Sprite2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"arena_shrine")
	_spawned_at = SimClock.now
	_last_now = _spawned_at
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -36)
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(_sprite)
	_icon = Sprite2D.new()
	_icon.texture = load(ArenaBoon.icon_path(boon_id)) as Texture2D
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.position = Vector2(0, -ICON_FLOAT_PX)
	_icon.scale = Vector2.ONE * SPRITE_SCALE
	add_child(_icon)


func time_left() -> float:
	return maxf(0.0, LIFETIME_SECONDS - (SimClock.now - _spawned_at))


func progress_fraction() -> float:
	return clampf(progress_seconds / CLAIM_SECONDS, 0.0, 1.0)


## Advances the fill by the SimClock time since the last call. Returns true on the tick it is claimed.
func check_player(player: Node2D) -> bool:
	var now: float = SimClock.now
	var dt: float = maxf(0.0, now - _last_now)
	_last_now = now
	if is_claimed or is_expired:
		return false
	if now - _spawned_at >= LIFETIME_SECONDS:
		is_expired = true
		_ended_at = now
		expired.emit(self)
		return false
	if player != null and player.global_position.distance_to(global_position) <= CLAIM_RADIUS_PX:
		progress_seconds += dt
		if progress_seconds >= CLAIM_SECONDS:
			progress_seconds = CLAIM_SECONDS
			is_claimed = true
			_ended_at = now
			CombatStats.add_run_counter("shrines_claimed")
			Sfx.play("shrine_claim", global_position)
			claimed.emit(self, boon_id)
			return true
	return false


func _process(_delta: float) -> void:
	var now: float = SimClock.now
	if is_claimed or is_expired:
		var t: float = (now - _ended_at) / FADE_SECONDS
		if t >= 1.0:
			queue_free()
			return
		modulate.a = 1.0 - t
		_icon.position.y = -ICON_FLOAT_PX - 24.0 * t
	else:
		_icon.position.y = -ICON_FLOAT_PX + 5.0 * sin(now * 2.6)
		var left: float = LIFETIME_SECONDS - (now - _spawned_at)
		if left < BLINK_SECONDS:
			var on: bool = int(now * 6.0) % 2 == 0
			modulate.a = 1.0 if on else 0.35
	queue_redraw()


## Ground ring: faint claim radius while waiting, gold fill arc as the claim progresses.
func _draw() -> void:
	if is_claimed or is_expired:
		return
	_draw_pillar()
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.55))
	# Dark underline then a bright ring, so it reads on sand and on grass.
	draw_arc(Vector2.ZERO, CLAIM_RADIUS_PX, 0.0, TAU, 40, Color(0.09, 0.11, 0.18, 0.7), 5.0, false)
	draw_arc(Vector2.ZERO, CLAIM_RADIUS_PX, 0.0, TAU, 40, Color(0.7, 0.95, 1.0, 0.95), 2.5, false)
	var f: float = progress_fraction()
	if f > 0.0:
		draw_arc(Vector2.ZERO, CLAIM_RADIUS_PX, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(1.0, 0.85, 0.3, 1.0), 5.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Idle pillar of light (docs/33 B5): a column that fades out upward, breathing slowly, with a few
## motes rising through it, so an unclaimed Shrine reads from across the arena. Pure SimClock draw.
func _draw_pillar() -> void:
	var now: float = SimClock.now
	var breathe: float = 0.75 + 0.25 * sin(now * 2.2)
	var tint: Color = Color(0.6, 0.92, 1.0)
	var bands: int = 12
	for i in bands:
		var t0: float = float(i) / float(bands)
		var y0: float = -t0 * PILLAR_HEIGHT_PX
		var half_w: float = lerpf(34.0, 14.0, t0) * SPRITE_SCALE * 0.75
		var a: float = (1.0 - t0) * 0.30 * breathe
		draw_rect(Rect2(-half_w, y0 - PILLAR_HEIGHT_PX / float(bands), half_w * 2.0, PILLAR_HEIGHT_PX / float(bands) + 1.0), Color(tint.r, tint.g, tint.b, a))
	# A brighter core.
	for i in bands:
		var t0: float = float(i) / float(bands)
		var half_w: float = lerpf(12.0, 5.0, t0) * SPRITE_SCALE * 0.75
		draw_rect(Rect2(-half_w, -(t0 + 1.0 / float(bands)) * PILLAR_HEIGHT_PX, half_w * 2.0, PILLAR_HEIGHT_PX / float(bands) + 1.0), Color(1.0, 1.0, 1.0, (1.0 - t0) * 0.35 * breathe))
	# Motes rising through the column.
	for k in 6:
		var phase: float = fmod(now * 0.45 + float(k) * 0.37, 1.0)
		var x: float = sin(float(k) * 2.3 + now * 0.9) * 14.0
		var y: float = -phase * PILLAR_HEIGHT_PX
		draw_rect(Rect2(x - 2.0, y - 2.0, 4.0, 4.0), Color(1.0, 1.0, 0.9, (1.0 - phase) * 0.9))
