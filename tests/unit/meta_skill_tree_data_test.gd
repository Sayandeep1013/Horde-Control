extends GdUnitTestSuite

## Skill Tree data model tests (Meta layer core, build brief item 6).
## MASTER_SDLC.md > Provisional Values Register > "Meta: Skill Tree costs":
## "Rank r of a tier-t node costs base(t) x (1 + 0.5 x (r - 1)), rounded;
## base 8 / 16 / 28 / 45 Cores for tiers 1-4 (v2, D250); the root ... is free
## and always owned." Proves the price formula as a pure static function,
## independent of MetaProgress, and proves data/meta/skill_tree.tres's own
## shape (v2: 30 nodes + the root in five branches, unique ids, every
## prerequisite resolves, the full tree's cost) -- docs/18 section 4.2.

var _tree: SkillTreeDefinition


func before_test() -> void:
	_tree = load("res://data/meta/skill_tree.tres")


# --- Price formula (Register > "Meta: Skill Tree costs") --------------------

func test_tier_1_price_progression() -> void:
	# base 8: rank1 = 8, rank2 = 8*1.5 = 12, rank3 = 8*2.0 = 16.
	assert_int(SkillNodeDefinition.price_for_rank(1, 1)).is_equal(8)
	assert_int(SkillNodeDefinition.price_for_rank(1, 2)).is_equal(12)
	assert_int(SkillNodeDefinition.price_for_rank(1, 3)).is_equal(16)


func test_every_tier_base_cost_at_rank_1() -> void:
	assert_int(SkillNodeDefinition.price_for_rank(1, 1)).is_equal(8)
	assert_int(SkillNodeDefinition.price_for_rank(2, 1)).is_equal(16)
	assert_int(SkillNodeDefinition.price_for_rank(3, 1)).is_equal(28)
	assert_int(SkillNodeDefinition.price_for_rank(4, 1)).is_equal(45)


func test_tier_4_price_progression() -> void:
	# base 45: rank1 = 45, rank2 = 45*1.5 = 67.5 -> rounds to 68.
	assert_int(SkillNodeDefinition.price_for_rank(4, 1)).is_equal(45)
	assert_int(SkillNodeDefinition.price_for_rank(4, 2)).is_equal(68)


## FALSIFICATION (named in the report): temporarily changing `0.5` to `0.4`
## in src/data/skill_node_definition.gd's price_for_rank() made
## test_tier_1_price_progression's rank-2 assertion fail (expected 12, got 11),
## proving this test actually exercises the formula rather than a
## tautological restatement. Reverted after confirming the failure.
func test_tier_0_and_out_of_range_tiers_are_free_not_erroring() -> void:
	assert_int(SkillNodeDefinition.price_for_rank(0, 1)).append_failure_message("the root (tier 0) must always be free").is_equal(0)
	assert_int(SkillNodeDefinition.price_for_rank(5, 1)).append_failure_message("a tier with no authored base cost must not crash the caller").is_equal(0)


# --- Authored tree shape (docs/18 section 4.2) -------------------------------

func test_tree_has_the_root_plus_thirty_nodes_in_five_branches() -> void:
	assert_int(_tree.nodes.size()).append_failure_message("docs/31 section 7.1: about 30 nodes (Archer 5, Survival 6, Battle Skills 5, Tower 7, Fortune 7) plus the root").is_equal(31)
	var per_branch: Dictionary = {}
	for n in _tree.nodes:
		if n.id != _tree.root_id:
			per_branch[n.branch] = int(per_branch.get(n.branch, 0)) + 1
	assert_int(per_branch.size()).is_equal(5)
	assert_int(int(per_branch[SkillNodeDefinition.Branch.ARCHER])).is_equal(5)
	assert_int(int(per_branch[SkillNodeDefinition.Branch.SURVIVAL])).is_equal(6)
	assert_int(int(per_branch[SkillNodeDefinition.Branch.BATTLE])).is_equal(5)
	assert_int(int(per_branch[SkillNodeDefinition.Branch.TOWER])).is_equal(7)
	assert_int(int(per_branch[SkillNodeDefinition.Branch.FORTUNE])).is_equal(7)


## The full tree costs 1,616 Cores (Register "v1.0 Meta Progression": about 1,600).
func test_full_tree_cost_matches_the_register() -> void:
	var total: int = 0
	for n in _tree.nodes:
		for r in range(1, n.max_rank + 1):
			total += SkillNodeDefinition.price_for_rank(n.tier, r) if n.tier > 0 else 0
	assert_int(total).is_equal(1616)


## No two nodes share a grid cell (the board lays nodes out by `grid_position`).
func test_no_two_nodes_share_a_grid_cell() -> void:
	var seen: Dictionary = {}
	for n in _tree.nodes:
		assert_bool(seen.has(n.grid_position)).append_failure_message("'%s' shares cell %s" % [n.id, n.grid_position]).is_false()
		seen[n.grid_position] = true


## Every authored icon_id resolves to a real file, so no node falls back to a glyph by accident.
func test_every_node_icon_exists() -> void:
	for n in _tree.nodes:
		assert_str(n.icon_id).append_failure_message("'%s' names no icon" % n.id).is_not_empty()
		assert_bool(ResourceLoader.exists("res://assets/ui/icons/icon_%s.png" % n.icon_id)).append_failure_message("'%s': missing icon_%s.png" % [n.id, n.icon_id]).is_true()


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
	for id in ["armory", "second_dash", "watchtower", "deep_pockets"]:
		var node: SkillNodeDefinition = _tree.get_node_definition(id)
		assert_object(node).append_failure_message("expected an authored '%s' node" % id).is_not_null()
		assert_int(node.prerequisite_ids.size()).append_failure_message("'%s' should converge on two tier-2 siblings" % id).is_equal(2)


func test_get_all_node_ids_includes_root_and_every_node() -> void:
	var ids: Array[String] = _tree.get_all_node_ids()
	assert_int(ids.size()).is_equal(31)
	assert_bool(ids.has("root")).is_true()
	assert_bool(ids.has("second_wind")).is_true()
	assert_bool(ids.has("war_chest")).is_true()
	assert_bool(ids.has("lucky_charm")).append_failure_message("D117's new Lucky Charm node is missing from the authored tree").is_true()
