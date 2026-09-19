extends Area2D
class_name TowerInteractionRadius

## TowerInteractionRadius (P2.4). MASTER_SDLC.md > Tower Overview > "Tower
## Interaction Mechanics": "the player must physically enter the Tower
## Interaction Radius (a circle around the Tower base; Provisional Default
## 160 pixels in the prototype arena)" and "While the player's body
## overlaps the Tower Interaction Radius, the player's auto-fire is
## disabled at any speed ... the Tower keeps firing." docs/20_Technical_
## Architecture.md > Collision Layers table, row 14: "InteractionRadius |
## Tower Console trigger Area2D | 1" -- masks PlayerBody (layer 1), so this
## Area2D actively monitors and uses body_entered/body_exited (a
## PhysicsBody overlap), unlike every Hurtbox (which never scans).
##
## ## Scope: the trigger only, not the Console
## This task's own row (PLAN.md > P2.4): "In: ... Interaction Radius
## trigger ... Out: evolution art, drones." The Tower Console (the 0.3s
## dwell-below-10%-speed check, the priced catalogue, Repair, the channel-
## and-fill-ring UI) is docs/19's own system, not named as this task's
## deliverable anywhere in the Development Phase Map's P2.4 row or PLAN.md
## -- no P2.x task in this phase's own table owns it either (P2.13
## "Console channel completion" is Phase 05). This component exposes only
## what MASTER_SDLC.md itself calls "physically enter[ing]" the radius: a
## real Area2D that reports whether the player's body currently overlaps
## it, and when that changes -- the minimum a Console (or the player's own
## auto-fire-disable check) needs to build on later, without this task
## reaching into player code (src/player/ is another implementer's
## write scope) or building UI that belongs to a different task.

signal player_entered(body: Node2D)
signal player_exited(body: Node2D)

var _overlapping_player_bodies: Array[Node2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = CollisionLayers.LAYER_INTERACTION_RADIUS
	collision_mask = CollisionLayers.MASK_INTERACTION_RADIUS # PlayerBody (layer 1)
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_player_inside() -> bool:
	return not _overlapping_player_bodies.is_empty()


func _on_body_entered(body: Node2D) -> void:
	if not _overlapping_player_bodies.has(body):
		_overlapping_player_bodies.append(body)
	if _overlapping_player_bodies.size() == 1:
		player_entered.emit(body)


func _on_body_exited(body: Node2D) -> void:
	_overlapping_player_bodies.erase(body)
	if _overlapping_player_bodies.is_empty():
		player_exited.emit(body)
