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

	"CONSOLE_TITLE": "Tower Console",
	"CONSOLE_HEADER_PLAYER": "PLAYER",
	"CONSOLE_HEADER_TOWER": "TOWER",
	"CONSOLE_REPAIR": "Repair",
	"CONSOLE_REPAIR_FOOTER": "Restores %d HP for %d Scrap",
	"CONSOLE_HP": "HP",
	"CONSOLE_SCRAP": "Scrap",
	"CONSOLE_RANK": "Rank",
	"CONSOLE_OF": "of",
	"CONSOLE_MAX": "MAX",
	"CONSOLE_TAKEN": "Taken",

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
	"RUN_END_CAUSE": "Cause",
	"RUN_END_CAUSE_PLAYER": "You were defeated",
	"RUN_END_CAUSE_TOWER": "The Tower was destroyed",
	"RUN_END_WAVE_REACHED": "Wave reached",
	"RUN_END_SCRAP_HELD": "Scrap held",
	"RUN_END_TIME_SURVIVED": "Time survived",
	"RUN_END_SETTINGS": "Settings",
	"RUN_END_MAIN_MENU": "Main Menu",

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
	"TITLE_CONTROLS_CONSOLE_CYCLE": "Console: cycle entry",
	"TITLE_CONTROLS_CONSOLE_SELECT": "Console: select entry",
	"TITLE_CONTROLS_CONSOLE_CANCEL": "Console: cancel",
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
