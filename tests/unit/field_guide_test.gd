extends GdUnitTestSuite

## The Field Guide (PT-UI, docs/33 A3; D322): its entries are built from the game's own data
## (so a page can never disagree with the game), undiscovered ones read "???", and discoveries
## persist in the profile as an additive id list (no schema bump). Every test redirects
## MetaProgress to a throwaway directory first.

var _dir: String


func before_test() -> void:
	_dir = "user://__field_guide_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func _entry(id: String) -> Dictionary:
	return FieldGuideCatalog.find_entry(id)


# --- entries come from data ----------------------------------------------------------------------

func test_every_tab_has_entries_and_every_id_is_unique() -> void:
	var ids: Dictionary = {}
	for tab in FieldGuideCatalog.Tab.values():
		var list: Array[Dictionary] = FieldGuideCatalog.entries(tab)
		assert_int(list.size()).append_failure_message("tab %s is empty" % FieldGuideCatalog.tab_name(tab)).is_greater(0)
		for entry: Dictionary in list:
			assert_bool(ids.has(entry["id"])).append_failure_message("duplicate entry id %s" % entry["id"]).is_false()
			ids[entry["id"]] = true


func test_every_entry_has_a_name_an_effect_a_symbol_and_no_raw_keys() -> void:
	for entry: Dictionary in FieldGuideCatalog.all_entries():
		var id: String = String(entry["id"])
		assert_str(String(entry["name"])).append_failure_message("%s has no name" % id).is_not_empty()
		assert_str(String(entry["effect"])).append_failure_message("%s has no effect text" % id).is_not_empty()
		assert_bool(AbilityDisplay.has_icon(String(entry["icon"]))).append_failure_message("%s has no icon icon_%s.png" % [id, entry["icon"]]).is_true()
		for field in ["name", "helps", "hurts", "effect", "tip", "hint"]:
			var text: String = String(entry[field])
			assert_bool(text.contains("FG_") or text.contains("%s") or text.contains("%d")).append_failure_message("%s.%s shows a raw key or an unfilled slot: %s" % [id, field, text]).is_false()


func test_the_new_playtest_ids_have_entries() -> void:
	for id in ["diagonal_arrows", "rear_arrow", "ricochet", "lightning_sprite", "meteor_shower", "blade_circle", "shadow_step", "goblin_shaman", "juggernaut", "bridge", "water"]:
		assert_bool(_entry(id).is_empty()).append_failure_message("no Field Guide entry for %s" % id).is_false()
	assert_str(String(_entry("juggernaut")["name"])).is_equal("Gutbarrel the Juggernaut")


func test_an_ability_page_quotes_the_ability_catalog_live() -> void:
	var effect: String = String(_entry("whirling_axes")["effect"])
	assert_str(effect).contains(AbilityCatalog.describe("whirling_axes", 1))
	assert_str(effect).contains(AbilityCatalog.describe("whirling_axes", AbilityIds.MAX_ABILITY_LEVEL))


func test_a_passive_page_is_the_upgrade_definitions_own_text() -> void:
	var def: UpgradeDefinition = load("res://data/upgrades/rapid_fire.tres") as UpgradeDefinition
	var entry: Dictionary = _entry("rapid_fire")
	var effect: String = def.effect_description.split(":", true, 1)[1].strip_edges()
	assert_str(String(entry["effect"]).to_lower()).is_equal(effect.to_lower())
	assert_str(String(entry["name"])).is_equal(def.effect_description.split(":", true, 1)[0].strip_edges())
	assert_str(String(entry["tip"])).contains(str(def.max_rank))


func test_an_enemy_page_reads_the_enemy_definition() -> void:
	var def: EnemyDefinition = load("res://data/enemies/tower_seeker.tres") as EnemyDefinition
	var effect: String = String(_entry("tower_seeker")["effect"])
	assert_str(effect).contains("%d HP" % def.health_band.value)
	assert_str(effect).contains("Hits for %d" % def.attack_profile.damage_per_hit_or_tick)
	# Change the data and the page follows (restored after).
	var original: int = def.health_band.value
	def.health_band.value = original + 7
	assert_str(String(_entry("tower_seeker")["effect"])).contains("%d HP" % (original + 7))
	def.health_band.value = original


