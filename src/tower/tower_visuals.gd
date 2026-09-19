extends Node2D
class_name TowerVisuals

## TowerVisuals (P2.4). Build section: "Make its state legible at a
## glance ... the energy core's brightness or colour tracking health, a
## shield shimmer that fades as the shield depletes, a clear damage flash,
## and a visible pulse when it fires. Code-driven animation only
## (Node.create_tween() is permitted for cosmetic work; the get_tree()
## variants are banned)." Every tween below is a bare create_tween() call
## on `self` or a child Sprite2D, never get_tree().create_tween() --
## tools/checks/banned_api_check.sh greps for exactly that distinction.
##
## Purely cosmetic and read-only: this component only listens to
## TowerHealth's/TowerWeapon's signals and drives Sprite2D.modulate/scale.
## It never mutates gameplay state, so it has no bearing on any acceptance
## test and needs no SimClock-deadline discipline (SimClock's rule targets
## GAMEPLAY deadlines; a cosmetic tween bound to this node pauses with it
## exactly as the master's own carve-out describes).
##
## Two-layer approach: `Sprite` (assets/sprites/tower.png at native scale --
## see the P2.4 evidence report for why no additional Sprite2D.scale is
## applied) carries the health-tracked colour tint; `ShieldShimmer`, a
## second Sprite2D using the SAME texture in additive-ish overlay (a
## brighter, cyan-shifted modulate with alpha driven by the shield
## fraction), carries the shield readout so health and shield never fight
## for the same colour channel.

const HEALTHY_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const CRITICAL_TINT: Color = Color(1.0, 0.35, 0.32, 1.0)
const FLASH_TINT: Color = Color(1.6, 1.6, 1.6, 1.0)
const FIRE_PULSE_SCALE: float = 1.12

const DAMAGE_FLASH_DURATION: float = 0.12
const FIRE_PULSE_DURATION: float = 0.1
const SHIELD_SHIMMER_PULSE_DURATION: float = 1.4

@export var sprite_path: NodePath
@export var shield_shimmer_path: NodePath

var _sprite: Sprite2D = null
var _shield_shimmer: Sprite2D = null
var _base_tint: Color = HEALTHY_TINT
var _flash_tween: Tween = null
var _pulse_tween: Tween = null
var _shimmer_loop_tween: Tween = null


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_shield_shimmer = get_node_or_null(shield_shimmer_path) as Sprite2D
	if _shield_shimmer != null:
		_shield_shimmer.modulate = Color(0.6, 0.95, 1.0, 0.0)
		_start_shimmer_loop()


func on_health_changed(current_health: float, max_health: float) -> void:
	if _sprite == null or max_health <= 0.0:
		return
	var fraction: float = clampf(current_health / max_health, 0.0, 1.0)
	_base_tint = HEALTHY_TINT.lerp(CRITICAL_TINT, 1.0 - fraction)
	if _flash_tween == null or not _flash_tween.is_running():
		_sprite.modulate = _base_tint


func on_shield_changed(current_shield: float, max_shield: float) -> void:
	if _shield_shimmer == null:
		return
	var fraction: float = clampf(current_shield / max_shield, 0.0, 1.0) if max_shield > 0.0 else 0.0
	var t: Tween = create_tween()
	t.tween_property(_shield_shimmer, "modulate:a", 0.55 * fraction, 0.25)


func on_damage_flash_requested(_amount: float) -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", FLASH_TINT, DAMAGE_FLASH_DURATION * 0.4)
	_flash_tween.tween_property(_sprite, "modulate", _base_tint, DAMAGE_FLASH_DURATION * 0.6)


func on_fired(_timestamp: float) -> void:
	if _sprite == null:
		return
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_sprite, "scale", Vector2.ONE * FIRE_PULSE_SCALE, FIRE_PULSE_DURATION * 0.4)
	_pulse_tween.tween_property(_sprite, "scale", Vector2.ONE, FIRE_PULSE_DURATION * 0.6)


func _start_shimmer_loop() -> void:
	if _shield_shimmer == null:
		return
	_shimmer_loop_tween = create_tween()
	_shimmer_loop_tween.set_loops()
	_shimmer_loop_tween.tween_property(_shield_shimmer, "scale", Vector2.ONE * 1.03, SHIELD_SHIMMER_PULSE_DURATION * 0.5)
	_shimmer_loop_tween.tween_property(_shield_shimmer, "scale", Vector2.ONE, SHIELD_SHIMMER_PULSE_DURATION * 0.5)
