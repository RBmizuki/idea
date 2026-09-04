# API_SPEC.md

## 1. 方針

- Next.js App Routerの`app/api/*` Route Handlerを使用する。
- UIはRoute Handler経由でapplication serviceを呼ぶ。`page.tsx`に業務ロジックを置かない。
- JSON API。日時はISO 8601 UTC、金額はdecimal string + currency。
- 書き込みは`Idempotency-Key`を推奨し、Run開始・Stage retry・外部actionでは必須。
- Long-running操作は`202 Accepted`とjob resourceを返す。
- Optimistic concurrencyに`If-Match: <version/hash>`を使う。

## 2. 共通Response

成功:

```json
{
  "data": {},
  "meta": {
    "request_id": "req_...",
    "schema_version": "1.0.0"
  }
}
```

エラー:

```json
{
  "error": {
    "code": "PAYER_REQUIRED",
    "message": "支払者が未設定のためHard Gateを通過できません",
    "details": [
      {"path": "customer.payer", "reason": "required_for_pass"}
    ],
    "retryable": false,
    "action": "支払者候補と予算原資の証拠を追加してください"
  },
  "meta": {"request_id": "req_..."}
}
```

## 3. Error codes

| HTTP | Code | 意味 |
|---:|---|---|
| 400 | VALIDATION_ERROR | Zod/JSON Schema不適合 |
| 401 | UNAUTHENTICATED | 認証なし |
| 403 | FORBIDDEN | workspace/role違反 |
| 404 | NOT_FOUND | resourceなし |
| 409 | VERSION_CONFLICT | If-Match不一致 |
| 409 | APPROVAL_REQUIRED | 承認なしで外部行為要求 |
| 409 | INVALID_STATE_TRANSITION | 状態遷移違反 |
| 409 | IDEMPOTENCY_CONFLICT | 同じkeyで異なるpayload |
| 422 | EVIDENCE_REQUIRED | FACTにEvidence不足 |
| 422 | HARD_GATE_BLOCKED | Gate hold/fail |
| 429 | BUDGET_LIMIT_REACHED | Run/stage/agent予算 |
| 502 | PROVIDER_ERROR | LLM/search provider失敗 |
| 503 | JOB_QUEUE_UNAVAILABLE | worker/DB queue問題 |

## 4. Run API

### `POST /api/runs`

新規draft Run。

Request:

```json
{
  "name": "Japan public infrastructure scan",
  "brief_input": {
    "objective": "1〜3人で作れるB2B/B2G事業を探索",
    "regions": ["JP"],
    "domains": ["public_data", "infrastructure", "disaster"],
    "excluded_domains": ["weapons", "consumer_credit"],
    "team_size": 2,
    "mvp_weeks": 10,
    "budget": {"amount": "60.00", "currency": "USD"}
  },
  "rubric_version_id": "..."
}
```

Response `201`: run + compile job。

Validation:

- team_size 1..3 default
- mvp_weeks 1..12 for initial constraints
- budget > 0
- regions non-empty

### `GET /api/runs?status=&cursor=&limit=`

Run一覧。limit 1..100。

### `GET /api/runs/{runId}`

Run summary、stages、cost、counts、blocking approvals。

### `POST /api/runs/{runId}/start`

必須header: `Idempotency-Key`。draft/pausedから開始。

### `POST /api/runs/{runId}/pause`

Request `{ "reason": "manual review" }`。

### `POST /api/runs/{runId}/resume`

Snapshot hash不変を検査。変更があれば`409 FORK_REQUIRED`。

### `POST /api/runs/{runId}/fork`

Requestに変更するbrief/rubric/prompt policy。parent link付きdraftを返す。

### `POST /api/runs/{runId}/cancel`

実行中jobは安全停止、artifactは保持。

## 5. Stage / Job API

### `GET /api/runs/{runId}/stages`

stage status、counts、duration、cost、errors。

