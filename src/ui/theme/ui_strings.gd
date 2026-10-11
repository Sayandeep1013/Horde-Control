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
	"HUD_SCRAP_CORES": "~ %d Cores at run end",
	"HUD_FULL": "FULL",
	"HUD_HOPPER": "hopper",
	# v1.0 HUD (docs/31 8.1): no captions; these are the few words that remain.
	"HUD_REPAIRING": "REPAIRING",
	"WAVE_TYPE_STANDARD": "STANDARD",
	"WAVE_TYPE_SPLIT": "SPLIT",
	"WAVE_TYPE_SIEGE": "SIEGE",
	"WAVE_TYPE_HUNT": "HUNT",
	"WAVE_TYPE_GRAND_ASSAULT": "GRAND ASSAULT",
	"WAVE_TYPE_BOSS": "BOSS",
	"ELITE_CALLOUT": "ELITE · %s",
	"ELITE_AFFIX_SWIFT": "SWIFT",
	"ELITE_AFFIX_ARMORED": "ARMORED",
	"ELITE_AFFIX_VOLATILE": "VOLATILE",
	"ELITE_AFFIX_VAMPIRIC": "VAMPIRIC",

	"DRAFT_TITLE": "Level up! Choose an upgrade",
	# UX review P0-4 (D128): every way to pick, from project.godot's input map.
	"DRAFT_HOW_TO_PICK": "Click a card  |  keys 1 / 2 / 3  |  A / D, then Space  |  or hold W / Up",
	"DRAFT_HOLD_CAPTION": "Hold W / Up to pick",
	"DRAFT_REROLL": "Reroll: R (%d left)",
	"DRAFT_REROLL_NONE": "No rerolls left",

	# UX review items 4 and 9 (D129/D130): run objective, first-run hints, wave banners.
	"HINT_OBJECTIVE": "Protect yourself and the Tower - hold %d waves and slay the Bombardier King",
	"HINT_OBJECTIVE_NO_COUNT": "Protect yourself and the Tower - survive every wave",
	"HINT_AUTOFIRE": "Your bow fires automatically at the nearest goblin. Just move (WASD).",
	"HINT_PICKUPS": "Walk over crystals (XP) and gold sacks (Scrap) to collect them.",
	"HINT_ENEMIES": "Red torch goblins attack the Tower. Yellow TNT goblins hunt you. Purple barrels go for whichever is exposed.",
	"BANNER_WAVE": "Wave %d",
	"BANNER_SIEGE": "Siege incoming",
	"BANNER_WAVE_TYPED": "WAVE %d · %s",
	"BANNER_SIEGE_WARNING": "SIEGE INCOMING",

	# D115 (no in-run shop): every CONSOLE_* key (Tower Console UI text) is
	# removed along with the Console itself -- nothing left registers or
	# reads them (verified by grep before removal).

	"PAUSE_MENU_TITLE": "Paused",
	"PAUSE_MENU_RESUME": "Resume",
	"PAUSE_MENU_SETTINGS": "Settings",
	"PAUSE_MENU_HOW_TO_PLAY": "How to Play",
	"PAUSE_BUILD_TITLE": "Build",
	"PAUSE_BUILD_SKILL": "Battle Skill",
	"PAUSE_BUILD_ABILITIES": "Abilities",
	"PAUSE_BUILD_TOWER_ABILITIES": "Tower",
	"PAUSE_BUILD_PASSIVES": "Passives",
	"PAUSE_BUILD_NONE": "None yet",
	"PAUSE_BUILD_DIFFICULTY": "Difficulty",
	"PAUSE_BUILD_SEED": "Seed",
	"PAUSE_STATS_TITLE": "Run stats",
	"PAUSE_STAT_TIME": "Time",
	"PAUSE_STAT_KILLS": "Kills",
	"PAUSE_STAT_ELITES": "Elites",
	"PAUSE_STAT_DAMAGE_TAKEN": "Damage taken",
	"PAUSE_STAT_SCRAP_REPAIRED": "Scrap repaired",
	"PAUSE_STAT_CORES": "Est. Cores",
	"PAUSE_LEVEL_RANK": "Lv %d",
	"PAUSE_PASSIVE_RANK": "%s %d/%d",
	"PAUSE_MENU_MAIN_MENU": "Abandon run",
	# Ability, Battle Skill and passive display names (docs/31 sections 3-4); AbilityNames.display().
	"ABILITY_ARROW_STORM": "Arrow Storm",
	"ABILITY_FROST_NOVA": "Frost Nova",
	"ABILITY_FIREBOMB": "Firebomb",
	"ABILITY_WAR_HORN": "War Horn",
	"ABILITY_FLAME_ARROWS": "Flame Arrows",
	"ABILITY_FROST_ARROWS": "Frost Arrows",
	"ABILITY_WHIRLING_AXES": "Whirling Axes",
	"ABILITY_DYNAMITE_SATCHEL": "Dynamite Satchel",
	"ABILITY_STORM_BOLT": "Storm Bolt",
	"ABILITY_CALTROPS": "Caltrops",
	"ABILITY_SACRED_GROUND": "Sacred Ground",
	"ABILITY_BALLISTA": "Ballista",
	"ABILITY_CATAPULT": "Catapult",
	"ABILITY_FROST_WARD": "Frost Ward",
	"ABILITY_SPIKED_PALISADE": "Spiked Palisade",
	"ABILITY_FLEET_STEP": "Fleet Step",
	"ABILITY_BATTLE_FOCUS": "Battle Focus",
	"ABILITY_BLAST_RADIUS": "Blast Radius",
	"ABILITY_KEEN_EYE": "Keen Eye",
	"ABILITY_LEATHER_ARMOR": "Leather Armor",
	"ABILITY_ABILITY_POWER": "War Training",
	"ABILITY_STONE_MASON": "Stone Mason",

	"PAUSE_MENU_ABANDON_TITLE": "Abandon run? Progress so far still earns Cores",
	"PAUSE_MENU_ABANDON_CANCEL": "Keep playing",
	"PAUSE_MENU_ABANDON_CONFIRM": "Abandon",

	"SETTINGS_MENU_TITLE": "Settings",
	"SETTINGS_MOVEMENT_ONLY": "Movement-only controls",
	"SETTINGS_ON": "On",
	"SETTINGS_OFF": "Off",
	"SETTINGS_BACK": "Back",
	# Settings screen rebuild (Review Decision Log D121): the row-list's own
	# nine adjustable rows, plus the three Display Mode values.
	"SETTINGS_MASTER_VOLUME": "Master Volume",
	"SETTINGS_MUSIC_VOLUME": "Music Volume",
	"SETTINGS_EFFECTS_VOLUME": "Sound Effects Volume",
	"SETTINGS_MUTE_ALL": "Mute All",
	"SETTINGS_DISPLAY_MODE": "Display Mode",
	"SETTINGS_DISPLAY_WINDOWED": "Windowed",
	"SETTINGS_DISPLAY_FULLSCREEN": "Fullscreen",
	"SETTINGS_DISPLAY_BORDERLESS": "Borderless",
	"SETTINGS_VSYNC": "V-Sync",
	"SETTINGS_SCREEN_SHAKE": "Screen Shake",
	"SETTINGS_DAMAGE_NUMBERS": "Damage Numbers",
	# v1.0 tabbed Settings (docs/31 8.4).
	"SETTINGS_TAB_AUDIO": "Audio",
	"SETTINGS_TAB_VIDEO": "Video",
	"SETTINGS_TAB_GAMEPLAY": "Gameplay",
	"SETTINGS_TAB_CONTROLS": "Controls",
	"SETTINGS_TAB_ACCESSIBILITY": "Accessibility",
	"SETTINGS_INTERFACE_VOLUME": "Interface Volume",
	"SETTINGS_WINDOW_SIZE": "Window Size",
	"SETTINGS_WINDOW_SIZE_LOCKED": "Windowed only",
	"SETTINGS_FPS_LIMIT": "FPS Limit",
	"SETTINGS_FPS_UNLIMITED": "Unlimited",
	"SETTINGS_SHOW_FPS": "Show FPS",
	"SETTINGS_AUTO_CAST": "Auto-cast Battle Skill",
	"SETTINGS_SHOW_OVERHEAD_BARS": "Show Overhead Bars",
	"SETTINGS_PAUSE_UNFOCUSED": "Pause When Unfocused",
	"SETTINGS_HUD_SCALE": "HUD Scale",
	"SETTINGS_REDUCE_FLASHING": "Reduce Flashing",
	"SETTINGS_ENEMY_OUTLINES": "Enemy Outlines",
	"SETTINGS_RESET_CONTROLS": "Reset Controls",
	"SETTINGS_RESET_DEFAULTS": "Reset to Defaults",
	"SETTINGS_RESET_CONFIRM": "Press again",
	"SETTINGS_REBIND_PROMPT": "Press a key...",
	"SETTINGS_REBIND_HINT": "Left / Right picks the slot, Confirm rebinds, Esc cancels.",
	"SETTINGS_GAMEPAD_NOTE": "Gamepad is fixed: stick moves, B / LB dashes, Y / RB casts the Battle Skill, Start pauses.",
	"SETTINGS_ACTION_MOVE_UP": "Move Up",
	"SETTINGS_ACTION_MOVE_DOWN": "Move Down",
	"SETTINGS_ACTION_MOVE_LEFT": "Move Left",
	"SETTINGS_ACTION_MOVE_RIGHT": "Move Right",
	"SETTINGS_ACTION_DASH": "Dash",
	"SETTINGS_ACTION_BATTLE_SKILL": "Battle Skill",
	"SETTINGS_ACTION_PAUSE": "Pause",

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
	"RUN_END_SEED": "Seed: %d",
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
	"HUB_SETTINGS": "Settings",
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
	"SKILL_TREE_ROOT_EXPLANATION": "Earn Cores by playing runs. Select a node, then click it (or hold Space / A) to buy it -- buying reveals its neighbours. Reset Tree refunds every Core spent, any time, in the Hub only.",
	# Polish pass: names the actual keys/buttons the hold gesture accepts.
	"SKILL_TREE_HOLD_TO_BUY": "Click, or hold Space / A, to buy",
	"SKILL_TREE_HOLD_TO_RESET": "Hold Space / Click / A to reset",
	"SKILL_TREE_BRANCH_ARCHER": "Archer",
	"SKILL_TREE_BRANCH_TOWER": "Tower",
	"SKILL_TREE_BRANCH_FORTUNE": "Fortune",
	"SKILL_TREE_LEGEND_OWNED": "Owned",
	"SKILL_TREE_LEGEND_AVAILABLE": "Available",
	"SKILL_TREE_LEGEND_UNAFFORDABLE": "Can't afford",
	"SKILL_TREE_LEGEND_LOCKED": "Locked",

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
	"ACHIEVEMENTS_REWARD_CARD": "Unlocks card: %s",
	"ACHIEVEMENTS_REWARD_PERK": "Reward: %s",
	"ACHIEVEMENTS_PERK_REROLL": "+1 Draft reroll each run",
	"ACHIEVEMENTS_PERK_DAMAGE": "+%d%% weapon damage",
	"ACHIEVEMENTS_PERK_CORES": "+%d%% Cores at run end",

	"TITLE_GAME_NAME": "HORDE CONTROL",
	"TITLE_TAGLINE": "Defend the Tower. Survive the horde.",
	"TITLE_PLAY": "Play",
	"TITLE_CONTROLS": "Controls",
	"TITLE_HOW_TO_PLAY": "How to Play",
	"TITLE_CREDITS": "Credits",
	"TITLE_SETTINGS": "Settings",
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
	"TITLE_CONTROLS_DASH": "Dash",
	"TITLE_CONTROLS_SKILL": "Battle Skill",
	"TITLE_CONTROLS_DEBUG_OVERLAY": "Debug overlay (dev)",
	"TITLE_CONTROLS_DEBUG_PSEUDOLOC": "Pseudo-localization (dev)",

	# How to Play (docs/31 8.5): four short sections. %s slots hold the live key bindings.
	"HOWTO_TITLE": "How to Play",
	"HOWTO_1_HEAD": "Protect yourself and the Tower",
	"HOWTO_1_BODY": "You and the Tower each have a health bar, and losing either ends the run. Your bow fires on its own, so just move (%s).",
	"HOWTO_2_HEAD": "Dash and Battle Skill",
	"HOWTO_2_BODY": "Press %s to dash; you cannot be hurt mid-dash. Press %s for your Battle Skill. It recharges, and Auto-cast in Settings uses it for you.",
	"HOWTO_3_HEAD": "Draft: abilities, passives and Tower cards",
	"HOWTO_3_BODY": "Each level-up offers three cards. Abilities add new attacks (4 for you, 3 for the Tower) and level up to 5. Passives raise stats. Tower cards strengthen the Tower.",
	"HOWTO_4_HEAD": "Repair with Scrap",
	"HOWTO_4_BODY": "Collect Scrap, then stand near the Tower: the Scrap you carry repairs it. Scrap left at the end becomes Cores, so spend it when it counts.",
	"HOWTO_BACK": "Back",

	"TITLE_CREDITS_TITLE": "Credits",
	"TITLE_CREDITS_TINY_SWORDS": "Tiny Swords by Pixel Frog (CC0) - pixelfrog-assets.itch.io/tiny-swords",
	"TITLE_CREDITS_MUSIC": "\"Battle Theme A\" by cynicmusic (CC0) - opengameart.org",
	"TITLE_CREDITS_KENNEY": "Sound effects and sprites by Kenney (kenney.nl, CC0)",
	"TITLE_CREDITS_FONT": "Jersey 10 font by The Soft Type Project Authors (SIL OFL 1.1)",
	"TITLE_CREDITS_GODOT": "Made with Godot Engine (MIT) - godotengine.org",

	# --- WP-META (D250-D254): Skill Tree v2, achievements, War Camp pickers, Results ---
	"SKILL_TREE_BRANCH_SURVIVAL": "Survival",
	"SKILL_TREE_BRANCH_BATTLE": "Battle Skills",
	"SKILL_TREE_LEGEND_OWNED_MAX": "Maxed",
	"ACHIEVEMENTS_PERK_MOVE_SPEED": "+%d%% move speed",
	"ACHIEVEMENTS_PERK_REPAIR": "+%d%% Tower repair per Scrap",
	"ACHIEVEMENTS_PERK_LUCK": "+%d luck",
	"ACHIEVEMENTS_PERK_XP": "+%d%% experience",
	"ACHIEVEMENTS_PERK_ABILITY_DAMAGE": "+%d%% ability damage",
	"ACHIEVEMENTS_PERK_START_SCRAP": "+%d starting Scrap",
	"ACHIEVEMENTS_PERK_WARLORD": "Warlord title and a gold Tower",
	"ACHIEVEMENTS_PERK_REGICIDE": "+%d%% Cores (adds to other bonuses)",
	"ACHIEVEMENTS_PER_RUN": "In one run",
	"RECORDS_BEST_ENDLESS": "Best Endless wave",
	"RECORDS_ELITES": "Elites defeated",
	"RECORDS_BOSSES": "Bosses defeated",
	"HUB_SETUP_TITLE": "Run Setup",
	"HUB_DIFFICULTY": "Difficulty",
	"HUB_BATTLE_SKILL": "Battle Skill",
	"HUB_ENDLESS": "Endless mode",
	"HUB_ENDLESS_ON": "Endless: On",
	"HUB_ENDLESS_OFF": "Endless: Off",
	"HUB_ENDLESS_HINT": "After the Final Boss the waves keep coming. Fight for your best wave.",
	"HUB_LOCKED_DIFFICULTY": "Locked. Win a run on %s to open it.",
	"HUB_LOCKED_SKILL": "Locked. Buy %s in the Skill Tree.",
	"HUB_V3_NOTICE": "The Skill Tree was rebuilt. Your Cores were refunded.",
	"HUB_V3_NOTICE_AMOUNT": "You got %d Cores back.",
	"HUB_START_RUN_SETUP": "Start Run",
	"ABILITY_NAME_ARROW_STORM": "Arrow Storm",
	"ABILITY_NAME_FROST_NOVA": "Frost Nova",
	"ABILITY_NAME_FIREBOMB": "Firebomb",
	"ABILITY_NAME_WAR_HORN": "War Horn",
	"ABILITY_NAME_FLAME_ARROWS": "Flame Arrows",
	"ABILITY_NAME_FROST_ARROWS": "Frost Arrows",
	"ABILITY_NAME_WHIRLING_AXES": "Whirling Axes",
	"ABILITY_NAME_DYNAMITE_SATCHEL": "Dynamite Satchel",
	"ABILITY_NAME_STORM_BOLT": "Storm Bolt",
	"ABILITY_NAME_CALTROPS": "Caltrops",
	"ABILITY_NAME_SACRED_GROUND": "Sacred Ground",
	"ABILITY_NAME_BALLISTA": "Ballista",
	"ABILITY_NAME_CATAPULT": "Catapult",
	"ABILITY_NAME_FROST_WARD": "Frost Ward",
	"ABILITY_NAME_SPIKED_PALISADE": "Spiked Palisade",
	"ABILITY_NAME_BOW": "Bow",
	"ABILITY_NAME_TOWER_BOW": "Tower Bow",
	"ABILITY_NAME_BURN": "Burning",
	"ABILITY_DESC_ARROW_STORM": "Arrows rain on the thickest crowd near you.",
	"ABILITY_DESC_FROST_NOVA": "A freezing burst around you slows everything.",
	"ABILITY_DESC_FIREBOMB": "Lob dynamite and leave burning ground.",
	"ABILITY_DESC_WAR_HORN": "Restores the Tower shield and speeds up every bow.",
	"RESULTS_RETRY": "Retry",
	"RESULTS_WAR_CAMP": "War Camp",
	"RESULTS_DIFFICULTY": "Difficulty: %s",
	"RESULTS_ENDLESS_TAG": "Endless",
	"RESULTS_WAVES": "Waves: %d/%d",
	"RESULTS_WAVES_ENDLESS": "Wave reached: %d",
	"RESULTS_KILLS": "Kills: %d",
	"RESULTS_ELITES": "Elites: %d",
	"RESULTS_DAMAGE_TITLE": "Damage by source",
	"RESULTS_NO_DAMAGE": "No damage recorded this run.",
	"RESULTS_SETTLEMENT_TITLE": "Cores earned",
	"RESULTS_NEW_BEST_ENDLESS": "NEW BEST -- Endless wave",
	"RESULTS_UNLOCKED_DIFFICULTY": "%s difficulty unlocked",
	"RESULTS_UNLOCKED_ENDLESS": "Endless mode unlocked",
	"RESULTS_WARLORD_TITLE": "Warlord",
}

