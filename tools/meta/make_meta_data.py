#!/usr/bin/env python3
"""Generates data/meta/skill_tree.tres (v2, D250) and data/meta/achievements.tres
(16 achievements, D251) from the tables below. Run from the repo root:
    python tools/meta/make_meta_data.py
The Register ("Meta: Skill Tree effects" / "Meta: Achievements") owns every number;
keep this file and the Register in step."""

# --- Skill tree -----------------------------------------------------------
# EffectKind integers (src/data/skill_node_definition.gd)
EK = dict(HP=0, SPEED=1, DMG=2, RATE=3, MAGNET=4, SECOND_WIND=5, T_HP=6, T_DMG=7, T_SHIELD=8,
          T_REGEN=9, T_RANGE=10, FORTRESS=11, SCRAP=12, XP=13, REROLL=14, CORES=15, SCRAP_CAP=16,
          WAR_CHEST=17, LUCK=18, CRIT=19, RANGE=20, ARMORY=21, IRON=22, DASH_CD=23, DASH_CH=24,
          SKILL_UNLOCK=25, SKILL_CD=26, SKILL_DMG=27, REPAIR=28, T_ABILITY=29)
# Branch ints: ARCHER 0, TOWER 1, FORTUNE 2, SURVIVAL 3, BATTLE 4
# (id, name, branch, (gx, gy), tier, max_rank, effect, value, template, prereqs, icon, unlock)
N = [
    # Archer (west)
    ("sharpened_arrows", "Sharpened Arrows", 0, (-1, -1), 1, 3, "DMG", 0.08, "+{value}% arrow damage per rank.", ["root"], "caliber", ""),
    ("quick_draw", "Quick Draw", 0, (-1, 1), 1, 3, "RATE", 0.06, "+{value}% fire rate per rank.", ["root"], "rapid_fire", ""),
    ("keen_eye", "Keen Eye", 0, (-2, -1), 3, 3, "CRIT", 0.04, "+{value}% critical chance per rank.", ["sharpened_arrows"], "keen_eye", ""),
    ("eagle_eye", "Eagle Eye", 0, (-2, 1), 2, 2, "RANGE", 0.10, "+{value}% bow range per rank.", ["quick_draw"], "optics", ""),
    ("armory", "Armory", 0, (-3, 0), 4, 1, "ARMORY", 1.0, "Your Opening Pick offers 4 abilities rolled Epic instead of 3 at Rare.", ["keen_eye", "eagle_eye"], "chest", ""),
    # Survival (north)
    ("vitality", "Vitality", 3, (0, -1), 1, 3, "HP", 0.10, "+{value}% player max health per rank.", ["root"], "vitality", ""),
    ("swift_boots", "Swift Boots", 3, (-1, -2), 1, 3, "SPEED", 0.04, "+{value}% move speed per rank.", ["vitality"], "swift_feet", ""),
    ("iron_skin", "Iron Skin", 3, (0, -2), 3, 3, "IRON", 0.05, "-{value}% damage taken per rank.", ["vitality"], "leather_armor", ""),
    ("fleet_foot", "Fleet Foot", 3, (-1, -3), 2, 2, "DASH_CD", 0.10, "-{value}% dash cooldown per rank.", ["swift_boots"], "fleet_step", ""),
    ("second_dash", "Second Dash", 3, (0, -3), 3, 1, "DASH_CH", 1.0, "+1 dash charge.", ["fleet_foot", "iron_skin"], "dash", ""),
    ("second_wind", "Second Wind", 3, (0, -4), 4, 1, "SECOND_WIND", 1.0, "Once per run, a killing blow leaves you at 1 health.", ["second_dash"], "heart", ""),
    # Battle Skills (north-east)
    ("skill_focus", "Skill Focus", 4, (1, -1), 2, 3, "SKILL_CD", 0.08, "-{value}% Battle Skill cooldown per rank.", ["root"], "battle_focus", ""),
    ("skill_power", "Skill Power", 4, (1, -2), 4, 3, "SKILL_DMG", 0.15, "+{value}% Battle Skill damage per rank.", ["skill_focus"], "ability_power", ""),
    ("frost_nova_unlock", "Frost Nova", 4, (2, -1), 2, 1, "SKILL_UNLOCK", 1.0, "Unlocks the Frost Nova Battle Skill in the War Camp.", ["skill_focus"], "frost_nova", "frost_nova"),
    ("firebomb_unlock", "Firebomb", 4, (2, -2), 3, 1, "SKILL_UNLOCK", 1.0, "Unlocks the Firebomb Battle Skill in the War Camp.", ["skill_focus"], "firebomb", "firebomb"),
    ("war_horn_unlock", "War Horn", 4, (3, -1), 3, 1, "SKILL_UNLOCK", 1.0, "Unlocks the War Horn Battle Skill in the War Camp.", ["frost_nova_unlock"], "war_horn", "war_horn"),
    # Tower (east)
    ("stone_walls", "Stone Walls", 1, (1, 0), 1, 3, "T_HP", 0.10, "+{value}% Tower max health per rank.", ["root"], "reinforced_plating", ""),
    ("arrow_slits", "Arrow Slits", 1, (1, 1), 1, 3, "T_DMG", 0.10, "+{value}% Tower damage per rank.", ["root"], "tower_volley", ""),
    ("shield_runes", "Shield Runes", 1, (2, 0), 2, 2, "T_SHIELD", 0.15, "+{value}% Tower shield per rank.", ["stone_walls"], "shield_matrix", ""),
    ("masons_kit", "Mason's Kit", 1, (2, 1), 2, 2, "REPAIR", 0.20, "+{value}% Tower repair per Scrap per rank.", ["arrow_slits"], "repair_kit", ""),
    ("watchtower", "Watchtower", 1, (3, 0), 3, 2, "T_RANGE", 0.10, "+{value}% Tower range per rank.", ["shield_runes", "masons_kit"], "watchtower_upgrade", ""),
    ("engineers", "Engineers", 1, (3, 1), 4, 2, "T_ABILITY", 0.15, "+{value}% Tower ability damage per rank.", ["masons_kit"], "catapult", ""),
    ("fortress", "Fortress", 1, (4, 0), 4, 1, "FORTRESS", 1.0, "The Tower starts one evolution stage up, with +20% health and +20% damage.", ["watchtower"], "tower", ""),
    # Fortune (south)
    ("scavenger", "Scavenger", 2, (0, 1), 1, 3, "SCRAP", 15.0, "+{value} starting Scrap per rank.", ["root"], "coin", ""),
    ("scholar", "Scholar", 2, (1, 2), 1, 3, "XP", 0.10, "+{value}% experience per rank.", ["scavenger"], "crystal", ""),
    ("lucky_draw", "Lucky Draw", 2, (-1, 2), 2, 2, "REROLL", 1.0, "+{value} Draft reroll per rank.", ["scavenger"], "recycle", ""),
    ("lucky_charm", "Lucky Charm", 2, (-1, 3), 2, 2, "LUCK", 3.0, "+{value} luck (better card rarity) per rank.", ["lucky_draw"], "magnet", ""),
    ("prospector", "Prospector", 2, (1, 3), 3, 2, "CORES", 0.15, "+{value}% Cores from every run per rank.", ["scholar"], "core", ""),
    ("deep_pockets", "Deep Pockets", 2, (0, 3), 3, 1, "SCRAP_CAP", 50.0, "+{value} Scrap carry cap.", ["lucky_draw", "prospector"], "patch_kit", ""),
    ("war_chest", "War Chest", 2, (0, 4), 4, 1, "WAR_CHEST", 1.0, "Start at level 1 with one free Draft when the first wave begins.", ["deep_pockets"], "chest", ""),
]


