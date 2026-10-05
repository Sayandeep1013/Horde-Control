extends Node2D
class_name TelegraphVisual

## TelegraphVisual (integration task). Wires
## `assets/ui/telegraph_exclaim.png` (a project-made red "!" glyph, D142; it replaced the
## Kenney diamond because a rhombus now means XP crystal only) (docs/25_
## Asset_Pipeline.md) into the three enemy scenes, showing a sprite while
## the attached EnemyController's attack wind-up is active.
##
## Purely cosmetic and read-only, matching src/tower/tower_visuals.gd's own
## established pattern for this project: it only POLLS `EnemyController.
## is_windup_active()` (an existing public typed query -- never a private
## field) and toggles its own `visible`/`modulate`, and never mutates
## gameplay state. `src/enemy/enemy_controller.gd` is not on this
## integration task's do-not-touch list, but this component deliberately
## does not require any change to it: `is_windup_active()` already existed
## before this task, built by P2.5 for its own test seam
## (`is_windup_active_for_test`-style convention), and is reused here
## rather than adding a new signal for a component this project's own
## `TowerVisuals` already shows can be built as a pure poller.
##
## ## Draw order: telegraphs 40 (docs/20 > Scene Tree draw order), absolute
## This node is a child of the enemy body, which itself sits inside
## `Entities` (z_index 20, y_sort_enabled) once the prototype scene wires
## it in -- `z_as_relative` accumulates THROUGH every CanvasItem ancestor
## whose own `z_as_relative` is true (Godot's own documented rule), so a
## plain relative `z_index = 40` here would render at 20 (Entities) + 0
## (the enemy body, which sets no z_index of its own) + 40 = 60, the
## damage-number band, not the telegraph band. Setting `z_as_relative =
## false` makes this node's `z_index` an ABSOLUTE value (40) regardless of
## how deep its ancestor chain is or what z_index those ancestors carry --
## the same fix this integration task applied to scenes/player.tscn's and
## scenes/tower.tscn's own `Projectiles` containers, named in the
## integration evidence report as a real defect this task found by
## actually nesting entities the way the prototype scene requires.
const TELEGRAPH_Z_INDEX: int = 40

## Art session follow-up (cosmetic only): the wind-up reads as a pulsing
## warning marker above the head plus a ground ring under the feet that
## fills as the strike approaches, instead of a bare diamond on the body
## (which, drawn over the Tower, looked like red boxes stuck to it).
const MARKER_HEIGHT_PX: float = 104.0
## Art-consistency pass (D161): the "!" and the ground ring are pixel art
## drawn at native size (scale 1.0). The marker pulses by modulate (alpha),
## never by scale, so its pixels never resample; the ring is a 6-frame sheet
## whose frame follows the wind-up progress.
const MARKER_PULSE_HZ: float = 6.0
const MARKER_PULSE_ALPHA: float = 0.25
const RING_FRAMES: int = 6
const RING_FRAME_SIZE: Vector2i = Vector2i(64, 32)
const RING_TEXTURE: Texture2D = preload("res://assets/ui/telegraph_ring.png")
## UX review item 5 (D131): every telegraph, whatever the enemy, uses ONE
## danger colour; enemy identity stays in the sprite. The ground disc grows
## from nothing to the full ring as the wind-up reaches the strike moment.
const DANGER_COLOUR: Color = UiPalette.DANGER

## Integration task, docs/25_Asset_Pipeline.md: assigned in each of
## scenes/entities/{tower_seeker,player_hunter,opportunist}.tscn -- never a
## hardcoded path in this script's logic (D99).
@export var texture: Texture2D

## Defaults to the parent node (the enemy's own CharacterBody2D root),
## matching this project's `origin_path`/NodePath("..") convention.
@export var controller_path: NodePath = NodePath("..")

var _controller: EnemyController = null
var _sprite: Sprite2D = null
var _ring: Sprite2D = null
var _ring_atlas: AtlasTexture = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE # pauses with the enemy it decorates; a paused wind-up has nothing new to show anyway
	z_index = TELEGRAPH_Z_INDEX
	z_as_relative = false # see header, "Draw order"

	_controller = get_node_or_null(controller_path) as EnemyController

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.texture = texture
	_sprite.modulate = DANGER_COLOUR
	_sprite.position = Vector2(0.0, -MARKER_HEIGHT_PX)
	_sprite.scale = Vector2.ONE
	add_child(_sprite)

	_ring_atlas = AtlasTexture.new()
	_ring_atlas.atlas = RING_TEXTURE
	_ring_atlas.region = Rect2(Vector2.ZERO, Vector2(RING_FRAME_SIZE))
	_ring = Sprite2D.new()
	_ring.name = "Ring"
	_ring.texture = _ring_atlas
	_ring.modulate = DANGER_COLOUR
	_ring.show_behind_parent = true
	add_child(_ring)

	visible = false


# Driven in physics ticks (not _process) so the pulse stays inside the interpolated
# transform of the enemy it decorates (physics interpolation, feel pass D151).
func _physics_process(_delta: float) -> void:
	var active: bool = _controller != null and _controller.is_windup_active()
	visible = active
	if active:
		var pulse: float = 1.0 - MARKER_PULSE_ALPHA * (0.5 + 0.5 * sin(SimClock.now * TAU * MARKER_PULSE_HZ))
		_sprite.modulate = Color(DANGER_COLOUR, pulse)
		var progress: float = _controller.get_windup_progress()
		var frame: int = clampi(int(round(progress * float(RING_FRAMES - 1))), 0, RING_FRAMES - 1)
		_ring_atlas.region = Rect2(Vector2(frame * RING_FRAME_SIZE.x, 0), Vector2(RING_FRAME_SIZE))


func get_sprite_for_test() -> Sprite2D:
	return _sprite


func set_controller_for_test(controller: EnemyController) -> void:
	_controller = controller
