extends Area2D
class_name TowerProjectile

## TowerProjectile (P2.4). Provisional Values Register > Tower row: "Tower
## base weapon: 20 dmg x 1.25 shots/s (25 DPS), range 480 px, projectile
## 900 px/s" -- speed/damage are handed in per-shot by launch(), read by
## tower_weapon.gd from data/tower/base_weapon.tres, never literals here.
##
## Collision layer/mask: docs/20_Technical_Architecture.md > Collision
## Layers table, row 6 "TowerProjectile | Tower projectile Area2D | 9, 4,
## 15" -- CollisionLayers.LAYER_TOWER_PROJECTILE /
## CollisionLayers.MASK_TOWER_PROJECTILE (EnemyHurtbox, World, ArenaBounds).
##
## ## Immediate resolution, not SimLoop's (unconsumed) hit queue
## docs/20 states area overlap callbacks "must only enqueue a hit record
## ... for step 7 to process, never resolve damage directly," but the
## existing P1.5 framework this task builds on does not actually follow
## that for its one shipped attacker: src/combat/hitbox.gd's own
## _on_area_entered() calls `hurtbox.receive_hit()` directly, and
## src/core/sim_loop.gd's _step_07_hit_queue_resolution() sorts and then
## CLEARS `_hit_queue` without resolving anything from it ("Future damage
## resolution (combat system) consumes _hit_queue here" -- not yet true).
## This file follows the same precedent hitbox.gd already established
## rather than being the first attacker in this codebase to route through
## a queue nothing drains -- named here as an inherited framework gap, not
## something this task introduces. See the P2.4 evidence report.
##
## ## Projectile Orphans (docs/20 > "Animation, Hitbox, and State Cleanup
## Rules" > "Projectile Orphans"): "If the entity that fired a projectile
## dies, the projectile continues, but its damage source reference is
## resolved by value at the time of firing, not by reference to the dead
## entity." `launch()` takes `source` as a StringName (a value, e.g.
## `&"tower"`), never a live Node reference to the firing Tower -- so a
## freed/destroyed Tower can never leave a dangling reference on an
## in-flight projectile, structurally, not by caller discipline alone.
##
## Pool-compatible: joins the `pool_body` group (src/core/pool.gd's
## discovery convention) so a Pool reusing this instance restores its
## baseline collision_layer/collision_mask on every acquire(), exactly like
## every other pooled combat node in this project.
##
## ## The intersect_ray sweep (LEDGER F03-17 -- fixed)
## docs/20 > "Physics & Collisions": "Fast projectiles must not tunnel:
## PhysicsDirectSpaceState2D.intersect_ray (with collide_with_areas = true)
## sweeps from the projectile's previous position to its current position
## whenever its travel in a single physics tick exceeds 12 pixels. At 60
## physics ticks per second this is every projectile defined in the
## prototype -- even the Tower's slowest, at 900 px/s, covers 15 px per
## tick." This file previously advanced by a bare `global_position +=
## _velocity * delta` and relied solely on Godot's own discrete
## `area_entered`/`body_entered` (a per-tick check against the END-of-step
## transform only), which is exactly the tunnelling gap docs/20 describes --
## at 900 px/s (15 px/tick) this projectile's own travel exceeds the 12 px
## threshold on literally every tick it is active, the same as
## `src/combat/player_projectile.gd`'s 1000 px/s shot. `_sweep_and_resolve()`
## below is read from, and mirrors, `player_projectile.gd`'s own
## `_sweep_and_resolve()` (that file's header names this exact gap as a
## "cross-task/ledger candidate" left for whoever next owns this file --
## this task is that owner). `_on_area_entered()`/`_on_body_entered()` are
## kept unchanged as the fallback for the (not reached at this weapon's
## speed, but general-purpose) case where a single tick's travel is <= 12
## px. Damage, lifetime and pooling behaviour are unchanged: the sweep only
## changes HOW a hit is detected, never what happens once one is.

## Collision radius. A framework/rendering constant, like death_state.gd's
## own placeholder max_hp/hitbox.gd's placeholder damage (see those files'
## headers for the same carve-out) -- not a Provisional Values Register
## number: no Register row sizes a generic projectile's own hit-detection
## circle, only entity body/hurtbox radii and weapon damage/range/speed,
## all of which ARE read from the Register via base_weapon.tres. Named
## explicitly rather than silently treated as a balance number.
const COLLISION_RADIUS_PX: float = 6.0

