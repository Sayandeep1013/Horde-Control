extends RefCounted
class_name MetaLoadoutApplier

## The ONE application seam (build brief item 3) between `MetaLoadout` (the
## frozen per-run bonuses `MetaProgress.build_run_loadout()` computes at run
## start) and the live systems `scenes/prototype.tscn` assembles. Called
## once, from `src/integration/prototype_integration.gd`'s `_ready()`,
## before any other wiring in that file runs.
##
## ## Runtime copies only -- never the authored .tres (build brief, hard
## requirement)
## Every Resource this file touches (`PlayerDefinition`, `WeaponDefinition`
## x2, `TowerDefinition`) is `duplicate(true)`-d first; the duplicate is
## reassigned to the live node's own `definition`/`weapon_definition` field
## and re-applied through that node's OWN existing, already-re-entrant
## configure()/`_apply_definition()` method (Player._apply_definition(),
## AutoWeapon.configure(), Tower.configure() -- all three are already public
## and documented as safe to call again after `_ready()`). The original
## `data/**/*.tres` objects that every OTHER instance/test still loads via
## `preload()` are never mutated -- `duplicate(true)` guarantees a distinct
## object graph (resource-pattern skill, section 8).
##
## ## Why this folds cleanly under the P2.11 upgrade multiplier layer
## AutoWeapon/TowerWeapon/TowerHealth each carry a SEPARATE, REPLACE-not-
## compound multiplier field for their own in-run upgrade channel
## (`set_damage_multiplier()`, `set_fire_rate_multiplier()`,
## `set_range_multiplier()`, `set_bonus_max_shield_fraction()` --
## src/upgrade/upgrade_system.gd's own header). Those fields are UNTOUCHED
## here -- verified by reading upgrade_system.gd: they are only ever written
## from `apply_rank()`, never at `_ready()`/`configure()`, so they still
## start at their neutral default (1.0 multiplier / 0.0 fraction) for every
## run regardless of this applier. Meta bonuses are instead folded into the
## BASE values `configure()` derives from the definition Resource (e.g.
## `WeaponDefinition.damage_band.value`), so the two layers compose as
## `base x (1 + meta) x (1 + upgrade)` -- a deliberate, named interpretation
## (not a literal reading of C-STACK, which governs bonuses to the SAME
## stat within ONE channel) recorded in docs/18 section 6: meta progression
## and one run's own upgrades are different systems on different timescales,
## and this is the only route available that touches neither
## src/upgrade/upgrade_system.gd nor the multiplier fields' own
## replace-not-compound contract.
##
## ## Second Wind / Fortress / War Chest (the three non-scalar nodes)
## These are typed commands on the live node, not a Resource field: `Player.
## set_second_wind_available()`, `TowerEvolutionStage.advance_one_stage()`,
## and a one-shot `WaveDirector.wave_opened` connection that calls
## `DraftController.queue_forced_draft_for_meta()` when `wave_index == 0`
## (the first wave). None of the three mutate a definition Resource.
##
## ## Fortress ALSO carries a scalar gameplay effect (decision D114, blind
## review of the meta layer finding #2)
## The evolution-stage head start alone changes only the Tower's art in the
## prototype (no stat difference is wired to evolution stage yet) -- D114
## adds a fixed +20% Tower max health and +20% Tower weapon damage on top of
## it, composed EXACTLY like Stone Walls (`tower_max_health_bonus`) and
## Arrow Slits (`tower_weapon_damage_bonus`): `FORTRESS_TOWER_MAX_HEALTH_
## BONUS`/`FORTRESS_TOWER_WEAPON_DAMAGE_BONUS` below are added into the SAME
## local bonus fractions `_apply_tower()` already computes from those two
## nodes' own loadout fields, so a profile owning Fortress AND Stone Walls
## (say) gets both bonuses added together before the base value is
## multiplied ONCE -- the Register's own "percentages add ... and multiply
## the base once" rule, applied across sibling nodes touching the same stat
## rather than only within one node's own ranks. These two fractions are
## hardcoded constants, not read off `SkillNodeDefinition.value_per_rank`,
## because Fortress has exactly one rank and `value_per_rank` there is a
## presence flag (1.0), not a percentage (see that file's own "mechanic
## node" comment) -- the two numbers instead live directly beside the
## Register row they cite (Provisional Values Register > "Meta: Skill Tree
## effects" > "Fortress ... adds +20% Tower max health and +20% Tower
## weapon damage").
##
## ## Idempotence for every test/harness that instantiates scenes/
## prototype.tscn without ever buying a Skill Tree rank
## `MetaProgress`'s own in-memory default profile starts at zero ranks (see
## that file's header, "Never touches real user://profile.json at boot"), so
## `build_run_loadout()` returns an all-zero `MetaLoadout` for every existing
## test and every fresh install. Every step below is written to be a true
## no-op in that case: duplicating a Resource and re-applying identical
## values is behaviourally indistinguishable from never having run.

