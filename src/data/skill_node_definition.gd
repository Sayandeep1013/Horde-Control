extends Resource
class_name SkillNodeDefinition

## Skill Tree node definition (Meta layer core; docs/18_Permanent_Skill_Tree.md
## section 4.1/4.2; MASTER_SDLC.md > Provisional Values Register > "Meta:
## Skill Tree costs" / "Meta: Skill Tree effects"; Review Decision Log
## D109-D112). One instance per node authored on `data/meta/skill_tree.tres`
## (SkillTreeDefinition.nodes), including the root ("Command Tent").
##
## ## Adjacency / unlock ordering (docs/18 section 4.1): "`grid_position` ...
## is cosmetic only; the real unlock graph is each node's explicit
## `prerequisite_ids` list ... A node can be bought once EVERY node in its
## `prerequisite_ids` is owned at rank >= 1 -- most nodes name exactly one
## parent, but the three tier-3 nodes (Long Reach, Watchtower, Deep Pockets)
## each name BOTH of their tier-2 siblings ... A node is revealed ... once it
## is owned or any ONE of its `prerequisite_ids` is owned." `grid_position`
## therefore drives ONLY the Hub/Skill Tree screen's own canvas layout (the
## second agent's consumer), never `MetaProgress.is_visible()`/`can_buy()`.
##
## ## Effect kind + per-rank value (build spec item 1)
## Every node has exactly ONE effect kind and a single `value_per_rank`
## applied linearly (rank r contributes `value_per_rank * r`, per the
## Register's own wording -- "Percentages add within a node ... no
## diminishing return is stated anywhere for the Skill Tree, unlike
## upgrades' own C-STACK note about a DIFFERENT stacking case"). The three
## one-rank "mechanic" nodes (Second Wind, Fortress, War Chest) use
## `value_per_rank` as a simple presence flag (1.0 once owned, unused
## otherwise) -- their real effect is binary, not scalar.

## Matches docs/18 section 4.1's own three branch names ("Archer" is the
## player, "Fortune" is the economy branch).
enum Branch { ARCHER, TOWER, FORTUNE }

## Matches `MetaLoadout`'s own field set one-to-one -- see that file's
## header. Kept as a flat enum (not nested per-branch) so `MetaLoadout`'s
## application switch is a single match statement.
enum EffectKind {
	PLAYER_MAX_HEALTH_PERCENT,
	PLAYER_MOVE_SPEED_PERCENT,
	PLAYER_WEAPON_DAMAGE_PERCENT,
	PLAYER_FIRE_RATE_PERCENT,
	PLAYER_MAGNET_RADIUS_PERCENT,
	PLAYER_SECOND_WIND,
	TOWER_MAX_HEALTH_PERCENT,
	TOWER_WEAPON_DAMAGE_PERCENT,
	TOWER_MAX_SHIELD_PERCENT,
	## D115 (no in-run shop) removed the Tower Console and its repair price,
	## which this member (formerly TOWER_REPAIR_PRICE_REDUCTION_PERCENT) used
	## to discount for Mason's Kit -- see that node's own comment in
	## data/meta/skill_tree.tres. Renamed rather than removed: its integer
	## VALUE (9) is what data/meta/skill_tree.tres's `effect_kind = 9` stores
	## on disk, so the member stays at the same enum position and only its
	## meaning/name changes, repurposed to Mason's Kit's new effect.
	TOWER_SHIELD_REGEN_RATE_PERCENT,
	TOWER_WEAPON_RANGE_PERCENT,
	TOWER_FORTRESS_START,
	ECONOMY_STARTING_SCRAP_FLAT,
	ECONOMY_XP_GAIN_PERCENT,
	ECONOMY_DRAFT_REROLL_FLAT,
	ECONOMY_SETTLEMENT_CORES_PERCENT,
	ECONOMY_SCRAP_CAP_FLAT,
	ECONOMY_WAR_CHEST_START,
	## D117: Lucky Charm's rarity-luck points, shifting Draft card odds from
	## Common toward Rare/Epic (src/ui/draft_controller.gd's rarity roll).
	ECONOMY_DRAFT_RARITY_LUCK_FLAT,
}

## Register > "Meta: Skill Tree costs": "base 5 / 10 / 18 / 30 Cores for
## tiers 1-4". Index 0 unused (tier is 1-based for every purchasable node;
## the root is tier 0 and priced separately, see `price_for_rank()` below).
const TIER_BASE_COST: Array[int] = [0, 5, 10, 18, 30]

@export var id: String = ""
@export var display_name: String = ""
## A human-readable template the Hub/Skill Tree screen fills per rank, e.g.
## "+{value}% player max health" -- substitution is that screen's own job
## (not built by this task); kept here so the effect's wording lives beside
## its data instead of being hand-duplicated in UI code.
@export var description_template: String = ""
@export var branch: Branch = Branch.ARCHER
## Cosmetic only -- the Hub/Skill Tree screen's own canvas layout. See class
## header, "Adjacency / unlock ordering."
@export var grid_position: Vector2i = Vector2i.ZERO
## 0 = the root (free, always owned, never purchased); 1-4 = the four
## purchasable tiers priced by `price_for_rank()`.
@export var tier: int = 1
@export var max_rank: int = 1
@export var effect_kind: EffectKind = EffectKind.PLAYER_MAX_HEALTH_PERCENT
@export var value_per_rank: float = 0.0
## The real unlock graph (docs/18 section 4.1). Node ids that must ALL be
## owned (rank >= 1) before this node can be bought. Empty for the root.
@export var prerequisite_ids: Array[String] = []


## Register > "Meta: Skill Tree costs": "Rank r of a tier-t node costs
## base(t) x (1 + 0.5 x (r - 1)), rounded". `rank` is the rank being BOUGHT
## (1-based: the price of the first rank is `rank=1`). Tier 0 (the root) is
## always free -- it is never purchased, but this returns 0 for it rather
## than erroring, so a caller does not need a special case.
static func price_for_rank(node_tier: int, rank: int) -> int:
	if node_tier <= 0 or node_tier >= TIER_BASE_COST.size():
		return 0
	if rank < 1:
		return 0
	var base_cost: float = float(TIER_BASE_COST[node_tier])
	return int(round(base_cost * (1.0 + 0.5 * float(rank - 1))))
