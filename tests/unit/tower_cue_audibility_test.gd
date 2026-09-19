extends GdUnitTestSuite

## Tower cue audibility check (P2.6 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Readability Tests > "Tower cue audibility
## check": "The cue plays on an AudioStreamPlayer routed to the TowerCue bus
## (which sends to SFX_Priority) with pan = clamp((Tower x - player x) /
## 960, -1, 1), at full volume from the far arena corner (scripted bus and
## pan assertion), and respects the 250 ms retrigger limit." Extended by
## this task's own brief to also assert audibility over concurrent SFX (the
## ducking ramp) and the HUD's four fields at 1080p surviving pseudo-
## localization, per the phase exit criterion: "HUD fields readable at
## 1080p; cue audible over concurrent sounds."
##
## ## Ownership boundary, named rather than silently crossed (see the P2.6
## evidence report, "Falsification"): `src/audio/tower_cue_player.gd`,
## `src/audio/audio_ducking.gd`, `src/audio/cue_retrigger_limiter.gd`, and
## `default_bus_layout.tres` are P1.6 deliverables, outside this task's
## write scope (P2.6's "Your files" list names only `src/ui/`,
## `scenes/ui/`, and specific test suites). This suite RE-VERIFIES those
## mechanisms as reached through THIS task's own wiring
## (`src/ui/threat_feedback.gd`), which is the actual named acceptance
## test's job -- but this task's own falsification (below) mutates only
## `src/ui/*.gd`, never the P1.6 files, per the hard write-scope
## constraint. The bus-routing and retrigger-limit sub-checks re-verify a
## mechanism P1.6 already built and already falsified in its own suites
## (`tests/unit/audio/test_tower_cue_player.gd`,
## `tests/unit/audio/test_bus_layout.gd`); this task does not repeat that
## mechanism's own falsification, only its own wiring's.

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")

const PAN_DIVISOR: float = 960.0 # C-TOWERCUE, cited not restated


func _build_player() -> Player:
	var player: Player = auto_free(PlayerScene.instantiate() as Player)
	add_child(player)
	return player


func _build_tower() -> Tower:
	var tower: Tower = auto_free(TowerScene.instantiate() as Tower)
	add_child(tower)
	return tower


func _build_threat_feedback(tower: Tower, player: Player, clock: Node) -> ThreatFeedback:
	var tf: ThreatFeedback = auto_free(ThreatFeedback.new())
	add_child(tf)
	tf.set_sim_clock_for_test(clock)
	tf.set_tower_ref(tower)
	tf.set_player_ref(player)
	return tf


func _build_clock() -> Node:
	var clock: Node = auto_free(SimClockScript.new())
	add_child(clock)
	return clock


func _hit(tower: Tower, amount: float = 10.0) -> void:
	tower.hurtbox.receive_hit(auto_free(Node.new()), amount, "test_attacker")


# ============================================================================
# 1. Bus routing: TowerCue -> SFX_Priority -> Master, with an AudioEffectPanner.
# ============================================================================

func test_towercue_bus_routes_to_sfx_priority_which_routes_to_master() -> void:
	var towercue_idx: int = AudioServer.get_bus_index("TowerCue")
	assert_int(towercue_idx).append_failure_message("TowerCue bus does not exist in the live AudioServer bus graph").is_greater(-1)
	assert_str(AudioServer.get_bus_send(towercue_idx)).is_equal("SFX_Priority")

	var sfx_priority_idx: int = AudioServer.get_bus_index("SFX_Priority")
	assert_int(sfx_priority_idx).is_greater(-1)
	assert_str(AudioServer.get_bus_send(sfx_priority_idx)).is_equal("Master")

	assert_int(AudioServer.get_bus_effect_count(towercue_idx)).append_failure_message("TowerCue bus has no AudioEffectPanner").is_greater(0)
	assert_object(AudioServer.get_bus_effect(towercue_idx, 0)).is_instanceof(AudioEffectPanner)


