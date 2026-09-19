extends CharacterBody2D
class_name EnemyController

## EnemyController (P2.5). docs/09_Enemy_AI_Architecture.md > "Intent
## Behaviour Defaults" in full is this file's complete owning section:
## Attack slots, the Tower Seeker body-block rule, the Player Hunter leash
## rule, the Opportunist event rule, the stuck rules, and the telegraph
## minimums. One script drives all three prototype intents (Tower Seeker,
## Player Hunter, Opportunist) rather than three separate classes, because
## docs/09's leash rule requires a Hunter to become "a full Tower Seeker...
## while keeping its current HP" -- a live re-skin of the SAME node/instance
## is far simpler and safer (no re-parenting, no losing pooled-instance
## identity, no EntityRegistry churn beyond a re-tag) than swapping scripts
## or scenes at runtime. `current_intent` starts from `definition.
## target_intent` and only ever changes via `_convert_to_tower_seeker()`.
##
## Builds on the P1.5 framework exactly as instructed ("do not
## reimplement"): `src/combat/hitbox.gd`, `hurtbox.gd`, and `death_state.gd`
## are reused unmodified, in the same node layout
## `scenes/entities/placeholder_enemy.tscn` already established (BodyShape,
## Hurtbox, Hitbox, DeathState).
##
## ## No NavigationAgent2D
## Register > Spawning & Waves > "Attack slots (C-SLOTS)": "the prototype
## uses no NavigationAgent2D". Steering is seek-plus-separation, computed
## every tick inside this controller (SimLoop step 3, once wired -- see
## "SimLoop wiring" below), never a NavigationAgent2D path query. The
## `ai-navigation` skill's entire NavigationAgent2D section does not apply
## here; this is the documented, expected skill-vs-project departure
## CLAUDE.md and this task's own brief both name in advance.
##
## ## SimLoop wiring (task instruction, matching src/player/player.gd's and
## src/combat/auto_weapon.gd's own precedent exactly)
## docs/20's SimLoop order names step 3 ("enemy AI and movement") as the
## real integration point, but `src/core/sim_loop.gd`'s
## `_step_03_enemy_ai_and_movement()` is still an empty stub and `src/core/`
## is outside this task's write scope. `physics_step(delta)` is exposed
## publicly and `driven_externally` (default false) lets a future SimLoop
## integration take over without this node ever double-stepping in the same
## tick -- the same seam P2.1/P2.3/P2.4 already established for their own
## SimLoop steps.
##
## ## Immediate hit resolution, not SimLoop's (unconsumed) hit queue
## Matching src/tower/tower_projectile.gd's own header precedent exactly:
## docs/20 states an Area2D overlap callback "must only enqueue a hit
## record... for step 7 to process, never resolve damage directly," but the
## P1.5 framework this task builds on (hitbox.gd's own `_on_area_entered()`)
## already resolves synchronously via `hurtbox.receive_hit()`, and
## SimLoop's step 7 clears `_hit_queue` without ever consuming it. This
## file follows that same established precedent (melee wind-ups and contact
## ticks both resolve through `Hitbox.activate_window()`/
## `deactivate_window()`, never through `SimLoop.enqueue_hit()`) rather than
## being the first attacker in this codebase to route through a queue
## nothing drains. Named again here, not silently repeated, because this
## task's own brief calls the enqueue_hit rule out explicitly.
##
## ## The EntityRegistry "tower_seeker" tag (LEDGER F03-15)
## `src/tower/tower_weapon.gd`'s `SEEKER_TAG`/`ENEMY_TAG` constants are read
## here, not retyped: every enemy registers under `ENEMY_TAG`, and a Tower
## Seeker (by spawn OR by leash conversion) additionally registers under
## `SEEKER_TAG`. A Hunter that converts re-registers (deregister, then
## register with the new tag set) rather than trying to mutate tags on an
## already-registered entity -- EntityRegistry has no "add a tag" command,
## only a tag list supplied at `register_entity()` time.
##
## ## Cross-task seam: the Tower is not in EntityRegistry
## Unlike the player (`src/player/player.gd` registers itself under
## `&"player"`), `src/tower/tower.gd` never calls `EntityRegistry.
## register_entity()` for itself -- confirmed by reading every file under
## `src/tower/`. Tower Seekers and Opportunists therefore cannot find "the
## Tower" via any EntityRegistry query. This controller exposes
## `set_tower_reference(tower)` (a typed command) and an `@export
## tower_path` fallback, mirroring `src/tower/tower_weapon.gd`'s own
## `origin_path` seam for the same class of gap. Named as a cross-task seam
## for the evidence report, not silently patched by registering the Tower
## from enemy code (which would make an enemy responsible for another
## system's own registration).

const CONTACT_HITBOX_MARGIN_PX: float = 6.0 # docs/20 > Physics & Collisions > "Entity sizes": "Every enemy's contact hitbox radius is its body radius plus 6 px" -- a real, cited rule, not an escalation.

signal windup_started()
signal attack_resolved(target: Node2D, damage: float)
signal leash_telegraph_started()
signal converted_to_tower_seeker()
signal target_switched(new_target: Node2D)
signal removed_while_stuck(position: Vector2, drop_table: DropTable)

## Set true by a future SimLoop integration task once sim_loop.gd's step 3
## calls into this controller directly; see header.
@export var driven_externally: bool = false

## The typed data contract this enemy reads every tuning value from.
## `data/enemies/*.tres`; swapped live by `_convert_to_tower_seeker()`.
@export var definition: EnemyDefinition = null

## Register-cited numbers docs/09 requires that have no home in the Enemy
## Definition Contract -- see src/enemy/enemy_ai_tuning.gd's own header.
@export var tuning: EnemyAITuning = preload("res://src/enemy/enemy_ai_tuning.tres")

