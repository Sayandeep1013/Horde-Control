extends RefCounted
class_name RunConfig
## v1.0 run configuration carried from the War Camp into a run (WP0, decision
## D171; docs/31 §2, §6.2). Static, because `change_scene_to_file()` frees
## every node; this is NOT a sixth gameplay autoload (D112 keeps the autoload
## list fixed). Written by the Hub (WP-META) and by Retry on the Results
## screen; read by PrototypeIntegration/WaveDirector (WP-ENEMIES), the Battle
## Skill controller (WP-COMBAT) and Settlement (WP-META). Tests call
## reset_for_test() in after_test().

const DIFFICULTY_DIR: String = "res://data/difficulty/"
const DIFFICULTY_IDS: Array[String] = ["recruit", "soldier", "veteran", "warlord"]
const DEFAULT_DIFFICULTY_ID: String = "soldier"
const DEFAULT_BATTLE_SKILL_ID: String = "arrow_storm"

static var difficulty_id: String = DEFAULT_DIFFICULTY_ID
static var battle_skill_id: String = DEFAULT_BATTLE_SKILL_ID
static var endless: bool = false

static var _cache: Dictionary = {} # id -> DifficultyProfile


static func get_difficulty() -> DifficultyProfile:
	return get_difficulty_by_id(difficulty_id)


static func get_difficulty_by_id(id: String) -> DifficultyProfile:
	if not DIFFICULTY_IDS.has(id):
		id = DEFAULT_DIFFICULTY_ID
	if not _cache.has(id):
		var res: Resource = load(DIFFICULTY_DIR + id + ".tres")
		_cache[id] = res if res is DifficultyProfile else DifficultyProfile.new()
	return _cache[id]


static func get_all_difficulties() -> Array[DifficultyProfile]:
	var out: Array[DifficultyProfile] = []
	for id in DIFFICULTY_IDS:
		out.append(get_difficulty_by_id(id))
	return out


static func reset_for_test() -> void:
	difficulty_id = DEFAULT_DIFFICULTY_ID
	battle_skill_id = DEFAULT_BATTLE_SKILL_ID
	endless = false
