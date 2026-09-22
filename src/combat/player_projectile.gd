extends Area2D
class_name PlayerProjectile

## PlayerProjectile (P2.3). Provisional Values Register > Player & Weapons >
## "Handgun (Starting Weapon)": "10 dmg/shot, 2 shots/s (20 DPS), range 260
## px, nearest re-picked every shot, projectile 1000 px/s" -- damage/speed
## are handed in per-shot by launch(), read by auto_weapon.gd from
## data/weapons/handgun.tres, never literals here. Mirrors
## src/tower/tower_projectile.gd's shape (P2.4 precedent, PLAN.md's own
## instruction to read and mirror it), with two deliberate departures named
## below: the intersect_ray sweep, and a real Sprite2D visual.
##
## Collision layer/mask: docs/20_Technical_Architecture.md > Collision
## Layers table, row 5 "PlayerProjectile | Player projectile Area2D | 9, 4,
## 15" -- CollisionLayers.LAYER_PLAYER_PROJECTILE /
## CollisionLayers.MASK_PLAYER_PROJECTILE (EnemyHurtbox, World, ArenaBounds).
##
## ## Readability (Register > Interfaces > "Readability"; docs/20 > Scene
## Tree draw order): "player projectiles 30 (rendered at <= 70% opacity)".
## Set directly on this node in _ready(): z_index = 30, modulate.a = 0.7.
## Unlike tower_projectile.gd (which has no Sprite2D at all -- Tower's own
## evidence report never had to cite an opacity row, since none exists for
## Tower projectiles), this task's own binding sources name the player-
## projectile opacity row explicitly, so a real Sprite2D is added rather
## than leaving the opacity value on a node nothing draws through (the
## `projectile_texture` export's own comment, a few lines down, has the
## current asset and why the art session swapped it).
##
## ## Departure from tower_projectile.gd: the intersect_ray sweep IS
## implemented here
## docs/20 > "Physics & Collisions": "Fast projectiles must not tunnel:
## PhysicsDirectSpaceState2D.intersect_ray (with collide_with_areas = true)
## sweeps from the projectile's previous position to its current position
## whenever its travel in a single physics tick exceeds 12 pixels. At 60
## physics ticks per second this is every projectile defined in the
## prototype -- even the Tower's slowest, at 900 px/s, covers 15 px per
## tick. A projectile enqueues at most one hit and then deactivates." This
## weapon's projectile travels at 1000 px/s = 16.67 px/tick, so the sweep
## branch below runs on literally every tick this projectile is active, not
## as a rare fallback. `tower_projectile.gd` (the precedent this task was
## told to mirror) does NOT implement this sweep -- it relies solely on the
## `area_entered` signal, which is Godot's own discrete per-tick overlap
## check against the END-of-step transform, not a continuous sweep. That
## gap exists in tower_projectile.gd too (900 px/s also exceeds 12 px/tick)
## but is outside this task's write scope (src/tower/) to fix; named here
## and in the evidence report as a cross-task/ledger candidate, not silently
## copied forward into this file. `_on_area_entered()` / `_on_body_entered()`
## are kept as a fallback for the (never reached at this weapon's speed, but
## general-purpose) case where a single tick's travel is <= 12 px.
##
## ## Projectile Orphans (docs/20 > "Animation, Hitbox, and State Cleanup
## Rules" > "Projectile Orphans"): "If the entity that fired a projectile
## dies, the projectile continues, but its damage source reference is
## resolved by value at the time of firing, not by reference to the dead
## entity." `launch()` takes `source` as a StringName (a value, e.g.
## `&"player"`), never a live Node reference to the firing Player -- so a
## freed/destroyed Player can never leave a dangling reference on an
## in-flight projectile, structurally, not by caller discipline alone.
##
## ## F03-22 fix: hits now route through SimLoop's hit queue when possible
## docs/20 states an Area2D overlap callback "must only enqueue a hit
## record ... for step 7 to process, never resolve damage directly." Both
## `_sweep_and_resolve()` and `_on_area_entered()` now call
## `SimLoop.enqueue_hit()` (via `_deliver_hit()`, below) whenever a real
## SimLoop instance is reachable -- the assembled game, always, once one
## fires a shot. When no SimLoop is reachable (every isolated unit test in
## player_projectile_test.gd, none of which build one), both fall back to
## the ORIGINAL immediate `hurtbox.receive_hit()` call so that suite's own
## coverage of the sweep, the Projectile Orphans rule, lifetime expiry, and
## no-piercing keeps exercising this file's mechanics unchanged. See
## src/combat/hitbox.gd's own header for the identical fallback reasoning
## and `_sim_loop`'s field comment below for how the reference is resolved.
## `src/tower/tower_projectile.gd` still resolves damage directly and
## unconditionally -- src/tower/ is outside this task's write scope, named
## as a required seam in the evidence report.
##
## ## SimLoop / driven_externally (this task's own seam, NOT wired to a
## real registration anywhere in-scope)
## `driven_externally` (default false) and the public `physics_step(delta)`
## method below mirror player.gd's/enemy_controller.gd's/auto_weapon.gd's
## own convention exactly, so a future task can flip this projectile's
## MOVEMENT over to SimLoop's step 5 with a one-line change at its one
## construction site. That construction site is
## `src/combat/auto_weapon.gd`'s `_projectile_factory()` (`PlayerProjectile.
## new()`), outside this task's write scope -- nothing in-scope ever
## constructs a projectile with `driven_externally` already true, so this
## projectile's movement stays self-driven via `_physics_process()` in
## every configuration this task can reach. Default stays false rather
## than true precisely so every existing player_projectile_test.gd test
## (none of which registers a projectile with a SimLoop) keeps
## self-driving exactly as before. Named as a required seam in the
## evidence report. This gap does NOT affect the F03-22 damage-resolution
## fix above, which is wired independently of `driven_externally`.
##
## Pool-compatible: joins the `pool_body` group (src/core/pool.gd's
## discovery convention) so a Pool reusing this instance restores its
## baseline collision_layer/collision_mask on every acquire().

