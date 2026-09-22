extends Node2D
class_name TowerVisuals

## TowerVisuals (P2.4; art pass, D102). Build section: "Make its state legible at a
## glance ... the energy core's brightness or colour tracking health, a
## shield shimmer that fades as the shield depletes, a clear damage flash,
## and a visible pulse when it fires. Code-driven animation only
## (Node.create_tween() is permitted for cosmetic work; the get_tree()
## variants are banned)." Every tween below is a bare create_tween() call
## on `self` or a child Sprite2D/AnimatedSprite2D, never
## get_tree().create_tween() -- tools/checks/banned_api_check.sh greps for
## exactly that distinction.
##
## Purely cosmetic and read-only: this component only listens to
## TowerHealth's/TowerWeapon's/TowerEvolutionStage's signals and drives
## Sprite2D.modulate/scale/texture and a couple of AnimatedSprite2D
## visibility flags. It never mutates gameplay state, so it has no bearing
## on any acceptance test and needs no SimClock-deadline discipline
## (SimClock's rule targets GAMEPLAY deadlines; a cosmetic tween bound to
## this node pauses with it exactly as the master's own carve-out
## describes).
##
## ## Art pass (D102): Tiny Swords, common canvas, base-anchored
## `stage_textures`/`destroyed_*_texture` all share one 320x256 canvas (the
## native size of Castle_Blue.png; the two Tower_Blue-derived textures are
## letterboxed into it -- see assets/third_party/tiny_swords/PROVENANCE.md,
## `Derived/` rows) so a SINGLE scale and a SINGLE anchor offset works for
## every stage, exactly like the old 4x-Kenney-scale note this replaces
## used to explain for its own texture size. `Visuals` itself now carries
## scale (1,1) (real pixel-art art at the Tower's intended on-screen size,
## no upscale needed) and `texture_filter = NEAREST` (propagates to every
## child left at the CanvasItem default of "inherit from parent").
## `Sprite`/`ShieldShimmer` are positioned at `(0, -CANVAS_SIZE.y / 2.0)`
## rather than left at Visuals' own origin: every source image already has
## its building's ground line at the very bottom of its 256 px canvas
## height (confirmed by inspecting Tower_Blue.png/Castle_Blue.png
## directly), so shifting a CENTERED Sprite2D up by half the canvas height
## puts that bottom edge exactly on the Tower's own position -- "Anchor so
## the building's base sits on the Tower's position" (task brief).
##
## ## GroundShadow (was `Platform`)
## The old Kenney art needed a separate always-visible base-plate sprite;
## the Tiny Swords buildings already draw their own foundation, so that
## slot is repurposed (same NodePath/export shape, renamed for what it now
## holds) to carry a small procedurally-generated soft shadow ellipse
## (`assets/sprites/tower/tower_ground_shadow.png` -- fully original
## pixels, not derived from any asset pack, so it carries no PROVENANCE
## row) instead of a Kenney plate texture. Still the first child drawn
## (sibling order), so it sits under the building.
##
## ## Fire overlay (new, task brief item: "Add Fire.png flames ... when
## health is low ... purely cosmetic")
## Two small AnimatedSprite2D children, `FireLow`/`FireCritical`, share ONE
## SpriteFrames built once in `_ready()` by slicing
## `assets/third_party/tiny_swords/Effects/Fire/Fire.png` (128x128, 7
## frames) into an AtlasTexture per frame -- built from code so the shared
## resource is created exactly once regardless of Tower instance count
## (the project's own "share SpriteFrames resources" performance rule,
## scenery_scatter.gd's own header). `FireLow` shows below
## FIRE_LOW_HEALTH_FRACTION, `FireCritical` ADDITIONALLY shows below
## FIRE_CRITICAL_HEALTH_FRACTION -- "more at <25%" (task brief) reads as
## MORE flames, not a bigger single flame, so both stay independently
## visible/hidden rather than one sprite changing size. Both thresholds are
## local cosmetic-feel constants, matching this file's own existing
## DAMAGE_FLASH_DURATION/FIRE_PULSE_SCALE precedent -- not Register numbers
## (they cannot change the shape of the game; the task brief itself offers
## them with "e.g.").
##
## ## Destroyed art (task brief item: "Show Castle/Tower_Destroyed when the
## Tower dies")
## `TowerHealth.tower_destroyed(timestamp)` already exists and already
## fires exactly once, at Logical Death (see that file's header) -- it was
## simply never connected to Visuals. `src/tower/tower.gd` now makes that
## connection in `_ready()` (`health.tower_destroyed.connect(visuals.
## on_tower_destroyed)`), matching every other Health->Visuals wire in that
## same block. `on_tower_destroyed()` swaps `Sprite.texture` to
## `destroyed_tower_texture` (stages 0-1, the round tower silhouette) or
## `destroyed_castle_texture` (stages 2-3, the castle silhouette), keyed by
## `_current_stage` (tracked from `on_stage_changed`, which Tower.gd already
## calls once at boot to prime stage 0 before this method can ever see a
## stale value) and stops the shield shimmer (no shield reads once the
## Tower is gone).
##
## ## Stage-to-texture mapping (integration task; docs/25_Asset_Pipeline.md;
## MASTER_SDLC.md > Tower Evolution Stages: Base/Reinforced/Armed/Fortress).
## `stage_textures[0..3]` holds Base/Reinforced/Armed/Fortress, assigned in
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

