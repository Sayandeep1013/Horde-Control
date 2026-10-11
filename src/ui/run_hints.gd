extends Node
class_name RunHints

## RunHints (review fix, D241). Contextual, once-per-profile teaching hints for
## the v1.0 game, replacing the old wave-1 "just move" set. Each hint:
##   - fires on its own trigger (run start, first damage to the player, the
##     Battle Skill first becoming ready, the Tower first losing health while the
##     player holds Scrap, and the first sighting of a Bomber, Brute, elite, boss);
##   - is shown at most once per profile (`MetaProgress.is_hint_seen`);
##   - shows for HINT_SECONDS on pausable time (a pause freezes the clock and the
##     queue), and never overlaps another: requests wait in a queue;
##   - reads live binding names from `InputHints`; the touch string table (a
##     `%s` slot-less text) covers phone builds.
## The run objective line goes through the same queue (it repeats every run, so
## it is not recorded), which keeps it from stacking with a hint.
## Timings: Register > v1.0 Interface > "Contextual hints".

const HINT_SECONDS: float = 5.0
const GAP_SECONDS: float = 0.6
const POLL_SECONDS: float = 0.4
const MAX_QUEUE: int = 4
## How far from the player counts as "seen" (about the half-diagonal of the play view).
const SIGHT_RADIUS_PX: float = 1100.0

const ID_START: String = "start"
const ID_DASH: String = "dash"
const ID_SKILL_READY: String = "skill_ready"
const ID_TOWER_REPAIR: String = "tower_repair"
const ID_BOMBER: String = "bomber"
const ID_BRUTE: String = "brute"
const ID_ELITE: String = "elite"
const ID_BOSS: String = "boss"

const TEXT_KEYS: Dictionary = {
	ID_START: "HINT_START", ID_DASH: "HINT_DASH", ID_SKILL_READY: "HINT_SKILL_READY",
	ID_TOWER_REPAIR: "HINT_TOWER_REPAIR", ID_BOMBER: "HINT_BOMBER", ID_BRUTE: "HINT_BRUTE",
	ID_ELITE: "HINT_ELITE", ID_BOSS: "HINT_BOSS",
}

## Receives (text, seconds) when a hint is due. Set by the announcer.
var show_callback: Callable = Callable()
## Returns the Scrap the player carries now (set by the HUD).
var scrap_source: Callable = Callable()

var _queue: Array[Dictionary] = [] # {id, text}
var _active: bool = false
var _timer: SceneTreeTimer = null
var _poll_left: float = POLL_SECONDS
var _player_bound: Node = null
var _tower_bound: Node = null
var _skill_was_ready: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.elite_spawned.connect(_on_elite_spawned)
	EventBus.boss_spawned.connect(_on_boss_spawned)


func _exit_tree() -> void:
	if EventBus.elite_spawned.is_connected(_on_elite_spawned):
		EventBus.elite_spawned.disconnect(_on_elite_spawned)
	if EventBus.boss_spawned.is_connected(_on_boss_spawned):
		EventBus.boss_spawned.disconnect(_on_boss_spawned)
	_unbind(_player_bound, _on_player_damaged)
	_unbind(_tower_bound, _on_tower_damaged)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = POLL_SECONDS
	_bind_sources()
	_poll_skill()
	_poll_enemies()
	_pump()


# --- Requests ---------------------------------------------------------------------

## True when `id` has not been shown on this profile and is not already waiting.
func wants(id: String) -> bool:
	if MetaProgress.is_hint_seen(id):
		return false
	for entry: Dictionary in _queue:
		if String(entry["id"]) == id:
			return false
	return true


## Queues the hint `id` unless seen or already queued. `args` fill its text's
## `%s` slots, the LAST slot-count entries being used (the touch text has fewer).
func request(id: String, args: Array = []) -> void:
	if not TEXT_KEYS.has(id) or not wants(id):
		return
	_enqueue(id, text_for(id, args))


## A repeating line (the run objective): queued like a hint, never recorded.
func request_line(text: String) -> void:
	_enqueue("", text)


func _enqueue(id: String, text: String) -> void:
	if _queue.size() >= MAX_QUEUE:
		return
	_queue.append({"id": id, "text": text})
	_pump()


