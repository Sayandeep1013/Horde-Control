extends GdUnitTestSuite

## The off-screen Tower indicator (P2.6). MASTER_SDLC.md > Visual Direction
## & Camera > "Directional Threat Feedback" > "Off-screen Indicator": "If
## the Tower is off-screen, a persistent, subtle UI indicator ... points
## toward it. Below 40% Tower health, the indicator changes both shape and
## colour and additionally shows a short arc on the side of the Tower
## currently being hit." MASTER_SDLC.md > Visual Edge Cases >
## "Colour-only distinctions": shape must carry the low-health state
## independently of colour.

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")


func _build_fixture() -> Dictionary:
	var clock: Node = auto_free(SimClockScript.new())
	add_child(clock)
	var tower: Tower = auto_free(TowerScene.instantiate() as Tower)
	add_child(tower)
	var player: Player = auto_free(PlayerScene.instantiate() as Player)
	add_child(player)
	var camera: GameCamera = auto_free(GameCamera.new())
	add_child(camera)
	var tf: ThreatFeedback = auto_free(ThreatFeedback.new())
	add_child(tf)

	tf.set_sim_clock_for_test(clock)
	tf.set_tower_ref(tower)
	tf.set_player_ref(player)
	tf.set_camera_ref(camera)
	camera.snap_to(Vector2.ZERO)

	return {"clock": clock, "tower": tower, "player": player, "camera": camera, "tf": tf}


func test_indicator_hidden_when_tower_is_onscreen() -> void:
	var f: Dictionary = _build_fixture()
	var tower: Tower = f["tower"]
	var tf: ThreatFeedback = f["tf"]

	tower.global_position = Vector2(50.0, 0.0)
	assert_bool(tf.is_showing_offscreen_indicator()).is_false()


func test_indicator_shown_when_tower_is_offscreen() -> void:
	var f: Dictionary = _build_fixture()
	var tower: Tower = f["tower"]
	var tf: ThreatFeedback = f["tf"]

	tower.global_position = Vector2(5000.0, 0.0)
	assert_bool(tf.is_showing_offscreen_indicator()).is_true()


func test_indicator_shape_and_colour_both_change_below_40_percent_health() -> void:
	var f: Dictionary = _build_fixture()
	var tower: Tower = f["tower"]
	var tf: ThreatFeedback = f["tf"]
	tower.global_position = Vector2(5000.0, 0.0)

	var shape_before: StringName = tf.get_indicator_shape()
	var color_before: Color = tf.get_indicator_color()
	assert_bool(tf.is_indicator_low_health()).is_false()

	var lethal_to_below_40: float = tower.health.max_shield + tower.health.max_health * 0.65
	tower.hurtbox.receive_hit(auto_free(Node.new()), lethal_to_below_40, "test")

	assert_bool(tf.is_indicator_low_health()).append_failure_message("Tower health did not read as below 40%% after the hit").is_true()
	var shape_after: StringName = tf.get_indicator_shape()
	var color_after: Color = tf.get_indicator_color()

	assert_bool(shape_after == shape_before).append_failure_message("indicator SHAPE did not change below 40%% Tower health").is_false()
	assert_bool(color_after == color_before).append_failure_message("indicator COLOUR did not change below 40%% Tower health").is_false()


func test_hit_arc_appears_after_a_hit_and_points_at_the_side_hit() -> void:
	var f: Dictionary = _build_fixture()
	var tower: Tower = f["tower"]
	var clock: Node = f["clock"]
	var tf: ThreatFeedback = f["tf"]
	tower.global_position = Vector2(5000.0, 0.0)

	assert_bool(tf.has_recent_hit_arc()).append_failure_message("a hit arc appeared with no hit ever recorded").is_false()

	var attacker := Node2D.new()
	add_child(attacker)
	auto_free(attacker)
	# South of the Tower's own centre (not the camera's) -- "the side of the
	# Tower currently being hit" is a Tower-relative bearing.
	attacker.global_position = tower.global_position + Vector2(0.0, 300.0)

	clock.now = 0.0
	tower.hurtbox.receive_hit(attacker, 10.0, "test")

	assert_bool(tf.has_recent_hit_arc()).is_true()
	var bearing: float = tf.get_hit_arc_bearing_from_tower()
	assert_float(bearing).is_equal_approx(PI / 2.0, 0.05) # south, in Godot's +Y-down convention


func test_hit_arc_expires_after_its_display_window() -> void:
	var f: Dictionary = _build_fixture()
	var tower: Tower = f["tower"]
	var clock: Node = f["clock"]
	var tf: ThreatFeedback = f["tf"]
	tower.global_position = Vector2(5000.0, 0.0)

	var attacker := Node2D.new()
	add_child(attacker)
	auto_free(attacker)
	attacker.global_position = tower.global_position + Vector2(0.0, 300.0)

	clock.now = 0.0
	tower.hurtbox.receive_hit(attacker, 10.0, "test")
	assert_bool(tf.has_recent_hit_arc()).is_true()

	clock.now = 5.0 # well past the arc's own display window
	assert_bool(tf.has_recent_hit_arc()).append_failure_message("the hit arc never expired").is_false()
