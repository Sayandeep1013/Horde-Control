extends GdUnitTestSuite

## Player silhouette test (P2.1; MASTER_SDLC.md > Acceptance Test Matrix >
## Readability Tests > "Player silhouette test"; PLAN.md P2.1 row: "P2.1
## render-order result (player above enemies when surrounded)" -- this is
## how PLAN.md itself scopes the test for THIS task specifically, distinct
## from the full tester-probe silhouette-distinguishability check the
## Acceptance Test Matrix runs later with human testers (P2.16)).
##
## Two things checked here:
##  1. The render-order claim itself (docs/20 > Scene Tree: "a fixed
##     z_index keeps the player drawn above every enemy regardless of foot
##     position"), simulated concretely: enemies placed both above and
##     below the player's Y position inside a Y-sort-enabled container (the
##     literal "surrounded" case), the player kept OUTSIDE that container as
##     a sibling (matching "the player is not a child of Entities and is
##     not part of that Y-sort group"), and z_index compared numerically --
##     Godot's canvas draw order is z_index-primary, so this numeric
##     relationship is what actually guarantees the visual claim.
##  2. assets/sprites/player_silhouette.png (decision D99;
##     tools/art/generate_sprites.py --silhouette) exists, is not blank, and
##     is shape-distinct from the three enemy silhouettes the generator's
##     own header lists as needing to stay "tellable apart at a glance"
##     (player: "circle with shoulders, upright"; Tower Seeker: "broad blunt
##     wedge"; Player Hunter: "narrow sharp arrowhead"; Opportunist: "round
##     blob with trailing tendrils") -- a coarse 8x8 alpha-grid distance
##     check, not a full human-tester probe, but a real falsifiable
##     assertion rather than only "the file exists."

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

# These point at the sprites the SCENES ACTUALLY RENDER, and the silhouette
# is derived from each one's own alpha channel by _alpha_grid() rather than
# read from a separate pre-rendered *_silhouette.png.
#
# That indirection is deliberate. This suite previously compared a set of
# generated *_silhouette.png files, and when the entity art was replaced
# (F03-31) those files stayed on disk unchanged -- so this named acceptance
# test would have kept passing while comparing the silhouettes of sprites
# the game no longer draws. A test that cannot notice the thing it guards
# was swapped out is the same failure class as F03-27, where art existed on
# disk that nothing rendered. Deriving the silhouette from the rendered
# sprite's own alpha makes that divergence impossible by construction.
const PLAYER_SPRITE_PATH: String = "res://assets/third_party/kenney/entities/player.png"
const PLAYER_SILHOUETTE_PATH: String = PLAYER_SPRITE_PATH

## Art session (D102 follow-up): the three enemies used to render a single
## standalone PNG each, so `path` alone was a complete silhouette. They now
## render an AnimatedSprite2D whose SpriteFrames crop frames out of a shared
## Tiny Swords sheet (tools/art/generate_enemy_sprite_frames.py) -- alpha-
## gridding the WHOLE sheet would average dozens of unrelated frames into
## noise, not a silhouette. `region` picks one representative frame (each
## enemy's own idle/disguise pose, frame 0) out of that sheet instead, which
## `_load_image()` below now crops to before building the alpha grid.
const ENEMY_SILHOUETTES: Dictionary = {
	"tower_seeker": {"path": "res://assets/third_party/tiny_swords/Factions/Goblins/Troops/Torch/Red/Torch_Red.png", "region": Rect2i(0, 0, 192, 192)},
	"player_hunter": {"path": "res://assets/third_party/tiny_swords/Factions/Goblins/Troops/TNT/Yellow/TNT_Yellow.png", "region": Rect2i(0, 0, 192, 192)},
	"opportunist": {"path": "res://assets/third_party/tiny_swords/Factions/Goblins/Troops/Barrel/Purple/Barrel_Purple.png", "region": Rect2i(0, 0, 128, 128)},
}

# Register > Readability row: "draw order z_index: environment 0, pickups
# 10, enemies 20 (Y-sorted among themselves), Tower 25, player projectiles
# 30 ..., effects 35, telegraphs 40, player 50, damage numbers 60."
const ENEMY_Z_INDEX: int = 20


## Loads an imported PNG as an Image through the resource/import pipeline
## (`load()` -> Texture2D -> get_image()) rather than Image.load() reading
## the raw file directly off disk. Image.load() on a res:// path that has
## an .import file works today but prints "Loaded resource as image file,
## this will not work on export" (Godot reads the raw bytes, bypassing the
## import cache an exported build would need) -- an engine WARNING, not an
## ERROR (tools/run_tests.ps1's Guard 4 only fails closed on ERROR/SCRIPT
## ERROR/USER ERROR/USER SCRIPT ERROR lines), but avoidable, so this suite
## avoids it rather than leaving a warning in every run's output.
func _load_image(path: String, region: Variant = null) -> Image:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null
	var img: Image = texture.get_image()
	if region is Rect2i and img != null:
		img = img.get_region(region as Rect2i)
	return img


