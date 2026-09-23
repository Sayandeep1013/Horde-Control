extends GdUnitTestSuite

## MetaLoadoutApplier tests (Meta layer core, build brief item 6: "loadout
## application for at least four node kinds on real runtime copies (and the
## .tres unchanged afterwards); Second Wind triggers once"). Every fixture
## below instantiates the REAL scenes/player.tscn / scenes/tower.tscn (not a
## logic-only stand-in), matching this project's own established convention
## for proving a real Resource/scene wiring rather than an assumed one (see
## tests/unit/player_scene_test.gd's and tower_health_recovery_test.gd's own
## headers). Every test re-reads the SAME preloaded `data/**/*.tres` constant
## the real game preloads, so a passing "unchanged afterwards" assertion is
## checking the actual shared singleton Resource instance, not a copy.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const PlayerDefinitionResource: PlayerDefinition = preload("res://data/player/prototype.tres")
const HandgunResource: WeaponDefinition = preload("res://data/weapons/handgun.tres")
const TowerDefinitionResource: TowerDefinition = preload("res://data/tower/base.tres")

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)


func _make_player() -> Player:
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	player.set_registry_for_test(_registry)
	add_child(player)
	return player


func _make_tower() -> Tower:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	tower.set_registry_for_test(_registry)
	add_child(tower)
	return tower


func _loadout() -> MetaLoadout:
	return MetaLoadout.new()


# --- Player branch: max health, move speed, weapon damage --------------------

## FALSIFICATION (named in the report): temporarily gating the max_health
## mutation in `MetaLoadoutApplier._apply_player()` behind `if false and ...`
## made this test fail (expected 120, `death_state.max_hp` stayed 100).
## Reverted after confirming the failure.
func test_player_max_health_bonus_applies_to_a_runtime_copy_and_leaves_the_tres_untouched() -> void:
	var original_max_health: int = PlayerDefinitionResource.max_health
	var player: Player = _make_player()
	var expected: int = int(round(float(original_max_health) * 1.20))

	var loadout: MetaLoadout = _loadout()
	loadout.player_max_health_bonus = 0.20
	MetaLoadoutApplier.apply(loadout, player, null, null, null, null, null)

	assert_float(player.death_state.max_hp).append_failure_message("Vitality's +20%% should raise the runtime copy's max_hp").is_equal_approx(float(expected), 0.01)
	assert_int(PlayerDefinitionResource.max_health).append_failure_message("the authored .tres must never be mutated").is_equal(original_max_health)
	assert_bool(player.definition == PlayerDefinitionResource).append_failure_message("player.definition must now point at a DUPLICATE, not the shared preloaded resource").is_false()


func test_player_move_speed_bonus_applies_without_touching_the_tres() -> void:
	var original_speed: float = PlayerDefinitionResource.base_speed_px_per_second
	var player: Player = _make_player()

	var loadout: MetaLoadout = _loadout()
	loadout.player_move_speed_bonus = 0.04
	MetaLoadoutApplier.apply(loadout, player, null, null, null, null, null)

	assert_float(player.definition.base_speed_px_per_second).is_equal_approx(original_speed * 1.04, 0.01)
	assert_float(PlayerDefinitionResource.base_speed_px_per_second).is_equal(original_speed)


func test_player_weapon_damage_bonus_applies_to_the_effective_damage_and_leaves_the_tres_untouched() -> void:
	var original_damage: int = HandgunResource.damage_band.value # BandedValue.value is int (src/data/banded_value.gd)
	var player: Player = _make_player()
	var weapon: AutoWeapon = player.get_node("AutoWeapon") as AutoWeapon
	await get_tree().physics_frame # AutoWeapon._ready() (sibling order) configures from its own default definition first

	var loadout: MetaLoadout = _loadout()
	loadout.player_weapon_damage_bonus = 0.08
	MetaLoadoutApplier.apply(loadout, player, null, weapon, null, null, null)

	# MetaLoadoutApplier rounds the mutated int damage_band.value (10 * 1.08 =
	# 10.8 -> rounds to 11) rather than truncating -- the effective damage is
	# therefore derived from that ROUNDED int, not the exact fractional bonus.
	var expected_rounded_damage: int = int(round(float(original_damage) * 1.08))
	assert_float(weapon.get_effective_damage_per_shot()).is_equal_approx(float(expected_rounded_damage), 0.01)
	assert_int(HandgunResource.damage_band.value).append_failure_message("the shared handgun.tres damage_band must never be mutated").is_equal(original_damage)


# --- Tower branch: max health, repair price ----------------------------------