## D147: keyboard-and-mouse wording replaced by touch wording in the mobile
## layout (a phone build, or `--touch-ui`). Same keys; `ensure_registered()`
## picks one table once. A key absent here keeps its desktop text.
const MOBILE_MESSAGES: Dictionary = {
	"DRAFT_HOW_TO_PICK": "Tap a card to pick it",
	"DRAFT_HOLD_CAPTION": "Or hold up to pick",
	"DRAFT_REROLL": "Reroll (%d left)",
	"HINT_AUTOFIRE": "Your bow fires automatically at the nearest goblin. Just move: drag on the left side of the screen.",
	"HOWTO_1_BODY": "You and the Tower each have a health bar, and losing either ends the run. Your bow fires on its own, so just drag on the left side of the screen to move.",
	"HOWTO_2_BODY": "Tap the Dash button to dash; you cannot be hurt mid-dash. Tap the big Battle Skill button to cast it. It recharges, and Auto-cast in Settings uses it for you.",
	"SKILL_TREE_ROOT_EXPLANATION": "Earn Cores by playing runs. Tap a node, then tap it again (or press and hold) to buy it -- buying reveals its neighbours. Reset Tree refunds every Core spent, any time, in the Hub only.",
	"SKILL_TREE_HOLD_TO_BUY": "Tap again, or press and hold, to buy",
	"SKILL_TREE_HOLD_TO_RESET": "Press and hold to reset",
}

static var _registered: bool = false


static func ensure_registered() -> void:
	if _registered:
		return
	_registered = true
	var translation := Translation.new()
	translation.locale = LOCALE
	var mobile: bool = TouchUi.is_mobile_layout_real()
	for key: String in MESSAGES:
		translation.add_message(key, MOBILE_MESSAGES.get(key, MESSAGES[key]) if mobile else MESSAGES[key])
	TranslationServer.add_translation(translation)
