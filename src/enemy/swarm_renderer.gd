extends Node2D
class_name SwarmRenderer

## SwarmRenderer (PT-PERF, D390-D399). Draws every plain enemy (Tower Seeker, Player
## Hunter, Opportunist, Brute: an EnemyController with no Behavior whose scene uses only
## EnemyAnimator visuals) from MultiMesh instance buffers instead of one node tree each:
## no AnimatedSprite2D, no EnemyAnimator `_process`, no per-enemy HealthBar or
## TelegraphVisual. It is the "batched drawing" half of Performance Fallback Ladder
## step 3 (docs/20); SwarmBrain is the "batched brain" half.
##
## ## What is drawn how
## - Bodies: one shared sprite atlas (the Torch / TNT / Barrel sheets stacked, built at
##   start-up from the SpriteFrames the scenes already use) and one `swarm_enemy.gdshader`
##   that picks the animation frame from a row table (derived from the SpriteFrames
##   AtlasTexture regions, so frames, fps and strike clips match), flips, squashes,
##   flashes, tints, outlines and interpolates the physics tick. The shader also
##   replaces `enemy_outline.gdshader` for these enemies (steady accessibility outline,
##   gold / red elite outline).
## - Shadows: one MultiMesh under every body (z 19 versus the play layer's 20).
## - Draw order: the Entities container is Y-sorted with the player, the Tower and
##   the node-rendered enemies (bosses, Bomber, Shaman). Bodies are split into BANDS at
##   the y of each of those "separators"; each band is its own MultiMeshInstance2D
##   parked at the band's y, so the engine's Y-sort interleaves bands with the
##   separators exactly as it interleaved individual enemy nodes. Inside a band the
##   instances are written in y order (insertion sort of a persistent order, nearly
##   sorted frame to frame).
## - Health bars and wind-up markers: one overlay node (`SwarmOverlay`) draws both.
## - Death: the skull FX and the Opportunist's own explode clip come from capped pools
##   (Register "Swarm rendering": FX_CAP concurrent), not one instanced node per kill.
##
## ## Presentation state per slot (the slot index is SwarmBrain's)
## `s_*` arrays below. The controller (EnemyController `_sv_*`) runs the same state
## machine EnemyAnimator did (idle / run by speed, facing hysteresis, directional
## strike, flash on damage) and writes the result here through the small setters.
##
## ## Cost
## A buffer fill (once per physics tick, in `_process`) is ~8 stores per enemy; the
## engine uploads one buffer per band. Nothing is allocated per frame.

const ATLAS_SHEETS: Array[String] = [
	"res://assets/sprite_frames/tower_seeker.tres",
	"res://assets/sprite_frames/player_hunter.tres",
	"res://assets/sprite_frames/opportunist.tres",
]
const SHADOW_TEXTURE: Texture2D = preload("res://assets/third_party/tiny_swords/Derived/shadow_unit.png")
const EXCLAIM_TEXTURE: Texture2D = preload("res://assets/ui/telegraph_exclaim.png")
const RING_TEXTURE: Texture2D = preload("res://assets/ui/telegraph_ring.png")
const DEATH_FX_SCENE: PackedScene = preload("res://scenes/fx/death_fx.tscn")
const ENEMY_SHADER: Shader = preload("res://assets/shaders/swarm_enemy.gdshader")
const SHADOW_SHADER: Shader = preload("res://assets/shaders/swarm_shadow.gdshader")

## Register "Swarm rendering": concurrent skull FX (the high-intensity VFX cap) and
## Opportunist explode clips.
const FX_CAP: int = EntityCaps.MAX_HIGH_INTENSITY_VFX
const CLIP_CAP: int = 12
const MAX_ROWS: int = 128
const MAX_PROFILES: int = 16
const MAX_BANDS: int = 10
const MAX_SEPARATORS: int = MAX_BANDS - 1
const FLOATS_PER_INSTANCE: int = 16 # Transform2D (8) + color (4) + custom data (4)
## Colour and custom data reach the GPU as half floats in the Compatibility renderer
## (integers are exact only up to 2048), so every channel below carries a small integer.
const TICK_RANGE: int = 2048 # animation start stamps are SimClock ticks modulo this
const HIT_AGE_NONE: int = 15 # hit age channel: ticks since the last hit (0..7), 15 = none
const HIT_AGE_LIMIT: int = 8
const SHADOW_Y_OFFSET: float = 2.0 # Shadow Sprite2D position (0, 2) in every scene

# --- packed bits (INSTANCE_CUSTOM.z), see swarm_enemy.gdshader ---
const SQ_ONE: int = 21 # 0.6 + 21 * 1.2 / 63 = 1.0 (animation speed scale 1.0)
const SPEED_MIN: float = 0.6
const SPEED_MAX: float = 1.8

const OUTLINE_NONE: int = 0
const OUTLINE_STEADY: int = 1
const OUTLINE_GOLD: int = 2
const OUTLINE_RED: int = 3

const TINT_NONE: int = 0
const TINT_BURN: int = 1
const TINT_SLOW: int = 2
const TINT_FREEZE: int = 3

const ELITE_SCALE: float = 1.18
const HIT_UNSET: int = -100000
const TICKS_PER_SECOND: float = 60.0