## Read only for `base_speed_px_per_second` (Register > Player & Weapons:
## "320 px/s (reference 1.0)") -- MovementProfile.speed_multiplier is
## defined relative to this value (docs/20 > Contract Field Semantics >
## "Movement profile"), so this reference avoids hardcoding "320" anywhere
## in this file.
@export var player_definition_for_speed_reference: PlayerDefinition = preload("res://data/player/prototype.tres")

## What a converting Player Hunter becomes. Unused by a Tower Seeker or
## Opportunist instance (harmless to leave assigned on every scene).
@export var seeker_definition_for_conversion: EnemyDefinition = preload("res://data/enemies/tower_seeker.tres")

## Register > Spawning & Waves > "Overtime finishers": "no leash timer, the
## finisher flag survives any conversion". Not spawned by anything in this
## task's scope (the Wave Director is P2.8) -- included because docs/09
## and the Register both name it explicitly as a Player Hunter exception.
@export var is_finisher: bool = false

## Optional direct wiring to a Tower instance -- see header, "Cross-task
## seam: the Tower is not in EntityRegistry".
@export var tower_path: NodePath

## Integration task, docs/25_Asset_Pipeline.md: cues played through the
## existing AudioPool (src/audio/audio_pool.gd) on this enemy taking damage
## and on this enemy's own death -- never a hardcoded path (D99), never a
## second/duplicate pool. Both null-tolerant (no sound) like every other
## optional audio hook in this project.
@export var hit_sfx: AudioStream
@export var death_sfx: AudioStream
var _audio_pool: Node = null

@export var body_shape_path: NodePath = NodePath("BodyShape")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")
@export var hurtbox_shape_path: NodePath = NodePath("Hurtbox/HurtboxShape")
@export var hitbox_path: NodePath = NodePath("Hitbox")
@export var hitbox_shape_path: NodePath = NodePath("Hitbox/HitboxShape")
@export var death_state_path: NodePath = NodePath("DeathState")

var body_shape: CollisionShape2D = null
var hurtbox: Hurtbox = null
var hurtbox_shape: CollisionShape2D = null
var hitbox: Hitbox = null
var hitbox_shape: CollisionShape2D = null
var death_state: DeathState = null

var current_intent: ContractEnums.TargetIntent = ContractEnums.TargetIntent.TowerSeeker

var _configured: bool = false
var _player: Node2D = null
var _tower: Node2D = null

## Only the Opportunist needs sticky target memory -- the Tower Seeker's
## target is always the Tower and the Player Hunter's is always the player,
## recomputed fresh every tick with no memory required (see
## `_get_current_target()`).
var _opportunist_target: Node2D = null
var _last_switch_time: float = -INF
var _out_of_range_since: float = -1.0

## Attack cycle (shared by Melee wind-ups and Contact ticks -- see header,
## "the same cycle model" note on `_process_attack_cycle()`).
var _next_hit_time: float = -1.0
var _windup_active: bool = false
var _hitbox_active_ticks_remaining: int = 0

## Tower Seeker body-block tracking (docs/09 > "Tower Seeker body-block
## rule").
var _is_body_blocked: bool = false
var _bodyblock_reference_time: float = -1.0
var _bodyblock_reference_position: Vector2 = Vector2.ZERO

## Player Hunter leash tracking (docs/09 > "Player Hunter leash rule").
var _leash_deadline: float = -1.0
var _leash_telegraph_active: bool = false

## Stuck-rule tracking (docs/09 > "Stuck rules"). `_stuck_episode_start_
## time` drives `_stuck_seconds` (the 3/8/20s staged marks) for the whole
## episode; `_progress_reference_*` is only the checkpoint progress is
## measured against and may be re-anchored mid-episode (an Opportunist's 3s
## secondary-target switch) without resetting the episode clock -- see
## `_update_stuck_tracking()`'s own comment for exactly how and why the two
## are kept separate.
var _stuck_episode_start_time: float = -1.0
var _progress_reference_time: float = -1.0
var _progress_reference_distance: float = 0.0
var _stuck_seconds: float = 0.0
var _did_3s_fallback: bool = false
var _direct_approach: bool = false
var _stuck_despawned: bool = false

## Test-injectable references, matching this project's established
## convention (player.gd, tower_weapon.gd, death_state.gd, ...).
var _registry: Node = null
var _clock: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"pool_body")
	collision_layer = CollisionLayers.LAYER_ENEMY_BODY
	collision_mask = CollisionLayers.MASK_ENEMY_BODY_GROUND
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	body_shape = get_node_or_null(body_shape_path) as CollisionShape2D
	hurtbox = get_node_or_null(hurtbox_path) as Hurtbox
	hurtbox_shape = get_node_or_null(hurtbox_shape_path) as CollisionShape2D
	hitbox = get_node_or_null(hitbox_path) as Hitbox
	hitbox_shape = get_node_or_null(hitbox_shape_path) as CollisionShape2D
	death_state = get_node_or_null(death_state_path) as DeathState

	if hitbox != null:
		hitbox.owner_entity = self
		hitbox.hit_landed.connect(_on_hitbox_hit_landed)
	if hurtbox != null:
		hurtbox.damage_received.connect(_on_hurtbox_damage_received)
	if death_state != null:
		# Integration task: THIS enemy's OWN death (distinct from
		# _connect_target_death_signal(), which listens to an OPPORTUNIST
		# TARGET's death for the event rule) -- plays death_sfx once,
		# through the existing AudioPool, never a second/duplicate signal
		# path. src/combat/death_state.gd itself is on this integration
		# task's do-not-touch list; this only connects to its already-public
		# `logical_death` signal from a file that IS in scope.
		death_state.logical_death.connect(_on_own_logical_death)

	if _registry == null:
		_registry = EntityRegistry
	if _clock == null:
		_clock = SimClock

	if definition != null:
		current_intent = definition.target_intent
	_apply_definition()

	if tower_path != NodePath():
		var n: Node = get_node_or_null(tower_path)
		if n is Node2D:
			_tower = n as Node2D

	_register_with_entity_registry()
	_configured = definition != null and tuning != null


