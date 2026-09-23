extends GdUnitTestSuite

## D118 (achievements) tests. MASTER_SDLC.md > Provisional Values Register >
## "Meta: Achievements" and > "Meta: Run-End Settlement (prototype)" (the
## Scrap->Cores line, D115). Every test redirects the real `MetaProgress`
## autoload to a throwaway directory first (hard constraint), matching
## meta_progress_settlement_test.gd's own established convention.
##
## Falsifications:
##  1. settle_run() unlocks an achievement the instant its metric crosses
##     threshold, and reports it in the breakdown's own
##     `newly_unlocked_achievements`.
##  2. An already-unlocked achievement is never reported "newly unlocked"
##     again, and never double-applies its perk.
##  3. Lifetime counters (`lifetime_kills`/`lifetime_scrap_collected`)
##     accumulate ACROSS settlements, never reset per run.
##  4. `get_unlocked_card_ids()` returns exactly the unlocked achievements'
##     own `unlocks_card_id`, nothing from a perk-only achievement.
##  5. `has_perk()` is true only once the achievement naming that perk_id is
##     unlocked.
##  6. The three per-run metrics (`run_waves_cleared`/`run_victory`/
##     `run_tower_health_fraction`) read THIS settlement's own run_summary,
##     never a lifetime counter.
##  7. D115: Scrap converts to Cores at floor(scrap_carried / 10), and the
##     settlement bonus (Prospector/Founder) applies to the sum INCLUDING
##     the Scrap line, not before it.
##  8. The six real authored achievements (data/meta/achievements.tres)
##     reference exactly the three real UNLOCK-gated cards and three known
##     perk ids -- a schema sanity check against the live content, not the
##     test fixture used above.
##  9. MetaLoadoutApplier applies each of the three perks (Hoarder/Founder/
##     Marksman) correctly once MetaProgress reports it unlocked.

const AchievementListScript: GDScript = preload("res://src/data/achievement_list.gd")
const AchievementDefinitionScript: GDScript = preload("res://src/data/achievement_definition.gd")
const RealAchievementList: AchievementList = preload("res://data/meta/achievements.tres")
const DraftTestHelpers: GDScript = preload("res://tests/unit/draft_test_helpers.gd")

var _dir: String


func before_test() -> void:
	_dir = "user://__meta_test_achievements_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_achievement_list_for_test(RealAchievementList)
	MetaProgress.set_base_path_for_test("user://")


func _make_achievement(id: String, metric: String, threshold: float, unlocks_card_id: String = "", perk_id: String = "") -> AchievementDefinition:
	var a: AchievementDefinition = AchievementDefinitionScript.new()
	a.id = id
	a.display_name = id.capitalize()
	a.description = "test fixture"
	a.metric = metric
	a.threshold = threshold
	a.unlocks_card_id = unlocks_card_id
	a.perk_id = perk_id
	return a


func _fake_list(achievements: Array[AchievementDefinition]) -> AchievementList:
	var list: AchievementList = AchievementListScript.new()
	list.achievements = achievements
	return list


func _settle(run_id: String, kills: int = 0, scrap_carried: int = 0, waves_cleared: int = 0, victory: bool = false, tower_health_fraction: float = 1.0) -> Dictionary:
	return MetaProgress.settle_run({
		"run_id": run_id, "sim_time_seconds": 0.0, "waves_cleared": waves_cleared, "kills": kills,
		"victory": victory, "abandoned": false, "scrap_carried": scrap_carried,
		"tower_health_fraction": tower_health_fraction,
	})


# --- Falsification 1/2: unlock on threshold, never re-reported -------------

