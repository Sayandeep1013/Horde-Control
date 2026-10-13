extends Node

## Phone layout audit (dev-only, D370). Opens every screen at one window size and
## reports, machine-readably, every visible Control whose rect leaves the viewport or
## the (simulated) safe area, every text whose box clips it, text drawn under the
## readable minimum, and text/button overlaps. Nothing in scenes/ references it.
##
##   Godot_v4.7.1-stable_win64_console.exe --path . --audio-driver Dummy \
##     res://src/dev/layout_audit.tscn -- --size=2400x1080 --touch-ui \
##     [--safe-inset=110,0,0,40] [--screens=title,hub_run,...] [--out=sandbox/audit/a.json] \
##     [--shots=sandbox/captures/mobile_layout/a] --meta-profile-dir=<absolute temp dir>
##
## Prints `AUDIT <screen> errors=N warns=M` per screen and `AUDIT_TOTAL errors=N warns=M`,
## and with `--out=` writes every finding as JSON (one object per screen). Severity:
##   error  text / button / slider that leaves the safe area, is cut by a clipping
##          ancestor, or whose text is clipped by its own box
##   warn   panel or icon outside the safe area, a child past its container,
##          text under the readable minimum, text-over-text overlap
## The staging reaches into a few private members (like pt_ui_capture); nothing in the
## game depends on this file.

const TOLERANCE_PX: float = 1.5
## Short side of a typical phone in dp (landscape); 14 dp is the readable floor (task brief).
const PHONE_SHORT_SIDE_DP: float = 400.0
const MIN_TEXT_DP: float = 14.0
const OVERLAP_MIN_AREA: float = 30.0

var _size: Vector2i = Vector2i(2400, 1080)
var _only: PackedStringArray = PackedStringArray()
var _out: String = ""
var _shots: String = ""
var _results: Array = []
var _total_errors: int = 0
var _total_warns: int = 0
var _scene: Node = null
var _screen_name: String = ""
var _touch: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	GameSettings.set_show_first_time_tips_for_test(false)
	_touch = TouchUi.is_mobile_layout()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var p: PackedStringArray = arg.trim_prefix("--size=").split("x")
			_size = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--screens="):
			_only = arg.trim_prefix("--screens=").split(",")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
	var window: Window = get_window()
	window.size = _size
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _run() -> void:
	await _frames(5)
	for entry: Array in _screens():
		var sname: String = entry[0]
		if not _only.is_empty() and not _only.has(sname) and not _only.has(sname.get_slice(":", 0)):
			continue
		_screen_name = sname
		await (entry[1] as Callable).call()
		await _frames(2)
		_audit(sname)
		if _shots != "":
			await _shoot(sname)
		await _teardown()
	print("WINDOW size=", get_window().size, " scale=", get_window().content_scale_factor, " final=", get_window().get_final_transform())
	print("AUDIT_TOTAL size=%dx%d touch=%s errors=%d warns=%d" % [_size.x, _size.y, str(_touch), _total_errors, _total_warns])
	if _out != "":
		var path: String = ProjectSettings.globalize_path("res://").path_join(_out)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"size": [_size.x, _size.y], "touch": _touch, "errors": _total_errors, "warns": _total_warns, "screens": _results}, "\t"))
		f.close()
	get_tree().quit()