func test_a_boss_page_reads_its_behaviour_constants() -> void:
	var effect: String = String(_entry("goblin_warchief")["effect"])
	assert_str(effect).contains(str(int(WarchiefBehavior.SLAM_RADIUS_PX)))
	assert_str(effect).contains(str(int(WarchiefBehavior.SLAM_DAMAGE)))
	var king: String = String(_entry("bombardier_king")["effect"])
	assert_str(king).contains(str(int(KingBehavior.SIEGE_DAMAGE)))


func test_arena_pages_read_the_arena_constants() -> void:
	assert_str(String(_entry("powder_keg")["effect"])).contains(str(int(ArenaKeg.BLAST_RADIUS_PX)))
	assert_str(String(_entry("powder_keg")["effect"])).contains(str(int(ArenaKeg.ENEMY_DAMAGE)))
	assert_str(String(_entry("shrine")["effect"])).contains(str(int(ArenaShrine.LIFETIME_SECONDS)))
	assert_str(String(_entry("spike_trap")["effect"])).contains(str(int(ArenaSpikeTrap.DAMAGE)))


func test_pacts_and_blessings_use_the_event_controllers_live_numbers() -> void:
	for pact in RunEvents.PACT_IDS:
		assert_str(String(_entry(pact)["effect"])).is_equal(EventDraftController.pact_effect(pact))
	assert_str(String(_entry("mend")["effect"])).contains(str(int(round(RunEvents.MEND_HEAL_FRACTION * 100.0))))
	assert_str(String(_entry("blood_pact")["effect"])).contains(str(int(round(RunEvents.PACT_COST_FRACTION * 100.0))))


func test_every_entry_has_helps_or_hurts() -> void:
	for entry: Dictionary in FieldGuideCatalog.all_entries():
		assert_bool(String(entry["helps"]) != "" or String(entry["hurts"]) != "").append_failure_message("%s says neither how it helps nor how it hurts" % entry["id"]).is_true()


# --- discovery -------------------------------------------------------------------------------------

func test_a_fresh_profile_knows_only_the_starting_things() -> void:
	assert_bool(MetaProgress.is_discovered("flame_arrows")).is_false()
	assert_bool(FieldGuideCatalog.is_known(_entry("flame_arrows"))).is_false()
	assert_bool(FieldGuideCatalog.is_known(_entry("arrow_storm"))).append_failure_message("the starting Battle Skill is known from the start").is_true()
	assert_bool(FieldGuideCatalog.is_known(_entry("champion_ranger"))).append_failure_message("an unlocked Champion is known").is_true()
	assert_bool(FieldGuideCatalog.is_known(_entry("champion_warden"))).append_failure_message("a locked Champion is not").is_false()


func test_an_undiscovered_entry_reads_question_marks_until_met() -> void:
	var guide: FieldGuideScreen = auto_free(FieldGuideScreen.new())
	add_child(guide)
	guide.open(FieldGuideCatalog.Tab.ABILITIES)
	guide._show_entry("flame_arrows")
	assert_str(guide.get_detail_name()).is_equal("???")
	assert_str(guide.get_detail_effect()).contains("Not met yet")
	assert_str(guide.get_detail_effect()).not_contains("dps")
	FieldGuideCatalog.note_seen("flame_arrows")
	guide.open(FieldGuideCatalog.Tab.ABILITIES)
	guide._show_entry("flame_arrows")
	assert_str(guide.get_detail_name()).is_equal("Flame Arrows")
	assert_str(guide.get_detail_helps()).is_not_empty()
	assert_str(guide.get_detail_tip()).is_not_empty()
	assert_str(guide.get_detail_effect()).contains("dps")


func test_a_locked_tile_is_a_locked_selectable() -> void:
	var guide: FieldGuideScreen = auto_free(FieldGuideScreen.new())
	add_child(guide)
	guide.open(FieldGuideCatalog.Tab.ABILITIES)
	var overlay: SelectableState = SelectableState.of(guide.get_tile("ricochet"))
	assert_int(overlay.get_state()).is_equal(SelectableState.State.LOCKED)
	guide.get_tile("ricochet").pressed.emit()
	assert_str(guide.get_selected_id()).append_failure_message("a locked tile cannot be pinned").is_equal("")
	assert_str(guide.get_shown_id()).append_failure_message("pressing it still answers: the page explains").is_equal("ricochet")
	assert_str(guide.get_detail_name()).is_equal("???")
	assert_bool(overlay.visible_cues()["padlock"]).is_true()


