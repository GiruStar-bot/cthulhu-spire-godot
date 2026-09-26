class_name SanityTendrils
extends Control

## 低い正気度の触手（GDD v1.1 §5）。段階は累積：1＝ターン終了ボタン、2＝＋ログ、3＝＋HUD（先端に目）。
## アニメは段階が変わった瞬間だけ。SanityFx の子として置き、各パネルと同じ絶対 z で描く
## （ログは clip_contents なのでパネルの子にはしない）。素材が無い触手は描かない。
## 段階3の HUD は前後 2 枚（HUD_SPLIT）。前面はここ（UI の上）、背面は戦闘の背景と敵の絵の間に置く。

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
## 段階3の HUD の触手を前後 2 枚に分けた素材（#93）。2 枚ともあれば SPECS の 1 枚の hud.png より優先する。
##  front：今までの HUD の触手と同じ所（UI の上、HUD と同じ z）。先端の目もこちら。
##  back ：戦闘の背景の上・敵の絵の下（panels["enemy_row"] の直前の兄弟）。UI はすべてこの上に描かれる。
##  2 枚は 1 本の絵を列で分けたもの。同じコマ番号を出せば継ぎ目なくつながる（コマは front が決め、back は写すだけ）。
##  コマの大きさ・コマ数・付け根・目の位置はここだけ。コマを広げる（160〜200px など）ときは数字を変えるだけでよい
##  （付け根は左上基準なので、右へ広げるなら anchor はそのまま）。
const HUD_SPLIT := {
	"tier": 3, "panel": "hud",
	"tex": "res://art/pixel/fx/sanity_tendril_hud_front.png",
	"back_tex": "res://art/pixel/fx/sanity_tendril_hud_back.png",
	"frame": Vector2i(128, 80), "frames": 14, "corner": Vector2(0, 0), "anchor": Vector2i(4, 3),
	## 待機 A / B での目の左上（front の原寸 px）。成長 9〜11 は素材に描かれている
	"eye_idle": [Vector2i(33, 1), Vector2i(34, 1)],
}
const TEX_EYE := "res://art/pixel/fx/sanity_eye.png"
## HUD の触手の目：待機コマ A/B での目の左上（素材の原寸 px。A は伸びきったコマと同じ位置）。
## 既定は描き直した素材（#92）。旧素材の位置も持ち、待機コマ A に sanity_eye.png の開いた目が
## その位置にそのまま描かれている方を選ぶ（どちらの素材でも瞬きがずれない）。
const EYE_POS_IDLE: Array[Vector2i] = [Vector2i(41, 1), Vector2i(42, 1)]
const EYE_POS_IDLE_OLD: Array[Vector2i] = [Vector2i(47, 1), Vector2i(48, 1)]
## 瞬きのコマは透明な所があるので、先に目の 12x8 をこの色で塗ってから重ねる
const EYE_LID_COLOR := Color("0b0f0e")

var _tier: int = 0
## 敗北で固めた後は段階の変化を受け付けない
var _frozen: bool = false
var _panels: Dictionary = {}
var _tendrils: Dictionary = {}  # tier -> SanityTendril
var _specs: Dictionary = {}  # tier -> 実際に使っている spec（段階3は HUD_SPLIT か SPECS の hud）


func _ready() -> void:
	name = "Tendrils"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	VideoSettings.get_instance().changed.connect(_on_reduce_motion_changed)