func _shoot(sname: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://").path_join("%s_%s.png" % [_shots, sname.replace(":", "_")])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)


func _teardown() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null
	TouchUi.set_scale_suspended(get_window(), false) # a Skill Tree freed while open would leave the scale suspended
	for reason: StringName in PauseAuthority.get_active_reasons(): # a Draft freed while open leaves its pause reason behind
		PauseAuthority.pop_reason_immediate(reason)
	get_tree().paused = false
	await _frames(3)


func _add(node: Node) -> Node:
	add_child(node)
	_scene = node
	return node


# ---------------------------------------------------------------------------
# The audit
# ---------------------------------------------------------------------------

func _audit(sname: String) -> void:
	var window: Window = get_window()
	var canvas: Vector2 = SafeArea.canvas_size(window)
	var safe: Rect2 = SafeArea.rect(window)
	var canvas_rect := Rect2(Vector2.ZERO, canvas)
	var findings: Array = []
	var controls: Array[Control] = []
	_collect(get_tree().root, controls)
	var density: float = PHONE_SHORT_SIDE_DP / minf(canvas.x, canvas.y) # dp per logical px
	var texts: Array[Dictionary] = []
	for c: Control in controls:
		var cls: String = _kind(c)
		if cls == "" or (cls != "text" and cls != "button" and _under_decor(c)):
			continue
		var rect: Rect2 = _global_rect(c)
		if rect.size.x < 1.0 or rect.size.y < 1.0:
			continue
		# a full-screen backdrop is allowed to bleed
		if rect.size.x >= canvas.x * 0.95 and rect.size.y >= canvas.y * 0.95 and cls != "text" and cls != "button":
			continue
		var eff: Rect2 = _text_extent(c, rect) if cls == "text" else rect
		var clipped_by: String = ""
		var hidden: bool = false
		var a: Node = c.get_parent()
		while a != null and a != get_tree().root:
			if a is Control and _clips(a as Control):
				var ar: Rect2 = _global_rect(a as Control)
				var inter: Rect2 = eff.intersection(ar)
				if inter.size.x <= 0.0 or inter.size.y <= 0.0:
					hidden = true
					clipped_by = String(a.name)
					break
				if not inter.is_equal_approx(eff):
					clipped_by = String(a.name)
				eff = inter
			a = a.get_parent()
		if hidden:
			if not _scrollable_ancestor(c):
				findings.append(_f("error", "clipped_away", c, rect, "fully clipped by %s" % clipped_by))
			continue
		if clipped_by != "" and not _scrollable_ancestor(c):
			findings.append(_f("error" if cls in ["text", "button"] else "warn", "clipped", c, rect, "cut by %s" % clipped_by))
		var sev: String = "error" if cls in ["text", "button"] else "warn"
		var out_v: String = _outside(eff, canvas_rect)
		if out_v != "":
			findings.append(_f(sev, "outside_viewport", c, rect, out_v))
		else:
			var out_s: String = _outside(eff, safe)
			if out_s != "":
				findings.append(_f(sev, "outside_safe", c, rect, out_s))
		# the control's own box vs its content
		if cls == "text" or cls == "button":
			var clip_msg: String = _text_clipped(c)
			if clip_msg != "":
				findings.append(_f("error", "text_clipped", c, rect, clip_msg))
			var fs: int = _font_size(c)
			# the dp model (400 dp short side) is a phone's; it is wrong for a tablet aspect
			if _touch and canvas.x / canvas.y >= 1.7 and fs >= 8 and _has_text(c) and float(fs) * density < MIN_TEXT_DP - 0.01:
				findings.append(_f("warn", "small_text", c, rect, "%d px = %.1f dp" % [fs, float(fs) * density]))
			if _has_text(c):
				texts.append({"c": c, "r": eff})
		# child past its container
		if c.get_parent() is Container and not (c.get_parent() is ScrollContainer):
			var pr: Rect2 = _global_rect(c.get_parent() as Control)
			if pr.size.x > 4.0 and pr.size.y > 4.0 and not pr.grow(TOLERANCE_PX).encloses(rect) and (cls == "text" or cls == "button") and not _clips_any_ancestor(c):
				findings.append(_f("warn", "past_container", c, rect, "parent %s %s" % [c.get_parent().name, _rs(pr)]))
	# text overlaps
	for i: int in texts.size():
		for j: int in range(i + 1, texts.size()):
			var ci: Control = texts[i]["c"]
			var cj: Control = texts[j]["c"]
			if ci.is_ancestor_of(cj) or cj.is_ancestor_of(ci):
				continue
			if _layer_of(ci) != _layer_of(cj):
				continue # an overlay over the HUD or the game is meant to cover it
			var inter: Rect2 = (texts[i]["r"] as Rect2).intersection(texts[j]["r"])
			if inter.size.x * inter.size.y >= OVERLAP_MIN_AREA and inter.size.x > 3.0 and inter.size.y > 3.0:
				var f: Dictionary = _f("warn", "overlap", ci, texts[i]["r"], "with %s %s" % [_path(cj), _rs(texts[j]["r"])])
				findings.append(f)
	var errors: int = 0
	var warns: int = 0
	for f: Dictionary in findings:
		if f["sev"] == "error":
			errors += 1
		else:
			warns += 1
	_total_errors += errors
	_total_warns += warns
	_results.append({"screen": sname, "errors": errors, "warns": warns, "canvas": [canvas.x, canvas.y], "safe": _rs(safe), "findings": findings})
	print("AUDIT %s errors=%d warns=%d (controls=%d canvas=%s safe=%s)" % [sname, errors, warns, controls.size(), str(canvas), _rs(safe)])


func _f(sev: String, kind: String, c: Control, rect: Rect2, detail: String) -> Dictionary:
	return {"sev": sev, "kind": kind, "node": _path(c), "class": c.get_class(), "rect": _rs(rect), "detail": detail, "text": _text_of(c).left(40)}


func _rs(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]


func _path(n: Node) -> String:
	var parts: PackedStringArray = []
	var cur: Node = n
	var depth: int = 0
	while cur != null and cur != get_tree().root and depth < 7:
		parts.append(String(cur.name))
		cur = cur.get_parent()
		depth += 1
	parts.reverse()
	return "/".join(parts)


func _outside(r: Rect2, bounds: Rect2) -> String:
	var parts: PackedStringArray = []
	if r.position.x < bounds.position.x - TOLERANCE_PX:
		parts.append("left %.0f" % (bounds.position.x - r.position.x))
	if r.position.y < bounds.position.y - TOLERANCE_PX:
		parts.append("top %.0f" % (bounds.position.y - r.position.y))
	if r.end.x > bounds.end.x + TOLERANCE_PX:
		parts.append("right %.0f" % (r.end.x - bounds.end.x))
	if r.end.y > bounds.end.y + TOLERANCE_PX:
		parts.append("bottom %.0f" % (r.end.y - bounds.end.y))
	return ", ".join(parts)


## Walks the whole tree for Controls that can actually be seen.
func _collect(node: Node, out: Array[Control]) -> void:
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	if node is Window and node != get_tree().root:
		return
	if node is Control:
		var c: Control = node as Control
		if not c.visible or c.modulate.a < 0.05:
			return
		if c.get_parent() is Container and c.get_parent() is TabContainer and not c.visible:
			return
		out.append(c)
	elif node is CanvasItem and not (node as CanvasItem).visible:
		return
	for ch: Node in node.get_children():
		_collect(ch, out)


func _kind(c: Control) -> String:
	if c is Label or c is RichTextLabel:
		return "text" if _has_text(c) else ""
	if c is BaseButton or c is LineEdit or (c is Range and not (c is ProgressBar) and not (c is ScrollBar)):
		return "button"
	if c is TextureRect:
		return "icon" if (c as TextureRect).texture != null else ""
	if c is PanelContainer:
		return "panel"
	if c is ProgressBar:
		return "icon"
	return ""


## A single-line Label draws only as wide as its text (centred or right aligned inside a wide box).
func _text_extent(c: Control, rect: Rect2) -> Rect2:
	if not (c is Label):
		return rect
	var l: Label = c as Label
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.text.contains("\n"):
		return rect
	var font: Font = l.get_theme_font("font")
	var w: float = font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x * c.get_global_transform_with_canvas().get_scale().x
	if w >= rect.size.x:
		return rect
	var x: float = rect.position.x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (rect.size.x - w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += rect.size.x - w
	return Rect2(x, rect.position.y, w, rect.size.y)


## Scenery (the title/hub backdrop art) may bleed past the edges.
func _under_decor(c: Control) -> bool:
	var a: Node = c.get_parent()
	while a != null and a != get_tree().root:
		var n: String = String(a.name)
		if n.begins_with("Background") or n.begins_with("Backdrop") or n.begins_with("Scrim") or n.begins_with("World"):
			return true
		a = a.get_parent()
	return false


func _layer_of(n: Node) -> Node:
	var a: Node = n
	while a != null:
		if a is CanvasLayer:
			return a
		a = a.get_parent()
	return null


func _has_text(c: Control) -> bool:
	return _text_of(c).strip_edges() != ""


func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is Button:
		return (c as Button).text
	return ""


func _font_size(c: Control) -> int:
	if c is RichTextLabel:
		return c.get_theme_font_size("normal_font_size")
	return c.get_theme_font_size("font_size")


func _global_rect(c: Control) -> Rect2:
	var xf: Transform2D = c.get_global_transform_with_canvas()
	var p: Array[Vector2] = [xf * Vector2.ZERO, xf * Vector2(c.size.x, 0.0), xf * c.size, xf * Vector2(0.0, c.size.y)]
	var mn: Vector2 = p[0]
	var mx: Vector2 = p[0]
	for v: Vector2 in p:
		mn = mn.min(v)
		mx = mx.max(v)
	return Rect2(mn, mx - mn)


func _clips(c: Control) -> bool:
	return c is ScrollContainer or c.clip_contents or c is SubViewportContainer


func _clips_any_ancestor(c: Control) -> bool:
	var a: Node = c.get_parent()
	while a is Control:
		if _clips(a as Control):
			return true
		a = a.get_parent()
	return false


func _scrollable_ancestor(c: Control) -> bool:
	var a: Node = c.get_parent()
	while a != null and a != get_tree().root:
		if a is ScrollContainer:
			var sc: ScrollContainer = a as ScrollContainer
			var bar: ScrollBar = sc.get_v_scroll_bar()
			var hbar: ScrollBar = sc.get_h_scroll_bar()
			if (sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and bar.max_value > bar.page + 0.5) or (sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and hbar.max_value > hbar.page + 0.5):
				return true
		a = a.get_parent()
	return false


## Empty when the text fits its own box, else a description.
func _text_clipped(c: Control) -> String:
	if c is Label:
		var l: Label = c as Label
		var font: Font = l.get_theme_font("font")
		var fs: int = l.get_theme_font_size("font_size")
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			if l.get_line_count() > l.get_visible_line_count() and l.max_lines_visible < 0:
				return "%d lines, %d visible" % [l.get_line_count(), l.get_visible_line_count()]
			var widest: float = 0.0
			for w: String in l.text.split(" "):
				widest = maxf(widest, font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			if widest > l.size.x + TOLERANCE_PX:
				return "word %.0f px wider than box %.0f" % [widest, l.size.x]
			return ""
		var lines: PackedStringArray = l.text.split("\n")
		var w2: float = 0.0
		for ln: String in lines:
			w2 = maxf(w2, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if w2 > l.size.x + TOLERANCE_PX and (l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING):
			return "text %.0f px wider than box %.0f" % [w2, l.size.x]
		if l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and w2 > l.size.x + TOLERANCE_PX:
			return "truncated (ellipsis): text %.0f px, box %.0f" % [w2, l.size.x]
		if l.get_line_count() > l.get_visible_line_count() and l.max_lines_visible < 0:
			return "%d lines, %d visible" % [l.get_line_count(), l.get_visible_line_count()]
	elif c is Button:
		var b: Button = c as Button
		var font2: Font = b.get_theme_font("font")
		var fs2: int = b.get_theme_font_size("font_size")
		var sb: StyleBox = b.get_theme_stylebox("normal")
		var inner: float = b.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
		if b.icon != null:
			inner -= b.icon.get_width()
		var tw: float = 0.0
		for ln2: String in b.text.split("\n"):
			tw = maxf(tw, font2.get_string_size(ln2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x)
		if tw > inner + TOLERANCE_PX and b.autowrap_mode == TextServer.AUTOWRAP_OFF:
			return "button text %.0f px wider than %.0f" % [tw, inner]
	elif c is RichTextLabel:
		var r: RichTextLabel = c as RichTextLabel
		if not r.fit_content and not r.scroll_active and r.get_content_height() > r.size.y + TOLERANCE_PX:
			return "rich text %d px tall in %d" % [r.get_content_height(), r.size.y]
		if r.get_content_width() > r.size.x + TOLERANCE_PX and not r.fit_content and r.autowrap_mode == TextServer.AUTOWRAP_OFF:
			return "rich text %d px wide in %d" % [r.get_content_width(), r.size.x]
	return ""



# ---------------------------------------------------------------------------
# Staging. Each entry: [name, Callable]. Entries may `await`.
# ---------------------------------------------------------------------------

func _screens() -> Array:
	var s: Array = []
	s.append(["title", _st_title])
	s.append(["title_controls", _st_title_controls])
	s.append(["title_credits", _st_title_credits])
	for tab: int in 5:
		s.append(["title_settings:%d" % tab, _st_title_settings.bind(tab)])
	s.append(["hub_run", _st_hub.bind("run", false)])
	s.append(["hub_loadout", _st_hub.bind("loadout", false)])
	s.append(["hub_run_unlocked", _st_hub.bind("run", true)])
	s.append(["hub_loadout_unlocked", _st_hub.bind("loadout", true)])
	s.append(["hub_skill_tree", _st_hub_overlay.bind("skilltree")])
	s.append(["hub_achievements", _st_hub_overlay.bind("achievements")])
	s.append(["hub_records", _st_hub_overlay.bind("records")])
	for tab: int in 5:
		s.append(["hub_settings:%d" % tab, _st_hub_overlay.bind("settings%d" % tab)])
	s.append(["hub_guide_locked", _st_hub_overlay.bind("guide_locked")])
	for tab: int in 8:
		s.append(["hub_guide:%d" % tab, _st_hub_overlay.bind("guide%d" % tab)])
	for id: String in _explainer_ids():
		s.append(["explainer:%s" % id, _st_explainer.bind(id)])
	s.append(["results_loss", _st_results.bind(false, false)])
	s.append(["results_win", _st_results.bind(true, false)])
	s.append(["results_endless", _st_results.bind(false, true)])
	s.append(["pause", _st_pause.bind("")])
	s.append(["pause_abandon", _st_pause.bind("abandon")])
	s.append(["pause_howto", _st_pause.bind("howto")])
	s.append(["pause_guide", _st_pause.bind("guide")])
	s.append(["pause_settings:0", _st_pause.bind("settings0")])
	s.append(["pause_settings:2", _st_pause.bind("settings2")])
	s.append(["draft", _st_draft])
	s.append(["draft_long", _st_draft_long])
	s.append(["event_opening", _st_event.bind("opening")])
	for kind: String in ["patrons_boon", "sanctuary", "blood_pact"]:
		s.append(["event_%s" % kind, _st_event.bind(kind)])
	s.append(["hud", _st_hud.bind("")])
	s.append(["hud_boss", _st_hud.bind("boss")])
	s.append(["hud_siege", _st_hud.bind("siege")])
	s.append(["hud_far", _st_hud.bind("far")])
	return s


## The longest few first-encounter cards, plus a few typical ones.
func _explainer_ids() -> Array[String]:
	var ranked: Array = []
	for entry: Dictionary in FieldGuideCatalog.all_entries():
		var n: int = 0
		for k: String in ["helps", "hurts", "effect", "tip", "desc"]:
			n += String(entry.get(k, "")).length()
		ranked.append([n, String(entry["id"])])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: Array[String] = []
	for i: int in mini(4, ranked.size()):
		out.append(ranked[i][1])
	for id: String in ["tower_seeker", "bomber", "goblin_warchief", "shrine"]:
		if not out.has(id) and not FieldGuideCatalog.find_entry(id).is_empty():
			out.append(id)
	return out


func _load_scene(path: String) -> Node:
	return _add((load(path) as PackedScene).instantiate())


func _st_title() -> void:
	_load_scene("res://scenes/title.tscn")
	await _frames(40)


func _st_title_controls() -> void:
	var t: TitleScreen = _load_scene("res://scenes/title.tscn") as TitleScreen
	await _frames(10)
	t._on_how_to_play_pressed()
	await _frames(30)


func _st_title_credits() -> void:
	var t: TitleScreen = _load_scene("res://scenes/title.tscn") as TitleScreen
	await _frames(10)
	t._on_credits_pressed()
	await _frames(30)


func _st_title_settings(tab: int) -> void:
	var t: TitleScreen = _load_scene("res://scenes/title.tscn") as TitleScreen
	await _frames(10)
	t._on_settings_pressed()
	await _frames(20)
	t.get_settings_menu_for_test().show_tab_for_debug(tab)
	await _frames(20)


func _st_hub(page: String, unlocked: bool) -> void:
	if unlocked:
		for id: String in ["recruit", "soldier", "veteran", "warlord"]:
			MetaProgress.set_difficulty_victories_for_test(id, 1)
	var hub: HubScreen = _load_scene("res://scenes/hub.tscn") as HubScreen
	await _frames(30)
	hub.show_page_for_test(page)
	await _frames(25)


func _st_hub_overlay(which: String) -> void:
	var hub: HubScreen = _load_scene("res://scenes/hub.tscn") as HubScreen
	await _frames(25)
	var under: Node = hub.get_node_or_null("Root")
	if under is CanvasItem:
		(under as CanvasItem).visible = false # the War Camp itself is audited on its own; only the overlay counts here
	if which.begins_with("guide"):
		if which != "guide_locked":
			for entry: Dictionary in FieldGuideCatalog.all_entries():
				MetaProgress.mark_discovered(String(entry["id"]))
		hub._on_field_guide_pressed()
		await _frames(15)
		hub.get_field_guide_for_test().open(0 if which == "guide_locked" else int(which.trim_prefix("guide")))
	elif which == "skilltree":
		hub._on_skill_tree_pressed()
	elif which == "achievements":
		hub._on_achievements_pressed()
	elif which == "records":
		hub._on_records_pressed()
	else:
		hub._on_settings_pressed()
		await _frames(15)
		hub.get_settings_menu_for_test().show_tab_for_debug(int(which.trim_prefix("settings")))
	await _frames(40)


func _answer_opening_pick(proto: Node) -> void:
	var ui: Node = proto.get_event_controller()
	while ui != null and ui.is_showing():
		ui.skip_lockout_for_test()
		ui.confirm_choice_for_test(0)


func _proto(answer_pick: bool = true) -> Node:
	for entry: Dictionary in FieldGuideCatalog.all_entries():
		MetaProgress.mark_explainer_seen(String(entry["id"]))
	var p: Node = _load_scene("res://scenes/prototype.tscn")
	var overlay: Node = p.get_node_or_null("DebugOverlay")
	if overlay != null:
		overlay.set("visible", false)
	await _frames(30)
	if answer_pick:
		_answer_opening_pick(p)
		await _frames(30)
	return p


func _find_class(node: Node, cls: String) -> Node:
	var scr: Script = node.get_script() as Script
	if scr != null and scr.get_global_name() == cls:
		return node
	for ch: Node in node.get_children():
		var r: Node = _find_class(ch, cls)
		if r != null:
			return r
	return null


func _st_pause(kind: String) -> void:
	var p: Node = await _proto()
	var flow: RunFlowController = p.get_node("RunFlowController") as RunFlowController
	flow._on_pause_action_pressed()
	await _frames(40)
	match kind:
		"abandon":
			flow.pause_menu._enter_abandon_confirmation()
		"howto":
			flow.pause_menu._on_option_confirmed(PauseMenu.OPTION_HOW_TO_PLAY)
		"guide":
			flow.pause_menu._open_field_guide()
		"settings0", "settings2":
			flow.pause_menu.settings_requested.emit()
			await _frames(15)
			flow.settings_menu.show_tab_for_debug(int(kind.trim_prefix("settings")))
	await _frames(30)


func _st_draft() -> void:
	var p: Node = await _proto()
	var draft: DraftController = p.get_node("DraftInstance") as DraftController
	draft.force_open_for_test(false)
	await _frames(60)
	draft.simulate_hover_for_test(1)
	await _frames(15)


## The Draft with the three cards that have the longest descriptions (the height worst case).
func _st_draft_long() -> void:
	var p: Node = await _proto()
	var draft: DraftController = p.get_node("DraftInstance") as DraftController
	draft.force_open_for_test(false)
	await _frames(40)
	var us: Node = p.get_node_or_null("Main/UpgradeSystem")
	var defs: Array = []
	for pool: int in [ContractEnums.PoolOwnership.Player, ContractEnums.PoolOwnership.Tower]:
		defs.append_array(us.get_offerable_upgrades(pool))
	defs.sort_custom(func(a: UpgradeDefinition, b: UpgradeDefinition) -> bool: return a.effect_description.length() > b.effect_description.length())
	for i: int in mini(3, draft.get_card_view_count_for_test()):
		var d: UpgradeDefinition = defs[i]
		var honest: Dictionary = us.get_honest_card_value(d.unique_id, 1.0)
		draft.get_card_view_for_test(i).setup(d, 0, ContractEnums.Rarity.Common, honest)
	await _frames(15)


func _st_event(kind: String) -> void:
	var p: Node = await _proto(kind != "opening")
	if kind != "opening":
		p.get_run_events().queue_dev_event(kind, false)
	await _frames(70)
	var ec: Node = p.get_event_controller()
	if ec != null and ec.has_method("simulate_hover_for_test"):
		ec.simulate_hover_for_test(1)
	await _frames(15)


func _st_explainer(id: String) -> void:
	GameSettings.set_show_first_time_tips_for_test(true)
	var ex := ExplainerController.new()
	ex.forced_for_test = true
	_add(ex)
	await _frames(3)
	ex.request(id)
	await _frames(45)
	GameSettings.set_show_first_time_tips_for_test(false)


func _st_results(victory: bool, endless: bool) -> void:
	UiStrings.ensure_registered()
	var screen: RunEndScreen = _load_scene("res://scenes/ui/run_end.tscn") as RunEndScreen
	var report: Array[Dictionary] = []
	for entry: Array in [["bow", 18400.0], ["ballista", 9100.0], ["flame_arrows", 6200.0], ["tower_bow", 5300.0], ["burn", 3900.0], ["whirling_axes", 2600.0], ["caltrops", 900.0]]:
		report.append({"source_id": entry[0], "damage": entry[1]})
	screen.show_summary({
		"outcome_title": "Victory" if victory else "Defeated", "cause_text": "" if victory else "The Tower was destroyed",
		"wave_reached": 15 if victory else 22 if endless else 11, "wave_total": 15, "scrap_held": 140, "time_survived_seconds": 905.0 if victory else 640.0,
		"kills": 5120, "elite_kills": 9, "difficulty_name": "Warlord", "endless": endless, "run_seed": 4242, "damage_report": report,
		"champion_id": "warden", "relic_ids": ["quiver_of_echoes", "masons_trowel", "iron_banner"],
	})
	screen.set_settlement({
		"lines": [
			{"label": "Time survived (15 min)", "amount": 15}, {"label": "Waves cleared (15)", "amount": 30},
			{"label": "Enemies defeated (5120)", "amount": 20}, {"label": "Elites defeated (9)", "amount": 9},
			{"label": "Scrap (140)", "amount": 14}, {"label": "Victory", "amount": 10},
			{"label": "Settlement bonus (+20%)", "amount": 20}, {"label": "Warlord difficulty (x1.4)", "amount": 46},
		] if victory else [{"label": "Time survived (10 min)", "amount": 10}, {"label": "Waves cleared (11)", "amount": 22}, {"label": "Enemies defeated (512)", "amount": 20}],
		"total_cores": 164 if victory else 52, "saved": true,
		"new_best_waves": true, "new_best_endless_wave": endless, "unlocked_difficulty": "warlord" if victory else "", "unlocked_endless": victory,
		"newly_unlocked_achievements": [{"id": "founder", "display_name": "Founder"}, {"id": "slayer", "display_name": "Goblin Slayer"}] if victory else [],
	})
	screen.set_active(true)
	await _frames(150)


func _st_hud(kind: String) -> void:
	var p: Node = await _proto()
	var mgr: Node = get_tree().get_first_node_in_group(&"ability_manager")
	var us: Node = p.get_node_or_null("Main/UpgradeSystem")
	var ids: Array = []
	ids.append_array(AbilityIds.PLAYER_ABILITIES.slice(0, AbilityIds.MAX_PLAYER_ABILITIES))
	ids.append_array(AbilityIds.TOWER_ABILITIES.slice(0, AbilityIds.MAX_TOWER_ABILITIES))
	var granted: int = 0
	for id: String in ids:
		if granted >= 99:
			break
		for r: int in 5:
			if us != null and us.get_definition(id) != null:
				us.apply_rank(id, 1.0)
			elif mgr != null:
				mgr.grant_ability(id, 1.0)
		granted += 1
	var arena: Node = p.get_node_or_null("Main/ArenaInteractables")
	if arena != null:
		for b: String in ["war", "haste", "ward", "bounty"]:
			arena.claim_boon(b)
	var tower: Node = p.get_node_or_null("Main/Tower")
	if tower != null:
		tower.death_state.current_hp = tower.health.max_health * 0.4
	var ps: Node = p.get_node_or_null("Main/PickupSystem")
	if ps != null:
		ps.run_inventory.scrap_current = 1234
	var announcer: Node = _find_class(p, "RunAnnouncer")
	match kind:
		"boss":
			EventBus.emit_wave_started(10, 15, "boss", true)
			EventBus.emit_boss_spawned(null, "gutbarrel", "Gutbarrel the Juggernaut", 2600.0)
			EventBus.emit_boss_health_changed("gutbarrel", 1500.0, 2600.0)
		"siege":
			EventBus.emit_wave_started(13, 15, "grand_assault", false)
			EventBus.emit_siege_warning(12.0)
			EventBus.emit_elite_spawned(null, "swift")
		"far":
			var pl: Node2D = p.get_node_or_null("Main/Player") as Node2D
			if pl != null:
				pl.global_position = Vector2(1300.0, 700.0)
				pl.reset_physics_interpolation()
	if announcer != null:
		announcer.show_toast("ELITE - EXPLOSIVE", 30.0)
		announcer.show_wave_banner(12, "grand_assault", false)
	await _frames(60)
	if kind == "" and announcer != null:
		var hints: Node = announcer.get_hints_for_test()
		if hints != null:
			hints.request_line("Walk to move. Your bow fires on its own.")
		await _frames(20)
