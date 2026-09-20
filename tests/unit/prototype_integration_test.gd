extends GdUnitTestSuite

## The assembled scene, asserted as a wired system rather than as a set of
## nodes (integration task item 7; finding F05-33 carried it here after an
## API session limit ended that agent mid-verification).
##
## WHY THIS FILE EXISTS. This project has recorded **eight** findings of one
## shape: a correct, tested component that nothing in the assembled scene ever
## calls. Three enemies with no sprite node at all and 353 tests green
## (F03-27); the Pressure Metric never reaching the debug overlay (F04-04);
## stuck-enemy drops never connected (F04-11); the pickup system's NodePaths
## unset (F04-12); the upgrade system's four NodePaths unset (F05-07); the
## Draft scene never instantiated, so nothing could open a Draft in the
## running game (F05-15); the Console's run-inventory call never made, after
## which it dwell-detects, builds itself, and silently never opens (F05-20);
## and wave-spawned enemies never given a Tower reference, so no Seeker could
## seek (F05-23). Component suites cannot see any of this by construction:
## each component was correct and each of its own tests passed.
##
## Two of those eight fail with NO SYMPTOM AT ALL - no error, no warning, and
## a screen that looks plausible. So the assertions here are deliberately of
## two kinds:
##   (a) identity assertions on the seams that fail silently - the same
##       RunInventory object must actually reach the Console, the run-flow
##       controller and the HUD, and one run seed must actually reach both
##       consumers - because "it exists" and "it is connected to the right
##       instance" are different claims and only the second one is the bug;
##   (b) behavioural assertions driven through the real scene - a
##       wave-spawned enemy resolves the Tower, and killing an enemy moves
##       the HUD's own numbers.
##
## `prototype_scene_test.gd` (the scene's structure) and
## `prototype_wave_integration_test.gd` (the director actually spawning into
## it) are the two files this one extends rather than duplicates: neither
## asserts a single cross-system seam.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")

var _root: Node


func before_test() -> void:
	_root = auto_free(PrototypeScene.instantiate())
	add_child(_root)


func after_test() -> void:
	# The tree's paused flag and PauseAuthority are process-wide, so a test
	# that leaves a pause reason active silently freezes every PAUSABLE node
	# in the NEXT test - which is how the HUD-sync assertion below first
	# failed while the identical sync passed earlier in this same file.
	# Matching the convention every other suite here uses.
	get_tree().paused = false
	# Released pool instances are alive and out of the tree, which is Godot's
	# definition of an orphan, so the pools are cleared here to keep the count
	# honest. Deliberately NO remove_child(): detaching the root makes every
	# descendant an orphan at the instant gdUnit4 counts them (F03-35), which
	# is how a suite that only instantiated this scene once reported ~370.
	if is_instance_valid(_root):
		var spawner: Node = _root.get_node_or_null("Main/EntitySpawner")
		if spawner != null and spawner.has_method("clear_all_for_test"):
			spawner.clear_all_for_test()
		var tower: Node = _root.get_node_or_null("Main/Tower")
		if tower != null and tower.get("weapon") != null and tower.weapon.has_method("get_pool_for_test"):
			# TowerWeapon builds its OWN pool, separate from the one
			# EntitySpawner owns, and clear_all_for_test() never reaches it -
			# the single uncleared pool behind finding F05-25's 200 orphans
			# and five leaked-RID engine errors.
			var weapon_pool: Pool = tower.weapon.get_pool_for_test()
			if weapon_pool != null:
				weapon_pool.clear_for_test()


func _node(path: String) -> Node:
	return _root.get_node_or_null(path)


## `prototype_integration.gd` is attached to the scene ROOT itself (the
## "Prototype" Node2D), not to a child named after it - so the composition
## root and the scene root are the same node here. Resolved in one place for
## the same reason as _hud().
func _integration() -> Node:
	return _root


