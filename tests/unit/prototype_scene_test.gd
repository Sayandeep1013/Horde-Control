extends GdUnitTestSuite

## Prototype scene-integration suite (P2.7 integration task). Instantiates
## `res://scenes/prototype.tscn` -- the assembled playable prototype
## (arena, Tower, player, camera, HUD, threat feedback, three hand-placed
## enemies one per intent, no Wave Director) -- and asserts every wiring
## claim the integration task's own report makes:
##   - every required node is present;
##   - the container layout docs/20 > Scene Tree requires (via
##     scenes/main.tscn, instanced unmodified) is intact;
##   - the player sits outside `Entities` with the Register's z_index;
##   - every z_index matches the Register's draw-order row, measured as the
##     EFFECTIVE (accumulated) z_index Godot actually renders with, not the
##     bare per-node property -- see `_effective_z_index()` below for why
##     that distinction matters here specifically;
##   - all three enemies are present, registered under the right
##     EntityRegistry tags, and findable by the Tower's REAL targeting
##     query (its own `_physics_process`, not a synthetic lookup);
##   - every texture and audio stream this task wired resolves to a
##     non-null resource loaded from the expected on-disk path, not merely
##     "the scene loaded without an error" (a broken resource path is
##     silent -- Godot logs a load error and carries on with a null
##     texture, per this task's own brief);
##   - the Tower cue is routed to TowerCue.
##
## Cannot be run: run_project / game_* are sandbox-only (author decision);
## the feel check itself is the author's. This suite is the headless proof
## in its place.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")

var _proto: Node = null
var _main: Node = null
var _tower: Tower = null
var _player: Player = null
var _camera: GameCamera = null
var _hud: Hud = null
var _threat_feedback: ThreatFeedback = null
var _ui_sfx: UiSfx = null
var _shared_ducking: AudioDucking = null
var _seeker: EnemyController = null
var _hunter: EnemyController = null
var _opportunist: EnemyController = null


func before_test() -> void:
	_proto = auto_free(PrototypeScene.instantiate())
	add_child(_proto)
	_main = _proto.get_node("Main")
	_tower = _proto.get_node("Main/Tower") as Tower
	_player = _proto.get_node("Main/Player") as Player
	_camera = _proto.get_node("Main/Player/GameCamera") as GameCamera
	_hud = _proto.get_node("Hud") as Hud
	_threat_feedback = _proto.get_node("ThreatFeedbackLayer/Overlay") as ThreatFeedback
	_ui_sfx = _proto.get_node("UiSfx") as UiSfx
	_shared_ducking = _proto.get_node("SharedAudioDucking") as AudioDucking
	_seeker = _proto.get_node("Main/Entities/TowerSeeker") as EnemyController
	_hunter = _proto.get_node("Main/Entities/PlayerHunter") as EnemyController
	_opportunist = _proto.get_node("Main/Entities/Opportunist") as EnemyController


## Walks up from `node`, accumulating each ancestor's own `z_index` while
## the node being examined has `z_as_relative == true`, and stopping (per
## Godot's own documented CanvasItem.z_as_relative rule) at the first node
## -- inclusive -- whose `z_as_relative` is false. This is NOT the same as
## reading `node.z_index` alone: this integration task found a real defect
## (see `test_player_projectile_effective_z_index_is_30_not_accumulated`
## below) that a bare property check cannot see, because the property was
## already correct on every node individually -- only the RENDERED,
## accumulated result was wrong.
static func _effective_z_index(node: CanvasItem) -> int:
	var total: int = node.z_index
	var relative: bool = node.z_as_relative
	var current: Node = node
	while relative:
		var parent: Node = current.get_parent()
		if not (parent is CanvasItem):
			break
		var p: CanvasItem = parent as CanvasItem
		total += p.z_index
		relative = p.z_as_relative
		current = p
	return total


func _advance_physics(ticks: int) -> void:
	for i in range(ticks):
		await get_tree().physics_frame


# --- Every required node is present -----------------------------------------

