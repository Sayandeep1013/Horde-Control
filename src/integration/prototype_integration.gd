extends Node2D
class_name PrototypeIntegration

## PrototypeIntegration (P2.7 integration task). Attached to
## scenes/prototype.tscn's own root. This is the "whichever future task
## next owns scenes/main.tscn" / "the integration task" every P2.1-P2.6
## evidence report named and deferred, for exactly the typed-command wiring
## each of those tasks already built a seam for and could not call itself:
## `EnemyController.set_tower_reference()`, `Hud.set_player_ref()`/
## `set_tower_ref()`, `ThreatFeedback.set_player_ref()`/`set_tower_ref()`/
## `set_camera_ref()`/`set_ducking_node_ref()`, and the new
## `set_audio_pool_ref()` seams this task added to `AutoWeapon`,
## `TowerWeapon`, `EnemyController`, and `Player`.
##
## This script performs ONLY wiring (typed-command calls on already-built
## public seams) -- it contains no gameplay logic of its own and did not, at
## the time this header was written (P2.7), touch any file on THAT task's
## do-not-touch list (src/core/sim_loop.gd, src/core/event_bus.gd,
## src/combat/death_state.gd, src/combat/hitbox.gd,
## src/tower/tower_projectile.gd). A later task (F03-09/F03-22, see
## `_wire_sim_loop()` below) had src/core/sim_loop.gd, src/combat/hitbox.gd,
## and src/combat/player_projectile.gd in ITS OWN write scope and edited
## them; src/core/event_bus.gd, src/combat/death_state.gd, and
## src/tower/tower_projectile.gd remain untouched by every task to date.
##
## ## The AudioDucking placement (see NEXT_SESSION.md's open contradiction
## row, and this task's own evidence report for the full reasoning): this
## script does NOT parent a PROCESS_MODE_ALWAYS AudioDucking node under
## Main (scenes/main.tscn's own gameplay root) -- it only hands the
## already-instanced AudioPool (living under Main, per docs/20 > Scene
## Tree) a plain object REFERENCE to a shared AudioDucking node that lives
## as this wrapper scene's own sibling, outside Main entirely. Docs/20's
## "Nothing under the gameplay root may set PROCESS_MODE_ALWAYS" is about
## what is PARENTED there, not about what a node under it is allowed to
## hold a reference to -- so this does not touch, let alone resolve, the
## open author decision; it simply avoids the conflict for this
## integration scene by never nesting the ducking node inside the
## gameplay root at all.

@export var main_path: NodePath = NodePath("Main")
@export var player_path: NodePath = NodePath("Main/Player")
@export var tower_path: NodePath = NodePath("Main/Tower")
@export var camera_path: NodePath = NodePath("Main/Player/GameCamera")
@export var hud_path: NodePath = NodePath("Hud")
@export var threat_feedback_path: NodePath = NodePath("ThreatFeedbackLayer/Overlay")
@export var ui_sfx_path: NodePath = NodePath("UiSfx")
@export var shared_ducking_path: NodePath = NodePath("SharedAudioDucking")
@export var enemy_paths: Array[NodePath] = []

## F03-09. `sim_loop_path` resolves the real running SimLoop instance
## directly by NodePath (unlike hitbox.gd/player_projectile.gd/
## enemy_controller.gd's own group-lookup seam): this script is the
## composition root's own `Prototype` node, so its `_ready()` already runs
## LAST, after every descendant's (including Main/SimLoop's) -- no sibling-
## order race to defer around. `auto_weapon_path`/`wave_director_path` are
## the two OTHER driven_externally nodes this task can register only from
## here, because their own scripts (src/combat/auto_weapon.gd,
## src/director/wave_director.gd) are outside this task's write scope and
## cannot self-register the way enemy_controller.gd now does.
@export var sim_loop_path: NodePath = NodePath("Main/SimLoop")
@export var auto_weapon_path: NodePath = NodePath("Main/Player/AutoWeapon")
@export var wave_director_path: NodePath = NodePath("Main/WaveDirector")

