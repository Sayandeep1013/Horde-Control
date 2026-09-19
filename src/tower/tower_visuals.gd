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
## Two-layer approach: `Sprite` (no per-sprite scale of its own; the
## parent `Visuals` node carries a 4.0 scale so the 64x64 Kenney tiles span
## this Tower's 212 px footprint -- see scenes/tower.tscn) carries the
## health-tracked colour tint; `ShieldShimmer`, a second Sprite2D using the
## SAME texture as `Sprite` in additive-ish overlay (a brighter,
## cyan-shifted modulate with alpha driven by the shield fraction), carries
## the shield readout so health and shield never fight for the same colour
## channel.
##
## ## Stage-to-texture mapping (integration task; docs/25_Asset_Pipeline.md;
## MASTER_SDLC.md > Tower Evolution Stages: Base/Reinforced/Armed/Fortress).
## `Platform` (a separate, always-visible Sprite2D set from `platform_path`)
## carries `assets/third_party/kenney/tower/tower_platform.png` as the base
## plate, unaffected by evolution stage. `stage_textures[0..3]` holds the
## four Kenney evolution-stage textures
## (tower_stage1_base.png..tower_stage4_fortress.png), assigned in
## scenes/tower.tscn as exported properties, never a hardcoded path in this
## script's logic (D99). `on_stage_changed()` is a typed listener for
## `TowerEvolutionStage.stage_changed` (wired by src/tower/tower.gd), and is
## also called once by Tower._ready() immediately after connecting, to
## prime the initial (stage 0, Base) texture before any rank is ever taken
## -- `TowerEvolutionStage.configure()` sets the initial stage but does not
## itself emit `stage_changed` (it only emits on a stage CHANGE), so nothing
## else would ever apply stage 0's texture otherwise. `ShieldShimmer`'s
## texture is kept in sync with `Sprite`'s on every stage change so the
## shimmer overlay never shows a different stage's silhouette than the base
## sprite it overlays.

const HEALTHY_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const CRITICAL_TINT: Color = Color(1.0, 0.35, 0.32, 1.0)
const FLASH_TINT: Color = Color(1.6, 1.6, 1.6, 1.0)
const FIRE_PULSE_SCALE: float = 1.12

const DAMAGE_FLASH_DURATION: float = 0.12
const FIRE_PULSE_DURATION: float = 0.1
const SHIELD_SHIMMER_PULSE_DURATION: float = 1.4

@export var sprite_path: NodePath
@export var shield_shimmer_path: NodePath
@export var platform_path: NodePath

## Stage-to-texture mapping (docs/25_Asset_Pipeline.md; integration task).
## Index 0 = Base, 1 = Reinforced, 2 = Armed, 3 = Fortress -- matching
## TowerEvolutionStage's own stage-index convention (0-3) and the
## Register's "Tower evolution thresholds" row order. Asset paths are
## assigned in scenes/tower.tscn, never hardcoded here (D99).
@export var stage_textures: Array[Texture2D] = []

## The always-visible base plate, independent of evolution stage.
@export var platform_texture: Texture2D

var _sprite: Sprite2D = null
var _shield_shimmer: Sprite2D = null
var _platform: Sprite2D = null
var _base_tint: Color = HEALTHY_TINT
var _flash_tween: Tween = null
var _pulse_tween: Tween = null
var _shimmer_loop_tween: Tween = null


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_shield_shimmer = get_node_or_null(shield_shimmer_path) as Sprite2D
	_platform = get_node_or_null(platform_path) as Sprite2D
	if _platform != null and platform_texture != null:
		_platform.texture = platform_texture
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


## Typed listener for TowerEvolutionStage.stage_changed(new_stage,
## ranks_held), wired by src/tower/tower.gd. Also called once, directly, by
## Tower._ready() right after connecting, to prime the initial stage 0
## texture -- TowerEvolutionStage.configure() sets the initial stage but
## only emits this signal on a later CHANGE, never for the starting value.
func on_stage_changed(new_stage: int, _ranks_held: int) -> void:
	if stage_textures.is_empty():
		return
	var clamped_stage: int = clampi(new_stage, 0, stage_textures.size() - 1)
	var tex: Texture2D = stage_textures[clamped_stage]
	if tex == null:
		return
	if _sprite != null:
		_sprite.texture = tex
	if _shield_shimmer != null:
		_shield_shimmer.texture = tex


func _start_shimmer_loop() -> void:
	if _shield_shimmer == null:
		return
	_shimmer_loop_tween = create_tween()
	_shimmer_loop_tween.set_loops()
	_shimmer_loop_tween.tween_property(_shield_shimmer, "scale", Vector2.ONE * 1.03, SHIELD_SHIMMER_PULSE_DURATION * 0.5)
	_shimmer_loop_tween.tween_property(_shield_shimmer, "scale", Vector2.ONE, SHIELD_SHIMMER_PULSE_DURATION * 0.5)