func _register_with_entity_registry() -> void:
	if _registry == null:
		return
	var tags: Array = [TowerWeapon.ENEMY_TAG]
	if current_intent == ContractEnums.TargetIntent.TowerSeeker:
		tags.append(TowerWeapon.SEEKER_TAG)
	_registry.register_entity(self, global_position, tags)


func _exit_tree() -> void:
	if _registry != null and _registry.is_registered(self):
		_registry.deregister_entity(self)
	AttackSlotManager.release_claim(_tower, self)
	AttackSlotManager.release_claim(_player, self)
	AttackSlotManager.release_claim(_opportunist_target, self)


## Applies every tuning value from `definition` to this instance's live
## nodes/components. Called from `_ready()` (preserved_hp < 0, a fresh
## spawn) and from `_convert_to_tower_seeker()` (preserved_hp >= 0, the
## leash rule's "keeping its current HP").
func _apply_definition(preserved_hp: float = -1.0) -> void:
	if definition == null:
		push_error("EnemyController: definition (EnemyDefinition) is null -- nothing to read Register values from")
		return

	var body_radius: float = float(definition.movement_profile.body_radius_px) if definition.movement_profile != null else 0.0
	_set_circle_radius(body_shape, body_radius)
	_set_circle_radius(hurtbox_shape, body_radius) # "hurtbox equals the body" -- placeholder_enemy.gd's own extension of the Player-only Contract wording, reused here for consistency.
	_set_circle_radius(hitbox_shape, body_radius + CONTACT_HITBOX_MARGIN_PX)

	if hitbox != null:
		# Tower Seeker and Opportunist can both end up attacking the Tower
		# (Seeker always; Opportunist whenever its current target IS the
		# Tower) as well as the player (Seeker's body-block rule; Opportunist
		# targeting the player) -- the SAME physical hitbox naturally hits
		# whichever hurtbox is actually in range when it activates, so no
		# per-target branching is needed at hit-resolution time, only at mask
		# level. Player Hunter's Contact behaviour never damages the Tower
		# (Register > Enemies > "All enemies": "No contact damage to the
		# Tower").
		var targets_tower: bool = current_intent != ContractEnums.TargetIntent.PlayerHunter
		hitbox.targets_tower = targets_tower
		hitbox.collision_mask = CollisionLayers.MASK_ENEMY_HITBOX_PLAYER_AND_TOWER if targets_tower else CollisionLayers.MASK_ENEMY_HITBOX_PLAYER_ONLY

	if death_state != null:
		var max_hp: float = float(definition.health_band.value) if definition.health_band != null else 0.0
		death_state.max_hp = max_hp
		if preserved_hp >= 0.0:
			death_state.current_hp = minf(preserved_hp, max_hp) # leash rule: "keeping its current HP"
		else:
			death_state.reset_for_reuse()

	if current_intent == ContractEnums.TargetIntent.PlayerHunter and not is_finisher:
		_leash_deadline = _now() + tuning.leash_timeout_seconds
	else:
		_leash_deadline = -1.0
	_leash_telegraph_active = false


static func _set_circle_radius(shape_node: CollisionShape2D, radius: float) -> void:
	if shape_node == null or not (shape_node.shape is CircleShape2D):
		return
	(shape_node.shape as CircleShape2D).radius = radius


func _now() -> float:
	return _clock.now if _clock != null else 0.0


func _current_speed() -> float:
	var multiplier: float = definition.movement_profile.speed_multiplier if definition != null and definition.movement_profile != null else 0.0
	var base_speed: float = player_definition_for_speed_reference.base_speed_px_per_second if player_definition_for_speed_reference != null else 0.0
	return base_speed * multiplier


func _body_radius() -> float:
	return float(definition.movement_profile.body_radius_px) if definition != null and definition.movement_profile != null else 0.0


func _reach() -> float:
	return float(definition.attack_profile.reach_or_range_px) if definition != null and definition.attack_profile != null else 0.0


# --- Test-only seams (never called by gameplay code) ----------------------

func set_registry_for_test(registry: Node) -> void:
	_registry = registry


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func set_player_for_test(player: Node2D) -> void:
	_player = player


## Typed command (not test-only -- this is the real seam a future
## integration task calls once scenes/main.tscn wires Tower + enemies
## together; see header). Also usable directly from a test.
func set_tower_reference(tower: Node2D) -> void:
	_tower = tower


## Typed command (integration task): wires the shared AudioPool `hit_sfx`/
## `death_sfx` play through. Also usable directly from a test.
func set_audio_pool_ref(pool: Node) -> void:
	_audio_pool = pool


func get_current_intent() -> ContractEnums.TargetIntent:
	return current_intent


func get_target_for_test() -> Node2D:
	return _get_current_target()


func is_direct_approach_for_test() -> bool:
	return _direct_approach


func get_stuck_seconds_for_test() -> float:
	return _stuck_seconds


func is_stuck_despawned() -> bool:
	return _stuck_despawned


func is_body_blocked_for_test() -> bool:
	return _is_body_blocked


func is_windup_active() -> bool:
	return _windup_active


func is_leash_telegraphing() -> bool:
	return _leash_telegraph_active


func get_leash_deadline_for_test() -> float:
	return _leash_deadline


func set_leash_deadline_for_test(deadline: float) -> void:
	_leash_deadline = deadline


