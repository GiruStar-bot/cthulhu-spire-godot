class_name SanityFrameStains
extends Control

## 低い正気度の「パネル枠のインク染み」（SanityFx の子）。画面の四隅は 3 つがパネルに隠れるので、
## HUD・ログ・ターン終了ボタンなどの枠にも段階（SanityTiers）を出す。
## 素材が無ければ何も描かない（代わりの描画なし）。

const TEX_FRAMES: Array[String] = [
	"res://art/pixel/fx/sanity_frame_1.png",
	"res://art/pixel/fx/sanity_frame_2.png",
	"res://art/pixel/fx/sanity_frame_3.png",
]
## 素材は 24x24、9-slice の余白は四辺 8px、辺はタイル前提で描かれている。
const PATCH_MARGIN := 8
## 素材の配置（#85 の実素材）：外側 0〜5px目は枠の外へ垂れるインク、6〜7px目がパネル外周 2px の線に重なる帯、
## 8px目から内側は透明。なので染みの矩形は常にパネルの矩形より各辺 6px 外へ広げる（帯とパネル外周線が揃う）。
const ART_BORDER_OUTSET := 6.0
const TIER_FADE := 0.6

var _panels: Array[Control] = []
var _stains: Array[NinePatchRect] = []
## 染みごとの切り抜き用の親（clip_contents）。隣の要素との隙間が 6px 未満の辺だけ、垂れたインクをそこで切る。
var _clips: Array[Control] = []
## 隣の要素（手札・敵の行動予告など）のグローバル矩形を返す Callable（-> Array[Rect2]）。
var _neighbor_source: Callable
var _tier: int = 0
var _tween: Tween


func _ready() -> void:
	name = "FrameStains"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_layout_all)
	set_process(false)


## 手札の扇や行動予告は毎ターン・ホバーで動くので、見えている間は毎フレーム切り抜きを合わせ直す（矩形 3 つ分で軽い）。
func _process(_delta: float) -> void:
	_layout_all()


func set_neighbor_source(source: Callable) -> void:
	_neighbor_source = source
	_layout_all()


## 染みを付けるパネルを登録（呼び直すと前の登録は消える）。
func set_panels(panels: Array[Control]) -> void:
	clear()
	for panel in panels:
		if panel == null or not is_instance_valid(panel):
			continue
		var stain := NinePatchRect.new()
		stain.name = "Stain_" + str(panel.name)
		stain.patch_margin_left = PATCH_MARGIN
		stain.patch_margin_top = PATCH_MARGIN
		stain.patch_margin_right = PATCH_MARGIN
		stain.patch_margin_bottom = PATCH_MARGIN
		stain.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		stain.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
		stain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		## パネルの外へ 2px はみ出すので、ボタンやカードのクリックを絶対に奪わない
		stain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var clip := Control.new()
		clip.name = "Clip_" + str(panel.name)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.visible = false
		## パネルと同じ絶対 z。SanityFx は Combat で後から足されるので、同じ z ならパネルの枠より手前に描かれる
		clip.z_as_relative = false
		clip.z_index = _absolute_z(panel)
		add_child(clip)
		clip.add_child(stain)
		_panels.append(panel)
		_stains.append(stain)
		_clips.append(clip)
		var relayout: Callable = _layout_all
		panel.item_rect_changed.connect(relayout)
		panel.visibility_changed.connect(relayout)
		panel.tree_exiting.connect(relayout, CONNECT_DEFERRED)
	_layout_all()
	set_tier(_tier, false)


## 段階 0 は全部隠す。1〜3 は sanity_frame_1〜3。reduce_motion ON なら即差し替え。
func set_tier(tier: int, animate: bool) -> void:
	_tier = clampi(tier, 0, TEX_FRAMES.size())
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var tex: Texture2D = null
	if _tier > 0:
		tex = _tex(TEX_FRAMES[_tier - 1])
	if not animate or VideoSettings.is_reduce_motion():
		_set_texture(tex)
		modulate.a = 1.0
		return
	_tween = create_tween()
	if _any_visible():
		_tween.tween_property(self, "modulate:a", 0.0, TIER_FADE * 0.5)
		_tween.tween_callback(_set_texture.bind(tex))
		_tween.tween_property(self, "modulate:a", 1.0, TIER_FADE * 0.5)
	else:
		modulate.a = 0.0
		_set_texture(tex)
		_tween.tween_property(self, "modulate:a", 1.0, TIER_FADE)


func current_tier() -> int:
	return _tier


func stains() -> Array[NinePatchRect]:
	return _stains


func clips() -> Array[Control]:
	return _clips


## 戦闘の決着・退出時：染みをすべて消し、パネルとのつながりも切る。
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for panel in _panels:
		if is_instance_valid(panel):
			for sig: Signal in [panel.item_rect_changed, panel.visibility_changed, panel.tree_exiting]:
				if sig.is_connected(_layout_all):
					sig.disconnect(_layout_all)
	for clip in _clips:
		if is_instance_valid(clip):
			clip.queue_free()
	_panels.clear()
	_stains.clear()
	_clips.clear()
	_tier = 0
	set_process(false)


func _exit_tree() -> void:
	clear()


func _set_texture(tex: Texture2D) -> void:
	for stain in _stains:
		stain.texture = tex
	_layout_all()


func _layout_all() -> void:
	var neighbors: Array[Rect2] = []
	if _neighbor_source.is_valid():
		neighbors.assign(_neighbor_source.call())
	var any_shown: bool = false
	for i in range(_stains.size()):
		var stain: NinePatchRect = _stains[i]
		var clip: Control = _clips[i]
		var panel: Control = _panels[i]
		var alive: bool = is_instance_valid(panel) and panel.is_inside_tree() and not panel.is_queued_for_deletion()
		clip.visible = alive and stain.texture != null and panel.is_visible_in_tree()
		if not clip.visible:
			continue
		any_shown = true
		var inner: Rect2 = panel.get_global_rect()
		var others: Array[Rect2] = neighbors.duplicate()
		for j in range(_panels.size()):
			if j != i and is_instance_valid(_panels[j]) and _panels[j].is_visible_in_tree():
				others.append(_panels[j].get_global_rect())
		var ext: Array[float] = FrameStainExtents.side_extents(inner, others, ART_BORDER_OUTSET)
		clip.global_position = inner.position - Vector2(ext[0], ext[1])
		clip.size = inner.size + Vector2(ext[0] + ext[2], ext[1] + ext[3])
		## 染みそのものは常に 6px 外へ（帯をパネル外周線に揃えたまま、垂れた部分だけ親で切る）
		stain.position = inner.position - Vector2(ART_BORDER_OUTSET, ART_BORDER_OUTSET) - clip.global_position
		stain.size = inner.size + Vector2(ART_BORDER_OUTSET, ART_BORDER_OUTSET) * 2.0
	set_process(any_shown)


func _any_visible() -> bool:
	for clip in _clips:
		if clip.visible:
			return true
	return false


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
