# Abyss of R'lyeh Godot移植 — Claude Code引き継ぎ資料

このファイルはGodotプロジェクトのルートに配置し、Claude Code起動時に読み込ませることを想定している。

## 背景・方針

- 既存タイトル「Abyss of R'lyeh」（React 19 + Vite + Zustand + TypeScript製）を、Godot 4系（GDScript）で作り直すプロジェクト
- 目的：将来的なSteamリリース。Electronパックのリスク（バイナリサイズ・パフォーマンス・Steamworks統合の煩雑さ・コントローラー対応の弱さ）を避けるため、ゲームエンジンに移行する
- 進め方：**まずReact版の仕様を忠実に移植し、その後Godotエンジンならではの改善（Steamworks連携、シェーダー演出、Tween/AnimationPlayerによる演出強化等）を追加する**という2段階
- React版の詳細仕様は同梱の `PROJECT_HANDOFF_v2.md` を参照。特に「3. 厳守すべきルール・避けるべき実装・省略してはいけない手順」は移植時の必読事項

## 技術選定

- エンジン：Godot 4系最新安定版
- 言語：GDScript（イテレーション速度重視、TypeScript版からの移行しやすさより「色々試す」スタンスを優先）
- 開発者：宗一郎（Yamamoto Luca）が全設計判断を行い、コーディングはAIに一任する方針

## React版からの構造対応（移植の骨格）

React版の「2つの独立した永続化層」を、Godotでは以下のAutoload（Singleton）2本に対応させる：

| React版 | Godot版 | 役割 |
|---|---|---|
| `useCollectionStore`（localStorage） | `autoload/CollectionData.gd` | カード・ルーン・装備・デッキ（テンプレート方式の複数デッキ管理） |
| `game/store.ts` | `autoload/GameState.gd` | HP/SAN/現在階層/装着中装備スロット等、ラン中の状態 |

**この2つを混同して片方だけ更新すると同期が壊れる**（React版で実際に踏んだ地雷）。Godot移植でも明確に分離すること。

## 実際のフォルダ構成（フェーズAで確定）

```
res://
├── autoload/
│   ├── CollectionData.gd   # useCollectionStore.ts 相当
│   └── GameState.gd        # game/store.ts の GameStore + profile.ts の PlayerProfile 相当。
│                            # シーン遷移関数（begin/startRun/enterFloor/finishAdvance/
│                            # claimReward/resolveFlee/resolveEvent/leaveVillage/visitVillage/
│                            # resumeDescent/extractToHub/giveUp/acceptShatter等）もここに集約
├── scripts/
│   ├── mulberry32.gd       # rng.ts の mulberry32() 移植（class_name Mulberry32）
│   ├── floors.gd           # floors.ts の typeFor()/generateRunTable() 移植（class_name Floors）
│   ├── profile.gd          # profile.ts の純粋関数群＋セーブ/ロード移植（class_name Profile）。
│   │                        # GameState.gd の永続プロフィール系フィールドの計算式はここに一本化
│   ├── equipment.gd        # equipment.ts 全35種の装備定義＋ロール処理移植（class_name Equipment）
│   └── runes.gd            # runes.ts 全9種のルーン定義移植（class_name Runes）。
│                            # 引き継ぎ資料v2(3-4-8)は「現存6種」と書いてあるが実ソースは9種。
│                            # ドキュメントより実コードを正とし9種全て移植済み
├── scenes/
│   ├── main_menu/          # TitleScreen.tsx 相当
│   ├── hub/                # HubScreen.tsx 相当（単一画面、タブで descend/deck/equipment/
│   │                       #   sell/shop/packs を切替。floor>0でも同じ画面＝中継点）
│   ├── combat/             # CombatView.tsx 相当
│   ├── reward/             # RewardView.tsx 相当
│   ├── event/              # EventView.tsx 相当
│   ├── rest/                # RestView.tsx 相当（村ハブ→酒場/鍛冶屋のサブ状態）
│   └── end/                # EndView.tsx（victory/defeat共有）+ ShatterView.tsx 相当
├── resources/          # Resourceベースのデータ定義クラス（card_def.gd, equipment_def.gd, rune_def.gd, enemy_def.gd）※フェーズB以降
└── data/               # 上記クラスから生成した.tresファイル置き場 ※フェーズB以降
```

`src/game/types.ts`のScene型のうち `"prologue"` / `"map"` / `"prepare"` / `"between"` は
`GameApp.tsx`のswitch文には存在するが、実際にはどの遷移関数からもセットされない到達不能
パス（デッドコード）と確認済みのため、本移植では再現していない。

## 現在着手中のフェーズ

**フェーズA：画面遷移の骨組み**（「箱を先に作ってから中身を詰める」というReact版の設計哲学を踏襲）

実ソース（`GameApp.tsx`のシーン切替 + `store.ts`の`enterFloor`/`finishAdvance`等の遷移関数）
を読み、以下の状態遷移を実際のロジックの形のまま（値はダミー）再現した：

```
title → hub（begin）
hub（floor<=0, 探索開始タブ=PrepareView相当） --start_run--> combat/rest/event（enterFloorの分岐）
hub（floor>0, 探索開始タブ=CheckpointPanel相当） --resume_descent--> 次の階層へ
hub（floor>0） --extract_to_hub--> hub（floor=0にリセット）
combat --勝利--> reward --claim_reward--> finishAdvance分岐（10層毎ボス撃破ならhubへ自動帰還/最終層ならvictory/それ以外は次の階層）
combat --敗北--> defeat（正気0ならshatter）
event --選択--> finishAdvance分岐へ合流
rest（村ハブ） --酒場/鍛冶屋--> サブ状態（プレースホルダー） --次の層へ--> finishAdvance系ではなくenterFloor直接
defeat --giveUp--> hub
victory --give_up（実ソースはボタン表記「タイトルへ戻る」で実際はhubへ戻る食い違いがあったが、
         本移植では表記を「帰還」に修正済み）--> hub
shatter --accept_shatter--> title
```

