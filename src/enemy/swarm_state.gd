extends RefCounted
class_name SwarmState
## PT-SWARM shared swarm state (D341). Kept out of EnemyController on purpose:
## a script with static variables stays loaded until exit, and EnemyController
## preloads definition resources, so statics there pinned ~120 resources into
## the engine's "still in use at exit" report. This class preloads nothing.

## Live enemies, pushed once per tick by the Wave Director; drives the AI LOD.
static var alive_count: int = 0
## The arena's FlowField node (group "flow_field"), cached by EnemyController.
static var flow_field: Node = null
static var flow_field_next_lookup: float = -INF


static func reset() -> void:
	alive_count = 0
	flow_field = null
	flow_field_next_lookup = -INF
