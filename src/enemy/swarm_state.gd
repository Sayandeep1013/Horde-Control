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
## PT-PERF (D390): the arena's SwarmBrain (steps every plain enemy at SimLoop step 3)
## and SwarmRenderer (draws them in one pass). Both null in isolated unit tests, where
## an enemy keeps its own per-node step and node visuals. Untyped on purpose (script
## cycle with EnemyController, see ShutdownHygiene / D256).
static var brain: Node = null
static var renderer: Node = null


static func reset() -> void:
	alive_count = 0
	flow_field = null
	flow_field_next_lookup = -INF
	brain = null
	renderer = null