def tres_tree():
    out = ['[gd_resource type="Resource" script_class="SkillTreeDefinition" format=3]\n',
           '[ext_resource type="Script" path="res://src/data/skill_tree_definition.gd" id="1_tree"]',
           '[ext_resource type="Script" path="res://src/data/skill_node_definition.gd" id="2_node"]\n',
           '; GENERATED by tools/meta/make_meta_data.py -- edit the table there, not this file.',
           '; Permanent Skill Tree v2 (D250; docs/31 section 7.1, docs/18). Five branches radiate from',
           '; the Command Tent: Archer west, Survival north, Battle Skills north-east, Tower east,',
           '; Fortune south. `prerequisite_ids` is the real unlock graph; `grid_position` is layout only.\n']
    ids = ["root"]
    out += ['[sub_resource type="Resource" id="Resource_root"]', 'script = ExtResource("2_node")', 'id = "root"',
            'display_name = "Command Tent"', 'description_template = "The heart of the War Camp. Always yours."',
            'branch = 0', 'grid_position = Vector2i(0, 0)', 'tier = 0', 'max_rank = 1', 'effect_kind = 0',
            'value_per_rank = 0.0', 'prerequisite_ids = Array[String]([])', 'icon_id = "tent"', 'unlock_id = ""\n']
    for (i, name, br, gp, tier, mr, ek, val, tmpl, pre, icon, unlock) in N:
        ids.append(i)
        pre_s = ", ".join('"%s"' % p for p in pre)
        out += ['[sub_resource type="Resource" id="Resource_%s"]' % i, 'script = ExtResource("2_node")',
                'id = "%s"' % i, 'display_name = "%s"' % name, 'description_template = "%s"' % tmpl,
                'branch = %d' % br, 'grid_position = Vector2i(%d, %d)' % gp, 'tier = %d' % tier,
                'max_rank = %d' % mr, 'effect_kind = %d' % EK[ek], 'value_per_rank = %s' % val,
                'prerequisite_ids = Array[String]([%s])' % pre_s, 'icon_id = "%s"' % icon,
                'unlock_id = "%s"\n' % unlock]
    refs = ", ".join('SubResource("Resource_%s")' % i for i in ids)
    out += ['[resource]', 'script = ExtResource("1_tree")', 'root_id = "root"',
            'nodes = Array[ExtResource("2_node")]([%s])' % refs]
    return "\n".join(out) + "\n"


