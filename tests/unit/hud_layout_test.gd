extends GdUnitTestSuite

## HUD field wiring and the Register's border-shape/colour rule (P2.6).
## docs/19_UI_UX.md > "HUD"; MASTER_SDLC.md > Provisional Values Register >
## Interfaces > "HUD" row ("both bars tick at 40% and change border shape
## below it"); > Visual Edge Cases > "Colour-only distinctions" ("No
## gameplay-critical information may be conveyed through colour alone.
## Shape and motion must carry it as well.").
##
## Exercises the cross-task seam this task names rather than crossing: the
## HUD reads Player/Tower state through direct references and public state
## (`Player.death_state`, `TowerHealth`), never through `EventBus`, because
## `EventBus` carries no player_damaged/player_died signal and its
## `enemy_died` is unconditionally emitted even for the player's own death
## (Phase 03 LEDGER F03-06).

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func _build_hud() -> Hud:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	return hud


func _build_player() -> Player:
	var player: Player = auto_free(PlayerScene.instantiate() as Player)
	add_child(player)
	return player


func _build_tower() -> Tower:
	var tower: Tower = auto_free(TowerScene.instantiate() as Tower)
	add_child(tower)
	return tower


# --- Player health wiring ---------------------------------------------------

func test_player_health_bar_reflects_the_players_death_state() -> void:
	var hud: Hud = _build_hud()
	var player: Player = _build_player()
	hud.set_player_ref(player)

	player.apply_damage(20.0, "test")
	hud._refresh_player_health() # exercised directly -- see header, this is the same method _process() calls every frame

	var bar: HudBar = hud.get_player_health_bar()
	assert_float(bar.get_value()).is_equal_approx(player.death_state.current_hp, 0.01)
	assert_float(bar.get_max_value()).is_equal_approx(player.death_state.max_hp, 0.01)


func test_player_health_bar_is_below_tick_under_40_percent() -> void:
	var hud: Hud = _build_hud()
	var player: Player = _build_player()
	hud.set_player_ref(player)

	var max_hp: float = player.death_state.max_hp
	player.apply_damage(max_hp * 0.65, "test") # leaves 35%, below the 40% tick
	hud._refresh_player_health()

	var bar: HudBar = hud.get_player_health_bar()
	assert_bool(bar.is_below_tick()).is_true()
	assert_float(bar.get_border_width()).is_greater(2.0)
	assert_int(bar.get_border_corner_radius()).is_equal(0)


func test_player_health_bar_is_not_below_tick_above_40_percent() -> void:
	var hud: Hud = _build_hud()
	var player: Player = _build_player()
	hud.set_player_ref(player)

	var max_hp: float = player.death_state.max_hp
	player.apply_damage(max_hp * 0.10, "test") # leaves 90%, well above 40%
	hud._refresh_player_health()

	var bar: HudBar = hud.get_player_health_bar()
	assert_bool(bar.is_below_tick()).is_false()
	assert_int(bar.get_border_corner_radius()).is_greater(0)


# --- Tower health + shield wiring -------------------------------------------

func test_tower_health_bar_reflects_health_and_shield_split() -> void:
	var hud: Hud = _build_hud()
	var tower: Tower = _build_tower()
	hud.set_tower_ref(tower)

	# Shield absorbs first (Register > Tower: "the shield absorbs damage
	# before health"), then spills into health once broken.
	var max_shield: float = tower.health.max_shield
	tower.hurtbox.receive_hit(auto_free(Node.new()), max_shield + 40.0, "test")
	hud._refresh_tower_health()

	var bar: HudBar = hud.get_tower_health_bar()
	assert_float(bar.get_value()).is_equal_approx(tower.health.get_current_health(), 0.01)
	assert_float(bar.get_shield_value()).is_equal_approx(0.0, 0.01)
	assert_float(bar.get_value()).is_equal_approx(tower.health.max_health - 40.0, 0.5)


func test_tower_health_bar_is_below_tick_under_40_percent_health() -> void:
	var hud: Hud = _build_hud()
	var tower: Tower = _build_tower()
	hud.set_tower_ref(tower)

	var lethal_to_65_percent: float = tower.health.max_shield + tower.health.max_health * 0.65
	tower.hurtbox.receive_hit(auto_free(Node.new()), lethal_to_65_percent, "test")
	hud._refresh_tower_health()

	var bar: HudBar = hud.get_tower_health_bar()
	assert_bool(bar.is_below_tick()).is_true()


func test_wave_label_reads_from_the_hud_economy_state_seam() -> void:
	var hud: Hud = _build_hud()
	hud.economy_state.wave_current = 3
	hud.economy_state.wave_total = 8
	hud._refresh_tower_health()

	assert_str(hud.get_wave_label().text).contains("3/8")


# --- The four HUD fields exist and are distinct -----------------------------

func test_four_fields_are_distinct_nodes() -> void:
	var hud: Hud = _build_hud()
	var fields: Array = [hud.get_player_health_field(), hud.get_tower_health_field(), hud.get_scrap_field(), hud.get_xp_field()]
	for field in fields:
		assert_object(field).is_not_null()
	# No two of the four fields are the same node.
	for i in range(fields.size()):
		for j in range(fields.size()):
			if i != j:
				assert_bool(fields[i] == fields[j]).is_false()
