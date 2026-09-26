class_name SanityTendrils
extends Control

## 低い正気度の触手（GDD v1.1 §5）。段階は累積：1＝ターン終了ボタン、2＝＋ログ、3＝＋HUD（先端に目）。
## アニメは段階が変わった瞬間だけ。SanityFx の子として置き、各パネルと同じ絶対 z で描く
## （ログは clip_contents なのでパネルの子にはしない）。素材が無い触手は描かない。

## 段階が変わった瞬間に 1 回だけ（段階を飛ばしても 1 回、一番上の段階で）。音と合わせる用。
signal changed(tier: int, duration: float, is_retract: bool)

## 原寸で描かれた素材を 3 倍・nearest で表示
const ART_SCALE := 3.0
## 付け根（デザインくん指定）：画面上の左上 = パネルの角 − anchor × 3。
##  corner はパネル矩形内の割合（(1,1)=右下、(1,0)=右上、(0,0)=左上）、anchor は素材の原寸 px。
##  1152x648 での左上：ターン終了 (1008,504)、ログ (960,1)、HUD (0,1)
const SPECS: Array[Dictionary] = [
	{"tier": 1, "panel": "end_turn", "tex": "res://art/pixel/fx/sanity_tendril_endturn.png",
		"frame": Vector2i(48, 48), "corner": Vector2(1, 1), "anchor": Vector2i(42, 42)},
	{"tier": 2, "panel": "log", "tex": "res://art/pixel/fx/sanity_tendril_log.png",
		"frame": Vector2i(64, 64), "corner": Vector2(1, 0), "anchor": Vector2i(60, 3)},
	{"tier": 3, "panel": "hud", "tex": "res://art/pixel/fx/sanity_tendril_hud.png",
		"frame": Vector2i(80, 64), "corner": Vector2(0, 0), "anchor": Vector2i(4, 3)},
]
const TEX_EYE := "res://art/pixel/fx/sanity_eye.png"
## HUD の触手の目：待機コマ A/B での目の左上（素材の原寸 px。A は伸びきったコマと同じ位置）
const EYE_POS_IDLE: Array[Vector2i] = [Vector2i(47, 1), Vector2i(48, 1)]
## 瞬きのコマは透明な所があるので、先に目の 12x8 をこの色で塗ってから重ねる
const EYE_LID_COLOR := Color("0b0f0e")

var _tier: int = 0
var _panels: Dictionary = {}
var _tendrils: Dictionary = {}  # tier -> SanityTendril


func _ready() -> void:
	name = "Tendrils"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	VideoSettings.get_instance().changed.connect(_on_reduce_motion_changed)


## panels: {"end_turn": Control, "log": Control, "hud": Control}
func set_panels(panels: Dictionary) -> void:
	clear()
	_panels = panels
	for spec in SPECS:
		var panel: Control = panels.get(spec.panel) as Control
		var sheet: Texture2D = _tex(str(spec.tex))
		if panel == null or sheet == null:
			continue
		var t := SanityTendril.new()
		t.name = "Tendril_" + str(spec.panel)
		t.setup(sheet, spec.frame, ART_SCALE)
		t.z_as_relative = false
		t.z_index = _absolute_z(panel)
		if int(spec.tier) == 3:
			var eyes: Array[Texture2D] = _eye_frames()
			if not eyes.is_empty():
				t.enable_eye(eyes, EYE_POS_IDLE)
		add_child(t)
		_tendrils[int(spec.tier)] = t
	_layout()


## 段階の反映。上がったら新しく要る触手を同時に伸ばし、下がったら新しい段階より上だけ退かせる。
func set_tier(tier: int) -> void:
	tier = clampi(tier, 0, SPECS.size())
	var old: int = _tier
	if tier == old:
		return
	_tier = tier
	var reduce: bool = VideoSettings.is_reduce_motion()
	var grow: bool = tier > old
	var top: int = tier if grow else old
	for t in range(mini(old, tier) + 1, maxi(old, tier) + 1):
		var node: SanityTendril = _tendrils.get(t) as SanityTendril
		if node == null:
			continue
		if grow:
			node.play_grow(reduce)
		else:
			node.play_retract(reduce)
	_layout()
	changed.emit(top, _duration(top, grow), not grow)


func current_tier() -> int:
	return _tier


func tendril(tier: int) -> SanityTendril:
	return _tendrils.get(tier) as SanityTendril


## 画面上の左上 = パネルの角 − anchor × 3（パネルが動いたら毎フレーム追う）
static func place_for(panel_rect: Rect2, spec: Dictionary) -> Vector2:
	var corner: Vector2 = panel_rect.position + panel_rect.size * (spec.corner as Vector2)
	return corner - Vector2(spec.anchor as Vector2i) * ART_SCALE


## 勝敗が決まったとき・戦闘を出るとき：音を出さずに全部消す。
func clear() -> void:
	for node in _tendrils.values():
		if is_instance_valid(node):
			(node as Node).queue_free()
	_tendrils.clear()
	_tier = 0


func _process(_delta: float) -> void:
	_layout()


func _layout() -> void:
	for spec in SPECS:
		var node: SanityTendril = _tendrils.get(int(spec.tier)) as SanityTendril
		var panel: Control = _panels.get(spec.panel) as Control
		if node == null or not node.visible:
			continue
		if panel == null or not is_instance_valid(panel) or not panel.is_inside_tree():
			node.hide_now()
			continue
		node.global_position = place_for(panel.get_global_rect(), spec)


## 素材から読んだ伸びる尺（無ければ 12fps のコマ数どおりの既定値）
func _duration(tier: int, grow: bool) -> float:
	var node: SanityTendril = _tendrils.get(tier) as SanityTendril
	var fallback: Array[float] = [0.0, 8.0, 10.0, 12.0]
	var full: float = node.grow_duration() if node != null else fallback[tier] / SanityTendril.FPS
	return full if grow else full / SanityTendril.RETRACT_SPEED


func _eye_frames() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var sheet: Texture2D = _tex(TEX_EYE)
	if sheet == null:
		return out
	var img: Image = sheet.get_image()
	if img == null:
		return out
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var fw: int = SanityTendril.EYE_FRAME.x
	var fh: int = SanityTendril.EYE_FRAME.y
	for f in range(img.get_width() / fw):
		var frame := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
		frame.fill(EYE_LID_COLOR)
		frame.blend_rect(img, Rect2i(f * fw, 0, fw, fh), Vector2i.ZERO)
		out.append(ImageTexture.create_from_image(frame))
	return out


func _on_reduce_motion_changed(enabled: bool) -> void:
	for node in _tendrils.values():
		(node as SanityTendril).set_reduce_motion(enabled)


static func _absolute_z(item: CanvasItem) -> int:
	var z: int = 0
	var node: Node = item
	while node is CanvasItem:
		var ci := node as CanvasItem
		z += ci.z_index
		if not ci.z_as_relative:
			break
		node = node.get_parent()
	return z


func _tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return ResourceLoader.load(path, "Texture2D") as Texture2D
