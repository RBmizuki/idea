-- Demand Foundry MVP core schema (reference DDL)
-- PostgreSQL 15+ / Supabase-compatible. Production migrations should split this file.

create extension if not exists pgcrypto;
create extension if not exists vector;

create type app_role as enum ('owner','operator','reviewer','approver','viewer');
create type run_status as enum ('draft','queued','running','paused','budget_paused','awaiting_approval','completed','failed','cancelled');
create type stage_status as enum ('pending','ready','running','needs_review','passed','blocked','failed','skipped');
create type job_status as enum ('queued','running','succeeded','failed','dead','cancelled');
create type claim_classification as enum ('FACT','ESTIMATE','ASSUMPTION','HYPOTHESIS','UNKNOWN');
create type review_status as enum ('proposed','approved','contested','stale','rejected','superseded');
create type gate_result as enum ('PASS','HOLD','FAIL');
create type approval_status as enum ('requested','approved','rejected','expired','revoked','executed');

create table workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  default_timezone text not null default 'Asia/Tokyo',
  default_currency text not null default 'JPY',
  status text not null default 'active' check (status in ('active','suspended','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table workspace_memberships (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role app_role not null,
  status text not null default 'active' check (status in ('active','suspended')),
  created_at timestamptz not null default now(),
  unique (workspace_id,user_id)
);

create table prompt_versions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  prompt_key text not null,
  version text not null,
  system_template text not null,
  input_template text not null,
  output_schema_id text,
  status text not null check (status in ('draft','active','retired')),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  content_hash text not null,
  created_at timestamptz not null default now(),
  unique (workspace_id,prompt_key,version)
);

create table rubric_versions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  rubric_key text not null,
  version text not null,
  weights_json jsonb not null,
  anchors_json jsonb not null default '{}'::jsonb,
  hard_gate_policy_json jsonb not null,
  status text not null check (status in ('draft','active','retired')),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  content_hash text not null,
  created_at timestamptz not null default now(),
  unique (workspace_id,rubric_key,version),
  check (jsonb_typeof(weights_json)='object')
);

create table model_policies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  policy_key text not null,
  version text not null,
  provider text not null,
  model_name text not null,
  model_version text not null,
  generation_parameters jsonb not null,
  cost_table_version text not null,
  status text not null check (status in ('draft','active','retired')),
  created_at timestamptz not null default now(),
  unique (workspace_id,policy_key,version)
);

create table runs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  run_key text not null,
  parent_run_id uuid references runs(id),
  status run_status not null default 'draft',
  completion_type text,
  brief_snapshot jsonb not null,
  constraints_snapshot jsonb not null,
  rubric_version_id uuid not null references rubric_versions(id),
  prompt_manifest jsonb not null,
  model_policy_id uuid not null references model_policies(id),
  budget_limit numeric(14,4) not null check (budget_limit >= 0),
  budget_currency text not null default 'JPY',
  spent_amount numeric(14,4) not null default 0 check (spent_amount >= 0),
  committed_amount numeric(14,4) not null default 0 check (committed_amount >= 0),
  random_seed bigint,
  source_snapshot_cutoff timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  paused_reason text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id,run_key)
);

create table run_stages (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade,
  stage_key text not null,
  stage_version text not null,
  status stage_status not null default 'pending',
  dependency_state jsonb not null default '{}'::jsonb,
  input_hash text,
  output_hash text,
  required_artifacts_json jsonb not null default '[]'::jsonb,
  metrics_json jsonb not null default '{}'::jsonb,
  error_summary text,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (run_id,stage_key,stage_version)
);

create table pipeline_jobs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade,
  run_stage_id uuid not null references run_stages(id) on delete cascade,
  entity_type text,
  entity_id uuid,
  stage_key text not null,
  handler_version text not null,
  status job_status not null default 'queued',
  priority integer not null default 0,
  attempt integer not null default 0 check (attempt >= 0),
  max_attempts integer not null default 3 check (max_attempts between 1 and 10),
  available_at timestamptz not null default now(),
  locked_by text,
  locked_until timestamptz,
  heartbeat_at timestamptz,
  idempotency_key text not null unique,
  input_hash text not null,
  estimated_max_cost numeric(14,4) not null default 0 check (estimated_max_cost >= 0),
  last_error_code text,
  last_error_detail_uri text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index pipeline_jobs_claim_idx on pipeline_jobs(status,available_at,priority desc,created_at);
create index pipeline_jobs_run_stage_idx on pipeline_jobs(run_id,stage_key,status);

