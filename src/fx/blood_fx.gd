extends RefCounted
class_name BloodFx

## BloodFx (hit-feedback pass). Shared, cheap, POOLED cosmetic hit feedback
## (a particle burst plus a ground splat decal) for every damage-dealing hit
## in the game, enemy or player. Called by `src/enemy/enemy_animator.gd`
## (`damage_applied`/`logical_death`) and `src/player/player.gd`
## (`Hurtbox.damage_received`) -- neither of which this file depends on;
## callers hand in a world position, an away-from-source direction, and the
## live container node to spawn into.
##
## ## Not an EntitySpawner budget category, on purpose
## MASTER_SDLC.md's Provisional Values Register names six Technical Caps
## (enemies, pickups, projectiles, damage numbers, telegraphs, high-
## intensity VFX -- `src/core/entity_caps.gd`); blood is not a seventh row,
## and this task (a later, additive visual pass outside the tracked phase
## process) has no standing to add one. This follows the EXACT precedent
## `src/fx/death_fx.gd` / `src/enemy/enemy_animator.gd` already established
## for this same situation (that file's header: the skull FX is "spawned
## into the dying enemy's OWN parent container ... not through
## EntitySpawner's pool/cap machinery ... cheap enough ... it does not need
## the high_intensity_vfx budget's cap enforcement to stay bounded"). Two
## small, fixed, self-imposed caps below (`MAX_BURSTS`, `MAX_SPLATS`) keep
## this file's own total node count bounded regardless of how many enemies
## are ever on screen at once, the same way that precedent does.
##
## Consequence, named rather than silently left for someone else to
## rediscover: `src/debug/overlay.gd`'s "Effects"/"HighIntensityVFX" fields
## read `EntitySpawner`'s own pool counts, so blood FX nodes (like the
## pre-existing skull death FX) do not show up in either overlay figure.
## That gap already existed before this file; this file does not widen it
## into a new category, only reuses the one already accepted.
##
## ## Why static class-level pools, not an Autoload
## This project's four Autoloads are fixed by docs/20 (SimClock,
## PauseAuthority, EventBus, EntityRegistry) -- CLAUDE.md is explicit that a
## skill pack suggesting more is wrong for this project. A `static var` on a
## GDScript class (Godot 4.x) persists for the life of the running game
## exactly like a singleton would, without registering a fifth Autoload:
## every hit anywhere in the game shares the same two pools below, so a
## swarm fight's total blood-FX node count never exceeds `MAX_BURSTS +
## MAX_SPLATS` no matter how many enemies are hit at once. Instances are
## reused round-robin (the next cyclic slot is, by construction, the one
## used longest ago) instead of freed and recreated per hit -- "no per-hit
## node churn" (this task's own brief).
##
## ## Scene reload safety
## A static pool survives a full scene reload (e.g. starting a new run),
## but the NODES it references do not -- they were freed with the old
## scene tree. Every acquire path below checks `is_instance_valid()` first
## and rebuilds+re-parents a fresh instance into that slot when the old one
## is gone, exactly like `Pool.acquire()`'s own baseline-snapshot path
## handles "first time this slot is ever used".

enum Tier { PLAYER, HIT, DEATH }

const MAX_BURSTS: int = 16
const MAX_SPLATS: int = 24

const COLOR_BLOOD_BRIGHT: Color = Color(0.85, 0.07, 0.05, 1.0)
const COLOR_BLOOD_DARK: Color = Color(0.34, 0.02, 0.02, 1.0)

## docs/20_Technical_Architecture.md > Scene Tree > draw order: "effects: 35"
## -- flying blood is exactly that category, drawn above enemies (20) and
## the Tower (25) so it reads clearly over whatever it was sprayed from.
const BURST_Z_INDEX: int = 35

## A ground stain is NOT the "effects" bucket above (that would draw it
## floating over the enemy that made it) -- it belongs at ground level,
## above raw environment art (0) but below anything that stands on the
## ground (pickups 10, enemies 20), matching how `death_fx.gd` already
## carves its own absolute z_index out of docs/20's scheme for the same
## kind of reason ("a fading corpse effect never draws over a still-living
## entity").
const SPLAT_Z_INDEX: int = 5