func get_claimed_slot_for_test() -> int:
	var target: Node2D = _get_current_target()
	if target == null:
		return -1
	return AttackSlotManager.current_claim(target, self)


func is_waiting_for_slot_for_test() -> bool:
	var target: Node2D = _get_current_target()
	if target == null or _direct_approach:
		return false
	var plan: Dictionary = _compute_slot_plan(target, _target_radius(target))
	return plan.get("is_waiting_for_slot", false)


func get_last_switch_time_for_test() -> float:
	return _last_switch_time


# --- Physics step (SimLoop step 3 seam) ------------------------------------

func _physics_process(delta: float) -> void:
	if driven_externally:
		return
	physics_step(delta)


func physics_step(delta: float) -> void:
	if not _configured or _stuck_despawned:
		return
	if death_state != null and death_state.is_dead:
		return

	_resolve_player_reference()
	_resolve_tower_reference()

	if current_intent == ContractEnums.TargetIntent.PlayerHunter:
		_update_leash()
		if _stuck_despawned or (death_state != null and death_state.is_dead):
			return

	if current_intent == ContractEnums.TargetIntent.Opportunist and (_opportunist_target == null or not is_instance_valid(_opportunist_target)):
		_pick_opportunist_initial_target()

	var target: Node2D = _get_current_target()
	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if current_intent == ContractEnums.TargetIntent.TowerSeeker:
		_update_body_block_tracking()
	else:
		_is_body_blocked = false

	var in_attack_range: bool = _is_in_attack_range(target)
	var plan: Dictionary = _empty_plan()
	if not in_attack_range and not _direct_approach:
		plan = _compute_slot_plan(target, _target_radius(target))

	_update_stuck_tracking(target, in_attack_range, plan)
	if _stuck_despawned:
		return

	if current_intent == ContractEnums.TargetIntent.Opportunist:
		_update_opportunist_out_of_range(target)

	if in_attack_range:
		velocity = Vector2.ZERO
		move_and_slide()
		if _registry != null:
			_registry.update_position(self, global_position)
	else:
		var desired: Vector2 = _desired_position(target, plan)
		_apply_movement(desired, _current_speed())

	_process_attack_cycle(in_attack_range, target)


func _resolve_player_reference() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if _registry == null:
		return
	var players: Array[Node2D] = _registry.get_entities_with_tag(&"player")
	if not players.is_empty():
		_player = players[0]


func _resolve_tower_reference() -> void:
	if _tower != null and is_instance_valid(_tower):
		return
	if tower_path != NodePath():
		var n: Node = get_node_or_null(tower_path)
		if n is Node2D:
			_tower = n as Node2D


## The enemy's current target -- fixed by intent for the Tower Seeker
## (always the Tower) and Player Hunter (always the player); sticky,
## event-driven memory only for the Opportunist (`_opportunist_target`).
func _get_current_target() -> Node2D:
	match current_intent:
		ContractEnums.TargetIntent.TowerSeeker:
			return _tower
		ContractEnums.TargetIntent.PlayerHunter:
			return _player
		ContractEnums.TargetIntent.Opportunist:
			return _opportunist_target
		_:
			return null


# --- Distance helpers -------------------------------------------------------

## Register > Spawning & Waves footprint radius; Player body radius. Used
## both for the attack-slot ring geometry and for the Opportunist's
## "footprint edge" distance rule.
func _target_radius(target: Node2D) -> float:
	if target == _tower and target is Tower:
		var t: Tower = target as Tower
		if t.definition != null and t.definition.tower_footprint != null:
			return float(t.definition.tower_footprint.footprint_radius_px)
		return 0.0
	if target is Player:
		var p: Player = target as Player
		return float(p.definition.body_radius_px) if p.definition != null else 0.0
	return 0.0


## docs/09 > "Opportunist event rule": "Tower distance is measured to the
## Tower's footprint edge" -- stated for the Tower specifically, not for the
## player, so a player target uses plain centre-to-centre distance here by
## deliberate omission, not an oversight. Used by the Opportunist's aggro
## range check, out-of-range timer, and 25%-closer switch comparison.
func _event_distance_to(target: Node2D) -> float:
	var raw: float = global_position.distance_to(target.global_position)
	if target == _tower:
		raw -= _target_radius(target)
	return maxf(raw, 0.0)


## Surface-to-surface gap (centre distance minus BOTH radii), matching the
## attack-slot ring formula's own internal geometry (Register > Spawning &
## Waves > "Attack slots (C-SLOTS)": ring radius = target radius + attacker
## body radius + reach -- i.e. reach is the gap beyond both surfaces, not a
## centre-to-centre figure). Used for the melee/contact attack-range gate,
## a DIFFERENT distance than `_event_distance_to()` above -- named
## explicitly since the two could easily be conflated.
func _reach_distance_to(target: Node2D) -> float:
	var raw: float = global_position.distance_to(target.global_position)
	return maxf(raw - _target_radius(target) - _body_radius(), 0.0)


## This is also, by construction, THE mechanism behind "time a Tower
## Seeker spends blocked by the player's body accrues no stuck time"
## (this task's own brief): `_update_stuck_tracking()`'s very first line
## is `if in_attack_range: ... return`, so a body-blocked Seeker never
## reaches that function's stuck-accrual logic at all while this returns
## true. There is deliberately no SEPARATE "exempt" flag for body-block
## inside stuck-tracking -- an earlier version had one, proved unreachable
## dead code by this task's own falsification pass (see
## `_update_stuck_tracking()`'s header), and was removed.
func _is_in_attack_range(target: Node2D) -> bool:
	if _reach_distance_to(target) <= _reach():
		return true
	# Tower Seeker body-block rule: "it attacks the player with its normal
	# telegraphed attack... without changing intent" -- while blocked, the
	# Seeker's target stays the Tower (current_target unaffected) but the
	# SAME attack cycle below actually lands on whichever hurtbox (player's)
	# is physically in the hitbox's reach; see _apply_definition()'s
	# targets_tower comment for why one hitbox mask covers both cases.
	if current_intent == ContractEnums.TargetIntent.TowerSeeker and _is_body_blocked:
		return true
	return false


