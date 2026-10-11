class_name HudFakes
extends RefCounted

## Stand-ins for the nodes the combat and enemy packages build, so the HUD and
## pause menu can be exercised (tests, captures) before those packages land.
## Each registers itself in the group the real node will use and answers the
## query methods the UI reads. Dev/test only; no game code depends on this.


class FakePlayer extends Node:
	var charges: int = 1
	var max_charges: int = 2
	var cooldown_remaining: float = 0.0
	var cooldown_total: float = 2.8

	func _init() -> void:
		add_to_group(&"player")

	func get_dash_state() -> Dictionary:
		return {"charges": charges, "max_charges": max_charges, "cooldown_remaining": cooldown_remaining, "cooldown_total": cooldown_total}


class FakeBattleSkill extends Node:
	var skill_id: String = "arrow_storm"
	var cooldown_remaining: float = 0.0
	var cooldown_total: float = 16.0
	var is_ready: bool = true

	func _init() -> void:
		add_to_group(&"battle_skill")

	func get_state() -> Dictionary:
		return {"skill_id": skill_id, "cooldown_remaining": cooldown_remaining, "cooldown_total": cooldown_total, "ready": is_ready}


class FakeAbilityManager extends Node:
	var player_abilities: Array = [{"id": "flame_arrows", "level": 3}, {"id": "whirling_axes", "level": 1}, {"id": "storm_bolt", "level": 5}]
	var tower_abilities: Array = [{"id": "ballista", "level": 2}]
	var passives: Array = [
		{"id": "fleet_step", "display_name": "Fleet Step", "rank": 2, "max_rank": 3, "pool": "player"},
		{"id": "stone_mason", "display_name": "Stone Mason", "rank": 1, "max_rank": 2, "pool": "tower"},
	]

	func _init() -> void:
		add_to_group(&"ability_manager")

	func get_owned_abilities(slot_kind: String) -> Array:
		return player_abilities if slot_kind == "player" else tower_abilities

	func get_passive_summary() -> Array:
		return passives


class FakeTowerRepair extends Node:
	var repairing: bool = false

	func _init() -> void:
		add_to_group(&"tower_repair")

	func is_repairing() -> bool:
		return repairing


class FakeWaveDirector extends Node:
	var wave_number: int = 6
	var wave_count: int = 15
	var wave_type: String = "split"
	var progress: float = 0.4
	var elapsed: float = 272.0
	var boss: bool = false

	func _init() -> void:
		add_to_group(&"wave_director")

	func get_current_wave_number() -> int:
		return wave_number

	func get_wave_count() -> int:
		return wave_count

	func get_current_wave_type() -> String:
		return wave_type

	func get_wave_progress() -> float:
		return progress

	func get_run_elapsed_seconds() -> float:
		return elapsed

	func is_boss_wave() -> bool:
		return boss


## Adds one of each fake under `parent` and returns them by name.
static func install(parent: Node) -> Dictionary:
	var out: Dictionary = {
		"player": FakePlayer.new(), "skill": FakeBattleSkill.new(), "abilities": FakeAbilityManager.new(),
		"repair": FakeTowerRepair.new(), "director": FakeWaveDirector.new(),
	}
	for key: String in out:
		parent.add_child(out[key])
	return out