func test_tower_max_health_bonus_applies_and_leaves_the_tres_untouched() -> void:
	var original_max_health: int = TowerDefinitionResource.max_health_and_shield_fraction.maximum_health
	var tower: Tower = _make_tower()

	var loadout: MetaLoadout = _loadout()
	loadout.tower_max_health_bonus = 0.10
	MetaLoadoutApplier.apply(loadout, null, tower, null, null, null, null)

	var expected: float = float(original_max_health) * 1.10
	assert_float(tower.health.max_health).is_equal_approx(expected, 1.0)
	assert_int(TowerDefinitionResource.max_health_and_shield_fraction.maximum_health).append_failure_message("the shared base.tres must never be mutated").is_equal(original_max_health)


func test_masons_kit_reduces_the_repair_price_read_live_by_the_console() -> void:
	var original_cost: int = TowerDefinitionResource.repair_price.scrap_cost
	var tower: Tower = _make_tower()

	var loadout: MetaLoadout = _loadout()
	loadout.repair_price_reduction = 0.15
	MetaLoadoutApplier.apply(loadout, null, tower, null, null, null, null)

	var expected: int = int(round(float(original_cost) * 0.85))
	# Console.gd reads tower.definition.repair_price.scrap_cost LIVE every
	# tick (no caching) -- this is the exact same read path, proving the
	# reassigned `tower.definition` is what a real Console would see.
	assert_int(tower.definition.repair_price.scrap_cost).is_equal(expected)
	assert_int(TowerDefinitionResource.repair_price.scrap_cost).is_equal(original_cost)


# --- Fortress (non-scalar) ----------------------------------------------------

func test_fortress_advances_the_tower_one_evolution_stage_at_run_start() -> void:
	var tower: Tower = _make_tower()
	assert_int(tower.evolution_stage.get_current_stage()).is_equal(0)

	var loadout: MetaLoadout = _loadout()
	loadout.fortress_enabled = true
	MetaLoadoutApplier.apply(loadout, null, tower, null, null, null, null)

	assert_int(tower.evolution_stage.get_current_stage()).append_failure_message("Fortress should start the Tower one stage up from Base").is_equal(1)


# --- Economy branch: starting Scrap, scrap cap, XP gain -----------------------

func test_scavenger_and_deep_pockets_apply_to_a_real_run_inventory() -> void:
	var inv := RunInventory.new()
	inv.configure(preload("res://data/economy/prototype.tres"), null)
	var base_cap: int = inv.scrap_cap

	var loadout: MetaLoadout = _loadout()
	loadout.starting_scrap = 45
	loadout.scrap_cap_bonus = 50
	MetaLoadoutApplier.apply(loadout, null, null, null, inv, null, null)

	assert_int(inv.scrap_current).is_equal(45)
	assert_int(inv.scrap_cap).is_equal(base_cap + 50)


func test_scholar_xp_gain_bonus_scales_credited_xp() -> void:
	var inv := RunInventory.new()
	inv.configure(preload("res://data/economy/prototype.tres"), null)

	var loadout: MetaLoadout = _loadout()
	loadout.xp_gain_bonus = 0.10
	MetaLoadoutApplier.apply(loadout, null, null, null, inv, null, null)

	# BUGFIX (meta layer core review): crediting 10.0 XP here (11.0 after the
	# +10% bonus) crosses data/economy/prototype.tres' own level-0 cost (8.0,
	# base_cost 5 + per_level_increment 3 x (0+1), decision D108) and
	# credit_xp()'s own level-up loop then consumes 8.0 of it, leaving 3.0 --
	# not 11.0. 5.0 (5.5 after the bonus) stays under that threshold, so this
	# assertion tests ONLY the multiplier, not level-up bookkeeping (that is
	# run_inventory_test.gd's own job).
	inv.credit_xp(5.0)
	assert_float(inv.xp_current).is_equal_approx(5.5, 0.01)


# --- Lucky Draw (Draft rerolls) -----------------------------------------------

func test_lucky_draw_adds_bonus_rerolls_on_top_of_the_register_baseline() -> void:
	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(controller)
	assert_int(controller.get_rerolls_remaining()).is_equal(1) # Register baseline

	var loadout: MetaLoadout = _loadout()
	loadout.bonus_draft_rerolls = 2
	MetaLoadoutApplier.apply(loadout, null, null, null, null, controller, null)

	assert_int(controller.get_rerolls_remaining()).is_equal(3)


# --- War Chest (level start + deferred first-wave free Draft) ----------------

func test_war_chest_grants_level_one_immediately() -> void:
	var inv := RunInventory.new()
	inv.configure(preload("res://data/economy/prototype.tres"), null)
	assert_int(inv.level).is_equal(0)

	var loadout: MetaLoadout = _loadout()
	loadout.war_chest_enabled = true
	MetaLoadoutApplier.apply(loadout, null, null, null, inv, null, null)

	assert_int(inv.level).append_failure_message("War Chest starts the run at level 1").is_equal(1)