# Health bar (EnemyHealthBar look and timing).
const BAR_FADE_DELAY: float = 2.0
const BAR_FADE_DURATION: float = 0.4
const BAR_TRAIL_RATE: float = 1.6
const BAR_WIDTH: float = 32.0
const BAR_HEIGHT: float = 4.0
const BAR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.9)
const BAR_BACKGROUND: Color = Color(0.10, 0.09, 0.09, 0.85)
const BAR_LOW: Color = Color(0.82, 0.14, 0.10, 1.0)
const BAR_HIGH: Color = Color(0.92, 0.80, 0.18, 1.0)
const BAR_TRAIL: Color = Color(0.98, 0.98, 0.95, 0.95)

# Wind-up marker (TelegraphVisual look).
const MARKER_HEIGHT_PX: float = 104.0
const MARKER_PULSE_HZ: float = 6.0
const MARKER_PULSE_ALPHA: float = 0.25
const RING_FRAMES: int = 6
const RING_FRAME_SIZE: Vector2 = Vector2(64, 32)
const OVERLAY_Z_INDEX: int = 40 # telegraph band, absolute (docs/20 Scene Tree draw order)


class Profile:
	var id: int = 0
	var key: String = ""
	var frames: SpriteFrames = null
	var offset: Vector2 = Vector2.ZERO
	var tint: Color = Color.WHITE
	var scale: float = 1.0
	var reserved: Color = Color.WHITE
	var reserved_raw: Color = Color.WHITE
	var directional: bool = false
	var death_anim: StringName = &""
	var bar_dy: float = -86.0
	var rows: Dictionary = {} # animation name -> row
	var row_seconds: Dictionary = {} # row -> clip length in seconds
	# Leash conversion art (Player Hunter -> Tower Seeker); frames == null when none.
	var conv_frames: SpriteFrames = null
	var conv_offset: Vector2 = Vector2(0, -37)
	var conv_directional: bool = true
	var conv_reserved: Color = Color.WHITE
	var converted: Profile = null


## Per-slot presentation state.
var s_active: PackedByteArray = PackedByteArray()
var s_in_order: PackedByteArray = PackedByteArray() # the slot still has an entry in `_order` (a detached one is dropped at the next fill)
var s_prof: PackedInt32Array = PackedInt32Array()
var s_row: PackedInt32Array = PackedInt32Array()
var s_sq: PackedInt32Array = PackedInt32Array() # animation speed code 0..63
var s_fl: PackedInt32Array = PackedInt32Array() # outline mode | tint << 2 | flip << 4
var s_start: PackedInt32Array = PackedInt32Array() # SimClock tick of the animation start, modulo TICK_RANGE
var s_hit: PackedInt32Array = PackedInt32Array() # SimClock tick of the last hit
var s_scale: PackedFloat32Array = PackedFloat32Array()
# Health bar: hp bookkeeping so the trail and fade are closed-form in `draw_overlay`.
var b_on: PackedByteArray = PackedByteArray()
var b_hp: PackedFloat32Array = PackedFloat32Array()
var b_max: PackedFloat32Array = PackedFloat32Array()
var b_trail_ref: PackedFloat32Array = PackedFloat32Array()
var b_trail_t: PackedFloat32Array = PackedFloat32Array()
var b_hit_t: PackedFloat32Array = PackedFloat32Array()
var b_dy: PackedFloat32Array = PackedFloat32Array()
# Wind-up marker.
var m_on: PackedByteArray = PackedByteArray()
var m_t0: PackedFloat32Array = PackedFloat32Array()
var m_dur: PackedFloat32Array = PackedFloat32Array()

var _profiles: Array[Profile] = []
var _profile_by_key: Dictionary = {}
var _row_a: PackedVector4Array = PackedVector4Array()
var _row_b: PackedVector4Array = PackedVector4Array()
var _row_c: PackedVector4Array = PackedVector4Array()
var _row_d: PackedVector4Array = PackedVector4Array()
var _atlas_regions: Dictionary = {} # Texture2D -> Vector2 (origin in the atlas)
var _atlas_size: Vector2 = Vector2.ZERO
var _atlas: ImageTexture = null
var _enemy_material: ShaderMaterial = null
var _shadow_material: ShaderMaterial = null

var _capacity: int = 0
var _band_nodes: Array[MultiMeshInstance2D] = []
var _band_rids: Array[RID] = []
var _band_counts: PackedInt32Array = PackedInt32Array()
var _shadow_node: MultiMeshInstance2D = null
var _shadow_rid: RID = RID()
var _scratch: PackedFloat32Array = PackedFloat32Array()
var _shadow_scratch: PackedFloat32Array = PackedFloat32Array()
var _order: PackedInt32Array = PackedInt32Array()
var _dirty: bool = false
var _overlay: Node2D = null
var _bar_slots: PackedInt32Array = PackedInt32Array()
var _marker_slots: PackedInt32Array = PackedInt32Array()
var _node_enemies: Array = [] # behaviour-driven enemies that are separators in the Y-sort
var _separators: PackedFloat32Array = PackedFloat32Array()
var _fx_pool: Array = []
var _clip_pool: Array = []
var _warned_full: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	y_sort_enabled = true # its band nodes join the Entities Y-sort group
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"swarm_renderer")
	SwarmState.renderer = self
	_capacity = EntityCaps.max_enemies() + 16
	_build_atlas()
	_enemy_material = ShaderMaterial.new()
	_enemy_material.shader = ENEMY_SHADER
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = SHADOW_SHADER
	_build_nodes()
	_scratch = _fresh_buffer()
	_shadow_scratch = _fresh_buffer()
	_enemy_material.set_shader_parameter("atlas_size", _atlas_size)
	_enemy_material.set_shader_parameter("atlas_tex", _atlas)
	_row_a.resize(MAX_ROWS)
	_row_b.resize(MAX_ROWS)
	_row_c.resize(MAX_ROWS)
	_row_d.resize(MAX_ROWS)
	_push_rows()


