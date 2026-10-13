shader_type canvas_item;
// PT-PERF (D390-D399): the ground shadows of every plain swarm enemy, one MultiMesh
// (SwarmRenderer). The quad is the shadow texture's own size; per instance
//   INSTANCE_CUSTOM.x = profile scale (Visuals scale), COLOR.g / COLOR.b = packed
//   (cur - prev) displacement, interpolated like the body (see swarm_enemy.gdshader).

uniform float phys_frac = 1.0;
uniform vec2 shadow_offset = vec2(0.0, 2.0);

void vertex() {
	vec2 disp = (vec2(COLOR.g, COLOR.b) - 128.0) * 0.25;
	float s = INSTANCE_CUSTOM.x;
	VERTEX = (VERTEX + shadow_offset) * s - disp * (1.0 - phys_frac);
}

void fragment() {
	// COLOR already holds the instance colour (the packed displacement above): drop it.
	COLOR = texture(TEXTURE, UV);
}
