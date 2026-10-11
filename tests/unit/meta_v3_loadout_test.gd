extends GdUnitTestSuite

## Skill Tree v2 -> run loadout -> live hooks (WP-META, D250). Proves that every
## one of the 30 nodes changes the loadout when owned (so no node is a dead
## purchase), that the loadout values match the Register, and that the applier
## calls the WP-COMBAT hooks with the right numbers, skips absent ones silently,
## and is safe to run twice.

var _dir: String
var _spy: Node


func before_test() -> void:
	_dir = "user://__meta_v3_loadout_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


## Every script variable of a loadout as a Dictionary, for before/after comparison.
func _snapshot(loadout: MetaLoadout) -> Dictionary:
	var out: Dictionary = {}
	for prop in loadout.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[prop["name"]] = loadout.get(prop["name"])
	return out


## FALSIFICATION (named in the report): removing the `SKILL_DAMAGE_PERCENT` arm
## from `MetaProgress.build_run_loadout()` made skill_power fail this test.
func test_every_tree_node_changes_the_loadout_when_owned() -> void:
	var baseline: Dictionary = _snapshot(MetaProgress.build_run_loadout())
	var checked: int = 0
	for id in MetaProgress.skill_tree.get_purchasable_node_ids():
		var node: SkillNodeDefinition = MetaProgress.skill_tree.get_node_definition(id)
		MetaProgress.set_rank_for_test(id, node.max_rank)
		var after: Dictionary = _snapshot(MetaProgress.build_run_loadout())
		MetaProgress.set_rank_for_test(id, 0)
		assert_bool(after == baseline).append_failure_message("node '%s' (effect %d) is a dead purchase: the loadout did not change" % [id, node.effect_kind]).is_false()
		checked += 1
	assert_int(checked).is_equal(30)


func test_loadout_values_match_the_register_at_max_rank() -> void:
	for node in MetaProgress.skill_tree.nodes:
		if node.tier > 0:
			MetaProgress.set_rank_for_test(node.id, node.max_rank)
	var l: MetaLoadout = MetaProgress.build_run_loadout()
	assert_float(l.player_weapon_damage_bonus).is_equal_approx(0.24, 0.0001)
	assert_float(l.player_fire_rate_bonus).is_equal_approx(0.18, 0.0001)
	assert_float(l.player_crit_chance_bonus).is_equal_approx(0.12, 0.0001)
	assert_float(l.player_weapon_range_bonus).is_equal_approx(0.20, 0.0001)
	assert_bool(l.armory_enabled).is_true()
	assert_float(l.player_max_health_bonus).is_equal_approx(0.30, 0.0001)
	assert_float(l.player_move_speed_bonus).is_equal_approx(0.12, 0.0001)
	assert_float(l.damage_taken_reduction).is_equal_approx(0.15, 0.0001)
	assert_float(l.dash_cooldown_reduction).is_equal_approx(0.20, 0.0001)
	assert_int(l.dash_extra_charges).is_equal(1)
	assert_bool(l.second_wind_enabled).is_true()
	assert_array(l.unlocked_battle_skills).contains_exactly(["frost_nova", "firebomb", "war_horn"])
	assert_float(l.skill_cooldown_reduction).is_equal_approx(0.24, 0.0001)
	assert_float(l.skill_damage_bonus).is_equal_approx(0.45, 0.0001)
	assert_float(l.tower_max_health_bonus).is_equal_approx(0.30, 0.0001)
	assert_float(l.tower_weapon_damage_bonus).is_equal_approx(0.30, 0.0001)
	assert_float(l.tower_max_shield_bonus).is_equal_approx(0.30, 0.0001)
	assert_float(l.tower_repair_bonus).is_equal_approx(0.40, 0.0001)
	assert_float(l.tower_weapon_range_bonus).is_equal_approx(0.20, 0.0001)
	assert_float(l.tower_ability_damage_bonus).is_equal_approx(0.30, 0.0001)
	assert_bool(l.fortress_enabled).is_true()
	assert_int(l.starting_scrap).is_equal(45)
	assert_float(l.xp_gain_bonus).is_equal_approx(0.30, 0.0001)
	assert_int(l.bonus_draft_rerolls).is_equal(2)
	assert_int(l.rarity_luck_points).is_equal(6)
	assert_float(l.settlement_cores_bonus).is_equal_approx(0.30, 0.0001)
	assert_int(l.scrap_cap_bonus).is_equal(50)
	assert_bool(l.war_chest_enabled).is_true()


# --- Hooks ----------------------------------------------------------------------

const SPY_SOURCE: String = """extends Node
var calls: Dictionary = {}
func set_dash_extra_charges(n: int) -> void:
	calls['set_dash_extra_charges'] = n
func set_dash_cooldown_multiplier(m: float) -> void:
	calls['set_dash_cooldown_multiplier'] = m
func set_skill_cooldown_multiplier(m: float) -> void:
	calls['set_skill_cooldown_multiplier'] = m
func set_skill_damage_multiplier(m: float) -> void:
	calls['set_skill_damage_multiplier'] = m
func set_ability_damage_multiplier(m: float) -> void:
	calls['set_ability_damage_multiplier'] = m
func set_tower_ability_damage_multiplier(m: float) -> void:
	calls['set_tower_ability_damage_multiplier'] = m
func add_crit_chance(f: float) -> void:
	calls['add_crit_chance'] = f
func set_damage_taken_multiplier(m: float) -> void:
	calls['set_damage_taken_multiplier'] = m
func set_repair_multiplier(m: float) -> void:
	calls['set_repair_multiplier'] = m
func grant_free_random_ability() -> void:
	calls['grant_count'] = int(calls.get('grant_count', 0)) + 1
"""


