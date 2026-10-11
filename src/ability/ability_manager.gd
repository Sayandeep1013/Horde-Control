extends Node
class_name AbilityManager
## v1.0 ability hub (docs/31 §4; Register "v1.0 Combat & Abilities"). Owns the
## ability nodes (one script per ability, levels 1-5), enforces the slot limits
## (AbilityIds.MAX_*), and is the single home of the derived multipliers that
## passives and the meta layer feed (crit chance, area, ability damage, skill
## and dash cooldowns, damage taken, repair). Group "ability_manager".
##
## Slot kinds are the strings "player" and "tower" (EventBus.ability_leveled and
## get_owned_abilities use them).

signal ability_changed(ability_id: String, level: int)

const SLOT_PLAYER: String = "player"
const SLOT_TOWER: String = "tower"

# Register: derived-stat floors, so stacked cards plus the Skill Tree cannot
# reach zero or negative values.
const COOLDOWN_MULT_FLOOR: float = 0.3
const DAMAGE_TAKEN_FLOOR: float = 0.25

const SCRIPTS: Dictionary = {
	"flame_arrows": preload("res://src/ability/flame_arrows.gd"),
	"frost_arrows": preload("res://src/ability/frost_arrows.gd"),
	"whirling_axes": preload("res://src/ability/whirling_axes.gd"),
	"dynamite_satchel": preload("res://src/ability/dynamite_satchel.gd"),
	"storm_bolt": preload("res://src/ability/storm_bolt.gd"),
	"caltrops": preload("res://src/ability/caltrops.gd"),
	"sacred_ground": preload("res://src/ability/sacred_ground.gd"),
	"ballista": preload("res://src/ability/ballista.gd"),
	"catapult": preload("res://src/ability/catapult.gd"),
	"frost_ward": preload("res://src/ability/frost_ward.gd"),
	"spiked_palisade": preload("res://src/ability/spiked_palisade.gd"),
}

var _owned: Dictionary = {} # id -> AbilityNode
var _best_rarity: Dictionary = {} # id -> highest rarity multiplier rolled (damage scaling)
var _passive_totals: Dictionary = {} # passive id -> summed rarity-scaled fraction
var _player: Node2D = null
var _tower: Node2D = null
var _upgrade_system: Node = null

# Meta hooks (WP-META calls these via MetaLoadoutApplier). Every one is ABSOLUTE:
# it assigns the loadout value, never adds, so calling the set twice (the
# integration repeats it deferred) leaves each derived value equal to the loadout once.
var _meta_dash_extra: int = 0
var _meta_dash_cd: float = 1.0
var _meta_skill_cd: float = 1.0
var _meta_skill_dmg: float = 1.0
var _meta_ability_dmg: float = 1.0
var _meta_tower_ability_dmg: float = 1.0
var _meta_crit: float = 0.0
var _meta_damage_taken: float = 1.0
var _meta_repair: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"ability_manager")
	call_deferred("_push_to_player")


# --- scene references (lazy, group based) -------------------------------------

func get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D if is_inside_tree() else null
	return _player


func get_tower() -> Node2D:
	if _tower == null or not is_instance_valid(_tower):
		_tower = get_tree().get_first_node_in_group(&"tower") as Node2D if is_inside_tree() else null
	return _tower


func get_upgrade_system() -> Node:
	if _upgrade_system == null or not is_instance_valid(_upgrade_system):
		_upgrade_system = get_tree().get_first_node_in_group(&"upgrade_system") if is_inside_tree() else null
	return _upgrade_system


func set_player_for_test(p: Node2D) -> void:
	_player = p


func set_tower_for_test(t: Node2D) -> void:
	_tower = t


func set_upgrade_system_for_test(u: Node) -> void:
	_upgrade_system = u


# --- ability ownership ----------------------------------------------------------

static func slot_kind_of(ability_id: String) -> String:
	return SLOT_TOWER if AbilityIds.is_tower_ability(ability_id) else SLOT_PLAYER


static func max_slots(slot_kind: String) -> int:
	return AbilityIds.MAX_TOWER_ABILITIES if slot_kind == SLOT_TOWER else AbilityIds.MAX_PLAYER_ABILITIES


func get_level(ability_id: String) -> int:
	var n: AbilityNode = _owned.get(ability_id)
	return n.level if n != null else 0


func owned_count(slot_kind: String) -> int:
	var c: int = 0
	for id in _owned.keys():
		if slot_kind_of(id) == slot_kind:
			c += 1
	return c


