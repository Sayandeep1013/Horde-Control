extends Node
class_name TowerHealth

## TowerHealth (P2.4). MASTER_SDLC.md > Tower Overview > "Health Recovery
## Rules": "Tower health does not regenerate. It is restored only by the
## Repair action" and "the base Tower has a shield equal to 25% of Tower
## maximum health. The shield absorbs damage before health. It begins
## regenerating at 10% of its maximum per second after 8 seconds without
## the Tower taking any damage to health or shield; every hit restarts that
## 8-second delay, including the hit that breaks the shield." Provisional
## Values Register > Tower row cites the concrete numbers (500 HP; shield
## 25%; regen 10%/s after 8s, delay restarts on every hit including the
## breaking hit) -- read from data/tower/base.tres via configure(), never
## restated here as a literal.
##
## ## Why this does not simply add the Tower's Hurtbox to DeathState's own
## hurtbox_paths (the double-damage problem)
## src/combat/death_state.gd's _resolve_refs() connects EVERY hurtbox in
## hurtbox_paths directly to apply_damage(amount) with the FULL incoming
## amount -- that auto-wiring is exactly right for an entity with a single
## health pool (every existing user: the placeholder enemy), but the Tower
## has TWO pools and the Register's own rule is "the shield absorbs damage
## before health": health must only ever receive the REMAINDER after
## shield absorption, never the full incoming amount. There is no
## interception point inside that auto-wired path without editing
## death_state.gd, which is outside this task's write scope ("Build on it;
## do not reimplement" -- src/combat/ is a forbidden edit, not a rewrite
## target). So this file:
##   1. Leaves the Tower's DeathState.hurtbox_paths EMPTY in the scene (no
##      auto-connect at all -- see scenes/tower.tscn), and instead connects
##      to the real TowerHurtbox's damage_received signal ITSELF, splits the
##      amount (shield first, then the leftover via
##      death_state.apply_damage(remainder)) -- exactly one call to
##      apply_damage() per hit, with the correct post-shield amount.
##   2. Replicates, by hand, the TWO cleanup calls DeathState would have
##      made on that hurtbox at Logical Death (mark_dead(),
##      apply_logical_death_layers()) from a listener on DeathState's own
##      logical_death signal (fired synchronously, same call stack, as the
##      last step of _enter_logical_death()) -- so the real hurtbox still
##      gets exactly the same protection every other pooled hurtbox gets,
##      just triggered one level up instead of inside hurtbox_paths' loop.
## Named here as a deliberate, documented design choice, not a silent
## reinterpretation of the framework -- see the P2.4 evidence report,
## "Contradictions and ambiguities."
##
## ## Shield regen timing: SimClock, not a countdown
## `_last_damage_sim_time` stores a SimClock.now SNAPSHOT taken the instant
## damage lands (to either pool); regen only begins once
## `SimClock.now - _last_damage_sim_time >= regen_delay_seconds`, and the
## per-tick regen amount is derived from `SimClock.now` deltas between
## consecutive _physics_process calls, never `delta` accumulated as a
## countdown (src/core/sim_clock.gd's own header rule: "Every gameplay
## deadline in this project is a value compared against SimClock.now, never
## a running countdown").

signal shield_changed(current_shield: float, max_shield: float)
signal health_changed(current_health: float, max_health: float)
signal damage_flash_requested(amount: float)
signal tower_destroyed(timestamp: float)

@export var hurtbox_path: NodePath
@export var death_state_path: NodePath

var max_health: float = 0.0
var max_shield: float = 0.0
var current_shield: float = 0.0
var regen_rate_percent_per_second: float = 0.0
var regen_delay_seconds: float = 0.0

## P2.11 modifier layer (src/upgrade/upgrade_system.gd): the definition-
## derived base max_shield (max_health x base_shield_fraction, from
## data/tower/base.tres via configure() below), kept separately from the
## live `max_shield` field above so Shield Matrix's bonus can be recomputed
## fresh from this untouched base every time -- never compounded onto
## whatever `max_shield` happened to hold from a previous call.
var _base_max_shield: float = 0.0

## Shield Matrix's current TOTAL fraction of max_health granted as extra
## shield capacity -- MASTER_SDLC.md > Progression Edge Cases > "Percentage
## bonuses to the same stat stack" (C-STACK): this is the upgrade's own
## already-summed `(1 + sum of bonuses)`-style total (here, sum of
## effect_per_rank across every rank held), pushed by src/upgrade/
## upgrade_system.gd on every apply_rank() call; set_bonus_max_shield_
## fraction() below REPLACES this value, it never adds to it.
var _bonus_max_shield_fraction: float = 0.0

var _hurtbox: Hurtbox = null
var _death_state: DeathState = null
var _last_damage_sim_time: float = -INF
var _last_regen_sim_time: float = 0.0
var _configured: bool = false

## Test-injectable SimClock reference (this project's own convention, e.g.
## death_state.gd's set_registry_for_test()/set_event_bus_for_test()); the
## real SimClock Autoload has no reset_for_test() of its own to lean on
## (its header comment names one but none exists in the file -- flagged in
## the P2.4 evidence report as a contradiction found, not silently
## resolved), so tests inject a fresh instance instead, matching
## tests/unit/pause_clock_test.gd's own established pattern.
var _clock: Node = null

