extends Resource
class_name DifficultyProfile
## v1.0 difficulty profile (WP0, decision D171; docs/31 §6.2). One .tres per
## profile under data/difficulty/. Values are Provisional Defaults; the
## Register row "Difficulty profiles" (v1.0 Contracts) owns them. Read by the
## Wave Director at spawn time (WP-ENEMIES) and by Run-End Settlement
## (WP-META) through RunConfig.get_difficulty().

@export var id: String = "soldier"
@export var display_name: String = "Soldier"
@export_multiline var description: String = ""
@export var sort_order: int = 1
@export var enemy_hp_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var spawn_count_multiplier: float = 1.0
## Added to the per-wave elite chance (0.04 = +4 percentage points).
@export var elite_chance_add: float = 0.0
@export var boss_hp_multiplier: float = 1.0
@export var cores_multiplier: float = 1.0
## "" = open from a fresh profile; otherwise the difficulty id that must be
## won once ("soldier" -> unlocked by a Soldier victory).
@export var unlocked_by_victory_on: String = ""
