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


## Typed command: applies every field on `loadout` to the given live run.
## Every parameter after `loadout` may be null (a system not present in a
## given test/harness scene simply has its corresponding bonuses skipped,
## never crashes) -- matching this project's own "null reference tolerated"
## convention (src/upgrade/upgrade_system.gd's header, "a null reference is
## tolerated everywhere below").
static func apply(loadout: MetaLoadout, player: Player, tower: Tower, player_weapon: AutoWeapon, run_inventory: RunInventory, draft_controller: DraftController, wave_director: Object) -> void:
	if loadout == null:
		return
	_apply_player(loadout, player, player_weapon)
	_apply_tower(loadout, tower)
	_apply_economy(loadout, run_inventory)
	_apply_draft(loadout, draft_controller)
	_apply_war_chest(loadout, run_inventory, draft_controller, wave_director)


# --- Player branch -----------------------------------------------------------

static func _apply_player(loadout: MetaLoadout, player: Player, player_weapon: AutoWeapon) -> void:
	if player != null and player.definition != null:
		var dup: PlayerDefinition = player.definition.duplicate(true) as PlayerDefinition
		if loadout.player_max_health_bonus != 0.0:
			dup.max_health = int(round(float(dup.max_health) * (1.0 + loadout.player_max_health_bonus)))
		if loadout.player_move_speed_bonus != 0.0:
			dup.base_speed_px_per_second *= (1.0 + loadout.player_move_speed_bonus)
		if loadout.player_magnet_radius_bonus != 0.0:
			dup.magnet_radius_px = int(round(float(dup.magnet_radius_px) * (1.0 + loadout.player_magnet_radius_bonus)))
		player.definition = dup
		player._apply_definition()
		player.set_second_wind_available(loadout.second_wind_enabled)

	if player_weapon != null and player_weapon.definition != null:
		var weapon_def: WeaponDefinition = player_weapon.definition
		if (loadout.player_weapon_damage_bonus != 0.0 or loadout.player_fire_rate_bonus != 0.0) and weapon_def.damage_band != null and weapon_def.engagement_rhythm != null:
			var dup_weapon: WeaponDefinition = weapon_def.duplicate(true) as WeaponDefinition
			if loadout.player_weapon_damage_bonus != 0.0:
				dup_weapon.damage_band.value = int(round(float(dup_weapon.damage_band.value) * (1.0 + loadout.player_weapon_damage_bonus))) # BandedValue.value is int -- a bare `*=` truncates the float product back through the int setter instead of rounding it
			if loadout.player_fire_rate_bonus != 0.0:
				dup_weapon.engagement_rhythm.fire_rate_per_second *= (1.0 + loadout.player_fire_rate_bonus)
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

	var needs_tower_dup: bool = tower_max_health_bonus != 0.0 or loadout.tower_max_shield_bonus != 0.0 or loadout.repair_price_reduction != 0.0 or loadout.tower_weapon_range_bonus != 0.0
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
		if loadout.repair_price_reduction != 0.0 and dup_tower.repair_price != null:
			dup_tower.repair_price.scrap_cost = int(round(float(dup_tower.repair_price.scrap_cost) * (1.0 - loadout.repair_price_reduction)))
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
	if loadout.starting_scrap > 0:
		run_inventory.credit_scrap(loadout.starting_scrap)
	if loadout.xp_gain_bonus != 0.0:
		run_inventory.set_xp_gain_multiplier(1.0 + loadout.xp_gain_bonus)


static func _apply_draft(loadout: MetaLoadout, draft_controller: DraftController) -> void:
	if draft_controller != null and loadout.bonus_draft_rerolls > 0:
		draft_controller.add_bonus_rerolls(loadout.bonus_draft_rerolls)


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