## Test-injectable EventBus reference, same convention.
var _event_bus: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_clock = SimClock
	_event_bus = EventBus
	_hurtbox = get_node_or_null(hurtbox_path) as Hurtbox
	_death_state = get_node_or_null(death_state_path) as DeathState
	if _hurtbox != null:
		_hurtbox.damage_received.connect(_on_hurtbox_damage_received)
	if _death_state != null:
		_death_state.logical_death.connect(_on_death_state_logical_death)
	_last_regen_sim_time = _now()


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func set_event_bus_for_test(bus: Node) -> void:
	_event_bus = bus


func _now() -> float:
	return _clock.now if _clock != null else 0.0


## Typed command: applies the Register's numbers (read from `definition`,
## never restated as a literal) to this component and to the wired
## DeathState's health pool. Must run before either pool is read for
## gameplay (Tower._ready() calls this before anything can damage the
## Tower).
func configure(definition: TowerDefinition) -> void:
	assert(definition != null, "TowerHealth.configure() requires a TowerDefinition")
	assert(definition.max_health_and_shield_fraction != null, "TowerDefinition.max_health_and_shield_fraction is required")
	assert(definition.shield_regeneration != null, "TowerDefinition.shield_regeneration is required")
	max_health = float(definition.max_health_and_shield_fraction.maximum_health)
	_base_max_shield = max_health * definition.max_health_and_shield_fraction.base_shield_fraction
	max_shield = _base_max_shield
	current_shield = max_shield
	regen_rate_percent_per_second = definition.shield_regeneration.rate_percent_per_second
	regen_delay_seconds = definition.shield_regeneration.delay_seconds
	if _death_state != null:
		_death_state.max_hp = max_health
		_death_state.current_hp = max_health
	_configured = true
	_last_regen_sim_time = _now()
	health_changed.emit(get_current_health(), max_health)
	shield_changed.emit(current_shield, max_shield)


func get_current_health() -> float:
	return _death_state.current_hp if _death_state != null else 0.0


## Typed command (P2.11 modifier layer; see this file's `_bonus_max_shield_
## fraction` field comment). `fraction` is Shield Matrix's own already-
## summed TOTAL fraction of max_health across every rank held (C-STACK) --
## REPLACES the previous fraction, never adds to it, so a repeat call from
## the other channel at an unchanged cumulative rank is a true no-op
## (delta 0.0) rather than double-granting the same capacity.
##
## Register: "Shield Matrix +10% of Tower maximum health as extra shield
## per rank." The newly granted capacity is handed over ALREADY FILLED --
## current_shield rises by exactly the capacity's own increase, never
## beyond it (clamped to the new max_shield). This is an interpretation,
## not a Register-stated rule (the Register states the capacity increase,
## not whether it arrives charged or empty) -- see the P2.11 evidence
## report, "Interpretations."
func set_bonus_max_shield_fraction(fraction: float) -> void:
	if not _configured:
		return
	var new_max_shield: float = _base_max_shield + max_health * fraction
	var shield_delta: float = new_max_shield - max_shield
	_bonus_max_shield_fraction = fraction
	max_shield = new_max_shield
	current_shield = clampf(current_shield + shield_delta, 0.0, max_shield)
	shield_changed.emit(current_shield, max_shield)


func get_bonus_max_shield_fraction_for_test() -> float:
	return _bonus_max_shield_fraction


func is_destroyed() -> bool:
	return _death_state != null and _death_state.is_dead


func _physics_process(_delta: float) -> void:
	_try_regenerate_shield()


## Shield-then-health split (Register: "The shield absorbs damage before
## health"). Called from the real TowerHurtbox's damage_received signal,
## NOT from DeathState's own auto-wiring -- see header.
func _on_hurtbox_damage_received(amount: float, source: Variant, _hitbox: Node) -> void:
	if not _configured or _death_state == null or _death_state.is_dead:
		return
	if amount <= 0.0:
		return
	_last_damage_sim_time = _now() # restarts the regen delay -- "including the hit that breaks it"
	var absorbed: float = minf(current_shield, amount)
	current_shield -= absorbed
	var remainder: float = amount - absorbed
	if remainder > 0.0:
		_death_state.apply_damage(remainder, source)
	shield_changed.emit(current_shield, max_shield)
	health_changed.emit(get_current_health(), max_health)
	damage_flash_requested.emit(amount)
	if _event_bus != null:
		_event_bus.emit_tower_damaged(amount, get_current_health(), current_shield)


func _try_regenerate_shield() -> void:
	var now: float = _now()
	var dt: float = now - _last_regen_sim_time
	_last_regen_sim_time = now
	if not _configured or dt <= 0.0:
		return
	if _death_state != null and _death_state.is_dead:
		return
	if current_shield >= max_shield:
		return
	if now - _last_damage_sim_time < regen_delay_seconds:
		return
	var new_shield: float = minf(max_shield, current_shield + max_shield * (regen_rate_percent_per_second / 100.0) * dt)
	if not is_equal_approx(new_shield, current_shield):
		current_shield = new_shield
		shield_changed.emit(current_shield, max_shield)


## Replicates the two Logical Death cleanup calls DeathState would have
## made on the Tower's real hurtbox if it had been listed in
## hurtbox_paths (see header) -- and records the run-ending cause.
func _on_death_state_logical_death(_entity: Node2D, _position: Vector2) -> void:
	if _hurtbox != null:
		_hurtbox.mark_dead()
		_hurtbox.apply_logical_death_layers()
	tower_destroyed.emit(_now())