## Register > "Meta: Skill Tree effects" / decision D114 -- see class
## header, "Fortress ALSO carries a scalar gameplay effect."
const FORTRESS_TOWER_MAX_HEALTH_BONUS: float = 0.20
const FORTRESS_TOWER_WEAPON_DAMAGE_BONUS: float = 0.20

## D118 (achievements). Register > "Meta: Achievements": "Marksman perk
## (weapon_damage_bonus): +5% player weapon damage." Composes additively
## with Sharpened Arrows' own `player_weapon_damage_bonus`, exactly like
## Fortress composes with Stone Walls/Arrow Slits above -- ONE combined
## fraction, applied once, never a second `configure()` call layering a
## second multiplier on top of the first.
const ACHIEVEMENT_WEAPON_DAMAGE_BONUS: float = 0.05


## v1.0 achievement perks (D251). Register > "Meta: Achievements".
const ACHIEVEMENT_MOVE_SPEED_BONUS: float = 0.05 ## Untouchable
const ACHIEVEMENT_REPAIR_BONUS: float = 0.10 ## Mason
const ACHIEVEMENT_LUCK_BONUS: int = 3 ## Elite Hunter
const ACHIEVEMENT_XP_BONUS: float = 0.05 ## Endless Marathon
const ACHIEVEMENT_ABILITY_DAMAGE_BONUS: float = 0.05 ## Full Arsenal
const ACHIEVEMENT_START_SCRAP_BONUS: int = 10 ## Survivor
## Warlord's gold Tower skin tint (cosmetic, applied to the Tower sprite only).
const WARLORD_TOWER_TINT: Color = Color(1.0, 0.88, 0.5)

## ## v2 hooks owned by WP-COMBAT (D250)
## The Skill Tree v2 nodes that act on systems this package does not own call
## a small named method on that system's node, found by group, and are skipped
## silently when the node or the method is absent (they do not exist on every
## base). All live on the AbilityManager (group "ability_manager"):
## set_dash_extra_charges(n), set_dash_cooldown_multiplier(m),
## set_damage_taken_multiplier(m), set_crit_chance_bonus(f),
## set_skill_cooldown_multiplier(m), set_skill_damage_multiplier(m),
## set_ability_damage_multiplier(m), set_tower_ability_damage_multiplier(m),
## set_repair_multiplier(m). (grant_free_random_ability() stays on the AbilityManager for
## tests but is no longer called here: Armory now widens the Opening Pick, D281.)
## Every setter takes the ABSOLUTE multiplier, so calling this twice is safe.


