# DATA_MODEL.md

## 1. 方針

- PostgreSQLを唯一の正とする。
- 全業務テーブルに`workspace_id`を持たせ、RLSで分離する。
- 重要entityは上書きせず、`logical_id + version`でrevisionを作る。
- 状態遷移は`*_status_events`へappendし、current statusはprojectionとして保持する。
- LLMのraw出力はObject Storage、正規化結果はDBへ保存する。
- JSONBは可変payloadに使うが、Gate、payer、status、cost等の検索・制約対象は列に出す。
- IDはUUIDv7推奨。人間可読IDは別列（`run-YYYY-MM-DD-XX`, `I-001`）。

## 2. 共通列

主要テーブルの共通列:

```text
id uuid primary key
workspace_id uuid not null
run_id uuid null
created_at timestamptz not null
created_by uuid/null
updated_at timestamptz not null
schema_version text not null
content_hash text null
metadata jsonb not null default '{}'
```

Revision対象:

```text
logical_id uuid not null
version int not null
parent_version_id uuid null
is_current boolean not null
unique(workspace_id, logical_id, version)
unique(workspace_id, logical_id) where is_current
```

## 3. Identity / Access

### `workspaces`

- PK: `id`
- columns: `name`, `slug`, `default_timezone`, `default_currency`, `status`
- unique: `slug`

### `profiles`

- PK/FK: `user_id -> auth.users.id`
- columns: `display_name`, `status`

### `workspace_memberships`

- PK: `id`
- FK: `workspace_id`, `user_id`
- columns: `role` (`owner`, `operator`, `reviewer`, `approver`, `viewer`), `status`
- unique: `(workspace_id, user_id)`

MVPではowner/operatorを中心に実装し、reviewer/approver/viewerは簡易権限に留める。

## 4. Versioned configuration

### `prompt_versions`

- `prompt_key`, `version`, `system_template`, `input_template`, `output_schema_id`
- `status`: draft/active/retired
- `approved_by`, `approved_at`
- unique `(workspace_id, prompt_key, version)`

### `rubric_versions`

- `rubric_key`, `version`, `weights_json`, `anchors_json`, `hard_gate_policy_json`
- weights合計100のCHECKまたはapplication validation

### `agent_versions`

- `agent_key`, `version`, `tool_policy_json`, `stop_policy_json`, `prompt_version_id`

### `model_policies`

- `policy_key`, `provider`, `model_name`, `model_version`, `temperature`, `max_output_tokens`, `cost_table_version`

## 5. Run / Pipeline

### `runs`

- PK `id`; human key `run_key`
- FK `workspace_id`, `parent_run_id`, `brief_artifact_id`, `rubric_version_id`
- columns:
  - `status`
  - `completion_type`
  - `budget_limit`, `budget_currency`
  - `spent_amount`, `committed_amount`
  - `random_seed`
  - `source_snapshot_cutoff`
  - `started_at`, `completed_at`, `paused_reason`
- unique `(workspace_id, run_key)`

### `run_stages`

- PK `id`; FK `run_id`
- `stage_key`, `stage_version`, `status`, `dependency_state`
- `input_hash`, `output_hash`
- `started_at`, `finished_at`
- `required_artifacts_json`, `metrics_json`, `error_summary`
- unique `(run_id, stage_key, stage_version)`

### `pipeline_jobs`

- PK `id`; FK `run_id`, optional `entity_id`
- `stage_key`, `handler_version`, `status`
- `priority`, `attempt`, `max_attempts`
- `available_at`, `locked_by`, `locked_until`, `heartbeat_at`
- `idempotency_key`, `input_hash`
- `estimated_max_cost`, `last_error_code`, `last_error_detail_ref`
- unique `idempotency_key`
- indexes: `(status, available_at, priority)`, `(run_id, stage_key)`

### `artifacts`