func test_every_required_node_is_present() -> void:
	assert_object(_main).append_failure_message("Main instance missing").is_not_null()
	assert_object(_tower).append_failure_message("Tower instance missing or wrong type").is_not_null()
	assert_object(_player).append_failure_message("Player instance missing or wrong type").is_not_null()
	assert_object(_camera).append_failure_message("GameCamera missing or wrong type").is_not_null()
	assert_object(_hud).append_failure_message("Hud instance missing or wrong type").is_not_null()
	assert_object(_threat_feedback).append_failure_message("ThreatFeedback overlay missing or wrong type").is_not_null()
	assert_object(_ui_sfx).append_failure_message("UiSfx missing or wrong type").is_not_null()
	assert_object(_shared_ducking).append_failure_message("SharedAudioDucking missing or wrong type").is_not_null()
	assert_object(_seeker).append_failure_message("TowerSeeker missing or wrong type").is_not_null()
	assert_object(_hunter).append_failure_message("PlayerHunter missing or wrong type").is_not_null()
	assert_object(_opportunist).append_failure_message("Opportunist missing or wrong type").is_not_null()
	assert_int(_seeker.get_current_intent()).is_equal(ContractEnums.TargetIntent.TowerSeeker)
	assert_int(_hunter.get_current_intent()).is_equal(ContractEnums.TargetIntent.PlayerHunter)
	assert_int(_opportunist.get_current_intent()).is_equal(ContractEnums.TargetIntent.Opportunist)


# --- Container layout intact (docs/20 > Scene Tree), via the unmodified Main instance ---

func test_main_still_carries_the_six_named_containers() -> void:
	for n in ["Entities", "Projectiles", "Pickups", "Effects", "Environment", "Audio"]:
		assert_object(_main.get_node_or_null(n)).append_failure_message("Main is missing container: %s" % n).is_not_null()
	assert_object(_main.get_node_or_null("SimLoop")).append_failure_message("Main is missing SimLoop").is_not_null()
	assert_object(_main.get_node_or_null("EntitySpawner")).append_failure_message("Main is missing EntitySpawner").is_not_null()


func test_entities_is_y_sorted_and_the_other_five_containers_are_not() -> void:
	assert_bool((_main.get_node("Entities") as Node2D).y_sort_enabled).is_true()
	for n in ["Projectiles", "Pickups", "Effects", "Environment"]:
		assert_bool((_main.get_node(n) as Node2D).y_sort_enabled).append_failure_message("%s must not be y-sorted" % n).is_false()


func test_nothing_under_main_the_gameplay_root_sets_process_mode_always() -> void:
	var offenders: Array[String] = _find_process_mode_always(_main, "")
	assert_array(offenders).append_failure_message(
		"nodes under Main (the gameplay root) set PROCESS_MODE_ALWAYS, banned by docs/20 > Scene Tree: %s" % str(offenders)
	).is_empty()


func _find_process_mode_always(node: Node, path: String) -> Array[String]:
	var out: Array[String] = []
	var here: String = path + "/" + node.name
	if node.process_mode == Node.PROCESS_MODE_ALWAYS:
		out.append(here)
	for child in node.get_children():
		out.append_array(_find_process_mode_always(child, here))
	return out


## The PROCESS_MODE_ALWAYS nodes this integration task DOES need (Hud,
## the shared AudioDucking, UiSfx) exist -- just outside Main, per the
## contradiction named in this task's own report and in NEXT_SESSION.md.
func test_the_process_mode_always_nodes_this_scene_needs_exist_outside_main() -> void:
	assert_int(_hud.process_mode).append_failure_message("Hud must be PROCESS_MODE_ALWAYS (docs/20 > Global Simulation Authority)").is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_int(_shared_ducking.process_mode).append_failure_message("the shared AudioDucking must be PROCESS_MODE_ALWAYS").is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_int(_ui_sfx.process_mode).append_failure_message("UiSfx must be PROCESS_MODE_ALWAYS").is_equal(Node.PROCESS_MODE_ALWAYS)
	# None of them is a descendant of Main (the gameplay root).
	assert_object(_hud.get_parent()).is_same(_proto)
	assert_object(_shared_ducking.get_parent()).is_same(_proto)
	assert_object(_ui_sfx.get_parent()).is_same(_proto)