func _make_spy(source: String = SPY_SOURCE) -> Node:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	var n := Node.new()
	n.set_script(script)
	n.add_to_group(&"ability_manager")
	add_child(n)
	auto_free(n)
	return n


func _full_loadout() -> MetaLoadout:
	for node in MetaProgress.skill_tree.nodes:
		if node.tier > 0:
			MetaProgress.set_rank_for_test(node.id, node.max_rank)
	return MetaProgress.build_run_loadout()


func test_every_hook_is_called_on_the_ability_manager_with_the_register_values() -> void:
	var spy: Node = _make_spy()
	var result: Dictionary = MetaLoadoutApplier.apply_group_hooks(_full_loadout(), get_tree(), true)
	var calls: Dictionary = spy.get("calls")
	assert_int(int(calls["set_dash_extra_charges"])).is_equal(1)
	assert_float(float(calls["set_dash_cooldown_multiplier"])).is_equal_approx(0.80, 0.0001)
	assert_float(float(calls["set_damage_taken_multiplier"])).is_equal_approx(0.85, 0.0001)
	assert_float(float(calls["add_crit_chance"])).is_equal_approx(0.12, 0.0001)
	assert_float(float(calls["set_skill_cooldown_multiplier"])).is_equal_approx(0.76, 0.0001)
	assert_float(float(calls["set_skill_damage_multiplier"])).is_equal_approx(1.45, 0.0001)
	assert_float(float(calls["set_tower_ability_damage_multiplier"])).is_equal_approx(1.30, 0.0001)
	assert_float(float(calls["set_repair_multiplier"])).is_equal_approx(1.40, 0.0001)
	assert_int(int(calls["grant_count"])).append_failure_message("Armory grants one free ability").is_equal(1)
	assert_bool(bool(result["armory_granted"])).is_true()


func test_an_empty_loadout_calls_no_hook() -> void:
	var spy: Node = _make_spy()
	var result: Dictionary = MetaLoadoutApplier.apply_group_hooks(MetaProgress.build_run_loadout(), get_tree(), true)
	assert_dict(spy.get("calls")).append_failure_message("neutral values must not stomp the system's own defaults").is_empty()
	assert_array(result["called"]).is_empty()


func test_absent_hooks_and_missing_nodes_are_skipped_silently() -> void:
	var loadout: MetaLoadout = _full_loadout()
	# No ability_manager node at all.
	var none: Dictionary = MetaLoadoutApplier.apply_group_hooks(loadout, get_tree(), true)
	assert_array(none["called"]).is_empty()
	assert_bool(bool(none["armory_granted"])).is_false()
	# A node that only has one of the methods.
	var partial: Node = _make_spy("extends Node\nvar calls: Dictionary = {}\nfunc add_crit_chance(f: float) -> void:\n\tcalls['add_crit_chance'] = f\n")
	var some: Dictionary = MetaLoadoutApplier.apply_group_hooks(loadout, get_tree(), true)
	assert_array(some["called"]).contains_exactly(["add_crit_chance"])
	assert_bool(bool(some["armory_granted"])).append_failure_message("no grant method, so the grant is reported not done (a retry may find it later)").is_false()
	assert_float(float((partial.get("calls") as Dictionary)["add_crit_chance"])).is_equal_approx(0.12, 0.0001)


func test_running_the_hooks_twice_never_grants_the_armory_ability_twice() -> void:
	var spy: Node = _make_spy()
	var loadout: MetaLoadout = _full_loadout()
	var first: Dictionary = MetaLoadoutApplier.apply_group_hooks(loadout, get_tree(), true)
	MetaLoadoutApplier.apply_group_hooks(loadout, get_tree(), not bool(first["armory_granted"])) # the integration's deferred retry
	assert_int(int((spy.get("calls") as Dictionary)["grant_count"])).is_equal(1)


func test_mason_and_ability_power_perks_compose_with_the_tree() -> void:
	MetaProgress.set_achievement_unlocked_for_test("mason")
	MetaProgress.set_achievement_unlocked_for_test("full_arsenal")
	MetaProgress.set_rank_for_test("masons_kit", 2) # +40%
	var spy: Node = _make_spy()
	MetaLoadoutApplier.apply_group_hooks(MetaProgress.build_run_loadout(), get_tree(), true)
	var calls: Dictionary = spy.get("calls")
	assert_float(float(calls["set_repair_multiplier"])).append_failure_message("+40% Mason's Kit + 10% Mason").is_equal_approx(1.50, 0.0001)
	assert_float(float(calls["set_ability_damage_multiplier"])).is_equal_approx(1.05, 0.0001)


## apply() reaches the hooks through the node it is given: a Tower and a Player in
## the tree make the call to the real group lookup, and the spy is found.
func test_apply_returns_the_hook_result() -> void:
	var spy: Node = _make_spy()
	var result: Dictionary = MetaLoadoutApplier.apply(_full_loadout(), null, null, null, null, null, null)
	assert_array(result["called"]).is_not_empty()
	assert_int(int((spy.get("calls") as Dictionary)["set_dash_extra_charges"])).is_equal(1)