### `POST /api/runs/{runId}/stages/{stageKey}/retry`

Request:

```json
{
  "scope": "failed_only",
  "entity_ids": ["optional"],
  "reason": "source parser fixed"
}
```

同一input/handlerで成功済みjobは作らない。

### `GET /api/jobs/{jobId}`

status、attempt、leaseの一般情報。raw errorはadminのみ。

## 6. Brief / Config API

### `GET /api/runs/{runId}/brief`
### `PATCH /api/runs/{runId}/brief`

draft時のみ。同時更新はIf-Match。

### `POST /api/runs/{runId}/brief/compile`

自由入力からsnapshot候補を作る。確定は次API。

### `POST /api/runs/{runId}/brief/finalize`

Finalize後immutable。

### `GET /api/prompt-versions`
### `POST /api/prompt-versions`
### `POST /api/prompt-versions/{id}/activate`

Activateはapprover権限と監査理由必須。

### `GET /api/rubric-versions`
### `POST /api/rubric-versions`

weights合計100、anchor 0/5/10等のvalidate。

## 7. Source / Evidence API

### `POST /api/runs/{runId}/sources`

Request:

```json
{
  "type": "url",
  "url": "https://example.go.jp/document.pdf",
  "expected_publisher": "Example Ministry",
  "purpose": "support signal S-001"
}
```

Response: source + snapshot job。

### `POST /api/runs/{runId}/sources/upload`

multipart。許可mime、サイズ、malware scan。

### `GET /api/runs/{runId}/sources`
### `GET /api/sources/{sourceId}`
### `GET /api/source-snapshots/{snapshotId}/view`

Viewは短時間signed URLまたはsafe viewer。

### `GET /api/runs/{runId}/evidence?review_status=`
### `POST /api/evidence/{evidenceId}/review`

Request:

```json
{
  "action": "approve",
  "classification": "FACT",
  "scope": {"geography": "JP", "as_of": "2023-10-01"},
  "notes": "Source directly states the count"
}
```

Actions: approve/downgrade/reject/split/mark_conflict。

### `POST /api/claims`

FACTの場合、`evidence_ids`必須。ESTIMATEはformula必須。

### `POST /api/claims/{claimId}/links`

support/refute/contextを追加。

## 8. Signal / Problem / Opportunity / Idea API

共通:

- `GET /api/runs/{runId}/{resources}`
- `GET /api/{resource}/{id}`
- `POST /api/{resource}/{id}/revise`
- `POST /api/{resource}/{id}/status`

### `POST /api/runs/{runId}/signals/generate`
### `POST /api/runs/{runId}/problems/generate`
### `POST /api/runs/{runId}/opportunities/generate`
### `POST /api/runs/{runId}/ideas/generate`

長時間処理。`202` jobを返す。

Idea generate Request:

```json
{
  "opportunity_ids": ["O-..."],
  "count": 20,
  "generation_methods": [
    "automation", "decision_support", "monitoring", "aggregation",
    "data_integration", "standardization", "outcome_pricing", "api"
  ],
  "novelty_threshold": 0.82
}
```

Validation:

- count 1..50
- Opportunityは同一Runかつcurrent
- generation_methods >= 4

### `POST /api/ideas/{ideaId}/revise`

新revisionを作る。元行は変更しない。

## 9. Novelty API

### `POST /api/runs/{runId}/novelty/compute`
### `GET /api/ideas/{ideaId}/similar`

Response:

```json
{
  "data": {
    "cluster_id": "NC-04",
    "candidates": [
      {
        "idea_id": "I-007",
        "composite_similarity": 0.88,
        "classification": "near_duplicate",
        "same_dimensions": ["customer", "problem", "mechanism"],
        "different_dimensions": ["payer", "pricing"]
      }
    ]
  }
}
```

### `POST /api/novelty-links/{id}/review`

Humanがduplicate/related/distinctを確定。

## 10. Gate / Evaluation API

### `POST /api/ideas/{ideaId}/hard-gate`