## Common canvas every stage/destroyed texture shares -- see class header.
const CANVAS_SIZE: Vector2 = Vector2(320.0, 256.0)

## Cosmetic feel thresholds for the fire overlay -- see class header,
## "Fire overlay." Not Register numbers: purely a VFX trigger point, named
## with "e.g." by the task brief itself.
const FIRE_LOW_HEALTH_FRACTION: float = 0.5
const FIRE_CRITICAL_HEALTH_FRACTION: float = 0.25
const FIRE_FRAME_SIZE: int = 128
const FIRE_FRAME_COUNT: int = 7
const FIRE_ANIMATION_NAME: StringName = &"burn"
const FIRE_FPS: float = 10.0

## Stages 0-1 (Tower silhouette) vs 2-3 (Castle silhouette) -- see class
## header, "Destroyed art."
const CASTLE_FAMILY_MIN_STAGE: int = 2

@export var sprite_path: NodePath
@export var shield_shimmer_path: NodePath
@export var ground_shadow_path: NodePath
@export var fire_low_path: NodePath
@export var fire_critical_path: NodePath

## Stage-to-texture mapping (docs/25_Asset_Pipeline.md; integration task).
## Index 0 = Base, 1 = Reinforced, 2 = Armed, 3 = Fortress -- matching
## TowerEvolutionStage's own stage-index convention (0-3) and the
## Register's "Tower evolution thresholds" row order. Asset paths are
## assigned in scenes/tower.tscn, never hardcoded here (D99).
@export var stage_textures: Array[Texture2D] = []

## The always-visible soft ground shadow, independent of evolution stage.
## Was `platform_texture` (a Kenney base-plate sprite) before the D102 art
## pass -- see class header, "GroundShadow."
@export var ground_shadow_texture: Texture2D

## Destroyed-state art -- see class header, "Destroyed art."
@export var destroyed_tower_texture: Texture2D
@export var destroyed_castle_texture: Texture2D

## Source sheet for the fire overlay (128x128, 7-frame loop) -- see class
## header, "Fire overlay."
@export var fire_texture: Texture2D

var _sprite: Sprite2D = null
var _shield_shimmer: Sprite2D = null
var _ground_shadow: Sprite2D = null
var _fire_low: AnimatedSprite2D = null
var _fire_critical: AnimatedSprite2D = null
var _base_tint: Color = HEALTHY_TINT
var _flash_tween: Tween = null
var _pulse_tween: Tween = null
var _shimmer_loop_tween: Tween = null
var _current_stage: int = 0
var _destroyed: bool = false


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_shield_shimmer = get_node_or_null(shield_shimmer_path) as Sprite2D
	_ground_shadow = get_node_or_null(ground_shadow_path) as Sprite2D
	_fire_low = get_node_or_null(fire_low_path) as AnimatedSprite2D
	_fire_critical = get_node_or_null(fire_critical_path) as AnimatedSprite2D
	if _ground_shadow != null and ground_shadow_texture != null:
		_ground_shadow.texture = ground_shadow_texture
	if _shield_shimmer != null:
		_shield_shimmer.modulate = Color(0.6, 0.95, 1.0, 0.0)
		_start_shimmer_loop()
	_setup_fire()