func _exit_tree() -> void:
	if SwarmState.renderer == self:
		SwarmState.renderer = null


# --- build ------------------------------------------------------------------

func _fresh_buffer() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(_capacity * FLOATS_PER_INSTANCE)
	buf.fill(0.0)
	for i in _capacity: # identity Transform2D rows: [1 0 0 x | 0 1 0 y]; the shader moves them
		var base: int = i * FLOATS_PER_INSTANCE
		buf[base] = 1.0
		buf[base + 5] = 1.0
		buf[base + 11] = 1.0
	return buf


func _build_atlas() -> void:
	var sheets: Array[Texture2D] = []
	for path in ATLAS_SHEETS:
		var sf: SpriteFrames = load(path) as SpriteFrames
		if sf != null:
			_collect_sheets(sf, sheets)
	_rebuild_atlas(sheets)


func _collect_sheets(sf: SpriteFrames, into: Array[Texture2D]) -> void:
	for anim in sf.get_animation_names():
		for i in sf.get_frame_count(anim):
			var tex: AtlasTexture = sf.get_frame_texture(anim, i) as AtlasTexture
			if tex != null and tex.atlas != null and not into.has(tex.atlas):
				into.append(tex.atlas)


func _rebuild_atlas(sheets: Array[Texture2D]) -> void:
	var width: int = 0
	var height: int = 0
	for t in sheets:
		width = maxi(width, t.get_width())
		height += t.get_height()
	var img: Image = Image.create(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	var y: int = 0
	_atlas_regions.clear()
	for t in sheets:
		var src: Image = t.get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(0, y))
		_atlas_regions[t] = Vector2(0, y)
		y += t.get_height()
	_atlas_size = Vector2(img.get_size())
	if _atlas == null:
		_atlas = ImageTexture.create_from_image(img)
	else:
		_atlas.set_image(img)
	if _enemy_material != null:
		_enemy_material.set_shader_parameter("atlas_size", _atlas_size)


func _build_nodes() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = SHADOW_TEXTURE.get_size()
	_shadow_node = _make_mmi(shadow_mesh, SHADOW_TEXTURE, _shadow_material, -1)
	_shadow_node.name = "Shadows"
	_shadow_rid = _shadow_node.multimesh.get_rid()
	for b in MAX_BANDS:
		var band: MultiMeshInstance2D = _make_mmi(mesh, _atlas, _enemy_material, 0)
		band.name = "Band%d" % b
		band.visible = false
		_band_nodes.append(band)
		_band_rids.append(band.multimesh.get_rid())
		_band_counts.append(0)
	var overlay_script: GDScript = load("res://src/enemy/swarm_overlay.gd")
	_overlay = overlay_script.new() as Node2D
	_overlay.name = "Overlay"
	_overlay.set("renderer", self)
	_overlay.z_as_relative = false
	_overlay.z_index = OVERLAY_Z_INDEX
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_overlay)


func _make_mmi(mesh: Mesh, tex: Texture2D, mat: ShaderMaterial, z: int) -> MultiMeshInstance2D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = _capacity
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-4000.0, -4000.0, -1.0), Vector3(8000.0, 8000.0, 2.0))
	var node := MultiMeshInstance2D.new()
	node.multimesh = mm
	node.texture = tex
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.material = mat
	node.z_index = z
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(node)
	return node


func _push_rows() -> void:
	_enemy_material.set_shader_parameter("anim_a", _row_a)
	_enemy_material.set_shader_parameter("anim_b", _row_b)
	_enemy_material.set_shader_parameter("anim_c", _row_c)
	_enemy_material.set_shader_parameter("anim_d", _row_d)


# --- profiles ---------------------------------------------------------------

## Returns the Profile for these art parameters, creating its animation rows on first
## use; null when the row table or the profile table is full (the enemy then keeps
## node visuals).
func profile_for(frames: SpriteFrames, offset: Vector2, tint: Color, scale: float, reserved: Color, directional: bool, death_anim: StringName, bar_dy: float) -> Profile:
	var outline_on: bool = GameSettings.is_enemy_outlines()
	var key: String = "%s|%s|%s|%.3f|%s|%s|%s|%s" % [frames.resource_path, offset, tint, scale, reserved if outline_on else Color.TRANSPARENT, directional, death_anim, bar_dy]
	var existing: Variant = _profile_by_key.get(key)
	if existing != null:
		return existing as Profile
	if _profiles.size() >= MAX_PROFILES:
		return null
	var p := Profile.new()
	p.id = _profiles.size()
	p.key = key
	p.frames = frames
	p.offset = offset
	p.tint = tint
	p.scale = scale
	p.reserved = reserved if outline_on else Color.TRANSPARENT
	p.reserved_raw = reserved
	p.directional = directional
	p.death_anim = death_anim
	p.bar_dy = bar_dy
	if not _add_rows(p):
		return null
	_profiles.append(p)
	_profile_by_key[key] = p
	_push_rows()
	return p


