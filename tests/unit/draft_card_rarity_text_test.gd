extends GdUnitTestSuite
## A Rare/Epic card must describe the value the player will actually get
## (src/ui/draft_card_view.gd `_scaled_effect_text`, D117).

func test_common_text_is_unchanged() -> void:
	assert_str(DraftCardView._scaled_effect_text("+10% player fire rate per rank", 1.0)).is_equal("+10% player fire rate per rank")


func test_rare_and_epic_scale_every_percentage() -> void:
	assert_str(DraftCardView._scaled_effect_text("+10% damage, +15% range", 1.5)).is_equal("+15% damage, +22.5% range")
	assert_str(DraftCardView._scaled_effect_text("+10% player fire rate per rank", 2.2)).is_equal("+22% player fire rate per rank")


func test_non_whole_results_are_shown_honestly_not_rounded() -> void:
	assert_str(DraftCardView._scaled_effect_text("heal 1% of max health per second per rank", 1.5, "regeneration")).is_equal("heal 1.5% of max health per second per rank")


func test_cards_whose_effect_ignores_rarity_keep_their_authored_text() -> void:
	assert_str(DraftCardView._scaled_effect_text("instantly heal the Tower 25% of its max health", 1.5, "repair_kit")).is_equal("instantly heal the Tower 25% of its max health")
	assert_str(DraftCardView._scaled_effect_text("+1 extra arrow per rank at 70% damage, spread", 2.2, "multishot")).is_equal("+1 extra arrow per rank at 70% damage, spread")
