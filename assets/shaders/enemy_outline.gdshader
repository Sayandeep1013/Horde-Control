shader_type canvas_item;
// v1.0 (WP-ENEMIES, docs/31 §5.2 and §8.4): outline around an enemy sprite.
// Elites use a pulsing gold (or red, Vampiric) outline; the Enemy outlines
// accessibility setting uses a steady 1 px intent-coloured one. Cosmetic only,
// so TIME (wall clock) is fine here.

uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.2, 1.0);
uniform float outline_width = 1.0;
uniform float pulse_speed = 0.0;
uniform float pulse_amount = 0.0;

void fragment() {
	// In Godot 4 COLOR already holds texture x modulate when fragment() starts.
	vec4 body = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	float pulse = 1.0 - pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	float out_a = outline_color.a * pulse * a * (1.0 - body.a);
	COLOR = vec4(mix(outline_color.rgb, body.rgb, body.a), max(body.a, out_a));
}