const SPLAT_VISIBLE_SECONDS: float = 3.5
const SPLAT_FADE_SECONDS: float = 1.5 # total ~5s, inside the 4-6s brief

const SPLAT_TEXTURE_VARIANT_COUNT: int = 4
const SPLAT_TEXTURE_SIZE: int = 14

## `_burst_pool`/`_splat_pool` are deliberately UNTYPED (`Array`, not
## `Array[CPUParticles2D]`/`Array[Sprite2D]`). Found by this task's own test
## run (teaching_siege_tuning_test.gd, tower_damage_path_test.gd, via the
## identical pattern in `damage_number_fx.gd`, which DID surface it): once a
## test's scene tree is torn down between test functions while this static
## pool survives for the whole test binary (header, "Scene reload safety"),
## a slot can hold a NODE THE ENGINE ALREADY FREED. Reading that slot into
## anything statically typed -- a typed array element OR a `var x:
## CPUParticles2D = ...` local -- makes Godot 4.7.1 try to verify the freed
## object's dynamic type against the declared static type, which raises
## "Trying to assign invalid previously freed instance" instead of just
## handing back a value `is_instance_valid()` can check. `_acquire_burst()`/
## `_acquire_splat_slot()` below are the ONLY places that ever read a slot
## before confirming validity, and they do so through these untyped arrays
## specifically so that read cannot itself crash; every OTHER read
## (`_spawn_burst()`/`_spawn_splat()`'s own indexing) happens only after
## the acquire function has already guaranteed the slot holds a live object.
static var _burst_pool: Array = []
static var _burst_next_index: int = 0

static var _splat_pool: Array = []
static var _splat_tweens: Array[Tween] = [] # Tween is RefCounted, not a freed-Node hazard (killing a Tween does not free it while this array still holds a reference), so this one stays typed.
static var _splat_next_index: int = 0

static var _particle_texture: ImageTexture = null
static var _blood_ramp: Gradient = null
static var _splat_textures: Array[ImageTexture] = []


## Typed entry point for an enemy hit (`tier == HIT`) or an enemy death
## (`tier == DEATH`, bigger burst + bigger splat). `container` is the live
## node the caller already resolved to spawn cosmetics into (the enemy's
## own parent -- see `enemy_animator.gd`'s `_spawn_death_fx()` for the same
## convention); this class has no scene-tree access of its own.
static func spawn_hit(container: Node, position: Vector2, away_direction: Vector2, tier: Tier = Tier.HIT) -> void:
	if container == null or not is_instance_valid(container):
		return
	var dir: Vector2 = _resolve_direction(away_direction)
	_spawn_burst(container, position, dir, tier)
	if tier != Tier.PLAYER: # brief: player hits stay "restrained" -- burst only, no ground splat trailing the player around the arena
		_spawn_splat(container, position, tier == Tier.DEATH)


## Convenience for callers that only have a `Variant` damage `source`
## (`DeathState.damage_applied`'s own signature) rather than an
## already-computed direction. Returns the away-from-source direction when
## `source` is a live `Node2D`, or `Vector2.ZERO` (spawn_hit's own "pick a
## random direction instead" sentinel) otherwise -- brief: "source position
## if available, else random".
static func direction_away_from(source: Variant, at_position: Vector2) -> Vector2:
	if source is Node2D and is_instance_valid(source):
		return at_position - (source as Node2D).global_position
	return Vector2.ZERO


static func _resolve_direction(away_direction: Vector2) -> Vector2:
	if away_direction.length_squared() > 0.0001:
		return away_direction.normalized()
	return Vector2.RIGHT.rotated(randf() * TAU)


# --- Particle burst ---------------------------------------------------------

static func _spawn_burst(container: Node, position: Vector2, dir: Vector2, tier: Tier) -> void:
	var burst: CPUParticles2D = _acquire_burst(container)
	if burst == null:
		return
	burst.global_position = position
	burst.direction = dir
	match tier:
		Tier.PLAYER:
			burst.amount = randi_range(4, 6)
			burst.initial_velocity_min = 40.0
			burst.initial_velocity_max = 110.0
			burst.scale_amount_min = 1.2
			burst.scale_amount_max = 2.6
		Tier.DEATH:
			burst.amount = 18
			burst.initial_velocity_min = 80.0
			burst.initial_velocity_max = 240.0
			burst.scale_amount_min = 2.2
			burst.scale_amount_max = 5.0
		_:
			burst.amount = randi_range(6, 12)
			burst.initial_velocity_min = 55.0
			burst.initial_velocity_max = 160.0
			burst.scale_amount_min = 1.6
			burst.scale_amount_max = 3.6
	burst.restart()
	burst.emitting = true


