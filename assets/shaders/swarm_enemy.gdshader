shader_type canvas_item;
// PT-PERF (D390-D399): draws every plain swarm enemy from one MultiMesh instance
// buffer (SwarmRenderer). One QuadMesh of size 2x2 is placed per enemy; this shader
//   * picks the animation frame from the shared atlas (row table + SimClock ticks),
//   * places the sprite (frame size, offset, profile scale, horizontal flip, hit squash),
//   * interpolates the physics-tick position (cur - (cur - prev) * (1 - phys_frac)),
//   * adds the hit flash, status tint, and the steady / elite outline.
// It replaces AnimatedSprite2D + EnemyAnimator + enemy_outline.gdshader for these
// enemies. All gameplay state stays in EnemyController; the instance only carries
// presentation data. The Compatibility renderer stores colour and custom data as half
// floats, so every channel is a small integer (exact up to 2048):
//   INSTANCE_CUSTOM.x  animation start, SimClock ticks modulo 2048
//   INSTANCE_CUSTOM.y  animation row (profile x animation) into the tables below
//   INSTANCE_CUSTOM.z  animation speed code 0..63 (0.6 .. 1.8, code 21 = 1.0)
//   INSTANCE_CUSTOM.w  ticks since the last hit (0..7), 15 = none
//   COLOR.r            outline mode (0 none, 1 steady, 2 gold, 3 red) | status tint << 2 | flip << 4
//   COLOR.g, COLOR.b   (cur - prev) displacement, (d * 4 + 128) per axis

// Row tables, one entry per (profile, animation):
//   anim_a: first-frame atlas origin x, y (texels), frame count (negative = no loop), fps
//   anim_b: frame width, height (texels), sprite offset x, y (px, before the profile scale)
//   anim_c: profile tint rgb, profile scale
//   anim_d: steady (accessibility) outline colour rgb, unused
uniform vec4 anim_a[128];
uniform vec4 anim_b[128];
uniform vec4 anim_c[128];
uniform vec4 anim_d[128];
uniform sampler2D atlas_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_size = vec2(1344.0, 2304.0);
uniform float tick_clock = 0.0;
uniform float phys_frac = 1.0;
uniform float reduce_flashing = 0.0;

const float TICKS_PER_SECOND = 60.0;
const float TICK_RANGE = 2048.0;
const float HIT_FLASH_SECONDS = 0.08;
const float HIT_FLASH_BRIGHT = 2.4;
const float SQUASH_SECONDS = 0.12;
const float SQUASH_RISE_FRACTION = 0.35;
const vec2 SQUASH_SCALE = vec2(1.18, 0.82);
const vec3 ELITE_GOLD = vec3(1.0, 0.82, 0.2);
const vec3 ELITE_RED = vec3(1.0, 0.2, 0.15);
const vec3 TINT_BURN = vec3(1.35, 0.8, 0.45);
const vec3 TINT_SLOW = vec3(0.72, 0.88, 1.15);
const vec3 TINT_FREEZE = vec3(0.8, 1.05, 1.5);

varying vec2 v_uv;
varying flat vec2 v_origin;
varying flat vec2 v_fsize;
varying flat vec3 v_tint;
varying flat vec4 v_outline;