func test_cue_player_is_a_non_positional_audiostreamplayer_routed_to_towercue() -> void:
	var clock: Node = _build_clock()
	var tower: Tower = _build_tower()
	var player: Player = _build_player()
	var tf: ThreatFeedback = _build_threat_feedback(tower, player, clock)

	var cue_player: TowerCuePlayer = tf.get_cue_player()
	assert_object(cue_player).is_not_null()
	# AudioStreamPlayer, not AudioStreamPlayer2D/3D -- non-positional, so its
	# own output volume never attenuates with distance ("at full volume ...
	# no matter how far off-screen the Tower is", docs/20).
	assert_bool(cue_player is AudioStreamPlayer).is_true()
	assert_str(cue_player.bus).is_equal("TowerCue")


# ============================================================================
# 2. Pan formula for a Tower far off-screen on each side, driven through
#    this task's own wiring (a real hurtbox hit -> ThreatFeedback -> the
#    real TowerCuePlayer -> the real TowerCue bus's panner).
# ============================================================================

func test_pan_matches_formula_for_tower_far_to_the_right() -> void:
	var clock: Node = _build_clock()
	var tower: Tower = _build_tower()
	var player: Player = _build_player()
	var tf: ThreatFeedback = _build_threat_feedback(tower, player, clock)

	tower.global_position = Vector2(5000.0, 0.0) # far right, past the arena's own extent
	player.global_position = Vector2(0.0, 0.0)

	_hit(tower, 10.0)

	var towercue_idx: int = AudioServer.get_bus_index("TowerCue")
	var effect: AudioEffectPanner = AudioServer.get_bus_effect(towercue_idx, 0) as AudioEffectPanner
	var expected: float = clampf((5000.0 - 0.0) / PAN_DIVISOR, -1.0, 1.0)
	assert_float(expected).is_equal_approx(1.0, 0.0001) # sanity: this scenario is meant to clamp
	assert_float(effect.pan).append_failure_message("pan did not match clamp((tower_x - player_x)/960, -1, 1) for a Tower far to the right").is_equal_approx(expected, 0.01)


func test_pan_matches_formula_for_tower_far_to_the_left() -> void:
	var clock: Node = _build_clock()
	var tower: Tower = _build_tower()
	var player: Player = _build_player()
	var tf: ThreatFeedback = _build_threat_feedback(tower, player, clock)

	tower.global_position = Vector2(-5000.0, 0.0) # far left
	player.global_position = Vector2(0.0, 0.0)

	_hit(tower, 10.0)

	var towercue_idx: int = AudioServer.get_bus_index("TowerCue")
	var effect: AudioEffectPanner = AudioServer.get_bus_effect(towercue_idx, 0) as AudioEffectPanner
	var expected: float = clampf((-5000.0 - 0.0) / PAN_DIVISOR, -1.0, 1.0)
	assert_float(expected).is_equal_approx(-1.0, 0.0001)
	assert_float(effect.pan).append_failure_message("pan did not match clamp((tower_x - player_x)/960, -1, 1) for a Tower far to the left").is_equal_approx(expected, 0.01)


func test_pan_matches_formula_for_an_unclamped_offset() -> void:
	var clock: Node = _build_clock()
	var tower: Tower = _build_tower()
	var player: Player = _build_player()
	var tf: ThreatFeedback = _build_threat_feedback(tower, player, clock)

	tower.global_position = Vector2(480.0, 0.0)
	player.global_position = Vector2(0.0, 0.0)

	_hit(tower, 10.0)

	var towercue_idx: int = AudioServer.get_bus_index("TowerCue")
	var effect: AudioEffectPanner = AudioServer.get_bus_effect(towercue_idx, 0) as AudioEffectPanner
	assert_float(effect.pan).is_equal_approx(0.5, 0.01)


# ============================================================================
# 3. The 250 ms retrigger limit holds under a burst (direct, low-level - the
#    class itself is a P1.6 mechanism this task re-verifies but does not own).
# ============================================================================

