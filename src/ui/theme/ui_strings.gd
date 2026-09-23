extends RefCounted
class_name UiStrings

## UiStrings (UI pass). The English text for every `tr()` key the UI uses,
## registered with TranslationServer at runtime.
##
## Why this exists: the project calls `tr("HUD_WAVE")` and every other key
## below, but ships no translation file and registers none in
## `project.godot`, so every one of them rendered as its raw key ("HUD_WAVE
## 1/8", "HUD_LEVEL 0") in the scene a human launches. `project.godot` is
## outside the UI pass's write scope, so the strings are registered from
## code instead. The durable fix -
## a `.csv`/`.po` under version control, listed under
## `internationalization/locale/translations` - is requested in
## phases/UI_PASS/HANDOFF.md; when it lands, delete this file and the one
## call to `ensure_registered()` in ui_theme.gd.
##
## Registered under locale "en", which is also Godot's default
## `internationalization/locale/fallback`, so it resolves on a machine whose
## OS locale is anything else. Built-in pseudo-localization (F2, docs/19)
## applies on top of these strings exactly as it did on the raw keys.
##
## Wording follows docs/19: "Wave n/8", "FULL", "Rank n of 3", "MAX".

const LOCALE: String = "en"

const MESSAGES: Dictionary = {
	"HUD_WAVE": "Wave",
	"HUD_LEVEL": "Level",
	"HUD_REROLLS": "Rerolls",
	"HUD_FULL": "FULL",
	"HUD_HOPPER": "hopper",
	"HUD_GLYPH_PLAYER": "HP",
	"HUD_GLYPH_TOWER": "TOWER",
	"HUD_GLYPH_SCRAP": "SCRAP",
	"HUD_GLYPH_XP": "XP",

	"DRAFT_TITLE": "Level-Up Draft",

	# D115 (no in-run shop): every CONSOLE_* key (Tower Console UI text) is
	# removed along with the Console itself -- nothing left registers or
	# reads them (verified by grep before removal).

	"PAUSE_MENU_TITLE": "Paused",
	"PAUSE_MENU_RESUME": "Resume",
	"PAUSE_MENU_SETTINGS": "Settings",
	"PAUSE_MENU_MAIN_MENU": "Main Menu",

	"SETTINGS_MENU_TITLE": "Settings",
	"SETTINGS_MOVEMENT_ONLY": "Movement-only controls",
	"SETTINGS_ON": "On",
	"SETTINGS_OFF": "Off",
	"SETTINGS_BACK": "Back",

	"RUN_END_TITLE": "Run Over",
	# Meta layer core: the outcome header itself now reads as one of these
	# four words (build brief: "outcome header (Victory / Defeated / Tower
	# Fallen / Abandoned)") in place of the generic RUN_END_TITLE above,
	# which stays registered as the show_summary() fallback for a caller
	# that supplies no outcome_title (see run_end.gd's own show_summary()).
	"RUN_END_OUTCOME_VICTORY": "Victory",
	"RUN_END_OUTCOME_DEFEATED": "Defeated",
	"RUN_END_OUTCOME_TOWER_FALLEN": "Tower Fallen",
	"RUN_END_OUTCOME_ABANDONED": "Abandoned",
	"RUN_END_CAUSE": "Cause",
	"RUN_END_CAUSE_PLAYER": "You were defeated",
	"RUN_END_CAUSE_TOWER": "The Tower was destroyed",
	# Meta layer core (D113): promotes the literal src/run/run_flow_controller.gd
	# named as a follow-up seam for whoever next owned this file (its own
	# header, "cause_text = 'Run abandoned'") -- now a real key.
	"RUN_END_CAUSE_ABANDONED": "Run abandoned",
	"RUN_END_WAVE_REACHED": "Wave reached",
	"RUN_END_SCRAP_HELD": "Scrap held",
	"RUN_END_TIME_SURVIVED": "Time survived",
	"RUN_END_SETTINGS": "Settings",
	"RUN_END_MAIN_MENU": "Main Menu",
	# Meta layer core (build brief item 4): the run-end screen's new primary
	# choice -- promotes the plain literal RunEndScreen._build_ui() used
	# ("Continue," named there as "no tr() key exists for it yet") to a real
	# key now that this session owns this file.
	"RUN_END_CONTINUE": "Continue",
	"RUN_END_SETTLEMENT_TOTAL": "Cores earned",
	"RUN_END_NEW_BEST_WAVES": "NEW BEST -- waves cleared",
	"RUN_END_NEW_BEST_KILLS": "NEW BEST -- enemies defeated",
	"RUN_END_NEW_BEST_TIME": "NEW BEST -- time survived",
	"RUN_END_ALREADY_SETTLED": "Already settled",
	# Blind review of the meta layer, finding #6: shown instead of a Cores
	# total when `MetaProgress.settle_run()`'s own breakdown reports
	# `saved == false` -- most commonly a read-only-newer-version profile
	# (docs/18 section 6) -- so the results screen never claims Cores were
	# saved when they were not.
	"RUN_END_NOT_SAVED": "Not saved -- this profile could not be written to.",
	# D118 (achievements). `%s` is the unlocked achievement's own
	# display_name -- run_end.gd's own String % formats it, same convention
	# as SKILL_TREE_RESPEC_REFUND's "%d Cores" above.
	"RUN_END_ACHIEVEMENT_UNLOCKED": "Achievement unlocked: %s",

	# --- Meta layer core: Hub (War Camp) -----------------------------------
	"HUB_TITLE": "War Camp",
	"HUB_START_RUN": "Start Run",
	"HUB_SKILL_TREE": "Skill Tree",
	"HUB_RECORDS": "Records",
	"HUB_ACHIEVEMENTS": "Achievements",
	"HUB_BACK_TO_TITLE": "Back to Title",
	# docs/18_Permanent_Skill_Tree.md section 2: "the first time the Hub
	# opens ... a one-line hint," quoted verbatim.
	"HUB_FIRST_VISIT_HINT": "Earn Cores in battle. Spend them here. Every run counts.",
	"HUB_HINT_DISMISS": "Got it",
	"HUB_WARNING_SAVE_FAILED": "Your progress could not be saved. It will retry automatically.",
	"HUB_WARNING_RECOVERED": "Your save could not be read; a new profile was started. The damaged file was kept as profile.corrupt.json.",
	"HUB_WARNING_READ_ONLY": "This save was made by a newer version of the game and is read-only here.",

	# --- Meta layer core: Skill Tree screen --------------------------------
	"SKILL_TREE_TITLE": "Skill Tree",
	"SKILL_TREE_BACK": "Back",
	"SKILL_TREE_RESPEC": "Reset Tree",
	"SKILL_TREE_RESPEC_DESC": "Refunds every Core spent and resets every rank to 0. Hub only.",
	"SKILL_TREE_RESPEC_REFUND": "Refund: %d Cores",
	"SKILL_TREE_RESPEC_NONE": "Nothing to refund",
	"SKILL_TREE_MAX": "MAX",
	"SKILL_TREE_RANK_OF": "Rank %d of %d",
	"SKILL_TREE_SILHOUETTE_NAME": "???",
	"SKILL_TREE_SILHOUETTE_HINT": "Unlocks a neighbouring node to reveal this one.",
	"SKILL_TREE_ALWAYS_OWNED": "The heart of the War Camp. Always yours.",
	# Polish pass (coordinator review): the root's own explanation, shown in
	# the detail panel when nothing else is selected.
	"SKILL_TREE_ROOT_EXPLANATION": "Earn Cores by playing runs. Select a node and hold Space / click / A to buy it -- buying reveals its neighbours. Reset Tree refunds every Core spent, any time, in the Hub only.",
	# Polish pass: names the actual keys/buttons the hold gesture accepts.
	"SKILL_TREE_HOLD_TO_BUY": "Hold Space / Click / A to buy",
	"SKILL_TREE_HOLD_TO_RESET": "Hold Space / Click / A to reset",
	"SKILL_TREE_BRANCH_ARCHER": "Archer",
	"SKILL_TREE_BRANCH_TOWER": "Tower",
	"SKILL_TREE_BRANCH_FORTUNE": "Fortune",

	# --- Meta layer core: Records panel -------------------------------------
	"RECORDS_TITLE": "Records",
	"RECORDS_BEST_WAVE": "Best wave reached",
	"RECORDS_LONGEST_TIME": "Longest time survived",
	"RECORDS_MOST_KILLS": "Most kills in a run",
	"RECORDS_RUNS": "Runs played",
	"RECORDS_VICTORIES": "Victories",
	"RECORDS_LIFETIME_CORES": "Lifetime Cores earned",
	"RECORDS_BACK": "Back",

	# --- D118: Achievements panel -------------------------------------------
	"ACHIEVEMENTS_TITLE": "Achievements",
	"ACHIEVEMENTS_BACK": "Back",
	"ACHIEVEMENTS_UNLOCKED": "Unlocked",
	"ACHIEVEMENTS_LOCKED": "Locked",

	"TITLE_GAME_NAME": "HORDE CONTROL",
	"TITLE_TAGLINE": "Defend the Tower. Survive the horde.",
	"TITLE_PLAY": "Play",
	"TITLE_CONTROLS": "Controls",
	"TITLE_CREDITS": "Credits",
	"TITLE_QUIT": "Quit",
	"TITLE_BACK": "Back",

	"TITLE_CONTROLS_TITLE": "Controls",
	"TITLE_CONTROLS_MOVE": "Move",
	"TITLE_CONTROLS_DRAFT_CYCLE": "Draft: cycle card",
	"TITLE_CONTROLS_DRAFT_SELECT": "Draft: select card",
	"TITLE_CONTROLS_CONFIRM": "Confirm",
	"TITLE_CONTROLS_REROLL": "Reroll",
	# D115 (no in-run shop): the four TITLE_CONTROLS_CONSOLE_* keys (Console
	# open/cycle/select/cancel control hints) are removed along with the
	# Console itself and the three rows in src/ui/title_screen.gd that
	# displayed them.
	"TITLE_CONTROLS_PAUSE": "Pause",
	"TITLE_CONTROLS_DEBUG_OVERLAY": "Debug overlay (dev)",
	"TITLE_CONTROLS_DEBUG_PSEUDOLOC": "Pseudo-localization (dev)",

	"TITLE_CREDITS_TITLE": "Credits",
	"TITLE_CREDITS_TINY_SWORDS": "Tiny Swords by Pixel Frog (CC0) - pixelfrog-assets.itch.io/tiny-swords",
	"TITLE_CREDITS_MUSIC": "\"Battle Theme A\" by cynicmusic (CC0) - opengameart.org",
	"TITLE_CREDITS_KENNEY": "Sound effects and sprites by Kenney (kenney.nl, CC0)",
	"TITLE_CREDITS_FONT": "Jersey 10 font by The Soft Type Project Authors (SIL OFL 1.1)",
	"TITLE_CREDITS_GODOT": "Made with Godot Engine (MIT) - godotengine.org",
}

static var _registered: bool = false


static func ensure_registered() -> void:
	if _registered:
		return
	_registered = true
	var translation := Translation.new()
	translation.locale = LOCALE
	for key: String in MESSAGES:
		translation.add_message(key, MESSAGES[key])
	TranslationServer.add_translation(translation)
