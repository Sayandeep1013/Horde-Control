extends GdUnitTestSuite
## A Player Hunter converted to a Tower Seeker by the leash rule must look
## like a Tower Seeker (src/enemy/enemy_animator.gd, converted_* exports), and
## a pooled instance must get its original art back on reuse.

const HunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")
const SEEKER_FRAMES: String = "res://assets/sprite_frames/tower_seeker.tres"


func _spawn_hunter() -> Node2D:
	var hunter: Node2D = HunterScene.instantiate()
	add_child(hunter)
	auto_free(hunter)
	return hunter


func test_conversion_swaps_to_tower_seeker_art() -> void:
	var hunter: Node2D = _spawn_hunter()
	var sprite: AnimatedSprite2D = hunter.get_node("Visuals/AnimatedSprite2D")
	var original: SpriteFrames = sprite.sprite_frames
	assert_str(original.resource_path).is_not_equal(SEEKER_FRAMES)

	hunter.converted_to_tower_seeker.emit()

	assert_str(sprite.sprite_frames.resource_path).is_equal(SEEKER_FRAMES)
	assert_bool(hunter.get_node("Visuals").directional_strike).is_true()


func test_reuse_restores_the_original_art() -> void:
	var hunter: Node2D = _spawn_hunter()
	var visuals: Node = hunter.get_node("Visuals")
	var sprite: AnimatedSprite2D = hunter.get_node("Visuals/AnimatedSprite2D")
	var original: SpriteFrames = sprite.sprite_frames
	hunter.converted_to_tower_seeker.emit()

	visuals._restore_alive_visuals() # the path a pooled instance takes on reuse

	assert_object(sprite.sprite_frames).is_same(original)
	assert_bool(visuals.directional_strike).is_false()