func has_free_slot(slot_kind: String) -> bool:
	return owned_count(slot_kind) < max_slots(slot_kind)


## True if the Draft may offer this ability: it is owned and below level 5, or
## it is new and a slot of its kind is free (docs/31 §4.1).
func can_grant(ability_id: String) -> bool:
	if not SCRIPTS.has(ability_id):
		return false
	var lvl: int = get_level(ability_id)
	if lvl > 0:
		return lvl < AbilityIds.MAX_ABILITY_LEVEL
	return has_free_slot(slot_kind_of(ability_id))


## Adds the ability at level 1 or raises it by one. `rarity_mult` is the rolled
## card's value multiplier; the best one rolled for this ability scales its
## damage (rarity scales damage only). Returns the new level, or 0 on refusal.
func grant_ability(ability_id: String, rarity_mult: float = 1.0) -> int:
	if not can_grant(ability_id):
		return 0
	_best_rarity[ability_id] = maxf(float(_best_rarity.get(ability_id, 1.0)), rarity_mult)
	var node: AbilityNode = _owned.get(ability_id)
	var kind: String = slot_kind_of(ability_id)
	if node != null:
		node.set_level(node.level + 1, float(_best_rarity[ability_id]))
	else:
		node = (SCRIPTS[ability_id] as GDScript).new() as AbilityNode
		node.setup(ability_id, 1, float(_best_rarity[ability_id]), self, kind == SLOT_TOWER)
		_owned[ability_id] = node
		add_child(node)
	ability_changed.emit(ability_id, node.level)
	EventBus.emit_ability_leveled(ability_id, node.level, kind)
	return node.level


