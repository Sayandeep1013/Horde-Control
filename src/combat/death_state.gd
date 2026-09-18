extends Node
class_name DeathState

## DeathState (P1.5; docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Logical Death"; > "Animation, Hitbox, and
## State Cleanup Rules" in full). The Logical/Visual Death state machine.
## Owns the one piece of HP tracking this task needs to know "the instant an
## entity's HP reaches 0" (docs/20's own phrase) -- see "HP ownership" below
## for why that is a named interpretation, not an assumption.
##
## ## Logical vs. Visual Death, step by step (docs/20 > "Animation, Hitbox,
## and State Cleanup Rules" > "Logical vs. Visual Death" and "Logical
## Death"):
## 1. `apply_damage()` is called (by a hurtbox's `damage_received` signal,
##    connected below). If `is_dead` is already true, the call is discarded
##    -- "checked first by every damage handler" -- before HP is touched.
## 2. HP drops. If HP is still > 0, nothing else happens this call.
## 3. If HP <= 0, `_enter_logical_death()` runs, in this exact order:
##    a. `is_dead = true` -- synchronous, first, unconditionally, before any
##       deferred call. This is what makes step 1's check meaningful for a
##       hit that lands later THIS SAME tick.
##    b. Every hurtbox's `mark_dead()` -- synchronous, so a hit already
##       in-flight against one of this entity's own hurtboxes is caught by
##       the hurtbox's own receive_hit() the instant it runs, not only by
##       this file's own re-entrancy guard.
##    c. Every hitbox's `deactivate_window()` -- Animation Cancellation:
##       "the attack state is immediately cancelled" -- cancels an
##       in-progress wind-up/active window synchronously AND queues the
##       deferred `monitoring = false`.
##    d. Every hurtbox's `apply_logical_death_layers()` -- deferred
##       `monitorable = false` and `collision_layer = 0`.
##    e. The body's `collision_layer` and `collision_mask` -- deferred, mask
##       becomes World + ArenaBounds only (CollisionLayers.DYING_BODY_MASK).
##    f. `EntityRegistry.set_entity_alive(entity, false)` -- see "The
##       set_entity_alive seam" below.
##    g. `EventBus.emit_enemy_died(entity, position)`.
##    h. This node's own `logical_death` signal, for any local listener
##       (the placeholder enemy's animation, once one exists).
## 4. Visual Death: `_physics_process` polls `SimClock.now` against a
##    deadline set at step 3 (never a raw per-frame countdown -- see "Visual
##    Death timing" below) while `is_dead` is true. The body keeps its
##    World+ArenaBounds mask throughout, so a knockback/ragdoll (none exists
##    yet on the placeholder) would still collide with terrain (docs/20 >
##    "Spatial Cleanup").
## 5. On timer expiry: `visual_death_finished` is emitted. This file does
##    NOT call Pool.release()/EntitySpawner.despawn_enemy() itself --
##    docs/20 > "Communication, events": "A system emits a signal; it never
##    calls a mutating function on another system." The owner (the
##    placeholder enemy) connects this signal and calls despawn.
##
## ## HP ownership
## docs/05 (Combat System) is a stub with no `Health` contract, and P1.5's
## own deliverable list is exactly `hitbox.gd`, `hurtbox.gd`, `death_state.gd`
## -- no fourth "health.gd" file. Rather than invent an unscoped fourth
## component, this file keeps the minimum HP tracking Logical Death's own
## definition requires ("the instant an entity's HP reaches 0") co-located
## with the flag it sets. `apply_damage(amount, source)` matches docs/20's
## own named command example, `Health.apply_damage(amount, source)`,
## letter-for-letter in signature shape even though the class is not named
## `Health`. Named here as an interpretation, not silently assumed.
##
## ## Visual Death timing
## SimClock's own header comment states the project rule directly: "Every
## gameplay deadline in this project is a value compared against
## SimClock.now, never a running countdown, and never driven by Timer,
## SceneTree.create_timer(), or SceneTree.create_tween()." A raw
## `_visual_death_elapsed += delta` counter would violate that rule, so this
## file instead stores `_visual_death_deadline = SimClock.now +
## visual_death_duration` at Logical Death and compares SimClock.now against
## it every physics tick. `process_mode = PROCESS_MODE_PAUSABLE` (matching
## SimClock/EntityRegistry/CombatStats) so the Visual Death timer stops with
## the simulation exactly as SimClock.now itself does -- an entity mid-death
## animation when the Level-Up Draft opens does not finish dying while the
## game is paused.
##
## ## The set_entity_alive seam (LEDGER F02-11, F02-12: P1.5 "owns Logical
## Death, so you own whether set_entity_alive() is the right seam"). RULING:
## yes, use it. EntityRegistry.set_entity_alive() flips a registered
## entity's liveness for QUERY purposes without deregistering it --
## entity_registry.gd's own header: "Logical Death ... sets a `dead` flag on
## the entity itself and keeps it in the scene (ragdoll/knockback, pool
## reuse later); this is the one sanctioned channel for that flag to reach
## the registry's query results." That is exactly this file's step 3f. The
## alternative -- deregistering at Logical Death instead -- would be wrong:
## entity_spawner.gd's own header states deregistration happens at DESPAWN
## (Pool.release()), not at Logical Death, specifically so "a dying-but-not-
## yet-pooled entity ... stays registered with alive=false and is excluded
## from live queries by that flag, not by being torn out of the registry."
## Wave/encounter completion (docs/11: "driven by EntityRegistry tag queries
## against actual live entities") needs exactly this: an enemy mid-Visual-
## Death must stop counting toward a wave's live-enemy total immediately,
## not wait for its Visual Death animation to finish and get pooled.