func test_retrigger_limit_holds_under_a_rapid_burst() -> void:
	var clock: Node = _build_clock()
	var tower: Tower = _build_tower()
	var player: Player = _build_player()
	var tf: ThreatFeedback = _build_threat_feedback(tower, player, clock)
	var cue_player: TowerCuePlayer = tf.get_cue_player()
	var stream: AudioStream = tf.get_cue_stream()

	assert_bool(cue_player.play_tower_damage(stream, 0.0, 0.0, 0.0)).append_failure_message("first play in the burst should always succeed").is_true()
	for attempt_ms in [10.0, 50.0, 100.0, 150.0, 200.0, 249.0]:
		assert_bool(cue_player.play_tower_damage(stream, 0.0, 0.0, attempt_ms)).append_failure_message("a retrigger at %sms should have been blocked by the 250ms limit" % attempt_ms).is_false()
	assert_bool(cue_player.play_tower_damage(stream, 0.0, 0.0, 260.0)).append_failure_message("a retrigger past the 250ms limit should succeed").is_true()


func test_retrigger_limit_wired_through_real_tower_damage_events() -> void:
	# Same rule, but exercised through THIS task's own wiring: two real
	# Hurtbox hits close together in SimClock time must not both reach the
	# cue player as two successful plays.
	var clock: Node = _build_clock()
	var tower: Tower = _build_tower()
	var player: Player = _build_player()
	var tf: ThreatFeedback = _build_threat_feedback(tower, player, clock)
	var cue_player: TowerCuePlayer = tf.get_cue_player()

	clock.now = 0.0
	_hit(tower, 10.0)
	var after_first: float = cue_player.get_limiter().time_since_last_trigger_ms("tower_damage", 0.0)
	assert_float(after_first).append_failure_message("the first hit should have triggered the cue immediately").is_equal_approx(0.0, 0.01)

	clock.now = 0.1 # 100ms later, sim time -- well inside the 250ms limit
	_hit(tower, 10.0)
	var since_first_at_100ms: float = cue_player.get_limiter().time_since_last_trigger_ms("tower_damage", 100.0)
	assert_float(since_first_at_100ms).append_failure_message("a second hit inside the 250ms limit must not have re-triggered the cue (the limiter's recorded timestamp should not have moved)").is_equal_approx(100.0, 0.5)


# ============================================================================
# 4. The cue remains audible over concurrent SFX: ducking fires on SFX and
#    Ambience (and Music), and SFX_Priority itself never ducks.
# ============================================================================

func test_cue_triggers_ducking_on_sfx_and_ambience_but_not_sfx_priority() -> void:
	var clock: Node = _build_clock()
	var tower: Tower = _build_tower()
	var player: Player = _build_player()
	var tf: ThreatFeedback = _build_threat_feedback(tower, player, clock)

	var sfx_priority_idx: int = AudioServer.get_bus_index("SFX_Priority")
	var sfx_priority_before: float = AudioServer.get_bus_volume_db(sfx_priority_idx)

	var ducking: AudioDucking = tf.get_ducking_node()
	assert_object(ducking).append_failure_message("ThreatFeedback did not wire an AudioDucking node to its TowerCuePlayer").is_not_null()

	tower.global_position = Vector2(1000.0, 0.0)
	player.global_position = Vector2(0.0, 0.0)
	_hit(tower, 10.0) # plays the cue -> calls ducking.notify_priority_started()

	assert_int(ducking.get_active_priority_count()).is_greater(0)

	ducking.step(0.05) # the Register's own 50ms attack time -- should be at (or very near) full duck

	assert_float(ducking.get_last_sfx_db()).append_failure_message("SFX bus did not duck while the Tower cue was playing").is_less(0.0)
	assert_float(ducking.get_last_ambience_db()).append_failure_message("Ambience bus did not duck while the Tower cue was playing").is_less(0.0)
	assert_float(ducking.get_last_music_db()).append_failure_message("Music bus did not duck while the Tower cue was playing").is_less(0.0)

	var sfx_priority_after: float = AudioServer.get_bus_volume_db(sfx_priority_idx)
	assert_float(sfx_priority_after).append_failure_message("SFX_Priority's own bus volume changed -- it must never duck").is_equal_approx(sfx_priority_before, 0.001)


# ============================================================================
# 5. HUD fields at 1920x1080 (canvas_items/keep, pinned) and layout survival
#    under the F2 pseudo-localization expansion (30%), with no silent
#    truncation.
# ============================================================================