## Typed command: applies every field on `loadout` to the given live run.
## Every parameter after `loadout` may be null (a system not present in a
## given test/harness scene simply has its corresponding bonuses skipped,
## never crashes) -- matching this project's own "null reference tolerated"
## convention (src/upgrade/upgrade_system.gd's header, "a null reference is
## tolerated everywhere below").
static func apply(loadout: MetaLoadout, player: Player, tower: Tower, player_weapon: AutoWeapon, run_inventory: RunInventory, draft_controller: DraftController, wave_director: Object) -> Dictionary:
	if loadout == null:
		return {}
	_apply_player(loadout, player, player_weapon)
	_apply_tower(loadout, tower)
	_apply_economy(loadout, run_inventory)
	_apply_draft(loadout, draft_controller)
	_apply_war_chest(loadout, run_inventory, draft_controller, wave_director)
	var tree: SceneTree = _tree_of([player, tower, player_weapon, run_inventory, draft_controller])
	var hooks: Dictionary = apply_group_hooks(loadout, tree, true)
	_apply_warlord_tint(tower)
	return hooks


# --- Player branch -----------------------------------------------------------

static func _apply_player(loadout: MetaLoadout, player: Player, player_weapon: AutoWeapon) -> void:
	if player != null and player.definition != null:
		var dup: PlayerDefinition = player.definition.duplicate(true) as PlayerDefinition
		if loadout.player_max_health_bonus != 0.0:
			dup.max_health = int(round(float(dup.max_health) * (1.0 + loadout.player_max_health_bonus)))
		var speed_bonus: float = loadout.player_move_speed_bonus
		if MetaProgress.has_perk("move_speed_bonus"):
			speed_bonus += ACHIEVEMENT_MOVE_SPEED_BONUS # D251: Untouchable, composed with Swift Boots
		if speed_bonus != 0.0:
			dup.base_speed_px_per_second *= (1.0 + speed_bonus)
		if loadout.player_magnet_radius_bonus != 0.0:
			dup.magnet_radius_px = int(round(float(dup.magnet_radius_px) * (1.0 + loadout.player_magnet_radius_bonus)))
		player.definition = dup
		player._apply_definition()
		player.set_second_wind_available(loadout.second_wind_enabled)

	if player_weapon != null and player_weapon.definition != null:
		var weapon_def: WeaponDefinition = player_weapon.definition
		# D118: Marksman's fixed perk folds into the SAME combined fraction
		# Sharpened Arrows contributes -- see this file's header, "Fortress
		# ALSO carries a scalar gameplay effect," for the identical pattern.
		var weapon_damage_bonus: float = loadout.player_weapon_damage_bonus
		if MetaProgress.has_perk("weapon_damage_bonus"):
			weapon_damage_bonus += ACHIEVEMENT_WEAPON_DAMAGE_BONUS
		var needs_weapon_dup: bool = weapon_damage_bonus != 0.0 or loadout.player_fire_rate_bonus != 0.0 or loadout.player_weapon_range_bonus != 0.0
		if needs_weapon_dup and weapon_def.damage_band != null and weapon_def.engagement_rhythm != null:
			var dup_weapon: WeaponDefinition = weapon_def.duplicate(true) as WeaponDefinition
			if weapon_damage_bonus != 0.0:
				dup_weapon.damage_band.value = int(round(float(dup_weapon.damage_band.value) * (1.0 + weapon_damage_bonus))) # BandedValue.value is int -- a bare `*=` truncates the float product back through the int setter instead of rounding it
			if loadout.player_fire_rate_bonus != 0.0:
				dup_weapon.engagement_rhythm.fire_rate_per_second *= (1.0 + loadout.player_fire_rate_bonus)
			if loadout.player_weapon_range_bonus != 0.0:
				dup_weapon.effective_range_px = int(round(float(dup_weapon.effective_range_px) * (1.0 + loadout.player_weapon_range_bonus))) # D250: Eagle Eye
			player_weapon.definition = dup_weapon
			player_weapon.configure(dup_weapon)


# --- Tower branch --------------------------------------------------------------

