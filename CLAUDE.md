@AGENTS.md
@GODOT_CODING_RULES.md

# Claude Code 専用追加指示

## 役割
- ロジック層（GameState.gd / CollectionData.gd / scripts/）の実装・修正
- 他エージェントのブランチをmainへマージする統合作業
- マージ時は必ずノードパス整合性チェックを実行してから push すること

## 完了後
- `/usage` を実行し、結果を USAGE REPORT の quota remaining に記入
- 残量が少ない（50%以下目安）場合は必ずClaudeに申告してから次タスクへ進む
