extends GdUnitTestSuite

## UX review item 5 (D131): readable ground symbols.


func test_windup_progress_is_zero_when_no_windup_is_active() -> void:
	var c: EnemyController = auto_free(EnemyController.new())
	assert_float(c.get_windup_progress()).is_equal(0.0)


## D377: a wind-up on the Tower shows no ring or "!"; one on the player does.
func test_windup_marker_shows_only_for_attacks_on_the_player() -> void:
	var c: EnemyController = auto_free(EnemyController.new())
	assert_bool(c.is_windup_marker_shown()).is_false()
	c._windup_active = true
	c._windup_on_tower = false
	assert_bool(c.is_windup_marker_shown()).is_true()
	c._windup_on_tower = true
	assert_bool(c.is_windup_marker_shown()).is_false()


func test_every_telegraph_uses_the_one_danger_colour() -> void:
	assert_that(TelegraphVisual.DANGER_COLOUR).is_equal(UiPalette.DANGER)


func test_pickups_bob_visibly() -> void:
	assert_float(Pickup.BOB_AMPLITUDE_PX).is_greater_equal(4.0)


func test_xp_crystal_hue_matches_the_xp_bar() -> void:
	var img: Image = (load("res://assets/sprites/pickup_xp_crystal.png") as Texture2D).get_image()
	var hue_sum: float = 0.0
	var n: int = 0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			# The 2 px ink outline (D161) is dark and blue-grey by design; the
			# hue of the crystal itself is read from its lit, saturated pixels.
			if c.a > 0.9 and c.s > 0.2 and c.v > 0.5:
				hue_sum += c.h
				n += 1
	assert_int(n).is_greater(100)
	assert_float(hue_sum / float(n)).is_equal_approx(UiPalette.XP.h, 0.03)
