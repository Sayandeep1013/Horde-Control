extends Node
class_name SimLoop

## SimLoop (MASTER_SDLC.md > Determinism where it matters, C-SIMLOOP;
## docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards >
## "SimLoop order"). Drives gameplay once per physics tick, in a fixed
## fifteen-step order; entities do not run their own gameplay
## _physics_process. Area2D overlap callbacks elsewhere must only enqueue a
## hit record (enqueue_hit()) for step 7 to process, never resolve damage
## directly.
##
## Not an Autoload (unlike SimClock and PauseAuthority, which the master
## explicitly calls Autoloads): this node belongs under the gameplay root
## scene, which P1.3 builds. `class_name SimLoop` (added by this task) is
## purely a static type/enum handle for other scripts to reference
## (`SimLoop.Step.PLAYER_MOVEMENT`, `node is SimLoop`) -- it does NOT make
## this a singleton; there is still exactly one real instance, living at
## Main/SimLoop, and every other script that needs THAT instance (not just
## the type) finds it via the `&"sim_loop"` group this file's own _ready()
## joins (see "Reaching this instance from elsewhere" below).
##
## PROCESS_MODE_PAUSABLE so it stops with the rest of the gameplay tree.
##
## ## Registration API (this task, F03-09)
## A system or entity that wants to be driven by the correct step instead of
## running its own `_physics_process` calls `register(step, node)` once
## (typically from its own `_ready()`), where `step` is one of the `Step`
## enum values below and `node` exposes a public `physics_step(delta)`
## method -- exactly the method every `driven_externally`-capable file in
## this project already exposes (player.gd, enemy_controller.gd,
## auto_weapon.gd, wave_director.gd). `unregister(step, node)` removes it
## again (a node that dies, despawns, or is freed). Every registered node's
## OWN `driven_externally` export must be set true wherever it is
## registered -- SimLoop has no way to suppress a node's `_physics_process`
## itself, so a node registered here while still self-driving would be
## stepped twice per tick. That pairing (`driven_externally = true` set in
## the scene file + a `register()` call) is this task's own wiring
## responsibility; SimLoop's `register()` only refuses a node with no
## `physics_step` method, it cannot detect a caller that forgot the flag.
##
## ## Ordering rule inside one step (DETERMINISTIC, per this task's brief)
## Registered nodes at the same step are called in ascending order of:
## 1. `EntityRegistry`'s own serial for that node, if `EntityRegistry`
##    exposes one -- checked via `has_method(&"get_registration_serial")`
##    on the injected/default registry reference, never assumed present.
##    **EntityRegistry does not currently expose this method** (confirmed
##    by reading src/core/entity_registry.gd in full; entity_registry.gd is
##    outside this task's write scope) -- this branch is therefore
##    unreachable in the shipped build today and is named as a required
##    seam in the evidence report, not silently left as dead-looking code:
##    it is here so a future EntityRegistry addition needs no change on
##    this side, and every node falls back to (2) until that day.
## 2. Registration order -- a monotonic counter (`_next_registration_serial`)
##    assigned the instant `register()` accepts a node and never reused,
##    even if that node later unregisters and re-registers (it gets a NEW,
##    larger serial and moves to the back of its step's order rather than
##    reclaiming its old position).
## A node freed or removed mid-tick is never called: `_run_step()` checks
## `is_instance_valid()` on every entry immediately before calling
## `physics_step()`.
##
## ## Registration/unregistration during a tick never mutates an
## in-progress iteration
## `register()`/`unregister()` never mutate the `Array` currently stored at
## `_registrations[step]` in place -- each call builds a brand-new `Array`
## (via `duplicate()` + append/remove_at) and only then replaces the
## dictionary entry. `_run_step()` itself takes its own `duplicate()`
## snapshot of that array before sorting and iterating it. So a
## register()/unregister() call made from inside another node's
## `physics_step()` this same tick (a node registering a child, an enemy
## unregistering itself on death) can safely replace `_registrations[step]`
## without ever touching the `Array` object `_run_step()` is currently
## looping over; the change takes effect starting the NEXT time that step
## runs, never retroactively on the pass in progress.
##
## ## Reaching this instance from elsewhere (dependency-injection skill,
## "Scene Injection" / group-lookup for a non-Autoload scene singleton)
## `_ready()` below calls `add_to_group(&"sim_loop")`. Any node elsewhere in
## the tree that needs the real running instance (not just the type) calls
## `get_tree().get_first_node_in_group(&"sim_loop")` -- matching this
## project's own "test-injectable, defaults to the real thing" convention
## (`set_*_for_test()` everywhere else), except the "real thing" here is a
## scene node, not an Autoload, so a group replaces the Autoload lookup.
## Callers that need this at `_ready()` time (hitbox.gd, player_projectile.
## gd, enemy_controller.gd) do the lookup from a `call_deferred()`-scheduled
## method, not `_ready()` itself: `_ready()` fires bottom-up, and for
## SIBLINGS under Main (Entities before SimLoop in main.tscn's own child
## order) an enemy under `Entities` finishes its `_ready()` before SimLoop
## ever runs its own -- a same-frame, non-deferred group lookup from that
## enemy's `_ready()` would find nothing. Deferring the lookup to the end of
## the same frame (after every node's `_ready()`, including SimLoop's, has
## run) resolves this without depending on sibling order at all.
##
## ## Combat serial (separate from the registration-order serial above)
## `get_combat_serial(subject)` answers a DIFFERENT question -- "which
## fixed integer does this attacker/target sort by in step 7's hit queue"
## (docs/20 > SimLoop order, step 7: "player serial 0, Tower serial 1") --
## and is kept as its own counter/map rather than reusing
## `_next_registration_serial`, because the two answer unrelated questions
## (per-step call order vs. per-tick hit-resolution order) and a caller
## that mixed them could accidentally make an entity's registration-order
## position leak into hit-resolution order or vice versa.
##
## Most steps have no systems to call yet beyond what this task wires --
## this is P1.1's own note, still true for steps 1, 8-12, 14, 15. Step 7
## (hit queue sort) and step 14 (PauseAuthority.flush()) were already fully
## implemented before this task; step 7 gains real damage RESOLUTION here
## (F03-22), on top of the sort it already had.

