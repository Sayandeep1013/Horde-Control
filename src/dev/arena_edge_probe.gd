extends Node2D

## Development-only verification helper (art pass, D102), matching
## scene_capture.gd's own "not part of the shipped game" convention.
## Instances scenes/arena.tscn with a static Camera2D placed wherever
## --campos=x,y says, so the biome's coastline/tower art can be captured
## without depending on the player controller's own movement/input state
## (out of this task's write scope). Used together with scene_capture.tscn:
##
##   Godot ... res://src/dev/scene_capture.tscn -- \
##     --scene=res://src/dev/arena_edge_probe.tscn \
##     --campos=0,-1550 --zoom=1.0 --frames=10 --out=sandbox/captures/edge

@export var arena_scene: PackedScene = preload("res://scenes/arena.tscn")


func _ready() -> void:
	var arena: Node2D = arena_scene.instantiate()
	add_child(arena)

	var cam_pos: Vector2 = Vector2.ZERO
	var zoom: float = 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--campos="):
			var parts: PackedStringArray = arg.trim_prefix("--campos=").split(",")
			if parts.size() == 2:
				cam_pos = Vector2(float(parts[0]), float(parts[1]))
		elif arg.begins_with("--zoom="):
			zoom = float(arg.trim_prefix("--zoom="))

	var camera: Camera2D = Camera2D.new()
	camera.position = cam_pos
	camera.zoom = Vector2.ONE * zoom
	add_child(camera)
	camera.make_current()
