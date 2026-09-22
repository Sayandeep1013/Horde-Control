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


## Art session: extended to also walk an AnimatedSprite2D's baked frames
## (the player's Visuals/Sprite2D is one now, driving assets/sprite_frames/
## player_archer.tres) -- CLAUDE.md: "if a test asserts on the old ...
## structure, update it minimally; do not weaken what it proves." The claim
## this suite makes ("a texture that loads but carries no pixels still gets
## caught") now covers every baked frame of every animation, not just a
## single Sprite2D.texture, which is a strictly WIDER check than before.
func test_each_entity_texture_actually_resolves_to_image_data() -> void:
	# A Sprite2D whose texture failed to load leaves `texture` null, which the
	# test above catches. This one catches the subtler case: a texture that
	# loads but carries no pixels, which would render nothing while looking
	# correctly wired in both the file and the inspector.
	#
	# Art session (D102 follow-up): the three enemies now render through an
	# AnimatedSprite2D (src/enemy/enemy_animator.gd), not a Sprite2D -- a
	# Shadow Sprite2D sibling still exists under each enemy's Visuals node,
	# so the original Sprite2D-only walk below would keep passing (the
	# shadow alone satisfies `checked > 0`) while silently no longer
	# checking the actual character art at all. Checking AnimatedSprite2D's
	# SpriteFrames explicitly, every frame of every animation, keeps this
	# test proving what it always proved.
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
			elif n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames != null:
				var frames: SpriteFrames = (n as AnimatedSprite2D).sprite_frames
				for anim_name in frames.get_animation_names():
					for idx in range(frames.get_frame_count(anim_name)):
						var frame_tex: Texture2D = frames.get_frame_texture(anim_name, idx)
						assert_object(frame_tex).append_failure_message(
							"%s > %s animation '%s' frame %d has a null texture" % [name, inst.get_path_to(n), anim_name, idx]
						).is_not_null()
						if frame_tex != null:
							assert_int(frame_tex.get_width()).append_failure_message(
								"%s > %s animation '%s' frame %d has a texture with zero width" % [name, inst.get_path_to(n), anim_name, idx]
							).is_greater(0)
							assert_int(frame_tex.get_height()).append_failure_message(
								"%s > %s animation '%s' frame %d has a texture with zero height" % [name, inst.get_path_to(n), anim_name, idx]
							).is_greater(0)
				checked += 1
			for c in n.get_children():
				stack.append(c)
		assert_int(checked).append_failure_message(
			"%s had no textured Sprite2D/AnimatedSprite2D to check" % name
		).is_greater(0)
		remove_child(inst)


func test_the_three_enemies_use_the_silhouette_distinct_unit_art() -> void:
	# LEDGER F03-21 and F03-31. The constraint is the master's: a Tower
	# Seeker, a Player Hunter and an Opportunist must stay distinguishable at
	# a glance under load, which means distinguishable by SHAPE, since
	# colour-only distinctions are banned outright (Visual Edge Cases >
	# "Colour-only distinctions").
	#
	# Art session (D102 follow-up): this used to pin each enemy's Sprite2D to
	# one of the generated placeholder PNGs. Those Sprite2D nodes are gone --
	# replaced by an AnimatedSprite2D per enemy (src/enemy/enemy_animator.gd)
	# driven by a SpriteFrames resource built from the Tiny Swords CC0 sheets
	# (tools/art/generate_enemy_sprite_frames.py) -- but the underlying
	# constraint this test exists to pin is unchanged and, if anything, more
	# clearly met: a torch-wielding goblin, a dynamite-throwing goblin and a
	# disguised barrel share no outline at all. This asserts each enemy's
	# AnimatedSprite2D resolves back to its OWN reserved sheet (unwrapping
	# the AtlasTexture frame to the sheet it was cropped from), so a later
	# asset sweep cannot quietly point two enemies at the same art, or drop
	# back to a shared generic sprite, with every other test still green.
	var expected: Dictionary = {
		"tower_seeker": "res://assets/third_party/tiny_swords/Factions/Goblins/Troops/Torch/Red/Torch_Red.png",
		"player_hunter": "res://assets/third_party/tiny_swords/Factions/Goblins/Troops/TNT/Yellow/TNT_Yellow.png",
		"opportunist": "res://assets/third_party/tiny_swords/Factions/Goblins/Troops/Barrel/Purple/Barrel_Purple.png",
	}
	for name in expected:
		var packed: PackedScene = load(ENTITY_SCENES[name]) as PackedScene
		var inst: Node = auto_free(packed.instantiate())
		add_child(inst)
		var paths: Array[String] = []
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames != null and not _is_telegraph(n):
				var frames: SpriteFrames = (n as AnimatedSprite2D).sprite_frames
				for anim in frames.get_animation_names():
					if frames.get_frame_count(anim) <= 0:
						continue
					var tex: Texture2D = frames.get_frame_texture(anim, 0)
					if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
						paths.append((tex as AtlasTexture).atlas.resource_path)
					elif tex != null:
						paths.append(tex.resource_path)
			for c in n.get_children():
				stack.append(c)
		assert_array(paths).append_failure_message(
			"%s must render the silhouette-distinct sheet %s (F03-21 and F03-31: shared/generic art "
			% [name, expected[name]]
			+ "fails the readability requirement). Rendered instead: %s" % [paths]
		).contains([expected[name]])
		remove_child(inst)