func test_settle_run_unlocks_an_achievement_the_instant_its_metric_crosses_threshold() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([_make_achievement("kill_ten", "lifetime_kills", 10.0, "test_card")]))

	var first: Dictionary = _settle("ach_1", 9)
	assert_bool(MetaProgress.is_achievement_unlocked("kill_ten")).append_failure_message("9 kills must not unlock a 10-kill achievement").is_false()
	assert_array(first["newly_unlocked_achievements"]).is_empty()

	var second: Dictionary = _settle("ach_2", 1) # 9 + 1 = 10, crosses the threshold on THIS settlement
	assert_bool(MetaProgress.is_achievement_unlocked("kill_ten")).is_true()
	var newly: Array = second["newly_unlocked_achievements"]
	assert_int(newly.size()).is_equal(1)
	assert_str(String((newly[0] as Dictionary)["id"])).is_equal("kill_ten")

	var third: Dictionary = _settle("ach_3", 5) # already unlocked -- must never be reported again
	assert_array(third["newly_unlocked_achievements"]).append_failure_message("an already-unlocked achievement must never be reported newly-unlocked twice").is_empty()


# --- Falsification 3: lifetime counters accumulate across settlements ------

func test_lifetime_kills_and_scrap_collected_accumulate_across_settlements() -> void:
	_settle("acc_1", 5, 20)
	_settle("acc_2", 6, 35)
	assert_int(MetaProgress.get_lifetime_kills()).is_equal(11)
	assert_int(MetaProgress.get_lifetime_scrap_collected()).is_equal(55)


# --- Falsification 4/5: card unlocks vs perks -------------------------------

func test_get_unlocked_card_ids_and_has_perk_reflect_only_unlocked_achievements() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([
		_make_achievement("card_one", "lifetime_kills", 5.0, "unlockable_card"),
		_make_achievement("perk_one", "lifetime_kills", 5.0, "", "test_perk"),
		_make_achievement("locked_one", "lifetime_kills", 999.0, "never_reached_card"),
	]))

	assert_array(MetaProgress.get_unlocked_card_ids()).is_empty()
	assert_bool(MetaProgress.has_perk("test_perk")).is_false()

	_settle("unlock_1", 5) # crosses card_one's and perk_one's threshold, not locked_one's

	assert_array(MetaProgress.get_unlocked_card_ids()).append_failure_message("only card_one's own unlocks_card_id must appear").contains(["unlockable_card"])
	assert_int(MetaProgress.get_unlocked_card_ids().size()).append_failure_message("a perk-only achievement must never contribute a card id").is_equal(1)
	assert_bool(MetaProgress.has_perk("test_perk")).is_true()
	assert_bool(MetaProgress.has_perk("never_granted")).is_false()


# --- Falsification 6: per-run metrics never read a lifetime counter --------

func test_run_scoped_metrics_read_only_this_settlements_own_summary() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([
		_make_achievement("wave_five", "run_waves_cleared", 5.0, "waves_card"),
		_make_achievement("win_one", "run_victory", 1.0, "victory_card"),
		_make_achievement("keeper", "run_tower_health_fraction", 0.5, "keeper_card"),
	]))

	_settle("low_1", 0, 0, 2, false, 0.9) # 2 waves, no victory, but healthy Tower
	assert_bool(MetaProgress.is_achievement_unlocked("wave_five")).is_false()
	assert_bool(MetaProgress.is_achievement_unlocked("win_one")).is_false()
	assert_bool(MetaProgress.is_achievement_unlocked("keeper")).append_failure_message("0.9 >= 0.5 must unlock Keeper of the Keep's own condition").is_true()

	_settle("high_1", 0, 0, 6, true, 0.1) # 6 waves + victory this time, Tower nearly dead
	assert_bool(MetaProgress.is_achievement_unlocked("wave_five")).is_true()
	assert_bool(MetaProgress.is_achievement_unlocked("win_one")).is_true()


# --- Falsification 7: D115 Scrap->Cores, composed with the settlement bonus -

func test_scrap_converts_to_cores_at_settlement_and_the_bonus_applies_to_the_full_sum() -> void:
	var no_bonus: Dictionary = _settle("scrap_1", 0, 55) # floor(55/10) = 5
	assert_int(no_bonus["total_cores"]).is_equal(5)

	_grant_prospector_rank_1()
	var with_bonus: Dictionary = _settle("scrap_2", 0, 55) # floor(5 * 1.15) = 5 (Cores this small don't move) -- use a bigger Scrap figure to see the bonus
	assert_int(with_bonus["total_cores"]).is_equal(5)

	var bigger: Dictionary = _settle("scrap_3", 0, 200) # floor(200/10) = 20 -> floor(20 * 1.15) = 23
	assert_int(bigger["total_cores"]).append_failure_message("Prospector's bonus must apply to the subtotal INCLUDING the Scrap line, not before it").is_equal(23)


