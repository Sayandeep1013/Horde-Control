extends GdUnitTestSuite

## Coverage for src/core/combat_stats.gd (P1.2). Fresh CombatStats instance
## per test (not the project's autoload singleton), so one test's
## report_sheet_dps() calls can never leak into the next.

const CombatStatsScript: GDScript = preload("res://src/core/combat_stats.gd")
const AttackProfileScript: GDScript = preload("res://src/data/attack_profile.gd")
const WeaponDefinitionScript: GDScript = preload("res://src/data/weapon_definition.gd")
const BandedValueScript: GDScript = preload("res://src/data/banded_value.gd")
const EngagementRhythmScript: GDScript = preload("res://src/data/engagement_rhythm.gd")

var _stats: Node


func before_test() -> void:
	_stats = auto_free(CombatStatsScript.new()) as Node
	add_child(_stats)


func test_process_mode_is_pausable() -> void:
	assert_int(_stats.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


func test_sheet_dps_is_damage_over_interval() -> void:
	# Handgun sheet DPS from MASTER_SDLC.md > Player Overview: "10 damage per
	# shot at 2 shots per second (20 DPS)" -- interval form is 0.5s/shot.
	assert_float(_stats.sheet_dps(10.0, 0.5)).is_equal_approx(20.0, 0.0001)
	# Tower base weapon: "20 damage per shot, 1.25 shots per second (25 DPS)"
	# -- interval form is 0.8s/shot.
	assert_float(_stats.sheet_dps(20.0, 0.8)).is_equal_approx(25.0, 0.0001)


func test_sheet_dps_guards_against_division_by_zero() -> void:
	assert_float(_stats.sheet_dps(50.0, 0.0)).is_equal(0.0)
	assert_float(_stats.sheet_dps(50.0, -1.0)).is_equal(0.0)


func test_sheet_dps_from_attack_profile_reads_the_shared_struct() -> void:
	# Tower Seeker: "melee 15 dmg per 1.5 s cycle (10 DPS)" (MASTER_SDLC.md >
	# Provisional Values Register > Enemy roster).
	var profile: Resource = AttackProfileScript.new()
	profile.damage_per_hit_or_tick = 15
	profile.cycle_or_tick_interval_seconds = 1.5
	assert_float(_stats.sheet_dps_from_attack_profile(profile)).is_equal_approx(10.0, 0.0001)


func test_sheet_dps_from_attack_profile_handles_null() -> void:
	assert_float(_stats.sheet_dps_from_attack_profile(null)).is_equal(0.0)


func test_sheet_dps_from_weapon_reads_damage_band_and_engagement_rhythm() -> void:
	var weapon: Resource = WeaponDefinitionScript.new()
	var band: Resource = BandedValueScript.new()
	band.value = 10
	var rhythm: Resource = EngagementRhythmScript.new()
	rhythm.fire_rate_per_second = 2.0
	weapon.damage_band = band
	weapon.engagement_rhythm = rhythm

	assert_float(_stats.sheet_dps_from_weapon(weapon)).is_equal_approx(20.0, 0.0001)


func test_sheet_dps_from_weapon_handles_missing_substructs() -> void:
	assert_float(_stats.sheet_dps_from_weapon(null)).is_equal(0.0)
	var weapon: Resource = WeaponDefinitionScript.new()
	assert_float(_stats.sheet_dps_from_weapon(weapon)).is_equal(0.0) # both substructs null


func test_report_and_get_sheet_dps_round_trips_per_subject() -> void:
	assert_bool(_stats.report_sheet_dps(&"player", 20.0)).is_true()
	assert_bool(_stats.report_sheet_dps(&"tower", 25.0)).is_true()
	assert_float(_stats.get_sheet_dps(&"player")).is_equal(20.0)
	assert_float(_stats.get_sheet_dps(&"tower")).is_equal(25.0)


func test_report_sheet_dps_refuses_negative_values() -> void:
	# docs/20 > Communication, commands: "The owning system validates the
	# request and may refuse it" -- this is where that half of the rule has
	# to be real, not decorative.
	assert_bool(_stats.report_sheet_dps(&"player", -5.0)).is_false()
	assert_bool(_stats.has_reported_sheet_dps(&"player")).is_false()
	assert_float(_stats.get_sheet_dps(&"player")).is_equal(0.0)


func test_get_sheet_dps_defaults_to_zero_for_unreported_subject() -> void:
	assert_float(_stats.get_sheet_dps(&"nobody_reported_this_yet")).is_equal(0.0)
	assert_bool(_stats.has_reported_sheet_dps(&"nobody_reported_this_yet")).is_false()