`202`。Deterministic precheck後、必要な説明job。

### `GET /api/ideas/{ideaId}/hard-gate`

各HG code、result、evidence、required next action。

### `POST /api/runs/{runId}/evaluations/start`

Hard Gate PASSのみ。Blinded packetを生成。

### `GET /api/ideas/{ideaId}/evaluations`

Evaluator別、criterion別、median/MAD、disagreement。

### `POST /api/runs/{runId}/pairwise/start`
### `GET /api/runs/{runId}/pairwise`

### `POST /api/ideas/{ideaId}/red-team`

Request `{ "modes": ["killer", "improver"] }`。Killer完了前にImproverを開始しない。

### `POST /api/red-team-findings/{findingId}/resolve`

Requestにresolution、new idea revision、evidence refs。S3/S4は再Gate required。

## 11. Portfolio / Decision API

### `POST /api/runs/{runId}/portfolio/compute`

Request:

```json
{
  "validation_budget": {"amount": "300000", "currency": "JPY"},
  "max_selected": 3,
  "max_per_cluster": 1
}
```

### `POST /api/runs/{runId}/decisions/finalize`

Human approval。selected/hold/rejectedと理由を固定。

## 12. Validation API

### `POST /api/ideas/{ideaId}/validation-plans/generate`
### `GET /api/ideas/{ideaId}/validation-plans`
### `PATCH /api/validation-experiments/{id}`

### `POST /api/validation-experiments/{id}/request-approval`

外部接触内容、想定費用、PII有無をApprovalへ。

### `POST /api/validation-experiments/{id}/events`

Request:

```json
{
  "event_type": "data_shared",
  "occurred_at": "2026-09-22T03:00:00Z",
  "organization_ref": "ORG-ANON-003",
  "strength_level": 5,
  "value": {"dataset_rows": 320, "access_scope": "anonymized sample"},
  "evidence_artifact_id": "artifact_..."
}
```

Allowed event typeはenum。証拠artifactなしでも登録できるが`verified=false`。

### `POST /api/validation-experiments/{id}/complete`

Systemがmetricを計算し、人間がsuccess/hold/killを確定。

## 13. MVP / Learning API

### `POST /api/ideas/{ideaId}/mvp-projects`

Validation success + approval必須。未達は`422 VALIDATION_THRESHOLD_NOT_MET`。

### `GET /api/learning/calibration?window=&cohort=`

scoreとactual eventの比較。

### `POST /api/learning/snapshots`

n、期間、cohortを固定して生成。

### `POST /api/rule-change-proposals`

自動適用不可。

### `POST /api/rule-change-proposals/{id}/approve`

approver + backtest artifact必須。

## 14. Approval API

### `POST /api/approvals`
### `GET /api/approvals?status=requested`
### `POST /api/approvals/{id}/approve`
### `POST /api/approvals/{id}/reject`
### `POST /api/approvals/{id}/revoke`

承認対象payloadのhashを固定する。承認後にpayloadが変われば新承認が必要。

## 15. Export API

### `POST /api/runs/{runId}/exports`

Request:

```json
{
  "formats": ["markdown", "jsonl", "json"],
  "include_raw_model_calls": false,
  "include_source_files": false
}
```

### `GET /api/exports/{exportId}`

status、manifest、期限付きdownload ref。

## 16. Idempotency behavior

- 同一key + 同一payload hash: 初回responseを返す。
- 同一key + 異なるpayload: `409 IDEMPOTENCY_CONFLICT`。
- key保持期間: 30日。
- Stage retryは`handler_version + input_hash`が同じ成功jobを再作成しない。

## 17. Pagination / filtering

Cursor-based。

```text
GET /api/runs/{runId}/ideas?status=generated&gate=pass&limit=50&cursor=...
```

Sort keyはstableな`created_at,id`。全文検索は`q`、Evidence filterは`classification`, `trust_class`, `freshness`。
