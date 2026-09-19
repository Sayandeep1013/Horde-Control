extends Node2D
class_name Tower

## Tower (P2.4). MASTER_SDLC.md > Tower Overview (Why The Tower Has Its Own
## Health Pool, Tower Roles In Detail, Tower Interaction Mechanics, Tower
## Targeting Rule, Tower Evolution Stages, Tower Vulnerability Design,
## Health Recovery Rules) in full; Provisional Values Register > Tower for
## every number this scene and its children read (cited, never restated,
## in each child component's own header). docs/20_Technical_Architecture.md
## > "Scene Tree": "Tower 25" (z_index) in the gameplay root's draw order.
##
## Root controller: wires the six components built for this task (a
## StaticBody2D footprint, a Hurtbox, a DeathState, TowerHealth,
## TowerWeapon, TowerInteractionRadius, TowerEvolutionStage, and
## TowerVisuals) to `definition` and `weapon_definition`, both read from
## `data/tower/base.tres` and `data/tower/base_weapon.tres` respectively
## (assigned on the scene's root node in scenes/tower.tscn) -- "Author
## data/tower/base.tres from [the contract] and read your values from that
## resource, not from constants. A hardcoded Tower HP is a defect." Every
## numeric default below exists only as this script's OWN fallback for a
## Tower instanced without its resources assigned (e.g. a bare `Tower.new()`
## in a unit test); scenes/tower.tscn itself always assigns both resources,
## so gameplay never reaches those fallbacks.
##
## ## Scene tree placement (not this task's job to finish)
## This file's own root is a standalone Node2D scene
## (scenes/tower.tscn), not a child of scenes/main.tscn's `Entities`
## container -- the Tower is its own draw band (z_index 25, set below),
## distinct from "enemies 20 (Y-sorted)" per docs/20's Scene Tree bullet.
## Actually instancing this scene under scenes/main.tscn's gameplay root is
## left to whichever task next owns that file (outside this task's write
## scope; scenes/main.tscn does not yet contain a Tower, an arena, or a
## player as of this task -- P2.1/P2.2/P2.3 land in parallel with this one).

@export var definition: TowerDefinition
@export var weapon_definition: WeaponDefinition

@export var body_path: NodePath = NodePath("Body")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")
@export var death_state_path: NodePath = NodePath("DeathState")
@export var health_path: NodePath = NodePath("TowerHealth")
@export var weapon_path: NodePath = NodePath("TowerWeapon")
@export var interaction_radius_path: NodePath = NodePath("InteractionRadius")
@export var evolution_stage_path: NodePath = NodePath("TowerEvolutionStage")
@export var visuals_path: NodePath = NodePath("Visuals")

var body: StaticBody2D
var hurtbox: Hurtbox
var death_state: DeathState
var health: TowerHealth
var weapon: TowerWeapon
var interaction_radius: TowerInteractionRadius
var evolution_stage: TowerEvolutionStage
var visuals: TowerVisuals

## One RunTerminationRecorder per Tower instance by default (a real run has
## exactly one Tower); tests may inject a shared instance via
## set_run_termination_recorder_for_test() to model a Tower-and-player
## same-tick scenario against one recorder, matching this project's
## set_*_for_test() convention.
var _run_termination: RunTerminationRecorder = RunTerminationRecorder.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 25 # docs/20 > Scene Tree draw order: "Tower 25"
	body = get_node_or_null(body_path) as StaticBody2D
	hurtbox = get_node_or_null(hurtbox_path) as Hurtbox
	death_state = get_node_or_null(death_state_path) as DeathState
	health = get_node_or_null(health_path) as TowerHealth
	weapon = get_node_or_null(weapon_path) as TowerWeapon
	interaction_radius = get_node_or_null(interaction_radius_path) as TowerInteractionRadius
	evolution_stage = get_node_or_null(evolution_stage_path) as TowerEvolutionStage
	visuals = get_node_or_null(visuals_path) as TowerVisuals

	if definition != null:
		configure(definition, weapon_definition)

	if health != null and visuals != null:
		health.health_changed.connect(visuals.on_health_changed)
		health.shield_changed.connect(visuals.on_shield_changed)
		health.damage_flash_requested.connect(visuals.on_damage_flash_requested)
	if weapon != null and visuals != null:
		weapon.fired.connect(func(t: float) -> void: visuals.on_fired(t))
	if health != null:
		health.tower_destroyed.connect(_on_tower_destroyed)


## Typed command: applies both Register-sourced resources to every child
## component. Called automatically from _ready() when `definition` is
## already assigned in the scene (the normal case); exposed directly so a
## test can build a Tower programmatically and configure it explicitly,
## matching this project's configure()/set_*_for_test() conventions.
func configure(tower_definition: TowerDefinition, base_weapon: WeaponDefinition) -> void:
	assert(tower_definition != null, "Tower.configure() requires a TowerDefinition")
	definition = tower_definition
	weapon_definition = base_weapon

	if tower_definition.base_weapon_reference_id != "" and base_weapon != null:
		if base_weapon.unique_id != tower_definition.base_weapon_reference_id:
			push_warning("Tower.configure(): base_weapon_reference_id '%s' does not match the assigned WeaponDefinition's unique_id '%s'" % [tower_definition.base_weapon_reference_id, base_weapon.unique_id])

	if tower_definition.tower_footprint != null:
		var radius: float = float(tower_definition.tower_footprint.footprint_radius_px)
		_apply_circle_radius(body, radius)
		_apply_circle_radius(hurtbox, radius)
		var interaction_radius_px: float = float(tower_definition.tower_footprint.interaction_radius_px)
		_apply_circle_radius(interaction_radius, interaction_radius_px)

	if health != null:
		health.configure(tower_definition)
	if evolution_stage != null:
		evolution_stage.configure(tower_definition)
	if weapon != null and base_weapon != null and tower_definition.targeting_rule_parameters != null:
		weapon.configure(base_weapon, float(tower_definition.targeting_rule_parameters.range_px))


static func _apply_circle_radius(node: Node, radius: float) -> void:
	if node == null:
		return
	var shape_node: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is CircleShape2D):
		return
	(shape_node.shape as CircleShape2D).radius = radius


func is_destroyed() -> bool:
	return health != null and health.is_destroyed()


func set_run_termination_recorder_for_test(recorder: RunTerminationRecorder) -> void:
	_run_termination = recorder


func get_run_termination_recorder() -> RunTerminationRecorder:
	return _run_termination


func _on_tower_destroyed(timestamp: float) -> void:
	_run_termination.record_tick_deaths([RunTerminationRecorder.Category.TOWER], timestamp)
