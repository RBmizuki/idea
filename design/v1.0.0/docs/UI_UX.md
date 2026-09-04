# UI_UX.md

## 1. UX原則

- 華美さより、証拠・仮定・失格理由・次の行動を優先する。
- 色だけで状態を表さず、文字ラベルとiconを併用する。
- `FACT / ESTIMATE / ASSUMPTION / HYPOTHESIS / UNKNOWN`を常時表示する。
- scoreは根拠を折り畳まず、クリック1回でEvidenceへ遡れる。
- AIが自動確定したように見せず、generated / verified / human-approvedを分ける。
- 破壊的操作と外部行為は二段階承認。

## 2. ロール

| Role | 読取 | Run操作 | Evidence review | Decision | Approval | Config |
|---|---:|---:|---:|---:|---:|---:|
| owner | all | yes | yes | yes | yes | yes |
| operator | workspace | yes | yes | draft | request | no activate |
| reviewer | assigned | no | yes | comment | no | no |
| approver | workspace | no | read | finalize | yes | activate |
| viewer | workspace | no | no | no | no | no |

MVPはowner/operator/viewerを優先し、残りは簡易実装。

## 3. Global navigation

```text
Dashboard
Runs
Evidence Library
Signals
Problems
Opportunities
Ideas
Evaluations
Red Team
Validation Experiments
MVP Projects
Portfolio
Learning
Prompt / Rubric Versions
Cost Dashboard
Audit Log
```

## 4. Dashboard

**目的**: 現在のRun、詰まり、予算、次のHuman actionを一画面で把握。  
**主利用者**: owner/operator。  
**表示**:

- active runs
- stage funnel counts
- approvals waiting
- budget spent/committed/remaining
- evidence coverage
- hard gate pass/hold/fail
- validation events last 30 days
- top blockers

**操作**: New Run、Resume、Review Evidence、Approve/Rejectへ移動。  
**状態遷移**: 画面自体なし。Run状態を操作。  
**エラー**: metrics一部失敗はカード単位で表示し、全画面を落とさない。  
**空状態**: 「最初の探索Briefを作成」。  
**権限**: viewerは操作button非表示。

Wireframe:

```text
+ Demand Foundry -------------------------------- [New Run]
| ACTION REQUIRED: 12 evidence reviews / 1 approval
+ Active Run: run-... -------------------------------+
| [Evidence 72%] [Ideas 20] [Gate 6/8/6] [$34/$60] |
| Brief -> Sources -> Evidence -> Ideas -> Evaluate |
|                         ^ blocked: 3 claims       |
+---------------------------------------------------+
| Top validation candidates | Budget | Recent outcomes |
+---------------------------------------------------+
```

## 5. Runs

**目的**: Run一覧と再現・fork・resume。  
**表示**: run key、brief summary、status、current stage、counts、cost、created/updated、parent。  
**操作**: create/start/pause/resume/fork/cancel/export。  
**状態遷移**: draft→queued→running→paused/completed/failed。  
**エラー**: Resume不可理由、snapshot mismatch、budget block。  
**空**: template選択。  
**権限**: operator以上がwrite。

### Run Detail

Tabs: Overview / Stage Jobs / Sources / Outputs / Costs / Audit / Export。

```text
Run run-2026-09-04-01 [running] [Pause]
Brief v1 | Rubric v1 | Prompt set v3 | Seed 41322
Stages
[x] Brief  [x] Signals  [!] Evidence Review  [ ] Problems ...
Blocking items
- E-019 source locator missing   [Review]
- Budget 82% used                [Open costs]
```

## 6. Evidence Library

**目的**: Source、Evidence、Claimの支持関係を確認。  
**利用者**: operator/reviewer/auditor。  
**表示**:

- source class/publisher/date/freshness
- claim classification/status
- locator preview
- support/refute links
- numeric metadata
- prompt injection/quarantine flag

