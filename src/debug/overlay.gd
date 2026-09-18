class_name DebugOverlay
extends CanvasLayer

## Debug Overlay (docs/20_Technical_Architecture.md > "Debugging, Telemetry
## & Run Recording" > Debug Overlay bullet; MASTER_SDLC.md > Provisional
## Values Register > Technical Caps & Performance > "Debug overlay" row,
## C-TELEMETRY). Displays every field that bullet names -- see
## phases/PHASE_02_Technical_Foundations/evidence/p14_report.md for the
## field-by-field mapping table this file is built against.
##
## PROCESS_MODE_ALWAYS: MASTER_SDLC.md > Global Simulation Authority names
## "the UI CanvasLayer" itself as PROCESS_MODE_ALWAYS ("PauseAuthority,
## EventBus, the UI CanvasLayer ... are PROCESS_MODE_ALWAYS, so they keep
## functioning while paused"). This scene root is that layer's debug
## counterpart, so it keeps sampling FPS and refreshing its own text while
## the game is paused (a Level-Up Draft, the pause menu, the debug pause
## reason itself) instead of freezing along with the gameplay it exists to
## help a developer observe. The GAMEPLAY values it displays (entity
## counts, HP, Pressure, SimClock time) still read as frozen during a
## pause, because their OWN sources (EntityRegistry, SimClock, and this
## scene's own injected setters, none of which this node writes to itself)
## stop changing -- this node's process mode only keeps ITS OWN sampling
## and text refresh alive; it does not fabricate motion in paused data.
##
## F1 (debug_overlay_toggle) and F2 (debug_pseudoloc_toggle) are existing
## project.godot actions bound by decision D78 (MASTER_SDLC.md > Review
## Decision Log); this script is their only current consumer. No new input
## action is invented here.
##
## Entity-count and telemetry-count fields query
## EntityRegistry.get_entity_count(tag) with this script's OWN choice of
## tag strings ("enemy", "projectile", "pickup", "effect", "damage_number",
## "telegraph", "vfx_high_intensity"). "enemy" is the one tag
## EntityRegistry itself already hard-codes (get_enemies_in_radius(),
## get_live_enemy_count()), so it is not this script's invention; the other
## six are this script's own convention, since no pool, spawner, or VFX
## system exists yet (P1.3 is concurrent with this task; P1.5+ is later) to
## fix one. If a later system tags its pooled instances differently, these
## counts read zero rather than erroring -- see the evidence report,
## "Contradictions and ambiguities."
##
## Player/Tower HP & shield, Wave/Encounter ID, Pressure value & state, and
## health quadrant have no owning system yet: Health is doc 05 / P2.x, the
## Wave Director is P2.8, and the Pressure Metric is P2.9 -- P2.9's own
## task row (PLAN.md line, MASTER_SDLC.md task table) names "overlay
## fields" as part of ITS OWN deliverable, meaning this phase is expected
## to leave the display slot present and empty, not populated. Until a real
## system calls the typed setters below, these fields display "n/a" rather
## than a fabricated number.

const TAG_ENEMY: StringName = &"enemy"
const TAG_PROJECTILE: StringName = &"projectile"
const TAG_PICKUP: StringName = &"pickup"
const TAG_EFFECT: StringName = &"effect"
const TAG_DAMAGE_NUMBER: StringName = &"damage_number"
const TAG_TELEGRAPH: StringName = &"telegraph"
const TAG_VFX_HIGH_INTENSITY: StringName = &"vfx_high_intensity"

## Tag -> EntitySpawner count method. Kept as data so a reviewer can diff it
## against `src/core/entity_spawner.gd` without reading either implementation.
const _SPAWNER_COUNT_METHODS: Dictionary = {
	TAG_ENEMY: "get_enemy_count",
	TAG_PICKUP: "get_pickup_count",
	TAG_PROJECTILE: "get_projectile_count",
	TAG_DAMAGE_NUMBER: "get_damage_number_count",
	TAG_TELEGRAPH: "get_telegraph_count",
	TAG_VFX_HIGH_INTENSITY: "get_high_intensity_vfx_count",
}

