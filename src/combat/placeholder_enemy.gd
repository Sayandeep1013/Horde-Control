extends CharacterBody2D
class_name PlaceholderEnemy

## PlaceholderEnemy (P1.5 task brief: "A placeholder enemy wiring all three
## together, so the framework is exercised by something real rather than
## only by mocks."). Not a real Enemy Definition Contract instance -- no
## Enemy .tres resource, no AI, no movement (this phase's task table, P1.5
## row: "Out: enemy behaviour"). Exists only to give hitbox.gd / hurtbox.gd
## / death_state.gd a real CharacterBody2D + Area2D scene tree to run
## inside, for the Ghost hit test (tests/unit/ghost_hit_test.gd) and for
## P1.7's later swarm scene to instance from.
##
## Body layer/mask: EnemyBody (2), ground-enemy masks
## (CollisionLayers.MASK_ENEMY_BODY_GROUND) -- docs/20 Collision Layers
## table, row 2, "flying enemies drop 4" carve-out not applicable (this
## placeholder is a ground enemy).
## Body radius: 14 px (docs/20 > Physics & Collisions > "Entity sizes":
## "Opportunist 14 px"). Hurtbox radius: same as body -- this file's own
## interpretation, named rather than silently assumed: docs/20 states
## "hurtbox equals the body" explicitly only for the Player (Player
## Definition Contract fields > "Hurtbox definition"); extended here to this
## placeholder enemy for simplicity. Hitbox radius: 20 px = body radius + 6
## (docs/20's stated rule, applying to every enemy's contact hitbox, not
## Player-specific).

@export var hitbox_node_path: NodePath = NodePath("Hitbox")
@export var hurtbox_node_path: NodePath = NodePath("Hurtbox")
@export var death_state_node_path: NodePath = NodePath("DeathState")

var hitbox: Hitbox
var hurtbox: Hurtbox
var death_state: DeathState


func _ready() -> void:
	add_to_group(&"pool_body")
	collision_layer = CollisionLayers.LAYER_ENEMY_BODY
	collision_mask = CollisionLayers.MASK_ENEMY_BODY_GROUND
	hitbox = get_node_or_null(hitbox_node_path) as Hitbox
	hurtbox = get_node_or_null(hurtbox_node_path) as Hurtbox
	death_state = get_node_or_null(death_state_node_path) as DeathState
	if hitbox != null:
		hitbox.owner_entity = self


## Convenience wrapper so a caller (AI, or a test) does not need to know
## this entity's internal node layout -- opens the attack window (docs/20 >
## SimLoop order, step 6 "wind-up completion ... contact ticks").
func start_attack_window() -> void:
	if hitbox != null:
		hitbox.activate_window()


func end_attack_window() -> void:
	if hitbox != null:
		hitbox.deactivate_window()


## Typed command forwarding straight to death_state.gd -- kept here so a
## caller that only holds a PlaceholderEnemy reference (not its DeathState
## child) can still deal damage without reaching into child nodes itself.
func apply_damage(amount: float, source: Variant = null) -> bool:
	return death_state.apply_damage(amount, source) if death_state != null else false


func is_dead() -> bool:
	return death_state != null and death_state.is_dead


## Called by whoever re-spawns this instance from a Pool AFTER
## Pool.acquire() has already restored the engine-level Logical Death flags
## -- see death_state.gd's own reset_for_reuse() header for why this second
## step cannot be skipped.
func reset_for_reuse() -> void:
	if death_state != null:
		death_state.reset_for_reuse()