- `artifact_type`, `logical_key`, `storage_uri`, `mime_type`, `content_hash`, `byte_size`
- `producer_job_id`, `input_artifact_ids`, `schema_id`
- unique `(run_id, artifact_type, logical_key, content_hash)`

### `model_calls`

- FK `job_id`, `agent_version_id`, `prompt_version_id`, `model_policy_id`
- `request_hash`, `response_hash`, `raw_request_uri`, `raw_response_uri`
- `input_tokens`, `output_tokens`, `cached_tokens`, `latency_ms`
- `estimated_cost`, `actual_cost`, `currency`
- `finish_reason`, `schema_valid`, `repair_count`
- index `(run_id, agent_version_id)`

### `cost_entries`

Append-only ledger。

- `scope_type`: run/stage/job/agent/model/idea/opportunity
- `scope_id`
- `entry_type`: commit/debit/release/adjustment
- `amount`, `currency`, `cost_category`, `model_call_id`
- `reason`, `created_at`

`runs.spent_amount`はledger projection。

### `approvals`

- `action_type`: external_contact, email_send, ad_spend, contract, payment, pii_collection, customer_data_use, production_deploy, regulated_claim, high_budget, business_launch
- `resource_type`, `resource_id`
- `status`: requested/approved/rejected/expired/revoked/executed
- `requested_by`, `approved_by`, `expires_at`
- `request_payload_hash`, `conditions_json`, `executed_at`

### `audit_logs`

Append-only。

- `actor_type`, `actor_id`
- `action`, `resource_type`, `resource_id`
- `before_hash`, `after_hash`
- `reason`, `request_id`, `ip_hash`, `created_at`
- UPDATE/DELETE禁止。保守操作はcompensating event。

## 6. Evidence

### `sources`

論理出典。

- `source_key`, `title`, `source_type`, `publisher`
- `canonical_url`, `document_identifier`
- `published_at`, `geography`, `industry`, `language`
- `trust_class`, `terms_note`, `status`
- unique `(workspace_id, canonical_url)` where not null

### `source_snapshots`

- FK `source_id`
- `retrieved_at`, `content_hash`, `storage_uri`, `mime_type`, `http_status`
- `extract_status`, `extraction_quality`, `extractor_version`
- `is_current`
- unique `(source_id, content_hash)`

### `claims`

- `claim_key`, `statement`
- `classification`: FACT/ESTIMATE/ASSUMPTION/HYPOTHESIS/UNKNOWN
- `claim_scope_json`（time/geography/population）
- numeric fields: `numeric_value`, `unit`, `denominator`, `formula_json`
- `status`: proposed/verified/contested/stale/rejected/superseded
- `owner_id`, `review_due_at`

### `evidence_items`

- FK `source_snapshot_id`
- `evidence_key`, `summary`, `locator_json`, `quote_hash`
- `confidence_score`, `freshness_score`, `directness_score`
- `classification_recommendation`
- `review_status`, `reviewed_by`, `reviewed_at`

### `claim_evidence_links`

- FK `claim_id`, `evidence_item_id`
- `relation`: supports/refutes/context
- `strength`, `scope_match`, `notes`
- unique `(claim_id, evidence_item_id, relation)`

### `research_tasks`

- `target_type`, `target_id`, `question`, `required_evidence_type`
- `priority`, `status`, `due_at`, `resolution_artifact_id`

## 7. Domain entities

### `signals`

Revisioned。

- `signal_key`, `change_type`, `headline`
- `changed_from`, `changed_to`
- `effective_at`, `observed_at`
- `geography`, `industry`, `affected_actors_json`
- `confidence`, `status`

### `signal_evidence_links`

- `signal_id`, `evidence_item_id`, `relation`

### `problems`

Revisioned。

- `problem_key`, `title`
- `actor`, `trigger_event`, `location_context`, `task_attempted`, `failure`
- `frequency_json`, `current_workflow`, `current_alternative`
- `current_cost_json`, `cost_of_inaction_json`
- `root_causes_json`, `why_unsolved`
- `status`

