extends Node2D
class_name TelegraphVisual

## TelegraphVisual (integration task). Wires
## `assets/third_party/kenney/telegraphs/telegraph_diamond.png` (docs/25_
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
const MARKER_SCALE: float = 0.55
const MARKER_PULSE_HZ: float = 6.0
const MARKER_PULSE_AMOUNT: float = 0.18
const GROUND_RING_RADIUS_PX: float = 26.0
const GROUND_RING_SQUASH: float = 0.5

## Integration task, docs/25_Asset_Pipeline.md: assigned in each of
## scenes/entities/{tower_seeker,player_hunter,opportunist}.tscn -- never a
## hardcoded path in this script's logic (D99).
@export var texture: Texture2D

## Defaults to the parent node (the enemy's own CharacterBody2D root),
## matching this project's `origin_path`/NodePath("..") convention.
@export var controller_path: NodePath = NodePath("..")

var _controller: EnemyController = null
var _sprite: Sprite2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE # pauses with the enemy it decorates; a paused wind-up has nothing new to show anyway
	z_index = TELEGRAPH_Z_INDEX
	z_as_relative = false # see header, "Draw order"

	_controller = get_node_or_null(controller_path) as EnemyController

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.texture = texture
	if _controller != null and _controller.definition != null and _controller.definition.telegraph_data != null:
		_sprite.modulate = _controller.definition.telegraph_data.telegraph_colour
	_sprite.position = Vector2(0.0, -MARKER_HEIGHT_PX)
	_sprite.scale = Vector2.ONE * MARKER_SCALE
	add_child(_sprite)

	visible = false


func _process(_delta: float) -> void:
	var active: bool = _controller != null and _controller.is_windup_active()
	visible = active
	if active:
		var pulse: float = 1.0 + MARKER_PULSE_AMOUNT * sin(SimClock.now * TAU * MARKER_PULSE_HZ)
		_sprite.scale = Vector2.ONE * MARKER_SCALE * pulse
		queue_redraw()


func _draw() -> void:
	var colour: Color = _sprite.modulate if _sprite != null else Color(1, 0.2, 0.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, GROUND_RING_SQUASH))
	draw_circle(Vector2.ZERO, GROUND_RING_RADIUS_PX, Color(colour, 0.28))
	draw_arc(Vector2.ZERO, GROUND_RING_RADIUS_PX, 0.0, TAU, 32, Color(colour, 0.9), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func get_sprite_for_test() -> Sprite2D:
	return _sprite


func set_controller_for_test(controller: EnemyController) -> void:
	_controller = controller
