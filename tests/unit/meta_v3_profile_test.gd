extends GdUnitTestSuite

## Profile schema 3 (WP-META, D252-D254; docs/31 section 7.3, docs/24 section 5).
## Covers: the v2 -> v3 migration (exact refund at the OLD prices, tree reset,
## one-time notice flag, atomic save with a .bak of the old file), v3 field
## reconciliation and clamping, selection persistence and the RunConfig
## hand-off, Battle Skill gating by the tree, and every achievement's
## condition against the run summary / profile counters.
## Every test redirects MetaProgress to a throwaway directory first.

var _dir: String


func before_test() -> void:
	_new_profile_dir()


func after_test() -> void:
	RunConfig.reset_for_test()
	MetaProgress.set_base_path_for_test("user://")


func _new_profile_dir() -> void:
	_dir = "user://__meta_v3_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func _write_profile(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var f: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _read_profile_file(filename: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(_dir.path_join(filename), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


## A realistic v2 profile: a tree the player had spent Cores on.
func _v2_profile() -> Dictionary:
	return {
		"schema_version": 2, "cores": 12, "lifetime_cores": 400,
		"tree_ranks": {"vitality": 3, "long_reach": 2, "second_wind": 1, "war_chest": 1, "lucky_charm": 2},
		"records": {"best_waves_cleared": 6, "best_kills": 150, "best_survival_seconds": 400.0, "runs_settled": 9, "victories": 1},
		"settled_run_ids": ["old_run_1"], "first_hub_seen": true, "first_run_hints_seen": true,
		"flags": {}, "lifetime_kills": 777, "lifetime_scrap_collected": 321,
		"unlocked_achievement_ids": ["goblin_slayer", "hoarder"],
	}


# --- Migration 2 -> 3 -----------------------------------------------------------

## The refund is priced with the v2 table (5 / 10 / 18 / 30), NOT the live one.
## vitality x3 (tier 1): 5 + 8 + 10 = 23; long_reach x2 (tier 3): 18 + 27 = 45;
## second_wind (tier 4): 30; war_chest (tier 4): 30; lucky_charm x2 (tier 2):
## 10 + 15 = 25. Total 153, on top of the 12 Cores already held.
##
## FALSIFICATION (named in the report): pointing `_migrate_2_to_3()` at the live
## `SkillNodeDefinition.TIER_BASE_COST` (8 / 16 / 28 / 45) made the Cores
## assertion read 262 instead of 165.
func test_a_v2_profile_migrates_with_the_exact_v2_refund_and_a_reset_tree() -> void:
	_write_profile(_v2_profile())
	MetaProgress.reload_for_test()

	assert_int(MetaProgress.get_cores()).append_failure_message("12 held + 153 refunded at the v2 prices").is_equal(165)
	assert_int(MetaProgress.get_all_ranks_for_test().size()).append_failure_message("the tree is reset").is_equal(0)
	assert_int(MetaProgress.get_rank("vitality")).is_equal(0)
	assert_bool(MetaProgress.has_v3_notice()).append_failure_message("the one-time Hub notice flag is set").is_true()
	assert_int(MetaProgress.get_v3_refund_amount()).is_equal(153)
	assert_int(MetaProgress.get_lifetime_cores()).append_failure_message("a refund is not earnings").is_equal(400)


func test_migration_keeps_everything_else_in_the_profile() -> void:
	_write_profile(_v2_profile())
	MetaProgress.reload_for_test()
	assert_int(MetaProgress.get_lifetime_kills()).is_equal(777)
	assert_int(MetaProgress.get_lifetime_scrap_collected()).is_equal(321)
	assert_array(MetaProgress.get_unlocked_achievement_ids()).contains_exactly(["goblin_slayer", "hoarder"])
	assert_int(int(MetaProgress.get_records()["victories"])).is_equal(1)
	assert_bool(MetaProgress.is_first_hub_seen()).is_true()
	# The v1.0 fields start at their defaults: no past run is credited.
	assert_str(MetaProgress.get_selected_difficulty()).is_equal("soldier")
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("arrow_storm")
	assert_int(MetaProgress.get_runs_played()).is_equal(0)
	assert_bool(MetaProgress.is_endless_unlocked()).is_false()


