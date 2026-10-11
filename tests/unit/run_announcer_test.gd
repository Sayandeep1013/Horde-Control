extends GdUnitTestSuite

## Wave banners (exactly one per wave, D240) and the contextual once-per-profile
## hints (D241): queue, pause, per-profile persistence and wording.

var _dir: String


class FakeSkill extends Node:
	var is_ready: bool = false

	func get_state() -> Dictionary:
		return {"skill_id": "arrow_storm", "ready": is_ready, "cooldown_remaining": 0.0, "cooldown_total": 10.0}


func before_test() -> void:
	_dir = "user://__run_announcer_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	TouchUi.set_override_for_test(0)


func after_test() -> void:
	TouchUi.set_override_for_test(-1)
	MetaProgress.set_base_path_for_test("user://")
	get_tree().paused = false


func _make() -> RunAnnouncer:
	var announcer: RunAnnouncer = auto_free(RunAnnouncer.new())
	add_child(announcer)
	return announcer


func _texts(box: Control) -> Array[String]:
	var out: Array[String] = []
	for n in box.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func _banner_count(announcer: RunAnnouncer, text: String) -> int:
	return _texts(announcer.get_banner_box_for_test()).count(text)


# --- one banner per wave -------------------------------------------------------------

func test_wave_started_shows_exactly_one_banner_even_when_emitted_twice() -> void:
	var announcer: RunAnnouncer = _make()
	EventBus.emit_wave_started(1, 15, "standard", false)
	EventBus.emit_wave_started(1, 15, "standard", false)
	assert_int(_banner_count(announcer, "WAVE 1 · STANDARD")).is_equal(1)
	assert_int(announcer.get_banner_box_for_test().get_child_count()).append_failure_message("no second banner of any kind at wave 1").is_equal(1)


func test_a_legacy_wave_opened_signal_never_adds_a_banner() -> void:
	var announcer: RunAnnouncer = _make()
	var director: Node = auto_free(Node.new())
	director.set_script(_director_script())
	add_child(director)
	announcer.bind_wave_director(director)
	# Order A: legacy first, then the v1 signal.
	director.wave_opened.emit("t1", 0)
	EventBus.emit_wave_started(1, 15, "standard", false)
	assert_int(announcer.get_banner_box_for_test().get_child_count()).is_equal(1)
	# Order B: v1 first, then legacy.
	EventBus.emit_wave_started(2, 15, "standard", false)
	director.wave_opened.emit("t2", 1)
	assert_int(announcer.get_banner_box_for_test().get_child_count()).is_equal(2)
	assert_int(announcer.get_last_banner_wave_for_test()).is_equal(2)


func _director_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nsignal wave_opened(wave_id: String, wave_index: int)\n"
	script.reload()
	return script


func test_each_new_wave_number_gets_its_own_banner() -> void:
	var announcer: RunAnnouncer = _make()
	EventBus.emit_wave_started(5, 15, "standard", false)
	EventBus.emit_wave_started(6, 15, "siege", false)
	assert_array(_texts(announcer.get_banner_box_for_test())).contains(["WAVE 5 · STANDARD", "WAVE 6 · SIEGE"])


# --- objective and hints ---------------------------------------------------------------

func test_wave_one_shows_the_objective_first_then_the_start_hint_never_together() -> void:
	var announcer: RunAnnouncer = _make()
	EventBus.emit_wave_started(1, 15, "standard", false)
	var toasts: Array[String] = _texts(announcer.get_toast_box_for_test())
	assert_array(toasts).contains(["Protect yourself and the Tower - hold 15 waves and slay the Bombardier King"])
	assert_int(toasts.size()).append_failure_message("one toast at a time").is_equal(1)
	assert_int(announcer.get_hints_for_test().queued_count()).is_equal(1)


func test_start_hint_names_the_live_move_keys_and_is_remembered() -> void:
	var hints: RunHints = _make().get_hints_for_test()
	var text: String = hints.text_for(RunHints.ID_START, ["W A S D"])
	assert_str(text).is_equal("Your bow fires on its own. Move with W A S D.")
	assert_bool(hints.wants(RunHints.ID_DASH)).is_true()
	hints.request(RunHints.ID_DASH, ["Space"])
	assert_array(_texts(hints.get_parent().get_toast_box_for_test())).contains(["Press Space to dash through danger"])
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_DASH)).is_true()
	assert_bool(hints.wants(RunHints.ID_DASH)).is_false()


func test_a_seen_hint_never_shows_again_even_in_a_new_run() -> void:
	MetaProgress.mark_hint_seen(RunHints.ID_TOWER_REPAIR)
	var hints: RunHints = _make().get_hints_for_test()
	hints.request(RunHints.ID_TOWER_REPAIR)
	assert_int(hints.queued_count()).is_equal(0)
	assert_bool(hints.is_showing()).is_false()


