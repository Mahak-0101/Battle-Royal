shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_alpha_prepass;

uniform vec4 cloud_tint : hint_color = vec4(0.97, 0.98, 1.0, 1.0);
uniform vec4 shadow_tint : hint_color = vec4(0.73, 0.77, 0.83, 1.0);
uniform float cloud_scale = 0.0045;
uniform float cloud_speed = 0.004;
uniform float detail_scale = 0.012;
uniform float opacity = 0.34;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash(i + vec2(0.0, 0.0));
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.2, 11.3);
		amplitude *= 0.52;
	}
	return value;
}

void vertex() {
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wind = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.62);
	vec2 world_uv = world_pos.xz * cloud_scale + wind;
	vec2 detail_uv = world_pos.xz * detail_scale - wind * 0.7;

	float base = fbm(world_uv);
	float detail = fbm(detail_uv) * 0.45;
	float clouds = clamp(base + detail, 0.0, 1.0);

	float cloud_mask = smoothstep(0.48, 0.82, clouds);
	float softness = pow(cloud_mask, 1.25);

	float edge_x = smoothstep(0.02, 0.18, UV.x) * (1.0 - smoothstep(0.82, 0.98, UV.x));
	float edge_y = smoothstep(0.02, 0.18, UV.y) * (1.0 - smoothstep(0.82, 0.98, UV.y));
	float edge_fade = edge_x * edge_y;

	ALBEDO = mix(shadow_tint.rgb, cloud_tint.rgb, smoothstep(0.2, 0.95, clouds));
	ALPHA = softness * edge_fade * opacity;
}
