class_name AbilityNames
extends RefCounted

## Display names for ability, Battle Skill and passive ids. Names live in
## UiStrings as ABILITY_<ID>; an id with no entry (a card another package adds)
## falls back to a readable form of the id instead of showing a raw key.


static func display(id: String) -> String:
	var key: String = "ABILITY_" + id.to_upper()
	var text: String = TranslationServer.translate(StringName(key))
	if text == key or text == "":
		return id.replace("_", " ").capitalize()
	return text