## The profile of an enemy after leash conversion (Player Hunter -> Tower Seeker).
func converted_profile(p: Profile) -> Profile:
	if p.converted != null:
		return p.converted
	if p.conv_frames == null:
		return null
	var c: Profile = profile_for(p.conv_frames, p.conv_offset, p.tint, p.scale, p.conv_reserved, p.conv_directional, &"", p.bar_dy)

	p.converted = c
	return c


## The same art at another scale (the elite 1.18: the node version replaced the Visuals
## scale by that absolute value).
func rescaled_profile(p: Profile, scale: float) -> Profile:
	var c: Profile = profile_for(p.frames, p.offset, p.tint, scale, p.reserved_raw, p.directional, p.death_anim, p.bar_dy)
	if c != null and c.conv_frames == null:
		c.conv_frames = p.conv_frames
		c.conv_offset = p.conv_offset
		c.conv_directional = p.conv_directional
		c.conv_reserved = p.conv_reserved
	return c


func profile_by_id(id: int) -> Profile:
	return _profiles[id]


func _add_rows(p: Profile) -> bool:
	var names: PackedStringArray = p.frames.get_animation_names()
	if _row_count() + names.size() > MAX_ROWS:
		return false
	var missing: Array[Texture2D] = []
	for anim in names:
		for i in p.frames.get_frame_count(anim):
			var tex: AtlasTexture = p.frames.get_frame_texture(anim, i) as AtlasTexture
			if tex == null or tex.atlas == null:
				return false
			if not _atlas_regions.has(tex.atlas) and not missing.has(tex.atlas):
				missing.append(tex.atlas)
	if not missing.is_empty(): # a sheet the start-up list did not know: grow the atlas once
		var all: Array[Texture2D] = []
		for t in _atlas_regions.keys():
			all.append(t)
		all.append_array(missing)
		_rebuild_atlas(all)
	for anim in names:
		var n: int = p.frames.get_frame_count(anim)
		if n == 0:
			continue
		var first: AtlasTexture = p.frames.get_frame_texture(anim, 0) as AtlasTexture
		# Frames must be one horizontal strip of equal cells for the shader to index them.
		for i in n:
			var f: AtlasTexture = p.frames.get_frame_texture(anim, i) as AtlasTexture
			if f.atlas != first.atlas or f.region.size != first.region.size or not is_equal_approx(f.region.position.y, first.region.position.y) or not is_equal_approx(f.region.position.x, first.region.position.x + float(i) * first.region.size.x):
				return false
		var row: int = _row_count()
		var origin: Vector2 = _atlas_regions[first.atlas] + first.region.position
		var fps: float = p.frames.get_animation_speed(anim) / maxf(p.frames.get_frame_duration(anim, 0), 0.0001)
		var looped: bool = p.frames.get_animation_loop(anim)
		_row_a[row] = Vector4(origin.x, origin.y, float(n) if looped else -float(n), fps)
		_row_b[row] = Vector4(first.region.size.x, first.region.size.y, p.offset.x, p.offset.y)
		_row_c[row] = Vector4(p.tint.r, p.tint.g, p.tint.b, p.scale)
		_row_d[row] = Vector4(p.reserved.r, p.reserved.g, p.reserved.b, p.reserved.a)
		p.rows[StringName(anim)] = row
		p.row_seconds[row] = float(n) / maxf(fps, 0.0001)
		_used_rows += 1
	return true


var _used_rows: int = 0


func _row_count() -> int:
	return _used_rows


# --- slots ------------------------------------------------------------------

func ensure_slot(slot: int) -> void:
	if slot < s_active.size():
		return
	var n: int = maxi(slot + 1, s_active.size() * 2)
	n = maxi(n, 64)
	s_active.resize(n)
	s_in_order.resize(n)
	s_prof.resize(n)
	s_row.resize(n)
	s_sq.resize(n)
	s_fl.resize(n)
	s_start.resize(n)
	s_hit.resize(n)
	s_scale.resize(n)
	b_on.resize(n)
	b_hp.resize(n)
	b_max.resize(n)
	b_trail_ref.resize(n)
	b_trail_t.resize(n)
	b_hit_t.resize(n)
	b_dy.resize(n)
	m_on.resize(n)
	m_t0.resize(n)
	m_dur.resize(n)