func text_for(id: String, args: Array) -> String:
	var template: String = TranslationServer.translate(StringName(String(TEXT_KEYS[id])))
	var slots: int = template.count("%s")
	if slots == 0:
		return template
	return template % args.slice(maxi(0, args.size() - slots))


## True while a hint or line is on screen.
func is_showing() -> bool:
	return _active


func queued_count() -> int:
	return _queue.size()


func _pump() -> void:
	if _active or _queue.is_empty() or not is_inside_tree() or get_tree().paused:
		return
	var entry: Dictionary = _queue.pop_front()
	var id: String = String(entry["id"])
	if id != "":
		if MetaProgress.is_hint_seen(id):
			_pump()
			return
		MetaProgress.mark_hint_seen(id)
	_active = true
	if show_callback.is_valid():
		show_callback.call(String(entry["text"]), HINT_SECONDS)
	_timer = get_tree().create_timer(HINT_SECONDS + GAP_SECONDS, false) # pausable
	_timer.timeout.connect(_on_slot_done)


func _on_slot_done() -> void:
	_active = false
	_pump()


# --- Triggers ---------------------------------------------------------------------

## Called by the announcer when wave 1 opens.
func on_run_started() -> void:
	var moves: Array[String] = []
	for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		moves.append(InputHints.key_text(action))
	request(ID_START, [" ".join(moves)])


func _bind_sources() -> void:
	if _player_bound == null or not is_instance_valid(_player_bound):
		var player: Node = get_tree().get_first_node_in_group("player")
		if player != null and player.get("death_state") != null:
			_player_bound = player.get("death_state")
			if not _player_bound.damage_applied.is_connected(_on_player_damaged):
				_player_bound.damage_applied.connect(_on_player_damaged)
	if _tower_bound == null or not is_instance_valid(_tower_bound):
		var tower: Node = get_tree().get_first_node_in_group("tower")
		if tower != null and tower.get("death_state") != null:
			_tower_bound = tower.get("death_state")
			if not _tower_bound.damage_applied.is_connected(_on_tower_damaged):
				_tower_bound.damage_applied.connect(_on_tower_damaged)


func _unbind(node: Node, callable: Callable) -> void:
	if node != null and is_instance_valid(node) and node.damage_applied.is_connected(callable):
		node.damage_applied.disconnect(callable)


func _on_player_damaged(amount: float, _source: Variant, _remaining: float) -> void:
	if amount > 0.0:
		request(ID_DASH, [InputHints.key_text(&"dash")])


func _on_tower_damaged(amount: float, _source: Variant, _remaining: float) -> void:
	if amount > 0.0 and scrap_source.is_valid() and int(scrap_source.call()) > 0:
		request(ID_TOWER_REPAIR)


func _poll_skill() -> void:
	if not wants(ID_SKILL_READY):
		return
	var node: Node = get_tree().get_first_node_in_group("battle_skill")
	if node == null or not node.has_method("get_state"):
		return
	var state: Dictionary = node.get_state()
	var is_ready: bool = bool(state.get("ready", false))
	if is_ready and not _skill_was_ready:
		request(ID_SKILL_READY, [InputHints.key_text(&"battle_skill"), AbilityNames.display(String(state.get("skill_id", RunConfig.battle_skill_id)))])
	_skill_was_ready = is_ready


func _poll_enemies() -> void:
	if not (wants(ID_BOMBER) or wants(ID_BRUTE)):
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for enemy: Node2D in EntityRegistry.get_enemies_in_radius(player.global_position, SIGHT_RADIUS_PX):
		var id: String = enemy_kind(enemy)
		if id == "bomber":
			request(ID_BOMBER)
		elif id == "brute":
			request(ID_BRUTE)


## The EnemyDefinition id of `node` ("bomber", "brute", ...), or "".
static func enemy_kind(node: Object) -> String:
	if node is EnemyController and (node as EnemyController).definition != null:
		return (node as EnemyController).definition.unique_id
	return ""


func _on_elite_spawned(_entity: Node2D, _affix: String, _timestamp: float) -> void:
	request(ID_ELITE)


func _on_boss_spawned(_boss: Node2D, _boss_id: String, _display_name: String, _max_health: float, _timestamp: float) -> void:
	request(ID_BOSS)