## Collision radius. A framework/rendering constant, like tower_projectile.
## gd's own COLLISION_RADIUS_PX (see its header for the same carve-out) --
## not a Provisional Values Register number: no Register row sizes a
## generic projectile's own hit-detection circle, only entity body/hurtbox
## radii and weapon damage/range/speed, all of which ARE read from the
## Register via handgun.tres.
const COLLISION_RADIUS_PX: float = 6.0

## Readability (Register > Interfaces > "Readability"): "player projectiles
## ... 30 (rendered at <= 70% opacity)". 30 is the exact z_index; 0.7 is the
## ceiling itself, taken as the value rather than an arbitrary point under
## it, since the Register states no other figure to aim for.
const DRAW_Z_INDEX: int = 30
const MAX_OPACITY: float = 0.7

## docs/20 > Physics & Collisions: the sweep threshold, verbatim ("exceeds
## 12 pixels"). A framework/architecture constant, not a Register number.
const SWEEP_THRESHOLD_PX: float = 12.0

## Integration task, docs/25_Asset_Pipeline.md: the CC0 asset replacing the
## generated placeholder sprite this field used to be a bare `const`
## pointing at. An `@export` (D99: "asset paths ... never a hardcoded path
## buried in a function") rather than a `const`, so a scene or a future
## weapon evolution can swap it without touching this script -- the default
## below is only this field's fallback value, read the same way whether the
## projectile is scene-instanced or built via `.new()` (as src/combat/auto_
## weapon.gd's pooled factory does; export defaults apply either way).
##
## Art session: swapped from the flat Kenney icon to the Tiny Swords Arrow
## (assets/sprite_frames/arrow_projectile.tres, an AtlasTexture selecting
## the fully-extended "in-flight" half of Arrow.png -- see that resource's
## own header comment for why frame 0, not frame 1). `_ready()` below sizes
## and filters it, and adds a faint trailing ghost sprite behind it.
@export var projectile_texture: Texture2D = preload("res://assets/sprite_frames/arrow_projectile.tres")

## Cosmetic-only constants (not Provisional Values Register numbers -- the
## Register sizes the collision circle above, never a rendered sprite's
## scale): how big the arrow art renders relative to Arrow.png's own 64x64
## frame, and how far behind it the faint trail ghost sits.
const PROJECTILE_ART_SCALE: float = 0.6
const TRAIL_OFFSET_PX: float = 10.0