var _entity_source: Object = null

const FPS_WINDOW_MS: int = 10000 # rolling 10 second window, real (wall) time --
# FPS is a rendered-frame measurement, not a simulation-time one, so it is
# deliberately NOT measured against SimClock (which also freezes under
# pause, when FPS still very much exists and is worth showing).

## Provisional Default (MASTER_SDLC.md > Provisional Values Register >
## Technical Caps & Performance > "Debug overlay" row: "pseudo-localization
## toggle uses Godot's built-in pseudolocalization, expansion ratio 0.3").
## Cited, not restated as a bare literal anywhere else in this file.
const PSEUDOLOC_EXPANSION_RATIO: float = 0.3

const UNSET_LABEL: String = "n/a"

@onready var _fields_label: Label = $Panel/Margin/FieldsLabel

var _visible_overlay: bool = true
var _fps_samples: Array[Dictionary] = [] # [{"t_ms": int, "fps": float}, ...]

# Injected gameplay state (see header comment). NAN / empty string sentinels
# mean "no system has ever called the setter", displayed as UNSET_LABEL
# rather than a fabricated number.
var _player_hp: float = NAN
var _tower_hp: float = NAN
var _tower_shield: float = NAN
var _wave_id: String = ""
var _encounter_id: String = ""
var _pressure_value: float = NAN
var _pressure_state: String = ""
var _health_quadrant: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fields_label.visible = _visible_overlay


func _process(delta: float) -> void:
	_record_fps_sample(delta)
	_refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay_toggle"):
		_visible_overlay = not _visible_overlay
		_fields_label.visible = _visible_overlay
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_pseudoloc_toggle"):
		toggle_pseudolocalization()
		get_viewport().set_input_as_handled()


## Typed command. Flips Godot's built-in pseudolocalization on/off and
## (re)applies the Provisional Default expansion ratio each time it is
## turned on, since the ratio lives only in ProjectSettings' in-memory copy
## -- this never calls ProjectSettings.save(), so project.godot itself is
## never touched by this toggle (this delegation may only edit
## project.godot's autoload lines, and only if an autoload is added).
## reload_pseudolocalization() forces TranslationServer to re-read the
## ratio immediately rather than waiting for some other trigger.
func toggle_pseudolocalization() -> void:
	var enabled: bool = not TranslationServer.is_pseudolocalization_enabled()
	ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", PSEUDOLOC_EXPANSION_RATIO)
	TranslationServer.set_pseudolocalization_enabled(enabled)
	TranslationServer.reload_pseudolocalization()


func is_overlay_visible() -> bool:
	return _visible_overlay


## ---- Typed commands (docs/20 > "Communication, commands"): future
## systems push their own state here. This scene never reaches into
## another system's fields to read them.

func set_player_state(hp: float) -> void:
	_player_hp = hp


func set_tower_state(hp: float, shield: float) -> void:
	_tower_hp = hp
	_tower_shield = shield


func set_wave_encounter(wave_id: String, encounter_id: String) -> void:
	_wave_id = wave_id
	_encounter_id = encounter_id


func set_pressure(value: float, state: String) -> void:
	_pressure_value = value
	_pressure_state = state


func set_health_quadrant(quadrant: String) -> void:
	_health_quadrant = quadrant


## ---- FPS rolling window (real/wall time -- see header comment).

func _record_fps_sample(delta: float) -> void:
	var fps: float = (1.0 / delta) if delta > 0.0 else 0.0
	var now_ms: int = Time.get_ticks_msec()
	_fps_samples.append({"t_ms": now_ms, "fps": fps})
	while not _fps_samples.is_empty() and now_ms - int(_fps_samples[0]["t_ms"]) > FPS_WINDOW_MS:
		_fps_samples.pop_front()