func test_hints_never_stack_a_second_waits_in_the_queue() -> void:
	var announcer: RunAnnouncer = _make()
	var hints: RunHints = announcer.get_hints_for_test()
	hints.request(RunHints.ID_DASH, ["Space"])
	hints.request(RunHints.ID_TOWER_REPAIR)
	hints.request(RunHints.ID_SKILL_READY, ["Q", "Arrow Storm"])
	assert_int(_texts(announcer.get_toast_box_for_test()).size()).is_equal(1)
	assert_array(_texts(announcer.get_toast_box_for_test())).contains(["Press Space to dash through danger"])
	assert_int(hints.queued_count()).is_equal(2)
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_TOWER_REPAIR)).append_failure_message("queued hints are not marked seen until shown").is_false()


func test_hint_wording_names_the_threat_and_the_answer() -> void:
	var hints: RunHints = _make().get_hints_for_test()
	assert_str(hints.text_for(RunHints.ID_TOWER_REPAIR, [])).is_equal("Stand by the Tower to repair it with Scrap")
	assert_str(hints.text_for(RunHints.ID_SKILL_READY, ["Q", "Arrow Storm"])).is_equal("Q: Arrow Storm is ready")
	assert_float(RunHints.HINT_SECONDS).is_less_equal(6.0)


func test_hints_do_not_start_or_run_down_while_paused() -> void:
	var announcer: RunAnnouncer = _make()
	var hints: RunHints = announcer.get_hints_for_test()
	get_tree().paused = true
	hints.request(RunHints.ID_TOWER_REPAIR)
	assert_bool(hints.is_showing()).append_failure_message("a paused game shows no hint").is_false()
	assert_int(hints.queued_count()).is_equal(1)
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_TOWER_REPAIR)).is_false()
	get_tree().paused = false
	hints._pump()
	assert_bool(hints.is_showing()).is_true()
	await get_tree().process_frame
	get_tree().paused = true
	await get_tree().process_frame
	assert_bool(announcer.visible).append_failure_message("the announcer hides behind a menu").is_false()
	get_tree().paused = false
	assert_bool(announcer.visible).is_true()


func test_the_skill_ready_hint_fires_once_when_the_skill_first_reads_ready() -> void:
	var announcer: RunAnnouncer = _make()
	var hints: RunHints = announcer.get_hints_for_test()
	var skill: FakeSkill = auto_free(FakeSkill.new())
	skill.add_to_group(&"battle_skill")
	add_child(skill)
	hints._poll_skill()
	assert_bool(hints.is_showing()).is_false()
	skill.is_ready = true
	hints._poll_skill()
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_SKILL_READY)).is_true()
	assert_array(_texts(announcer.get_toast_box_for_test()).filter(func(t: String) -> bool: return t.ends_with("is ready"))).is_not_empty()
	skill.remove_from_group(&"battle_skill")


func test_tower_repair_hint_needs_scrap_in_hand() -> void:
	var hints: RunHints = _make().get_hints_for_test()
	var scrap: Array[int] = [0]
	hints.scrap_source = func() -> int: return scrap[0]
	hints._on_tower_damaged(30.0, null, 400.0)
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_TOWER_REPAIR)).append_failure_message("no Scrap, no repair hint").is_false()
	scrap[0] = 12
	hints._on_tower_damaged(30.0, null, 370.0)
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_TOWER_REPAIR)).is_true()


func test_first_player_damage_asks_for_the_dash_hint() -> void:
	var hints: RunHints = _make().get_hints_for_test()
	hints._on_player_damaged(0.0, null, 100.0)
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_DASH)).is_false()
	hints._on_player_damaged(8.0, null, 92.0)
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_DASH)).is_true()


func test_touch_builds_use_touch_wording_with_no_key_slots() -> void:
	var hints: RunHints = _make().get_hints_for_test()
	# The touch table is chosen once per process, so check the table itself and the slot rule.
	assert_str(UiStrings.MOBILE_MESSAGES["HINT_DASH"]).is_equal("Tap the Dash button to dash through danger")
	assert_str(UiStrings.MOBILE_MESSAGES["HINT_START"]).not_contains("%s")
	var template: String = UiStrings.MOBILE_MESSAGES["HINT_SKILL_READY"]
	assert_int(template.count("%s")).is_equal(1)
	assert_str(template % ["Arrow Storm"]).is_equal("Arrow Storm is ready: tap the big Battle Skill button")
	assert_object(hints).is_not_null()


func test_elite_and_boss_events_no_longer_queue_a_hint_toast() -> void:
	# PT-UI (D323): they are introduced by a paused explainer card, not a toast.
	var announcer: RunAnnouncer = _make()
	EventBus.emit_elite_spawned(null, "swift")
	EventBus.emit_boss_spawned(null, "warchief", "Goblin Warchief", 2600.0)
	assert_int(announcer.get_hints_for_test().queued_count()).is_equal(0)
	assert_bool(MetaProgress.is_hint_seen("elite")).is_false()
	assert_bool(MetaProgress.is_hint_seen("boss")).is_false()


func test_hints_seen_survives_a_reload_of_the_profile() -> void:
	MetaProgress.mark_hint_seen(RunHints.ID_TOWER_REPAIR)
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()
	assert_bool(MetaProgress.is_hint_seen(RunHints.ID_TOWER_REPAIR)).is_true()