void vertex() {
	int row = int(INSTANCE_CUSTOM.y + 0.5);
	int sq = int(INSTANCE_CUSTOM.z + 0.5);
	float hit_age = INSTANCE_CUSTOM.w;
	int cf = int(COLOR.r + 0.5);
	int omode = cf & 3;
	int stint = (cf >> 2) & 3;
	float flip = ((cf >> 4) & 1) == 1 ? -1.0 : 1.0;
	vec2 disp = (vec2(COLOR.g, COLOR.b) - 128.0) * 0.25;

	vec4 a = anim_a[row];
	vec4 b = anim_b[row];
	vec4 c = anim_c[row];
	float speed = 0.6 + float(sq) * (1.2 / 63.0);
	float elapsed = mod(tick_clock - INSTANCE_CUSTOM.x + TICK_RANGE, TICK_RANGE) / TICKS_PER_SECOND;
	float f = floor(elapsed * a.w * speed);
	float count = abs(a.z);
	float idx = a.z > 0.0 ? mod(f, count) : min(f, count - 1.0);
	v_origin = vec2(a.x + idx * b.x, a.y);
	v_fsize = b.xy;

	// Hit squash (EnemyAnimator: x1.18/y0.82, sine out then settle, 0.12 s).
	float t = hit_age / TICKS_PER_SECOND;
	bool hit = hit_age < 8.0;
	float k = 0.0;
	if (hit && t < SQUASH_SECONDS) {
		float rise = SQUASH_SECONDS * SQUASH_RISE_FRACTION;
		if (t < rise) {
			k = sin(t / rise * 1.5707963);
		} else {
			float u = (t - rise) / (SQUASH_SECONDS - rise);
			k = (1.0 - u) * (1.0 - u);
		}
	}
	// Hit flash (modulate 2.4 -> tint over 0.08 s, linear; the tween replaces the resting tint).
	vec3 modulate = c.rgb;
	if (hit && t < HIT_FLASH_SECONDS && reduce_flashing < 0.5) {
		modulate = mix(vec3(HIT_FLASH_BRIGHT), c.rgb, t / HIT_FLASH_SECONDS);
	}
	vec3 status = vec3(1.0);
	if (stint == 1) {
		float flicker = 0.5 + 0.5 * sin(TIME * 6.2831853 * 7.0);
		if (reduce_flashing > 0.5) {
			flicker = 0.5;
		}
		status = mix(vec3(1.0), TINT_BURN, 0.5 + 0.5 * flicker);
	} else if (stint == 2) {
		status = TINT_SLOW;
	} else if (stint == 3) {
		status = TINT_FREEZE;
	}
	v_tint = modulate * status;

	vec3 oc = vec3(0.0);
	float ow = 0.0;
	if (omode == 1) {
		oc = anim_d[row].rgb;
		ow = 1.0;
	} else if (omode == 2) {
		oc = ELITE_GOLD;
		ow = 1.5;
	} else if (omode == 3) {
		oc = ELITE_RED;
		ow = 1.5;
	}
	v_outline = vec4(oc, ow);

	v_uv = VERTEX * 0.5 + 0.5;
	vec2 local = VERTEX * 0.5 * b.xy + b.zw;
	local *= c.w * mix(vec2(1.0), SQUASH_SCALE, k);
	local.x *= flip;
	VERTEX = local - disp * (1.0 - phys_frac);
}

float tap(vec2 f) {
	if (f.x < 0.0 || f.y < 0.0 || f.x > 1.0 || f.y > 1.0) {
		return 0.0;
	}
	return textureLod(atlas_tex, (v_origin + f * v_fsize) / atlas_size, 0.0).a;
}

void fragment() {
	vec4 tex = texture(atlas_tex, (v_origin + v_uv * v_fsize) / atlas_size);
	vec4 body = vec4(tex.rgb * v_tint, tex.a);
	if (v_outline.w > 0.0) {
		vec2 px = v_outline.w / v_fsize;
		float a = 0.0;
		a = max(a, tap(v_uv + vec2(px.x, 0.0)));
		a = max(a, tap(v_uv - vec2(px.x, 0.0)));
		a = max(a, tap(v_uv + vec2(0.0, px.y)));
		a = max(a, tap(v_uv - vec2(0.0, px.y)));
		a = max(a, tap(v_uv + vec2(px.x, px.y)));
		a = max(a, tap(v_uv - vec2(px.x, px.y)));
		a = max(a, tap(v_uv + vec2(px.x, -px.y)));
		a = max(a, tap(v_uv + vec2(-px.x, px.y)));
		float pulse = v_outline.w > 1.2 ? 1.0 - 0.45 * (0.5 + 0.5 * sin(TIME * 4.0)) : 1.0;
		float out_a = pulse * a * (1.0 - body.a);
		COLOR = vec4(mix(v_outline.rgb, body.rgb, body.a), max(body.a, out_a));
	} else {
		COLOR = body;
	}
}
