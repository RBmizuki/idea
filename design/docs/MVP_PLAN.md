# MVP_PLAN.md

## 1. 実装戦略

12週間を「横断基盤を全部作ってから機能を載せる」形にせず、毎週End-to-Endの縦切りを増やす。

```text
Run作成 -> Job実行 -> Artifact保存 -> UI確認 -> Audit/Cost
```

この一本をWeek 2で通し、その後Source/Evidence、Idea/Gate、Validation/Learningを順に足す。

## 2. Team想定

### 1人

- Full-stack/architecture/operatorを兼務。
- UIはtable/detail中心。
- Pairwiseや高度なgraph表示はWeek 9以降。

### 2〜3人

- A: domain/backend/worker
- B: web/UI/UX
- C: evidence/LLM/evaluation/test（兼務可）

## 3. 12週間計画

### Week 1 — Skeleton / decisions

**到達点**

- Monorepo、CI、環境、DB migration。
- Auth、workspace、RLS skeleton。
- Zod/JSON Schema registry。
- Run/Stage/Job/Artifact/Cost/Auditのschema。
- Prompt/Rubric version model。

**受け入れ**

- User AがUser B workspaceを読めない。
- Run draftを作成しDBへ保存。
- weights合計不正をreject。

### Week 2 — 最初の縦切り: Brief -> Worker -> Artifact

**到達点**

- Brief Compiler。
- DB lease式worker。
- Idempotency、retry、pause/resume。
- LLM Gatewayの1 provider adapter。
- Cost preflight。

**Demo**

Brief入力→job→構造化YAML/JSON artifact→UI表示。

**受け入れ**

- Worker kill後、lease失効で再開。
- 同一idempotency keyで重複なし。
- budget不足でcall前停止。

### Week 3 — Source Snapshot

**到達点**

- URL/PDF/upload Source登録。
- Object Storage。
- Metadata、hash、extract status。
- Safe viewer、quarantine flag。

**受け入れ**

- 同URL同hashは重複snapshotなし。
- content変更は新snapshot。
- 禁止mimeをreject。

### Week 4 — Evidence / Claim

**到達点**

- Claim extraction、locator、support/refute。
- FACT/ESTIMATE/ASSUMPTION/HYPOTHESIS/UNKNOWN。
- Numeric validator。
- Evidence Review UI。

**受け入れ**

- FACT without evidenceは保存不可。
- PDF page/line locatorを表示。
- 数値のunit/date/region欠落をflag。

### Week 5 — Signal -> Problem -> Opportunity

**到達点**

- Stage 1〜4 handlers。
- Problem concrete fields。
- Customer role separation。
- Research task / evidence gap。

**受け入れ**

- payer/decision maker/alternative欠落をUIで明示。
- SignalからEvidenceへ遡れる。
- Opportunity statementをschemaで検証。

### Week 6 — 20 Ideas / Novelty

**到達点**

- Generation method matrix。
- Required Idea Card schema。
- Business Model Engineer。
- pgvector + lexical + field overlap。
- 20 ideas/run。

**受け入れ**

- 20件以上生成。
- 各Ideaにorigin refs。
- 類似clusterと差分軸を表示。
- 価格/市場数字はtype分離。

### Week 7 — Hard Gate

**到達点**

- 15 gate rules。
- pass/hold/fail、reason code、evidence required。
- Deterministic precheck + explanation。
- Gate UI。

**受け入れ**

- payer不明がpassしない。
- data access不能がfail。
- 30日検証不能がhold/fail。
- Human overrideにreason/expiry。

### Week 8 — Independent Evaluation

**到達点**

- Blinded packet。
- Evidence/Commercial/Technical referees。
- median/MAD/uncertainty aggregation。
- disagreement UI。

**受け入れ**

- packetにtitle/origin/rankなし。
- Generator agent IDとEvaluator agent IDが異なる。
- 個別score、理由、confidenceを比較可能。

### Week 9 — Pairwise / Red Team / Portfolio

**到達点**

- Pairwise randomized A/B。
- Killer/Improver分離。
- S4 fatal flow。
- Portfolio cost/diversity constraint。

**受け入れ**

- A/B順反転。
- S4 unresolved案を選択不可。
- 同cluster代表を原則1案。
- 上位3案の理由をexport可能。

### Week 10 — Validation / Human Approval

**到達点**

- Validation Plan generator。
- success/hold/kill schema。
- Approval objects。
- Behavior event timeline。

**受け入れ**

- 30日超planをrejectまたはflag。
- 好意だけのsuccessをreject。
- Approvalなし外部action requestが409。
- data_shared/LOI/paid等を登録可能。

### Week 11 — Learning / Export / Sample Run

**到達点**

- Prediction snapshots。
- Score vs actual event comparison。
- n<30 guard。
- JSON/JSONL/Markdown exporter。
- 公式Sourceを使うsample run。

**受け入れ**

