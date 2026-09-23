extends GdUnitTestSuite
## A Rare/Epic card must describe the value the player will actually get
## (src/ui/draft_card_view.gd `_scaled_effect_text`, D117).

func test_common_text_is_unchanged() -> void:
	assert_str(DraftCardView._scaled_effect_text("+10% player fire rate per rank", 1.0)).is_equal("+10% player fire rate per rank")


func test_rare_and_epic_scale_every_percentage() -> void:
	assert_str(DraftCardView._scaled_effect_text("+10% damage, +15% range", 1.5)).is_equal("+15% damage, +23% range")
	assert_str(DraftCardView._scaled_effect_text("+10% player fire rate per rank", 2.2)).is_equal("+22% player fire rate per rank")