static func _apply_tower(loadout: MetaLoadout, tower: Tower) -> void:
	if tower == null or tower.definition == null:
		return
	# Finding #2 / D114: Fortress's own two fixed fractions compose ADDITIVELY
	# with Stone Walls'/Arrow Slits' own loadout fields for the SAME stat --
	# see class header, "Fortress ALSO carries a scalar gameplay effect."
	# Combined into local vars up front so every branch below (the dup-need
	# checks AND the actual mutation) reads ONE number per stat, exactly as
	# if a single node had granted the combined bonus.
	var tower_max_health_bonus: float = loadout.tower_max_health_bonus
	var tower_weapon_damage_bonus: float = loadout.tower_weapon_damage_bonus
	if loadout.fortress_enabled:
		tower_max_health_bonus += FORTRESS_TOWER_MAX_HEALTH_BONUS
		tower_weapon_damage_bonus += FORTRESS_TOWER_WEAPON_DAMAGE_BONUS

	var needs_tower_dup: bool = tower_max_health_bonus != 0.0 or loadout.tower_max_shield_bonus != 0.0 or loadout.tower_shield_regen_bonus != 0.0 or loadout.tower_weapon_range_bonus != 0.0
	var needs_weapon_dup: bool = tower_weapon_damage_bonus != 0.0

	var dup_tower: TowerDefinition = tower.definition
	if needs_tower_dup:
		dup_tower = tower.definition.duplicate(true) as TowerDefinition
		if tower_max_health_bonus != 0.0 and dup_tower.max_health_and_shield_fraction != null:
			dup_tower.max_health_and_shield_fraction.maximum_health = int(round(float(dup_tower.max_health_and_shield_fraction.maximum_health) * (1.0 + tower_max_health_bonus)))
		if loadout.tower_max_shield_bonus != 0.0 and dup_tower.max_health_and_shield_fraction != null:
			# Additive to the base shield fraction, folded in BEFORE
			# TowerHealth.configure() derives `_base_max_shield` -- see this
			# file's header on why this stays clear of Shield Matrix's own
			# set_bonus_max_shield_fraction() (a REPLACE-not-add multiplier
			# layer that would otherwise silently discard this bonus the
			# first time a real Shield Matrix rank is taken in-run).
			dup_tower.max_health_and_shield_fraction.base_shield_fraction += loadout.tower_max_shield_bonus
		# D115 (no in-run shop) removed the Tower Console and its repair
		# price -- Mason's Kit (formerly a repair-price discount) is
		# repurposed to a Tower shield regen RATE bonus instead, folded into
		# the base the same way as every other Tower percentage bonus here.
		if loadout.tower_shield_regen_bonus != 0.0 and dup_tower.shield_regeneration != null:
			dup_tower.shield_regeneration.rate_percent_per_second *= (1.0 + loadout.tower_shield_regen_bonus)
		if loadout.tower_weapon_range_bonus != 0.0 and dup_tower.targeting_rule_parameters != null:
			dup_tower.targeting_rule_parameters.range_px = int(round(float(dup_tower.targeting_rule_parameters.range_px) * (1.0 + loadout.tower_weapon_range_bonus)))

	var dup_weapon: WeaponDefinition = tower.weapon_definition
	if needs_weapon_dup and tower.weapon_definition != null and tower.weapon_definition.damage_band != null:
		dup_weapon = tower.weapon_definition.duplicate(true) as WeaponDefinition
		dup_weapon.damage_band.value = int(round(float(dup_weapon.damage_band.value) * (1.0 + tower_weapon_damage_bonus))) # BandedValue.value is int -- see the identical fix/comment on the player weapon branch above

	if needs_tower_dup or needs_weapon_dup:
		tower.configure(dup_tower, dup_weapon)

	if loadout.fortress_enabled and tower.evolution_stage != null:
		tower.evolution_stage.advance_one_stage()


# --- Economy branch --------------------------------------------------------------