## Integration task (this pass). PickupSystem/UpgradeSystem's
## NodePath exports are authored directly on their own nodes in
## scenes/prototype.tscn (they are plain static paths within the scene,
## same convention as WaveDirector's own entity_spawner_path/tower_path/
## camera_path/debug_overlay_path); this script only wires what a NodePath
## cannot express -- object references (RunInventory is a RefCounted, not
## a node), Callables (the capacity providers), per-spawn signal
## connections, and the one true run_seed.
##
## D115 (no in-run shop): the Tower Console node/path is removed. The only
## in-run power growth is the Level-Up Draft (`draft_controller_path`).
@export var pickup_system_path: NodePath = NodePath("Main/PickupSystem")
@export var upgrade_system_path: NodePath = NodePath("Main/UpgradeSystem")
@export var draft_controller_path: NodePath = NodePath("DraftInstance")
@export var run_flow_controller_path: NodePath = NodePath("RunFlowController")
@export var debug_overlay_path: NodePath = NodePath("DebugOverlay")

## F05-13: the ONE run seed every keyed-RNG system in the assembled scene
## derives from. `WaveDirector.run_seed` and `DraftController.run_seed` are
## both set FROM this value in `_ready()` below, never authored
## independently in the .tscn -- see `_wire_run_seed()`. The Run Recorder
## is not instantiated anywhere in this scene as of this pass (confirmed:
## no scenes/**/*.tscn and no src/**/*.gd outside its own file and
## draft_controller.gd's comments references it), so it is not part of
## this propagation; named as a limitation in the evidence report rather
## than silently assumed solved.
@export var run_seed: int = 20260920

var _main: Node = null
var _player: Player = null
var _tower: Tower = null
var _camera: GameCamera = null
var _hud: Hud = null
var _threat_feedback: ThreatFeedback = null
var _ui_sfx: UiSfx = null
var _shared_ducking: AudioDucking = null
var _audio_pool: Node = null
var _enemies: Array[EnemyController] = []
var _sim_loop: Node = null
var _auto_weapon: Node = null
var _wave_director: Node = null
var _pickup_system: Node = null
var _upgrade_system: Node = null
var _draft_controller: Node = null
var _run_flow_controller: Node = null
var _debug_overlay: Node = null


func _ready() -> void:
	_main = get_node_or_null(main_path)
	_player = get_node_or_null(player_path) as Player
	_tower = get_node_or_null(tower_path) as Tower
	_camera = get_node_or_null(camera_path) as GameCamera
	_hud = get_node_or_null(hud_path) as Hud
	_threat_feedback = get_node_or_null(threat_feedback_path) as ThreatFeedback
	_ui_sfx = get_node_or_null(ui_sfx_path) as UiSfx
	_shared_ducking = get_node_or_null(shared_ducking_path) as AudioDucking
	_audio_pool = _main.get_node_or_null("Audio") if _main != null else null
	_sim_loop = get_node_or_null(sim_loop_path)
	_auto_weapon = get_node_or_null(auto_weapon_path)
	_wave_director = get_node_or_null(wave_director_path)
	_pickup_system = get_node_or_null(pickup_system_path)
	_upgrade_system = get_node_or_null(upgrade_system_path)
	_draft_controller = get_node_or_null(draft_controller_path)
	_run_flow_controller = get_node_or_null(run_flow_controller_path)
	_debug_overlay = get_node_or_null(debug_overlay_path)

	for path in enemy_paths:
		var enemy: EnemyController = get_node_or_null(path) as EnemyController
		if enemy != null:
			_enemies.append(enemy)

	_apply_meta_loadout()
	_wire_hud()
	_wire_threat_feedback()
	_wire_audio_ducking()
	_wire_audio_pool()
	_wire_enemies()
	_wire_sim_loop()
	_wire_run_seed()
	_wire_pickup_system()
	_wire_run_flow_controller()
	_wire_wave_director_capacity_and_overlay()


## Meta layer core (build brief item 3: "add ONE application seam"). The
## single call site in the whole run: applies the frozen per-run
## `MetaLoadout` (`MetaProgress.build_run_loadout()`, reading whatever Skill
## Tree ranks the Hub already committed) to this scene's live Player/Tower/
## AutoWeapon/RunInventory/DraftController/WaveDirector, through
## `MetaLoadoutApplier` (src/meta/meta_loadout_applier.gd) -- see that file's
## own header for exactly which definitions get duplicated and re-applied.
## Runs BEFORE every other `_wire_*()` call below so nothing else in this
## file's own wiring (HUD text, the capacity-provider Callables, etc.) ever
## observes a pre-loadout value. Safe to call with any argument null (every
## existing test/harness scene that omits a system simply skips that
## system's bonuses); safe to call with an all-zero loadout (the case for
## every scene instantiated without a Hub purchase ever having happened,
## which is every existing test) -- see that file's own header, "Idempotence."
func _apply_meta_loadout() -> void:
	var loadout: MetaLoadout = MetaProgress.build_run_loadout()
	var pickup_system: PickupSystem = _pickup_system as PickupSystem
	var run_inventory: RunInventory = pickup_system.run_inventory if pickup_system != null else null
	MetaLoadoutApplier.apply(loadout, _player, _tower, _auto_weapon as AutoWeapon, run_inventory, _draft_controller as DraftController, _wave_director)
	# D118: an UNLOCK-gated card (Piercing Arrows, Multishot, Tower Volley)
	# never appears in this run's Draft pool unless the achievement that
	# names it is already unlocked -- read once, at run start, same timing
	# as every other meta-layer application above.
	var upgrade_system: UpgradeSystem = _upgrade_system as UpgradeSystem
	if upgrade_system != null:
		upgrade_system.set_unlocked_card_ids(MetaProgress.get_unlocked_card_ids())