# --- Tower Seeker body-block rule -------------------------------------------

## docs/09 > "Tower Seeker body-block rule": "Blocked means less than 8 px
## of progress over 2 seconds with the player within the Seeker's 20 px
## reach... While blocked it attacks the player... and resumes its path the
## moment it is clear." Interpretation, named rather than silently assumed:
## the BLOCKED judgement itself is only re-evaluated at each 2-second
## checkpoint (the rule is inherently windowed -- "over 2 seconds"), but
## un-blocking is applied immediately the instant the player leaves reach,
## matching "resumes the moment it is clear" literally.
func _update_body_block_tracking() -> void:
	if _player == null or not is_instance_valid(_player):
		_is_body_blocked = false
		return
	var now: float = _now()
	var player_in_reach: bool = global_position.distance_to(_player.global_position) <= _reach()
	if not player_in_reach:
		_is_body_blocked = false
	if _bodyblock_reference_time < 0.0:
		_bodyblock_reference_time = now
		_bodyblock_reference_position = global_position
		return
	if now - _bodyblock_reference_time >= tuning.body_block_window_seconds:
		var progressed: float = _bodyblock_reference_position.distance_to(global_position)
		_is_body_blocked = player_in_reach and progressed < tuning.body_block_min_progress_px
		_bodyblock_reference_time = now
		_bodyblock_reference_position = global_position


# --- Attack slots and steering ----------------------------------------------

static func _empty_plan() -> Dictionary:
	return {"slot_count": 0, "radius": 0.0, "claimed_slot": -1, "is_waiting_for_slot": false}


## C-SLOTS: claims the nearest free slot once within `attack_slot_claim_
## radius_px` of the ring; otherwise reports `is_waiting_for_slot` so the
## caller can both position this enemy at the 32 px wait offset AND exempt
## it from stuck-time accrual (see `_update_stuck_tracking()`).
func _compute_slot_plan(target: Node2D, target_radius: float) -> Dictionary:
	var body_r: float = _body_radius()
	var reach: float = _reach()
	var slot_count: int = AttackSlotManager.compute_slot_count(target_radius, body_r, reach)
	var radius: float = AttackSlotManager.ring_radius(target_radius, body_r, reach)
	var claimed: int = AttackSlotManager.current_claim(target, self)
	var distance_to_ring: float = absf(global_position.distance_to(target.global_position) - radius)
	var waiting_for_slot: bool = false
	if claimed == -1 and distance_to_ring <= tuning.attack_slot_claim_radius_px:
		claimed = AttackSlotManager.claim_nearest_free_slot(target, self, slot_count, radius)
		waiting_for_slot = claimed == -1
	return {"slot_count": slot_count, "radius": radius, "claimed_slot": claimed, "is_waiting_for_slot": waiting_for_slot}


func _desired_position(target: Node2D, plan: Dictionary) -> Vector2:
	if _direct_approach:
		return target.global_position
	var claimed: int = plan.get("claimed_slot", -1)
	if claimed != -1:
		return AttackSlotManager.slot_world_position(target, claimed, plan.get("slot_count", 0), plan.get("radius", 0.0))
	if plan.get("is_waiting_for_slot", false):
		var dir_from_target: Vector2 = global_position - target.global_position
		if dir_from_target.length_squared() < 0.0001:
			dir_from_target = Vector2.RIGHT
		dir_from_target = dir_from_target.normalized()
		var wait_radius: float = plan.get("radius", 0.0) + tuning.attack_slot_wait_offset_px
		return target.global_position + dir_from_target * wait_radius
	return target.global_position # still travelling generally toward the target/ring


## Seek toward `desired_position` plus separation from other enemies within
## `separation_neighbor_radius_px` (C-SLOTS: "separation from EntityRegistry
## neighbours within 32 px"), computed here inside the controller's own
## per-tick step -- no NavigationAgent2D (see header).
func _apply_movement(desired_position: Vector2, speed: float) -> void:
	var to_desired: Vector2 = desired_position - global_position
	var seek: Vector2 = to_desired.normalized() if to_desired.length_squared() > 1.0 else Vector2.ZERO
	var separation: Vector2 = Vector2.ZERO
	if _registry != null and tuning.separation_neighbor_radius_px > 0.0:
		var neighbors: Array[Node2D] = _registry.get_entities_in_radius(global_position, tuning.separation_neighbor_radius_px, TowerWeapon.ENEMY_TAG)
		for n in neighbors:
			if n == self or not is_instance_valid(n):
				continue
			var away: Vector2 = global_position - n.global_position
			var dist: float = away.length()
			if dist < 0.001:
				away = Vector2(randf() - 0.5, randf() - 0.5)
				dist = 0.001
			separation += away.normalized() * ((tuning.separation_neighbor_radius_px - dist) / tuning.separation_neighbor_radius_px)
	var steering: Vector2 = seek + separation
	velocity = steering.normalized() * speed if steering.length_squared() > 0.0001 else Vector2.ZERO
	move_and_slide()
	if _registry != null:
		_registry.update_position(self, global_position)


# --- Stuck rules -------------------------------------------------------------

