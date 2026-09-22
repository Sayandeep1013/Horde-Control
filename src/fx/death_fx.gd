extends AnimatedSprite2D
class_name DeathFx

## DeathFx (art session, D102 follow-up). A one-shot skull-fall-then-dissolve
## effect, spawned by `src/enemy/enemy_animator.gd` at an enemy's Logical
## Death position.
##
## ## Why this is a separate node, not part of the dying enemy
## `death_state.gd`'s `visual_death_duration` (0.5s) is a contract value this
## task must not change, but the skull_fall (7 frames) + skull_dissolve (7
## frames) clips run 1.4s total at the pack's 10fps (docs/PROVENANCE.md).
## Playing them on the enemy's own `AnimatedSprite2D` would either get cut
## off mid-animation when the enemy is despawned/pooled at 0.5s, or require
## lengthening `visual_death_duration` -- explicitly forbidden. This node is
## cheap, freestanding, and outlives the enemy's own pooled instance: no
## collision, no EntityRegistry registration, nothing gameplay reads from it.
##
## ## Draw order
## `z_as_relative = false` makes `z_index` absolute (matches `telegraph_
## visual.gd`'s own reasoning for the same accumulation problem): 15 sits
## below `Entities`' own z_index 20 (docs/20 > Scene Tree draw order), so a
## fading corpse effect never draws over a still-living entity standing near
## the same spot.
##
## process_mode PAUSABLE (not the default INHERIT-from-a-detached-root,
## since this node's parent is the `Entities`/arena container, which is
## itself pausable) so a death mid-pause does not keep animating.

var _stage: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = 15
	animation_finished.connect(_on_animation_finished)
	play(&"skull_fall")


func _on_animation_finished() -> void:
	if _stage == 0:
		_stage = 1
		play(&"skull_dissolve")
	else:
		queue_free()
