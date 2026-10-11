extends EnemyBehavior
class_name BossBehavior
## v1.0 shared boss plumbing (docs/31 §5.3): EventBus lifecycle signals,
## the phase flag, summon requests (routed through the Wave Director so
## summons obey caps, scaling and rings), and the entrance roar. Subclasses
## add the attack pattern. A boss is an ordinary EnemyController (so it
## uses attack slots, the registry and the death/drop path) and is never
## handed back to the pool free list: it is discarded at visual death like
## every enemy (see Pool.discard()).
##
## PT-SWARM (docs/33 §C4, D340): phases are a list of HP fractions
## (`phase_fractions`, descending; phase N+2 starts below entry N), and every
## boss has stagger windows: after a big attack it is stunned for
## 1.5-2 s and takes +50% damage (`stagger()`), shown by a ring of stars over
## its head. `phase_two_fraction` stays as the first entry for the HUD.

signal phase_changed(phase: int)
signal staggered(seconds: float)

## Register "Boss stagger" (D340): damage taken x1.5 while staggered.
const STAGGER_DAMAGE_TAKEN_MULTIPLIER: float = 1.5
## Boss bullets: big orbs, the colours of the danger palette.
const BULLET_ORANGE: Color = Color(1.0, 0.5, 0.08)
const BULLET_RED: Color = Color(1.0, 0.18, 0.12)

@export var boss_id: String = ""
@export var display_name: String = ""
## Phase 2 starts below this fraction of max HP. Kept equal to phase_fractions[0].
@export var phase_two_fraction: float = 0.4
## Every phase threshold, descending (Warchief [0.5], King [0.6, 0.25]).
@export var phase_fractions: Array[float] = []
## Core bounty, paid at Run-End Settlement per boss killed (D255); informational
## here, the settlement reads the `boss_kills` of each boss id.
@export var core_reward: int = 8

var phase: int = 1
var _announced: bool = false
var _stagger_until: float = -INF
var _stagger_applied: bool = false
var _base_damage_taken: float = 1.0
var _stagger_cue: Node2D = null
var _bullets: EnemyBulletField = null
var staggers_total: int = 0


func is_boss() -> bool:
	return true


func bind(owner_controller: Node) -> void:
	super.bind(owner_controller)
	owner_controller.boss_id = boss_id
	if phase_fractions.is_empty():
		phase_fractions = [phase_two_fraction]
	phase_two_fraction = phase_fractions[0]
	if owner_controller.death_state != null:
		owner_controller.death_state.damage_applied.connect(_on_damage_applied)


## Called by the Wave Director once HP scaling has been applied.
func announce_spawn() -> void:
	if _announced:
		return
	_announced = true
	var ds: DeathState = controller.death_state
	EventBus.emit_boss_spawned(controller, boss_id, display_name, ds.max_hp if ds != null else 0.0)
	Sfx.play("boss_roar", controller.global_position, 10, true)


func get_health_fraction() -> float:
	var ds: DeathState = controller.death_state
	return ds.current_hp / maxf(ds.max_hp, 1.0) if ds != null else 1.0


## Multiplier applied to every attack cooldown (enrage phases shorten it).
func cooldown_scale() -> float:
	return 1.0


func _on_damage_applied(_amount: float, _source: Variant, remaining_hp: float) -> void:
	var ds: DeathState = controller.death_state
	EventBus.emit_boss_health_changed(boss_id, remaining_hp, ds.max_hp)
	if remaining_hp <= 0.0:
		return
	var frac: float = remaining_hp / maxf(ds.max_hp, 1.0)
	while phase - 1 < phase_fractions.size() and frac < phase_fractions[phase - 1]:
		phase += 1
		if phase == 2:
			_on_phase_two()
		_on_phase_entered(phase)
		phase_changed.emit(phase)


func _on_phase_two() -> void:
	Sfx.play("boss_roar", controller.global_position, 10, true)


## Every phase change (2, 3, ...). Subclasses reset their pattern timers here.
func _on_phase_entered(_new_phase: int) -> void:
	pass


# --- Stagger (D340) -------------------------------------------------------------

## Stuns the boss for `seconds`: it holds still, starts no attack, and takes
## STAGGER_DAMAGE_TAKEN_MULTIPLIER damage until the window closes.
func stagger(seconds: float) -> void:
	var ds: DeathState = controller.death_state
	if ds == null or ds.is_dead:
		return
	if not _stagger_applied:
		_base_damage_taken = ds.damage_taken_multiplier
		ds.damage_taken_multiplier = _base_damage_taken * STAGGER_DAMAGE_TAKEN_MULTIPLIER
		_stagger_applied = true
	_stagger_until = maxf(_stagger_until, _now() + seconds)
	staggers_total += 1
	_show_stagger_cue(true)
	staggered.emit(seconds)
	_on_stagger_started()


func is_staggered() -> bool:
	return _now() < _stagger_until


func stagger_time_left() -> float:
	return maxf(0.0, _stagger_until - _now())


## Subclasses clear in-flight attack state (telegraph lanes) here.
func _on_stagger_started() -> void:
	pass


## Call first in pre_step: while staggered the boss holds still and the tick is
## consumed (returns true); the window's end restores the damage multiplier.
func _stagger_step() -> bool:
	if _stagger_applied and _now() >= _stagger_until:
		_stagger_applied = false
		if controller.death_state != null:
			controller.death_state.damage_taken_multiplier = _base_damage_taken
		_show_stagger_cue(false)
	if _stagger_applied:
		controller.hold_position()
		return true
	return false


func _show_stagger_cue(on: bool) -> void:
	if on and not is_instance_valid(_stagger_cue):
		_stagger_cue = StaggerCue.new()
		_stagger_cue.position = Vector2(0.0, -controller.get_body_radius() * 3.2 - 40.0)
		controller.add_child(_stagger_cue)
	if is_instance_valid(_stagger_cue):
		_stagger_cue.visible = on


# --- Shared helpers ---------------------------------------------------------------

func bullets() -> EnemyBulletField:
	if _bullets == null or not is_instance_valid(_bullets):
		_bullets = EnemyBulletField.get_or_create(controller.get_parent(), controller.get_registry())
	return _bullets


func on_death() -> void:
	_show_stagger_cue(false)
	EventBus.emit_boss_defeated(boss_id, controller.global_position)
	CombatStats.add_run_counter("boss_kills", 1.0)


func request_summon(enemy_id: String, count: int) -> void:
	var director: Node = controller.get_tree().get_first_node_in_group(&"wave_director") if controller.is_inside_tree() else null
	if director != null and director.has_method("spawn_summons"):
		director.call("spawn_summons", enemy_id, count, controller.global_position)


## Draws the stunned-stars cue over a staggered boss (cosmetic, wall clock).
class StaggerCue extends Node2D:
	func _ready() -> void:
		z_as_relative = false
		z_index = 46

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var t: float = Time.get_ticks_msec() / 1000.0
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.3, 0.55), 3.0)
		for i in 5:
			var a: float = t * 3.0 + TAU * float(i) / 5.0
			var p := Vector2(cos(a) * 30.0, sin(a) * 12.0)
			_star(p, 9.0, Color(1.0, 0.92, 0.25))
		draw_string(ThemeDB.fallback_font, Vector2(-44.0, -22.0), "STAGGERED", HORIZONTAL_ALIGNMENT_CENTER, 88.0, 16, Color(1.0, 0.95, 0.5))

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var rr: float = r if k % 2 == 0 else r * 0.45
			var a: float = -PI / 2.0 + TAU * float(k) / 10.0
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.2, 0.1, 0.0), 1.5)