create table artifacts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade,
  producer_job_id uuid references pipeline_jobs(id),
  artifact_type text not null,
  logical_key text not null,
  storage_uri text not null,
  mime_type text not null,
  content_hash text not null,
  byte_size bigint not null check (byte_size >= 0),
  input_artifact_ids uuid[] not null default '{}',
  schema_id text,
  created_at timestamptz not null default now(),
  unique (run_id,artifact_type,logical_key,content_hash)
);

create table model_calls (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade,
  job_id uuid not null references pipeline_jobs(id) on delete cascade,
  agent_key text not null,
  agent_version text not null,
  prompt_version_id uuid not null references prompt_versions(id),
  model_policy_id uuid not null references model_policies(id),
  request_hash text not null,
  response_hash text,
  raw_request_uri text not null,
  raw_response_uri text,
  input_tokens integer check (input_tokens >= 0),
  output_tokens integer check (output_tokens >= 0),
  cached_tokens integer check (cached_tokens >= 0),
  latency_ms integer check (latency_ms >= 0),
  estimated_cost numeric(14,4) not null default 0,
  actual_cost numeric(14,4),
  currency text not null default 'JPY',
  finish_reason text,
  schema_valid boolean,
  repair_count integer not null default 0 check (repair_count >= 0),
  created_at timestamptz not null default now()
);
create index model_calls_request_idx on model_calls(run_id,request_hash);

create table cost_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade,
  scope_type text not null,
  scope_id uuid,
  entry_type text not null check (entry_type in ('commit','debit','release','adjustment')),
  amount numeric(14,4) not null check (amount >= 0),
  currency text not null default 'JPY',
  cost_category text not null,
  model_call_id uuid references model_calls(id),
  reason text not null,
  created_at timestamptz not null default now()
);
create index cost_entries_run_idx on cost_entries(run_id,created_at);

create table sources (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  source_key text not null,
  title text not null,
  source_type text not null,
  publisher text not null,
  canonical_url text,
  document_identifier text,
  published_at timestamptz,
  geography text,
  industry text,
  language text not null default 'ja',
  trust_class text not null,
  terms_note text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  unique (workspace_id,source_key)
);
create unique index sources_url_unique on sources(workspace_id,canonical_url) where canonical_url is not null;

create table source_snapshots (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  source_id uuid not null references sources(id) on delete cascade,
  retrieved_at timestamptz not null,
  content_hash text not null,
  storage_uri text not null,
  mime_type text not null,
  http_status integer,
  extract_status text not null,
  extraction_quality numeric(5,4) check (extraction_quality between 0 and 1),
  extractor_version text,
  is_current boolean not null default true,
  created_at timestamptz not null default now(),
  unique (source_id,content_hash)
);
create unique index source_snapshot_one_current on source_snapshots(source_id) where is_current;

create table claims (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade,
  claim_key text not null,
  statement text not null,
  classification claim_classification not null,
  claim_scope_json jsonb not null default '{}'::jsonb,
  numeric_value numeric,
  unit text,
  denominator text,
  formula_json jsonb,
  status review_status not null default 'proposed',
  owner_id uuid references auth.users(id),
  review_due_at timestamptz,
  content_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (run_id,claim_key)
);

create table evidence_items (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade,
  source_snapshot_id uuid not null references source_snapshots(id),
  evidence_key text not null,
  summary text not null,
  locator_json jsonb not null,
  quote_hash text,
  confidence_score numeric(5,4) not null check (confidence_score between 0 and 1),
  freshness_score numeric(5,4) not null check (freshness_score between 0 and 1),
  directness_score numeric(5,4) not null check (directness_score between 0 and 1),
  classification_recommendation claim_classification not null,
  review_status review_status not null default 'proposed',
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (run_id,evidence_key)
);

create table claim_evidence_links (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  claim_id uuid not null references claims(id) on delete cascade,
  evidence_item_id uuid not null references evidence_items(id) on delete cascade,
  relation text not null check (relation in ('supports','refutes','context')),
  strength numeric(5,4) not null check (strength between 0 and 1),
  scope_match numeric(5,4) not null check (scope_match between 0 and 1),
  notes text,
  unique (claim_id,evidence_item_id,relation)
);

-- Generic revisioned cards keep their complete machine-readable payload while
-- extracting gate-critical fields to columns. In a production migration,
-- signals/problems/opportunities may be split into more columns as usage stabilizes.
create table signals (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, signal_key text not null,
  logical_id uuid not null default gen_random_uuid(), version integer not null default 1,
  parent_version_id uuid references signals(id), is_current boolean not null default true,
  headline text not null, change_type text not null, confidence numeric(5,4), status text not null,
  payload jsonb not null, content_hash text not null, created_at timestamptz not null default now(),
  unique(run_id,signal_key,version)
);
create unique index signals_current_unique on signals(workspace_id,logical_id) where is_current;