## docs/09 > "Stuck rules": "After 3 seconds without path progress (its
## distance to target has shrunk by less than 8 pixels) it falls back...
## After 8 seconds of less than 8 pixels of displacement the global stuck
## detector forces direct approach; after 20 seconds still stuck it
## despawns." Interpretation, named rather than silently assumed: this is
## ONE continuous stuck-duration clock with staged one-time consequences at
## the 3/8/20 second marks, not three independent timers -- "still stuck"
## at 20 s reads as a continuation of the same episode the 3 s/8 s marks
## already flagged, not a fresh countdown. "Progress" is measured against a
## reference checkpoint (distance-to-target at the last time real progress
## was confirmed), reset the instant an 8 px improvement over that
## checkpoint is observed; while no such improvement occurs, elapsed time
## since the checkpoint IS the stuck duration.
##
## Two exemptions, per this task's own binding brief. The queued/waiting-
## for-a-slot one is a real, live branch below (`plan.is_waiting_for_slot`),
## continuously refreshing the checkpoint so no stuck time is retroactively
## charged once the exemption ends. The Tower Seeker body-block one is
## real too, but this function is provably NOT where it lives: a body-
## blocked Seeker is already `in_attack_range` (`_is_in_attack_range()`'s
## own body-block branch returns true unconditionally whenever `_is_body_
## blocked` is set, regardless of distance), so this function's own FIRST
## line (`if in_attack_range: ... return`) already exits before reaching
## the exempt check below for every Tower Seeker body-block case there is.
## An earlier version of this function ALSO OR'd `_is_body_blocked` into
## `exempt` here, as if this were a second, independent safeguard; this
## task's own falsification pass proved that clause was unreachable dead
## code by mutating it (setting it to always-false) and confirming zero
## effect on `tests/unit/stuck_exemption_test.gd`'s body-block test --
## which only changed outcome once the mutation targeted `_is_in_attack_
## range()`'s own body-block branch instead. Removed rather than left in
## as false reassurance; see the P2.5 evidence report.
##
## Two separate pieces of state, deliberately not one: `_stuck_episode_
## start_time` is when THIS stuck episode began, and drives `_stuck_seconds`
## (the 3/8/20 s staged marks) continuously across the episode, even across
## an Opportunist's 3 s secondary-target switch. `_progress_reference_*` is
## only the CHECKPOINT progress is measured against, and is deliberately
## re-anchored (without touching the episode clock) whenever the thing
## being measured against changes -- otherwise a post-switch tick would
## compare "distance to the NEW target now" against "distance to the OLD
## target a while ago", two unrelated numbers.
func _update_stuck_tracking(target: Node2D, in_attack_range: bool, plan: Dictionary) -> void:
	if in_attack_range:
		_clear_stuck_episode()
		return
	var exempt: bool = plan.get("is_waiting_for_slot", false)
	var now: float = _now()
	var current_distance: float = _reach_distance_to(target)
	if exempt:
		# A real bug lived here, found and fixed during this task's own
		# falsification pass: pre-seeding ONLY `_progress_reference_time`
		# (leaving `_stuck_episode_start_time` at _clear_stuck_episode()'s
		# -1 sentinel) meant that the instant exemption ended, the "cold
		# start" branch below was skipped (`_progress_reference_time` was
		# no longer < 0), and `_stuck_seconds = now - _stuck_episode_start_
		# time` computed `now - (-1.0)` -- a bogus value that instantly
		# exceeded the 20s despawn threshold, DESPAWNING an enemy the very
		# tick it finally got a free attack slot. `_clear_stuck_episode()`
		# alone is correct and sufficient: the first non-exempt tick then
		# falls through to the real cold-start branch below, which
		# initialises BOTH fields together, consistently.
		_clear_stuck_episode()
		return
	if _progress_reference_time < 0.0:
		_progress_reference_time = now
		_progress_reference_distance = current_distance
		_stuck_episode_start_time = now
		return
	if _progress_reference_distance - current_distance >= tuning.stuck_no_progress_px:
		# Same fix as the exempt branch above, same reasoning: do not
		# pre-seed `_progress_reference_time` here and leave `_stuck_
		# episode_start_time` at -1 -- the very next tick's cold-start
		# branch initialises both together.
		_clear_stuck_episode()
		return
	_stuck_seconds = now - _stuck_episode_start_time
	if _stuck_seconds >= tuning.stuck_despawn_seconds:
		_despawn_due_to_stuck(target)
		return
	if _stuck_seconds >= tuning.stuck_global_direct_approach_seconds:
		_direct_approach = true
	if _stuck_seconds >= tuning.stuck_no_progress_seconds and not _did_3s_fallback:
		_did_3s_fallback = true
		_apply_3s_stuck_fallback()


func _clear_stuck_episode() -> void:
	_stuck_episode_start_time = -1.0
	_progress_reference_time = -1.0
	_stuck_seconds = 0.0
	_did_3s_fallback = false
	_direct_approach = false


## "falls back to its secondary target or a direct approach if it has
## none. Prototype secondary targets: Tower Seekers and Player Hunters have
## none (their 3 s stuck step is direct approach); the Opportunist's is the
## other target." This fallback bypasses the Opportunist's own 25%-closer/
## lockout gate deliberately: that gate exists to prevent flip-flopping
## between two live, comparably attractive targets, not to block an
## un-sticking manoeuvre.
func _apply_3s_stuck_fallback() -> void:
	if current_intent == ContractEnums.TargetIntent.Opportunist:
		var other: Node2D = _tower if _opportunist_target == _player else _player
		if other != null and is_instance_valid(other):
			_set_opportunist_target(other, true)
			# Re-anchor the PROGRESS baseline to the new target -- see this
			# function group's header comment. `_stuck_episode_start_time`
			# (and therefore `_stuck_seconds`) is deliberately left alone:
			# this is still the same episode, now pursuing a different
			# target, not a fresh one restarting the 8s/20s clock.
			_progress_reference_time = _now()
			_progress_reference_distance = _reach_distance_to(other)
			return
	_direct_approach = true