func test_pinned_viewport_and_stretch_settings() -> void:
	assert_int(int(ProjectSettings.get_setting("display/window/size/viewport_width"))).is_equal(1920)
	assert_int(int(ProjectSettings.get_setting("display/window/size/viewport_height"))).is_equal(1080)
	assert_str(str(ProjectSettings.get_setting("display/window/stretch/mode"))).is_equal("canvas_items")
	assert_str(str(ProjectSettings.get_setting("display/window/stretch/aspect"))).is_equal("keep")


func _build_hud_in_1080p_viewport() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	add_child(vp)
	auto_free(vp)

	var hud: Hud = auto_free(Hud.new())
	vp.add_child(hud)

	return {"viewport": vp, "hud": hud}


func test_four_hud_fields_lay_out_within_the_pinned_viewport() -> void:
	var built: Dictionary = _build_hud_in_1080p_viewport()
	var hud: Hud = built["hud"]
	await get_tree().process_frame
	await get_tree().process_frame

	var bounds := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var fields: Array = [hud.get_player_health_field(), hud.get_tower_health_field(), hud.get_scrap_field(), hud.get_xp_field()]
	var names: Array = ["player health", "Tower health/wave", "Scrap", "XP/level/rerolls"]
	for i in range(fields.size()):
		var field: Control = fields[i]
		assert_object(field).append_failure_message("%s field was not built" % names[i]).is_not_null()
		var rect: Rect2 = field.get_global_rect()
		assert_bool(bounds.encloses(rect)).append_failure_message("%s field's rect %s is not fully inside the pinned 1920x1080 viewport" % [names[i], rect]).is_true()


func test_hud_layout_survives_pseudolocalization_without_silent_truncation() -> void:
	var built: Dictionary = _build_hud_in_1080p_viewport()
	var hud: Hud = built["hud"]
	await get_tree().process_frame

	var was_enabled: bool = TranslationServer.is_pseudolocalization_enabled()
	ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", 0.3)
	TranslationServer.set_pseudolocalization_enabled(true)
	TranslationServer.reload_pseudolocalization()

	await get_tree().process_frame
	await get_tree().process_frame

	# The Scrap value is this HUD's ONE designed-to-truncate field: ellipsis
	# display, full value recoverable via a custom focus tooltip.
	var scrap_label: HudTruncatableLabel = hud.get_scrap_label()
	assert_int(scrap_label.text_overrun_behavior).is_equal(TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_str(scrap_label.tooltip_text).append_failure_message("the Scrap label's full value is not recoverable via its tooltip").is_not_empty()

	# Every OTHER label must be structurally incapable of SILENT truncation:
	# not configured to trim, and wired to wrap/grow instead.
	var other_labels: Array = [hud.get_wave_label(), hud.get_full_badge_label(), hud.get_hopper_label(), hud.get_level_label(), hud.get_rerolls_label()]
	var other_names: Array = ["Wave", "FULL badge", "Hopper", "Level", "Rerolls"]
	for i in range(other_labels.size()):
		var label: Label = other_labels[i]
		assert_int(label.text_overrun_behavior).append_failure_message("%s label is configured to trim/truncate instead of growing" % other_names[i]).is_equal(TextServer.OVERRUN_NO_TRIMMING)
		assert_int(label.autowrap_mode).append_failure_message("%s label cannot wrap, so growth from pseudo-localization would silently clip it" % other_names[i]).is_not_equal(TextServer.AUTOWRAP_OFF)

	# The four fields must still fit inside the viewport after the 30%
	# expansion -- this is the actual "did the layout survive" claim.
	var bounds := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var fields: Array = [hud.get_player_health_field(), hud.get_tower_health_field(), hud.get_scrap_field(), hud.get_xp_field()]
	var names: Array = ["player health", "Tower health/wave", "Scrap", "XP/level/rerolls"]
	for i in range(fields.size()):
		var rect: Rect2 = (fields[i] as Control).get_global_rect()
		assert_bool(bounds.encloses(rect)).append_failure_message("%s field's rect %s no longer fits the pinned viewport once pseudo-localization expanded its text" % [names[i], rect]).is_true()

	TranslationServer.set_pseudolocalization_enabled(was_enabled)
	TranslationServer.reload_pseudolocalization()
