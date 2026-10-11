shader_type canvas_item;
// v1.0 (WP-ENEMIES, docs/31 §5.2 and §8.4): outline around an enemy sprite.
// Elites use a pulsing gold (or red, Vampiric) outline; the Enemy outlines
// accessibility setting uses a steady 1 px intent-coloured one. Cosmetic only,
// so TIME (wall clock) is fine here.

uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.2, 1.0);
uniform float outline_width = 1.0;
uniform float pulse_speed = 0.0;
uniform float pulse_amount = 0.0;
// Palette swap (Bomber, D206): when swap_hue >= 0 the goblin's greens and olive
// basket are recoloured to that hue (0..1) at swap_saturation of their own
// saturation; the red dynamite, the white eyes and the dark outline lines stay.
uniform float swap_hue = -1.0;
uniform float swap_saturation = 0.8;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// In Godot 4 COLOR already holds texture x modulate when fragment() starts.
	vec4 body = COLOR;
	if (swap_hue >= 0.0 && body.a > 0.0) {
		vec3 hsv = rgb2hsv(body.rgb);
		bool greens = hsv.x > 0.22 && hsv.x < 0.55 && hsv.y > 0.2;
		bool basket = hsv.x >= 0.10 && hsv.x <= 0.22 && hsv.y > 0.3 && hsv.z < 0.8;
		if (greens || basket) {
			hsv.x = swap_hue;
			hsv.y *= swap_saturation;
			body.rgb = hsv2rgb(hsv);
		}
	}
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