static func _apply_economy(loadout: MetaLoadout, run_inventory: RunInventory) -> void:
	if run_inventory == null:
		return
	if loadout.scrap_cap_bonus != 0:
		run_inventory.scrap_cap += loadout.scrap_cap_bonus
	var start_scrap: int = loadout.starting_scrap
	if MetaProgress.has_perk("start_scrap_bonus"):
		start_scrap += ACHIEVEMENT_START_SCRAP_BONUS # D251: Survivor
	if start_scrap > 0:
		run_inventory.credit_scrap(start_scrap)
	var xp_bonus: float = loadout.xp_gain_bonus
	if MetaProgress.has_perk("xp_bonus"):
		xp_bonus += ACHIEVEMENT_XP_BONUS # D251: Endless Marathon, composed with Scholar
	if xp_bonus != 0.0:
		run_inventory.set_xp_gain_multiplier(1.0 + xp_bonus)


static func _apply_draft(loadout: MetaLoadout, draft_controller: DraftController) -> void:
	if draft_controller == null:
		return
	# D118: Hoarder's own perk composes additively with Lucky Draw's ranks,
	# exactly like every other perk in this file composes with its Skill
	# Tree counterpart -- one combined count, one call.
	var bonus_rerolls: int = loadout.bonus_draft_rerolls
	if MetaProgress.has_perk("bonus_reroll"):
		bonus_rerolls += 1
	if bonus_rerolls > 0:
		draft_controller.add_bonus_rerolls(bonus_rerolls)
	# D117; Lucky Charm.
	var luck: int = loadout.rarity_luck_points
	if MetaProgress.has_perk("luck_bonus"):
		luck += ACHIEVEMENT_LUCK_BONUS # D251: Elite Hunter, composed with Lucky Charm
	if luck > 0:
		draft_controller.add_rarity_luck_points(luck)


## War Chest: "start at level 1 with one free Draft when the first wave
## begins" (Register > "Meta: Skill Tree effects"). The level-1 start is
## applied immediately (mirrors DraftController._grant_forced_level()'s own
## shape); the free Draft is deferred to the real WaveDirector.wave_opened
## signal for wave_index == 0 (the first wave, 0-based -- matching
## run_flow_controller.gd's own documented indexing), a ONE_SHOT connection
## so it can never fire twice even if wave_opened is re-emitted (a wave never
## reopens once ended, but this makes that guarantee explicit rather than
## assumed).
static func _apply_war_chest(loadout: MetaLoadout, run_inventory: RunInventory, draft_controller: DraftController, wave_director: Object) -> void:
	if not loadout.war_chest_enabled:
		return
	if run_inventory != null and run_inventory.level < 1:
		run_inventory.grant_meta_starting_level(1)
	if draft_controller != null and wave_director != null and wave_director.has_signal(&"wave_opened"):
		# CONNECT_ONE_SHOT is the only guard needed against a double free
		# Draft: this method runs exactly once per run (apply() is called
		# once from PrototypeIntegration._ready()), and a wave never reopens
		# once ended, so there is no realistic double-connect to defend
		# against separately.
		wave_director.wave_opened.connect(_make_first_wave_callback(draft_controller), CONNECT_ONE_SHOT)


static func _make_first_wave_callback(draft_controller: DraftController) -> Callable:
	return func(_wave_id: String, wave_index: int) -> void:
		if wave_index == 0 and is_instance_valid(draft_controller):
			draft_controller.queue_forced_draft_for_meta()


# --- v2 group hooks (D250) -------------------------------------------------------

static func _tree_of(candidates: Array) -> SceneTree:
	for c in candidates:
		if c is Node and (c as Node).is_inside_tree():
			return (c as Node).get_tree()
	return Engine.get_main_loop() as SceneTree


