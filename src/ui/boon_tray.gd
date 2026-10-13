extends Control
class_name BoonTray
## Active Shrine boons: one pill per boon with its icon and a countdown (seconds, or
## kills left for Bounty). Register "v1.0 Arena Interactables", docs/32 section B. Its own Control under the HUD
## CanvasLayer (the HUD script is untouched), anchored top-left just under the
## player cluster and scaled with the HUD Scale setting. Reads
## ArenaInteractables.get_active_boons() (group "arena_interactables"); empty when
## no boon is active, so it takes no room.

const TOP_OFFSET_DESIGN_PX: float = 112.0 # below the player cluster (pill + XP bar) at scale 1
const ICON_SIZE_PX: int = 32
const LOW_TIME_SECONDS: float = 3.0
const BLINK_HZ: float = 4.0

var _row: HBoxContainer = null
var _entries: Dictionary = {} # boon id -> {"pill": PanelContainer, "label": Label}
var _applied_scale: float = -1.0
var _applied_canvas: Vector2 = Vector2.ZERO
var _applied_margins: Vector4 = Vector4.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.get_theme()
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.theme_type_variation = UiTheme.hbox("M")
	add_child(_row)
	_apply_scale()


func _process(_delta: float) -> void:
	_apply_scale()
	var mgr: Node = get_tree().get_first_node_in_group(&"arena_interactables")
	var boons: Array[Dictionary] = mgr.get_active_boons() if mgr != null and mgr.has_method(&"get_active_boons") else []
	_sync(boons)


## Anchors top-left under the player cluster, honouring the HUD Scale setting (same cap as the HUD).
func _apply_scale() -> void:
	var canvas: Vector2 = get_viewport().get_visible_rect().size
	var s: float = Hud.effective_scale(GameSettings.get_hud_scale(), canvas.x)
	var m: Vector4 = SafeArea.margins(get_window()) # D370: inside the phone's safe area, like the HUD frame
	if is_equal_approx(s, _applied_scale) and canvas == _applied_canvas and m == _applied_margins:
		return
	_applied_scale = s
	_applied_canvas = canvas
	_applied_margins = m
	scale = Vector2(s, s)
	var edge: float = Hud.HUD_PHONE_EDGE_PX if SafeArea.is_active() else float(UiPalette.SCREEN_MARGIN)
	position = Vector2(m.x, m.y) + Vector2(edge, edge + TOP_OFFSET_DESIGN_PX) * s


func get_entry_count() -> int:
	return _entries.size()


func get_label_text_for_test(id: String) -> String:
	return (_entries[id]["label"] as Label).text if _entries.has(id) else ""


func _sync(boons: Array[Dictionary]) -> void:
	var live: Dictionary = {}
	for b in boons:
		var id: String = b["id"]
		live[id] = true
		if not _entries.has(id):
			_add_entry(id)
		var entry: Dictionary = _entries[id]
		var label: Label = entry["label"]
		var pill: PanelContainer = entry["pill"]
		if id == ArenaBoon.BOUNTY:
			label.text = "x%d" % int(b["kills_left"])
			pill.modulate.a = 1.0
		else:
			var remaining: float = float(b["remaining"])
			label.text = "%ds" % int(ceil(remaining))
			var blink: bool = remaining < LOW_TIME_SECONDS and not GameSettings.is_reduce_flashing()
			pill.modulate.a = 1.0 if not blink or int(SimClock.now * BLINK_HZ * 2.0) % 2 == 0 else 0.45
	for id in _entries.keys():
		if not live.has(id):
			(_entries[id]["pill"] as Node).queue_free()
			_entries.erase(id)


func _add_entry(id: String) -> void:
	var pill := PanelContainer.new()
	pill.name = "Boon_%s" % id
	pill.theme_type_variation = UiTheme.PILL
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.theme_type_variation = UiTheme.hbox("M")
	pill.add_child(box)
	var icon := TextureRect.new()
	icon.texture = load(ArenaBoon.icon_path(id)) as Texture2D
	icon.custom_minimum_size = Vector2(ICON_SIZE_PX, ICON_SIZE_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label := Label.new()
	label.theme_type_variation = UiTheme.HUD_VALUE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(44, 0)
	box.add_child(label)
	_row.add_child(pill)
	_entries[id] = {"pill": pill, "label": label}
