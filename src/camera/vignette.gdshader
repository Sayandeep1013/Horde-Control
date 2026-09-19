shader_type canvas_item;

// Subtle edge darkening for GameCamera (P2.2 task brief: "a subtle vignette
// or edge darkening ... Keep effects cheap and readable -- the readability
// hierarchy outranks visual density"). A single fullscreen radial fade, no
// texture sampling beyond the ColorRect's own solid colour, so the cost is
// one shader pass regardless of scene complexity.
//
// No Provisional Values Register row names a vignette; these three
// uniforms are stylistic constants, not gameplay numbers under CLAUDE.md's
// carve-out logic (they cannot be tuned in a way that changes the shape of
// the game -- only how dark the screen edge looks), so they are left as
// tunable uniforms with defaults here rather than added to the Register.

uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.55;
uniform float outer_radius : hint_range(0.0, 1.5) = 1.05;

void fragment() {
	// UV is normalized [0,1] across the ColorRect, which is anchored to
	// fill the full screen rect -- so this is screen-space regardless of
	// the camera's own world position or zoom.
	vec2 centered = UV - vec2(0.5);
	// Normalize so the screen corner (distance sqrt(0.5) from centre) maps
	// to 1.0, giving a consistent falloff shape independent of aspect
	// ratio (deliberately not aspect-corrected -- a faint ellipse reads as
	// a vignette just as well as a circle, and correcting it costs an extra
	// uniform this effect does not need).
	float dist = length(centered) / 0.70710678;
	float vignette = smoothstep(inner_radius, outer_radius, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity);
}