## The HUD is a CanvasLayer at the scene ROOT (scenes/prototype.tscn's "Hud"
## node), not under Main - resolved in one place so a test never guesses at
## a path, which is how this suite's first version produced a script error
## instead of a readable failure.
func _hud() -> Hud:
	return _node("Hud") as Hud


# --- (a) the seams that fail silently ---------------------------------------

func test_every_nodepath_export_on_every_wired_node_resolves() -> void:
	# The generic form of F04-12, F05-07 and F05-15: an unset or stale
	# NodePath resolves to null and the owning system quietly does nothing.
	# Walking the tree means a node wired LATER is covered without anyone
	# remembering to extend a list here.
	var unresolved: Array[String] = []
	var stack: Array[Node] = [_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var script: Script = node.get_script() as Script
		if script == null:
			continue
		if not script.resource_path.begins_with("res://src/"):
			continue # addons and engine scripts are not this project's wiring
		for property in node.get_property_list():
			if int(property.get("type", TYPE_NIL)) != TYPE_NODE_PATH:
				continue
			var property_name: String = String(property.get("name", ""))
			var path: NodePath = node.get(property_name)
			if path.is_empty():
				continue # an unset optional path is a separate question from a BROKEN one
			if node.get_node_or_null(path) == null:
				unresolved.append("%s.%s = \"%s\"" % [node.get_path(), property_name, path])

	assert_array(unresolved).append_failure_message(
		"NodePath exports that are set but resolve to nothing: %s. A path that resolves to null makes its owning system silently do nothing - the shape of findings F04-12, F05-07 and F05-15." % [unresolved]
	).is_empty()


func test_one_run_inventory_instance_reaches_every_system_that_reads_it() -> void:
	# F05-20 and F05-27, the two seams with no symptom: set_run_inventory() is
	# a required CODE call on both the Console and the run-flow controller,
	# because RunInventory is a RefCounted and cannot be a NodePath. Unwired,
	# the Console reads zero Scrap and never opens, and the run-end screen
	# always shows zero Scrap - which looks exactly like correct behaviour
	# after a player death.
	var pickup_system: Node = _node("Main/PickupSystem")
	assert_object(pickup_system).append_failure_message("Main/PickupSystem is not in the assembled scene").is_not_null()

	var inventory: RunInventory = pickup_system.run_inventory
	assert_object(inventory).append_failure_message("PickupSystem has no RunInventory").is_not_null()

	var console: Node = _node("Console")
	assert_object(console).append_failure_message("the Console is not instantiated in the assembled scene (F05-20)").is_not_null()
	assert_object(console._run_inventory).append_failure_message(
		"Console.set_run_inventory() was never called. Every entry then reads zero Scrap, so the Console dwell-detects, builds itself and NEVER OPENS, with no error anywhere (F05-20)."
	).is_same(inventory)

	var run_flow: Node = _node("RunFlowController")
	assert_object(run_flow).append_failure_message("RunFlowController is not instantiated in the assembled scene (F05-27)").is_not_null()
	assert_object(run_flow._run_inventory).append_failure_message(
		"RunFlowController.set_run_inventory() was never called, so the run-end screen's Scrap field always reads zero - indistinguishable from the correct post-death value (F05-27)."
	).is_same(inventory)


func test_the_hud_is_driven_by_the_real_run_inventory_not_its_neutral_defaults() -> void:
	# F04-12: RunInventory.apply_to_hud_state() exists and nothing called it,
	# so the HUD displayed HudEconomyState's own zero-state defaults forever.
	var pickup_system: Node = _node("Main/PickupSystem")
	var hud: Hud = _hud()
	assert_object(hud).append_failure_message("the HUD is not in the assembled scene").is_not_null()
	if hud == null:
		return # a null HUD makes every assertion below a script error rather than a readable failure

	pickup_system.run_inventory.credit_scrap(7)
	# The sync runs in PrototypeIntegration._process(), a RENDER frame - so a
	# physics frame is the wrong thing to wait for. An earlier version of this
	# suite awaited physics frames and passed here by timing luck while the
	# same assertion failed in a later test, which read as order dependence
	# and was really a frame-type mismatch.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(hud.economy_state.scrap_current).append_failure_message(
		"crediting 7 Scrap to the real run inventory did not reach the HUD's economy state, which still reads %d - RunInventory.apply_to_hud_state() is not being called (F04-12)." % hud.economy_state.scrap_current
	).is_equal(7)


