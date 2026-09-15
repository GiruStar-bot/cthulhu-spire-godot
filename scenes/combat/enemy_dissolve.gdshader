shader_type canvas_item;
render_mode unshaded, blend_mix;

// Port of .enemy-dissolve: tiled dissolve_noise INTERSECT
// linear-gradient(to top, transparent gone% → black keep%).
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : filter_nearest, repeat_enable;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float from_bottom = 1.0 - UV.y;
	float gone_h = mix(-0.16, 0.84, progress);
	float keep_h = mix(0.0, 1.0, progress);
	float wipe = smoothstep(gone_h, max(keep_h, gone_h + 0.02), from_bottom);
	vec2 n_uv = FRAGCOORD.xy / 48.0;
	float n = texture(noise_tex, n_uv).r;
	float mask = clamp(wipe * n, 0.0, 1.0);
	float bright = mix(1.4, 0.5, progress);
	float sat = mix(1.15, 0.3, progress);
	float gray = dot(col.rgb, vec3(0.30, 0.50, 0.20));
	vec3 rgb = mix(vec3(gray), col.rgb, sat) * bright;
	float fade = mix(1.0, 0.0, progress);
	COLOR = vec4(rgb, col.a * mask * fade);
}
