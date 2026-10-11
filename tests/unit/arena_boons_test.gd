extends GdUnitTestSuite

## v1.0 WP-ARENA (docs/32 section B; Register "v1.0 Arena Interactables"): the four Shrine boons, how they
## compose with Draft / meta multipliers (multiply, never overwrite), expiry on
## SimClock, the Bounty double-Scrap hook and the HUD boon tray. Expectations are
## literals from the Register.

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const DT: float = 1.0 / 60.0

var _player: Player
var _tower: Tower
var _mgr: ArenaInteractables
var _weapon: AutoWeapon


func before_test() -> void:
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	GameSettings.reset_state_for_test()
	_tower = auto_free(preload("res://scenes/tower.tscn").instantiate())
	add_child(_tower)
	_player = auto_free(preload("res://scenes/player.tscn").instantiate())
	_player.driven_externally = true
	add_child(_player)
	_player.global_position = Vector2(900, 700)
	_weapon = _player.get_node("AutoWeapon") as AutoWeapon
	_weapon.driven_externally = true
	_mgr = auto_free(ArenaInteractables.new())
	_mgr.spike_layout = null
	add_child(_mgr)


func after_test() -> void:
	GameSettings.reset_state_for_test()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()


func _advance(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		SimClock.now += DT


# --- War ---------------------------------------------------------------------------

func test_war_adds_35_percent_player_damage_and_composes_with_the_draft_multiplier() -> void:
	var base: float = _weapon.get_effective_damage_per_shot()
	_mgr.claim_boon("war")
	assert_float(_weapon.get_effective_damage_per_shot()).is_equal_approx(base * 1.35, 0.0001)
	# The Draft / meta setter is absolute: it must not overwrite the boon.
	_weapon.set_damage_multiplier(1.5)
	assert_float(_weapon.get_effective_damage_per_shot()).is_equal_approx(base * 1.5 * 1.35, 0.0001)
	_weapon.set_damage_multiplier(2.0)
	assert_float(_weapon.get_effective_damage_per_shot()).is_equal_approx(base * 2.0 * 1.35, 0.0001)
	# Abilities read the same multiplier through the weapon.
	assert_float(_weapon.get_damage_multiplier()).is_equal_approx(2.0 * 1.35, 0.0001)


func test_war_expires_after_20_seconds_and_restores_the_exact_multiplier() -> void:
	_weapon.set_damage_multiplier(1.5)
	var base: float = _weapon.get_effective_damage_per_shot()
	_mgr.claim_boon("war")
	_advance(19.9)
	_mgr.update_boons()
	assert_bool(_mgr.has_boon("war")).is_true()
	assert_float(_weapon.get_effective_damage_per_shot()).is_equal_approx(base * 1.35, 0.0001)
	_advance(0.2)
	_mgr.update_boons()
	assert_bool(_mgr.has_boon("war")).is_false()
	assert_float(_weapon.get_effective_damage_per_shot()).is_equal_approx(base, 0.0001)


# --- Haste -------------------------------------------------------------------------

func test_haste_multiplies_speed_and_dash_recharge_with_swift_feet_and_expires() -> void:
	_player.set_speed_multiplier(1.2) # Swift Feet
	_player.set_dash_cooldown_multiplier(0.8) # Fleet Step
	var cooldown_before: float = _player.get_dash_state()["cooldown_total"]
	_mgr.claim_boon("haste")
	assert_float(_player.get_boon_speed_multiplier()).is_equal_approx(1.30, 0.0001)
	assert_float(_player.get_dash_state()["cooldown_total"]).is_equal_approx(cooldown_before / 1.30, 0.0001)
	_player.set_speed_multiplier(1.5) # the absolute setter again: the boon stays
	assert_float(_player.get_boon_speed_multiplier()).is_equal_approx(1.30, 0.0001)
	assert_float(_player.get_speed_multiplier_for_test()).is_equal_approx(1.5, 0.0001)
	_advance(20.1)
	_mgr.update_boons()
	assert_float(_player.get_boon_speed_multiplier()).is_equal(1.0)
	assert_float(_player.get_dash_state()["cooldown_total"]).is_equal_approx(cooldown_before, 0.0001)


# --- Ward --------------------------------------------------------------------------

func test_ward_refills_the_shield_and_cuts_tower_damage_taken_by_25_percent() -> void:
	_tower.health.current_shield = 0.0
	_tower.health.set_palisade(0.2, 0.0) # Spiked Palisade: composes by multiplication
	_mgr.claim_boon("ward")
	assert_float(_tower.health.current_shield).is_equal(_tower.health.max_shield)
	var shield: float = _tower.health.current_shield
	_tower.health._on_hurtbox_damage_received(100.0, &"enemy", null)
	assert_float(shield - _tower.health.current_shield).is_equal_approx(100.0 * 0.8 * 0.75, 0.001)
	_advance(20.1)
	_mgr.update_boons()
	_tower.health.current_shield = _tower.health.max_shield
	var shield2: float = _tower.health.current_shield
	_tower.health._on_hurtbox_damage_received(100.0, &"enemy", null)
	assert_float(shield2 - _tower.health.current_shield).is_equal_approx(100.0 * 0.8, 0.001)


# --- Bounty ------------------------------------------------------------------------

func test_bounty_doubles_scrap_for_exactly_the_next_20_kills() -> void:
	assert_int(_mgr._consume_bounty_kill()).is_equal(1) # no boon
	_mgr.claim_boon("bounty")
	assert_int(_mgr.get_active_boons()[0]["kills_left"]).is_equal(20)
	for i in 20:
		assert_int(_mgr._consume_bounty_kill()).is_equal(2)
	assert_bool(_mgr.has_boon("bounty")).is_false()
	assert_int(_mgr._consume_bounty_kill()).is_equal(1)


func test_pickup_system_doubles_the_queued_scrap_drop_while_bounty_is_active() -> void:
	var ps: PickupSystem = auto_free(PickupSystem.new())
	add_child(ps)
	_mgr.set_pickup_system_for_test(ps)
	ps.scrap_multiplier_provider = Callable(_mgr, "_consume_bounty_kill")
	var enemy: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	enemy.driven_externally = true
	add_child(enemy)
	auto_free(enemy)
	ps._on_enemy_died(enemy, Vector2(100, 100), 0.0)
	assert_int(ps._pending_drops[0]["scrap_mult"]).is_equal(1)
	_mgr.claim_boon("bounty")
	ps._on_enemy_died(enemy, Vector2(100, 100), 0.0)
	assert_int(ps._pending_drops[1]["scrap_mult"]).is_equal(2)
	ps.clear_all_for_test()


# --- Several boons, tray -----------------------------------------------------------

func test_boons_coexist_and_each_expires_on_its_own_clock() -> void:
	_mgr.claim_boon("war")
	_advance(10.0)
	_mgr.claim_boon("haste")
	var boons: Array[Dictionary] = _mgr.get_active_boons()
	assert_int(boons.size()).is_equal(2)
	assert_float(boons[0]["remaining"]).is_equal_approx(10.0, 0.05)
	assert_float(boons[1]["remaining"]).is_equal_approx(20.0, 0.05)
	_advance(10.2)
	_mgr.update_boons()
	assert_bool(_mgr.has_boon("war")).is_false()
	assert_bool(_mgr.has_boon("haste")).is_true()
	assert_float(_player.get_boon_speed_multiplier()).is_equal_approx(1.30, 0.0001)


func test_claiming_a_boon_again_refreshes_its_duration() -> void:
	_mgr.claim_boon("war")
	_advance(15.0)
	_mgr.claim_boon("war")
	assert_float(_mgr.get_active_boons()[0]["remaining"]).is_equal_approx(20.0, 0.05)


func test_shrine_claim_applies_its_boon_through_the_manager() -> void:
	var s: ArenaShrine = _mgr.add_shrine(Vector2(500, 500), "war")
	_player.global_position = Vector2(500, 500)
	s.check_player(_player)
	for i in 160:
		_advance(DT)
		s.check_player(_player)
	assert_bool(_mgr.has_boon("war")).is_true()
	s.free()


func test_boon_tray_shows_an_icon_pill_with_countdown_and_removes_it_on_expiry() -> void:
	var tray: BoonTray = auto_free(BoonTray.new())
	add_child(tray)
	tray._process(0.0)
	assert_int(tray.get_entry_count()).is_equal(0)
	_mgr.claim_boon("war")
	_mgr.claim_boon("bounty")
	tray._process(0.0)
	assert_int(tray.get_entry_count()).is_equal(2)
	assert_str(tray.get_label_text_for_test("war")).is_equal("20s")
	assert_str(tray.get_label_text_for_test("bounty")).is_equal("x20")
	_advance(5.1) # 14.9 s left shows as 15 (rounded up)
	tray._process(0.0)
	assert_str(tray.get_label_text_for_test("war")).is_equal("15s")
	_advance(15.2)
	_mgr.update_boons()
	tray._process(0.0)
	assert_bool(tray.get_label_text_for_test("war") == "").is_true()
	assert_int(tray.get_entry_count()).is_equal(1) # Bounty has no timer, only kills


func test_boon_tray_honours_the_hud_scale_setting() -> void:
	var tray: BoonTray = auto_free(BoonTray.new())
	add_child(tray)
	GameSettings.set_hud_scale_pct(100)
	tray._apply_scale()
	var y1: float = tray.position.y
	var s1: float = tray.scale.x
	GameSettings.set_hud_scale_pct(125)
	tray._apply_scale()
	assert_float(tray.scale.x).is_greater(s1)
	assert_float(tray.position.y).is_greater(y1)