各シーンの中身は最小限（背景色・ラベル・遷移ボタンのみ）。目的は以下3点：
1. Autoload 2本（`GameState.gd`, `CollectionData.gd`）の器を作る
2. `get_tree().change_scene_to_file()` による実際のシーン遷移ロジックを全部配線する
3. `GameState`に最低限のダミー値（現在階層・HP/SAN等）を持たせ、画面間で値が引き継がれることを確認する

これが動いたら、次はB（戦闘ループの最小実装：カード1枚をプレイしてダメージが飛ぶ）に進む想定。

## 体制（複数エージェント並行作業）

以降、3エージェントが別ブランチで並行して作業する：

- **Grok**: `cards.ts`/`combat.ts`相当（カードデータ・戦闘ロジック）の移植
- **Codex**: ビジュアル/UI層の実装
- **Claude（このエージェント）**: `equipment.ts`/`runes.ts`/`profile.ts`のGDScript移植、
  `GameState.gd`/`CollectionData.gd`のデータ構造整合性の維持、他ブランチとのマージ調整

**実装済み（Claude担当分）**:
- `scripts/profile.gd` / `scripts/equipment.gd`（装備35種）/ `scripts/runes.gd`（ルーン9種）
- `autoload/GameState.gd`の永続プロフィール系フィールドは`Profile`の関数に委譲（二重管理を排除）
- プロフィールのセーブ/ロード（`user://cthulhu_spire_profile_v1.json`）を実装。`begin()`/`extract_to_hub()`/
  `give_up()`/`lose_combat()`（`markDefeat()`相当）/`accept_shatter()`等、実ソースで`persist(profile)`が
  呼ばれる箇所に対応する`_persist_profile()`呼び出しを配線済み
- 正気0での「全ロスト」判定に`hasFullSet(equipped, "fanatic")`ガードが実ソースにあるのに
  フェーズA初期実装で漏れていたのを発見し、`lose_combat()`に追加（データ整合性チェックで発見した実バグ修正）

**他ブランチをマージする際の注意**: `git fetch`で最新化してから作業すること。`GameState.gd`/
`CollectionData.gd`のフィールドを他エージェントが拡張する可能性があるため、コンフリクト解消時は
両者のフィールド定義を洗い出し、永続化データ（`Profile.empty_profile()`/`_persist_profile()`/
`_load_profile()`）が新フィールドを見落としていないか必ず確認する。

## 移植時に踏みやすい地雷（React版で実際に発生したもの。GDScript版でも要注意）

- 永続化データに新フィールドを足す時は必ずデフォルト値を用意する（`Dictionary.get(key, default)`等）。旧セーブとの互換性が壊れる
- 型・データ構造を変更した際は、それを使う全関数のシグネチャを洗い出して更新する
- 1回だけ計算する値（例：戦闘開始時に確定する装備ステータス）とリアルタイムに変わる値を混同しない
- 同じガード条件が複数箇所に分散している可能性がある（例：正気0の「全ロスト」トリガー）。1箇所直して満足せず、全呼び出し箇所を洗い出す
- カード枠線の色分け（攻撃=赤/防御=青/効果=紫）、戦闘ログの色分け、「戻る」ボタンは画面右下、といった確立済みUI/UXルールも踏襲する

## 重要：実装内容の参照元について

**このファイルはあくまで方針・構造のガイドラインであり、実装の正解ではない。** カードの数値、戦闘計算式、状態異常の細かい挙動、UIコンポーネントの構造など、実際のロジックは全て以下の手順でReact版の実ソースコードから読み取り、それをGDScriptに翻訳する形で移植すること。このmdの文章だけを元に「それらしく」再実装しない。

### 実ソースコードの取得手順

1. Godotプロジェクトのルート直下に `reference/` フォルダを作り、そこにReact版リポジトリを取得する：
   ```bash
   cd reference
   curl -sL -o repo.tar.gz "https://codeload.github.com/GiruStar-bot/cthulhu-spire/tar.gz/refs/heads/main"
   tar xzf repo.tar.gz
   ```
   （または `git clone https://github.com/GiruStar-bot/cthulhu-spire.git` でも可）
2. `reference/` はGodotプロジェクト自体のGit管理には含めない（`.gitignore`に追加）。あくまで移植時の参照専用
3. 移植作業時は、対象システムに対応する実ファイル（例：`src/game/store.ts`, `src/collection/`, カード・装備・敵の定義ファイル群, 戦闘ロジック本体）を実際に読み、そこにある型定義・数値・条件分岐をGDScriptの`Resource`/`Autoload`/関数として翻訳する
4. 数値（カードのコスト・ダメージ量、装備のtier別ボーナス確率など）は実ファイルから正確に転記する。憶測や「それらしい値」で埋めない

## 参考

- 既存リポジトリ（React版）: https://github.com/GiruStar-bot/cthulhu-spire
  - 内容確認が必要な場合: `curl -sL -o repo.tar.gz "https://codeload.github.com/GiruStar-bot/cthulhu-spire/tar.gz/refs/heads/main"`