static func _acquire_burst(container: Node) -> CPUParticles2D:
	if _burst_pool.size() < MAX_BURSTS:
		var fresh: CPUParticles2D = _build_burst()
		container.add_child(fresh)
		_burst_pool.append(fresh)
		return fresh

	var idx: int = _burst_next_index
	_burst_next_index = (_burst_next_index + 1) % MAX_BURSTS
	# `_burst_pool[idx]` is read here ONLY through `is_instance_valid()` (a
	# Variant parameter -- no static-type check on a possibly-freed value)
	# or, once validity is confirmed, through the typed `existing` local
	# below. Never assign this raw read into a `CPUParticles2D`-typed
	# variable directly -- see `_burst_pool`'s own header for why that
	# specific pattern is what crashed (in the sibling damage-number pool).
	if not is_instance_valid(_burst_pool[idx]):
		var fresh: CPUParticles2D = _build_burst()
		container.add_child(fresh)
		_burst_pool[idx] = fresh
		return fresh
	var existing: CPUParticles2D = _burst_pool[idx] # safe: just confirmed valid above
	if existing.get_parent() != container:
		existing.reparent(container) # NOT merely defensive for bursts specifically: the player's own hits (Tier.PLAYER) and every enemy's hits share this ONE pool, but resolve DIFFERENT containers (the player is not a child of `Entities`, docs/20 > Scene Tree) -- a slot last used by one kind and now reused by the other genuinely needs to move.
	return existing


static func _build_burst() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.4
	p.lifetime = 0.35
	p.spread = 45.0
	p.gravity = Vector2(0.0, 260.0)
	p.damping_min = 40.0
	p.damping_max = 100.0
	p.color_ramp = _get_blood_ramp()
	p.texture = _get_particle_texture()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.z_as_relative = false
	p.z_index = BURST_Z_INDEX
	return p


static func _get_blood_ramp() -> Gradient:
	if _blood_ramp == null:
		var g: Gradient = Gradient.new()
		var fade_out: Color = COLOR_BLOOD_DARK
		fade_out.a = 0.0
		g.colors = PackedColorArray([COLOR_BLOOD_BRIGHT, COLOR_BLOOD_DARK, fade_out])
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		_blood_ramp = g
	return _blood_ramp


## A shared 3x3 solid-white texture -- CPUParticles2D modulates it per-particle
## via `color_ramp`, and a tiny flat square reads as a "blood pixel" that
## fits this project's pixel-art style better than the engine's antialiased
## default point primitive.
static func _get_particle_texture() -> ImageTexture:
	if _particle_texture == null:
		var img: Image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 1.0, 1.0))
		_particle_texture = ImageTexture.create_from_image(img)
	return _particle_texture


# --- Ground splat decal ------------------------------------------------------

static func _spawn_splat(container: Node, position: Vector2, big: bool) -> void:
	var idx: int = _acquire_splat_slot(container)
	if idx == -1:
		return
	var splat: Sprite2D = _splat_pool[idx] # safe: _acquire_splat_slot() guarantees a live, valid instance at this index before returning
	splat.global_position = position + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	splat.texture = _splat_textures[randi() % _splat_textures.size()]
	splat.rotation = randf_range(0.0, TAU)
	var s: float = randf_range(1.5, 2.1) if big else randf_range(0.8, 1.3)
	splat.scale = Vector2(s, s)
	splat.modulate = Color(1.0, 1.0, 1.0, 1.0)
	splat.visible = true

	var old_tween: Tween = _splat_tweens[idx]
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var tween: Tween = splat.create_tween() # cosmetic-only Node.create_tween(), matching enemy_animator.gd's own hit-flash convention -- never get_tree().create_tween()
	tween.tween_interval(SPLAT_VISIBLE_SECONDS)
	tween.tween_property(splat, "modulate:a", 0.0, SPLAT_FADE_SECONDS)
	tween.finished.connect(_on_splat_faded.bind(splat))
	_splat_tweens[idx] = tween


