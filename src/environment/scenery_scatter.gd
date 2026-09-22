extends Node2D
class_name SceneryScatter

## Decorative scatter across the arena floor: rocks, bushes, plants and
## craters, placed deterministically from a keyed seed.
##
## WHY THIS EXISTS. The arena is 4800x3200 of flat ground. At the author's
## feel check the verdict named it directly ("use proper sceneery"): with a
## single tiled texture and nothing on it, the player has no fixed points to
## read motion against, so moving at 320 px/s across an empty plane looks
## almost static. Scatter gives parallax-free motion cues at ground level,
## which is the cheapest way to make speed legible in a top-down game.
##
## WHAT THIS IS NOT. These are **not** obstacles. MASTER_SDLC.md > Game
## Overview > Perspective and Arena specifies the prototype arena as having
## hard walls and **no interior obstacles**, and that is a gameplay rule
## about pathing and cover, not an art rule. Every node this creates is a
## bare Sprite2D with no collision shape, no physics body, and no
## EntityRegistry registration, so nothing can path around it, be blocked by
## it, or query it. It is paint on the floor.
##
## DRAW ORDER. Everything here sits at z_index 0, the environment band
## (MASTER_SDLC.md > Provisional Values Register > Interfaces >
## "Readability": environment 0, pickups 10, enemies 20, Tower 25 ...), so
## scatter can never draw over an entity. `z_as_relative` is set false for
## the same reason the projectile containers set it: z_index accumulates
## through relative CanvasItem ancestors, and this node is nested inside the
## arena inside the gameplay root (LEDGER: the P2.x integration finding).
##
## DETERMINISM. Placement comes from KeyedRng, not from randomize(), so the
## same seed lays out the same arena every run. That matters for the same
## reason spawn positions are keyed: a feel check, a bug report and a
## recorded run should all describe the same world.

## Arena size. MASTER_SDLC.md > Provisional Values Register > Arena & Camera
## > "Arena size" row (4800x3200), matching scenes/arena.tscn's own Floor
## region_rect rather than being independently chosen here.
@export var arena_size: Vector2 = Vector2(4800.0, 3200.0)

## Keep scatter off the walls. The arena's wall sprites are 64 px thick and
## their colliders sit flush; this inset keeps decoration from drawing
## half-under a wall.
@export var edge_inset_px: float = 96.0

## Keep scatter out of the Tower's working area. 160 px is the Tower's
## Interaction Radius (Register > Tower > "Tower footprint / Interaction
## Radius"), and the Console opens inside it, so decoration there would sit
## behind UI the player is trying to read. Doubled to leave visual room.
@export var tower_clear_radius_px: float = 320.0

## Tower centre. The camera and the prototype scene both place the Tower at
## the world origin; this is exported rather than assumed so the two move
## together if that ever changes (LEDGER F03-05 is exactly this seam).
@export var tower_center: Vector2 = Vector2.ZERO

## How many props to place. Not a gameplay number and not in the Register -
## it is a density choice for how the floor reads, tunable freely.
@export var prop_count: int = 220

## Seed parts, hashed by KeyedRng. Kept as a plain string so a caller can
## vary the layout per run by passing the run seed.
@export var seed_key: String = "arena_scatter"

@export var textures: Array[Texture2D] = []

## Per-prop scale jitter, so identical rocks do not read as a repeated
## stamp. Cosmetic only.
@export var min_scale: float = 0.7
@export var max_scale: float = 1.35

## Modulation toward the floor so scatter recedes rather than competing with
## entities for attention (Readability hierarchy: environment is the bottom
## band and degrades first).
@export var tint: Color = Color(1.0, 1.0, 1.0, 0.85)

var _placed: Array[Sprite2D] = []


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if textures.is_empty():
		push_warning("SceneryScatter has no textures assigned; the arena floor will be bare.")
		return
	_build()


## Public so a test can rebuild with a known seed and read the result back,
## rather than asserting against whatever _ready() happened to produce.
func build_for_test(count: int, key: String) -> void:
	prop_count = count
	seed_key = key
	_build()


func get_placed_count() -> int:
	return _placed.size()


func get_placed_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s in _placed:
		out.append(s.position)
	return out


func _clear() -> void:
	for s in _placed:
		if is_instance_valid(s):
			s.queue_free()
	_placed.clear()


func _build() -> void:
	_clear()
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "scatter", prop_count])
	var half: Vector2 = arena_size * 0.5
	var min_x: float = -half.x + edge_inset_px
	var max_x: float = half.x - edge_inset_px
	var min_y: float = -half.y + edge_inset_px
	var max_y: float = half.y - edge_inset_px
	var clear_sq: float = tower_clear_radius_px * tower_clear_radius_px

	var placed: int = 0
	var attempts: int = 0
	var attempt_cap: int = prop_count * 8 # bounded: a rejection loop must terminate
	while placed < prop_count and attempts < attempt_cap:
		attempts += 1
		var p: Vector2 = Vector2(
			rng.randf_range(min_x, max_x),
			rng.randf_range(min_y, max_y)
		)
		if p.distance_squared_to(tower_center) < clear_sq:
			continue # inside the Tower's working area; reject and retry
		var s: Sprite2D = Sprite2D.new()
		s.texture = textures[rng.randi_range(0, textures.size() - 1)]
		s.position = p
		s.scale = Vector2.ONE * rng.randf_range(min_scale, max_scale)
		s.rotation = rng.randf_range(0.0, TAU)
		s.modulate = tint
		s.z_index = 0
		s.z_as_relative = true # relative to this node, which is already absolute
		# Art pass (D102): pixel-art scenery must stay crisp regardless of
		# the project's own default canvas-item filter.
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		_placed.append(s)
		placed += 1
