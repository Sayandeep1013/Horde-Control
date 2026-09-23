extends Resource
class_name SkillTreeDefinition

## Skill Tree definition (Meta layer core; docs/18_Permanent_Skill_Tree.md
## section 4.2). Authors the whole tree as one flat list of
## `SkillNodeDefinition` (the root included, per the build brief: "authoring
## all 18 nodes + the root"). `MetaProgress` is the only reader that turns
## this static content into live profile state (ranks, cores, visibility);
## this Resource carries no runtime state of its own.

@export var root_id: String = "root"
@export var nodes: Array[SkillNodeDefinition] = []

var _by_id: Dictionary = {} # String -> SkillNodeDefinition, built lazily
var _index_built: bool = false


func get_node_definition(id: String) -> SkillNodeDefinition:
	_ensure_index()
	return _by_id.get(id, null)


func has_node(id: String) -> bool:
	_ensure_index()
	return _by_id.has(id)


## A test (or a future authoring tool) that mutates `nodes` directly after
## this Resource is already in use must call this to see the change --
## the index is otherwise built once, lazily, per this project's convention
## of treating authored Resource content as immutable (resource-pattern
## skill).
func rebuild_index() -> void:
	_index_built = false
	_ensure_index()


func get_all_node_ids() -> Array[String]:
	var out: Array[String] = []
	for n in nodes:
		if n != null:
			out.append(n.id)
	return out


## Every purchasable node id (tier >= 1), i.e. every node except the root.
func get_purchasable_node_ids() -> Array[String]:
	var out: Array[String] = []
	for n in nodes:
		if n != null and n.tier >= 1:
			out.append(n.id)
	return out


func _ensure_index() -> void:
	if _index_built:
		return
	_by_id.clear()
	for n in nodes:
		if n != null and n.id != "":
			_by_id[n.id] = n
	_index_built = true
