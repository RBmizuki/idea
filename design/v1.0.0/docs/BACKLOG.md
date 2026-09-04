# BACKLOG.md

Priority: P0=MVP必須、P1=12週内できれば、P2=後続。  
DoD共通: test、audit、error/empty state、schema docs、migrationが揃う。

## Epic E1 — Foundation / Access

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E1-01 | MonorepoとCIを構築 | P0 | - | lint/typecheck/test/migration CI |
| E1-02 | Workspace/Profile/Membership | P0 | E1-01 | RLS testでcross-workspace拒否 |
| E1-03 | Simple owner/operator/viewer roles | P0 | E1-02 | route/UI両方で権限反映 |
| E1-04 | MFA policy and session timeout | P1 | E1-02 | owner向け設定と監査 |
| E1-05 | Secret management/runbook | P0 | E1-01 | client bundleにsecretなし |

## Epic E2 — Run / Config / Execution

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E2-01 | Run CRUD/status transition | P0 | E1 | invalid transition test |
| E2-02 | Brief Compiler schema/UI | P0 | E2-01 | YAML/JSON snapshot生成 |
| E2-03 | Prompt/Rubric version tables | P0 | E2-01 | immutable active version |
| E2-04 | Pipeline job table and lease worker | P0 | E2-01 | SKIP LOCKED concurrency test |
| E2-05 | Idempotency key and artifact hash | P0 | E2-04 | duplicate executionなし |
| E2-06 | Pause/Resume/Reaper | P0 | E2-04 | worker kill E2E pass |
| E2-07 | Fork Run on snapshot change | P0 | E2-03 | parent link and separate hash |
| E2-08 | Stage DAG/dependency resolver | P0 | E2-04 | ready state deterministic |
| E2-09 | Live progress polling | P1 | E2-04 | 5s polling and stale state |

## Epic E3 — LLM / Cost

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E3-01 | LLMProvider interface | P0 | E2 | provider fixture tests |
| E3-02 | One provider adapter | P0 | E3-01 | structured output works |
| E3-03 | Model call logging | P0 | E3-02 | tokens/cost/hash/latency |
| E3-04 | Schema repair loop max2 | P0 | E3-02 | invalid→repair→review |
| E3-05 | Cost ledger/preflight | P0 | E3-03 | cap before call |
| E3-06 | Stage/agent/model caps | P0 | E3-05 | each cap tested |
| E3-07 | Cost dashboard | P1 | E3-05 | spent/committed/retry waste |
| E3-08 | Response cache by request hash | P1 | E3-03 | deterministic requests reused |

## Epic E4 — Source / Evidence

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E4-01 | URL Source registration | P0 | E2 | canonical metadata saved |
| E4-02 | PDF/file upload | P0 | E4-01 | mime/size/scan validation |
| E4-03 | Snapshot hash/object storage | P0 | E4-01 | immutable snapshots |
| E4-04 | Text extraction and quality status | P0 | E4-03 | failure goes review |
| E4-05 | Claim/Evidence tables | P0 | E4-03 | support/refute links |
| E4-06 | Evidence Verifier handler | P0 | E3,E4-05 | locator and classification |
| E4-07 | FACT invariant | P0 | E4-05 | no evidence -> 422 |
| E4-08 | Numeric validator | P0 | E4-05 | unit/date/region/formula checks |
| E4-09 | Evidence review UI | P0 | E4-06 | approve/downgrade/reject/split |
| E4-10 | Freshness/contradiction | P1 | E4-05 | stale/conflict badges/tasks |
| E4-11 | Prompt injection quarantine | P0 | E4-04 | canary test passes |

## Epic E5 — Venture Funnel

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E5-01 | Signal Scout handler | P0 | E4 | change cards, no ideas |
| E5-02 | Signal review/merge | P1 | E5-01 | duplicate merge history |
| E5-03 | Problem Miner handler | P0 | E5-01 | required 5W/workflow/cost |
| E5-04 | Problem detail UI | P0 | E5-03 | evidence and unknowns visible |
| E5-05 | Opportunity Mapper | P0 | E5-03 | role separation and budget |
| E5-06 | Opportunity detail UI | P0 | E5-05 | payer/budget gaps visible |
| E5-07 | Research task queue | P0 | E4-10,E5 | gaps can return to evidence |

## Epic E6 — Idea / Economics / Novelty

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E6-01 | Required Idea Card schema | P0 | E5 | JSON Schema published |
| E6-02 | Generation method matrix | P0 | E6-01 | >=4 methods/opportunity |
| E6-03 | Service Generator | P0 | E3,E6-02 | 20 valid ideas/run |
| E6-04 | Business Model Engineer | P0 | E6-03 | formula/sensitivity/10-1000 |
| E6-05 | Idea revision/history | P0 | E6-03 | append-only revision |
| E6-06 | pgvector embedding | P0 | E6-03 | model/version/hash stored |
| E6-07 | Lexical/field similarity | P0 | E6-03 | component scores |
| E6-08 | Novelty cluster UI | P0 | E6-06,E6-07 | differences visible |
| E6-09 | Human similarity review | P1 | E6-08 | duplicate/related/distinct |

