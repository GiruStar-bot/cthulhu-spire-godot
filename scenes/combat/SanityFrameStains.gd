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
## 前提：素材の外側 2px（0〜1px目）は枠の外へにじむインク、2〜3px目がパネル外周 2px の線に重なる。
## なので染みの矩形はパネルの矩形より各辺 2px 外へ広げる（=パネル外周線と素材の線が揃う）。
const ART_BORDER_OUTSET := 2.0
const TIER_FADE := 0.6

var _panels: Array[Control] = []
var _stains: Array[NinePatchRect] = []
var _tier: int = 0
var _tween: Tween


func _ready() -> void:
	name = "FrameStains"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_layout_all)


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
		stain.visible = false
		## パネルと同じ絶対 z。SanityFx は Combat で後から足されるので、同じ z ならパネルの枠より手前に描かれる
		stain.z_as_relative = false
		stain.z_index = _absolute_z(panel)
		add_child(stain)
		_panels.append(panel)
		_stains.append(stain)
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


## 戦闘の決着・退出時：染みをすべて消し、パネルとのつながりも切る。
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for panel in _panels:
		if is_instance_valid(panel):
			for sig: Signal in [panel.item_rect_changed, panel.visibility_changed, panel.tree_exiting]:
				if sig.is_connected(_layout_all):
					sig.disconnect(_layout_all)
	for stain in _stains:
		if is_instance_valid(stain):
			stain.queue_free()
	_panels.clear()
	_stains.clear()
	_tier = 0


func _exit_tree() -> void:
	clear()


func _set_texture(tex: Texture2D) -> void:
	for stain in _stains:
		stain.texture = tex
	_layout_all()


func _layout_all() -> void:
	for i in range(_stains.size()):
		var stain: NinePatchRect = _stains[i]
		var panel: Control = _panels[i]
		var alive: bool = is_instance_valid(panel) and panel.is_inside_tree() and not panel.is_queued_for_deletion()
		stain.visible = alive and stain.texture != null and panel.is_visible_in_tree()
		if not stain.visible:
			continue
		var rect: Rect2 = panel.get_global_rect().grow(ART_BORDER_OUTSET)
		stain.global_position = rect.position
		stain.size = rect.size


func _any_visible() -> bool:
	for stain in _stains:
		if stain.visible:
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
