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
## Hit effects (blood burst + splat, damage number) a swarm enemy may still spawn this
## tick; SwarmBrain refills it every tick (Register "Swarm rendering"). A lethal hit's
## damage number and the death burst are never skipped.
static var fx_budget: int = 1000000
static var brain: Node = null
## PT-PHONE (D396): per enemy scene, the per-life script variables of a freshly built enemy (see
## EnemyController._capture_pool_defaults). Primitive values only, so nothing here pins a resource.
static var pool_defaults: Dictionary = {}
static var renderer: Node = null


static func reset() -> void:
	alive_count = 0
	flow_field = null
	flow_field_next_lookup = -INF
	brain = null
	renderer = null
	fx_budget = 1000000
	pool_defaults.clear()