## Epic E7 — Hard Gate

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E7-01 | 15 deterministic prechecks | P0 | E6 | unit tests all branches |
| E7-02 | Gate explanation handler | P0 | E7-01,E3 | reason/evidence/next action |
| E7-03 | pass/hold/fail aggregation | P0 | E7-01 | fatal precedence |
| E7-04 | Gate detail UI | P0 | E7-02 | per-code status |
| E7-05 | Human override/expiry | P0 | E7-03 | reason/approver/audit |
| E7-06 | Re-Gate on revision | P0 | E6-05 | input hash change only |

## Epic E8 — Evaluation / Red Team / Portfolio

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E8-01 | Blinded packet builder | P0 | E7 | leak validator passes |
| E8-02 | Evidence Referee | P0 | E8-01 | score/reason/evidence |
| E8-03 | Commercial Referee | P0 | E8-01 | score/reason/unknowns |
| E8-04 | Technical Referee | P0 | E8-01 | critical path estimate |
| E8-05 | Median/MAD aggregation | P0 | E8-02..04 | formula unit tests |
| E8-06 | Evaluation matrix UI | P0 | E8-05 | disagreement visible |
| E8-07 | Pairwise A/B top candidates | P1 | E8-05 | order-reversal saved |
| E8-08 | Red Team Killer | P0 | E8-05 | 15 attacks/S1-S4 |
| E8-09 | Red Team Improver | P0 | E8-08 | revision or kill |
| E8-10 | S3/S4 re-Gate | P0 | E8-08,E7 | unresolved fatal unselectable |
| E8-11 | Portfolio optimizer | P0 | E8 | cost/diversity constraints |
| E8-12 | Decision finalize UI | P0 | E8-11 | reason and approval |

## Epic E9 — Validation / Approval

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E9-01 | Validation plan schema | P0 | E8 | success/hold/kill required |
| E9-02 | Validation Designer | P0 | E9-01 | top3 plans <=30 days |
| E9-03 | Approval object/API | P0 | E1,E9 | immutable payload hash |
| E9-04 | Experiment board UI | P0 | E9-02 | state/errors/empty |
| E9-05 | Behavior event registry | P0 | E9-04 | levels 1-10, verified flag |
| E9-06 | Experiment result calculator | P0 | E9-05 | metric vs threshold |
| E9-07 | Human result decision | P0 | E9-06 | success/hold/kill audited |
| E9-08 | Contact/CRM connector | P2 | E9-03 | approval-gated only |

## Epic E10 — MVP Project / Learning

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E10-01 | MVP promotion gate | P0 | E9 | no validation -> 422 |
| E10-02 | MVP scope/manual/excluded UI | P1 | E10-01 | value/payment moment |
| E10-03 | Prediction snapshots | P0 | E8 | immutable before outcome |
| E10-04 | Actual outcome join | P0 | E9,E10-03 | score vs event query |
| E10-05 | Learning dashboard | P0 | E10-04 | n and cohort shown |
| E10-06 | n<30 guard | P0 | E10-05 | no auto change |
| E10-07 | Rule change proposals | P0 | E10-05 | backtest/approval/version |
| E10-08 | Shadow calibration model | P2 | E10-07 | time-split evaluation |

## Epic E11 — Export / Audit / Operations

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E11-01 | Audit append-only API/trigger | P0 | E1 | update/delete blocked |
| E11-02 | Run JSONL exporter | P0 | E2..E10 | required files generated |
| E11-03 | Markdown FINAL/STATE exporter | P0 | E11-02 | no content mutation |
| E11-04 | Manifest/hash/count validation | P0 | E11-02 | verify command passes |
| E11-05 | Export UI | P0 | E11-02 | async status/download ref |
| E11-06 | Audit hash chain | P1 | E11-01 | daily anchor |
| E11-07 | Backup/restore runbook | P0 | E1 | rehearsal evidence |
| E11-08 | Metrics/alerts | P0 | E2,E3 | dead jobs/budget/schema alerts |

## Epic E12 — Acceptance / Sample / Release

| ID | Story / Task | Pri | Depends | Done |
|---|---|---:|---|---|
| E12-01 | Official-source sample run | P0 | E4..E11 | full chain and no fake source |
| E12-02 | 15 acceptance test suite | P0 | all P0 | all green |
| E12-03 | Adversarial source suite | P0 | E4,E7 | injection/fake/stale tests |
| E12-04 | Worker chaos/resume test | P0 | E2 | no duplicate output |
| E12-05 | RLS/security review | P0 | E1,E11 | critical/high 0 |
| E12-06 | Operator runbook | P0 | all P0 | second person completes run |
| E12-07 | Release checklist | P0 | E12-01..06 | owner sign-off |

## Critical path

```text
E1 -> E2 -> E3 -> E4 -> E5 -> E6 -> E7 -> E8 -> E9 -> E10 -> E11 -> E12
```

Parallelizable:

- UI detail screens can follow each backend Epic。
- Export skeleton can begin after E2。
- Security tests begin with E1/E4, not Week 12 only。