**操作**: approve/downgrade/reject/split/conflict/re-fetch。  
**遷移**: proposed→verified/contested/rejected/stale。  
**エラー**: source unavailable、extraction low quality、locator drift。  
**空**: URL/PDF追加guide。  
**権限**: reviewer以上。

Wireframe:

```text
Claim: "..." [FACT candidate] [Medium confidence]
Source: Ministry ... [A1] Published ... Retrieved ...
+---------------- Source page ----------------------+
| highlighted excerpt                              |
+--------------------------------------------------+
Numeric context: unit / date / geography / denominator
[Approve FACT] [Downgrade] [Split] [Reject] [Conflict]
Supports: ...   Refutes: ...
```

## 7. Signals

**目的**: サービス案になる前の変化をレビュー。  
**表示**: change type、from/to、effective date、affected actor、Evidence count、confidence。  
**操作**: merge duplicates、approve、reject、send to research。  
**状態**: candidate→verified→used/retired。  
**エラー**: source stale、change date conflict。  
**空**: query生成またはsource追加。  
**権限**: operator/reviewer。

## 8. Problems

**目的**: 抽象的Signalを具体的業務問題へ落とす。  
**表示**: actor/trigger/task/failure/frequency/current workflow/cost/root cause/evidence coverage。  
**操作**: revise、merge、mark unknown、create research task、promote to Opportunity。  
**状態**: draft→evidence_pending→verified→mapped/rejected。  
**エラー**: actor不明、current workflow欠落。  
**空**: Signal選択prompt。  
**権限**: operator。

## 9. Opportunities

**目的**: 支払可能な構造か確認。  
**表示**:

- user/payer/decision maker/champion/blocker/data owner/beneficiary
- budget source
- current alternative/current cost
- why now/purchase trigger
- initial wedge/expansion
- Evidence Coverage by field

**操作**: revise、research task、generate ideas。  
**状態**: draft→payer_pending→ready→generated/rejected。  
**エラー**: payer=user混同、budget空、data owner空。  
**空**: Problemから作成。  
**権限**: operator。

## 10. Ideas

**目的**: Idea Card、類似、Gate、次行動を比較。  
**表示**: one-liner、wedge、payer、alternative、classification badges、cluster、gate、score、largest unknown。  
**操作**: open/revise/cluster review/run gate/select for evaluation。  
**状態**: generated→research_pending/rejected/evaluating/...。  
**エラー**: schema invalid、missing evidence、duplicate unresolved。  
**空**: Opportunity生成を促す。  
**権限**: operator write、viewer read。

### Idea Detail

Headerにscoreより先に表示:

```text
Gate: HOLD — budget source is unverified
Largest unknown: will survey contractors pay from project delivery budget?
Next action: 5 qualified calls + one price ask by 2026-09-30
```

Tabs: Evidence / Customer & Workflow / Business Model / Technology / Competition / Risk / Validation / History。

## 11. Evaluations

**目的**: 独立評価と disagreementを可視化。  
**表示**: criterion matrix、median、MAD、confidence、reason/evidence。  
**操作**: view blind packet、flag invalid、request re-evaluation。  
**状態**: queued→partial→complete→disputed/final。  
**エラー**: evaluator leakage、packet mismatch、missing score。  
**空**: PASS案なし。  
**権限**: operator/approver。

```text
Criterion             Evidence  Commercial Technical Effective
Demand evidence          6          5          -        5.3
Payer & budget            5          6          -        5.1
Feasibility               -          -          8        7.6
Disagreement: Economic value (range 3-7) [Inspect]
```

## 12. Red Team

**目的**: 上位案の致命傷と修正可否を管理。  
**表示**: finding、severity、attacked assumption、evidence、falsification test、resolution。  
**操作**: accept/dispute/resolve/create revision/re-Gate。  
**状態**: open→accepted/disputed→resolved/unresolved/fatal。  
**エラー**: S3/S4解決後のre-Gate未実施。  
**空**: 上位案選定待ち。  
**権限**: operator/approver。

## 13. Validation Experiments