func test_migration_is_saved_atomically_and_keeps_a_v2_backup() -> void:
	_write_profile(_v2_profile())
	MetaProgress.reload_for_test()
	MetaProgress.acknowledge_v3_notice() # the Hub's dismissal: a real save point

	var saved: Dictionary = _read_profile_file("profile.json")
	assert_int(int(saved.get("schema_version", 0))).is_equal(3)
	assert_int(int(saved.get("cores", 0))).is_equal(165)
	assert_bool(bool(saved.get("tree_migrated_v3_notice", true))).append_failure_message("acknowledging clears the flag on disk").is_false()
	assert_int((saved["tree_ranks"] as Dictionary).size()).is_equal(0)
	var backup: Dictionary = _read_profile_file("profile.json.bak")
	assert_int(int(backup.get("schema_version", 0))).append_failure_message("the previous file is kept as .bak").is_equal(2)
	assert_bool((backup["tree_ranks"] as Dictionary).has("long_reach")).is_true()


func test_the_notice_flag_survives_a_reload_until_acknowledged() -> void:
	_write_profile(_v2_profile())
	MetaProgress.reload_for_test()
	MetaProgress.settle_run({"run_id": "after_migration", "sim_time_seconds": 60.0}) # any save point
	MetaProgress.reload_for_test()
	assert_bool(MetaProgress.has_v3_notice()).append_failure_message("not acknowledged yet, so still set").is_true()
	assert_int(MetaProgress.get_cores()).append_failure_message("and the refund is not paid twice on reload").is_equal(166)
	MetaProgress.acknowledge_v3_notice()
	MetaProgress.reload_for_test()
	assert_bool(MetaProgress.has_v3_notice()).is_false()


func test_a_v1_profile_also_gets_the_refund_and_notice() -> void:
	_write_profile({"schema_version": 1, "cores": 0, "lifetime_cores": 0, "tree_ranks": {"vitality": 1}, "records": {}, "settled_run_ids": [], "flags": {}})
	MetaProgress.reload_for_test()
	assert_int(MetaProgress.get_cores()).append_failure_message("vitality rank 1 at the v2 tier-1 price").is_equal(5)
	assert_bool(MetaProgress.has_v3_notice()).is_true()


func test_an_empty_v2_tree_still_sets_the_notice_and_refunds_nothing() -> void:
	var p: Dictionary = _v2_profile()
	p["tree_ranks"] = {}
	_write_profile(p)
	MetaProgress.reload_for_test()
	assert_int(MetaProgress.get_cores()).is_equal(12)
	assert_int(MetaProgress.get_v3_refund_amount()).is_equal(0)
	assert_bool(MetaProgress.has_v3_notice()).append_failure_message("the tree was rebuilt either way").is_true()


func test_the_refund_is_clamped_to_the_wallet_cap() -> void:
	var p: Dictionary = _v2_profile()
	p["cores"] = MetaProgress.CORE_WALLET_CAP - 10
	_write_profile(p)
	MetaProgress.reload_for_test()
	assert_int(MetaProgress.get_cores()).is_equal(MetaProgress.CORE_WALLET_CAP)


func test_a_newer_than_known_profile_stays_read_only_and_is_not_migrated() -> void:
	var p: Dictionary = _v2_profile()
	p["schema_version"] = MetaProgress.SCHEMA_VERSION + 1
	p["tree_ranks"] = {"vitality": 1}
	_write_profile(p)
	var before: String = FileAccess.get_file_as_string(_dir.path_join("profile.json"))
	MetaProgress.reload_for_test()
	assert_bool(bool(MetaProgress.get_flags()["read_only_newer_version"])).is_true()
	assert_bool(MetaProgress.buy("vitality")).is_false()
	MetaProgress.settle_run({"run_id": "ro_1", "sim_time_seconds": 600.0})
	assert_str(FileAccess.get_file_as_string(_dir.path_join("profile.json"))).append_failure_message("a newer-version file is never overwritten").is_equal(before)


# --- v3 field reconciliation -----------------------------------------------------