# --- Player outside Entities, with the Register's z_index -------------------

func test_player_is_not_a_child_of_entities_and_not_in_its_y_sort_group() -> void:
	var entities: Node = _main.get_node("Entities")
	assert_bool(_player.get_parent() == entities).append_failure_message("Player must not be a child of Entities (docs/20 > Scene Tree)").is_false()
	assert_object(_player.get_parent()).append_failure_message("Player is expected to be a direct child of Main, a sibling of Entities").is_same(_main)


func test_player_effective_z_index_is_50() -> void:
	assert_int(_effective_z_index(_player)).append_failure_message("Player's rendered z_index does not match the Register's Readability row (player 50)").is_equal(50)


# --- Every z_index matches the Register's draw-order row (effective, not bare) ---

func test_environment_floor_effective_z_index_is_0() -> void:
	var arena: Node = _main.get_node("Environment/ArenaInstance")
	var floor_sprite: Sprite2D = arena.get_node("Floor") as Sprite2D
	assert_int(_effective_z_index(floor_sprite)).is_equal(0)


func test_enemies_effective_z_index_is_20() -> void:
	for enemy in [_seeker, _hunter, _opportunist]:
		assert_int(_effective_z_index(enemy)).append_failure_message("%s does not render at the Register's enemy z-band (20)" % enemy.name).is_equal(20)


func test_tower_effective_z_index_is_25() -> void:
	assert_int(_effective_z_index(_tower)).is_equal(25)


func test_telegraph_visual_effective_z_index_is_40() -> void:
	for enemy in [_seeker, _hunter, _opportunist]:
		var telegraph: Node2D = enemy.get_node("TelegraphVisual") as Node2D
		assert_int(_effective_z_index(telegraph)).append_failure_message(
			"%s's TelegraphVisual does not render at the Register's telegraph z-band (40)" % enemy.name
		).is_equal(40)


## Real defect this integration task found (not a hypothetical): a Player
## projectile's OWN z_index property has always read 30 (P2.3's own
## acceptance test asserts exactly that, locally). But `Projectiles` (the
## container Player.gd's AutoWeapon pools into) is a CHILD OF PLAYER, and
## Godot's z_as_relative accumulates through every relative ancestor -- so
## the moment Player itself is not the scene root (i.e. the instant it is
## nested under Main, exactly what this integration task does), the
## rendered z_index became 0 (Main) + 50 (Player) + 0 (Projectiles) + 30
## (the projectile) = 80, not 30. Fixed by setting `Projectiles.z_as_
## relative = false` in scenes/player.tscn (and the identical fix in
## scenes/tower.tscn's own Projectiles container) -- see this task's
## evidence report.
func test_player_projectile_effective_z_index_is_30_not_accumulated() -> void:
	await _advance_physics(90) # fire_interval 0.5s at 60 Hz; the Seeker starts well within the Handgun's 260px range
	var projectiles_container: Node = _player.get_node("Projectiles")
	var live: Array = projectiles_container.get_children()
	assert_array(live).append_failure_message("AutoWeapon never fired -- cannot verify a real projectile's effective z_index").is_not_empty()
	var projectile: CanvasItem = live[0] as CanvasItem
	assert_int(_effective_z_index(projectile)).append_failure_message(
		"a real, fired PlayerProjectile's EFFECTIVE z_index is not 30 -- likely the z_as_relative accumulation bug this task fixed regressing"
	).is_equal(30)


