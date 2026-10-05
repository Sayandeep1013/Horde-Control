extends GdUnitTestSuite

## UX review P0-3 (D127): the Tower fades while the player is behind it.

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")


func _make() -> Array:
	var tower: Node2D = auto_free(TowerScene.instantiate())
	add_child(tower)
	var visuals: TowerVisuals = tower.get_node("Visuals")
	var player: Node2D = auto_free(Node2D.new())
	add_child(player)
	visuals.set_player_for_test(player)
	return [tower, visuals, player]


func test_player_inside_the_sprite_rect_is_occluded() -> void:
	var parts: Array = _make()
	var tower: Node2D = parts[0]
	var visuals: TowerVisuals = parts[1]
	var player: Node2D = parts[2]
	tower.global_position = Vector2(500, 500)
	player.global_position = tower.global_position + Vector2(0, -100)
	assert_bool(visuals.is_player_occluded()).is_true()
	player.global_position = tower.global_position + Vector2(600, 0)
	assert_bool(visuals.is_player_occluded()).is_false()


func test_alpha_fades_to_the_register_value_and_restores() -> void:
	var parts: Array = _make()
	var tower: Node2D = parts[0]
	var visuals: TowerVisuals = parts[1]
	var player: Node2D = parts[2]
	tower.global_position = Vector2(500, 500)
	player.global_position = tower.global_position + Vector2(0, -100)
	for i in 120:
		visuals._process(1.0 / 60.0)
	assert_float(visuals.modulate.a).is_equal_approx(TowerVisuals.OCCLUSION_FADE_ALPHA, 0.001)
	player.global_position = tower.global_position + Vector2(600, 0)
	for i in 120:
		visuals._process(1.0 / 60.0)
	assert_float(visuals.modulate.a).is_equal_approx(1.0, 0.001)
