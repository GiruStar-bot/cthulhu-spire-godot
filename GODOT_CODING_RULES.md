# GDScript コーディング規約・頻出パターン集
# Abyss of R'lyeh Godot版 — AI実装エージェント向け

このファイルはClaude Code / Codex / Grokが実装作業を行う前に必ず読むこと。
過去の実装で繰り返し発生したミスと、正しいパターンをまとめたもの。

---

## 1. 型推論の禁止パターン（最頻出バグ）

### NG: Dictionary.get() の戻り値を := で受ける
```gdscript
# BAD — Variantになりコンパイル警告/エラー
var value := some_dict.get("key", 0)

# GOOD — 明示的に型指定
var value: int = some_dict.get("key", 0)
var name: String = some_dict.get("name", "")
var items: Array = some_dict.get("items", [])
```

### NG: Callable.call() の戻り値を := で受ける
```gdscript
# BAD
var result := some_callable.call()

# GOOD
var result: float = float(some_callable.call())
var result: int = int(some_callable.call())
```

### NG: 存在しない bool() コンストラクタ
```gdscript
# BAD — GDScriptにbool()は存在しない
var flag := bool(some_dict.get("active"))

# GOOD — and/orはtruthinessを自動判定してboolを返す
var flag: bool = some_dict.get("active") and true
# または
var flag: bool = !!some_dict.get("active")  # ダブル否定でbool化
```

---

## 2. 存在しないGodot APIの使用禁止

### テキスト折り返し
```gdscript
# BAD — 存在しない
label.autowrap_mode = TextServer.AUTOWRAP_WORD_ARBITRARY

# GOOD
label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
```

### SceneTreeのシグナル
```gdscript
# BAD — Godot4には存在しない
get_tree().current_scene_changed.connect(func)

# GOOD — GameState.goto_scene()から明示的に呼び出す
# AudioManager.play_bgm_for_scene(scene_name) を goto_scene() 内で呼ぶ
```

### static関数をインスタンス経由で呼ぶ
```gdscript
# BAD — 警告が出る
CollectionData.peek_equipment(uid)  # インスタンス経由

# GOOD — クラス名から直接呼ぶ
CollectionData.peek_equipment(uid)  # CollectionDataはAutoloadなので実はOK
# staticと宣言されている関数は: ClassName.func_name() で呼ぶ
```

---

## 3. 組み込み関数名との衝突を避ける

以下の名前は GDScript 組み込み関数と衝突するため変数名に使わない:
- `seed` → `rng_seed` や `run_seed` を使う
- `floor` → `current_floor` や `floor_num` を使う
- `log` → `log_text` や `combat_log` を使う
- `wrap` → `wrap_mode` や `text_wrap` を使う

---

## 4. テクスチャの安全なロード（必須パターン）

```gdscript
# 必ずこの関数を使ってテクスチャをロードすること
func _load_texture_safe(path: String) -> Texture2D:
    if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
        return load("res://art/pixel/ui/card_back.png")  # フォールバック
    var resource: Resource = ResourceLoader.load(path, "Texture2D")
    if resource is Texture2D:
        return resource as Texture2D
    push_warning("Texture2Dとして読み込めませんでした: %s" % path)
    return load("res://art/pixel/ui/card_back.png")
```

---

## 5. ノードパスの整合性（必須チェック）

シーン構造を変更した際は必ず以下を確認すること:
- .tscn のノード名と .gd の @onready var のパスが一致しているか
- 新しいラッパーノードを追加した場合、既存の子パスが変わっていないか
- 過去に繰り返し発生した事故: MainMenu, Combat, Hubで「ラッパー追加 → パス不一致」

```gdscript
# 検証コマンド（実装後に必ず実行）
# python3 -c "
# import re
# gd = open('scenes/hub/Hub.gd').read()
# tscn = open('scenes/hub/Hub.tscn').read()
# node_names = set(re.findall(r'\[node name=\"([^\"]+)\"', tscn))
# paths = re.findall(r'\\\$([A-Za-z0-9_/]+)', gd)
# missing = [p for p in paths if p.split('/')[-1] not in node_names]
# print('Missing:', missing if missing else 'OK')
# "
```