func _fps_current() -> float:
	return Engine.get_frames_per_second()


## `p` in [0.0, 1.0]. Sorts the window's samples and indexes into them --
## p=0.01 is "1st percentile" (the low tail, i.e. near-worst-case frames),
## p=0.5 is the median.
func _fps_percentile(p: float) -> float:
	if _fps_samples.is_empty():
		return 0.0
	var values: Array[float] = []
	for s in _fps_samples:
		values.append(float(s["fps"]))
	values.sort()
	var idx: int = int(round(p * float(values.size() - 1)))
	idx = clampi(idx, 0, values.size() - 1)
	return values[idx]


## ---- Text refresh: one multi-line Label lists every docs/20 field (see
## the evidence report's field-mapping table for the full 1:1
## correspondence between a line here and a docs/20 bullet item).

func _refresh_text() -> void:
	var lines: Array[String] = []
	lines.append("FPS cur/median/p1: %.0f / %.0f / %.0f" % [_fps_current(), _fps_percentile(0.5), _fps_percentile(0.01)])
	lines.append("Entities  Enemies:%d  Projectiles:%d  Pickups:%d  Effects:%d" % [
		_count_tag(TAG_ENEMY), _count_tag(TAG_PROJECTILE),
		_count_tag(TAG_PICKUP), _count_tag(TAG_EFFECT),
	])
	lines.append("DamageNumbers:%d  Telegraphs:%d  HighIntensityVFX:%d" % [
		_count_tag(TAG_DAMAGE_NUMBER), _count_tag(TAG_TELEGRAPH), _count_tag(TAG_VFX_HIGH_INTENSITY),
	])
	lines.append("Player HP: %s" % _fmt(_player_hp))
	lines.append("Tower HP: %s  Tower Shield: %s" % [_fmt(_tower_hp), _fmt(_tower_shield)])
	lines.append("Wave: %s  Encounter: %s" % [_str_or_unset(_wave_id), _str_or_unset(_encounter_id)])
	lines.append("Pressure: %s  State: %s" % [_fmt(_pressure_value), _str_or_unset(_pressure_state)])
	lines.append("Health Quadrant: %s" % _str_or_unset(_health_quadrant))
	lines.append("Sim Time: %.2f" % SimClock.now)
	lines.append("[QA only, not a docs/20 overlay field] Pseudo-loc: %s (ratio %.1f)" % [
		("ON" if TranslationServer.is_pseudolocalization_enabled() else "OFF"), PSEUDOLOC_EXPANSION_RATIO,
	])
	_fields_label.text = "\n".join(lines)


## Counts come from the EntitySpawner when one is attached, and only fall back
## to EntityRegistry tags otherwise.
##
## Why (Phase 02 LEDGER F02-13): P1.3 deliberately registers only enemies,
## pickups and projectiles with EntityRegistry, on the reading that nothing
## needs a *spatial* query over damage numbers, telegraphs or high-intensity
## VFX. That reading is sound on its own. But docs/20's Debug Overlay field
## list requires counts for all six, so reading them from the spatial index
## made three of the six silently report zero - which this file's own header
## predicted as the failure mode. The spawner owns the pools and already
## exposes a count method per category, so it is the honest source for a
## count; the registry is for "what is near this point", not "how many exist".
func set_entity_source(spawner: Object) -> void:
	_entity_source = spawner


func _count_tag(tag: StringName) -> int:
	if _entity_source != null:
		var method: String = _SPAWNER_COUNT_METHODS.get(tag, "")
		if method != "" and _entity_source.has_method(method):
			return _entity_source.call(method)
	if EntityRegistry == null:
		return 0
	return EntityRegistry.get_entity_count(tag)


func _fmt(value: float) -> String:
	return UNSET_LABEL if is_nan(value) else "%.1f" % value


func _str_or_unset(value: String) -> String:
	return UNSET_LABEL if value.is_empty() else value