# --- Achievements ---------------------------------------------------------
# (id, name, description, metric, threshold, unlocks_card_id, perk_id, icon_id)
A = [
    ("goblin_slayer", "Goblin Slayer", "Defeat 300 enemies over your lifetime.", "lifetime_kills", 300, "frost_arrows", "", "kills"),
    ("veteran", "Veteran", "Reach wave 8 in a single run.", "run_wave_reached", 8, "storm_bolt", "", "veteran"),
    ("keeper_of_the_keep", "Keeper of the Keep", "Win a run with the Tower above 50% health.", "run_victory_tower_fraction", 0.5, "spiked_palisade", "", "tower"),
    ("warchief_slayer", "Warchief Slayer", "Defeat the Goblin Warchief.", "lifetime_boss_kills_warchief", 1, "catapult", "", "boss"),
    ("sanctified", "Sanctified", "Win a run on any difficulty.", "victories_total", 1, "sacred_ground", "", "sacred_ground"),
    ("hoarder", "Hoarder", "Collect 1000 Scrap over your lifetime.", "lifetime_scrap_collected", 1000, "", "bonus_reroll", "coin"),
    ("founder", "Founder", "Win your first run.", "victories_total", 1, "", "settlement_cores_bonus", "core"),
    ("marksman", "Marksman", "Defeat 2000 enemies over your lifetime.", "lifetime_kills", 2000, "", "weapon_damage_bonus", "caliber"),
    ("regicide", "Regicide", "Defeat the Bombardier King on Veteran or Warlord.", "run_king_killed_hard", 1, "", "settlement_cores_bonus_regicide", "war_horn"),
    ("warlord", "Warlord", "Win a run on Warlord.", "difficulty_victories_warlord", 1, "", "warlord_title", "warlord"),
    ("untouchable", "Untouchable", "Clear wave 5 or later without taking damage.", "run_untouchable_wave", 1, "", "move_speed_bonus", "shield_matrix"),
    ("mason", "Mason", "Repair 2000 Tower health in total.", "lifetime_repair", 2000, "", "repair_bonus", "repair"),
    ("elite_hunter", "Elite Hunter", "Defeat 50 elite enemies.", "lifetime_elite_kills", 50, "", "luck_bonus", "elite"),
    ("endless_20", "Endless Marathon", "Reach wave 20 in Endless mode.", "best_endless_wave", 20, "", "xp_bonus", "timer"),
    ("full_arsenal", "Full Arsenal", "Hold 4 player abilities in one run.", "run_player_abilities", 4, "", "ability_damage_bonus", "ability_power"),
    ("survivor", "Survivor", "Play 10 runs.", "runs_played", 10, "", "start_scrap_bonus", "heart"),
]


def tres_ach():
    out = ['[gd_resource type="Resource" script_class="AchievementList" format=3]\n',
           '[ext_resource type="Script" path="res://src/data/achievement_list.gd" id="1_list"]',
           '[ext_resource type="Script" path="res://src/data/achievement_definition.gd" id="2_def"]\n',
           '; GENERATED by tools/meta/make_meta_data.py -- edit the table there, not this file.',
           '; Achievements (D118, expanded to 16 by D251; docs/31 section 7.2). The Register row',
           '; "Meta: Achievements" owns every threshold and reward. Exactly one of',
           '; `unlocks_card_id` / `perk_id` is set per row.\n']
    ids = []
    for (i, name, desc, metric, th, card, perk, icon) in A:
        ids.append(i)
        out += ['[sub_resource type="Resource" id="Resource_%s"]' % i, 'script = ExtResource("2_def")',
                'id = "%s"' % i, 'display_name = "%s"' % name, 'description = "%s"' % desc,
                'metric = "%s"' % metric, 'threshold = %s' % float(th), 'unlocks_card_id = "%s"' % card,
                'perk_id = "%s"' % perk, 'icon_id = "%s"\n' % icon]
    refs = ", ".join('SubResource("Resource_%s")' % i for i in ids)
    out += ['[resource]', 'script = ExtResource("1_list")',
            'achievements = Array[AchievementDefinition]([%s])' % refs]
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    open("data/meta/skill_tree.tres", "w", encoding="utf-8", newline="\n").write(tres_tree())
    open("data/meta/achievements.tres", "w", encoding="utf-8", newline="\n").write(tres_ach())
    total = 0
    base = [0, 8, 16, 28, 45]
    for (_i, _n, _b, _g, tier, mr, *_r) in N:
        total += sum(round(base[tier] * (1 + 0.5 * (r - 1))) for r in range(1, mr + 1))
    print("nodes:", len(N), "full tree cost:", total)