## F05-13. Single source of truth: `run_seed` above. Both consumers are
## flipped here, at runtime, never authored independently on their own
## nodes -- the same "composition root owns cross-cutting state" reasoning
## F03-47 already established for `driven_externally`.
func _wire_run_seed() -> void:
	if _wave_director != null:
		_wave_director.run_seed = run_seed
	if _draft_controller != null:
		_draft_controller.run_seed = run_seed


func get_run_seed() -> int:
	return run_seed


## F04-11/F04-12 (fixed): the PickupSystem's own scene-authored NodePaths
## (entity_spawner_path/player_path/player_collector_path) are set directly
## in scenes/prototype.tscn; what remains is connecting each spawned
## enemy's `removed_while_stuck` signal (the hand-placed three here, and
## every Wave-Director-spawned one via `_on_wave_enemy_spawned()` below).
func _wire_pickup_system() -> void:
	if _pickup_system == null:
		return
	for enemy in _enemies:
		_connect_removed_while_stuck(enemy)


func _connect_removed_while_stuck(enemy: EnemyController) -> void:
	if enemy == null or _pickup_system == null:
		return
	if not enemy.removed_while_stuck.is_connected(_pickup_system.handle_enemy_removed_while_stuck):
		enemy.removed_while_stuck.connect(_pickup_system.handle_enemy_removed_while_stuck)


## D115 (no in-run shop): `_wire_console()` (the Tower Console's
## set_run_inventory()/driven_externally/SimLoop step 12
## CONSOLE_CHANNEL_COMPLETION wiring) is REMOVED along with the Console
## itself -- see the class doc addition above. `SimLoop.Step.CONSOLE_
## CHANNEL_COMPLETION` is left as a named step (docs/20 SimLoop order) in
## case a future in-run interface reuses the slot; nothing registers
## against it any more.


## F05-27: `RunFlowController` is instantiated in scenes/prototype.tscn
## with `tower_path`/`wave_director_path` already authored (its own
## defaults are empty NodePaths with no fallback, unlike this script's
## Main/Tower-style defaults, so the .tscn instance sets them explicitly).
## `set_run_inventory()` is the required code call for the same
## RefCounted-cross-reference reason named elsewhere in this file.
## D115 (no in-run shop): `set_console_ref()` no longer exists -- removed
## with the Console.
func _wire_run_flow_controller() -> void:
	if _run_flow_controller == null:
		return
	if _pickup_system != null:
		_run_flow_controller.set_run_inventory(_pickup_system.run_inventory)


## F04-04 (debug overlay) + the P2.9 evidence report's capacity seam ("the
## orchestrator must wire set_player_capacity_provider()/
## set_tower_capacity_provider() ... to the upgrade-aware DPS"). Verified,
## not assumed: CombatStats.get_sheet_dps() never learns about a live
## Rapid Fire/Heavy Rounds/Caliber rank (UpgradeSystem's
## set_damage_multiplier()/set_fire_rate_multiplier() do not re-report to
## CombatStats -- see auto_weapon.gd's/tower_weapon.gd's own
## get_effective_sheet_dps() comments), so the documented CombatStats
## fallback layer would silently under-report Capacity once any upgrade is
## taken; these two Callables bypass that stale layer entirely.
## `debug_overlay_path` is authored directly on the WaveDirector node in
## the .tscn (it already has its own NodePath-based
## `_resolve_debug_overlay()` fallback -- no code call is needed for that
## half of this function's name, kept together because both seams come
## from the same evidence report row).
func _wire_wave_director_capacity_and_overlay() -> void:
	if _wave_director == null:
		return
	if _auto_weapon != null and _auto_weapon.has_method("get_effective_sheet_dps"):
		_wave_director.set_player_capacity_provider(Callable(_auto_weapon, "get_effective_sheet_dps"))
	if _tower != null and _tower.weapon != null:
		_wave_director.set_tower_capacity_provider(Callable(_tower.weapon, "get_effective_sheet_dps"))