- 過去scoreを上書きしない。
- n<30でauto rule update不可。
- required run directoryが生成。
- counts/hash一致。

### Week 12 — Hardening / Pilot-ready

**到達点**

- Security tests、load/chaos/resume tests。
- Audit hash chain。
- UX polish、empty/error state。
- Backup restore rehearsal。
- Runbook、release checklist。

**受け入れ**

- 全MVP AC通過。
- Worker途中停止→resume E2E。
- prompt injection canary通過。
- budget cap E2E。
- sample runを新環境で再現。

## 4. Milestones

| Milestone | Week | Definition |
|---|---:|---|
| M1 Execution spine | 2 | Run/Job/Artifact/Cost/Resumeが通る |
| M2 Evidence spine | 4 | Source→Claim→Reviewが通る |
| M3 Venture funnel | 7 | Opportunity→20 Ideas→Hard Gate |
| M4 Independent selection | 9 | Blind eval→Red Team→Portfolio |
| M5 Closed learning loop | 11 | Validation event→prediction comparison |
| M6 MVP release | 12 | AC/security/restore/sample run通過 |

## 5. 縦切り実装順

1. 一つのBrief artifactを作る。
2. 一つのSourceから一つのFACTをverifyする。
3. 一つのProblem/Opportunity/Ideaを生成する。
4. そのIdeaをpayer欠落で落とす。
5. payerありIdeaを3評価者で比較する。
6. 一つのValidation Eventを登録してscoreとの比較を出す。
7. 20案・Novelty・Portfolioへスケールする。

## 6. テスト戦略

### Unit

- state transition
- gate rule
- cost arithmetic
- numeric claim validation
- similarity component
- final score formula
- approval payload hash

### Contract

- Zod <-> JSON Schema compatibility
- LLM structured output fixtures
- provider cost normalization
- API error schema

### Integration

- DB transaction + artifact write
- worker lease/reaper
- RLS
- signed URL
- source snapshot hash

### E2E

- Brief→Export
- pause/resume
- budget paused
- evidence review→Gate
- S4 fatal→not selected
- Validation event→Learning

### Adversarial

- prompt injection source
- fake citation URL
- stale/superseded source
- numeric unit mismatch
- duplicated idea rename
- evaluator packet leakage
- approval replay

## 7. Acceptance test matrix

| Test ID | Requirement | Expected |
|---|---|---|
| AT-01 | 20 ideas | count>=20 and schema valid>=95% |
| AT-02 | Evidence link | FACT missing evidence rejected |
| AT-03 | Classification | all claims typed |
| AT-04 | Payer gate | blank payer never PASS |
| AT-05 | Alternative | blank current alternative never PASS |
| AT-06 | 30-day plan | each top3 duration<=30 |
| AT-07 | Kill metric | each plan has measurable kill |
| AT-08 | Multi evaluator | >=3 independent evaluator runs |
| AT-09 | Similarity | renamed duplicate clustered |
| AT-10 | Explain selection | reason + evidence + risks + next action |
| AT-11 | Resume | completed job count unchanged after resume |
| AT-12 | Trace model | every LLM artifact has model call |
| AT-13 | Outcome entry | behavior event accepted and audited |
| AT-14 | Prediction actual | learning view joins snapshot/event |
| AT-15 | Export | JSON + JSONL + MD + manifest |

## 8. リスクと対応

| Risk | Early signal | Response |
|---|---|---|
| Structured output不安定 | schema repair>10% | prompt簡素化、分割、manual review |
| Source parser沼 | PDF抽出失敗>20% | manual locator、対象mime制限 |
| UI範囲過大 | Week 4でEvidence未完成 | graph/analyticsを削りtable/detailへ |
| Evaluation cost高 | run budgetの50%超 | Gateで候補を5〜8へ絞る、cached packet |
| B2G sample検証が遅い | 10日で面談0 | 受託会社/業界専門家wedgeへ切替 |
| Self-learning要求膨張 | rule engine未完成 | n guardとmanual proposalに限定 |
| RLS複雑化 | 権限bug | MVP role削減、policy test増加 |

## 9. 何を削るか

一人開発で遅れた場合、順に削る。

1. Fancy dashboard chart
2. Pairwise full round-robin（top4のみ）
3. Multiple embeddings（full concept一つ）
4. Reviewer assignment workflow（owner review）
5. Real-time updates（polling）
6. Python service
7. Multi-provider LLM
8. Automated web discovery（manual URL importを維持）

削ってはいけないもの:

- Evidence/Claim型
- payer Hard Gate
- generator/evaluator分離
- validation success/kill
- Job idempotency/Resume
- Cost/Audit
- Human approval

## 10. Release criteria

- P0 backlog完了。
- 15 acceptance testsすべてpass。
- critical/high security issue 0。
- sample runがclean DBから完了。
- export hash一致。
- operator runbookで別人が1回運用可能。
- 本番Source/顧客データを使う前にprivacy/legal checklist完了。