## panels: {"end_turn": Control, "log": Control, "hud": Control, "enemy_row": Control}
## enemy_row は段階3の背面を差し込む位置（その直前の兄弟）。無ければ背面は前面のすぐ下に描く。
func set_panels(panels: Dictionary) -> void:
	clear()
	_panels = panels
	for base in SPECS:
		var spec: Dictionary = resolve_spec(int(base.tier))
		if spec.is_empty():
			continue
		var panel: Control = panels.get(spec.panel) as Control
		var sheet: Texture2D = _tex(str(spec.tex))
		if panel == null or sheet == null:
			continue
		var t := SanityTendril.new()
		t.name = "Tendril_" + str(spec.panel)
		t.setup(sheet, spec.frame, ART_SCALE, int(spec.get("frames", -1)))
		t.z_as_relative = false
		t.z_index = _absolute_z(panel)
		if int(spec.tier) == 3:
			var eyes: Array[Texture2D] = _eye_frames()
			if not eyes.is_empty():
				var cands: Array = [spec.eye_idle] if spec.has("eye_idle") else [EYE_POS_IDLE, EYE_POS_IDLE_OLD]
				t.enable_eye(eyes, eye_pos_idle(sheet, spec.frame, t.grow_count(), cands))
		add_child(t)
		if spec.has("back_tex"):
			var back: SanityTendril.Layer = t.add_layer(_tex(str(spec.back_tex)))
			back.name = "Tendril_" + str(spec.panel) + "_back"
			_attach_back(back, t, panels.get("enemy_row") as Control)
		_tendrils[int(spec.tier)] = t
		_specs[int(spec.tier)] = spec
	_layout()


## 段階ごとに使う spec。段階3は front/back が 2 枚ともあれば HUD_SPLIT、無ければ 1 枚の hud.png、
## それも無ければ {}（その段階の触手は描かない）。
func resolve_spec(tier: int) -> Dictionary:
	if tier == int(HUD_SPLIT.tier) and _tex(str(HUD_SPLIT.tex)) != null and _tex(str(HUD_SPLIT.back_tex)) != null:
		return HUD_SPLIT
	for spec in SPECS:
		if int(spec.tier) == tier:
			return spec if _tex(str(spec.tex)) != null else {}
	return {}


## 実際に使っている spec（触手が無い段階は {}）
func spec_for(tier: int) -> Dictionary:
	return _specs.get(tier, {})


## 段階の背面（無ければ null）
func back_layer(tier: int) -> SanityTendril.Layer:
	var t: SanityTendril = _tendrils.get(tier) as SanityTendril
	return t.layer(0) if t != null else null


## 背面を敵の絵の入れ物（EnemyRow）の直前の兄弟にする。z は相対 0（EnemyRow の親と同じ）なので、
## 同じ z の背景・ベール・上端の暗がり・EnemyStage より後（上）、EnemyRow（z=1）とその中の敵の絵より下、
## 後ろの兄弟（メッセージ、手札、ボタン等）より下になる。EnemyRow が無ければ前面の直前（同じ z）に置く。
func _attach_back(back: Control, front: SanityTendril, enemy_row: Control) -> void:
	if enemy_row != null and is_instance_valid(enemy_row) and enemy_row.get_parent() != null:
		var parent: Node = enemy_row.get_parent()
		parent.add_child(back)
		parent.move_child(back, enemy_row.get_index())
		back.z_as_relative = true
		back.z_index = 0
	else:
		add_child(back)
		move_child(back, front.get_index())
		back.z_as_relative = false
		back.z_index = front.z_index


## 段階の反映。上がったら新しく要る触手を同時に伸ばし、下がったら新しい段階より上だけ退かせる。
func set_tier(tier: int) -> void:
	tier = clampi(tier, 0, SPECS.size())
	var old: int = _tier
	if tier == old or _frozen:
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


## 戦闘開始時の段階（前の戦闘から持ち越した正気度）。伸びるアニメも changed も音も出さず、
## 段階ぶんの触手を伸びきったコマですぐ出して待機（reduce_motion は静止）。以後の set_tier はこの段階から。
func show_tier_now(tier: int) -> void:
	tier = clampi(tier, 0, SPECS.size())
	if _frozen:
		return
	_tier = tier
	var reduce: bool = VideoSettings.is_reduce_motion()
	for t in _tendrils.keys():
		var node: SanityTendril = _tendrils[t] as SanityTendril
		if int(t) <= tier:
			node.show_grown(reduce)
		else:
			node.hide_now()
	_layout()


