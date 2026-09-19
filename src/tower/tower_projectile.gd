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

## Collision radius. A framework/rendering constant, like death_state.gd's
## own placeholder max_hp/hitbox.gd's placeholder damage (see those files'
## headers for the same carve-out) -- not a Provisional Values Register
## number: no Register row sizes a generic projectile's own hit-detection
## circle, only entity body/hurtbox radii and weapon damage/range/speed,
## all of which ARE read from the Register via base_weapon.tres. Named
## explicitly rather than silently treated as a balance number.
const COLLISION_RADIUS_PX: float = 6.0

signal hit_landed(hurtbox: Hurtbox, damage: float, source: Variant)
signal expired(projectile: TowerProjectile)

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _source: Variant = null
var _deadline: float = 0.0
var _active: bool = false

## Test-injectable SimClock reference, matching this project's convention.
var _clock: Node = null


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
	global_position += _velocity * delta
	if _now() >= _deadline:
		_expire()


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if not (area is Hurtbox):
		return
	var hurtbox: Hurtbox = area as Hurtbox
	var accepted: bool = hurtbox.receive_hit(self, _damage, _source)
	if accepted:
		hit_landed.emit(hurtbox, _damage, _source)
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
