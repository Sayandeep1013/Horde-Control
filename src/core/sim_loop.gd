extends Node

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
## scene, which P1.3 builds. It is written now, as a script with a clear,
## testable per-tick order, so P1.3 only has to add one node to the scene
## tree rather than design the order.
##
## PROCESS_MODE_PAUSABLE so it stops with the rest of the gameplay tree.
##
## Most steps have no systems to call yet -- this is P1.1; EventBus,
## EntityRegistry, Pool, hitboxes, the Wave Director, etc. land in later
## Phase 02/03 tasks. Each step is its own named, empty method so a later
## task's system call goes inside that method without touching the order.
## The order is this task's deliverable, not the bodies. Step 7 (hit queue
## sort) and step 14 (PauseAuthority.flush()) are fully implemented, since
## both are completely specified by this task's own inputs.

## Populated fresh every tick by _physics_process(), for tests to read back
## and confirm the real call order (tests/unit/sim_loop_order_test.gd).
## Never read by gameplay code.
var _last_step_log: Array[String] = []

## Hits enqueued by step 5 (projectile sweep) and step 6 (wind-up/contact
## ticks) land here; step 7 sorts and resolves them. Nothing populates this
## yet in P1.1 -- combat components land in P1.5.
var _hit_queue: Array[Dictionary] = []

## Snapshot of the sorted hit queue taken at the end of step 7, before it is
## cleared, so a test can read back the order that was actually applied
## (Phase 02 carried lesson: verify by reading the artifact back, not by
## the absence of an error). Never read by gameplay code.
var _last_hit_queue_snapshot_for_test: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(_delta: float) -> void:
	_last_step_log.clear()
	_step_01_input()
	_step_02_player_movement()
	_step_03_enemy_ai_and_movement()
	_step_04_weapon_targeting_and_firing()
	_step_05_projectile_movement_and_sweep()
	_step_06_windup_completion_and_contact_ticks()
	_step_07_hit_queue_resolution()
	_step_08_death_resolution()
	_step_09_drops()
	_step_10_pickup_movement_and_collection()
	_step_11_xp_and_level_up_requests()
	_step_12_console_channel_completion()
	_step_13_wave_director()
	_step_14_pause_flush()
	_step_15_ui_state()


## Typed command (docs/20 > Communication, commands): the one legal way for
## an Area2D overlap callback to register a hit. Never resolves damage
## itself; step 7 sorts and (once a later task adds it) resolves the queue.
func enqueue_hit(attacker_serial: int, target_serial: int, amount: float, source: Variant) -> void:
	_hit_queue.append({
		"attacker_serial": attacker_serial,
		"target_serial": target_serial,
		"amount": amount,
		"source": source,
	})


func get_last_step_log_for_test() -> Array[String]:
	return _last_step_log.duplicate()


func get_last_hit_queue_snapshot_for_test() -> Array[Dictionary]:
	return _last_hit_queue_snapshot_for_test.duplicate(true)


# 1. Input.
func _step_01_input() -> void:
	_last_step_log.append("01_input")
	# Player input reading lands with the Player Controller (P2.1).


# 2. Player movement.
func _step_02_player_movement() -> void:
	_last_step_log.append("02_player_movement")
	# P2.1.


# 3. Enemy AI and movement.
func _step_03_enemy_ai_and_movement() -> void:
	_last_step_log.append("03_enemy_ai_and_movement")
	# Enemy components land in P1.5; full AI in docs/09 and later P2.x tasks.


# 4. Weapon targeting and firing (player, then Tower).
func _step_04_weapon_targeting_and_firing() -> void:
	_last_step_log.append("04_weapon_targeting_and_firing")
	# Player weapon: P2.4. Tower weapon: P2.5. Player fires before Tower,
	# per this step's own documented order.


# 5. Projectile movement and sweep (enqueue hits).
func _step_05_projectile_movement_and_sweep() -> void:
	_last_step_log.append("05_projectile_movement_and_sweep")
	# P2.4/P2.5. A projectile's sweep calls enqueue_hit() here, never
	# resolves damage directly.


# 6. Wind-up completion and contact ticks (enqueue hits).
func _step_06_windup_completion_and_contact_ticks() -> void:
	_last_step_log.append("06_windup_completion_and_contact_ticks")
	# P1.5 hitbox/hurtbox framework. Contact-damage ticks call enqueue_hit()
	# here too.


# 7. Hit queue sorted by (target serial, attacker serial); player serial 0,
# Tower serial 1 (docs/20 > SimLoop order). Fully implemented: the sort is
# completely specified by this task's own inputs, even though no damage
# system yet exists to consume the sorted queue.
func _step_07_hit_queue_resolution() -> void:
	_last_step_log.append("07_hit_queue_resolution")
	_hit_queue.sort_custom(_hit_less_than)
	_last_hit_queue_snapshot_for_test = _hit_queue.duplicate(true)
	# Future damage resolution (combat system) consumes _hit_queue here.
	_hit_queue.clear()


static func _hit_less_than(a: Dictionary, b: Dictionary) -> bool:
	var a_target: int = a["target_serial"]
	var b_target: int = b["target_serial"]
	if a_target != b_target:
		return a_target < b_target
	var a_attacker: int = a["attacker_serial"]
	var b_attacker: int = b["attacker_serial"]
	return a_attacker < b_attacker


# 8. Death resolution in order Tower, bosses, player, other enemies.
func _step_08_death_resolution() -> void:
	_last_step_log.append("08_death_resolution")
	# P1.5 death_state.gd.


# 9. Drops.
func _step_09_drops() -> void:
	_last_step_log.append("09_drops")
	# P1.3 pools; P2.8 drop tables.


# 10. Pickup movement and collection.
func _step_10_pickup_movement_and_collection() -> void:
	_last_step_log.append("10_pickup_movement_and_collection")
	# P2.8.


# 11. XP and level-up requests.
func _step_11_xp_and_level_up_requests() -> void:
	_last_step_log.append("11_xp_and_level_up_requests")
	# P2.10/P2.12.


# 12. Console channel completion (void if either pool reached 0 this tick;
# "confirmed" = channel completed).
func _step_12_console_channel_completion() -> void:
	_last_step_log.append("12_console_channel_completion")
	# P2.13; docs/19 Tower Console UI.


# 13. Wave Director.
func _step_13_wave_director() -> void:
	_last_step_log.append("13_wave_director")
	# P2.8 Wave Director.


# 14. PauseAuthority.flush(). Pause requests made during this tick apply
# here, never mid-resolution. Fully implemented: PauseAuthority is this
# same task's own deliverable.
func _step_14_pause_flush() -> void:
	_last_step_log.append("14_pause_flush")
	PauseAuthority.flush()


# 15. UI state.
func _step_15_ui_state() -> void:
	_last_step_log.append("15_ui_state")
	# Later UI tasks (docs/19).