## See this file's header, "SimLoop / driven_externally". Defaults false
## (self-driven) -- no in-scope construction site ever flips this true
## today; kept for a future task to wire (see header).
@export var driven_externally: bool = false

signal hit_landed(hurtbox: Hurtbox, damage: float, source: Variant)
signal expired(projectile: PlayerProjectile)

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _source: Variant = null
var _deadline: float = 0.0
var _active: bool = false

## Test-injectable SimClock reference, matching this project's convention.
var _clock: Node = null

## F03-22: reference to the running SimLoop instance, resolved the same
## deferred, group-lookup way as src/combat/hitbox.gd's own `_sim_loop`
## field -- see that file's header for why the lookup must be deferred
## rather than run inline in _ready(). Test-injectable via
## set_sim_loop_for_test().
var _sim_loop: Node = null


func _ready() -> void:
	add_to_group(&"pool_body")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = DRAW_Z_INDEX
	modulate.a = MAX_OPACITY
	collision_layer = CollisionLayers.LAYER_PLAYER_PROJECTILE
	collision_mask = CollisionLayers.MASK_PLAYER_PROJECTILE
	monitoring = false
	monitorable = false # a projectile is never itself a valid hit target
	_clock = SimClock
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLLISION_RADIUS_PX
	shape.shape = circle
	shape.name = "CollisionShape2D"
	add_child(shape)

	var sprite := Sprite2D.new()
	sprite.texture = projectile_texture
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(PROJECTILE_ART_SCALE, PROJECTILE_ART_SCALE)
	_add_trail_sprite(sprite) # added first so it draws BEHIND the main sprite below
	add_child(sprite)

	visible = false
	call_deferred(&"_resolve_sim_loop_for_ready")


func _resolve_sim_loop_for_ready() -> void:
	if _sim_loop == null and is_inside_tree():
		_sim_loop = get_tree().get_first_node_in_group(&"sim_loop")


## Art session, cosmetic-only: a faint, static ghost of the arrow offset
## behind it along the projectile's own -X (this Area2D's `rotation` already
## points +X toward `_velocity`, per launch() below, so a fixed local offset
## reads as "behind" regardless of travel direction). No per-frame update --
## a real motion-trail (GPUParticles2D, or per-tick repositioning) is not
## needed for a 1000 px/s shot with a ~0.29s lifetime; a single dimmer,
## slightly smaller copy already reads as a soft streak at that speed.
func _add_trail_sprite(main_sprite: Sprite2D) -> void:
	var trail := Sprite2D.new()
	trail.name = "Trail"
	trail.texture = main_sprite.texture
	trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trail.scale = main_sprite.scale * 0.75
	trail.modulate = Color(1.0, 1.0, 1.0, 0.25)
	trail.position = Vector2(-TRAIL_OFFSET_PX, 0.0)
	add_child(trail)


func set_sim_loop_for_test(loop: Node) -> void:
	_sim_loop = loop


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func _now() -> float:
	return _clock.now if _clock != null else 0.0


## Typed command: fires this (already-pooled) projectile from `origin`
## toward `direction_normalized * speed`, dealing `damage` to the first
## Hurtbox it overlaps, self-expiring after `lifetime_seconds` of
## simulation time even if it never hits anything (out-of-range shots do
## not fly forever). `source` is a value (StringName), never a live Node
## reference -- see this file's header, "Projectile Orphans."
func launch(origin: Vector2, velocity: Vector2, damage: float, source: Variant, lifetime_seconds: float) -> void:
	global_position = origin
	rotation = velocity.angle()
	_velocity = velocity
	_damage = damage
	_source = source
	_deadline = _now() + lifetime_seconds
	_active = true
	visible = true
	set_deferred("monitoring", true)


func _physics_process(delta: float) -> void:
	if driven_externally:
		return
	physics_step(delta)