func _grant_prospector_rank_1() -> void:
	MetaProgress.settle_run({"run_id": "grant_for_scholar", "sim_time_seconds": 1200.0, "waves_cleared": 0, "kills": 0, "victory": false, "abandoned": false})
	MetaProgress.buy("scholar")
	MetaProgress.buy("prospector")


# --- Falsification 8: the six real authored achievements -------------------

func test_the_six_real_achievements_reference_exactly_the_three_unlock_gated_cards_and_three_known_perks() -> void:
	assert_int(RealAchievementList.achievements.size()).is_equal(6)
	var card_ids: Array[String] = []
	var perk_ids: Array[String] = []
	for a in RealAchievementList.achievements:
		assert_bool(a.unlocks_card_id != "" and a.perk_id != "").append_failure_message("'%s' names both a card and a perk -- exactly one is allowed" % a.id).is_false()
		assert_bool(a.unlocks_card_id == "" and a.perk_id == "").append_failure_message("'%s' names neither a card nor a perk" % a.id).is_false()
		if a.unlocks_card_id != "":
			card_ids.append(a.unlocks_card_id)
		if a.perk_id != "":
			perk_ids.append(a.perk_id)
	card_ids.sort()
	perk_ids.sort()
	assert_array(card_ids).is_equal(["multishot", "piercing_arrows", "tower_volley"])
	assert_array(perk_ids).is_equal(["bonus_reroll", "settlement_cores_bonus", "weapon_damage_bonus"])


# --- Falsification 9: MetaLoadoutApplier applies each perk ------------------

func test_hoarder_perk_grants_one_extra_draft_reroll() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([_make_achievement("hoarder", "lifetime_scrap_collected", 1.0, "", "bonus_reroll")]))
	_settle("hoarder_1", 0, 1)
	assert_bool(MetaProgress.has_perk("bonus_reroll")).is_true()

	var draft: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(draft)
	MetaLoadoutApplier.apply(MetaLoadout.new(), null, null, null, null, draft, null)
	assert_int(draft.get_rerolls_remaining()).append_failure_message("Hoarder's perk must add +1 to the baseline 1 reroll").is_equal(2)


func test_founder_perk_adds_five_percent_settlement_cores() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([_make_achievement("founder", "run_victory", 1.0, "", "settlement_cores_bonus")]))
	_settle("founder_1", 0, 0, 0, true) # unlocks Founder this same settlement

	var breakdown: Dictionary = _settle("founder_2", 0, 200) # floor(200/10)=20 -> floor(20*1.05)=21
	assert_int(breakdown["total_cores"]).is_equal(21)


func test_marksman_perk_adds_five_percent_player_weapon_damage() -> void:
	MetaProgress.set_achievement_list_for_test(_fake_list([_make_achievement("marksman", "lifetime_kills", 1.0, "", "weapon_damage_bonus")]))
	_settle("marksman_1", 1)
	assert_bool(MetaProgress.has_perk("weapon_damage_bonus")).is_true()

	var shooter: Node2D = auto_free(Node2D.new()) as Node2D
	add_child(shooter)
	var weapon: AutoWeapon = AutoWeapon.new()
	# A round base (100, not the real Handgun's 10) sidesteps int-rounding
	# ambiguity at the exact .5 boundary a real 10 x 1.05 = 10.5 would hit --
	# see MetaLoadoutApplier's own comment on why BandedValue.value is int.
	var weapon_def: WeaponDefinition = (load("res://data/weapons/handgun.tres") as WeaponDefinition).duplicate(true)
	weapon_def.damage_band.value = 100
	weapon.definition = weapon_def
	shooter.add_child(weapon)
	auto_free(weapon)
	MetaLoadoutApplier.apply(MetaLoadout.new(), null, null, weapon, null, null, null)
	assert_float(weapon.get_effective_damage_per_shot()).append_failure_message("Marksman's perk must raise the player's damage by exactly 5%").is_equal_approx(105.0, 0.01)
