shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	vec3 inverted = vec3(1.0) - c.rgb;
	COLOR = vec4(mix(c.rgb, inverted, amount), 1.0);
}