func test_v3_fields_are_clamped_and_unlocked_selections_enforced() -> void:
	_write_profile({
		"schema_version": 3, "cores": 5, "tree_ranks": {},
		"selected_difficulty": "veteran", "selected_battle_skill": "frost_nova", "selected_endless": true,
		"difficulty_victories": {"soldier": -4, "warlord": 2, "bogus": 9},
		"lifetime_boss_kills": {"warchief": -1, "king": 3}, "best_endless_wave": -7,
		"lifetime_elite_kills": -2, "lifetime_repair": "junk", "runs_played": -1,
	})
	MetaProgress.reload_for_test()
	assert_int(MetaProgress.get_difficulty_victories("soldier")).append_failure_message("negative clamps to 0").is_equal(0)
	assert_int(MetaProgress.get_difficulty_victories("warlord")).is_equal(2)
	assert_int(MetaProgress.get_lifetime_boss_kills("warchief")).is_equal(0)
	assert_int(MetaProgress.get_lifetime_boss_kills("king")).is_equal(3)
	assert_int(MetaProgress.get_best_endless_wave()).is_equal(0)
	assert_int(MetaProgress.get_lifetime_elite_kills()).is_equal(0)
	assert_int(MetaProgress.get_runs_played()).is_equal(0)
	assert_bool(MetaProgress.is_endless_unlocked()).append_failure_message("a recorded victory (warlord) unlocks Endless").is_true()
	assert_str(MetaProgress.get_selected_difficulty()).append_failure_message("Veteran needs a Soldier win (clamped to 0): falls back").is_equal("soldier")
	assert_str(MetaProgress.get_selected_battle_skill()).append_failure_message("frost_nova's tree node is not owned").is_equal("arrow_storm")


func test_unknown_selection_ids_fall_back_to_the_defaults() -> void:
	_write_profile({"schema_version": 3, "selected_difficulty": "nightmare", "selected_battle_skill": "meteor"})
	MetaProgress.reload_for_test()
	assert_str(MetaProgress.get_selected_difficulty()).is_equal("soldier")
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("arrow_storm")


func test_a_selected_skill_with_its_node_owned_is_kept() -> void:
	_write_profile({"schema_version": 3, "tree_ranks": {"skill_focus": 1, "frost_nova_unlock": 1}, "selected_battle_skill": "frost_nova"})
	MetaProgress.reload_for_test()
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("frost_nova")


# --- Selection persistence and the RunConfig hand-off ------------------------------

func test_selections_persist_and_reach_run_config() -> void:
	MetaProgress.set_difficulty_victories_for_test("soldier", 1) # opens Veteran and Endless
	MetaProgress.set_rank_for_test("skill_focus", 1)
	MetaProgress.set_rank_for_test("firebomb_unlock", 1)
	assert_bool(MetaProgress.set_selected_difficulty("veteran")).is_true()
	assert_bool(MetaProgress.set_selected_battle_skill("firebomb")).is_true()
	assert_bool(MetaProgress.set_selected_endless(true)).is_true()

	MetaProgress.reload_for_test() # read back from disk
	assert_str(MetaProgress.get_selected_difficulty()).is_equal("veteran")
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("firebomb")
	assert_bool(MetaProgress.get_selected_endless()).is_true()

	RunConfig.reset_for_test()
	MetaProgress.apply_selection_to_run_config()
	assert_str(RunConfig.difficulty_id).is_equal("veteran")
	assert_str(RunConfig.battle_skill_id).is_equal("firebomb")
	assert_bool(RunConfig.endless).is_true()


func test_locked_choices_are_refused() -> void:
	assert_bool(MetaProgress.set_selected_difficulty("veteran")).append_failure_message("Veteran needs a Soldier win").is_false()
	assert_bool(MetaProgress.set_selected_difficulty("warlord")).is_false()
	assert_bool(MetaProgress.set_selected_battle_skill("war_horn")).append_failure_message("War Horn needs its tree node").is_false()
	assert_bool(MetaProgress.set_selected_endless(true)).append_failure_message("Endless needs a win").is_false()
	assert_str(MetaProgress.get_selected_difficulty()).is_equal("soldier")
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("arrow_storm")
	assert_bool(MetaProgress.set_selected_difficulty("recruit")).append_failure_message("Recruit is open").is_true()


