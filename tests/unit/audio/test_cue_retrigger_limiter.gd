extends GdUnitTestSuite

## P1.6 - retrigger-limit bookkeeping.
##
## Follows docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic
## Ducking" > "Retrigger Limits"; values from MASTER_SDLC.md > Provisional
## Values Register > Audio > "Retrigger limits" row: player damage 150 ms,
## Tower damage 250 ms. Uses synthetic "now" timestamps throughout - no real
## waiting - since CueRetriggerLimiter is clock-agnostic by design (see
## src/audio/cue_retrigger_limiter.gd's header and p16_report.md).



func test_first_trigger_always_succeeds() -> void:
	var limiter = CueRetriggerLimiter.new()
	assert_bool(limiter.try_trigger("player_damage", 0.0, 150.0)).is_true()


func test_retrigger_before_limit_is_blocked() -> void:
	var limiter = CueRetriggerLimiter.new()
	limiter.try_trigger("player_damage", 0.0, 150.0)
	assert_bool(limiter.try_trigger("player_damage", 149.0, 150.0)).is_false()


func test_retrigger_at_exactly_the_limit_succeeds() -> void:
	var limiter = CueRetriggerLimiter.new()
	limiter.try_trigger("player_damage", 0.0, 150.0)
	assert_bool(limiter.try_trigger("player_damage", 150.0, 150.0)).is_true()


func test_retrigger_after_limit_succeeds() -> void:
	var limiter = CueRetriggerLimiter.new()
	limiter.try_trigger("tower_damage", 0.0, 250.0)
	assert_bool(limiter.try_trigger("tower_damage", 250.1, 250.0)).is_true()


func test_blocked_trigger_does_not_reset_the_window() -> void:
	var limiter = CueRetriggerLimiter.new()
	limiter.try_trigger("player_damage", 0.0, 150.0)
	assert_bool(limiter.try_trigger("player_damage", 100.0, 150.0)).is_false() # blocked, not recorded
	assert_bool(limiter.try_trigger("player_damage", 151.0, 150.0)).is_true() # measured from t=0, not t=100


func test_different_cue_ids_are_independent() -> void:
	var limiter = CueRetriggerLimiter.new()
	limiter.try_trigger("player_damage", 0.0, 150.0)
	assert_bool(limiter.try_trigger("tower_damage", 10.0, 250.0)).is_true()


## The two Register values are distinct and each cue must use its own.
func test_player_damage_and_tower_damage_keep_their_own_register_values() -> void:
	var limiter = CueRetriggerLimiter.new()
	limiter.try_trigger("player_damage", 0.0, 150.0)
	limiter.try_trigger("tower_damage", 0.0, 250.0)
	# player_damage's shorter 150 ms window has elapsed by t=200...
	assert_bool(limiter.try_trigger("player_damage", 200.0, 150.0)).is_true()
	# ...but tower_damage's longer 250 ms window has not.
	assert_bool(limiter.try_trigger("tower_damage", 200.0, 250.0)).is_false()


func test_reset_clears_a_single_cue() -> void:
	var limiter = CueRetriggerLimiter.new()
	limiter.try_trigger("player_damage", 0.0, 150.0)
	limiter.reset("player_damage")
	assert_bool(limiter.try_trigger("player_damage", 1.0, 150.0)).is_true()


func test_time_since_last_trigger_reports_minus_one_before_any_trigger() -> void:
	var limiter = CueRetriggerLimiter.new()
	assert_float(limiter.time_since_last_trigger_ms("player_damage", 500.0)).is_equal_approx(-1.0, 0.001)