---

## 6. visibility制御の必須パターン

タブ切り替え時は必ず全パネルをリセットしてから対象のみ表示:

```gdscript
func _hide_all_content_panels() -> void:
    descend_panel.visible = false
    deck_panel.visible = false
    equipment_panel.visible = false
    sell_panel.visible = false
    commerce_panel.visible = false
    # 追加したパネルがあれば必ずここに追加する

func _select_tab(tab_name: String) -> void:
    _hide_all_content_panels()
    match tab_name:
        "descend": descend_panel.visible = true
        "deck":    deck_panel.visible = true
        # ...
```

---

## 7. 画像ファイルの注意事項

- `art/pixel/packs/pack_*.png` は実体がJPEGのファイルが存在した（修正済み）
  → 新しく追加する画像は必ず実際のPNG形式であることを `file` コマンドで確認
- カード画像114件中11件が未存在（card_backにフォールバック済み）
  → ancient_wisdom, order_protection, calm_blessing, sealing_moment, wardlight_afterglow 等

---

## 8. プロジェクト構成の基本

```
autoload/
  GameState.gd      # HP/SAN/階層/ラン状態（混同禁止）
  CollectionData.gd # カード/装備/デッキ/ルーン（混同禁止）
  AudioManager.gd   # BGM/SFX管理

scripts/            # ロジッククラス（Autoloadではない）
  cards.gd          # Cards.CARDS, Cards.get_card(), Cards.weighted_card()
  combat.gd         # CombatLogic
  equipment.gd      # Equipment
  smith.gd          # Smith.make_smith()
  enemies.gd, enemy_ai.gd, floors.gd, mulberry32.gd, profile.gd, runes.gd

scenes/             # 各画面
  hub/Hub.gd+Hub.tscn
  combat/Combat.gd+Combat.tscn
  main_menu/MainMenu.gd+MainMenu.tscn
  rest/Rest.gd+Rest.tscn
  reward/, event/, end/, shatter/

art/
  pixel/cards/      # カードアート（.jpg）
  pixel/packs/      # パックアート（.png、PNGであることを確認済み）
  pixel/tickets/    # チケットアイコン（.png）
  pixel/equipment/  # 装備アイコン（.jpg）
  pixel/enemies/    # 敵画像（.png）
  pixel/ui/         # UIアセット（card_back.pngはフォールバック先）
```

---

## 9. 実装後の必須チェックリスト

実装完了・push前に必ず以下を全て実行すること:

```bash
# 1. GDScriptエラーチェック
godot --headless --quit 2>&1

# 2. ノードパス整合性チェック（Hub.gd/Hub.tscnの場合の例）
python3 -c "
import re
gd = open('scenes/hub/Hub.gd').read()
tscn = open('scenes/hub/Hub.tscn').read()
node_names = set(re.findall(r'\[node name=\"([^\"]+)\"', tscn))
paths = re.findall(r'\\\$([A-Za-z0-9_/]+)', gd)
missing = [p for p in paths if p.split('/')[-1] not in node_names]
print('Total:', len(paths), '/ Missing:', missing if missing else 'None')
"

# 3. Variant型推論の危険パターン検索
grep -n ":= .*\.get(" scenes/hub/Hub.gd

# 4. 架空APIの検索
grep -n "AUTOWRAP_WORD_ARBITRARY\|current_scene_changed\|bool(" scenes/**/*.gd
```

---

## 10. 絶対に触れないファイル（ロジック層）

以下のファイルはビジュアル実装時に変更禁止:
- `autoload/GameState.gd`
- `autoload/CollectionData.gd`
- `scripts/` 配下の全ファイル

変更が必要な場合は必ずこのチャットで確認を取ること。
