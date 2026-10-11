extends Sprite2D
class_name ExplosionFx
## v1.0 shared explosion visual (WP0, decision D179; docs/31 §9). Visual only:
## no collision, no damage, nothing gameplay reads. Damage is the caller's
## job (player abilities hit enemies, enemy bombs hit the player and Tower).
##
## Plays the Tiny Swords `Effects/Explosion/Explosions.png` strip (9 frames of
## 192 px, CC0, provenance in assets/third_party/tiny_swords/PROVENANCE.md),
## scaled so the visible blast roughly matches the gameplay radius.
## PROCESS_MODE_PAUSABLE so an explosion freezes with the tree.

const SHEET: Texture2D = preload("res://assets/third_party/tiny_swords/Effects/Explosion/Explosions.png")
const FRAME_COUNT: int = 9
const FPS: float = 18.0
## The visible fireball fills about 150 of the 192 px frame at its widest.
const VISIBLE_DIAMETER_PX: float = 150.0
## Above telegraph rings (40), below damage numbers (60); absolute.
const FX_Z_INDEX: int = 45

var _t: float = 0.0


## Adds an explosion at `world_position` under `parent` (normally the arena's
## Entities/FX container) and returns it. `radius` is the gameplay radius.
static func spawn(parent: Node, world_position: Vector2, radius: float) -> ExplosionFx:
	var fx := ExplosionFx.new()
	parent.add_child(fx)
	fx.global_position = world_position
	var s: float = maxf(0.25, (radius * 2.0) / VISIBLE_DIAMETER_PX)
	fx.scale = Vector2(s, s)
	return fx


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture = SHEET
	hframes = FRAME_COUNT
	frame = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	z_index = FX_Z_INDEX


func _process(delta: float) -> void:
	_t += delta
	var f: int = int(_t * FPS)
	if f >= FRAME_COUNT:
		queue_free()
		return
	frame = f