## Takes over the drawing of `enemy` (its slot in SwarmBrain): builds its profile from
## the Visuals it already carries, then frees those nodes (Visuals + Shadow +
## AnimatedSprite2D, TelegraphVisual, HealthBar). Returns false (and touches nothing)
## when the enemy is not a plain EnemyAnimator enemy or the tables are full.
func attach(slot: int, enemy: Node2D, now: float) -> Profile:
	if _order.size() >= _capacity:
		if not _warned_full:
			_warned_full = true
			push_warning("SwarmRenderer: more plain enemies than the pool capacity %d" % _capacity)
		return null
	var visuals: Node = enemy.get_node_or_null("Visuals")
	var sprite: AnimatedSprite2D = enemy.get_node_or_null("Visuals/AnimatedSprite2D") as AnimatedSprite2D
	if not (visuals is EnemyAnimator) or sprite == null or sprite.sprite_frames == null:
		return null
	var anim: EnemyAnimator = visuals as EnemyAnimator
	var bar: Node = enemy.get_node_or_null("HealthBar")
	var bar_dy: float = float(bar.get("vertical_offset")) if bar != null and bar.get("vertical_offset") != null else -86.0
	var definition: EnemyDefinition = enemy.get("definition") as EnemyDefinition
	var reserved: Color = Color.WHITE
	if definition != null and definition.readability_profile != null:
		reserved = definition.readability_profile.reserved_colour
	var p: Profile = profile_for(sprite.sprite_frames, sprite.offset, sprite.modulate, anim.scale.x, reserved, anim.directional_strike, anim.death_animation, bar_dy)
	if p == null:
		return null
	if anim.converted_sprite_frames != null and p.conv_frames == null:
		p.conv_frames = anim.converted_sprite_frames
		p.conv_offset = anim.converted_sprite_offset
		p.conv_directional = anim.converted_directional_strike
		var seeker_def: EnemyDefinition = enemy.get("seeker_definition_for_conversion") as EnemyDefinition
		if seeker_def != null and seeker_def.readability_profile != null:
			p.conv_reserved = seeker_def.readability_profile.reserved_colour
	ensure_slot(slot)
	s_active[slot] = 1
	s_prof[slot] = p.id
	s_scale[slot] = p.scale
	s_hit[slot] = HIT_UNSET
	b_on[slot] = 0
	m_on[slot] = 0
	b_dy[slot] = bar_dy
	var idle_row: int = int(p.rows.get(&"idle", 0))
	var outline: int = OUTLINE_STEADY if (GameSettings.is_enemy_outlines() and p.reserved.a > 0.0) else OUTLINE_NONE
	s_row[slot] = idle_row
	s_sq[slot] = SQ_ONE
	s_fl[slot] = outline
	s_start[slot] = tick_of(now)
	if s_in_order[slot] == 0:
		_order.append(slot)
		s_in_order[slot] = 1
	_dirty = true
	for n in ["Visuals", "TelegraphVisual", "HealthBar"]:
		var node: Node = enemy.get_node_or_null(n)
		if node != null:
			enemy.remove_child(node)
			node.free()
	return p


func detach(slot: int) -> void:
	if slot >= s_active.size() or s_active[slot] == 0:
		return
	s_active[slot] = 0
	b_on[slot] = 0
	m_on[slot] = 0
	_dirty = true


func is_attached(slot: int) -> bool:
	return slot < s_active.size() and s_active[slot] == 1


static func tick_of(seconds: float) -> int:
	return int(seconds * TICKS_PER_SECOND + 0.5)


func set_profile(slot: int, p: Profile, row: int, now: float) -> void:
	s_prof[slot] = p.id
	s_scale[slot] = p.scale
	s_row[slot] = row
	s_start[slot] = tick_of(now) & (TICK_RANGE - 1)
	_dirty = true


## Switch to animation `row` at speed code `sq`, restarting it at `now`.
func play_row(slot: int, row: int, sq: int, now: float) -> void:
	s_row[slot] = row
	s_sq[slot] = sq
	s_start[slot] = tick_of(now) & (TICK_RANGE - 1)


## Changes only the speed code, keeping the current frame (re-bases the start stamp).
func retime(slot: int, sq: int, now: float) -> void:
	var old_sq: int = s_sq[slot]
	if old_sq == sq:
		return
	var old_speed: float = SPEED_MIN + float(old_sq) * (1.2 / 63.0)
	var new_speed: float = SPEED_MIN + float(sq) * (1.2 / 63.0)
	var now_tick: int = tick_of(now)
	var elapsed: int = (now_tick - s_start[slot]) & (TICK_RANGE - 1)
	var phase: float = float(elapsed) * old_speed
	s_start[slot] = (now_tick - int(phase / new_speed)) & (TICK_RANGE - 1)
	s_sq[slot] = sq


static func speed_code(scale: float) -> int:
	return clampi(int(round((clampf(scale, SPEED_MIN, SPEED_MAX) - SPEED_MIN) * (63.0 / 1.2))), 0, 63)


func set_flip(slot: int, flipped: bool) -> void:
	if flipped:
		s_fl[slot] = s_fl[slot] | 16
	else:
		s_fl[slot] = s_fl[slot] & ~16


func set_outline(slot: int, mode: int) -> void:
	s_fl[slot] = (s_fl[slot] & ~3) | mode


func set_status_tint(slot: int, kind: int) -> void:
	if slot < s_fl.size() and s_active[slot] == 1:
		s_fl[slot] = (s_fl[slot] & ~12) | (kind << 2)


func set_slot_scale(slot: int, scale: float) -> void:
	s_scale[slot] = scale
