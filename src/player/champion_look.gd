extends RefCounted
class_name ChampionLook
## v1.0 Champion look (WP-LOADOUT, docs/32 C1): a palette shift on the archer's
## blue (assets/shaders/champion_palette.gdshader), applied to the player's
## AnimatedSprite2D material, so it survives every animation and the hit flash
## (which tints `modulate`). Cosmetic only; the hues avoid the enemy intent colours
## (Seeker red, Hunter yellow, Opportunist purple; docs/19 shape language) and the
## Ranger keeps the pack's own blue. Register "v1.0 Loadout": Champion look.

const SHADER: Shader = preload("res://assets/shaders/champion_palette.gdshader")
const SPRITE_PATH: NodePath = NodePath("Visuals/Sprite2D")

## id -> [target hue, saturation, brightness]; Ranger is untouched (no material).
const PALETTES: Dictionary = {
	"warden": [0.075, 1.1, 0.95], # bronze (green would vanish on the grass)
	"skirmisher": [0.52, 0.12, 1.55], # near-white silver
	"pactbound": [0.60, 0.25, 0.42], # ash charcoal
}


static func has_look(champion_id: String) -> bool:
	return PALETTES.has(champion_id)


## Applies (or clears) the Champion's material on `player`'s sprite. Returns the
## material that was set, or null for the Ranger / no sprite.
static func apply(player: Node, champion_id: String) -> ShaderMaterial:
	var sprite: CanvasItem = player.get_node_or_null(SPRITE_PATH) as CanvasItem
	if sprite == null:
		return null
	if not PALETTES.has(champion_id):
		sprite.material = null
		return null
	var p: Array = PALETTES[champion_id]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("target_hue", float(p[0]))
	mat.set_shader_parameter("saturation", float(p[1]))
	mat.set_shader_parameter("brightness", float(p[2]))
	sprite.material = mat
	return mat
