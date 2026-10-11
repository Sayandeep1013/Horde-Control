extends AbilityNode
class_name FrostArrowsAbility
## Frost Arrows (docs/31 §4.2): arrows slow 20-40% for 1.5 s; from level 3 a hit
## has a 5-12% chance to freeze for 1 s (bosses are immune via StatusEffects).

var _weapon: AutoWeapon = null
var _hook: Callable
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng = AbilityDamage.keyed_rng("freeze")
	_hook = Callable(self, "_on_arrow_hit")
	var p: Node2D = owner_node()
	_weapon = p.get_node_or_null("AutoWeapon") as AutoWeapon if p != null else null
	if _weapon != null and not _weapon.arrow_hit_hooks.has(_hook):
		_weapon.arrow_hit_hooks.append(_hook)


func _exit_tree() -> void:
	if _weapon != null and is_instance_valid(_weapon):
		_weapon.arrow_hit_hooks.erase(_hook)


func _on_arrow_hit(enemy: Node, _damage: float) -> void:
	if not AbilityDamage.is_enemy_alive(enemy):
		return
	StatusEffects.apply_slow(enemy, v("slow"), v("duration"))
	var chance: float = v("freeze_chance")
	if chance > 0.0 and _rng.randf() < chance:
		StatusEffects.apply_freeze(enemy, v("freeze_duration"))
		Sfx.play("frost", enemy.global_position)