### `problem_evidence_links`

- `problem_id`, `evidence_item_id`, `supported_field`

### `opportunities`

Revisioned。

- `opportunity_key`, `title`, `opportunity_statement`
- `user_role`, `problem_owner`, `payer`, `decision_maker`, `champion`, `blocker`, `data_owner`, `beneficiary`
- `budget_source`, `purchase_trigger`
- `current_alternative`, `current_cost_json`
- `why_now`, `initial_wedge`, `expansion_paths_json`
- `status`

### `ideas`

Revisioned。

- `idea_key`, `title`, `one_liner`
- `origin_json`, `change_json`, `problem_json`, `customer_json`
- `current_workflow`, `current_alternative`, `current_cost_json`
- `solution_json`, `business_model_json`, `market_json`, `gtm_json`
- `technology_json`, `competition_json`, `risk_json`
- `validation_json`, `mvp_json`, `economics_json`, `classification_json`
- extracted search columns: `payer`, `decision_maker`, `initial_wedge`, `generation_method`
- `current_status`

### `idea_origins`

- `idea_id`
- `source_type`: signal/problem/opportunity/evidence/idea
- `source_id`
- `relation`: derived_from/crossover/revision/responds_to

### `idea_status_events`

- `idea_logical_id`, `from_status`, `to_status`
- `event_type`, `occurred_at`, `actor_id`, `evidence_ref`, `notes`

Allowed status:

```text
generated, rejected, research_pending, interview_requested,
interview_completed, internal_referral, data_shared, LOI_received,
paid_pilot, converted, retained, expanded, churned, killed
```

## 8. Novelty Archive

### `idea_features`

- `idea_id`
- normalized text/IDs for `customer`, `problem`, `payer`, `mechanism`, `data`, `pricing`, `alternative`, `industry`, `value`, `contract`, `gtm`
- `feature_hash`

### `idea_embeddings`

- `idea_id`, `embedding_model`, `embedding_version`, `vector`, `input_hash`
- one embedding for full concept and optionally per dimension

### `novelty_clusters`

- `cluster_key`, `label`, `representative_idea_id`, `status`

### `idea_similarity_links`

- `idea_id_a`, `idea_id_b`
- `lexical_score`, `embedding_score`, `field_overlap_score`, `composite_score`
- `different_dimensions_json`, `classification`: duplicate/near_duplicate/related/distinct
- unique unordered pair

## 9. Evaluation

### `hard_gate_runs`

- `idea_id`, `gate_policy_version`, `overall_result`, `input_hash`, `executed_at`

### `hard_gate_checks`

- `hard_gate_run_id`, `gate_code`, `result`, `reason_codes`, `reason_text`
- `evidence_ids`, `evidence_required`, `is_fatal`

### `evaluation_packets`

- `idea_id`, `packet_version`, `blinded_label`, `payload_json`, `payload_hash`
- タイトル、origin、rankを含まないことをvalidatorで検査。

### `evaluator_runs`

- `evaluation_packet_id`, `evaluator_type`, `agent_version_id`
- `status`, `overall_confidence`, `model_call_id`

### `criterion_scores`

- `evaluator_run_id`, `criterion_key`, `score`, `confidence`
- `reason_codes`, `reason_text`, `evidence_refs`, `unknowns`

### `pairwise_matches`

- `round`, `idea_a_id`, `idea_b_id`, `presentation_order`
- `winner`, `margin`, `reason_codes`, `seed`, `model_call_id`
- unique `(run_id, round, idea_a_id, idea_b_id, presentation_order)`

### `red_team_reviews`

- `idea_id`, `review_type`: killer/improver
- `finding_code`, `severity`, `fatal`, `attacked_assumption`
- `finding`, `evidence_refs`, `test_to_falsify`, `resolution_status`

