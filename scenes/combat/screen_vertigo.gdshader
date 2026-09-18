shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float blur : hint_range(0.0, 1.0) = 0.0;
uniform float warp : hint_range(0.0, 1.0) = 0.0;
uniform float time_shift : hint_range(0.0, 40.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float w = warp * 0.010;
	uv.x += sin(uv.y * 16.0 + time_shift) * w;
	uv.y += cos(uv.x * 12.0 + time_shift * 0.65) * w * 0.65;

	vec2 px = vec2(blur * 0.0055, blur * 0.0055);
	vec4 c = texture(screen_texture, uv);
	c += texture(screen_texture, uv + vec2(px.x, 0.0));
	c += texture(screen_texture, uv - vec2(px.x, 0.0));
	c += texture(screen_texture, uv + vec2(0.0, px.y));
	c += texture(screen_texture, uv - vec2(0.0, px.y));
	c += texture(screen_texture, uv + px);
	c += texture(screen_texture, uv - px);
	c /= 7.0;

	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tone = mix(c.rgb, vec3(gray), blur * 0.32);
	tone = mix(tone, tone * vec3(0.86, 0.90, 0.96), warp * 0.22);
	COLOR = vec4(tone, 1.0);
}
