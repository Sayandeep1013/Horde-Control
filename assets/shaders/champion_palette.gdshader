shader_type canvas_item;
// WP-LOADOUT: Champion palette shift for the Tiny Swords archer (docs/32 C1). Only
// the pack's blue (the tunic, hood and quiver trim) moves; skin, wood and steel keep
// their colours so every Champion still reads as the same archer. Rotates the hue of
// blue pixels toward `target_hue`, then scales their saturation and brightness.
uniform float target_hue : hint_range(0.0, 1.0) = 0.6;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

const float BLUE_HUE = 0.6;

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
	vec4 col = COLOR;
	vec3 hsv = rgb2hsv(col.rgb);
	// 1 on blue-hued, reasonably saturated pixels; fades to 0 outside +-0.14 of blue.
	float w = (1.0 - smoothstep(0.07, 0.14, abs(hsv.x - BLUE_HUE))) * smoothstep(0.12, 0.3, hsv.y);
	vec3 shifted = hsv;
	shifted.x = target_hue;
	shifted.y = clamp(hsv.y * saturation, 0.0, 1.0);
	shifted.z = clamp(hsv.z * brightness, 0.0, 1.0);
	col.rgb = mix(col.rgb, hsv2rgb(shifted), w);
	COLOR = col;
}