## An entity's art must be at least as big as the thing it collides with.
##
## Swapping the Tower's art from the 256x256 generated sprite to a 64x64
## Kenney tile without adding scale rendered the Tower at roughly a QUARTER
## of its own 212 px collision footprint: enemies walked up to a 212 px
## radius and attacked ground that looked empty, and the 160 px Interaction
## Radius was far larger than anything visible to stand next to. Every
## other test passed, because every other test asks whether a texture loads,
## not whether it covers the body it belongs to.
##
## The assertion is deliberately loose - rendered extent must be at least
## 80% of the collider's diameter, not equal to it - because the project's
## convention is that entity art OVERHANGS its collision circle (the
## generated art used ~2.3x for small entities). This catches an order-of-
## magnitude mismatch, which is the failure that actually happens on an
## asset swap, without pinning an art ratio that is a style choice.
func test_rendered_art_is_not_smaller_than_the_collider_it_belongs_to() -> void:
	for name in ENTITY_SCENES:
		var packed: PackedScene = load(ENTITY_SCENES[name]) as PackedScene
		var inst: Node = auto_free(packed.instantiate())
		add_child(inst)

		var biggest_radius: float = 0.0
		var widest_render: float = 0.0
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			# Only BODY colliders count. An Area2D radius is often deliberately
			# larger than the entity -- the Tower's 160 px Interaction Radius is
			# the trigger you stand inside, and the player's Collector and magnet
			# radii are the same idea -- so comparing art against those would
			# demand art far bigger than the thing itself. The first version of
			# this test did exactly that and measured the Tower against a 320 px
			# Interaction Radius, which happened to still catch the bug but for
			# the wrong reason and with almost no margin.
			if n is CollisionShape2D and n.get_parent() is PhysicsBody2D:
				var shape: Shape2D = (n as CollisionShape2D).shape
				if shape is CircleShape2D:
					biggest_radius = maxf(biggest_radius, (shape as CircleShape2D).radius)
			if n is Sprite2D and (n as Sprite2D).texture != null and not _is_telegraph(n):
				var s: Sprite2D = n as Sprite2D
				# Accumulate scale up to the scene root, since the scale that
				# fixed the Tower lives on a parent node, not on the sprite.
				var eff: float = float(s.texture.get_width())
				var walk: Node = s
				while walk != null and walk != inst.get_parent():
					if walk is Node2D:
						eff *= absf((walk as Node2D).scale.x)
					walk = walk.get_parent()
				widest_render = maxf(widest_render, eff)
			elif n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames != null and not _is_telegraph(n):
				# Art session: the player's Visuals/Sprite2D is now an
				# AnimatedSprite2D -- measured the same way, off its current
				# (autoplay) animation's first frame, scale-chained to the
				# scene root exactly like the Sprite2D branch above.
				var anim_sprite: AnimatedSprite2D = n as AnimatedSprite2D
				var frames: SpriteFrames = anim_sprite.sprite_frames
				var anim_name: StringName = anim_sprite.animation
				if not frames.has_animation(anim_name):
					var names: PackedStringArray = frames.get_animation_names()
					if names.size() > 0:
						anim_name = StringName(names[0])
				if frames.has_animation(anim_name) and frames.get_frame_count(anim_name) > 0:
					var frame_tex: Texture2D = frames.get_frame_texture(anim_name, 0)
					if frame_tex != null:
						var eff2: float = float(frame_tex.get_width())
						var walk2: Node = anim_sprite
						while walk2 != null and walk2 != inst.get_parent():
							if walk2 is Node2D:
								eff2 *= absf((walk2 as Node2D).scale.x)
							walk2 = walk2.get_parent()
						widest_render = maxf(widest_render, eff2)
			for c in n.get_children():
				stack.append(c)

		if biggest_radius <= 0.0:
			continue # no circular collider to compare against
		var diameter: float = biggest_radius * 2.0
		assert_float(widest_render).append_failure_message(
			"%s renders at %.0f px wide but collides as a circle %.0f px across. "
			% [name, widest_render, diameter]
			+ "Art smaller than its own collider means the entity is attacked, "
			+ "blocked and targeted well outside anything the player can see."
		).is_greater_equal(diameter * 0.8)
		remove_child(inst)