static func _on_splat_faded(splat: Sprite2D) -> void:
	if is_instance_valid(splat):
		splat.visible = false


static func _acquire_splat_slot(container: Node) -> int:
	if _splat_pool.size() < MAX_SPLATS:
		var fresh: Sprite2D = _build_splat()
		container.add_child(fresh)
		_splat_pool.append(fresh)
		_splat_tweens.append(null)
		return _splat_pool.size() - 1

	var idx: int = _splat_next_index
	_splat_next_index = (_splat_next_index + 1) % MAX_SPLATS
	# Same "never assign a possibly-freed read into a typed variable"
	# discipline as `_acquire_burst()` above -- see `_splat_pool`'s header.
	if not is_instance_valid(_splat_pool[idx]):
		var fresh: Sprite2D = _build_splat()
		container.add_child(fresh)
		_splat_pool[idx] = fresh
	else:
		var existing: Sprite2D = _splat_pool[idx] # safe: just confirmed valid above
		if existing.get_parent() != container:
			existing.reparent(container) # defensive only -- unlike bursts, splats are never spawned for the player (see spawn_hit()), so every real caller here shares the one `Entities` container
	return idx


static func _build_splat() -> Sprite2D:
	_ensure_splat_textures()
	var s: Sprite2D = Sprite2D.new()
	s.texture = _splat_textures[0]
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_as_relative = false
	s.z_index = SPLAT_Z_INDEX
	s.visible = false
	return s


## Builds a handful of varied, small, procedurally-drawn blood-splat
## textures once (brief: "a few procedurally drawn or tiny generated pixel
## textures, varied") and caches them for the life of the running game --
## cheap (a few dozen pixels each, built at most `SPLAT_TEXTURE_VARIANT_
## COUNT` times ever), so every one of the up-to-`MAX_SPLATS` live decals
## can look different without a texture asset on disk.
static func _ensure_splat_textures() -> void:
	if not _splat_textures.is_empty():
		return
	for variant in range(SPLAT_TEXTURE_VARIANT_COUNT):
		_splat_textures.append(_build_splat_texture(variant))


static func _build_splat_texture(variant: int) -> ImageTexture:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4200 + variant # fixed per variant so the small texture cache is deterministic, not reshuffled every call

	var size: int = SPLAT_TEXTURE_SIZE
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size, size) * 0.5
	var base_radius: float = size * 0.30

	for y in size:
		for x in size:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			var wobble: float = rng.randf_range(-1.6, 1.6)
			if d < base_radius + wobble:
				var t: float = clampf(d / (base_radius + 2.0), 0.0, 1.0)
				var col: Color = COLOR_BLOOD_BRIGHT.lerp(COLOR_BLOOD_DARK, t)
				col.a = clampf(1.0 - t * 0.4, 0.0, 1.0)
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))

	# A few scattered spatter droplets around the main blob so the shape
	# reads as a splash rather than a perfect disc.
	var droplet_count: int = 4 + variant % 3
	for _i in droplet_count:
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = base_radius + rng.randf_range(1.0, 4.0)
		var px: int = int(round(center.x + cos(angle) * dist))
		var py: int = int(round(center.y + sin(angle) * dist))
		if px >= 0 and px < size and py >= 0 and py < size:
			img.set_pixel(px, py, COLOR_BLOOD_DARK)

	return ImageTexture.create_from_image(img)


## Test-only teardown, matching the naming convention every pooled/spawner
## class in this project already uses (`entity_spawner.gd`'s
## `clear_all_for_test()`, `pool.gd`'s `clear_for_test()`). Never called by
## gameplay code -- static state is meant to persist for the run.
static func clear_for_test() -> void:
	for n in _burst_pool:
		if is_instance_valid(n):
			n.queue_free()
	for n in _splat_pool:
		if is_instance_valid(n):
			n.queue_free()
	for t in _splat_tweens:
		if t != null and t.is_valid():
			t.kill()
	_burst_pool.clear()
	_burst_next_index = 0
	_splat_pool.clear()
	_splat_tweens.clear()
	_splat_next_index = 0