signal logical_death(entity: Node2D, position: Vector2)
signal visual_death_finished(entity: Node2D)
signal damage_applied(amount: float, source: Variant, remaining_hp: float)

## Framework/test-fixture defaults, NOT Provisional Values Register numbers
## -- see the P1.5 evidence report, "Contradictions and ambiguities," for
## why: no Enemy Definition Contract instance exists yet to supply a real
## HP/damage/Visual-Death-duration figure, and this component's own contract
## (docs/20 > "Logical vs. Visual Death") defines behaviour, not tuning.
## Every prototype enemy that replaces this placeholder must source its own
## values from the Register once one exists.
@export var max_hp: float = 30.0
@export var visual_death_duration: float = 0.6

## Node paths, resolved once in _ready() against this component's owner.
@export var hitbox_paths: Array[NodePath] = []
@export var hurtbox_paths: Array[NodePath] = []
@export var body_path: NodePath
## Defaults to `owner` (the scene root a placeholder/enemy instances) when
## left empty -- the Node2D EntityRegistry registers and EventBus reports
## position for.
@export var registry_entity_path: NodePath

var current_hp: float = 0.0
var is_dead: bool = false

var _hitboxes: Array[Hitbox] = []
var _hurtboxes: Array[Hurtbox] = []
var _body: Node = null
var _registry_entity: Node2D = null
var _visual_death_deadline: float = 0.0

## Test-injectable, default to the real Autoloads (same convention as
## entity_spawner.gd's set_registry_for_test()) -- a fresh instance per test
## so 100+ scripted deaths in the Ghost hit test never leak enemy_died
## signals or alive-flag writes into the project's real singletons.
var _registry: Node = null
var _event_bus: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_registry = EntityRegistry
	_event_bus = EventBus
	current_hp = max_hp
	_resolve_refs()
	set_physics_process(false)


func set_registry_for_test(registry: Node) -> void:
	_registry = registry


func set_event_bus_for_test(bus: Node) -> void:
	_event_bus = bus