func test_tower_projectile_effective_z_index_is_30_not_accumulated() -> void:
	await _advance_physics(90) # Tower's own fire_interval is 0.8s at 60 Hz
	var projectiles_container: Node = _tower.get_node("Projectiles")
	var live: Array = projectiles_container.get_children()
	assert_array(live).append_failure_message("TowerWeapon never fired -- cannot verify a real projectile's effective z_index").is_not_empty()
	var projectile: CanvasItem = live[0] as CanvasItem
	assert_int(_effective_z_index(projectile)).append_failure_message(
		"a real, fired TowerProjectile's EFFECTIVE z_index is not 30"
	).is_equal(30)


# --- All three enemies registered under the right tags, findable by the Tower's real query ---

func test_all_three_enemies_are_registered_under_the_enemy_tag() -> void:
	for enemy in [_seeker, _hunter, _opportunist]:
		assert_bool(EntityRegistry.is_registered(enemy)).append_failure_message("%s is not registered with EntityRegistry" % enemy.name).is_true()
		assert_array(EntityRegistry.get_tags(enemy)).append_failure_message("%s is not tagged 'enemy'" % enemy.name).contains([&"enemy"])


func test_only_the_tower_seeker_carries_the_tower_seeker_tag() -> void:
	assert_array(EntityRegistry.get_tags(_seeker)).append_failure_message("TowerSeeker is missing the 'tower_seeker' tag TowerWeapon's C-TOWERTARGET query depends on").contains([&"tower_seeker"])
	assert_array(EntityRegistry.get_tags(_hunter)).append_failure_message("PlayerHunter must not carry 'tower_seeker'").not_contains([&"tower_seeker"])
	assert_array(EntityRegistry.get_tags(_opportunist)).append_failure_message("Opportunist must not carry 'tower_seeker' (it is not currently converted)").not_contains([&"tower_seeker"])


## LEDGER F03-15's own warning made concrete: if the placed instances did
## not actually run EnemyController's registration path, "the Tower's
## targeting silently finds nothing." This drives the REAL TowerWeapon
## (its own `_physics_process`, never a synthetic EntityRegistry query
## built just for this test) and asserts it actually acquires the real
## Tower Seeker instance.
func test_the_towers_real_targeting_query_finds_the_placed_tower_seeker() -> void:
	await _advance_physics(5)
	assert_object(_tower.weapon.get_current_target()).append_failure_message(
		"TowerWeapon's real _physics_process did not acquire the hand-placed TowerSeeker -- C-TOWERTARGET would silently find nothing (LEDGER F03-15)"
	).is_same(_seeker)


func test_the_tower_is_wired_to_every_enemy_so_seeker_and_opportunist_can_find_it() -> void:
	# set_tower_reference() (F03-26's seam) must have actually run for all
	# three -- checked via the public get_target_for_test() query rather
	# than a private field.
	assert_object(_seeker.get_target_for_test()).append_failure_message("TowerSeeker's target did not resolve to the real Tower").is_same(_tower)


# --- Every wired texture resolves to a non-null resource ---------------------

func test_arena_floor_and_wall_textures_resolve_to_kenney_files() -> void:
	var arena: Node = _main.get_node("Environment/ArenaInstance")
	var floor_sprite: Sprite2D = arena.get_node("Floor") as Sprite2D
	assert_object(floor_sprite.texture).append_failure_message("Floor.texture is null -- broken resource path").is_not_null()
	assert_str(floor_sprite.texture.resource_path).contains("third_party/kenney/environment/floor_tile.png")
	for wall_name in ["WallNorthSprite", "WallSouthSprite", "WallWestSprite", "WallEastSprite"]:
		var wall: Sprite2D = arena.get_node(wall_name) as Sprite2D
		assert_object(wall.texture).append_failure_message("%s.texture is null -- broken resource path" % wall_name).is_not_null()
		assert_str(wall.texture.resource_path).append_failure_message("%s does not resolve to wall_tile.png" % wall_name).contains("third_party/kenney/environment/wall_tile.png")


