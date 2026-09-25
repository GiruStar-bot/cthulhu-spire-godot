shader_type canvas_item;

// 低い正気度の「彩度を少し落とす」だけのシェーダー。歪み・ぼかしは一切しない。
// SanityFx の z_index より下に描かれたもの（背景・敵）だけが対象。HUD や数値は上に描かれるので影響しない。
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c, vec3(l), amount), 1.0);
}
