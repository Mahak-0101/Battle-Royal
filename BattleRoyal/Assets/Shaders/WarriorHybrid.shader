shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_tint : hint_color = vec4(0.56, 0.38, 0.28, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.62;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float toon_steps : hint_range(2.0, 6.0) = 3.0;
uniform float toon_mix : hint_range(0.0, 1.0) = 0.35;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec4 rim_color : hint_color = vec4(1.0, 0.88, 0.72, 1.0);

void fragment() {
	ALBEDO = albedo_tint.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float stepped = floor(ndl * toon_steps) / max(toon_steps - 1.0, 1.0);
	float lit = mix(ndl, stepped, toon_mix);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * lit * ATTENUATION;

	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.2) * rim_strength;
	DIFFUSE_LIGHT += rim_color.rgb * rim * ATTENUATION;
}