## docs/20 > Physics & Collisions: the sweep threshold, verbatim ("exceeds
## 12 pixels"). A framework/architecture constant, not a Register number --
## same constant, same citation, as player_projectile.gd's own
## SWEEP_THRESHOLD_PX.
const SWEEP_THRESHOLD_PX: float = 12.0

signal hit_landed(hurtbox: Hurtbox, damage: float, source: Variant)
signal expired(projectile: TowerProjectile)

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _source: Variant = null
var _deadline: float = 0.0
var _active: bool = false

## Test-injectable SimClock reference, matching this project's convention.
var _clock: Node = null

## Integration task (F03-46 -- fixed): reference to the running SimLoop
## instance, resolved the same deferred, group-lookup way as
## src/combat/player_projectile.gd's own `_sim_loop` field (that file's
## header explains why the lookup must be deferred rather than run inline
## in `_ready()`, and why hitbox.gd's/player_projectile.gd's own fallback
## to immediate resolution is kept when no SimLoop is reachable -- every
## isolated unit test in this file's own suite). Test-injectable via
## `set_sim_loop_for_test()`.
var _sim_loop: Node = null


func _ready() -> void:
	add_to_group(&"pool_body")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = CollisionLayers.LAYER_TOWER_PROJECTILE
	collision_mask = CollisionLayers.MASK_TOWER_PROJECTILE
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
	visible = false
	call_deferred(&"_resolve_sim_loop_for_ready")


func _resolve_sim_loop_for_ready() -> void:
	if _sim_loop == null and is_inside_tree():
		_sim_loop = get_tree().get_first_node_in_group(&"sim_loop")


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
## not fly forever).
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
## header, "The intersect_ray sweep"). Godot's own `area_entered` signal is
## a discrete per-tick check against the END-of-step transform, not a
## continuous sweep -- without this, a projectile whose single-tick travel
## exceeds a target hurtbox's own radius could cross it entirely between two
## physics steps and never trigger an overlap at all. Mirrors
## player_projectile.gd's `_sweep_and_resolve()` exactly. Returns true if
## this call already resolved the projectile (a hit landed, or it struck
## terrain) and the caller must not also apply `next_position` uncontested
## -- false if the sweep found nothing along the segment and normal movement
## should proceed.
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


## F03-46 (fixed): routes through SimLoop.enqueue_hit() when a real SimLoop
## is reachable -- the assembled game, always, once the Tower fires a shot
## -- falling back to the original immediate hurtbox.receive_hit() call
## otherwise (every isolated unit test in this file's own suite, none of
## which build a SimLoop). Mirrors src/combat/player_projectile.gd's own
## `_deliver_hit()` exactly; shared by both call sites below so the routing
## decision lives in exactly one place.
func _deliver_hit(hurtbox: Hurtbox) -> void:
	if _sim_loop != null and _sim_loop.has_method(&"enqueue_hit"):
		var attacker_serial: int = _sim_loop.get_combat_serial(_source)
		var target_serial: int = _sim_loop.get_combat_serial(hurtbox.get_parent())
		_sim_loop.enqueue_hit(attacker_serial, target_serial, _damage, _source, hurtbox, self, func() -> void: hit_landed.emit(hurtbox, _damage, _source))
		return
	var accepted: bool = hurtbox.receive_hit(self, _damage, _source)
	if accepted:
		hit_landed.emit(hurtbox, _damage, _source)


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if not (area is Hurtbox):
		return
	var hurtbox: Hurtbox = area as Hurtbox
	_deliver_hit(hurtbox)
	_expire() # no piercing: one target per shot


## World (4) and ArenaBounds (15) are both in MASK_TOWER_PROJECTILE, but
## both are static PhysicsBody2D layers, not Area2D -- a PhysicsBody
## overlap fires body_entered, never area_entered. Without this handler the
## mask would still correctly exclude the projectile from ever damaging
## player/Tower bodies, but the projectile would silently pass through
## walls instead of stopping at them. A projectile that hits terrain
## simply expires in place (no damage to apply -- terrain has no Hurtbox).
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
## monitoring), matching hitbox.gd/hurtbox.gd's own reset_for_reuse()
## convention.
func reset_for_reuse() -> void:
	_active = false
	monitoring = false
	visible = false