## Named per docs/20 > "SimLoop order" verbatim. Only steps 2-6 and 13 are
## ever passed to register()/unregister() by this task's own wiring (see
## the evidence report for which concrete node registers at which step,
## and which steps have no registrant yet); the rest are declared for
## completeness and for any later phase that wants to register something
## at, say, step 9 (drops) without inventing its own numbering.
enum Step {
	INPUT = 1,
	PLAYER_MOVEMENT = 2,
	ENEMY_AI_AND_MOVEMENT = 3,
	WEAPON_TARGETING_AND_FIRING = 4,
	PROJECTILE_MOVEMENT_AND_SWEEP = 5,
	WINDUP_AND_CONTACT_TICKS = 6,
	HIT_QUEUE_RESOLUTION = 7,
	DEATH_RESOLUTION = 8,
	DROPS = 9,
	PICKUP_MOVEMENT_AND_COLLECTION = 10,
	XP_AND_LEVEL_UP_REQUESTS = 11,
	CONSOLE_CHANNEL_COMPLETION = 12,
	WAVE_DIRECTOR = 13,
	PAUSE_FLUSH = 14,
	UI_STATE = 15,
}

## Populated fresh every tick by _physics_process(), for tests to read back
## and confirm the real call order (tests/unit/sim_loop_order_test.gd).
## Never read by gameplay code.
var _last_step_log: Array[String] = []

## Hits enqueued by step 5 (projectile sweep) and step 6 (wind-up/contact
## ticks) land here; step 7 sorts and resolves them.
var _hit_queue: Array[Dictionary] = []

## Snapshot of the sorted hit queue taken at the end of step 7, before it is
## cleared, so a test can read back the order that was actually applied
## (Phase 02 carried lesson: verify by reading the artifact back, not by
## the absence of an error). Never read by gameplay code.
var _last_hit_queue_snapshot_for_test: Array[Dictionary] = []

