extends Node
class_name EnemyBehavior
## v1.0 (WP-ENEMIES, docs/31 §5): optional per-archetype behaviour attached to
## an EnemyController as a child node named "Behavior". The controller keeps
## owning movement, slots, health and the standard melee cycle; a behaviour
## only extends it through the four hooks below, so the Seeker/Hunter/
## Opportunist code paths are untouched when no behaviour is attached.
##
## State is an explicit enum + SimClock timestamps in each subclass (the
## project's state-machine idiom; no per-frame timers, no scene Timers).
## Subclasses: Bomber, Goblin Shaman, and the bosses (Goblin Warchief, Gutbarrel
## the Juggernaut, Bombardier King) through BossBehavior.

var controller: Node = null # untyped on purpose: typing it as EnemyController closes a script cycle that leaks at exit (D256)


## Called once from EnemyController._ready().
func bind(owner_controller: Node) -> void:
	controller = owner_controller


## Before the controller's own movement each physics tick. Return true when the
## behaviour fully drove this tick (movement and all); false lets the standard
## seek / attack-slot movement run.
func pre_step(_delta: float) -> bool:
	return false


## After the standard movement and attack cycle ran this tick.
func post_step(_delta: float, _in_attack_range: bool, _target: Node2D) -> void:
	pass


## A target replacing the intent's default, or null for the default.
func override_target() -> Node2D:
	return null


## True when the behaviour replaces the controller's melee wind-up/hit cycle.
func suppress_default_attack() -> bool:
	return false


func is_boss() -> bool:
	return false


## At this enemy's Logical Death.
func on_death() -> void:
	pass


## Damage this enemy deals: base x the wave/difficulty/elite multiplier.
func scaled_damage(base: float) -> float:
	return base * (controller.get_damage_multiplier() if controller != null else 1.0)


func _now() -> float:
	return controller._now() if controller != null else SimClock.now
