extends Node
class_name TowerEvolutionStage

## TowerEvolutionStage (P2.4). MASTER_SDLC.md > Tower Overview > "Tower
## Evolution Stages": "The Tower's silhouette changes three times across a
## full run, producing four distinct stages ... Trigger (Provisional
## Default: count of Tower upgrade ranks held from either channel): Base 0
## ranks, Reinforced 1 rank, Armed 3 ranks, Fortress 6 ranks." Thresholds
## are read from TowerDefinition.evolution_stage_thresholds
## (data/tower/base.tres), never restated as literals.
##
## P2.4's own scope row: "In: ... stage counter. Out: evolution art,
## drones." This file is exactly the counter -- it tracks
## `ranks_held` and derives the current stage index (0-3) from the
## Register-sourced thresholds, and emits stage_changed so a future visual
## system (this task's own tower_visuals.gd hooks it only for a placeholder
## read; distinct per-stage silhouette art is explicitly out of scope) or a
## future upgrade system can react. No upgrade system exists yet (Phase 05)
## to actually call add_ranks(); this component is ready for it.

signal stage_changed(new_stage: int, ranks_held: int)

var ranks_held: int = 0
var _thresholds: Array[int] = []
var _current_stage: int = 0


func configure(definition: TowerDefinition) -> void:
	assert(definition != null, "TowerEvolutionStage.configure() requires a TowerDefinition")
	_thresholds = definition.evolution_stage_thresholds.duplicate()
	_thresholds.sort()
	ranks_held = 0
	_current_stage = _stage_for_ranks(ranks_held)


func get_current_stage() -> int:
	return _current_stage


## Typed command: a future upgrade system reports ranks taken here (Tower
## upgrades from EITHER channel, per the Register row's own wording) rather
## than this component reaching into an upgrade system to poll a count --
## consistent with docs/20 > "Communication, commands".
func add_ranks(count: int = 1) -> void:
	if count <= 0:
		return
	ranks_held += count
	var new_stage: int = _stage_for_ranks(ranks_held)
	if new_stage != _current_stage:
		_current_stage = new_stage
		stage_changed.emit(_current_stage, ranks_held)


## Typed command (Meta layer core, Fortress node). MASTER_SDLC.md >
## Provisional Values Register > "Meta: Skill Tree effects": "Fortress:
## Tower starts one evolution stage up (1)." Called once, from
## `MetaLoadoutApplier`, AFTER `Tower.configure()` has already reset this
## component to stage 0 (ranks_held = 0) for the run -- jumps `ranks_held`
## directly to the threshold of the next stage rather than pretending a real
## upgrade rank was spent (`add_ranks()` is for actual Tower upgrade ranks
## taken in-run; this is a permanent head start, not a rank). Clamped to the
## last authored stage so a run that is somehow already at the final stage
## is a no-op rather than an out-of-range read.
func advance_one_stage(count: int = 1) -> void:
	if count <= 0 or _thresholds.is_empty():
		return
	var target_stage: int = clampi(_current_stage + count, 0, _thresholds.size() - 1)
	if target_stage == _current_stage:
		return
	ranks_held = _thresholds[target_stage]
	_current_stage = target_stage
	stage_changed.emit(_current_stage, ranks_held)


func _stage_for_ranks(ranks: int) -> int:
	var stage: int = 0
	for i in _thresholds.size():
		if ranks >= _thresholds[i]:
			stage = i
	return stage