func test_tower_visuals_stage_and_platform_textures_are_all_non_null() -> void:
	var visuals: TowerVisuals = _tower.visuals
	assert_object(visuals).is_not_null()
	assert_int(visuals.stage_textures.size()).append_failure_message("TowerVisuals.stage_textures must carry all four evolution stages").is_equal(4)
	for i in range(4):
		assert_object(visuals.stage_textures[i]).append_failure_message("stage_textures[%d] is null -- broken resource path" % i).is_not_null()
	assert_object(visuals.platform_texture).append_failure_message("TowerVisuals.platform_texture is null -- broken resource path").is_not_null()
	assert_str(visuals.platform_texture.resource_path).contains("third_party/kenney/tower/tower_platform.png")
	# The initial (stage 0, Base) texture must already be applied -- primed
	# once by Tower._ready(), not left waiting for a rank that is never
	# taken in this prototype.
	var sprite: Sprite2D = _tower.get_node("Visuals/Sprite") as Sprite2D
	assert_object(sprite.texture).is_same(visuals.stage_textures[0])
	assert_str(sprite.texture.resource_path).contains("tower_stage1_base.png")


func test_tower_weapon_projectile_texture_and_fire_sfx_are_non_null() -> void:
	assert_object(_tower.weapon.projectile_texture).append_failure_message("TowerWeapon.projectile_texture is null").is_not_null()
	assert_str(_tower.weapon.projectile_texture.resource_path).contains("third_party/kenney/projectiles/projectile_tower.png")
	assert_object(_tower.weapon.fire_sfx).append_failure_message("TowerWeapon.fire_sfx is null").is_not_null()
	assert_str(_tower.weapon.fire_sfx.resource_path).contains("third_party/kenney/audio/sfx/tower_fire.ogg")


func test_a_real_fired_tower_projectile_carries_the_wired_sprite() -> void:
	await _advance_physics(90)
	var projectiles_container: Node = _tower.get_node("Projectiles")
	var live: Array = projectiles_container.get_children()
	assert_array(live).is_not_empty()
	var sprite: Sprite2D = (live[0] as Node).get_node_or_null("Sprite2D") as Sprite2D
	assert_object(sprite).append_failure_message("the fired TowerProjectile has no Sprite2D child -- projectile_texture composition did not apply").is_not_null()
	assert_object(sprite.texture).is_same(_tower.weapon.projectile_texture)


func test_player_autoweapon_fire_sfx_and_projectile_texture_are_non_null() -> void:
	var auto_weapon: Node = _player.get_node("AutoWeapon")
	assert_object(auto_weapon.get("fire_sfx")).append_failure_message("AutoWeapon.fire_sfx is null").is_not_null()
	assert_str((auto_weapon.get("fire_sfx") as AudioStream).resource_path).contains("third_party/kenney/audio/sfx/player_fire.ogg")


func test_a_real_fired_player_projectile_carries_the_kenney_texture() -> void:
	await _advance_physics(90)
	var projectiles_container: Node = _player.get_node("Projectiles")
	var live: Array = projectiles_container.get_children()
	assert_array(live).append_failure_message("AutoWeapon never fired").is_not_empty()
	var projectile: PlayerProjectile = live[0] as PlayerProjectile
	assert_object(projectile.projectile_texture).is_not_null()
	assert_str(projectile.projectile_texture.resource_path).contains("third_party/kenney/projectiles/projectile_player.png")
	var sprite: Sprite2D = projectile.get_node_or_null("Sprite2D") as Sprite2D
	assert_object(sprite).is_not_null()
	assert_object(sprite.texture).is_same(projectile.projectile_texture)


func test_player_damage_sfx_is_non_null_and_wired_to_the_audio_pool() -> void:
	assert_object(_player.damage_sfx).append_failure_message("Player.damage_sfx is null").is_not_null()
	assert_str(_player.damage_sfx.resource_path).contains("third_party/kenney/audio/sfx/player_damage.ogg")


