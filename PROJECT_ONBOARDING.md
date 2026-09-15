# Abyss of R'lyeh — 新セッション引き継ぎプロンプト

このドキュメントを新しいチャット/エージェントセッションの冒頭に渡すこと。

---

## あなたの役割と環境

あなたは「Abyss of R'lyeh」というゲームの開発チームの一員です。
以下のツールが使えます：

- **bash tool**: リポジトリをcurlで取得し、実際のファイルを読んで作業できます
  （Web検索は不要。必要な情報は全てリポジトリ内にあります）

```bash
# リポジトリ取得の基本パターン
curl -sL "https://codeload.github.com/GiruStar-bot/cthulhu-spire-godot/tar.gz/refs/heads/main" \
  | tar xz -C /tmp/godot-project --strip-components=1

# 特定ファイルの直接取得
curl -sL "https://raw.githubusercontent.com/GiruStar-bot/cthulhu-spire-godot/main/AGENTS.md"

# ブランチの確認
curl -sL "https://codeload.github.com/GiruStar-bot/cthulhu-spire-godot/tar.gz/refs/heads/BRANCH_NAME" \
  | tar xz ...
```

---

## プロジェクト概要

| 項目 | 内容 |
|---|---|
| タイトル | Abyss of R'lyeh（深淵のルルイエ） |
| ジャンル | デッキビルドローグライク（Slay the Spire×クトゥルフ神話） |
| 目標 | Steam配信 |
| 原作 | React 19 + TypeScript（GiruStar-bot/cthulhu-spire） |
| 移植先 | Godot 4.7 + GDScript（GiruStar-bot/cthulhu-spire-godot） |

---

## リポジトリ構成

```
GiruStar-bot/cthulhu-spire-godot  ← 作業対象（Godot版）
GiruStar-bot/cthulhu-spire        ← 原作参照用（React版、変更しない）
```

---

## 現在の開発状況（2026年9月15日時点）

### 完了済みフェーズ

| フェーズ | 内容 | 状態 |
|---|---|---|
| A | 画面遷移の骨組み（Title/Hub/Combat/Rest/Reward/Event/End/Shatter） | ✅ |
| B | 戦闘ループ（カードプレイ・ダメージ計算・敵AI） | ✅ |
| C | カード全種・敵全種のデータ移植 | ✅ |
| D | デッキ管理（複数デッキ・フィルター・検索） | ✅ |
| E | 装備・ルーンシステム | ✅ |
| F | 村落・鍛冶屋（Rest画面） | ✅ |
| G | メタ進行（プロフィール永続化・グリモワール） | ✅ |
| H | 音響（BGM/SFX、AudioManager） | ✅ |

### 進行中・残タスク

| 項目 | 状態 |
|---|---|
| Hub画面のUI刷新（Godotネイティブデザインに再設計中） | 進行中 |
| 戦闘画面のドラッグ操作・UI没入感改善 | 進行中 |
| 戦闘画面の扇形手札レイアウト | 未着手 |
| タイトル画面のクレジット・フルスクリーン | 未着手 |
| 全体プレイテスト | 未着手 |
| Steam向け改善（Steamworks連携・コントローラー対応） | 未着手 |

---

## 開発体制

| エージェント | 役割 | リセット時刻 |
|---|---|---|
| Claude（このチャット） | 監督・設計・検証・タスク割り当て | 毎週土曜 20:00 JST |
| Claude Code | 構造・ロジック・マージ統合 | 毎週土曜 20:00 JST |
| Codex | ビジュアル・UI層 | 2026/09/19 18:38 JST |
| Grok Build | ゲームロジック重実装 | 毎日 18:15 JST |

---

## 作業開始前の必読ファイル

```bash
# 作業ルール（禁止パターン・チェックリスト等）
curl -sL "https://raw.githubusercontent.com/GiruStar-bot/cthulhu-spire-godot/main/AGENTS.md"
curl -sL "https://raw.githubusercontent.com/GiruStar-bot/cthulhu-spire-godot/main/GODOT_CODING_RULES.md"
```

---

## よく使うbash toolパターン

```bash
# 最新mainを取得して作業
curl -sL "https://codeload.github.com/GiruStar-bot/cthulhu-spire-godot/tar.gz/refs/heads/main" \
  | tar xz -C /tmp/proj --strip-components=1

# 特定ファイルの内容確認
cat /tmp/proj/scenes/combat/Combat.gd

# ノードパス整合性チェック
python3 -c "
import re
gd = open('/tmp/proj/scenes/hub/Hub.gd').read()
tscn = open('/tmp/proj/scenes/hub/Hub.tscn').read()
node_names = set(re.findall(r'\[node name=\"([^\"]+)\"', tscn))
paths = re.findall(r'\\\$([A-Za-z0-9_/]+)', gd)
missing = [p for p in paths if p.split('/')[-1] not in node_names]
print('Missing:', missing if missing else 'OK')
"

# ロジックファイルが変更されていないか確認
curl -sL "https://raw.githubusercontent.com/GiruStar-bot/cthulhu-spire-godot/main/scripts/combat.gd" \
  -o /tmp/main_combat.gd
diff /tmp/main_combat.gd /tmp/proj/scripts/combat.gd | wc -l
# → 0 なら無変更

# 原作React版の参照
curl -sL "https://raw.githubusercontent.com/GiruStar-bot/cthulhu-spire/main/src/components/game/CombatView.tsx"
```

---

## 完了報告フォーマット（必須）

```
### USAGE REPORT
- agent: [Claude Code | Codex | Grok]
- task: （1行）
- status: [done | blocked | partial]
- files changed: （パスのみ）
- quota remaining: [unknown | 数値]
- next: （Claudeへの引き継ぎ1行）
```