## F04-12 / F05-15: `RunInventory.apply_to_hud_state()` exists and nothing
## called it; the HUD's `rerolls_remaining`/`wave_current`/`wave_total`
## fields are populated the same way, every frame, from the real
## DraftController/WaveDirector queries this pass added
## (`get_rerolls_remaining()`, `get_current_wave_display_index()`,
## `get_wave_total_count()`).
func _process(_delta: float) -> void:
	if _hud == null or _hud.economy_state == null:
		return
	if _pickup_system != null and _pickup_system.run_inventory != null:
		_pickup_system.run_inventory.apply_to_hud_state(_hud.economy_state)
	if _draft_controller != null and _draft_controller.has_method("get_rerolls_remaining"):
		_hud.economy_state.rerolls_remaining = _draft_controller.get_rerolls_remaining()
	if _wave_director != null:
		_hud.economy_state.wave_current = _wave_director.get_current_wave_display_index()
		_hud.economy_state.wave_total = _wave_director.get_wave_total_count()


## F05-23 / F03-45: connected in `_wire_sim_loop()` below to
## `WaveDirector.enemy_spawned`. Every enemy the Wave Director spawns --
## which is nearly all of them in real play -- needs the SAME two things
## this script already gives the three hand-placed enemies: registration
## with SimLoop's step 3 (so it stops self-driving outside the
## deterministic per-tick order) and a `removed_while_stuck` connection to
## PickupSystem. The Tower reference itself needs NO wiring here any more
## -- `EnemyController._resolve_tower_reference()` now falls back to
## EntityRegistry (see that file's own header, F05-23), which is why this
## handler is short: the one Blocker-severity gap closed at the component
## level, not the spawn-call-site level.
func _on_wave_enemy_spawned(instance: Node2D, _enemy_id: String, _position: Vector2) -> void:
	if instance is EnemyController:
		var enemy: EnemyController = instance as EnemyController
		enemy.driven_externally = true # picked up by its own deferred SimLoop registration -- see enemy_controller.gd's header
		_connect_removed_while_stuck(enemy)


## F03-09: registers this scene's driven_externally-capable nodes (Player,
## AutoWeapon, the Wave Director, and the three hand-placed enemies) with
## SimLoop's per-step call order.
##
## `driven_externally` is flipped to `true` HERE, at runtime, rather than
## being baked into scenes/player.tscn / scenes/entities/*.tscn themselves
## -- an earlier version of this task set it directly in those shared
## scene files and broke a real set of existing tests (leash_test.gd's
## `test_landing_a_real_hit_on_the_player_resets_the_leash_timer`,
## player_movement_test.gd, player_input_buffer_test.gd) that instantiate
## those scenes DIRECTLY and rely on the scene's own default (false,
## self-driven) to exercise the real `_physics_process()` via `await
## get_tree().physics_frame`, with no SimLoop anywhere in their tree to
## drive them instead. Flipping the flag only on the specific instances
## THIS integration script wires keeps every other instantiation of the
## same scenes (every existing unit test) self-driven exactly as before.
##
## The three hand-placed enemies are flipped and left to register
## THEMSELVES: `enemy_controller.gd`'s own `_ready()` schedules a deferred
## `_resolve_sim_loop_and_register()` call (see that file's header) that
## reads `driven_externally` and registers with SimLoop if it is true.
## Because this whole scene's `_ready()` chain runs bottom-up and
## synchronously before any deferred call fires, setting the flag here --
## in THIS node's own `_ready()`, which runs LAST in that chain, being the
## scene root -- still lands before the enemy's deferred check reads it.
## A Wave-Director-spawned enemy created later (after this integration
## script's own `_ready()` has already returned) is NOT reached by this
## method at all and keeps `driven_externally = false` (self-driven, the
## pre-existing behaviour) -- named as a required seam in the evidence
## report for whichever task next owns entity_spawner.gd/wave_director.gd's
## own spawn call sites. The Tower's own weapon (TowerWeapon) has no
## driven_externally/physics_step seam and src/tower/ is outside this
## task's write scope, so it is not registered either -- also named there.
func _wire_sim_loop() -> void:
	if _sim_loop == null:
		return
	if _player != null:
		_player.driven_externally = true
		_sim_loop.register(SimLoop.Step.PLAYER_MOVEMENT, _player)
	if _auto_weapon != null:
		_auto_weapon.driven_externally = true
		_sim_loop.register(SimLoop.Step.WEAPON_TARGETING_AND_FIRING, _auto_weapon)
	if _wave_director != null:
		_wave_director.driven_externally = true
		_sim_loop.register(SimLoop.Step.WAVE_DIRECTOR, _wave_director)
		if _wave_director.has_signal(&"enemy_spawned") and not _wave_director.enemy_spawned.is_connected(_on_wave_enemy_spawned):
			_wave_director.enemy_spawned.connect(_on_wave_enemy_spawned)
	for enemy in _enemies:
		enemy.driven_externally = true # picked up by its own deferred registration -- see comment above


