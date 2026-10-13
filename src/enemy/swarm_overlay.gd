extends Node2D
class_name SwarmOverlay

## SwarmOverlay (PT-PERF, D390-D399). The one canvas item SwarmRenderer draws the
## wind-up markers and the damaged-enemy health bars with, instead of a TelegraphVisual
## and an EnemyHealthBar node per enemy. All state lives in SwarmRenderer; this node
## only owns the `_draw()` callback.

## The owning SwarmRenderer (untyped: script cycle, see ShutdownHygiene / D256).
var renderer: Node = null


func _draw() -> void:
	if renderer != null:
		renderer.draw_overlay(self)