func get_owned_abilities(slot_kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _owned.keys():
		if slot_kind_of(id) == slot_kind:
			out.append({"id": id, "level": (_owned[id] as AbilityNode).level})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	return out


func get_ability_node(ability_id: String) -> AbilityNode:
	return _owned.get(ability_id)


## Passives the run holds, for the pause Build panel: [{id, display_name, rank,
## max_rank, pool}] with pool "player" or "tower". Ranks live in UpgradeSystem.
func get_passive_summary() -> Array[Dictionary]:
	var us: Node = get_upgrade_system()
	if us != null and us.has_method("get_passive_ranks"):
		return us.get_passive_ranks()
	return []


## What the next level of `ability_id` does, for the Draft card (honest values).
## {"level_text": "NEW ABILITY" | "Lv 2 → 3", "effect_text": String, "next_level": int}
func describe_next(ability_id: String, rarity_mult: float = 1.0) -> Dictionary:
	var lvl: int = get_level(ability_id)
	var best: float = maxf(float(_best_rarity.get(ability_id, 1.0)), rarity_mult)
	var nxt: int = mini(lvl + 1, AbilityIds.MAX_ABILITY_LEVEL)
	return {
		"level_text": "NEW ABILITY" if lvl <= 0 else "Lv %d → %d" % [lvl, nxt],
		"effect_text": _with_synergies(ability_id, AbilityCatalog.describe(ability_id, nxt, best)),
		"next_level": nxt,
	}


## Appends the synergy lines whose partner ability is owned (Draft card text).
func _with_synergies(ability_id: String, text: String) -> String:
	for line in AbilitySynergy.active_texts(ability_id, _owned.keys()):
		text += "
" + line
	return text


## Active synergy lines for an owned ability (pause Build panel, tooltips).
func get_active_synergies(ability_id: String) -> Array[String]:
	return AbilitySynergy.active_texts(ability_id, _owned.keys())


## Armory keystone (docs/31 §7.1): a free Level-1 player ability from the
## unlocked pool. Goes through UpgradeSystem when present so the card's rank
## stays in step with the ability level. Returns the ability id ("" if none).
func grant_free_random_ability(rng_seed: int = 0) -> String:
	var pool: Array[String] = []
	var us: Node = get_upgrade_system()
	for id in AbilityIds.PLAYER_ABILITIES:
		if get_level(id) > 0 or not can_grant(id):
			continue
		if us != null and us.has_method("is_ability_available") and not us.is_ability_available(id):
			continue
		pool.append(id)
	if pool.is_empty():
		return ""
	var rng: RandomNumberGenerator
	if rng_seed != 0:
		rng = RandomNumberGenerator.new() # test / explicit seam
		rng.seed = rng_seed
	else:
		rng = AbilityDamage.keyed_rng("armory")
	var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
	if us != null and us.has_method("apply_rank") and us.get_definition(pick) != null:
		us.apply_rank(pick, 1.0)
	else:
		grant_ability(pick, 1.0)
	return pick


# --- passives (set by UpgradeSystem) ---------------------------------------------

## Called by UpgradeSystem with the total rarity-scaled fraction for the passive.
func set_passive_total(passive_id: String, total_fraction: float) -> void:
	_passive_totals[passive_id] = total_fraction
	_push_to_player()
	_refresh_tower_palisade()


func get_passive_total(passive_id: String) -> float:
	return float(_passive_totals.get(passive_id, 0.0))


# --- derived multipliers (pull) ----------------------------------------------------

func get_crit_chance() -> float:
	return clampf(get_passive_total(AbilityIds.KEEN_EYE) + _meta_crit, 0.0, 0.95)


func get_area_multiplier() -> float:
	return 1.0 + get_passive_total(AbilityIds.BLAST_RADIUS)


func _weapon_damage_multiplier() -> float:
	var p: Node2D = get_player()
	var w: Node = p.get_node_or_null("AutoWeapon") if p != null else null
	return w.get_damage_multiplier() if w != null and w.has_method("get_damage_multiplier") else 1.0


func get_player_ability_damage_multiplier() -> float:
	return _weapon_damage_multiplier() * (1.0 + get_passive_total(AbilityIds.ABILITY_POWER)) * _meta_ability_dmg


func get_tower_ability_damage_multiplier() -> float:
	var t: Node2D = get_tower()
	var base: float = 1.0
	if t != null and t.get("weapon") != null and t.weapon.has_method("get_damage_multiplier"):
		base = t.weapon.get_damage_multiplier()
	return base * _meta_tower_ability_dmg


func get_skill_damage_multiplier() -> float:
	return _weapon_damage_multiplier() * _meta_skill_dmg


func get_skill_cooldown_multiplier() -> float:
	return maxf(COOLDOWN_MULT_FLOOR, (1.0 - get_passive_total(AbilityIds.BATTLE_FOCUS)) * _meta_skill_cd)


func get_repair_multiplier() -> float:
	return (1.0 + get_passive_total(AbilityIds.STONE_MASON)) * _meta_repair


func get_dash_cooldown_multiplier() -> float:
	return maxf(COOLDOWN_MULT_FLOOR, (1.0 - get_passive_total(AbilityIds.FLEET_STEP)) * _meta_dash_cd)


func get_damage_taken_multiplier() -> float:
	return maxf(DAMAGE_TAKEN_FLOOR, (1.0 - get_passive_total(AbilityIds.LEATHER_ARMOR)) * _meta_damage_taken)


func _push_to_player() -> void:
	var p: Node2D = get_player()
	if p == null:
		return
	if p.has_method("set_dash_cooldown_multiplier"):
		p.set_dash_cooldown_multiplier(get_dash_cooldown_multiplier())
		p.set_dash_extra_charges(_meta_dash_extra)
		p.set_damage_taken_multiplier(get_damage_taken_multiplier())


func _refresh_tower_palisade() -> void:
	var n: AbilityNode = _owned.get(AbilityIds.SPIKED_PALISADE)
	if n != null:
		n.on_level_changed()


# --- meta hooks (WP-META: src/meta/meta_loadout_applier.gd) -------------------------

func set_dash_extra_charges(n: int) -> void:
	_meta_dash_extra = maxi(0, n)
	_push_to_player()


func set_dash_cooldown_multiplier(m: float) -> void:
	_meta_dash_cd = m
	_push_to_player()


func set_skill_cooldown_multiplier(m: float) -> void:
	_meta_skill_cd = m


func set_skill_damage_multiplier(m: float) -> void:
	_meta_skill_dmg = m


func set_ability_damage_multiplier(m: float) -> void:
	_meta_ability_dmg = m


func set_tower_ability_damage_multiplier(m: float) -> void:
	_meta_tower_ability_dmg = m
	_refresh_tower_palisade()


func set_crit_chance_bonus(f: float) -> void:
	_meta_crit = maxf(0.0, f)


func set_damage_taken_multiplier(m: float) -> void:
	_meta_damage_taken = m
	_push_to_player()


func set_repair_multiplier(m: float) -> void:
	_meta_repair = m
