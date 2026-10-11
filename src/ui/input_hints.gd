class_name InputHints
extends RefCounted

## Live key hints for the HUD and How to Play: reads the Input Map as it is
## NOW, so a rebinding in Settings shows up without a restart.


## "Space", "E", "RMB" ... the first keyboard binding of `action`, else its
## mouse button, else "". Never a hard-coded key name.
static func key_text(action: StringName) -> String:
	var all: Array[String] = key_texts(action)
	return all[0] if not all.is_empty() else ""


## Every keyboard binding, then mouse buttons, in Input Map order.
static func key_texts(action: StringName) -> Array[String]:
	var out: Array[String] = []
	if not InputMap.has_action(action):
		return out
	var mouse: Array[String] = []
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var key := ev as InputEventKey
			var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			if code != 0:
				out.append(GameSettings.key_label(code))
		elif ev is InputEventMouseButton:
			mouse.append(_mouse_text((ev as InputEventMouseButton).button_index))
	out.append_array(mouse)
	return out


static func joined(action: StringName, separator: String = " / ") -> String:
	return separator.join(key_texts(action))


static func _mouse_text(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return "LMB"
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		MOUSE_BUTTON_MIDDLE:
			return "MMB"
		_:
			return "Mouse %d" % button