func _despawn_due_to_stuck(target: Node2D) -> void:
	if _stuck_despawned:
		return
	_stuck_despawned = true
	AttackSlotManager.release_claim(target, self)
	AttackSlotManager.release_claim(_opportunist_target, self)
	if _registry != null and _registry.is_registered(self):
		_registry.deregister_entity(self)
	velocity = Vector2.ZERO
	# "it despawns, its drops are placed at its position, and it counts as
	# removed, not killed" (docs/09) -- this MUST NOT go through
	# death_state.apply_damage()/kill(), which would emit EventBus.
	# emit_enemy_died() and mislabel a removal as a kill (the same class of
	# mislabelling LEDGER F03-06 already flags for the player's own death).
	# No EventBus signal exists for "enemy removed, not killed, with drops
	# to place" -- src/core/event_bus.gd is outside this task's scope to
	# extend, so this local signal is what a future pickup/wave-completion
	# system connects to once it exists. Named as an Escalation.
	removed_while_stuck.emit(global_position, definition.drop_table if definition != null else null)
	queue_free()


# --- Attack cycle (Melee wind-up and Contact tick share one model) --------

## Contact behaviour is exempt from windup minimums (docs/09 > "Telegraph
## minimums": "Body contact damage is exempt from these minimums, because
## approaching into contact range is itself the telegraph") -- a Contact
## enemy's own TelegraphData.windup_duration_seconds is authored as 0.0, so
## this single cycle model naturally collapses the wind-up phase to nothing
## for Contact without a separate code path: `windup_start == next_hit_time`
## when the duration is zero.
##
## Toggling `Hitbox.activate_window()`/`deactivate_window()` once per cycle
## (rather than leaving it permanently open) is required, not stylistic:
## Area2D's `area_entered` fires only on a NEW overlap, so a target standing
## continuously inside a permanently-open hitbox would only ever be hit
## once. This matches hitbox.gd's own documented usage pattern (docs/20 >
## SimLoop order step 6: "wind-up completion and contact ticks").
func _process_attack_cycle(in_attack_range: bool, _target: Node2D) -> void:
	if hitbox == null or definition == null or definition.attack_profile == null or definition.telegraph_data == null:
		return
	if not in_attack_range:
		if _hitbox_active_ticks_remaining > 0:
			_hitbox_active_ticks_remaining = 0
			hitbox.deactivate_window()
		_windup_active = false
		_next_hit_time = -1.0 # leaving range cancels the cycle -- re-entry starts a fresh wind-up, never a banked instant hit
		return

	var now: float = _now()
	if _hitbox_active_ticks_remaining > 0:
		_hitbox_active_ticks_remaining -= 1
		if _hitbox_active_ticks_remaining == 0:
			hitbox.deactivate_window()

	if _next_hit_time < 0.0:
		_next_hit_time = now + definition.attack_profile.cycle_or_tick_interval_seconds

	var windup_start: float = _next_hit_time - definition.telegraph_data.windup_duration_seconds
	if now >= windup_start and not _windup_active:
		_windup_active = true
		windup_started.emit()

	if now >= _next_hit_time:
		hitbox.activate_window()
		_hitbox_active_ticks_remaining = 2 # brief pulse -- long enough for the deferred `monitoring=true` to land and for Area2D to detect the overlap (matches ghost_hit_test.gd's own one-frame-settle precedent, plus one tick of margin)
		attack_resolved.emit(_target, float(definition.attack_profile.damage_per_hit_or_tick))
		_next_hit_time = now + definition.attack_profile.cycle_or_tick_interval_seconds
		_windup_active = false


## Player Hunter leash reset: "resets every time it lands a hit on the
## player" -- `Hitbox.hit_landed` only ever fires for a hit this enemy's OWN
## hitbox delivered (hitbox.gd's own signal), and a Player Hunter's hitbox
## mask is PlayerHurtbox-only (`_apply_definition()`'s `targets_tower =
## false`), so any landed hit while still a Hunter is, by construction, a
## hit on the player.
func _on_hitbox_hit_landed(_hurtbox: Hurtbox, _damage: float, _source: Variant) -> void:
	if current_intent == ContractEnums.TargetIntent.PlayerHunter and not is_finisher and death_state != null and not death_state.is_dead:
		_leash_deadline = _now() + tuning.leash_timeout_seconds
		_leash_telegraph_active = false


## Opportunist event rule, event 1: "it takes damage from the other
## target". `source` is the StringName tag the attacking weapon stamped at
## fire time (`&"player"` from src/combat/auto_weapon.gd, `&"tower"` from
## src/tower/tower_weapon.gd) -- resolved by value, matching docs/20's
## Projectile Orphans convention, so this handler never needs a live
## reference to the attacker.
func _on_hurtbox_damage_received(_amount: float, source: Variant, _hitbox: Node) -> void:
	# Integration task: plays regardless of intent, BEFORE the Opportunist-
	# only early return below (that return is about the event rule, not
	# about whether this enemy was hit at all).
	if _audio_pool != null and hit_sfx != null and _audio_pool.has_method("play"):
		_audio_pool.play(hit_sfx, global_position, 0, false, "SFX")
	if current_intent != ContractEnums.TargetIntent.Opportunist:
		return
	if _opportunist_target == null or not is_instance_valid(_opportunist_target):
		return
	var source_kind: StringName = source if source is StringName else &""
	if source_kind != &"player" and source_kind != &"tower":
		return
	var current_kind: StringName = &"tower" if _opportunist_target == _tower else &"player"
	if source_kind != current_kind:
		_opportunist_reevaluate()


# --- Player Hunter leash rule ------------------------------------------------