func test_a_met_tile_pins_as_selected_and_stays_when_another_is_focused() -> void:
	FieldGuideCatalog.note_seen("flame_arrows")
	FieldGuideCatalog.note_seen("whirling_axes")
	var guide: FieldGuideScreen = auto_free(FieldGuideScreen.new())
	add_child(guide)
	guide.open(FieldGuideCatalog.Tab.ABILITIES)
	guide.get_tile("flame_arrows").pressed.emit()
	assert_int(SelectableState.of(guide.get_tile("flame_arrows")).get_state()).is_equal(SelectableState.State.SELECTED)
	SelectableState.of(guide.get_tile("whirling_axes")).set_focused(true)
	assert_int(SelectableState.of(guide.get_tile("flame_arrows")).get_state()).append_failure_message("a pinned entry stays SELECTED while focus is elsewhere").is_equal(SelectableState.State.SELECTED)
	assert_int(SelectableState.of(guide.get_tile("whirling_axes")).get_state()).is_equal(SelectableState.State.FOCUSED)


func test_discovery_persists_additively_without_a_schema_bump() -> void:
	MetaProgress.mark_discovered("ricochet")
	MetaProgress.mark_discovered("ricochet") # idempotent
	MetaProgress.mark_discovered("bridge")
	MetaProgress.mark_explainer_seen("shrine")
	MetaProgress.settle_run({"run_id": "save_%d" % randi(), "sim_time_seconds": 0.0, "victory": false, "difficulty_id": "soldier"}) # saves
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()
	assert_bool(MetaProgress.is_discovered("ricochet")).is_true()
	assert_bool(MetaProgress.is_discovered("bridge")).is_true()
	assert_bool(MetaProgress.is_explainer_seen("shrine")).is_true()
	assert_int(MetaProgress.get_discovered_ids().count("ricochet")).is_equal(1)
	assert_int(int(MetaProgress.get_profile_for_test()["schema_version"])).append_failure_message("additive keys: no schema bump").is_equal(MetaProgress.SCHEMA_VERSION)


func test_an_old_profile_without_the_new_keys_loads_clean_and_junk_ids_are_dropped() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var file := FileAccess.open(_dir + "profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": MetaProgress.SCHEMA_VERSION, "cores": 5, "discovered_ids": ["a", "a", "", "b"]}))
	file.close()
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()
	assert_array(MetaProgress.get_discovered_ids()).is_equal(["a", "b"])
	assert_bool(MetaProgress.is_explainer_seen("anything")).is_false()
	assert_int(MetaProgress.get_cores()).is_equal(5)


func test_a_card_shown_in_a_draft_marks_its_ability_discovered() -> void:
	var def: UpgradeDefinition = load("res://data/upgrades/whirling_axes.tres") as UpgradeDefinition
	var card: DraftCardView = auto_free(DraftCardView.new())
	add_child(card)
	card.setup(def, 0)
	assert_bool(MetaProgress.is_discovered(def.ability_id if def.ability_id != "" else def.unique_id)).is_true()
	assert_bool(card.get_icon_rect().texture != null).is_true()
	assert_int(int(card.get_icon_rect().custom_minimum_size.x)).append_failure_message("the symbol is at least 64 px").is_greater_equal(64)


func test_a_card_with_no_icon_falls_back_to_the_pool_glyph() -> void:
	var def: UpgradeDefinition = (load("res://data/upgrades/whirling_axes.tres") as UpgradeDefinition).duplicate() as UpgradeDefinition
	def.unique_id = "no_such_icon_xyz"
	def.ability_id = ""
	var card: DraftCardView = auto_free(DraftCardView.new())
	add_child(card)
	card.setup(def, 0)
	assert_object(card.get_icon_rect().texture).is_not_null()
	assert_bool(AbilityDisplay.has_icon("no_such_icon_xyz")).is_false()
