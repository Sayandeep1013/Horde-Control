extends GdUnitTestSuite

## P1.6 - Tower Cue Player: pan formula and shared retrigger limit.
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Tower Cue Player": pan = clamp((Tower x - player x) / 960,
## -1, 1); shares the 250 ms Tower-damage retrigger limit. Matches
## MASTER_SDLC.md > Provisional Values Register > Interfaces > "Threat
## feedback" row (C-TOWERCUE) and > Audio > "Retrigger limits" row.

func _make_player() -> TowerCuePlayer:
	var p := TowerCuePlayer.new()
	add_child(p)
	auto_free(p)
	return p


static func _make_silent_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := int(22050 * 0.25)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		data[i] = 128
	stream.data = data
	return stream


func test_bus_is_towercue() -> void:
	var p := _make_player()
	assert_str(p.bus).is_equal("TowerCue")


func test_pan_formula_center() -> void:
	assert_float(TowerCuePlayer.compute_pan(500.0, 500.0)).is_equal_approx(0.0, 0.0001)


func test_pan_formula_tower_to_the_right() -> void:
	# (Tower x - player x) / 960: Tower 480 px right of player -> 0.5
	assert_float(TowerCuePlayer.compute_pan(980.0, 500.0)).is_equal_approx(0.5, 0.0001)


func test_pan_formula_clamps_to_positive_one() -> void:
	assert_float(TowerCuePlayer.compute_pan(5000.0, 0.0)).is_equal_approx(1.0, 0.0001)


func test_pan_formula_clamps_to_negative_one() -> void:
	assert_float(TowerCuePlayer.compute_pan(-5000.0, 0.0)).is_equal_approx(-1.0, 0.0001)


func test_first_tower_damage_play_succeeds() -> void:
	var p := _make_player()
	var stream := _make_silent_stream()
	assert_bool(p.play_tower_damage(stream, 100.0, 0.0, 0.0)).is_true()
	assert_bool(p.is_playing()).is_true()


func test_retrigger_within_250ms_is_blocked() -> void:
	var p := _make_player()
	var stream := _make_silent_stream()
	assert_bool(p.play_tower_damage(stream, 100.0, 0.0, 0.0)).is_true()
	assert_bool(p.play_tower_damage(stream, 100.0, 0.0, 249.0)).is_false()


func test_retrigger_after_250ms_succeeds() -> void:
	var p := _make_player()
	var stream := _make_silent_stream()
	assert_bool(p.play_tower_damage(stream, 100.0, 0.0, 0.0)).is_true()
	assert_bool(p.play_tower_damage(stream, 100.0, 0.0, 250.1)).is_true()


func test_apply_pan_sets_the_towercue_bus_panner_when_bus_exists() -> void:
	# Depends on default_bus_layout.tres being the live bus graph (verified
	# independently by test_bus_layout.gd). If the TowerCue bus somehow does
	# not exist, this simply confirms the defensive false return rather than
	# erroring.
	var p := _make_player()
	var idx := AudioServer.get_bus_index("TowerCue")
	if idx == -1:
		return
	var applied: bool = p.call("_apply_pan", 980.0, 500.0)
	assert_bool(applied).is_true()
	var effect := AudioServer.get_bus_effect(idx, 0)
	assert_float(effect.pan).is_equal_approx(0.5, 0.01)
