extends RefCounted
class_name AttackSlotManager

## AttackSlotManager (P2.5). Register > Spawning & Waves > "Attack slots
## (C-SLOTS)"; docs/09_Enemy_AI_Architecture.md > "Intent Behaviour
## Defaults" > "Attack slots" bullet, this task's complete owning section:
## "N = floor(2pi x (target radius + attacker body radius + reach) / (2 x
## attacker body radius + 4)), evenly spaced. An enemy claims the nearest
## free slot when within 64 px of the slot ring; an enemy with no free slot
## waits 32 px outside the ring and accrues no stuck time." The 64/32 px
## figures and the separation radius live on EnemyAITuning (a Register
## number belongs in authored data, not a script constant); this file is
## pure geometry and claim bookkeeping.
##
## ## Why a static-var script, not an Autoload
## Multiple EnemyController instances attacking the same target (the Tower,
## or the player) must agree on which slots are already taken -- shared
## state across instances. Registering a new Autoload means editing
## project.godot, which every hard constraint in this task forbids. Godot
## 4.x GDScript `static var` gives one shared table for the lifetime of the
## running process without any scene-tree node or project setting at all;
## `AttackSlotManager.claim_nearest_free_slot(...)` is callable from any
## script that preloads/references this class, exactly like a singleton,
## with none of the project.godot footprint.
##
## ## Test isolation
## `static var` state outlives any single test function -- it is scoped to
## the process, not to a scene tree gdUnit4 tears down between tests. Every
## suite that exercises attack slots must call `clear_all_for_test()` in
## `before_test()`, the same discipline this project already requires for
## EntityRegistry and Pool's own shared state.
##
## ## Dangling claimants
## A claimant freed without releasing its claim (a test that frees an enemy
## node without calling release_claim() first, or a real despawn this task
## does not intercept) would otherwise squat on a slot forever.
## `_reap_stale_claims()` drops any claim whose claimant is no longer
## `is_instance_valid()`, called at the start of every claim/free-slot
## query -- the same "reap on next query" pattern src/core/entity_registry.gd
## already uses for its own dangling-reference case (Phase 02 LEDGER F02-15).
##
## ## Why `target`/`claimant` are typed `Variant`, not `Node2D` (a real bug
## found and fixed during this task's own falsification pass)
## `EnemyController._exit_tree()` calls `release_claim()` against whatever
## `_tower`/`_player`/`_opportunist_target` happened to hold at teardown --
## and gdUnit4's own cross-test node cleanup order is not guaranteed, so
## that reference can already be a FREED instance by the time `_exit_tree()`
## runs. Godot's argument-passing itself rejects a freed instance against a
## statically-typed `Node2D` parameter ("Invalid type... previously freed")
## BEFORE the callee's own body ever runs -- an `is_instance_valid()` guard
## written as the function's first line does not help, because the crash
## happens at the call boundary, not inside the function. `Variant`
## parameters accept the freed reference without that boundary check, so
## the `is_instance_valid()` guards already inside these functions can do
## their job. Reproduced via `tests/unit/stuck_exemption_test.gd`'s own
## multi-entity teardown; see the P2.5 evidence report.

## target (Node2D) -> Dictionary[int slot_index -> Node2D claimant]
static var _claims_by_target: Dictionary = {}


## Test-only teardown. Never called by gameplay code.
static func clear_all_for_test() -> void:
	_claims_by_target.clear()


## N = floor(2pi x (target_radius + attacker_body_radius + reach) /
## (2 x attacker_body_radius + 4)) -- C-SLOTS, transcribed verbatim.
static func compute_slot_count(target_radius_px: float, attacker_body_radius_px: float, reach_px: float) -> int:
	var spacing: float = 2.0 * attacker_body_radius_px + 4.0
	if spacing <= 0.0:
		return 0
	var n: float = TAU * (target_radius_px + attacker_body_radius_px + reach_px) / spacing
	return int(floor(n))


