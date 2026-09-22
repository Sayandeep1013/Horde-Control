extends RefCounted
class_name DamageNumberFx

## DamageNumberFx (hit-feedback pass, optional item per this task's own
## brief: "only if the Register/caps already define damage numbers").
## MASTER_SDLC.md's Provisional Values Register DOES define one -- `src/
## core/entity_caps.gd`'s own `MAX_DAMAGE_NUMBERS` (30), transcribed there
## from the Register's "Entity caps" row -- so this file exists rather than
## being skipped. `MAX_NUMBERS` below REFERENCES that constant directly
## (CLAUDE.md: "every gameplay number lives in the ... Register; every other
## place references it"), never re-typing the literal 30.
##
## ## Still not routed through EntitySpawner's own damage-number pool
## `src/core/entity_spawner.gd` already owns a `spawn_damage_number()` pool
## capped at the same Register number, but reaching it requires either a
## fifth Autoload (not permitted -- see `blood_fx.gd`'s header) or an
## `@export`ed NodePath wired on the one EntitySpawner instance living under
## `scenes/main.tscn`/the assembled prototype scene, which this task's hard
## constraints put out of reach (touching that wiring risks the exact
## structural-scene conflict with the parallel mechanics/HUD sessions this
## task was told to avoid). This file instead follows `blood_fx.gd`'s own
## precedent one more time: a small, separately-capped, static-class pool
## that reads the SAME Register number rather than inventing its own,
## cheap enough to need no cap enforcement of its own beyond that shared
## number. Named consequence, not silently left: `src/debug/overlay.gd`'s
## "DamageNumbers" field reads `EntitySpawner.get_damage_number_count()`,
## so numbers spawned here do not add to that count -- the same gap
## `blood_fx.gd`'s header already accepts for its own two pools.
##
## Enemy hits only (this task's brief names enemies for health bars; the
## player's own hit feedback is deliberately "restrained" per that same
## brief, and a floating number over the player's own head would fight the
## HUD's player HP display, which is out of this task's allowed paths).

const MAX_NUMBERS: int = EntityCaps.MAX_DAMAGE_NUMBERS

const RISE_DISTANCE_PX: float = 30.0
const VISIBLE_SECONDS: float = 0.6
const FONT_SIZE: int = 21
const OUTLINE_SIZE: int = 3

const COLOR_NORMAL: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_LETHAL: Color = Color(1.0, 0.85, 0.20, 1.0)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.85)

## docs/20_Technical_Architecture.md > Scene Tree > draw order: "damage
## numbers: 60" -- the topmost cosmetic layer, above telegraphs (40) and
## the player (50), so a number is never hidden by anything it is reporting
## damage against.
const Z_INDEX: int = 60

## `_pool` is deliberately UNTYPED (`Array`, not `Array[Node2D]`). Found by
## this task's own test run (teaching_siege_tuning_test.gd, tower_damage_
## path_test.gd): once a test's scene tree is torn down between test
## functions while this static pool survives for the whole test binary
## (header, "Scene reload safety"), a slot can hold a NODE THE ENGINE
## ALREADY FREED. Reading that slot into anything statically typed --
## a typed array element OR a `var x: NumberLabel = ...` local -- makes
## Godot 4.7.1 try to verify the freed object's dynamic type against the
## declared static type, which raises "Trying to assign invalid previously
## freed instance" instead of just handing back a value `is_instance_valid()`
## can check. `_acquire_slot()` below is the ONLY place that ever reads a
## slot before confirming validity, and it does so through this untyped
## array specifically so that read cannot itself crash; every OTHER read
## (`spawn()`'s own `_pool[idx]`) happens only after `_acquire_slot()` has
## already guaranteed the slot holds a live object.
static var _pool: Array = []
static var _tweens: Array[Tween] = [] # Tween is RefCounted, not a freed-Node hazard (killing a Tween does not free it while this array still holds a reference), so this one stays typed.
static var _next_index: int = 0


## A tiny `_draw()`-only Node2D, one per pooled slot -- matches `src/enemy/
## enemy_health_bar.gd`'s own "a small Node2D with `_draw()` is fine"
## precedent rather than a Control/Label subtree in world space.
class NumberLabel:
	extends Node2D

	var label_text: String = ""
	var label_color: Color = Color.WHITE

	func _draw() -> void:
		if label_text.is_empty():
			return
		var font: Font = ThemeDB.fallback_font
		var size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var origin: Vector2 = Vector2(-size.x * 0.5, size.y * 0.25)
		draw_string_outline(font, origin, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, COLOR_OUTLINE)
		draw_string(font, origin, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, label_color)


## Typed entry point. `container` is the caller's already-resolved live
## node (the enemy's own parent -- same convention as `blood_fx.gd`).
## `lethal` picks the brighter colour for a killing blow.
static func spawn(container: Node, position: Vector2, amount: float, lethal: bool = false) -> void:
	if MAX_NUMBERS <= 0 or container == null or not is_instance_valid(container):
		return
	var idx: int = _acquire_slot(container)
	if idx == -1:
		return
	var label: NumberLabel = _pool[idx] # safe: _acquire_slot() guarantees a live, valid instance at this index before returning
	label.label_text = str(int(round(amount)))
	label.label_color = COLOR_LETHAL if lethal else COLOR_NORMAL
	label.global_position = position + Vector2(randf_range(-6.0, 6.0), -6.0)
	label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	label.visible = true
	label.queue_redraw()

	var old_tween: Tween = _tweens[idx]
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var tween: Tween = label.create_tween() # cosmetic-only Node.create_tween(), matching every other FX in this pass
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -RISE_DISTANCE_PX), VISIBLE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, VISIBLE_SECONDS).set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(_on_number_faded.bind(label))
	_tweens[idx] = tween


static func _on_number_faded(label: Node2D) -> void:
	if is_instance_valid(label):
		label.visible = false


static func _acquire_slot(container: Node) -> int:
	if _pool.size() < MAX_NUMBERS:
		var fresh: NumberLabel = _build_label()
		container.add_child(fresh)
		_pool.append(fresh)
		_tweens.append(null)
		return _pool.size() - 1

	var idx: int = _next_index
	_next_index = (_next_index + 1) % MAX_NUMBERS
	# `_pool[idx]` is read here ONLY through `is_instance_valid()` (a Variant
	# parameter -- no static-type check on a possibly-freed value) or, once
	# validity is confirmed, through the untyped `existing` local below.
	# Never assign this raw read into a `NumberLabel`-typed variable -- see
	# `_pool`'s own header for why that specific pattern is what crashed.
	if not is_instance_valid(_pool[idx]):
		var fresh: NumberLabel = _build_label()
		container.add_child(fresh)
		_pool[idx] = fresh
	else:
		var existing: Node = _pool[idx] # safe: just confirmed valid above
		if existing.get_parent() != container:
			existing.reparent(container) # defensive only -- this file is enemy-only (see header), so every real caller shares the one `Entities` container, unlike blood_fx.gd's burst pool which also serves the player
	return idx


static func _build_label() -> NumberLabel:
	var l: NumberLabel = NumberLabel.new()
	l.z_as_relative = false
	l.z_index = Z_INDEX
	l.visible = false
	return l


## Test-only teardown, matching `blood_fx.gd`'s own `clear_for_test()`.
## Never called by gameplay code.
static func clear_for_test() -> void:
	for n in _pool:
		if is_instance_valid(n):
			n.queue_free()
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_pool.clear()
	_tweens.clear()
	_next_index = 0