func flash(slot: int, now: float) -> void:
	s_hit[slot] = tick_of(now)


# --- health bar and marker --------------------------------------------------

## A hit landed: `hp_before` / `hp_after` are the health values around it.
func bar_hit(slot: int, hp_before: float, hp_after: float, max_hp: float, now: float) -> void:
	var trail_now: float = b_hp[slot]
	if b_on[slot] == 1:
		trail_now = maxf(hp_after, b_trail_ref[slot] - max_hp * BAR_TRAIL_RATE * (now - b_trail_t[slot]))
	else:
		trail_now = 0.0
		_bar_slots.append(slot)
	b_on[slot] = 1
	b_trail_ref[slot] = maxf(trail_now, hp_before)
	b_trail_t[slot] = now
	b_hp[slot] = hp_after
	b_max[slot] = max_hp
	b_hit_t[slot] = now


## Healing (Vampiric leech) keeps a shown bar current.
func bar_sync(slot: int, hp: float, max_hp: float) -> void:
	if b_on[slot] == 1:
		b_hp[slot] = hp
		b_max[slot] = max_hp


func bar_off(slot: int) -> void:
	b_on[slot] = 0


func marker_on(slot: int, now: float, duration: float) -> void:
	if m_on[slot] == 0:
		_marker_slots.append(slot)
	m_on[slot] = 1
	m_t0[slot] = now
	m_dur[slot] = duration


func marker_off(slot: int) -> void:
	m_on[slot] = 0


# --- node-rendered enemies as Y-sort separators -----------------------------

func register_node_enemy(e: Node2D) -> void:
	if not _node_enemies.has(e):
		_node_enemies.append(e)


func unregister_node_enemy(e: Node2D) -> void:
	_node_enemies.erase(e)


# --- death effects ------------------------------------------------------------

## The skull fall-and-dissolve at a kill. At most FX_CAP at once (Register "Swarm
## rendering"); beyond it the extra skulls are skipped (cosmetic only).
func spawn_death_fx(world_pos: Vector2) -> void:
	var fx: DeathFx = null
	for n in _fx_pool:
		if is_instance_valid(n) and not (n as DeathFx).visible:
			fx = n
			break
	if fx == null:
		if _fx_pool.size() >= FX_CAP:
			return
		fx = DEATH_FX_SCENE.instantiate() as DeathFx
		fx.pooled = true
		get_parent().add_child(fx)
		_fx_pool.append(fx)
	fx.replay(world_pos)


## The Opportunist's own explode clip (its `death` animation), pooled.
func spawn_death_clip(frames: SpriteFrames, anim: StringName, offset: Vector2, scale: float, world_pos: Vector2, flipped: bool = false) -> void:
	var clip: AnimatedSprite2D = null
	for n in _clip_pool:
		if is_instance_valid(n) and not (n as AnimatedSprite2D).visible:
			clip = n
			break
	if clip == null:
		if _clip_pool.size() >= CLIP_CAP:
			return
		clip = AnimatedSprite2D.new()
		clip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		clip.animation_finished.connect(func() -> void: clip.visible = false)
		get_parent().add_child(clip)
		_clip_pool.append(clip)
	clip.sprite_frames = frames
	clip.offset = offset
	clip.scale = Vector2(scale, scale)
	clip.flip_h = flipped
	clip.global_position = world_pos
	clip.visible = true
	clip.play(anim)


# --- per-frame ----------------------------------------------------------------

## Called by SwarmBrain at the end of every physics tick.
func mark_dirty() -> void:
	_dirty = true


## Dev: wall time of the last _process (fill included) and the overlay draw, microseconds.
var profile_enabled: bool = false
var prof_process_usec: int = 0
var prof_fill_usec: int = 0
var prof_overlay_usec: int = 0
var prof_fills: int = 0


func _process(_delta: float) -> void:
	var t_start: int = Time.get_ticks_usec() if profile_enabled else 0
	var frac: float = Engine.get_physics_interpolation_fraction()
	_enemy_material.set_shader_parameter("tick_clock", float(tick_of(SimClock.now) & (TICK_RANGE - 1)))
	_enemy_material.set_shader_parameter("phys_frac", frac)
	_enemy_material.set_shader_parameter("reduce_flashing", 1.0 if GameSettings.is_reduce_flashing() else 0.0)
	_shadow_material.set_shader_parameter("phys_frac", frac)
	if _dirty:
		_dirty = false
		var t_fill: int = Time.get_ticks_usec() if profile_enabled else 0
		_fill()
		if profile_enabled:
			prof_fill_usec += Time.get_ticks_usec() - t_fill
			prof_fills += 1
	if not _bar_slots.is_empty() or not _marker_slots.is_empty():
		_overlay.queue_redraw()
	elif _overlay_has_content:
		_overlay_has_content = false
		_overlay.queue_redraw()
	if profile_enabled:
		prof_process_usec += Time.get_ticks_usec() - t_start


var _overlay_has_content: bool = false


