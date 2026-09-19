extends GdUnitTestSuite

## The 8-segment vignette: damage window, fade curve, and pointing rule
## (P2.6). MASTER_SDLC.md > Visual Direction & Camera > "Directional Threat
## Feedback": "a red directional vignette appears at the screen edge, drawn
## as 8 discrete edge segments; its intensity follows the damage taken in
## the last second and it fades over 0.6 seconds. It points toward the
## Tower when the Tower is off-screen and toward the attacker when the
## Tower is on-screen." Provisional Values Register > Interfaces > "Threat
## feedback" row (cited, not restated).
##
## `ThreatFeedback.recompute(now)` (src/ui/threat_feedback.gd) is called
## directly with hand-chosen SimClock values throughout, rather than
## awaiting real `_process()` frames, matching this project's established
## "call the per-tick method directly with an injected clock" test
## convention (e.g. `tower_health_recovery_test.gd`). This makes the fade
## curve's exact shape deterministically checkable instead of depending on
## real frame timing.

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

	return {"clock": clock, "tower": tower, "player": player, "camera": camera, "tf": tf}


func _hit(tower: Tower, amount: float) -> void:
	tower.hurtbox.receive_hit(auto_free(Node.new()), amount, "test_attacker")


# --- Intensity: rises with damage, holds through the 1s window, then fades
# over 0.6s once the window empties -------------------------------------

func test_intensity_rises_immediately_on_damage() -> void:
	var f: Dictionary = _build_fixture()
	var clock: Node = f["clock"]
	var tower: Tower = f["tower"]
	var tf: ThreatFeedback = f["tf"]

	clock.now = 0.0
	_hit(tower, tower.health.max_health * 0.15 * 0.5) # half of the escalated normalization -> raw 0.5
	tf.recompute(0.0)

	assert_float(tf.get_display_intensity()).is_equal_approx(0.5, 0.01)


func test_intensity_holds_for_the_full_1s_window() -> void:
	var f: Dictionary = _build_fixture()
	var clock: Node = f["clock"]
	var tower: Tower = f["tower"]
	var tf: ThreatFeedback = f["tf"]

	clock.now = 0.0
	_hit(tower, tower.health.max_health * 0.15 * 0.5)
	tf.recompute(0.0)
	tf.recompute(1.0) # inclusive edge of the 1s window -- damage is still "in the last 1 s"

	assert_float(tf.get_display_intensity()).append_failure_message("intensity dropped before the Register's 1s damage window closed").is_equal_approx(0.5, 0.01)


func test_intensity_fades_gradually_not_as_an_instant_cliff() -> void:
	var f: Dictionary = _build_fixture()
	var clock: Node = f["clock"]
	var tower: Tower = f["tower"]
	var tf: ThreatFeedback = f["tf"]

	clock.now = 0.0
	_hit(tower, tower.health.max_health * 0.15 * 0.5)
	tf.recompute(0.0)
	tf.recompute(1.0)
	tf.recompute(1.0001) # a hair past the window -- raw drops to 0 here

	var just_past_window: float = tf.get_display_intensity()
	assert_float(just_past_window).append_failure_message("intensity fell all at once instead of fading -- it should have barely moved 0.1ms past the window").is_greater(0.49)
	assert_float(just_past_window).is_less(0.5)


func test_intensity_fully_fades_within_0point6_seconds_of_the_window_closing() -> void:
	var f: Dictionary = _build_fixture()
	var clock: Node = f["clock"]
	var tower: Tower = f["tower"]
	var tf: ThreatFeedback = f["tf"]

	clock.now = 0.0
	_hit(tower, tower.health.max_health * 0.15 * 0.5)
	tf.recompute(0.0)
	tf.recompute(1.0)
	tf.recompute(1.0001)
	tf.recompute(1.0001 + 0.6)

	assert_float(tf.get_display_intensity()).append_failure_message("intensity did not fully fade within 0.6s of the damage window closing").is_equal_approx(0.0, 0.001)


func test_shield_damage_and_health_damage_both_raise_intensity() -> void:
	# "triggered by shield and health damage" -- this listens to the
	# Tower's Hurtbox.damage_received directly, upstream of TowerHealth's own
	# shield/health split, so both cases raise intensity by construction;
	# this test proves it end to end rather than by code inspection alone.
	var f1: Dictionary = _build_fixture()
	var clock1: Node = f1["clock"]
	var tower1: Tower = f1["tower"]
	var tf1: ThreatFeedback = f1["tf"]
	clock1.now = 0.0
	_hit(tower1, 10.0) # small hit, absorbed entirely by shield
	tf1.recompute(0.0)
	assert_float(tf1.get_display_intensity()).append_failure_message("a pure shield hit did not raise vignette intensity").is_greater(0.0)

	var f2: Dictionary = _build_fixture()
	var clock2: Node = f2["clock"]
	var tower2: Tower = f2["tower"]
	var tf2: ThreatFeedback = f2["tf"]
	clock2.now = 0.0
	_hit(tower2, tower2.health.max_shield + 10.0) # breaks the shield, spills into health
	tf2.recompute(0.0)
	assert_float(tf2.get_display_intensity()).append_failure_message("a hit that also damaged health did not raise vignette intensity").is_greater(0.0)


# --- Pointing rule: Tower off-screen -> point at the Tower; Tower on-screen
# -> point at the attacker ------------------------------------------------

func test_points_at_the_tower_when_it_is_offscreen() -> void:
	var f: Dictionary = _build_fixture()
	var tower: Tower = f["tower"]
	var camera: GameCamera = f["camera"]
	var tf: ThreatFeedback = f["tf"]

	camera.snap_to(Vector2.ZERO)
	tower.global_position = Vector2(5000.0, 0.0) # well outside the visible rect

	assert_bool(tf.is_tower_on_screen()).is_false()
	var dir: Vector2 = tf.get_pointing_direction()
	assert_float(dir.x).is_equal_approx(1.0, 0.01)
	assert_float(dir.y).is_equal_approx(0.0, 0.01)
	assert_int(tf.get_active_segment_index()).is_equal(0) # angle 0 = +X


func test_points_at_the_attacker_not_the_tower_when_the_tower_is_onscreen() -> void:
	var f: Dictionary = _build_fixture()
	var tower: Tower = f["tower"]
	var camera: GameCamera = f["camera"]
	var tf: ThreatFeedback = f["tf"]

	camera.snap_to(Vector2.ZERO)
	tower.global_position = Vector2(100.0, 0.0) # on-screen, due EAST of the camera
	assert_bool(tf.is_tower_on_screen()).is_true()

	var attacker := Node2D.new()
	add_child(attacker)
	auto_free(attacker)
	attacker.global_position = Vector2(0.0, 300.0) # due SOUTH of the camera -- a different bearing than the Tower's

	tower.hurtbox.receive_hit(attacker, 10.0, "test_attacker")

	var dir: Vector2 = tf.get_pointing_direction()
	# Must point SOUTH (toward the attacker), not EAST (toward the Tower).
	assert_float(dir.y).append_failure_message("pointed toward the Tower instead of the attacker while the Tower was on-screen").is_greater(0.9)
	assert_float(absf(dir.x)).is_less(0.2)