func on_health_changed(current_health: float, max_health: float) -> void:
	if _sprite == null or max_health <= 0.0:
		return
	var fraction: float = clampf(current_health / max_health, 0.0, 1.0)
	_base_tint = HEALTHY_TINT.lerp(CRITICAL_TINT, 1.0 - fraction)
	if _flash_tween == null or not _flash_tween.is_running():
		_sprite.modulate = _base_tint
	_update_fire(fraction)


func on_shield_changed(current_shield: float, max_shield: float) -> void:
	if _shield_shimmer == null or _destroyed:
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
	_current_stage = new_stage
	if _destroyed or stage_textures.is_empty():
		return
	var clamped_stage: int = clampi(new_stage, 0, stage_textures.size() - 1)
	var tex: Texture2D = stage_textures[clamped_stage]
	if tex == null:
		return
	if _sprite != null:
		_sprite.texture = tex
	if _shield_shimmer != null:
		_shield_shimmer.texture = tex


## Typed listener for TowerHealth.tower_destroyed(timestamp), wired by
## src/tower/tower.gd -- see class header, "Destroyed art."
func on_tower_destroyed(_timestamp: float = 0.0) -> void:
	_destroyed = true
	var destroyed_tex: Texture2D = destroyed_castle_texture if _current_stage >= CASTLE_FAMILY_MIN_STAGE else destroyed_tower_texture
	if _sprite != null and destroyed_tex != null:
		_sprite.texture = destroyed_tex
		_sprite.modulate = HEALTHY_TINT
		_sprite.scale = Vector2.ONE
	if _shield_shimmer != null:
		if _shimmer_loop_tween != null and _shimmer_loop_tween.is_running():
			_shimmer_loop_tween.kill()
		_shield_shimmer.modulate.a = 0.0


func _start_shimmer_loop() -> void:
	if _shield_shimmer == null:
		return
	_shimmer_loop_tween = create_tween()
	_shimmer_loop_tween.set_loops()
	_shimmer_loop_tween.tween_property(_shield_shimmer, "scale", Vector2.ONE * 1.03, SHIELD_SHIMMER_PULSE_DURATION * 0.5)
	_shimmer_loop_tween.tween_property(_shield_shimmer, "scale", Vector2.ONE, SHIELD_SHIMMER_PULSE_DURATION * 0.5)


## Builds the shared fire SpriteFrames once (see class header, "Fire
## overlay") and assigns it to both fire children. Both start hidden;
## on_health_changed() drives visibility from the real health fraction.
func _setup_fire() -> void:
	if fire_texture == null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(FIRE_ANIMATION_NAME)
	frames.set_animation_loop_mode(FIRE_ANIMATION_NAME, SpriteFrames.LOOP_LINEAR)
	frames.set_animation_speed(FIRE_ANIMATION_NAME, FIRE_FPS)
	for i in FIRE_FRAME_COUNT:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = fire_texture
		atlas.region = Rect2(i * FIRE_FRAME_SIZE, 0, FIRE_FRAME_SIZE, FIRE_FRAME_SIZE)
		frames.add_frame(FIRE_ANIMATION_NAME, atlas)
	for fire in [_fire_low, _fire_critical]:
		if fire == null:
			continue
		fire.sprite_frames = frames
		fire.animation = FIRE_ANIMATION_NAME
		fire.visible = false
		fire.play(FIRE_ANIMATION_NAME)


func _update_fire(fraction: float) -> void:
	if _destroyed:
		return
	if _fire_low != null:
		_fire_low.visible = fraction < FIRE_LOW_HEALTH_FRACTION
	if _fire_critical != null:
		_fire_critical.visible = fraction < FIRE_CRITICAL_HEALTH_FRACTION