create table problems (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, problem_key text not null,
  logical_id uuid not null default gen_random_uuid(), version integer not null default 1,
  parent_version_id uuid references problems(id), is_current boolean not null default true,
  title text not null, actor text not null, trigger_event text not null, current_alternative jsonb not null,
  current_cost_json jsonb not null, status text not null, payload jsonb not null, content_hash text not null,
  created_at timestamptz not null default now(), unique(run_id,problem_key,version)
);
create unique index problems_current_unique on problems(workspace_id,logical_id) where is_current;

create table opportunities (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, opportunity_key text not null,
  logical_id uuid not null default gen_random_uuid(), version integer not null default 1,
  parent_version_id uuid references opportunities(id), is_current boolean not null default true,
  title text not null, payer text, decision_maker text, budget_source text, purchase_trigger text,
  initial_wedge text, status text not null, payload jsonb not null, content_hash text not null,
  created_at timestamptz not null default now(), unique(run_id,opportunity_key,version)
);
create unique index opportunities_current_unique on opportunities(workspace_id,logical_id) where is_current;

create table ideas (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, idea_key text not null,
  logical_id uuid not null default gen_random_uuid(), version integer not null default 1,
  parent_version_id uuid references ideas(id), is_current boolean not null default true,
  title text not null, one_liner text not null, payer text, decision_maker text, budget_source text,
  current_alternative jsonb not null, data_access text, validation_duration_days integer,
  status text not null, card_json jsonb not null, content_hash text not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(run_id,idea_key,version), check (validation_duration_days is null or validation_duration_days between 1 and 30)
);
create unique index ideas_current_unique on ideas(workspace_id,logical_id) where is_current;
create index ideas_gate_fields_idx on ideas(run_id,status,payer,decision_maker);

create table idea_embeddings (
  idea_id uuid primary key references ideas(id) on delete cascade,
  workspace_id uuid not null references workspaces(id) on delete cascade,
  embedding_model text not null,
  embedding vector(1536) not null,
  structured_fingerprint jsonb not null,
  created_at timestamptz not null default now()
);

create table idea_similarity_links (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  idea_id uuid not null references ideas(id) on delete cascade,
  similar_idea_id uuid not null references ideas(id) on delete cascade,
  lexical_score numeric(5,4), embedding_score numeric(5,4), structured_score numeric(5,4),
  classification text not null check (classification in ('duplicate','near_duplicate','related','distinct')),
  material_differences jsonb not null default '[]'::jsonb,
  reviewed_by uuid references auth.users(id), created_at timestamptz not null default now(),
  check (idea_id <> similar_idea_id), unique(idea_id,similar_idea_id)
);

create table hard_gate_runs (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, idea_id uuid not null references ideas(id) on delete cascade,
  policy_version text not null, overall_result gate_result not null, reason text not null,
  packet_hash text not null, evaluator_identity text not null, created_at timestamptz not null default now()
);

create table hard_gate_checks (
  id uuid primary key default gen_random_uuid(), hard_gate_run_id uuid not null references hard_gate_runs(id) on delete cascade,
  gate_code text not null, result gate_result not null, fatal boolean not null default false,
  reason text not null, evidence_required text, evidence_ids uuid[] not null default '{}', unique(hard_gate_run_id,gate_code)
);

create table evaluator_runs (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, idea_id uuid not null references ideas(id) on delete cascade,
  evaluator_key text not null, evaluator_version text not null, packet_hash text not null,
  blind_mode boolean not null default true, total_score numeric(7,3), uncertainty numeric(7,3),
  rationale text not null, model_call_id uuid references model_calls(id), created_at timestamptz not null default now(),
  unique(run_id,idea_id,evaluator_key,evaluator_version,packet_hash)
);

create table criterion_scores (
  id uuid primary key default gen_random_uuid(), evaluator_run_id uuid not null references evaluator_runs(id) on delete cascade,
  criterion_key text not null, raw_score numeric(6,3) not null, weight numeric(6,3) not null,
  confidence numeric(5,4) not null check(confidence between 0 and 1), evidence_ids uuid[] not null default '{}',
  rationale text not null, unique(evaluator_run_id,criterion_key)
);

create table red_team_reviews (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, idea_id uuid not null references ideas(id) on delete cascade,
  reviewer_mode text not null check(reviewer_mode in ('killer','improver')),
  fatal boolean not null, attack_json jsonb not null, required_evidence_json jsonb not null default '[]'::jsonb,
  model_call_id uuid references model_calls(id), created_at timestamptz not null default now()
);