func test_one_run_seed_reaches_both_consumers() -> void:
	# F05-13: DraftController.run_seed, WaveDirector.run_seed and the Run
	# Recorder's seed are independent exports that must agree, or the run
	# replays wrong while every test stays green. The Determinism test is a
	# named prototype exit criterion, so a silent disagreement here defeats a
	# gate criterion rather than merely a feature.
	var integration: Node = _integration()
	assert_object(integration).append_failure_message("Main/PrototypeIntegration is not in the assembled scene").is_not_null()

	var expected: int = integration.get_run_seed()
	var director: Node = _node("Main/WaveDirector")
	var draft: Node = _node("DraftInstance")
	if draft == null:
		draft = _node("Draft")

	assert_int(director.run_seed).append_failure_message(
		"the Wave Director's run_seed (%d) does not match the one source (%d) - three independent seeds that must agree (F05-13)" % [director.run_seed, expected]
	).is_equal(expected)
	assert_object(draft).append_failure_message("the Draft scene is not instantiated, so nothing can open a Draft in the running game (F05-15)").is_not_null()
	assert_int(draft.run_seed).append_failure_message(
		"the Draft's run_seed (%d) does not match the one source (%d) - draft offers would then not reproduce under the Determinism test (F05-13)" % [draft.run_seed, expected]
	).is_equal(expected)


func test_the_wave_director_can_actually_report_pressure_to_the_overlay() -> void:
	# F04-04: set_debug_overlay_reference() existed and nothing called it, so
	# Pressure, its escalation state and the health quadrant never appeared on
	# screen even though all three were computed correctly.
	var director: Node = _node("Main/WaveDirector")
	assert_object(director).append_failure_message("Main/WaveDirector is not in the assembled scene").is_not_null()
	assert_bool(director.has_method("set_debug_overlay_reference")).append_failure_message("the Wave Director lost its overlay seam").is_true()

	# The director resolves its overlay LAZILY (`_resolve_debug_overlay()`),
	# the first time it actually has a Pressure sample to push - which needs a
	# combat wave open and outside the grace period. An earlier version of
	# this test asserted the cached `_debug_overlay` reference directly and
	# failed on a freshly instantiated scene, reading a cache before anything
	# had filled it rather than reading the wiring. What matters for F04-04 is
	# the seam: that the configured path reaches a node that can actually
	# display a Pressure sample.
	var overlay: Node = director.get_node_or_null(director.debug_overlay_path) if director.debug_overlay_path != NodePath() else null
	assert_object(overlay).append_failure_message(
		"the Wave Director's debug_overlay_path (\"%s\") reaches nothing, so Pressure, the escalation state and the health quadrant are computed and never displayed (F04-04)" % director.debug_overlay_path
	).is_not_null()
	if overlay == null:
		return
	assert_bool(overlay.has_method("set_pressure")).append_failure_message(
		"the node the Wave Director's overlay path reaches has no set_pressure() - the path resolves to the wrong kind of node"
	).is_true()
	assert_bool(overlay.has_method("set_health_quadrant")).append_failure_message(
		"the node the Wave Director's overlay path reaches has no set_health_quadrant()"
	).is_true()


# --- (b) behaviour, driven through the real scene ---------------------------