**目的**: 30日実験と行動証拠を実行・記録。  
**表示**: biggest uncertainty、target、day、cost、success/hold/kill、approval、event timeline。  
**操作**: edit script、request approval、start、record event、complete。  
**状態**: draft→approval_required→approved→running→success/hold/kill/inconclusive。  
**エラー**: approval expired、PII flag、metric未設定。  
**空**: selected ideaなし。  
**権限**: operator実行、approver承認。

Kanban:

```text
DRAFT | APPROVAL | RUNNING | SUCCESS | HOLD | KILLED
```

Event buttonは「面白い」より強い順に並べず、事実通り選択させる。証拠添付とverified flagを表示。

## 14. MVP Projects

**目的**: Validation通過案の最小実装を管理。  
**表示**: value moment、payment moment、scope、manual ops、excluded、acceptance criteria、customer commitment。  
**操作**: create only after gate、update milestone、kill/pause。  
**状態**: proposed→approved→building→pilot→converted/paused/killed。  
**エラー**: validation threshold未達、data approvalなし。  
**空**: 「まだ作らない」が正常状態である説明。  
**権限**: owner/operator。

## 15. Portfolio

**目的**: 限られた検証予算の配分。  
**表示**: final score、cluster、largest uncertainty、validation cost/time、upside、selected/hold/reject。  
**操作**: adjust budget、compute、manual override with reason、finalize。  
**状態**: draft→computed→reviewed→finalized。  
**エラー**: fatal案選択、cluster重複、budget超過。  
**空**: evaluation未完了。  
**権限**: owner/approver finalize。

## 16. Learning

**目的**: 予測と実績の差を見る。  
**表示**:

- score decile vs reply/referral/data/paid/retention
- predicted vs actual development duration
- cohort/sample size
- calibration error
- rule change proposals

**操作**: cohort filter、snapshot作成、proposal review。  
**状態**: insufficient_data→descriptive→calibration_candidate→approved_change。  
**エラー**: sample leakage、n不足、outcome未検証。  
**空**: 「まず結果を登録」。  
**権限**: operator read/propose、approver change。

## 17. Prompt / Rubric Versions

**目的**: 変更と再現性。  
**表示**: version、diff、active、used runs、backtest。  
**操作**: clone/edit/test/request activate/retire。  
**状態**: draft→tested→approved→active→retired。  
**エラー**: weights!=100、schema incompatible、backtestなし。  
**空**: default config。  
**権限**: owner/approver activate。

## 18. Cost Dashboard

**目的**: run/stage/agent/model/ideaの支出と停止。  
**表示**: spent/committed/remaining、cost per accepted item、retry waste、forecast。  
**操作**: pause run、lower limits、inspect calls。  
**状態**: normal→warning→restricted→budget_paused。  
**エラー**: provider cost unknown、ledger mismatch。  
**空**: no calls。  
**権限**: operator/owner。

## 19. Audit Log

**目的**: 誰が何をなぜ変えたか。  
**表示**: timestamp、actor、resource、action、before/after hash、reason、approval。  
**操作**: filter/export。変更・削除不可。  
**エラー**: projection lag警告。  
**空**: あり得ない。Run作成eventから開始。  
**権限**: owner/viewer（機微payloadはownerのみ）。

## 20. 状態表示の標準

- `VERIFIED FACT`: 緑 + check + text
- `ESTIMATE`: 青 + calculator
- `ASSUMPTION`: 黄 + triangle
- `HYPOTHESIS`: 紫 + flask
- `UNKNOWN`: 灰 + question
- `REFUTED/CONFLICT`: 赤 + conflict

色は補助。badge textを必須とする。

## 21. エラー文の標準

悪い例: `処理に失敗しました`。  
良い例:

```text
Evidence Verifierを完了できませんでした。
原因: PDFの該当ページから文字を抽出できません。
影響: E-019はFACTとして利用されず、3案がHard Gate HOLDです。
次の操作: ページ画像を確認してlocatorを手動登録するか、Sourceを差し替えてください。
```
