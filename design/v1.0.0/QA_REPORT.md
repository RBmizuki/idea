# QA_REPORT.md

検証日: 2026-09-04  
対象: Demand Foundry design-v1.0.0

## 自動検証結果

- 必須設計文書16件: PASS
- 必須sample run artifact: PASS
- JSON / JSONL parse: PASS
- YAML parse: PASS
- Idea Card 20件: PASS
- 全Ideaの主要schema field: PASS
- Hard Gate 20件: PASS
- PASS / HOLD / FAILの分岐fixture: PASS
- 30日以内のValidation Plan 3件: PASS
- Success / Hold / Kill条件: PASS
- Rubric weight合計100: PASS
- `idea-card.schema.json`適合: 20/20
- `evidence-item.schema.json`適合: 10/10
- `validation-plan.schema.json`適合: 3/3
- Package / run SHA-256 manifest: PASS

## 手動構造レビュー

- 3アーキテクチャ案の比較と採用理由: 確認済み
- Stage 0〜13の通過・失格・再実行条件: 確認済み
- Generator / Verifier / Evaluator / Red Team分離: 確認済み
- Human Approval対象: 確認済み
- UIの目的・表示・操作・状態・error・empty・権限: 確認済み
- 7視点Red Teamと反映内容: 確認済み
- 最終10問への明示回答: 確認済み

## 未実施の検証

- `db/core.sql`を実際のSupabase/PostgreSQLへ適用するmigration test
- Next.js / Worker実装のtypecheck・unit・integration・E2E
- 実LLMのstructured-output成功率と費用測定
- 実顧客への市場検証
- 法務・セキュリティの専門家による正式審査

したがって、本パッケージは**設計・fixtureとして検証済み**であり、実装済み製品または市場検証済み事業ではない。