func test_battle_skill_nodes_gate_exactly_their_skill() -> void:
	assert_array(MetaProgress.get_unlocked_battle_skills()).contains_exactly(["arrow_storm"])
	assert_str(MetaProgress.get_battle_skill_unlock_node_id("frost_nova")).is_equal("frost_nova_unlock")
	assert_str(MetaProgress.get_battle_skill_unlock_node_id("firebomb")).is_equal("firebomb_unlock")
	assert_str(MetaProgress.get_battle_skill_unlock_node_id("war_horn")).is_equal("war_horn_unlock")
	assert_str(MetaProgress.get_battle_skill_unlock_node_id("arrow_storm")).is_empty()
	MetaProgress.set_rank_for_test("firebomb_unlock", 1)
	assert_bool(MetaProgress.is_battle_skill_unlocked("firebomb")).is_true()
	assert_bool(MetaProgress.is_battle_skill_unlocked("frost_nova")).is_false()
	assert_bool(MetaProgress.is_battle_skill_unlocked("war_horn")).is_false()
	assert_array(MetaProgress.get_unlocked_battle_skills()).contains_exactly(["arrow_storm", "firebomb"])


func test_respec_relocks_a_selected_skill_immediately() -> void:
	MetaProgress.set_rank_for_test("skill_focus", 1)
	MetaProgress.set_rank_for_test("frost_nova_unlock", 1)
	MetaProgress.set_selected_battle_skill("frost_nova")
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("frost_nova")
	MetaProgress.respec()
	assert_str(MetaProgress.get_selected_battle_skill()).append_failure_message("the respec must relock the selected skill at once, not on the next load").is_equal("arrow_storm")
	MetaProgress.apply_selection_to_run_config()
	assert_str(RunConfig.battle_skill_id).is_equal("arrow_storm")
	MetaProgress.reload_for_test()
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("arrow_storm")


func test_a_locked_selected_difficulty_reads_as_soldier() -> void:
	MetaProgress.set_difficulty_victories_for_test("soldier", 1)
	assert_bool(MetaProgress.set_selected_difficulty("veteran")).is_true()
	MetaProgress.set_difficulty_victories_for_test("soldier", 0)
	assert_str(MetaProgress.get_selected_difficulty()).append_failure_message("a locked difficulty must fall back to soldier").is_equal("soldier")
	MetaProgress.apply_selection_to_run_config()
	assert_str(RunConfig.difficulty_id).is_equal("soldier")


func test_hints_seen_persists_and_reconcile_adds_the_key() -> void:
	assert_bool(MetaProgress.is_hint_seen("dash")).is_false()
	MetaProgress.mark_hint_seen("dash")
	MetaProgress.reload_for_test()
	assert_bool(MetaProgress.is_hint_seen("dash")).is_true()
	assert_int(int(MetaProgress.get_profile_for_test()["schema_version"])).is_equal(3)


func test_preview_settlement_matches_settle_run_with_bosses_victory_and_difficulty() -> void:
	var summary: Dictionary = {"run_id": "prev_1", "sim_time_seconds": 600.0, "waves_cleared": 15, "kills": 500, "victory": true,
		"scrap_carried": 55, "elite_kills": 4, "boss_kills": {"warchief": 1, "king": 1}, "difficulty_id": "veteran"}
	var preview: Dictionary = MetaProgress.preview_settlement(summary)
	var before: int = MetaProgress.get_cores()
	var settled: Dictionary = MetaProgress.settle_run(summary)
	assert_int(int(preview["total_cores"])).is_equal(int(settled["total_cores"]))
	assert_int(MetaProgress.get_cores() - before).is_equal(int(preview["total_cores"]))
	assert_int(int(preview["total_cores"])).is_greater(60)


# --- Achievements: conditions against the run summary and the profile counters ---------

## Settles one run on a fresh profile and returns the unlocked achievement ids.
func _unlocked_after(summary: Dictionary) -> Array[String]:
	_new_profile_dir()
	var s: Dictionary = {"run_id": "ach_%d" % randi(), "sim_time_seconds": 60.0}
	s.merge(summary, true)
	MetaProgress.settle_run(s)
	return MetaProgress.get_unlocked_achievement_ids()


