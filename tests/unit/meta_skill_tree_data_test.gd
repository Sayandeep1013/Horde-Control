extends GdUnitTestSuite

## Skill Tree data model tests (Meta layer core, build brief item 6).
## MASTER_SDLC.md > Provisional Values Register > "Meta: Skill Tree costs":
## "Rank r of a tier-t node costs base(t) x (1 + 0.5 x (r - 1)), rounded;
## base 5 / 10 / 18 / 30 Cores for tiers 1-4; the root ... is free and always
## owned." Proves the price formula as a pure static function, independent of
## MetaProgress, and proves data/meta/skill_tree.tres's own shape (18 nodes +
## the root, unique ids, every prerequisite resolves) -- docs/18 section 4.2.

var _tree: SkillTreeDefinition


func before_test() -> void:
	_tree = load("res://data/meta/skill_tree.tres")


# --- Price formula (Register > "Meta: Skill Tree costs") --------------------

func test_tier_1_price_progression() -> void:
	# base 5: rank1 = 5*(1+0)=5, rank2 = 5*(1+0.5)=7.5 -> rounds to 8, rank3 = 5*(1+1.0)=10.
	assert_int(SkillNodeDefinition.price_for_rank(1, 1)).is_equal(5)
	assert_int(SkillNodeDefinition.price_for_rank(1, 2)).is_equal(8)
	assert_int(SkillNodeDefinition.price_for_rank(1, 3)).is_equal(10)


func test_every_tier_base_cost_at_rank_1() -> void:
	assert_int(SkillNodeDefinition.price_for_rank(1, 1)).is_equal(5)
	assert_int(SkillNodeDefinition.price_for_rank(2, 1)).is_equal(10)
	assert_int(SkillNodeDefinition.price_for_rank(3, 1)).is_equal(18)
	assert_int(SkillNodeDefinition.price_for_rank(4, 1)).is_equal(30)


func test_tier_4_price_progression() -> void:
	# base 30: rank1 = 30, rank2 = 30*1.5 = 45.
	assert_int(SkillNodeDefinition.price_for_rank(4, 1)).is_equal(30)
	assert_int(SkillNodeDefinition.price_for_rank(4, 2)).is_equal(45)


## FALSIFICATION (named in the report): temporarily changing `0.5` to `0.4`
## in src/data/skill_node_definition.gd's price_for_rank() made
## test_tier_1_price_progression's rank-2 assertion fail (expected 8, got 7),
## proving this test actually exercises the formula rather than a
## tautological restatement. Reverted after confirming the failure.
func test_tier_0_and_out_of_range_tiers_are_free_not_erroring() -> void:
	assert_int(SkillNodeDefinition.price_for_rank(0, 1)).append_failure_message("the root (tier 0) must always be free").is_equal(0)
	assert_int(SkillNodeDefinition.price_for_rank(5, 1)).append_failure_message("a tier with no authored base cost must not crash the caller").is_equal(0)


# --- Authored tree shape (docs/18 section 4.2) -------------------------------

func test_tree_has_the_root_plus_eighteen_nodes() -> void:
	assert_int(_tree.nodes.size()).append_failure_message("docs/18 section 4.2: three branches of six nodes each, plus the root").is_equal(19)


func test_every_node_id_is_unique() -> void:
	var seen: Dictionary = {}
	for n in _tree.nodes:
		assert_bool(seen.has(n.id)).append_failure_message("duplicate node id '%s'" % n.id).is_false()
		seen[n.id] = true


func test_every_prerequisite_resolves_to_a_real_authored_node() -> void:
	for n in _tree.nodes:
		for prereq in n.prerequisite_ids:
			assert_object(_tree.get_node_definition(prereq)).append_failure_message("node '%s' names unknown prerequisite '%s'" % [n.id, prereq]).is_not_null()


func test_root_is_tier_zero() -> void:
	var root: SkillNodeDefinition = _tree.get_node_definition(_tree.root_id)
	assert_object(root).is_not_null()
	assert_int(root.tier).is_equal(0)


## The three tier-3 "convergence" nodes each require BOTH of their branch's
## tier-2 siblings (docs/18 section 4.1) -- proven directly against the
## authored data rather than assumed.
func test_tier_3_convergence_nodes_require_two_prerequisites() -> void:
	for id in ["long_reach", "watchtower", "deep_pockets"]:
		var node: SkillNodeDefinition = _tree.get_node_definition(id)
		assert_object(node).append_failure_message("expected an authored '%s' node" % id).is_not_null()
		assert_int(node.prerequisite_ids.size()).append_failure_message("'%s' should converge on two tier-2 siblings" % id).is_equal(2)


func test_get_all_node_ids_includes_root_and_every_node() -> void:
	var ids: Array[String] = _tree.get_all_node_ids()
	assert_int(ids.size()).is_equal(19)
	assert_bool(ids.has("root")).is_true()
	assert_bool(ids.has("second_wind")).is_true()
	assert_bool(ids.has("war_chest")).is_true()
