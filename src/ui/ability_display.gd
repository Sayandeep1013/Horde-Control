extends RefCounted
class_name AbilityDisplay
## Display names and icons for every ability, Battle Skill and damage-source id
## (WP-META, D254). The Results screen's damage report and the War Camp's Battle
## Skill picker both read it, so a source id is spelled and drawn the same way
## everywhere. Names go through UiStrings ("ABILITY_NAME_<ID>"); an unknown id
## falls back to a capitalised id so a new ability still reads sensibly.

const ICON_DIR: String = "res://assets/ui/icons/"
const FALLBACK_ICON: String = "icon_square"

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
		candidates.append(ICON_DIR + "icon_dynamite_satchel.png")
	elif id == AbilityIds.SOURCE_SPIKES:
		candidates.append(ICON_DIR + "icon_caltrops.png")
	candidates.append(ICON_DIR + FALLBACK_ICON + ".png")
	var tex: Texture2D = null
	for path in candidates:
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	_icon_cache[id] = tex
	return tex


## Shutdown hygiene (ShutdownHygiene).
static func release_caches() -> void:
	_icon_cache.clear()