## Calls the WP-COMBAT hooks the loadout and the achievement perks need, each
## only when its value is not neutral and only on a node found by group that has
## the method. Returns what it did: {"called": Array[String], "armory_granted":
## bool} so the caller can retry the grant later if the ability manager does not
## exist yet. `grant_armory` is accepted for compatibility and ignored (D281).
static func apply_group_hooks(loadout: MetaLoadout, tree: SceneTree, grant_armory: bool) -> Dictionary:
	var result: Dictionary = {"called": [] as Array[String], "armory_granted": false}
	if loadout == null or tree == null:
		return result
	var called: Array[String] = result["called"]

	if loadout.dash_extra_charges > 0:
		_hook(tree, &"set_dash_extra_charges", [loadout.dash_extra_charges], called)
	if loadout.dash_cooldown_reduction > 0.0:
		_hook(tree, &"set_dash_cooldown_multiplier", [1.0 - loadout.dash_cooldown_reduction], called)
	if loadout.damage_taken_reduction > 0.0:
		_hook(tree, &"set_damage_taken_multiplier", [1.0 - loadout.damage_taken_reduction], called)
	if loadout.player_crit_chance_bonus > 0.0:
		_hook(tree, &"set_crit_chance_bonus", [loadout.player_crit_chance_bonus], called)
	if loadout.skill_cooldown_reduction > 0.0:
		_hook(tree, &"set_skill_cooldown_multiplier", [1.0 - loadout.skill_cooldown_reduction], called)
	if loadout.skill_damage_bonus > 0.0:
		_hook(tree, &"set_skill_damage_multiplier", [1.0 + loadout.skill_damage_bonus], called)
	if MetaProgress.has_perk("ability_damage_bonus"):
		_hook(tree, &"set_ability_damage_multiplier", [1.0 + ACHIEVEMENT_ABILITY_DAMAGE_BONUS], called)
	if loadout.tower_ability_damage_bonus > 0.0:
		_hook(tree, &"set_tower_ability_damage_multiplier", [1.0 + loadout.tower_ability_damage_bonus], called)
	# Armory (docs/32 §A, D281): no longer grants a free random ability here. The skill
	# node now makes the Opening Pick offer 4 abilities rolled Epic (RunEvents reads
	# `loadout.armory_enabled`); `grant_armory` and "armory_granted" stay for callers.
	var repair_bonus: float = loadout.tower_repair_bonus
	if MetaProgress.has_perk("repair_bonus"):
		repair_bonus += ACHIEVEMENT_REPAIR_BONUS # D251: Mason, composed with Mason's Kit
	if repair_bonus > 0.0:
		_hook(tree, &"set_repair_multiplier", [1.0 + repair_bonus], called)
	return result


## Groups searched for a hook, in order. WP-COMBAT put every hook on the
## AbilityManager node; the others are tolerated so a split layout also works.
const HOOK_GROUPS: Array[StringName] = [&"ability_manager", &"player", &"battle_skill", &"tower_repair"]


## Calls `method` on the first node in HOOK_GROUPS that has it; false (silently) if none does.
static func _hook(tree: SceneTree, method: StringName, args: Array, called: Array[String]) -> bool:
	for group in HOOK_GROUPS:
		if _try_call(_first_in_group(tree, group), method, args):
			called.append(String(method))
			return true
	return false


static func _first_in_group(tree: SceneTree, group: StringName) -> Node:
	var nodes: Array[Node] = tree.get_nodes_in_group(group)
	return nodes[0] if not nodes.is_empty() else null


## Calls `method` when `node` is valid and has it; false (silently) otherwise.
static func _try_call(node: Node, method: StringName, args: Array) -> bool:
	if node == null or not is_instance_valid(node) or not node.has_method(method):
		return false
	node.callv(method, args)
	return true


## Warlord (D251): a gold tint on the Tower sprite, once the achievement is held.
static func _apply_warlord_tint(tower: Tower) -> void:
	if tower == null or not MetaProgress.has_perk("warlord_title"):
		return
	var sprite: CanvasItem = tower.get_node_or_null("Visuals/Sprite") as CanvasItem
	if sprite != null:
		sprite.self_modulate = WARLORD_TOWER_TINT
