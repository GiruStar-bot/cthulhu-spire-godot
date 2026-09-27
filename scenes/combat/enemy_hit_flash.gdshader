shader_type canvas_item;
render_mode unshaded, blend_mix;

// 被弾の白フラッシュ。色は捨てて、アルファの形だけ白くする。
// flash=0 で元の色、1 で真っ白。暗いドットも白くなる。
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, vec3(1.0), flash), tex.a);
}