func _fill() -> void:
	var brain: Node = SwarmState.brain
	if brain == null:
		return
	var pos: PackedVector2Array = brain.pos
	var prev: PackedVector2Array = brain.prev
	# Drop detached slots, keep the order of the rest.
	var kept: int = 0
	var n: int = _order.size()
	for k in n:
		var s: int = _order[k]
		if s_active[s] == 1:
			_order[kept] = s
			kept += 1
		else:
			s_in_order[s] = 0
	if kept != n:
		_order.resize(kept)
		n = kept
	# Insertion sort by y (the order is nearly sorted frame to frame).
	for k in range(1, n):
		var s: int = _order[k]
		var y: float = pos[s].y
		var j: int = k - 1
		while j >= 0 and pos[_order[j]].y > y:
			_order[j + 1] = _order[j]
			j -= 1
		_order[j + 1] = s
	# Separators: the player, the Tower and the node-rendered enemies.
	_separators.clear()
	_separators.append(brain.player_y)
	_separators.append(brain.tower_y)
	var dead_nodes: bool = false
	for e in _node_enemies:
		if not is_instance_valid(e):
			dead_nodes = true
			continue
		if _separators.size() >= MAX_SEPARATORS:
			break
		_separators.append((e as Node2D).global_position.y)
	if dead_nodes:
		_node_enemies = _node_enemies.filter(func(x: Variant) -> bool: return is_instance_valid(x))
	_separators.sort()
	var nsep: int = _separators.size()
	var band_y := PackedFloat32Array()
	band_y.resize(nsep + 1)
	band_y[0] = _separators[0] - 1.0
	for b in range(1, nsep):
		band_y[b] = 0.5 * (_separators[b - 1] + _separators[b])
	band_y[nsep] = _separators[nsep - 1] + 1.0
	var buf: PackedFloat32Array = _scratch
	_scratch = PackedFloat32Array()
	var sbuf: PackedFloat32Array = _shadow_scratch
	_shadow_scratch = PackedFloat32Array()
	var band: int = 0
	var cnt: int = 0
	var base_y: float = band_y[0]
	var tick_now: int = tick_of(SimClock.now)
	var shadow_count: int = 0
	for k in n:
		var s: int = _order[k]
		var p: Vector2 = pos[s]
		var py: float = p.y
		while band < nsep and py > _separators[band]:
			_flush_band(band, buf, cnt, band_y[band])
			band += 1
			cnt = 0
			base_y = band_y[band]
		var q: Vector2 = prev[s]
		var dx: int = int((p.x - q.x) * 4.0)
		var dy: int = int((py - q.y) * 4.0)
		if dx > 127:
			dx = 127
		elif dx < -127:
			dx = -127
		if dy > 127:
			dy = 127
		elif dy < -127:
			dy = -127
		var age: int = tick_now - s_hit[s]
		if age >= HIT_AGE_LIMIT:
			age = HIT_AGE_NONE
		var i: int = cnt * FLOATS_PER_INSTANCE
		buf[i + 3] = p.x
		buf[i + 7] = py - base_y
		buf[i + 8] = s_fl[s]
		buf[i + 9] = dx + 128
		buf[i + 10] = dy + 128
		buf[i + 12] = s_start[s]
		buf[i + 13] = s_row[s]
		buf[i + 14] = s_sq[s]
		buf[i + 15] = age
		cnt += 1
		var j: int = shadow_count * FLOATS_PER_INSTANCE
		sbuf[j + 3] = p.x
		sbuf[j + 7] = py
		sbuf[j + 9] = dx + 128
		sbuf[j + 10] = dy + 128
		sbuf[j + 12] = s_scale[s]
		shadow_count += 1
	_flush_band(band, buf, cnt, band_y[band])
	for b in range(band + 1, MAX_BANDS):
		_hide_band(b)
	_scratch = buf
	RenderingServer.multimesh_set_buffer(_shadow_rid, sbuf)
	RenderingServer.multimesh_set_visible_instances(_shadow_rid, shadow_count)
	_shadow_scratch = sbuf


func _flush_band(b: int, buf: PackedFloat32Array, count: int, y: float) -> void:
	var node: MultiMeshInstance2D = _band_nodes[b]
	_band_counts[b] = count
	if count == 0:
		_hide_band(b)
		return
	node.visible = true
	node.position = Vector2(0.0, y)
	RenderingServer.multimesh_set_buffer(_band_rids[b], buf)
	RenderingServer.multimesh_set_visible_instances(_band_rids[b], count)


func _hide_band(b: int) -> void:
	_band_counts[b] = 0
	var node: MultiMeshInstance2D = _band_nodes[b]
	if node.visible:
		node.visible = false


# --- overlay ------------------------------------------------------------------

## Draws the wind-up markers and the health bars (called from SwarmOverlay._draw).
func draw_overlay(canvas: CanvasItem) -> void:
	var t_overlay: int = Time.get_ticks_usec() if profile_enabled else 0
	_draw_overlay_impl(canvas)
	if profile_enabled:
		prof_overlay_usec += Time.get_ticks_usec() - t_overlay


