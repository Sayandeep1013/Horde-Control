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
const CLAIM_RADIUS_PX: float = 52.0
const CLAIM_SECONDS: float = 2.5
const LIFETIME_SECONDS: float = 25.0
const BLINK_SECONDS: float = 5.0
const ICON_FLOAT_PX: float = 104.0
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
	add_child(_sprite)
	_icon = Sprite2D.new()
	_icon.texture = load(ArenaBoon.icon_path(boon_id)) as Texture2D
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.position = Vector2(0, -ICON_FLOAT_PX)
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
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.55))
	# Dark underline then a bright ring, so it reads on sand and on grass.
	draw_arc(Vector2.ZERO, CLAIM_RADIUS_PX, 0.0, TAU, 40, Color(0.09, 0.11, 0.18, 0.7), 5.0, false)
	draw_arc(Vector2.ZERO, CLAIM_RADIUS_PX, 0.0, TAU, 40, Color(0.7, 0.95, 1.0, 0.95), 2.5, false)
	var f: float = progress_fraction()
	if f > 0.0:
		draw_arc(Vector2.ZERO, CLAIM_RADIUS_PX, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(1.0, 0.85, 0.3, 1.0), 5.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
