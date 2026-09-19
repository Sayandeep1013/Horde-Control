extends GdUnitTestSuite

## Every playable entity must actually RENDER something.
##
## This suite exists because of a defect that reached the assembled
## prototype scene with 353 other tests green: the three enemy scenes
## carried a telegraph visual, a hurtbox, a hitbox and a death state, but
## **no sprite node at all**. All three enemies were invisible. The
## generated enemy art existed on disk the whole time and was referenced by
## exactly one file -- tests/unit/player_silhouette_test.gd -- which loads
## the PNGs directly off disk to compare their shapes and therefore passed
## while nothing in any scene rendered them. Recorded as LEDGER F03-27.
##
## The integration suite could not catch it either, for a reason worth
## stating plainly: it asserts that every texture a scene REFERENCES
## resolves to a non-null resource. A texture that is never referenced at
## all is invisible to that check. "No broken paths" and "something is
## drawn" are different claims, and only the first one was being made.
##
## So this suite asserts the second claim directly, for every entity scene,
## by walking the instantiated tree for a CanvasItem that would actually
## put pixels on screen. It is deliberately written against the scene as
## instantiated rather than against the .tscn text, because a sprite whose
## texture fails to load still appears in the file.
##
## Draw order (MASTER_SDLC.md > Provisional Values Register > Interfaces >
## "Readability") is checked here only where the entity itself owns it. The
## enemies deliberately carry no z_index: their `Entities` container
## supplies z_index 20 and the Y-sort group (docs/20 > Scene Tree), so
## asserting a z_index on the enemy scene in isolation would assert the
## wrong thing. tests/unit/prototype_scene_test.gd covers the assembled
## draw order.

const ENTITY_SCENES: Dictionary = {
	"player": "res://scenes/player.tscn",
	"tower": "res://scenes/tower.tscn",
	"tower_seeker": "res://scenes/entities/tower_seeker.tscn",
	"player_hunter": "res://scenes/entities/player_hunter.tscn",
	"opportunist": "res://scenes/entities/opportunist.tscn",
}


## Collects every node that would draw a texture: a Sprite2D with a texture,
## or an AnimatedSprite2D with sprite_frames. Returns them with their paths
## so a failure message can say where it looked.
##
## Telegraph subtrees are skipped, and that exclusion is the point rather
## than a detail. The first version of this suite did not skip them and
## PASSED against the very defect it was written to catch: TelegraphVisual
## builds a Sprite2D child at runtime, so an enemy with no body sprite still
## had "a node that draws a texture" and the assertion was satisfied by the
## attack telegraph alone. Found by mutating a real scene rather than by
## reading the test. A telegraph is drawn only during an attack wind-up; an
## entity whose only visual is its telegraph is invisible for almost all of
## its life, which is exactly the failure this suite exists to prevent.
func _drawing_nodes(root: Node, skip_telegraphs: bool = true) -> Array[String]:
	var found: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if skip_telegraphs and _is_telegraph(n):
			continue # do not descend: its runtime Sprite2D child does not count
		if n is Sprite2D and (n as Sprite2D).texture != null:
			found.append(root.get_path_to(n))
		elif n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames != null:
			found.append(root.get_path_to(n))
		for c in n.get_children():
			stack.append(c)
	return found


func _is_telegraph(n: Node) -> bool:
	var s: Script = n.get_script() as Script
	if s != null and s.resource_path.ends_with("telegraph_visual.gd"):
		return true
	return n.name == &"TelegraphVisual"


func test_every_entity_scene_renders_at_least_one_texture() -> void:
	for name in ENTITY_SCENES:
		var path: String = ENTITY_SCENES[name]
		var packed: PackedScene = load(path) as PackedScene
		assert_object(packed).append_failure_message(
			"%s did not load as a PackedScene" % path
		).is_not_null()
		var inst: Node = auto_free(packed.instantiate())
		add_child(inst)
		var drawn: Array[String] = _drawing_nodes(inst)
		assert_array(drawn).append_failure_message(
			"%s ('%s') instantiates with NO node that draws a texture. " % [path, name]
			+ "An entity with no Sprite2D is invisible in the running game, and no "
			+ "amount of correct collision, AI or audio wiring makes it visible. "
			+ "This is the exact defect F03-27 records."
		).is_not_empty()
		remove_child(inst)


func test_each_entity_texture_actually_resolves_to_image_data() -> void:
	# A Sprite2D whose texture failed to load leaves `texture` null, which the
	# test above catches. This one catches the subtler case: a texture that
	# loads but carries no pixels, which would render nothing while looking
	# correctly wired in both the file and the inspector.
	for name in ENTITY_SCENES:
		var packed: PackedScene = load(ENTITY_SCENES[name]) as PackedScene
		var inst: Node = auto_free(packed.instantiate())
		add_child(inst)
		var stack: Array[Node] = [inst]
		var checked: int = 0
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Sprite2D and (n as Sprite2D).texture != null:
				var tex: Texture2D = (n as Sprite2D).texture
				assert_int(tex.get_width()).append_failure_message(
					"%s > %s has a texture with zero width" % [name, inst.get_path_to(n)]
				).is_greater(0)
				assert_int(tex.get_height()).append_failure_message(
					"%s > %s has a texture with zero height" % [name, inst.get_path_to(n)]
				).is_greater(0)
				checked += 1
			for c in n.get_children():
				stack.append(c)
		assert_int(checked).append_failure_message(
			"%s had no textured Sprite2D to check" % name
		).is_greater(0)
		remove_child(inst)


func test_the_three_enemies_use_the_generated_art_not_a_stock_pack() -> void:
	# LEDGER F03-21: Kenney's top-down character sprites are all the same
	# human-from-above oval and fail this project's silhouette requirement,
	# so the four combat entities keep the generated art (docs/25 > "What the
	# third-party assets do and do not cover"). This asserts that decision is
	# still true in the scenes, so a later asset sweep cannot quietly undo it
	# and leave the silhouette requirement unmet with every test still green.
	var expected: Dictionary = {
		"tower_seeker": "res://assets/sprites/enemy_tower_seeker.png",
		"player_hunter": "res://assets/sprites/enemy_player_hunter.png",
		"opportunist": "res://assets/sprites/enemy_opportunist.png",
	}
	for name in expected:
		var packed: PackedScene = load(ENTITY_SCENES[name]) as PackedScene
		var inst: Node = auto_free(packed.instantiate())
		add_child(inst)
		var paths: Array[String] = []
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Sprite2D and (n as Sprite2D).texture != null:
				paths.append((n as Sprite2D).texture.resource_path)
			for c in n.get_children():
				stack.append(c)
		assert_array(paths).append_failure_message(
			"%s must render the generated sprite %s (F03-21: the stock top-down "
			% [name, expected[name]]
			+ "character packs fail the silhouette requirement). Rendered instead: %s" % [paths]
		).contains([expected[name]])
		remove_child(inst)
