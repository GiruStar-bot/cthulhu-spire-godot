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

## 現在の開発状況（2026年9月27日時点。以下は実リポジトリの状態を確認した上での最新化）

### 完了済みフェーズ

| フェーズ | 内容 | 状態 |
|---|---|---|
| A | 画面遷移の骨組み（Title/Hub/Combat/Rest/Reward/Event/End/Shatter） | ✅ |
| B | 戦闘ループ（カードプレイ・ダメージ計算・敵AI） | ✅ |
| C | カード全種・敵全種のデータ移植 | ✅ |
| D | デッキ管理（複数デッキ・フィルター・検索） | ✅ |
| E | 装備・ルーンシステム（※装備・ルーンは後日プレイヤー機能から廃止済み。ロジック自体は`scripts/equipment.gd`/`scripts/runes.gd`に残存） | ✅ |
| F | 村落・鍛冶屋（Rest画面） | ✅ |
| G | メタ進行（プロフィール永続化・グリモワール） | ✅ |
| H | 音響（BGM/SFX、AudioManager） | ✅ |
| I | ステ振りの刷新（4元素羅針盤＋超越羅針盤、`scripts/compass.gd`／`scenes/hub/CompassPanel.gd`） | ✅ |

### 進行中・残タスク（2026年9月27日、リポジトリのコミット履歴・現行コードを直接確認した内容）

| 項目 | 状態 |
|---|---|
| 敵ピクセル立ち絵のリグ化（`scripts/enemies.gd`の`"px"`定義） | **進行中**：全24体中3体（侍祭 acolyte・狂信者 fanatic・尖塔の大司祭 priest）が完了。残り21体は未着手（`"px"`キーなし＝既定の128×224/8コマにフォールバック） |
| 戦闘の手札カードサイズ縮小 | ✅ 完了（`CARD_SIZE`を128×192→112×168に変更、PR #103として2026-09-26にmainへマージ済み） |
| Hub画面のUI刷新 | 大部分完了。羅針盤・超越羅針盤タブを含め主要タブは実装済み。細部の調整（配置・演出）は継続的に発生し得る |
| 戦闘画面のドラッグ操作・扇形手札レイアウト | ✅ 実装済み（`Combat.gd`の`_layout_fan`／ドラッグ&ドロップ） |
| タイトル画面のクレジット・フルスクリーン | ✅ 実装済み（`MainMenu.gd`のクレジットパネル・フルスクリーン切替） |
| バフイベント・会話イベント・贈り物モーダルの吹き出し統一 | ✅ 完了（`scenes/ui/SpeechBubble.gd`に一本化、PR #74で2026-09-25にマージ済み） |
| 全体プレイテスト | 未着手 |
| Steam向け改善（Steamworks連携・コントローラー対応） | 未着手（リポジトリ内にSteamworks/ゲームパッド関連の実装は見当たらない） |

新しいセッションで作業を始める際は、上記の「進行中」項目（特に敵ピクセル立ち絵の残り21体）を鵜呑みにせず、この表自体が更新から時間が経っている可能性を踏まえて `git log --oneline -20 origin/main` や該当ファイルを直接確認すること。

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
