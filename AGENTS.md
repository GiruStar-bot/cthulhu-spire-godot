# # Agent Working Agreements — Abyss of R'lyeh (Godot移植)

このファイルは Claude Code / Codex / Grok Build が作業開始時に必ず読むこと。

## プロジェクト概要（1行）
React/TypeScript製デッキビルドローグライク「Abyss of R'lyeh」を
Godot 4.7 + GDScriptに移植中。ロジックは移植済み、UIを刷新中。

## リポジトリ
- Godot版: https://github.com/GiruStar-bot/cthulhu-spire-godot (main)
- React原作参照用: https://github.com/GiruStar-bot/cthulhu-spire (参照のみ)

## 役割分担
- Claude Code: 構造・ロジック・マージ統合
- Codex: ビジュアル・UI（scenes/*.tscn / scenes/*.gdのUI層のみ）
- Grok: カード・戦闘・敵AIなどゲームロジックの重実装
- Claude（このチャット）: 監督・設計・検証・タスク割り当て

---

## GDScriptコーディング規約（Godot Gameplay Scripterスタイル）

### 必須：静的型付け
```gdscript
# BAD — 型なし
var value := some_dict.get("key", 0)
var enemy = get_node("Enemy")

# GOOD — 明示的型指定
var value: int = some_dict.get("key", 0)
@onready var enemy: EnemyBase = $Enemy
```

### 必須：シグナルの型付け
```gdscript
# BAD
signal health_changed  # パラメータ型なし

# GOOD
signal health_changed(new_health: float)
signal card_played(card_uid: String, target_id: String)
```

### 必須：コンポーネント設計
- 1スクリプト = 1つの責務（200行以内を目安）
- 上位ノードへの通知はシグナルで行う（get_parent()禁止）
- シーン単体でF6実行してクラッシュしないこと

### 禁止パターン（過去に繰り返し発生したバグ）
```gdscript
# NG: Variant型推論
var value := dict.get("key", 0)  # → var value: int = dict.get("key", 0)

# NG: 存在しないAPI
label.autowrap_mode = TextServer.AUTOWRAP_WORD_ARBITRARY  # → AUTOWRAP_ARBITRARY

# NG: bool()コンストラクタ
var flag := bool(dict.get("active"))  # → var flag: bool = dict.get("active") and true

# NG: 組み込み関数と同名の変数
var floor: int = 0  # → var current_floor: int = 0
var seed: int = 0   # → var rng_seed: int = 0
```

---

## 作業ルール

### 開始前に必ず行うこと
1. `GODOT_CODING_RULES.md` を読む
2. `git pull origin main` で最新化
3. 新しいブランチを切る（例: `codex/task-name`, `grok/task-name`）
4. 残クォータを確認（後述）

### 実装禁止（ビジュアル担当Codex向け）
- `autoload/GameState.gd`
- `autoload/CollectionData.gd`
- `scripts/` 配下の全ファイル
変更が必要な場合はClaudeに確認すること。

### 完了時の必須チェック（push前）
```bash
# 1. スクリプトエラー確認
godot --headless --quit 2>&1

# 2. ノードパス整合性確認（Hub.gd/Hub.tscnの場合の例）
python3 -c "
import re
gd = open('scenes/hub/Hub.gd').read()
tscn = open('scenes/hub/Hub.tscn').read()
node_names = set(re.findall(r'\[node name=\"([^\"]+)\"', tscn))
paths = re.findall(r'\\\$([A-Za-z0-9_/]+)', gd)
missing = [p for p in paths if p.split('/')[-1] not in node_names]
print('Missing:', missing if missing else 'OK')
"

# 3. 禁止パターン検索
grep -n "AUTOWRAP_WORD_ARBITRARY\|current_scene_changed\|bool(" scenes/**/*.gd
grep -n ":= .*\.get(" scenes/**/*.gd
```

### 完了報告フォーマット
```
### USAGE REPORT
- agent: [Claude Code | Codex | Grok]
- task: （1行）
- status: [done | blocked | partial]
- files changed: （パスのみ）
- quota remaining: [unknown | /usageの数値]
- next: （Claudeへの引き継ぎ1行）
```

---

## クォータリセット情報
| エージェント | リセット時刻 | 確認方法 |
|---|---|---|
| Claude Code | 毎週土曜 20:00 JST | `/usage` |
| Codex | 2026/09/19 18:38 JST（以降約1週間ごと） | `/status` |
| Grok Build | 毎日 18:15 JST | grok.com → Settings → Usage |

残量が少ない場合は小タスクで完了報告してClaudeに申告すること。

---

## プロジェクト構成
```
autoload/
  GameState.gd      # HP/SAN/階層/ラン状態
  CollectionData.gd # カード/装備/デッキ/ルーン
  AudioManager.gd   # BGM/SFX

scripts/            # ロジッククラス（Autoloadではない）
  cards.gd, combat.gd, equipment.gd, smith.gd
  enemies.gd, enemy_ai.gd, floors.gd, mulberry32.gd, profile.gd, runes.gd

scenes/             # 各画面
  hub/, combat/, main_menu/, rest/, reward/, event/, end/, shatter/

art/
  pixel/cards/    # .jpg
  pixel/packs/    # .png（PNGであることを確認済み）
  pixel/tickets/  # .png
  pixel/equipment/# .jpg
  pixel/enemies/  # .png
  pixel/ui/       # card_back.pngはフォールバック先
```
### USAGE REPORT
- agent: [Claude Code | Codex | Grok]
- task: （1行で何をしたか）
- status: [done | blocked | partial]
- files changed: （変更ファイルのパスのみ）
- quota remaining: [unknown | /usageの結果 | /statusの結果]
- next: （監督Claudeへの引き継ぎ1行）
```

残クォータは公式コマンドで取れた数値のみ記載。取れなければ `unknown`。

## クォータリセット情報
| エージェント | リセット時刻 | 確認方法 |
|---|---|---|
| Claude Code | 毎週土曜 20:00 JST | セッションで `/usage` |
| Codex | 2026/09/19 18:38 JST（次回以降は約1週間後） | セッションで `/status` |
| Grok Build | 毎日 17:15 北京時間（= 18:15 JST） | grok.com → Settings → Usage |

残量が少ないと感じたら、タスクを中断してClaudeに報告すること。
無理に続けてクォータを使い切るよりも、小さな単位で完了報告する方がよい。
