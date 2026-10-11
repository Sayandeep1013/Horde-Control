extends RefCounted
class_name AbilityDisplay
## Display names and icons for every ability, Battle Skill and damage-source id
## (WP-META, D254). The Results screen's damage report and the War Camp's Battle
## Skill picker both read it, so a source id is spelled and drawn the same way
## everywhere. Names go through UiStrings ("ABILITY_NAME_<ID>"); an unknown id
## falls back to a capitalised id so a new ability still reads sensibly.

const ICON_DIR: String = "res://assets/ui/icons/"
const FALLBACK_ICON: String = "icon_square"

## Boss ids the rest of the game uses (EventBus.boss_spawned, MetaProgress) -> the icon's id.
const BOSS_ICON_ALIASES: Dictionary = {"warchief": "goblin_warchief", "king": "bombardier_king"}
const ICON_PX_DEFAULT: int = 64

static var _icon_cache: Dictionary = {} # id -> Texture2D


static func display_name(id: String) -> String:
	UiStrings.ensure_registered()
	var key: String = "ABILITY_NAME_%s" % id.to_upper()
	var text: String = TranslationServer.translate(key)
	return id.capitalize() if text == key else text


## Icon for an id: icon_<id>.png, else the Tower/bow family, else a plain square.
static func icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var candidates: Array[String] = [ICON_DIR + "icon_%s.png" % id]
	if id == AbilityIds.SOURCE_BOW:
		candidates.append(ICON_DIR + "icon_arrow.png")
	elif id == AbilityIds.SOURCE_TOWER_BOW:
		candidates.append(ICON_DIR + "icon_tower.png")
	elif id == AbilityIds.SOURCE_STATUS_BURN:
		candidates.append(ICON_DIR + "icon_burn.png")
	elif id == AbilityIds.SOURCE_KEG:
		candidates.append(ICON_DIR + "icon_powder_keg.png")
		candidates.append(ICON_DIR + "icon_dynamite_satchel.png")
	elif id == AbilityIds.SOURCE_SPIKES:
		candidates.append(ICON_DIR + "icon_spike_trap.png")
		candidates.append(ICON_DIR + "icon_caltrops.png")
	elif BOSS_ICON_ALIASES.has(id):
		candidates.append(ICON_DIR + "icon_%s.png" % BOSS_ICON_ALIASES[id])
	candidates.append(ICON_DIR + FALLBACK_ICON + ".png")
	var tex: Texture2D = null
	for path in candidates:
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	_icon_cache[id] = tex
	return tex


## True when `id` has a real icon of its own (not the plain-square fallback).
static func has_icon(id: String) -> bool:
	if id == "":
		return false
	var tex: Texture2D = icon(id)
	return tex != null and tex != icon(FALLBACK_ICON.trim_prefix("icon_"))


## The icon as a pixel-crisp TextureRect `side` px square (the Draft cards, the Field Guide
## and the explainers share it). An id with no icon gets `fallback_id`'s (default: the plain square).
static func make_icon_rect(id: String, side: int = ICON_PX_DEFAULT, fallback_id: String = "") -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Icon"
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = icon(id if has_icon(id) or fallback_id == "" else fallback_id)
	return rect


## Shutdown hygiene (ShutdownHygiene).
static func release_caches() -> void:
	_icon_cache.clear()
