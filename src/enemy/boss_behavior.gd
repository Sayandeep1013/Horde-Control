extends EnemyBehavior
class_name BossBehavior
## v1.0 shared boss plumbing (docs/31 §5.3): EventBus lifecycle signals,
## the phase flag, summon requests (routed through the Wave Director so
## summons obey caps, scaling and rings), and the entrance roar. Subclasses
## add the attack pattern. A boss is an ordinary EnemyController (so it
## uses attack slots, the registry and the death/drop path) and is never
## handed back to the pool free list: it is discarded at visual death like
## every enemy (see Pool.discard()).

signal phase_changed(phase: int)

@export var boss_id: String = ""
@export var display_name: String = ""
## Phase 2 starts below this fraction of max HP (Register: Warchief 0.40, King 0.50).
@export var phase_two_fraction: float = 0.4
## Core bounty, paid at Run-End Settlement per boss killed (D255); informational
## here, the settlement reads the `boss_kills` of each boss id.
@export var core_reward: int = 8

var phase: int = 1
var _announced: bool = false


func is_boss() -> bool:
	return true


func bind(owner_controller: EnemyController) -> void:
	super.bind(owner_controller)
	owner_controller.boss_id = boss_id
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


## Multiplier applied to every attack cooldown (Warchief enrage: x0.7).
func cooldown_scale() -> float:
	return 1.0


func _on_damage_applied(_amount: float, _source: Variant, remaining_hp: float) -> void:
	var ds: DeathState = controller.death_state
	EventBus.emit_boss_health_changed(boss_id, remaining_hp, ds.max_hp)
	if phase == 1 and remaining_hp > 0.0 and remaining_hp / maxf(ds.max_hp, 1.0) < phase_two_fraction:
		phase = 2
		_on_phase_two()
		phase_changed.emit(phase)


func _on_phase_two() -> void:
	Sfx.play("boss_roar", controller.global_position, 10, true)


func on_death() -> void:
	EventBus.emit_boss_defeated(boss_id, controller.global_position)
	CombatStats.add_run_counter("boss_kills", 1.0)


func request_summon(enemy_id: String, count: int) -> void:
	var director: Node = controller.get_tree().get_first_node_in_group(&"wave_director") if controller.is_inside_tree() else null
	if director != null and director.has_method("spawn_summons"):
		director.call("spawn_summons", enemy_id, count, controller.global_position)