func _wire_hud() -> void:
	if _hud == null:
		return
	if _player != null:
		_hud.set_player_ref(_player)
	if _tower != null:
		_hud.set_tower_ref(_tower)


func _wire_threat_feedback() -> void:
	if _threat_feedback == null:
		return
	if _player != null:
		_threat_feedback.set_player_ref(_player)
	if _tower != null:
		_threat_feedback.set_tower_ref(_tower)
	if _camera != null:
		_threat_feedback.set_camera_ref(_camera)


## See header, "The AudioDucking placement". `AudioPool.ducking_node` and
## `TowerCuePlayer.ducking_node` are both plain, duck-typed `Node`
## references (audio_pool.gd's and tower_cue_player.gd's own header
## comments: "duck-typed via has_method") -- neither requires the ducking
## node to be its child, only reachable. `ThreatFeedback.set_ducking_node_
## ref()` already exists precisely for this (its own header: "if a single
## global AudioDucking node is later established ... the integration task
## should call this instead of leaving the private default in place").
func _wire_audio_ducking() -> void:
	if _shared_ducking == null:
		return
	if _threat_feedback != null:
		_threat_feedback.set_ducking_node_ref(_shared_ducking)
	if _audio_pool != null:
		_audio_pool.ducking_node = _shared_ducking


func _wire_audio_pool() -> void:
	if _audio_pool == null:
		return
	if _player != null:
		_player.set_audio_pool_ref(_audio_pool)
	if _tower != null and _tower.weapon != null:
		_tower.weapon.set_audio_pool_ref(_audio_pool)
	if _player != null:
		var auto_weapon: Node = _player.get_node_or_null("AutoWeapon")
		if auto_weapon != null and auto_weapon.has_method("set_audio_pool_ref"):
			auto_weapon.set_audio_pool_ref(_audio_pool)
	for enemy in _enemies:
		enemy.set_audio_pool_ref(_audio_pool)


## LEDGER F03-15/F03-26/F03-39/F05-23. F03-26 is closed (F03-39: the Tower
## now registers itself with EntityRegistry under `&"tower"`), so
## `set_tower_reference()` below is no longer the ONLY route a hand-placed
## enemy has to the Tower -- `EnemyController._resolve_tower_reference()`
## would now find it through the registry fallback even if this call were
## removed. It is kept anyway, for the three hand-placed enemies this
## script already holds a direct reference to, because `set_tower_reference
## ()`/`tower_path` are the project's real, typed-command wiring surface
## and this integration task's own brief asks explicitly to "keep
## set_tower_reference()/tower_path working." Wave-Director-spawned
## enemies (F05-23, the Blocker) rely on the EntityRegistry fallback alone
## -- see `_on_wave_enemy_spawned()`, which deliberately does NOT call
## `set_tower_reference()`.
func _wire_enemies() -> void:
	if _tower == null:
		return
	for enemy in _enemies:
		enemy.set_tower_reference(_tower)


func get_player() -> Player:
	return _player


func get_tower() -> Tower:
	return _tower


func get_camera() -> GameCamera:
	return _camera


func get_hud() -> Hud:
	return _hud


func get_threat_feedback() -> ThreatFeedback:
	return _threat_feedback


func get_ui_sfx() -> UiSfx:
	return _ui_sfx


func get_shared_ducking() -> AudioDucking:
	return _shared_ducking


func get_audio_pool() -> Node:
	return _audio_pool


func get_enemies() -> Array[EnemyController]:
	return _enemies


func get_sim_loop() -> Node:
	return _sim_loop