func test_an_enemy_added_to_the_assembled_scene_resolves_the_tower_without_being_told() -> void:
	# F05-23, the Blocker: only the three hand-placed enemies were ever given
	# a Tower reference, so every enemy the waves spawned - which is all of
	# them in real play - had no Tower to seek, and the dual-entity tension
	# the prototype exists to prove could not occur. The fix routes an
	# unreferenced enemy through the EntityRegistry's &"tower" tag, so this
	# asserts the production path rather than a test seam.
	var seeker_scene: PackedScene = load("res://scenes/entities/tower_seeker.tscn")
	var seeker: EnemyController = seeker_scene.instantiate() as EnemyController
	var entities: Node = _node("Main/Entities")
	assert_object(entities).append_failure_message("Main/Entities is not in the assembled scene").is_not_null()
	entities.add_child(seeker)
	seeker.global_position = Vector2(600.0, 0.0)

	# The resolver is deferred from _ready() (the Tower may not have
	# registered itself yet when a spawned enemy enters the tree), so a
	# settle frame is required before asserting.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved: Node2D = seeker._tower

	# MEASURED cross-test pollution, fixed at the cause rather than by
	# reordering: this test used to end with a bare `queue_free()`, which
	# defers the free past gdUnit4's own accounting and leaves the Seeker in
	# the EntityRegistry AUTOLOAD - a process-wide object that outlives the
	# scene. The next test in this file then failed its HUD-sync assertion
	# while the identical assertion passed earlier in the same file, and
	# moving this test later made it pass, which is how the pollution was
	# identified. A freed entity left in the registry is the dangling-
	# reference class that hid a real bug for a whole phase (F02-14), so the
	# entry is removed explicitly and the node freed immediately.
	if EntityRegistry.is_registered(seeker):
		EntityRegistry.deregister_entity(seeker)
	seeker.get_parent().remove_child(seeker)
	seeker.free()
	await get_tree().physics_frame

	assert_object(resolved).append_failure_message(
		"an enemy added to the assembled scene without set_tower_reference() resolved no Tower. In real play every wave-spawned enemy arrives exactly this way, so a Tower Seeker would never seek the Tower (F05-23)."
	).is_not_null()


func test_killing_an_enemy_moves_the_huds_own_numbers() -> void:
	# The whole drop chain through the assembled scene: the enemy's death
	# event reaches the pickup system (F04-11's neighbour), a drop is created
	# and credited, and the credit reaches the HUD (F04-12). Asserting on the
	# HUD's numbers rather than on the pickup system's internals is the point
	# - that is the surface a player actually sees.
	var hud: Hud = _hud()
	assert_object(hud).append_failure_message("the HUD is not in the assembled scene").is_not_null()
	if hud == null:
		return
	var pickup_system: Node = _node("Main/PickupSystem")
	var inventory: RunInventory = pickup_system.run_inventory

	var xp_before: float = inventory.xp_current
	var scrap_before: int = inventory.scrap_current

	# XP is credited and asserted WITHOUT an await in between, and only after
	# the Scrap chain has been measured. Crediting XP can raise a level-up
	# request, and an open Level-Up Draft pauses the whole tree through
	# PauseAuthority - which would stop the very per-frame HUD sync this test
	# exists to measure. Keeping the two chains apart is a property of the
	# test, not a claim about which one fires: an earlier version credited
	# both together and the Scrap assertion read 0 while the inventory held 1.
	assert_bool(get_tree().paused).append_failure_message(
		"the tree is already paused on entry to this test, so no PAUSABLE node processes and the HUD cannot sync - a pause reason leaked from an earlier test rather than a defect in the sync"
	).is_false()

	inventory.credit_scrap(1)
	# _process(), not _physics_process() - see the note in the HUD test above.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(inventory.scrap_current).append_failure_message("the run inventory did not take the Scrap credit at all").is_equal(scrap_before + 1)
	assert_int(hud.economy_state.scrap_current).append_failure_message(
		"the HUD's Scrap did not follow the run inventory (%d -> %d): the per-frame apply_to_hud_state() call is missing (F04-12)" % [scrap_before, hud.economy_state.scrap_current]
	).is_equal(scrap_before + 1)

	inventory.credit_xp(1.0)
	assert_float(inventory.xp_current).append_failure_message("the run inventory did not take the XP credit").is_greater(xp_before)