### `portfolio_decisions`

- `idea_id`, `decision`: select/hold/reject
- `final_score`, `allocation_amount`, `reason`, `next_action`
- `decision_version`, `approved_by`

## 10. Validation / MVP / Learning

### `validation_experiments`

- `idea_id`, `experiment_key`, `version`
- `biggest_uncertainty`, `hypothesis_claim_id`
- `target_definition_json`, `contact_method`, `script_artifact_id`
- `duration_days`, `budget`, `currency`
- `success_metric_json`, `hold_metric_json`, `kill_metric_json`
- `status`: draft/approval_required/approved/running/completed/paused/cancelled

### `experiment_events`

- `experiment_id`, `event_type`
- `occurred_at`, `actor_ref`, `organization_ref`
- `strength_level`, `value_json`, `evidence_artifact_id`
- `verified_by`, `notes`

PIIは直接格納せず、必要なら暗号化されたcontact vaultのreferenceのみ。

### `experiment_results`

- `experiment_id`, `result`: success/hold/kill/inconclusive
- `metrics_json`, `cost_actual`, `duration_actual_days`
- `decision_reason`, `decided_by`, `decided_at`

### `mvp_projects`

- `idea_id`, `status`, `scope_json`, `manual_operations_json`, `excluded_features_json`
- `planned_start`, `planned_end`, `acceptance_criteria_json`
- `value_moment`, `payment_moment`, `owner_id`

### `prediction_snapshots`

- `idea_id`, `as_of`, `rubric_version_id`
- `scores_json`, `gate_result`, `predicted_outcomes_json`
- `feature_snapshot_hash`

### `learning_snapshots`

- `window_start`, `window_end`, `sample_size`
- `calibration_metrics_json`, `cohort_definition_json`
- `findings_json`, `limitations_json`, `artifact_id`

### `rule_change_proposals`

- `target_type`: gate/rubric/prompt/model-policy
- `target_key`, `from_version`, `proposed_version`
- `change_json`, `reason`, `supporting_learning_snapshot_id`
- `backtest_result_json`, `status`, `approved_by`

## 11. Foreign key chain例

```text
Run
 -> Source Snapshot
 -> Evidence Item
 -> Claim
 -> Signal
 -> Problem
 -> Opportunity
 -> Idea revision
 -> Hard Gate / Evaluations / Red Team
 -> Validation Experiment
 -> Experiment Events / Result
 -> Prediction comparison / Rule proposal
```

すべてのchainを`run_id`だけで推測せず、明示的link tableで追跡する。

## 12. RLS方針

### Human session

- membershipがactiveなworkspace行のみSELECT。
- operator以上がdomain entity作成・編集。
- reviewerはEvidence reviewとコメントのみ。
- approverはApproval status変更のみ。
- viewerはSELECTのみ。
- audit_logs、cost_entriesはINSERTを直接許可せずsecurity definer function経由。

### Worker service role

- Service roleはRLS bypass可能だが、jobの`workspace_id`をapplicationで検証。
- Worker APIは公開しない。
- すべてのwriteに`producer_job_id`を付ける。

### Sensitive data

- raw model calls、source原文、approval payloadはviewerから非表示。
- contact vaultは別schemaとしMVPでは原則使用しない。

## 13. Retention

- Audit / decisions / evaluation: 原則長期保持。
- Source snapshot: ライセンスと目的に応じる。削除時もhash/metadataは保持可能。
- Raw LLM request/response: 180日default、監査要件により変更。
- Customer PII: 実験終了後30日以内削除をdefault。
- Exports: 90日default、再生成可能。

## 14. Migration原則

- `schema_version`をpayloadへ持たせる。
- 破壊的変更は新version列/新tableで段階移行。
- Prompt/Rubric変更とDB migrationを同一versionとして扱わない。
- 過去Runの再現に必要なschema readerを最低2 major version保持。
