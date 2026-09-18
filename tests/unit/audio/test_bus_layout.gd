extends GdUnitTestSuite

## P1.6 - bus layout as built against docs/20's routing.
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Audio Bus Hierarchy" and "Tower Cue Player"; MASTER_SDLC.md >
## Provisional Values Register > Audio > "Buses" row (C-TOWERCUE).
##
## Checks the LIVE AudioServer bus graph, not the .tres file parsed in
## isolation - specifically to prove default_bus_layout.tres at the project
## root is actually in effect at engine boot with no project.godot edit
## (see p16_report.md for why that path was chosen over src/audio/). No
## test anywhere in tests/unit/audio calls AudioServer.set_bus_layout(), so
## whatever graph is observed here is exactly what the running engine
## booted with from res://default_bus_layout.tres (Godot's built-in default
## value for the audio/buses/default_bus_layout project setting).

func test_default_bus_layout_setting_points_at_the_project_root_resource() -> void:
	var configured: String = ProjectSettings.get_setting("audio/buses/default_bus_layout")
	assert_str(configured).is_equal("res://default_bus_layout.tres")


func test_seven_buses_exist_with_the_expected_names() -> void:
	assert_int(AudioServer.bus_count).is_equal(7)
	var names := []
	for i in range(AudioServer.bus_count):
		names.append(AudioServer.get_bus_name(i))
	assert_array(names).contains("Master", "Music", "SFX", "SFX_Priority", "UI", "Ambience", "TowerCue")


func test_master_is_bus_zero() -> void:
	assert_str(AudioServer.get_bus_name(0)).is_equal("Master")


func test_music_sfx_sfx_priority_ui_ambience_send_to_master() -> void:
	for bus_name in ["Music", "SFX", "SFX_Priority", "UI", "Ambience"]:
		var idx := AudioServer.get_bus_index(bus_name)
		assert_int(idx).is_greater(-1)
		assert_str(AudioServer.get_bus_send(idx)).is_equal("Master")


func test_tower_cue_sends_to_sfx_priority_not_master() -> void:
	var idx := AudioServer.get_bus_index("TowerCue")
	assert_int(idx).is_greater(-1)
	assert_str(AudioServer.get_bus_send(idx)).is_equal("SFX_Priority")


func test_tower_cue_carries_an_audio_effect_panner() -> void:
	var idx := AudioServer.get_bus_index("TowerCue")
	assert_int(AudioServer.get_bus_effect_count(idx)).is_greater(0)
	assert_object(AudioServer.get_bus_effect(idx, 0)).is_instanceof(AudioEffectPanner)


func test_no_other_bus_carries_an_effect() -> void:
	for bus_name in ["Master", "Music", "SFX", "SFX_Priority", "UI", "Ambience"]:
		var idx := AudioServer.get_bus_index(bus_name)
		assert_int(AudioServer.get_bus_effect_count(idx)).is_equal(0)


func test_sfx_priority_bus_never_ducks_meaning_it_is_not_a_ducking_target() -> void:
	# docs/20: "SFX_Priority ... never ducks." The ducking node only ever
	# writes to SFX, Ambience, and Music (audio_ducking.gd's BUS_* consts) -
	# this test documents that SFX_Priority's own volume is untouched by
	# capturing it before/after a full ducking cycle driven against the
	# real buses.
	var idx := AudioServer.get_bus_index("SFX_Priority")
	var before := AudioServer.get_bus_volume_db(idx)

	var d := AudioDucking.new()
	add_child(d)
	auto_free(d)
	d.notify_priority_started()
	d.step(0.05)
	d.notify_priority_stopped()
	d.step(0.3)

	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(before, 0.001)