func _resolve_refs() -> void:
	_hitboxes.clear()
	_hurtboxes.clear()
	for p in hitbox_paths:
		var n: Node = get_node_or_null(p)
		if n is Hitbox:
			_hitboxes.append(n as Hitbox)
	for p in hurtbox_paths:
		var n: Node = get_node_or_null(p)
		if n is Hurtbox:
			_hurtboxes.append(n as Hurtbox)
			(n as Hurtbox).damage_received.connect(_on_hurtbox_damage_received)
	_body = get_node_or_null(body_path)
	if registry_entity_path != NodePath():
		_registry_entity = get_node_or_null(registry_entity_path) as Node2D
	else:
		_registry_entity = owner as Node2D


func _on_hurtbox_damage_received(amount: float, source: Variant, _hitbox: Node) -> void:
	apply_damage(amount, source)


## Typed command (docs/20 named example shape: "Health.apply_damage(amount,
## source)"). Returns false (no HP change) if this entity is already dead --
## "checked first by every damage handler" -- or if `amount` is not
## positive.
func apply_damage(amount: float, source: Variant = null) -> bool:
	if is_dead:
		return false
	if amount <= 0.0:
		return false
	current_hp -= amount
	damage_applied.emit(amount, source, current_hp)
	if current_hp <= 0.0:
		current_hp = 0.0
		_enter_logical_death()
	return true


func _enter_logical_death() -> void:
	is_dead = true # synchronous, first, unconditional -- see header step 3a
	for hb in _hurtboxes:
		hb.mark_dead() # synchronous -- header step 3b
	for hb in _hitboxes:
		hb.deactivate_window() # Animation Cancellation -- header step 3c
	for hb in _hurtboxes:
		hb.apply_logical_death_layers() # deferred -- header step 3d
	if _body != null:
		_body.set_deferred("collision_layer", 0)
		_body.set_deferred("collision_mask", CollisionLayers.DYING_BODY_MASK)

	var death_position: Vector2 = _registry_entity.global_position if _registry_entity != null else Vector2.ZERO

	if _registry_entity != null and _registry != null and _registry.is_registered(_registry_entity):
		_registry.set_entity_alive(_registry_entity, false) # header step 3f / "The set_entity_alive seam"
	if _event_bus != null:
		_event_bus.emit_enemy_died(_registry_entity, death_position) # header step 3g

	logical_death.emit(_registry_entity, death_position) # header step 3h

	_visual_death_deadline = SimClock.now + visual_death_duration
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not is_dead:
		set_physics_process(false)
		return
	if SimClock.now >= _visual_death_deadline:
		set_physics_process(false)
		visual_death_finished.emit(_registry_entity)


## Test-only / future-caller convenience: forces death without a hurtbox hit
## (the Ghost hit test's "the victim dies from an external lethal blow"
## step reuses apply_damage() with a large amount instead of this, so real
## damage plumbing is exercised end to end; this exists for suites that only
## need "this entity is now dead" without caring about the amount).
func kill(source: Variant = null) -> void:
	apply_damage(max(current_hp, 1.0), source)


## Called by whoever re-spawns a pooled instance, AFTER Pool.acquire() has
## already restored the four engine flags from its own baseline snapshot --
## see hurtbox.gd/hitbox.gd's own reset_for_reuse() headers for why Pool
## cannot do this part itself (it has no knowledge of this file's is_dead
## flag or current_hp). A caller that forgets this on a reused instance
## gets an instance that still refuses all damage via apply_damage()'s own
## is_dead check, even though its Area2D flags look clean -- named as the
## sharpest edge of this whole framework in the P1.5 evidence report.
func reset_for_reuse() -> void:
	is_dead = false
	current_hp = max_hp
	_visual_death_deadline = 0.0
	set_physics_process(false)
	for hb in _hurtboxes:
		hb.reset_for_reuse()
	for hb in _hitboxes:
		hb.reset_for_reuse()
