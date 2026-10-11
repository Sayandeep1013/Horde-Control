class_name SelectionReasons
extends RefCounted

## Short "why is this locked" lines for the selection-state ribbons (PT-UI, docs/33 A1).
## The long explanation stays in each screen's hint line; these fit a plate's reason slot
## at the 37 px floor. Every number or name is read from the live data.


static func difficulty(profile: DifficultyProfile) -> String:
	UiStrings.ensure_registered()
	var gate: DifficultyProfile = RunConfig.get_difficulty_by_id(profile.unlocked_by_victory_on)
	return TranslationServer.translate("SEL_LOCKED_WIN_ON") % (gate.display_name if gate != null else profile.unlocked_by_victory_on)


## A Battle Skill is unlocked by buying a Skill Tree node: the Cores it costs now, or the tree.
static func battle_skill(skill_id: String) -> String:
	UiStrings.ensure_registered()
	var node_id: String = MetaProgress.get_battle_skill_unlock_node_id(skill_id)
	if node_id != "" and MetaProgress.prerequisites_met(node_id):
		var price: int = MetaProgress.price_of_next_rank(node_id)
		if price > 0:
			return TranslationServer.translate("SEL_LOCKED_NEED_CORES") % price
	return TranslationServer.translate("SEL_LOCKED_SKILL_TREE")


## Champions and Relics: just "Locked" on the plate (their names and the tablets are narrow); the
## hint line below the grid says how to earn it, and a press brings it up.
static func loadout(_id: String) -> String:
	UiStrings.ensure_registered()
	return TranslationServer.translate("SEL_LOCKED_UNLOCK")