## The per-tick logic this file's own movement/sweep loop runs. Public, and
## gated by `driven_externally` above, so a future SimLoop integration can
## call it directly once that field is set true at construction (see this
## file's header, "SimLoop / driven_externally") -- exactly the same seam
## shape as player.gd/enemy_controller.gd/auto_weapon.gd already use.
func physics_step(delta: float) -> void:
	if not _active:
		return
	var previous_position: Vector2 = global_position
	var travel: Vector2 = _velocity * delta
	var next_position: Vector2 = previous_position + travel

	if travel.length() > SWEEP_THRESHOLD_PX:
		if _sweep_and_resolve(previous_position, next_position):
			return # a hit or terrain strike already expired this projectile

	global_position = next_position
	if _now() >= _deadline:
		_expire()


## docs/20 > "Physics & Collisions" (transcribed in full in this file's
## header). Godot's own `area_entered` signal is a discrete per-tick check
## against the END-of-step transform, not a continuous sweep -- without
## this, a projectile whose single-tick travel exceeds a target hurtbox's
## own radius could cross it entirely between two physics steps and never
## trigger an overlap at all. Returns true if this call already resolved
## the projectile (a hit landed, or it struck terrain) and the caller must
## not also apply `next_position` uncontested -- false if the sweep found
## nothing along the segment and normal movement should proceed.
func _sweep_and_resolve(from: Vector2, to: Vector2) -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = collision_mask
	var excluded: Array[RID] = [get_rid()]
	query.exclude = excluded

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return false

	var collider: Object = result.get("collider")
	var hit_position: Variant = result.get("position", to)
	global_position = hit_position as Vector2

	if collider is Hurtbox:
		_deliver_hit(collider as Hurtbox)
	# Either a Hurtbox hit (no piercing -- one target per shot) or terrain
	# (World/ArenaBounds -- both static PhysicsBody2D layers in this mask,
	# same reasoning as _on_body_entered() below): either way the shot ends.
	_expire()
	return true


## F03-22: routes through SimLoop.enqueue_hit() when a real SimLoop is
## reachable, falling back to the original immediate hurtbox.receive_hit()
## call otherwise -- see this file's header for the full reasoning. Shared
## by both call sites (the sweep and the discrete area_entered fallback) so
## the routing decision is made in exactly one place.
func _deliver_hit(hurtbox: Hurtbox) -> void:
	if _sim_loop != null and _sim_loop.has_method(&"enqueue_hit"):
		var attacker_serial: int = _sim_loop.get_combat_serial(_source)
		var target_serial: int = _sim_loop.get_combat_serial(hurtbox.get_parent())
		_sim_loop.enqueue_hit(attacker_serial, target_serial, _damage, _source, hurtbox, self, func() -> void: hit_landed.emit(hurtbox, _damage, _source))
		return
	var accepted: bool = hurtbox.receive_hit(self, _damage, _source)
	if accepted:
		hit_landed.emit(hurtbox, _damage, _source)


## Fallback for the general-purpose (never reached at this weapon's 1000
## px/s, since every tick's travel exceeds SWEEP_THRESHOLD_PX) case where a
## single tick's travel does not trigger the sweep above.
func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if not (area is Hurtbox):
		return
	var hurtbox: Hurtbox = area as Hurtbox
	_deliver_hit(hurtbox)
	_expire() # no piercing: one target per shot
	_expire() # no piercing: one target per shot


## World (4) and ArenaBounds (15) are both in MASK_PLAYER_PROJECTILE, but
## both are static PhysicsBody2D layers, not Area2D -- a PhysicsBody
## overlap fires body_entered, never area_entered. Fallback for the same
## general-purpose small-travel case as _on_area_entered() above; at this
## weapon's speed the sweep already stops the projectile at terrain before
## this signal would fire.
func _on_body_entered(_body: Node) -> void:
	if not _active:
		return
	_expire()


func _expire() -> void:
	if not _active:
		return
	_active = false
	set_deferred("monitoring", false)
	visible = false
	expired.emit(self)


## Called after Pool.acquire() has already restored the baseline
## collision_layer/collision_mask from the `pool_body` group snapshot --
## resets what Pool does not know about (this file's own _active flag and
## monitoring), matching tower_projectile.gd's own reset_for_reuse()
## convention.
func reset_for_reuse() -> void:
	_active = false
	monitoring = false
	visible = false
