# Agent Working Agreements — Abyss of R'lyeh (Godot移植)

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

## 作業ルール

### 開始前に必ず行うこと
1. `GODOT_CODING_RULES.md` を読む
2. `git pull origin main` で最新化
3. 新しいブランチを切る（例: `codex/task-name`, `grok/task-name`）
4. 残クォータを確認して報告（後述）

### 実装中の禁止事項
- `autoload/GameState.gd` / `autoload/CollectionData.gd` / `scripts/`配下
  はビジュアル担当（Codex）は変更禁止。変更が必要な場合はClaudeに確認。
- 架空のGodot APIを使わない（GODOT_CODING_RULESを参照）
- `.tscn`のノード構造を変えたら、対応する`.gd`のパスも必ず同時に更新

### 完了時の必須チェック（push前）
```bash
godot --headless --quit 2>&1          # スクリプトエラー確認
python3 -c "
import re
gd = open('scenes/hub/Hub.gd').read()
tscn = open('scenes/hub/Hub.tscn').read()
node_names = set(re.findall(r'\[node name=\"([^\"]+)\"', tscn))
paths = re.findall(r'\\\$([A-Za-z0-9_/]+)', gd)
missing = [p for p in paths if p.split('/')[-1] not in node_names]
print('Missing:', missing if missing else 'OK')
"
```

### 完了報告フォーマット（必ず最後にこの形式で出力）

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
