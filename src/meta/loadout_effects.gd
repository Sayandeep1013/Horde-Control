extends RefCounted
class_name LoadoutEffects
## v1.0 Loadout effects (WP-LOADOUT, docs/32 C; Register "v1.0 Loadout"). The one
## place a Champion or Relic id turns into numbers. `fold_into()` ADDS each term
## to the matching `MetaLoadout` field (or sets the new Loadout-only fields), so a
## stat the Skill Tree also touches reaches its absolute setter as ONE combined
## value, and a repeated apply never double-counts. Pure data in, data out: no
## nodes are touched here (`MetaLoadoutApplier` applies the result).
##
## Elite chance (King's Crown) and Lucky Coin's Patron's Boon card count are not
## here: the first is read from `RunConfig` by the Wave Director (`elite_chance_add()`),
## the second belongs to WP-RUNEVENTS, which reads `RunConfig.has_relic("lucky_coin")`.


static func fold_into(loadout: MetaLoadout, champion_id: String, relic_ids: Array) -> void:
	if loadout == null:
		return
	loadout.champion_id = champion_id if LoadoutCatalog.is_champion(champion_id) else LoadoutCatalog.DEFAULT_CHAMPION_ID
	match loadout.champion_id:
		"warden":
			loadout.tower_regen_in_radius_hp = LoadoutCatalog.WARDEN_TOWER_REGEN_HP_PER_SECOND
			loadout.tower_ability_damage_bonus += LoadoutCatalog.WARDEN_TOWER_ABILITY_DAMAGE_BONUS
			loadout.player_max_health_bonus -= LoadoutCatalog.WARDEN_PLAYER_MAX_HEALTH_PENALTY
		"skirmisher":
			loadout.moving_fire_rate_bonus = LoadoutCatalog.SKIRMISHER_MOVING_FIRE_RATE_BONUS
			loadout.dash_extra_charges += LoadoutCatalog.SKIRMISHER_EXTRA_DASH_CHARGES
		"pactbound":
			loadout.player_max_health_bonus -= LoadoutCatalog.PACTBOUND_PLAYER_MAX_HEALTH_PENALTY
	var seen: Array[String] = []
	for v in relic_ids:
		var id: String = String(v)
		if seen.has(id) or not LoadoutCatalog.is_relic(id):
			continue
		seen.append(id)
		match id:
			"quiver_of_echoes":
				loadout.echo_every_shots = LoadoutCatalog.QUIVER_ECHO_EVERY_SHOTS
			"masons_trowel":
				loadout.tower_repair_bonus += LoadoutCatalog.TROWEL_REPAIR_BONUS
			"hunters_charm":
				loadout.xp_gain_bonus += LoadoutCatalog.CHARM_XP_BONUS
			"warchiefs_horn":
				loadout.skill_cooldown_reduction += LoadoutCatalog.HORN_SKILL_COOLDOWN_REDUCTION
			"lucky_coin":
				loadout.bonus_draft_rerolls += LoadoutCatalog.COIN_BONUS_REROLLS
			"iron_banner":
				loadout.tower_shield_capacity_bonus = LoadoutCatalog.BANNER_SHIELD_BONUS
				loadout.tower_in_wave_shield_regen_fraction = LoadoutCatalog.BANNER_IN_WAVE_SHIELD_REGEN_FRACTION
			"ember_heart":
				loadout.burn_damage_bonus = LoadoutCatalog.EMBER_BURN_DAMAGE_BONUS
			# "kings_crown": the Wave Director and settlement read RunConfig / the run summary.