## step (Step enum int) -> Array[Dictionary] of {"node": Node, "reg_serial": int}.
## Never mutated in place -- see class doc, "Registration/unregistration
## during a tick never mutates an in-progress iteration".
var _registrations: Dictionary = {}
var _next_registration_serial: int = 0

## Test-injectable, defaults to the real EntityRegistry Autoload -- see
## class doc, "Ordering rule inside one step", point 1.
var _entity_registry: Node = null

## Combat-serial bookkeeping -- see class doc, "Combat serial". Dictionary
## keys mix Node references and normalized String tags (StringName values
## like &"player"/&"tower" are stringified before use as keys so the same
## logical subject always hits the same Dictionary entry regardless of
## which representation a caller passed).
var _combat_serial_by_subject: Dictionary = {}
var _next_combat_serial: int = 2 # 0 = player, 1 = Tower (docs/20 > SimLoop order, step 7)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"sim_loop") # see class doc, "Reaching this instance from elsewhere"
	if _entity_registry == null:
		_entity_registry = EntityRegistry


func set_entity_registry_for_test(registry: Node) -> void:
	_entity_registry = registry


func _physics_process(delta: float) -> void:
	_last_step_log.clear()
	_step_01_input(delta)
	_step_02_player_movement(delta)
	_step_03_enemy_ai_and_movement(delta)
	_step_04_weapon_targeting_and_firing(delta)
	_step_05_projectile_movement_and_sweep(delta)
	_step_06_windup_completion_and_contact_ticks(delta)
	_step_07_hit_queue_resolution(delta)
	_step_08_death_resolution(delta)
	_step_09_drops(delta)
	_step_10_pickup_movement_and_collection(delta)
	_step_11_xp_and_level_up_requests(delta)
	_step_12_console_channel_completion(delta)
	_step_13_wave_director(delta)
	_step_14_pause_flush(delta)
	_step_15_ui_state(delta)


# --- Registration API (F03-09) ---------------------------------------------