func _draw_overlay_impl(canvas: CanvasItem) -> void:
	var brain: Node = SwarmState.brain
	if brain == null:
		return
	var pos: PackedVector2Array = brain.pos
	var prev: PackedVector2Array = brain.prev
	var frac: float = Engine.get_physics_interpolation_fraction()
	var now: float = SimClock.now
	_overlay_has_content = false
	# Wind-up markers: ground ring that fills with the wind-up, "!" above the head.
	var danger: Color = UiPalette.DANGER
	var k: int = 0
	while k < _marker_slots.size():
		var s: int = _marker_slots[k]
		if m_on[s] == 0 or s_active[s] == 0:
			m_on[s] = 0
			_marker_slots[k] = _marker_slots[_marker_slots.size() - 1]
			_marker_slots.resize(_marker_slots.size() - 1)
			continue
		var p: Vector2 = prev[s].lerp(pos[s], frac)
		var progress: float = clampf((now - m_t0[s]) / maxf(m_dur[s], 0.0001), 0.0, 1.0) if m_dur[s] > 0.0 else 1.0
		var frame: int = clampi(int(round(progress * float(RING_FRAMES - 1))), 0, RING_FRAMES - 1)
		canvas.draw_texture_rect_region(RING_TEXTURE, Rect2(p - RING_FRAME_SIZE * 0.5, RING_FRAME_SIZE), Rect2(Vector2(frame * RING_FRAME_SIZE.x, 0.0), RING_FRAME_SIZE), danger)
		k += 1
		_overlay_has_content = true
	var pulse: float = 1.0 - MARKER_PULSE_ALPHA * (0.5 + 0.5 * sin(now * TAU * MARKER_PULSE_HZ))
	var mark_color := Color(danger, pulse)
	var ex_size: Vector2 = EXCLAIM_TEXTURE.get_size()
	for s in _marker_slots:
		var p: Vector2 = prev[s].lerp(pos[s], frac)
		canvas.draw_texture(EXCLAIM_TEXTURE, p + Vector2(-ex_size.x * 0.5, -MARKER_HEIGHT_PX - ex_size.y * 0.5), mark_color)
	# Health bars of damaged enemies.
	k = 0
	while k < _bar_slots.size():
		var s: int = _bar_slots[k]
		var age: float = now - b_hit_t[s]
		if b_on[s] == 0 or s_active[s] == 0 or age >= BAR_FADE_DELAY + BAR_FADE_DURATION:
			b_on[s] = 0
			_bar_slots[k] = _bar_slots[_bar_slots.size() - 1]
			_bar_slots.resize(_bar_slots.size() - 1)
			continue
		k += 1
		_overlay_has_content = true
		var alpha: float = 1.0
		if age > BAR_FADE_DELAY:
			alpha = 1.0 - clampf((age - BAR_FADE_DELAY) / BAR_FADE_DURATION, 0.0, 1.0)
		var maxhp: float = maxf(b_max[s], 0.001)
		var hp: float = clampf(b_hp[s], 0.0, maxhp)
		var trail: float = maxf(hp, b_trail_ref[s] - maxhp * BAR_TRAIL_RATE * (now - b_trail_t[s]))
		var frac_hp: float = hp / maxhp
		var trail_frac: float = clampf(trail, 0.0, maxhp) / maxhp
		var c: Vector2 = prev[s].lerp(pos[s], frac) + Vector2(0.0, b_dy[s])
		var hw: float = BAR_WIDTH * 0.5
		var hh: float = BAR_HEIGHT * 0.5
		canvas.draw_rect(Rect2(c.x - hw - 1.0, c.y - hh - 1.0, BAR_WIDTH + 2.0, BAR_HEIGHT + 2.0), Color(BAR_OUTLINE, BAR_OUTLINE.a * alpha))
		canvas.draw_rect(Rect2(c.x - hw, c.y - hh, BAR_WIDTH, BAR_HEIGHT), Color(BAR_BACKGROUND, BAR_BACKGROUND.a * alpha))
		if trail_frac > frac_hp:
			canvas.draw_rect(Rect2(c.x - hw, c.y - hh, BAR_WIDTH * trail_frac, BAR_HEIGHT), Color(BAR_TRAIL, BAR_TRAIL.a * alpha))
		if frac_hp > 0.0:
			var fill: Color = BAR_LOW.lerp(BAR_HIGH, frac_hp)
			canvas.draw_rect(Rect2(c.x - hw, c.y - hh, BAR_WIDTH * frac_hp, BAR_HEIGHT), Color(fill, alpha))


# --- test and probe seams ------------------------------------------------------

func get_active_count() -> int:
	var n: int = 0
	for s in _order:
		if s_active[s] == 1:
			n += 1
	return n


func get_band_instance_counts() -> PackedInt32Array:
	return _band_counts


func get_fx_pool_size() -> int:
	return _fx_pool.size()


func get_busy_fx_count() -> int:
	var n: int = 0
	for fx in _fx_pool:
		if is_instance_valid(fx) and (fx as DeathFx).visible:
			n += 1
	return n


func get_band_nodes() -> Array[MultiMeshInstance2D]:
	return _band_nodes


func get_profile_count() -> int:
	return _profiles.size()


func get_row_for(profile: Profile, anim: StringName) -> int:
	return int(profile.rows.get(anim, -1))


func get_slot_row(slot: int) -> int:
	return s_row[slot]


func get_slot_flags(slot: int) -> int:
	return s_fl[slot]


func force_fill_for_test() -> void:
	_dirty = false
	_fill()