func _update_leash() -> void:
	if is_finisher or _leash_deadline < 0.0:
		return
	var now: float = _now()
	if _leash_telegraph_active:
		if now >= _leash_deadline + tuning.leash_telegraph_seconds:
			_convert_to_tower_seeker()
		return
	if now >= _leash_deadline:
		_leash_telegraph_active = true
		leash_telegraph_started.emit()


## "converts permanently into a full Tower Seeker -- it adopts the Tower
## Seeker's complete behaviour and stat profile while keeping its current
## HP." Re-tags with EntityRegistry (LEDGER F03-15: "a Hunter that converts
## under the leash rule becomes a full Tower Seeker, so its tags must
## change with it") since register_entity()/deregister_entity() is the only
## API EntityRegistry exposes -- there is no "add a tag to an already-
## registered entity" command.
func _convert_to_tower_seeker() -> void:
	var preserved_hp: float = death_state.current_hp if death_state != null else 0.0
	AttackSlotManager.release_claim(_player, self)
	if _registry != null and _registry.is_registered(self):
		_registry.deregister_entity(self)

	definition = seeker_definition_for_conversion
	current_intent = ContractEnums.TargetIntent.TowerSeeker
	_apply_definition(preserved_hp)

	_register_with_entity_registry()

	_next_hit_time = -1.0
	_windup_active = false
	_is_body_blocked = false
	_bodyblock_reference_time = -1.0
	converted_to_tower_seeker.emit()


# --- Opportunist event rule --------------------------------------------------

func _pick_opportunist_initial_target() -> void:
	if _player == null or _tower == null or not is_instance_valid(_player) or not is_instance_valid(_tower):
		return # both references must resolve before a spawn choice can be made
	var dist_player: float = _event_distance_to(_player)
	var dist_tower: float = _event_distance_to(_tower)
	_set_opportunist_target(_player if dist_player <= dist_tower else _tower, false)


func _set_opportunist_target(new_target: Node2D, is_switch: bool) -> void:
	if _opportunist_target != null and is_instance_valid(_opportunist_target):
		AttackSlotManager.release_claim(_opportunist_target, self)
		_disconnect_target_death_signal(_opportunist_target)
	_opportunist_target = new_target
	if new_target != null:
		_connect_target_death_signal(new_target)
	if is_switch:
		_last_switch_time = _now()
		target_switched.emit(new_target)


func _connect_target_death_signal(target: Node2D) -> void:
	var ds: Variant = target.get("death_state")
	if ds is DeathState and not (ds as DeathState).logical_death.is_connected(_on_opportunist_target_died):
		(ds as DeathState).logical_death.connect(_on_opportunist_target_died)


func _disconnect_target_death_signal(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var ds: Variant = target.get("death_state")
	if ds is DeathState and (ds as DeathState).logical_death.is_connected(_on_opportunist_target_died):
		(ds as DeathState).logical_death.disconnect(_on_opportunist_target_died)


## Opportunist event rule, event 3: "its current target dies".
func _on_opportunist_target_died(_entity: Node2D, _position: Vector2) -> void:
	_opportunist_reevaluate()


## Integration task: THIS enemy's own death (see the `_ready()` connection
## comment above for how this differs from `_on_opportunist_target_died`).
func _on_own_logical_death(_entity: Node2D, position: Vector2) -> void:
	if _audio_pool != null and death_sfx != null and _audio_pool.has_method("play"):
		_audio_pool.play(death_sfx, position, 0, false, "SFX")


## Opportunist event rule, event 2: the out-of-range timer. "the out-of-
## range event fires after 3 continuous seconds outside the 400 px aggro
## range, and its timer restarts after every re-evaluation, whether or not
## the Opportunist switched" -- restarted unconditionally inside
## `_opportunist_reevaluate()` itself (called from all three events), not
## only here, so a re-evaluation triggered by damage or a target's death
## also restarts this clock.
func _update_opportunist_out_of_range(target: Node2D) -> void:
	var dist: float = _event_distance_to(target)
	if dist > tuning.opportunist_aggro_range_px:
		if _out_of_range_since < 0.0:
			_out_of_range_since = _now()
		elif _now() - _out_of_range_since >= tuning.opportunist_out_of_range_seconds:
			_opportunist_reevaluate()
	else:
		_out_of_range_since = -1.0


## The shared re-evaluation procedure for all three event triggers.
## "switches only if the other target is at least 25% closer than the
## current target and at least 3 seconds have passed since its last
## switch" (hysteresis + switch lockout, both Provisional Defaults). If the
## current target is already dead (the "target dies" event, by
## definition), the closer/lockout gate is bypassed and the switch is
## forced -- that gate exists to stop flip-flopping between two live,
## comparably attractive targets, not to strand the Opportunist on a
## corpse. Named as an interpretation, since docs/09 does not spell out
## this specific interaction.
func _opportunist_reevaluate() -> void:
	_out_of_range_since = -1.0 # "its timer restarts after every re-evaluation, whether or not the Opportunist switched"
	if _opportunist_target == null or not is_instance_valid(_opportunist_target):
		return
	var other: Node2D = _tower if _opportunist_target == _player else _player
	if other == null or not is_instance_valid(other):
		return
	if _is_target_dead(_opportunist_target):
		_set_opportunist_target(other, true)
		return
	var dist_current: float = _event_distance_to(_opportunist_target)
	var dist_other: float = _event_distance_to(other)
	var lockout_elapsed: bool = _last_switch_time <= -INF or (_now() - _last_switch_time) >= tuning.opportunist_switch_lockout_seconds
	var closer_enough: bool = dist_other <= dist_current * (1.0 - tuning.opportunist_switch_closer_fraction)
	if closer_enough and lockout_elapsed:
		_set_opportunist_target(other, true)


static func _is_target_dead(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return true
	var ds: Variant = target.get("death_state")
	return ds is DeathState and (ds as DeathState).is_dead