func test_player_sprite_and_silhouette_assets_exist_and_load() -> void:
	assert_bool(FileAccess.file_exists(PLAYER_SPRITE_PATH)).is_true()
	assert_bool(FileAccess.file_exists(PLAYER_SILHOUETTE_PATH)).is_true()

	var img: Image = _load_image(PLAYER_SILHOUETTE_PATH)
	assert_object(img).append_failure_message("failed to load %s as a Texture2D/Image" % PLAYER_SILHOUETTE_PATH).is_not_null()
	assert_int(img.get_width()).is_greater(0)
	assert_int(img.get_height()).is_greater(0)


func test_player_silhouette_has_visible_non_transparent_content() -> void:
	var img: Image = _load_image(PLAYER_SILHOUETTE_PATH)
	assert_object(img).is_not_null()

	var opaque_pixels: int = 0
	var total_pixels: int = img.get_width() * img.get_height()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.1:
				opaque_pixels += 1

	assert_int(opaque_pixels).append_failure_message("player_silhouette.png has %d/%d non-transparent pixels -- silhouette appears blank" % [opaque_pixels, total_pixels]).is_greater(int(total_pixels * 0.05))


func _alpha_grid(path: String, region: Variant = null, grid_size: int = 8) -> PackedFloat32Array:
	var img: Image = _load_image(path, region)
	assert_object(img).append_failure_message("failed to load %s" % path).is_not_null()
	img.resize(grid_size, grid_size, Image.INTERPOLATE_LANCZOS)
	var grid: PackedFloat32Array = PackedFloat32Array()
	grid.resize(grid_size * grid_size)
	for y in grid_size:
		for x in grid_size:
			grid[y * grid_size + x] = img.get_pixel(x, y).a
	return grid


func _grid_distance(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var total: float = 0.0
	for i in a.size():
		total += absf(a[i] - b[i])
	return total


func test_player_silhouette_is_shape_distinct_from_each_enemy_silhouette() -> void:
	var player_grid: PackedFloat32Array = _alpha_grid(PLAYER_SILHOUETTE_PATH)
	for enemy_name in ENEMY_SILHOUETTES.keys():
		var entry: Dictionary = ENEMY_SILHOUETTES[enemy_name]
		var enemy_grid: PackedFloat32Array = _alpha_grid(entry["path"], entry["region"])
		var distance: float = _grid_distance(player_grid, enemy_grid)
		assert_float(distance).append_failure_message("player silhouette's coarse alpha shape is nearly identical to %s's (distance=%f) -- readability hierarchy requires these stay distinguishable at a glance" % [enemy_name, distance]).is_greater(1.0)


# --- Render order (this task's PLAN.md-scoped assertion) -------------------

func test_player_z_index_is_above_the_register_enemy_z_index() -> void:
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	add_child(player)
	assert_int(player.z_index).is_greater(ENEMY_Z_INDEX)


func test_player_draws_above_enemies_surrounding_it_on_both_sides_of_its_y_position() -> void:
	# Simulates docs/20's own scenario: enemies both above and below the
	# player's foot position, inside a Y-sort-enabled container (mirroring
	# scenes/main.tscn's real "Entities" container -- see
	# tests/unit/main_scene_structure_test.gd), with the player kept as a
	# SEPARATE SIBLING outside it, exactly as docs/20 > Scene Tree requires:
	# "The player is not a child of Entities and is not part of that Y-sort
	# group."
	var root: Node2D = auto_free(Node2D.new())
	add_child(root)

	var entities: Node2D = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	entities.z_index = ENEMY_Z_INDEX
	root.add_child(entities)

	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	root.add_child(player) # sibling of Entities, NOT a child of it
	player.global_position = Vector2(0, 0)

	var enemy_above: Node2D = Node2D.new()
	enemy_above.global_position = Vector2(-20, -50) # smaller Y -- would draw "behind" under pure Y-sort
	entities.add_child(enemy_above)

	var enemy_below: Node2D = Node2D.new()
	enemy_below.global_position = Vector2(20, 50) # larger Y -- would draw "in front" under pure Y-sort
	entities.add_child(enemy_below)

	assert_object(player.get_parent()).append_failure_message("player must not be parented under the Y-sort Entities container").is_not_same(entities)
	assert_int(player.z_index).append_failure_message("player z_index (%d) must exceed the Entities/enemy z_index (%d) regardless of relative Y position, since Godot's canvas draw order is z_index-primary" % [player.z_index, entities.z_index]).is_greater(entities.z_index)
