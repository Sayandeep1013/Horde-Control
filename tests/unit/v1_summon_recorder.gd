extends Node
## Stands in for the Wave Director (group "wave_director") in boss tests:
## records the summons a boss requests.

var calls: Array = [] # [[enemy_id, count], ...]


func _ready() -> void:
	add_to_group(&"wave_director")


func spawn_summons(enemy_id: String, count: int, _near: Vector2) -> int:
	calls.append([enemy_id, count])
	return count
