extends Node2D
## Test double for the Wave Director suites (v1.0, WP-ENEMIES): a bare Node2D
## that records the director's calls. `behavior` is null for an ordinary
## enemy; a subclass-free boss double sets it through `make_boss()`.

class DummyBossBehavior extends RefCounted:
	var announced: bool = false

	func is_boss() -> bool:
		return true

	func announce_spawn() -> void:
		announced = true

var behavior: RefCounted = null
var scaling: Array = [] # [[hp, damage, hunter_damage], ...]
var elite_affix: String = ""
var death_state: Variant = null


func make_boss() -> void:
	behavior = DummyBossBehavior.new()


func set_wave_scaling(hp: float, damage: float, hunter_damage: float = 1.0) -> void:
	scaling.append([hp, damage, hunter_damage])


func apply_elite(affix: String) -> void:
	elite_affix = affix