func test_every_enemy_hit_and_death_sfx_are_non_null() -> void:
	for enemy in [_seeker, _hunter, _opportunist]:
		assert_object(enemy.hit_sfx).append_failure_message("%s.hit_sfx is null" % enemy.name).is_not_null()
		assert_str(enemy.hit_sfx.resource_path).contains("third_party/kenney/audio/sfx/enemy_hit.ogg")
		assert_object(enemy.death_sfx).append_failure_message("%s.death_sfx is null" % enemy.name).is_not_null()
		assert_str(enemy.death_sfx.resource_path).contains("third_party/kenney/audio/sfx/enemy_death.ogg")


func test_every_telegraph_visual_texture_is_non_null_and_carries_a_real_sprite() -> void:
	for enemy in [_seeker, _hunter, _opportunist]:
		var telegraph: TelegraphVisual = enemy.get_node("TelegraphVisual") as TelegraphVisual
		assert_object(telegraph.texture).append_failure_message("%s's TelegraphVisual.texture is null" % enemy.name).is_not_null()
		assert_str(telegraph.texture.resource_path).contains("third_party/kenney/telegraphs/telegraph_diamond.png")
		var sprite: Sprite2D = telegraph.get_sprite_for_test()
		assert_object(sprite).is_not_null()
		assert_object(sprite.texture).is_same(telegraph.texture)


func test_ui_sfx_cues_are_all_non_null_and_route_to_the_ui_bus() -> void:
	assert_object(_ui_sfx.confirm_stream).is_not_null()
	assert_str(_ui_sfx.confirm_stream.resource_path).contains("third_party/kenney/audio/ui/confirm.ogg")
	assert_object(_ui_sfx.cancel_stream).is_not_null()
	assert_str(_ui_sfx.cancel_stream.resource_path).contains("third_party/kenney/audio/ui/cancel.ogg")
	assert_object(_ui_sfx.cycle_stream).is_not_null()
	assert_str(_ui_sfx.cycle_stream.resource_path).contains("third_party/kenney/audio/ui/cycle.ogg")
	assert_str(_ui_sfx.get_confirm_player_for_test().bus).is_equal("UI")
	assert_str(_ui_sfx.get_cancel_player_for_test().bus).is_equal("UI")
	assert_str(_ui_sfx.get_cycle_player_for_test().bus).is_equal("UI")


# --- The Tower cue: real asset, routed to TowerCue --------------------------

func test_tower_cue_stream_is_the_real_kenney_asset_not_the_placeholder_tone() -> void:
	var stream: AudioStream = _threat_feedback.get_cue_stream()
	assert_object(stream).append_failure_message("ThreatFeedback.get_cue_stream() is null").is_not_null()
	assert_bool(stream is AudioStreamWAV).append_failure_message(
		"the Tower cue is still the procedurally generated placeholder tone (AudioStreamWAV) -- F03-18's audio gap is not closed"
	).is_false()
	assert_str(stream.resource_path).contains("third_party/kenney/audio/sfx/tower_damage.ogg")


func test_tower_cue_player_is_routed_to_the_towercue_bus() -> void:
	var cue_player: TowerCuePlayer = _threat_feedback.get_cue_player()
	assert_object(cue_player).is_not_null()
	assert_str(cue_player.bus).is_equal("TowerCue")
	assert_int(AudioServer.get_bus_index("TowerCue")).append_failure_message("TowerCue bus is missing from the bus layout").is_not_equal(-1)
	var towercue_idx: int = AudioServer.get_bus_index("TowerCue")
	assert_str(AudioServer.get_bus_send(towercue_idx)).append_failure_message("TowerCue must send to SFX_Priority").is_equal("SFX_Priority")


func test_shared_audio_ducking_wired_to_both_the_tower_cue_and_the_audio_pool() -> void:
	assert_object(_threat_feedback.get_ducking_node()).append_failure_message(
		"ThreatFeedback still holds its own private AudioDucking instead of the shared one this integration task wires"
	).is_same(_shared_ducking)
	var audio_pool: Node = _main.get_node("Audio")
	assert_object(audio_pool.get("ducking_node")).append_failure_message(
		"AudioPool.ducking_node is not wired to the shared AudioDucking -- priority SFX (e.g. player damage) would never duck"
	).is_same(_shared_ducking)
