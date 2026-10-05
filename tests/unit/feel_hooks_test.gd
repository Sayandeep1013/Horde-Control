extends GdUnitTestSuite

## D126 (review P1-9): screen shake is actually called on Player and Tower
## damage, respecting the Settings gate; pickup/level-up cues are wired.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")

var _proto: Node
var _camera: GameCamera
var _player: Player
var _tower: Tower


func before_test() -> void:
	GameSettings.set_screen_shake_enabled_for_test(true)
	_proto = auto_free(PrototypeScene.instantiate())
	_proto.run_seed = 1
	add_child(_proto)
	_camera = _proto.get_node("Main/GameCamera") as GameCamera
	_player = _proto.get_node("Main/Player") as Player
	_tower = _proto.get_node("Main/Tower") as Tower
	_camera.snap_to(_camera.global_position) # clears trauma


func after_test() -> void:
	GameSettings.set_screen_shake_enabled_for_test(true)


func test_player_hit_adds_trauma() -> void:
	_player.get_node("Hurtbox").damage_received.emit(5.0, null, null)
	assert_float(_camera.get_trauma_for_test()).is_equal_approx(PrototypeIntegration.TRAUMA_PLAYER_HIT, 0.001)


func test_player_hit_respects_the_settings_gate() -> void:
	GameSettings.set_screen_shake_enabled_for_test(false)
	_player.get_node("Hurtbox").damage_received.emit(5.0, null, null)
	assert_float(_camera.get_trauma_for_test()).is_equal(0.0)


func test_tower_shield_only_hit_does_not_shake() -> void:
	_tower.health._on_hurtbox_damage_received(20.0, null, null)
	assert_float(_camera.get_trauma_for_test()).is_equal(0.0)


func test_tower_health_loss_adds_trauma() -> void:
	_tower.health._on_hurtbox_damage_received(200.0, null, null)
	assert_float(_camera.get_trauma_for_test()).is_equal_approx(PrototypeIntegration.TRAUMA_TOWER_HEALTH_LOSS, 0.001)


func test_level_up_chime_is_always_mode_and_has_a_stream() -> void:
	var chime: AudioStreamPlayer = _proto.get_node("LevelUpPlayer") as AudioStreamPlayer
	assert_object(chime.stream).is_not_null()
	assert_int(chime.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_object((_proto.get_node("PickupTickPlayer") as AudioStreamPlayer).stream).is_not_null()