## The ring's radius -- the same quantity C-SLOTS' own formula divides by
## the circumference-per-slot spacing to get N, so it is not a second,
## independently-invented number.
static func ring_radius(target_radius_px: float, attacker_body_radius_px: float, reach_px: float) -> float:
	return target_radius_px + attacker_body_radius_px + reach_px


static func slot_world_position(target: Variant, slot_index: int, slot_count: int, radius: float) -> Vector2:
	if slot_count <= 0 or not is_instance_valid(target):
		return Vector2.ZERO
	var t: Node2D = target as Node2D
	var angle: float = TAU * float(posmod(slot_index, slot_count)) / float(slot_count)
	return t.global_position + Vector2.RIGHT.rotated(angle) * radius


## Typed command: releases any claim `claimant` currently holds against
## `target` (a no-op if it holds none, `target` is null, or `target` has
## already been freed -- see header, "Why target/claimant are typed
## Variant").
static func release_claim(target: Variant, claimant: Variant) -> void:
	if target == null or not is_instance_valid(target) or not _claims_by_target.has(target):
		return
	var slots: Dictionary = _claims_by_target[target]
	for slot_index in slots.keys().duplicate():
		if slots[slot_index] == claimant:
			slots.erase(slot_index)
	if slots.is_empty():
		_claims_by_target.erase(target)
	else:
		_claims_by_target[target] = slots


## The slot index `claimant` currently holds against `target`, or -1.
static func current_claim(target: Variant, claimant: Variant) -> int:
	if target == null or not is_instance_valid(target) or not _claims_by_target.has(target):
		return -1
	var slots: Dictionary = _claims_by_target[target]
	for slot_index in slots.keys():
		if slots[slot_index] == claimant:
			return slot_index
	return -1


## Typed command: claims the free slot angularly nearest `claimant`'s
## current bearing around `target`, releasing any slot it already held
## against this target first (so re-claiming is idempotent, never doubles
## up). Returns the claimed slot index, or -1 if every slot 0..slot_count-1
## is already held by a different, still-valid claimant -- "an enemy with
## no free slot waits 32 px outside the ring" (C-SLOTS).
static func claim_nearest_free_slot(target: Variant, claimant: Variant, slot_count: int, radius: float) -> int:
	if slot_count <= 0 or not is_instance_valid(target) or not is_instance_valid(claimant):
		return -1
	var t: Node2D = target as Node2D
	var c: Node2D = claimant as Node2D
	_reap_stale_claims(target)
	release_claim(target, claimant)
	var slots: Dictionary = _claims_by_target.get(target, {})
	var claimant_bearing: float = (c.global_position - t.global_position).angle()
	var best_slot: int = -1
	var best_angular_delta: float = INF
	for slot_index in slot_count:
		if slots.has(slot_index):
			continue
		var slot_angle: float = TAU * float(slot_index) / float(slot_count)
		var delta: float = absf(wrapf(slot_angle - claimant_bearing, -PI, PI))
		if delta < best_angular_delta:
			best_angular_delta = delta
			best_slot = slot_index
	if best_slot == -1:
		return -1
	slots[best_slot] = claimant
	_claims_by_target[target] = slots
	return best_slot


static func has_free_slot(target: Variant, slot_count: int) -> bool:
	if slot_count <= 0 or target == null or not is_instance_valid(target):
		return false
	_reap_stale_claims(target)
	var slots: Dictionary = _claims_by_target.get(target, {})
	return slots.size() < slot_count


static func claimed_slot_count(target: Variant) -> int:
	if target == null or not is_instance_valid(target) or not _claims_by_target.has(target):
		return 0
	_reap_stale_claims(target)
	return (_claims_by_target.get(target, {}) as Dictionary).size()


static func _reap_stale_claims(target: Variant) -> void:
	if not _claims_by_target.has(target):
		return
	var slots: Dictionary = _claims_by_target[target]
	for slot_index in slots.keys().duplicate():
		var claimant: Variant = slots[slot_index]
		if claimant == null or not is_instance_valid(claimant):
			slots.erase(slot_index)
	if slots.is_empty():
		_claims_by_target.erase(target)
	else:
		_claims_by_target[target] = slots