## BUGFIX (meta layer core review): the original version of this test wired
## no UpgradeSystem, so `queue_forced_draft_for_meta()`'s own
## `_try_open_next_draft()` -- which drains the queue and opens a draft
## SYNCHRONOUSLY, the instant nothing else is showing -- reached
## `_roll_three_cards()` with `_upgrade_system == null`, which
## `push_error()`s (an ENGINE ERROR line tests/run_tests.ps1's own Guard 4
## fails the whole suite on) and left `get_pending_draft_count_for_test()`
## at 0, not 1, immediately afterward (the request had already been popped
## and opened, not left queued) -- the assertion could never have passed.
## Fixed by wiring a real UpgradeSystem (so the draft opens cleanly) and
## asserting on `is_draft_showing_for_test()` (whether the free Draft
## actually opened), matching what `queue_forced_draft_for_meta()` really
## does: enqueue AND immediately try to open, not merely enqueue.
func test_war_chest_queues_a_free_draft_only_when_the_first_wave_opens() -> void:
	var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(upgrade_system)
	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	controller.set_upgrade_system_for_test(upgrade_system)
	add_child(controller)
	# A compiled `signal` declaration, not `add_user_signal()` on a bare Node:
	# `MetaLoadoutApplier` connects via dot-notation
	# (`wave_director.wave_opened.connect(...)`), which only resolves against
	# a signal the object's OWN script declares with the `signal` keyword --
	# matching tests/unit/run_flow_check_test.gd's own `_make_fake_wave_director()`
	# precedent for the identical reason.
	var wd_script := GDScript.new()
	wd_script.source_code = "extends Node\nsignal wave_opened(wave_id: String, wave_index: int)\n"
	wd_script.reload()
	var fake_wave_director := Node.new()
	fake_wave_director.set_script(wd_script)
	add_child(auto_free(fake_wave_director))

	var loadout: MetaLoadout = _loadout()
	loadout.war_chest_enabled = true
	MetaLoadoutApplier.apply(loadout, null, null, null, null, controller, fake_wave_director)

	assert_bool(controller.is_draft_showing_for_test()).append_failure_message("no free Draft before any wave has opened").is_false()
	fake_wave_director.emit_signal("wave_opened", "wave_t1", 0) # the first wave, 0-based
	assert_bool(controller.is_draft_showing_for_test()).append_failure_message("War Chest's free Draft should open when the FIRST wave opens").is_true()

	controller.confirm_choice_for_test(0) # close it, so the next wave_opened starts from an unambiguous closed baseline
	fake_wave_director.emit_signal("wave_opened", "wave_t2", 1) # CONNECT_ONE_SHOT must not fire a second time
	assert_bool(controller.is_draft_showing_for_test()).append_failure_message("a later wave must not trigger a second free Draft").is_false()


# --- Second Wind (once per run) -----------------------------------------------

func test_second_wind_saves_the_player_once_then_lets_a_second_lethal_hit_kill() -> void:
	var player: Player = _make_player()
	var max_hp: float = player.death_state.max_hp

	var loadout: MetaLoadout = _loadout()
	loadout.second_wind_enabled = true
	MetaLoadoutApplier.apply(loadout, player, null, null, null, null, null)

	assert_bool(player.apply_damage(max_hp * 10.0)).is_true() # a wildly lethal hit
	assert_bool(player.death_state.is_dead).append_failure_message("Second Wind should have prevented Logical Death on the first lethal hit").is_false()
	assert_float(player.death_state.current_hp).is_equal_approx(max_hp * 0.30, 0.5)

	assert_bool(player.apply_damage(max_hp * 10.0)).is_true()
	assert_bool(player.death_state.is_dead).append_failure_message("Second Wind is once per run -- the second lethal hit must kill normally").is_true()


# --- Idempotence for an all-zero loadout (every existing test's own scenario) -

func test_an_all_zero_loadout_is_a_true_no_op_on_a_real_player_and_tower() -> void:
	var player: Player = _make_player()
	var tower: Tower = _make_tower()
	var original_hp: float = player.death_state.max_hp
	var original_tower_hp: float = tower.health.max_health

	MetaLoadoutApplier.apply(MetaLoadout.new(), player, tower, null, null, null, null)

	assert_float(player.death_state.max_hp).is_equal(original_hp)
	assert_float(tower.health.max_health).is_equal(original_tower_hp)
	assert_int(tower.evolution_stage.get_current_stage()).is_equal(0)