func test_each_run_scoped_achievement_unlocks_on_its_condition_only() -> void:
	assert_array(_unlocked_after({"wave_reached": 7})).append_failure_message("wave 7 is short of Veteran").not_contains(["veteran"])
	assert_array(_unlocked_after({"wave_reached": 8})).contains(["veteran"])
	assert_array(_unlocked_after({"victory": true, "tower_health_fraction": 0.4})).not_contains(["keeper_of_the_keep"])
	assert_array(_unlocked_after({"victory": false, "tower_health_fraction": 0.9})).append_failure_message("a defeat never earns Keeper").not_contains(["keeper_of_the_keep"])
	assert_array(_unlocked_after({"victory": true, "tower_health_fraction": 0.6})).contains(["keeper_of_the_keep"])
	assert_array(_unlocked_after({"untouchable_wave": true})).contains(["untouchable"])
	assert_array(_unlocked_after({"untouchable_wave": false})).not_contains(["untouchable"])
	assert_array(_unlocked_after({"player_abilities": 3})).not_contains(["full_arsenal"])
	assert_array(_unlocked_after({"player_abilities": 4})).contains(["full_arsenal"])


func test_victory_achievements_and_the_difficulty_gated_ones() -> void:
	var win: Array[String] = _unlocked_after({"victory": true, "difficulty_id": "soldier"})
	assert_array(win).contains(["sanctified", "founder"])
	assert_array(win).not_contains(["warlord", "regicide"])
	assert_array(_unlocked_after({"victory": true, "difficulty_id": "warlord"})).contains(["warlord"])
	assert_array(_unlocked_after({"victory": true, "difficulty_id": "veteran"})).not_contains(["warlord"])
	assert_array(_unlocked_after({"boss_kills": {"king": 1}, "difficulty_id": "soldier"})).append_failure_message("Regicide needs Veteran or Warlord").not_contains(["regicide"])
	assert_array(_unlocked_after({"boss_kills": {"king": 1}, "difficulty_id": "veteran"})).contains(["regicide"])
	assert_array(_unlocked_after({"boss_kills": {"warchief": 1}})).contains(["warchief_slayer"])


func test_cumulative_achievements_read_the_profile_counters() -> void:
	assert_array(_unlocked_after({"elite_kills": 49})).not_contains(["elite_hunter"])
	assert_array(_unlocked_after({"elite_kills": 50})).contains(["elite_hunter"])
	assert_array(_unlocked_after({"repair_total": 2000})).contains(["mason"])
	assert_array(_unlocked_after({"endless": true, "wave_reached": 20})).contains(["endless_20"])
	assert_array(_unlocked_after({"endless": false, "wave_reached": 20})).append_failure_message("Endless wave 20 needs an Endless run").not_contains(["endless_20"])
	assert_array(_unlocked_after({"kills": 2000})).contains(["marksman", "goblin_slayer"])
	assert_array(_unlocked_after({"scrap_carried": 1000})).contains(["hoarder"])

	_new_profile_dir()
	MetaProgress.set_lifetime_counter_for_test("runs_played", 9)
	MetaProgress.settle_run({"run_id": "tenth", "sim_time_seconds": 10.0})
	assert_array(MetaProgress.get_unlocked_achievement_ids()).append_failure_message("the 10th run played earns Survivor").contains(["survivor"])


func test_progress_reports_current_target_and_fraction_per_achievement() -> void:
	MetaProgress.set_lifetime_counter_for_test("lifetime_repair", 500)
	var progress: Dictionary = MetaProgress.get_achievement_progress("mason")
	assert_float(float(progress["current"])).is_equal(500.0)
	assert_float(float(progress["target"])).is_equal(2000.0)
	assert_float(float(progress["fraction"])).is_equal_approx(0.25, 0.001)
	assert_bool(bool(progress["per_run"])).is_false()
	var per_run: Dictionary = MetaProgress.get_achievement_progress("untouchable")
	assert_bool(bool(per_run["per_run"])).is_true()
	assert_float(float(per_run["fraction"])).is_equal(0.0)
	assert_dict(MetaProgress.get_achievement_progress("no_such_achievement")).is_empty()


## Each of the five card-unlocking achievements opens exactly its card for the Draft.
func test_card_unlocking_achievements_feed_the_draft_unlock_list() -> void:
	MetaProgress.settle_run({"run_id": "cards", "sim_time_seconds": 60.0, "wave_reached": 8, "victory": true, "tower_health_fraction": 0.9, "boss_kills": {"warchief": 1}, "kills": 300})
	var cards: Array[String] = MetaProgress.get_unlocked_card_ids()
	for expected in ["frost_arrows", "storm_bolt", "spiked_palisade", "catapult", "sacred_ground"]:
		assert_array(cards).append_failure_message("%s should be unlocked by this run" % expected).contains([expected])