## Typed command. Registers `node` to be called via `node.physics_step(delta)`
## every tick at `step`'s point in the fixed order (see class doc). Refuses
## (returns false) a null/freed node, a node with no `physics_step(delta)`
## method, or a node already registered at this exact step -- the same node
## registered at a DIFFERENT step is allowed (see class doc).
func register(step: int, node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_method(&"physics_step"):
		push_error("SimLoop.register: '%s' has no physics_step(delta) method" % node.name)
		return false
	var list: Array = _registrations.get(step, [])
	for entry in list:
		if entry.get("node") == node:
			return false # already registered at this step
	var new_list: Array = list.duplicate()
	new_list.append({"node": node, "reg_serial": _next_registration_serial})
	_next_registration_serial += 1
	_registrations[step] = new_list
	return true


## Typed command. Refuses (returns false) a node not currently registered at
## `step`. Safe to call from inside that SAME step's own physics_step()
## callback -- see class doc.
func unregister(step: int, node: Node) -> bool:
	var list: Array = _registrations.get(step, [])
	for i in list.size():
		if list[i].get("node") == node:
			var new_list: Array = list.duplicate()
			new_list.remove_at(i)
			_registrations[step] = new_list
			return true
	return false


func is_registered(step: int, node: Node) -> bool:
	for entry in _registrations.get(step, []):
		if entry.get("node") == node:
			return true
	return false


func get_registered_count_for_test(step: int) -> int:
	return _registrations.get(step, []).size()


## Runs every node registered at `step`, in the documented deterministic
## order, skipping (never calling) any entry whose node was freed or
## removed since it registered.
func _run_step(step: int, delta: float) -> void:
	var list: Array = _registrations.get(step, [])
	if list.is_empty():
		return
	var ordered: Array = list.duplicate() # snapshot -- see class doc
	ordered.sort_custom(_registration_less_than)
	for entry in ordered:
		var node: Variant = entry.get("node")
		if node == null or not is_instance_valid(node):
			continue # freed or removed mid-tick -- never called
		(node as Node).physics_step(delta)


func _registration_less_than(a: Dictionary, b: Dictionary) -> bool:
	return _ordering_key_for(a) < _ordering_key_for(b)


func _ordering_key_for(entry: Dictionary) -> int:
	var node: Variant = entry.get("node")
	var reg_serial: int = entry.get("reg_serial", 0)
	if _entity_registry != null and node != null and _entity_registry.has_method(&"get_registration_serial"):
		var registry_serial: Variant = _entity_registry.get_registration_serial(node)
		if registry_serial is int and int(registry_serial) >= 0:
			return int(registry_serial)
	return reg_serial


# --- Combat serial (step 7 sort key; separate from the above) --------------

## Deterministic per-entity id used ONLY to order same-tick hits in step 7's
## sort (docs/20 > SimLoop order, step 7: "player serial 0, Tower serial 1").
## Accepts either a live Node (checked by class -- `Player`/`Tower` are
## global class_names) or a value tag (String/StringName, matching this
## project's "source resolved by value" convention for projectiles: `&
## "player"`/`&"tower"`). Player and Tower always resolve to 0/1; every
## other distinct subject is assigned the next ascending integer >= 2 the
## FIRST time this method ever sees it and keeps that value for as long as
## this SimLoop instance lives. Returns -1 for null (no attacker/target to
## order by).
func get_combat_serial(subject: Variant) -> int:
	if subject == null:
		return -1
	var key: Variant = subject
	if subject is StringName or subject is String:
		var s: String = String(subject)
		if s == "player":
			return 0
		if s == "tower":
			return 1
		key = s # normalize StringName/String to the same Dictionary key type
	elif subject is Player:
		return 0
	elif subject is Tower:
		return 1
	if _combat_serial_by_subject.has(key):
		return _combat_serial_by_subject[key]
	var serial: int = _next_combat_serial
	_next_combat_serial += 1
	_combat_serial_by_subject[key] = serial
	return serial


## Typed command (docs/20 > Communication, commands): the one legal way for
## an Area2D overlap callback to register a hit. Never resolves damage
## itself -- step 7 sorts, then resolves.
##
## `target_hurtbox`/`attacker_node`/`on_hit_accepted` are optional, added by
## this task (F03-22) on top of P1.1's original four positional args, kept
## backward compatible on purpose: sim_loop_order_test.gd's own coverage
## calls this with only the original four arguments to exercise the SORT in
## isolation, with nothing to resolve -- that call shape still works
## unchanged. A real caller (hitbox.gd, player_projectile.gd) supplies all
## seven so step 7 can actually apply the damage: `target_hurtbox` is the
## Hurtbox to call receive_hit() on, `attacker_node` is the first positional
## argument receive_hit() itself expects (the attacking Hitbox/Projectile,
## matching the pre-existing direct-call convention exactly), and
## `on_hit_accepted` is called (with no arguments) only if the hit is
## accepted -- the caller binds whatever it needs (its own `hit_landed`
## signal, damage numbers, once those exist) into that Callable.
func enqueue_hit(attacker_serial: int, target_serial: int, amount: float, source: Variant, target_hurtbox: Variant = null, attacker_node: Variant = null, on_hit_accepted: Callable = Callable()) -> void:
	_hit_queue.append({
		"attacker_serial": attacker_serial,
		"target_serial": target_serial,
		"amount": amount,
		"source": source,
		"target_hurtbox": target_hurtbox,
		"attacker_node": attacker_node,
		"on_hit_accepted": on_hit_accepted,
	})


func get_last_step_log_for_test() -> Array[String]:
	return _last_step_log.duplicate()


func get_last_hit_queue_snapshot_for_test() -> Array[Dictionary]:
	return _last_hit_queue_snapshot_for_test.duplicate(true)


# 1. Input.
func _step_01_input(delta: float) -> void:
	_last_step_log.append("01_input")
	# Player input reading lives inside Player.physics_step() itself
	# (Player's own header: input + movement are one combined step-1/2 call),
	# registered at step 2 below -- so nothing registers here today. The
	# dispatch call is present anyway: EVERY step dispatches its registrants,
	# with no exceptions, because a step that logs its name and dispatches
	# nothing is precisely the hole findings F03-51 and F04-10 fell into --
	# three systems registered against steps that never called them.
	_run_step(Step.INPUT, delta)


# 2. Player movement.
func _step_02_player_movement(delta: float) -> void:
	_last_step_log.append("02_player_movement")
	_run_step(Step.PLAYER_MOVEMENT, delta)


# 3. Enemy AI and movement.
func _step_03_enemy_ai_and_movement(delta: float) -> void:
	_last_step_log.append("03_enemy_ai_and_movement")
	_run_step(Step.ENEMY_AI_AND_MOVEMENT, delta)


# 4. Weapon targeting and firing (player, then Tower).
func _step_04_weapon_targeting_and_firing(delta: float) -> void:
	_last_step_log.append("04_weapon_targeting_and_firing")
	# Player weapon (AutoWeapon) registers here. The Tower's own weapon
	# (src/tower/tower_weapon.gd) has no driven_externally/physics_step seam
	# and src/tower/ is outside this task's write scope -- it keeps self-
	# driving via its own _physics_process(), so "player, then Tower" is
	# satisfied only for the player half today. Named as a required seam in
	# the evidence report.
	_run_step(Step.WEAPON_TARGETING_AND_FIRING, delta)


# 5. Projectile movement and sweep (enqueue hits).
func _step_05_projectile_movement_and_sweep(delta: float) -> void:
	_last_step_log.append("05_projectile_movement_and_sweep")
	# No registrant today: player_projectile.gd gained a physics_step()/
	# driven_externally seam this task (currently defaulting false, self-
	# driven, to avoid breaking its own isolated unit tests), but nothing in
	# this task's write scope constructs a projectile with driven_externally
	# already true -- src/combat/auto_weapon.gd's pooled factory (out of
	# scope) is the one call site that would need to flip it. Named as a
	# required seam in the evidence report. This does not affect F03-22:
	# damage resolution for player projectiles is wired independently of
	# this registration (see player_projectile.gd's own header).
	_run_step(Step.PROJECTILE_MOVEMENT_AND_SWEEP, delta)


# 6. Wind-up completion and contact ticks (enqueue hits).
func _step_06_windup_completion_and_contact_ticks(delta: float) -> void:
	_last_step_log.append("06_windup_completion_and_contact_ticks")
	# No registrant today, by a documented interpretation, not an oversight:
	# EnemyController's wind-up/contact-tick logic (_process_attack_cycle())
	# is folded into its single physics_step() call, registered at step 3
	# alongside movement (enemy_controller.gd cannot be split into two
	# independently-registrable methods without redesigning it, which this
	# task's brief forbids). Both still resolve before step 7's hit queue
	# either way, which is the property that actually matters for
	# determinism; the deviation from docs/20's literal per-step split is
	# named in the evidence report.
	_run_step(Step.WINDUP_AND_CONTACT_TICKS, delta)


# 7. Hit queue sorted by (target serial, attacker serial); player serial 0,
# Tower serial 1 (docs/20 > SimLoop order). The sort itself is unchanged
# from P1.1; this task (F03-22) adds the resolution that consumes it.
func _step_07_hit_queue_resolution(delta: float) -> void:
	_last_step_log.append("07_hit_queue_resolution")
	_hit_queue.sort_custom(_hit_less_than)
	_last_hit_queue_snapshot_for_test = _hit_queue.duplicate(true)
	for hit in _hit_queue:
		_resolve_one_hit(hit)
	_hit_queue.clear()
	# Registrants run AFTER the queue is resolved and cleared, so anything
	# registered here observes this tick's damage as already applied.
	_run_step(Step.HIT_QUEUE_RESOLUTION, delta)


## Applies the damage one queued hit record represents, in the sorted order
## established just above. A record with no `target_hurtbox` (the sort-only
## shape sim_loop_order_test.gd's own coverage uses) resolves to nothing --
## there is nothing to apply damage to, which is the intended no-op for
## that suite. `Hurtbox.receive_hit()` re-checks `is_dead` at the moment
## THIS call runs, not at enqueue time, which is what makes the existing
## ghost-hit guarantee ("a target that died earlier in the same tick takes
## no further hits") hold across the queue exactly as it held when
## resolution was immediate: a hit that lands on an already-Logically-Dead
## target this same tick is discarded here, in sorted order, by the same
## `is_dead` check that always guarded it.
func _resolve_one_hit(hit: Dictionary) -> void:
	var target_hurtbox: Variant = hit.get("target_hurtbox")
	if target_hurtbox == null or not is_instance_valid(target_hurtbox):
		return
	var amount: float = hit.get("amount", 0.0)
	var source: Variant = hit.get("source")
	var attacker_node: Variant = hit.get("attacker_node")
	var accepted: bool = (target_hurtbox as Hurtbox).receive_hit(attacker_node, amount, source)
	if accepted:
		var callback: Variant = hit.get("on_hit_accepted")
		if callback is Callable and (callback as Callable).is_valid():
			(callback as Callable).call()


static func _hit_less_than(a: Dictionary, b: Dictionary) -> bool:
	var a_target: int = a["target_serial"]
	var b_target: int = b["target_serial"]
	if a_target != b_target:
		return a_target < b_target
	var a_attacker: int = a["attacker_serial"]
	var b_attacker: int = b["attacker_serial"]
	return a_attacker < b_attacker


# 8. Death resolution in order Tower, bosses, player, other enemies.
func _step_08_death_resolution(delta: float) -> void:
	_last_step_log.append("08_death_resolution")
	# P1.5 death_state.gd drives itself from the hit that killed the entity;
	# the dispatch is here for any system that needs the post-death moment.
	_run_step(Step.DEATH_RESOLUTION, delta)


# 9. Drops.
func _step_09_drops(delta: float) -> void:
	_last_step_log.append("09_drops")
	# P2.10's PickupSystem registers a drop adapter here (finding F04-10:
	# registered and never dispatched until this call existed).
	_run_step(Step.DROPS, delta)


# 10. Pickup movement and collection.
func _step_10_pickup_movement_and_collection(delta: float) -> void:
	_last_step_log.append("10_pickup_movement_and_collection")
	# P2.10's PickupSystem (magnet, raycast blocking, lifetime, collection).
	_run_step(Step.PICKUP_MOVEMENT_AND_COLLECTION, delta)


# 11. XP and level-up requests.
func _step_11_xp_and_level_up_requests(delta: float) -> void:
	_last_step_log.append("11_xp_and_level_up_requests")
	# P2.10's run inventory raises the level-up request here; P2.12's Draft
	# consumes it on the same tick, before step 13 opens anything.
	_run_step(Step.XP_AND_LEVEL_UP_REQUESTS, delta)


# 12. Console channel completion (void if either pool reached 0 this tick;
# "confirmed" = channel completed).
func _step_12_console_channel_completion(delta: float) -> void:
	_last_step_log.append("12_console_channel_completion")
	# P2.13; docs/19 Tower Console UI. The Console never pauses, so its
	# purchase channel advances here on SimClock like any other system.
	_run_step(Step.CONSOLE_CHANNEL_COMPLETION, delta)


# 13. Wave Director.
func _step_13_wave_director(delta: float) -> void:
	_last_step_log.append("13_wave_director")
	_run_step(Step.WAVE_DIRECTOR, delta)


# 14. PauseAuthority.flush(). Pause requests made during this tick apply
# here, never mid-resolution. Fully implemented: PauseAuthority is this
# same task's own deliverable.
func _step_14_pause_flush(delta: float) -> void:
	_last_step_log.append("14_pause_flush")
	# Registrants run BEFORE the flush, so a pause a registrant requests this
	# tick applies in this same flush rather than one tick late.
	_run_step(Step.PAUSE_FLUSH, delta)
	PauseAuthority.flush()


# 15. UI state.
func _step_15_ui_state(delta: float) -> void:
	_last_step_log.append("15_ui_state")
	_run_step(Step.UI_STATE, delta)
	# Later UI tasks (docs/19).
