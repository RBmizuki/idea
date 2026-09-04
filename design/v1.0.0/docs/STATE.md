# STATE.md

## Current state

- Design package: **complete v1.0.0**
- Implementation: **not started**
- Sample run data: **included and schema-checked**
- Red Team review: **completed; material changes reflected**

## Completed

- [x] 依頼の目的、成功指標、制約、最大リスクを構造化
- [x] 重要仮定を明示
- [x] 3構成案を比較
- [x] モジュラーモノリス + DB workerを選定
- [x] VISION / PRD / ARCHITECTURE
- [x] AGENTS / PIPELINE / EVIDENCE / EVALUATION
- [x] DATA MODEL / API / UI
- [x] VALIDATION / SECURITY
- [x] 12週PLAN / BACKLOG / DECISIONS
- [x] 7視点Red Teamと修正
- [x] 20案を含む一貫したsample run
- [x] JSON Schemaと参考DDL
- [x] JSON/JSONL/YAML/Markdownの構文検査

## Not completed

- [ ] Next.js repository scaffold
- [ ] PostgreSQL migration適用
- [ ] Supabase Auth/RLS実装
- [ ] Worker実装
- [ ] LLM provider adapter実装
- [ ] Source parser実装
- [ ] UI実装
- [ ] Acceptance test自動化
- [ ] 実顧客への外部検証

## Next work

1. `MVP_PLAN.md` Week 1のrepository/DB skeletonを作る。
2. `db/core.sql`をmigration単位へ分割する。
3. `schemas/`を`packages/schemas`のZodへ変換する。
4. Brief→Worker→Artifactの最初の縦切りを作る。
5. sample runをfixtureとしてE2E testへ入れる。

## Blockers

- LLM provider/model/cost tableの最終選定。
- Hosting選定（Web/Workerを同一platformにするか分離するか）。
- Source fetchの利用規約/robots policyの運用責任者。
- 本番顧客データを扱う場合のDPA/セキュリティ要件。
- 実市場検証の対象業界と連絡先リストはHuman approvalが必要。

## Explicit unknowns

- 1Runあたりの実際のLLM費用。
- Source抽出失敗率。
- 日本語でのstructured output repair率。
- 一人運用時のEvidence review時間。
- 評価scoreと有料PoC率の相関。
- B2GとB2B2Gでの営業期間分布。

これらを実績なしに固定値として扱わない。