## 敗北時（GDD §8）：見えている触手を伸びきったコマで固め、戦闘シーンが消えるまで残す。
## 揺れ・瞬き・退く・音はなし。以後の段階の変化も無視する。
## all_tiers=true（正気度0の敗北）：段階に関係なく 3 本とも即座に出して固める（changed は出さない）。
func freeze_all(all_tiers: bool = false) -> void:
	_frozen = true
	for node in _tendrils.values():
		if is_instance_valid(node):
			(node as SanityTendril).freeze(all_tiers)
	_layout()


func is_frozen() -> bool:
	return _frozen


func current_tier() -> int:
	return _tier


func tendril(tier: int) -> SanityTendril:
	return _tendrils.get(tier) as SanityTendril


## 画面上の左上 = パネルの角 − anchor × 3（パネルが動いたら毎フレーム追う）
static func place_for(panel_rect: Rect2, spec: Dictionary) -> Vector2:
	var corner: Vector2 = panel_rect.position + panel_rect.size * (spec.corner as Vector2)
	return corner - Vector2(spec.anchor as Vector2i) * ART_SCALE


## 勝ったとき（と逃げられたとき）・パネルを付け直すとき：音を出さずに全部消す。
func clear() -> void:
	for node in _tendrils.values():
		if is_instance_valid(node):
			(node as SanityTendril).free_layers()
			(node as Node).queue_free()
	_tendrils.clear()
	_specs.clear()
	_tier = 0
	_frozen = false


func _process(_delta: float) -> void:
	_layout()


func _layout() -> void:
	for tier in _specs.keys():
		var spec: Dictionary = _specs[tier]
		var node: SanityTendril = _tendrils.get(tier) as SanityTendril
		var panel: Control = _panels.get(spec.panel) as Control
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		if panel == null or not is_instance_valid(panel) or not panel.is_inside_tree():
			node.hide_now()
			continue
		node.global_position = place_for(panel.get_global_rect(), spec)
		node.sync_layers()


## 素材から読んだ伸びる尺（無ければ 12fps のコマ数どおりの既定値）
func _duration(tier: int, grow: bool) -> float:
	var node: SanityTendril = _tendrils.get(tier) as SanityTendril
	var fallback: Array[float] = [0.0, 8.0, 10.0, 12.0]
	var full: float = node.grow_duration() if node != null else fallback[tier] / SanityTendril.FPS
	return full if grow else full / SanityTendril.RETRACT_SPEED


## 待機コマ A（index grow）に開いた目が描かれている位置の組を candidates から返す。
## どれも合わなければ candidates の先頭（既定は 1 枚の hud.png 用：#92、旧素材）。
func eye_pos_idle(sheet: Texture2D, frame: Vector2i, grow: int, candidates: Array = [EYE_POS_IDLE, EYE_POS_IDLE_OLD]) -> Array[Vector2i]:
	var art: Image = _rgba(sheet)
	var eye: Image = _rgba(_tex(TEX_EYE))
	var out: Array[Vector2i] = []
	if art != null and eye != null:
		for cand in candidates:
			if _eye_drawn_at(art, eye, Vector2i(grow * frame.x, 0) + (cand as Array)[0]):
				out.assign(cand)
				return out
	out.assign(candidates[0])
	return out


## sanity_eye.png の 1 コマ目（開いた目）の不透明ピクセルが art の at にそのまま描かれているか
static func _eye_drawn_at(art: Image, eye: Image, at: Vector2i) -> bool:
	var fs: Vector2i = SanityTendril.EYE_FRAME
	if at.x < 0 or at.y < 0 or at.x + fs.x > art.get_width() or at.y + fs.y > art.get_height():
		return false
	for y in fs.y:
		for x in fs.x:
			var c: Color = eye.get_pixel(x, y)
			if c.a > 0.5 and not art.get_pixel(at.x + x, at.y + y).is_equal_approx(c):
				return false
	return true


static func _rgba(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _eye_frames() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var img: Image = _rgba(_tex(TEX_EYE))
	if img == null:
		return out
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
		if is_instance_valid(node):
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
