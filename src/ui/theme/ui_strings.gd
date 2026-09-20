extends RefCounted
class_name UiStrings

## UiStrings (UI pass). The English text for every `tr()` key the UI uses,
## registered with TranslationServer at runtime.
##
## Why this exists: the project calls `tr("HUD_WAVE")` and 32 other keys, but
## ships no translation file and registers none in `project.godot`, so every
## one of them rendered as its raw key ("HUD_WAVE 1/8", "HUD_LEVEL 0") in the
## scene a human launches. `project.godot` is outside the UI pass's write
## scope, so the strings are registered from code instead. The durable fix -
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
	"CONSOLE_GLYPH_PLAYER": "●",
	"CONSOLE_GLYPH_TOWER": "■",
	"CONSOLE_REPAIR": "Repair",
	"CONSOLE_HP": "HP",
	"CONSOLE_SCRAP": "Scrap",
	"CONSOLE_RANK": "Rank",
	"CONSOLE_OF": "of",
	"CONSOLE_MAX": "MAX",
	"CONSOLE_TAKEN": "Taken",

	"PAUSE_MENU_TITLE": "Paused",
	"PAUSE_MENU_RESUME": "Resume",
	"PAUSE_MENU_SETTINGS": "Settings",

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