create table validation_experiments (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, idea_id uuid not null references ideas(id) on delete cascade,
  experiment_key text not null, status text not null check(status in ('draft','approved','running','held','passed','failed','cancelled')),
  biggest_uncertainty text not null, plan_json jsonb not null, duration_days integer not null check(duration_days between 1 and 30),
  budget_limit numeric(14,4) not null check(budget_limit >= 0), success_condition jsonb not null,
  hold_condition jsonb not null, kill_condition jsonb not null, preregistered_at timestamptz,
  started_at timestamptz, completed_at timestamptz, created_at timestamptz not null default now(),
  unique(run_id,experiment_key)
);

create table experiment_events (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  experiment_id uuid not null references validation_experiments(id) on delete cascade,
  event_type text not null check(event_type in ('contacted','replied','meeting_booked','interview_completed','internal_referral','data_shared','approval_started','LOI_received','paid_pilot','converted','retained','expanded','churned','rejected','killed')),
  evidence_level integer not null check(evidence_level between 1 and 10), occurred_at timestamptz not null,
  actor_org_hash text, amount numeric(14,4), currency text, evidence_artifact_id uuid references artifacts(id),
  notes text, recorded_by uuid references auth.users(id), created_at timestamptz not null default now()
);

create table prediction_snapshots (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  run_id uuid not null references runs(id) on delete cascade, idea_id uuid not null references ideas(id) on delete cascade,
  rubric_version_id uuid not null references rubric_versions(id), prediction_json jsonb not null,
  evidence_set_hash text not null, frozen_at timestamptz not null default now(), unique(run_id,idea_id,rubric_version_id)
);

create table approvals (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  action_type text not null check(action_type in ('external_contact','email_send','ad_spend','contract','payment','pii_collection','customer_data_use','production_deploy','regulated_claim','high_budget','business_launch')),
  resource_type text not null, resource_id uuid not null, status approval_status not null default 'requested',
  requested_by uuid not null references auth.users(id), approved_by uuid references auth.users(id),
  request_payload_hash text not null, conditions_json jsonb not null default '{}'::jsonb,
  expires_at timestamptz, executed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table audit_logs (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references workspaces(id) on delete cascade,
  actor_type text not null, actor_id text, action text not null, resource_type text not null, resource_id text not null,
  before_hash text, after_hash text, reason text not null, request_id text, ip_hash text,
  created_at timestamptz not null default now()
);

-- Membership helper. SECURITY DEFINER function must set an explicit search_path.
create or replace function public.is_workspace_member(target_workspace uuid, allowed_roles app_role[] default null)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from workspace_memberships m
    where m.workspace_id = target_workspace
      and m.user_id = auth.uid()
      and m.status = 'active'
      and (allowed_roles is null or m.role = any(allowed_roles))
  );
$$;

alter table runs enable row level security;
alter table ideas enable row level security;
alter table evidence_items enable row level security;
alter table validation_experiments enable row level security;
alter table approvals enable row level security;

create policy runs_read on runs for select using (public.is_workspace_member(workspace_id));
create policy runs_write on runs for all using (public.is_workspace_member(workspace_id,array['owner','operator']::app_role[])) with check (public.is_workspace_member(workspace_id,array['owner','operator']::app_role[]));
create policy ideas_read on ideas for select using (public.is_workspace_member(workspace_id));
create policy ideas_write on ideas for all using (public.is_workspace_member(workspace_id,array['owner','operator']::app_role[])) with check (public.is_workspace_member(workspace_id,array['owner','operator']::app_role[]));
create policy evidence_read on evidence_items for select using (public.is_workspace_member(workspace_id));
create policy evidence_write on evidence_items for all using (public.is_workspace_member(workspace_id,array['owner','operator','reviewer']::app_role[])) with check (public.is_workspace_member(workspace_id,array['owner','operator','reviewer']::app_role[]));
create policy validation_read on validation_experiments for select using (public.is_workspace_member(workspace_id));
create policy validation_write on validation_experiments for all using (public.is_workspace_member(workspace_id,array['owner','operator']::app_role[])) with check (public.is_workspace_member(workspace_id,array['owner','operator']::app_role[]));
create policy approvals_read on approvals for select using (public.is_workspace_member(workspace_id));
create policy approvals_write on approvals for all using (public.is_workspace_member(workspace_id,array['owner','approver']::app_role[])) with check (public.is_workspace_member(workspace_id,array['owner','approver']::app_role[]));

-- Worker uses a separately protected service role and must always scope queries by workspace_id and run_id.
-- audit_logs should be insert/select only at the application role; no update/delete policy is created.
