extends Resource
class_name AchievementList

## The whole achievements list, authored as one flat array (D118), mirroring
## SkillTreeDefinition's own shape/header rationale exactly: this Resource
## carries no runtime state (no unlocked/not-unlocked flag lives here --
## that is per-profile state MetaProgress owns), only static content.

@export var achievements: Array[AchievementDefinition] = []

var _by_id: Dictionary = {} # String -> AchievementDefinition, built lazily
var _index_built: bool = false


func get_achievement(id: String) -> AchievementDefinition:
	_ensure_index()
	return _by_id.get(id, null)


func get_all_ids() -> Array[String]:
	var out: Array[String] = []
	for a in achievements:
		if a != null:
			out.append(a.id)
	return out


func rebuild_index() -> void:
	_index_built = false
	_ensure_index()


func _ensure_index() -> void:
	if _index_built:
		return
	_by_id.clear()
	for a in achievements:
		if a != null and a.id != "":
			_by_id[a.id] = a
	_index_built = true
