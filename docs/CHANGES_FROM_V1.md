# CHANGES_FROM_V1.md

設計版: design-v2.0.0 / 所有範囲: v1.0.0 → v2.0.0 の文書別・節別差分、DB/API/Worker/RLS/予算/認証の対応表、superseded になる v1 ADR、将来 PostgreSQL へ移す際に必要なもの

v1 文書は `design/v1.0.0/docs/` に参照用として残す。本書は「何を変えたか」だけを扱い、変更後の定義は各 v2 文書（`docs/CONTRACTS.md §17` の所有表）が持つ。

## 1. 変更の要約

要約表は `CONTRACTS.md §1`。変更の動機は 3 つである。

1. **単一運営者・ローカル実行**: Auth / RLS / ホスティング / Worker は 12 週の一人開発では純粋な負債になる（v1 Red Team「一人の開発者視点」の残存リスクが顕在化した）。
2. **サブスクリプションで動く CLI**: API key と USD 従量ではなく、Claude Code / Codex / Gemini CLI をフェーズ別に使う。副産物として referee のベンダー分散が標準になる。
3. **IdeaForge v3.1 の教訓**: 決定的処理をスクリプトに固定し、オーケストレーターを配達人にする設計は機能したが、schema・証拠・記録・冪等性が無かった。v2 はその穴を `dfy` CLI で埋める。

**維持する核**（変更なし）: Evidence/Claim 型、15 Hard Gate、生成/評価分離、30 日検証と行動証拠、承認オブジェクト、監査（append-only）、export、median/MAD、pairwise ±5、Red Team S1〜S4、Learning の n 閾値、外部行為を実装しない方針。

凡例: **維持** = 内容そのまま（語彙置換のみ） / **変更** = 実質を変えた / **削除** = v2 に無い / **新設** = v1 に無い。

## 2. 文書別・節別の差分

### 2.1 README.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 位置づけ | 維持 | 「証拠駆動型ベンチャービルダー OS」の定義は同じ |
| 最重要の設計判断 | 変更 | モジュラーモノリス → `dfy` CLI + run directory。PostgreSQL → JSONL + journal。1 provider → フェーズ別 executor。他 5 項目は維持 |
| 文書一覧 | 変更 | `API_SPEC.md` → `CLI_SPEC.md`。新設 `CONTRACTS.md` / `EXECUTORS.md` / `ORCHESTRATION.md` / `CHANGES_FROM_V1.md`。`db/core.sql` 削除 |
| サンプル run | 維持 | mock executor の fixture として読込互換を保つ（`CONTRACTS.md §15`） |
| 推奨実装順 / パッケージ検証 | 変更 | `docs/MVP_PLAN.md`。`validate_package.py` → `dfy verify` + パッケージ validator |

### 2.2 VISION.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1.1 目的、1.2 成功の定義、5 北極星、6 運用像 | 維持 | 「全 LLM 呼び出しの費用追跡」は「requests は必須、tokens/USD は取得可能な場合」に緩和 |
| 1.3 初期制約 | 変更 | Next.js / PostgreSQL の記述を TypeScript CLI に置換。Python は使わない（forge.py 相当は TS に移植） |
| 1.4 最大リスク | 変更 | 「評価者の相関: 不同モデルは将来オプション」→ ベンダー分散が標準。「コスト暴走」→ 利用枠枯渇を追加 |
| 2 重要仮定 | 変更 | A-01（単一運営者）を設計決定に昇格。A-03（1 provider）削除。A-08（pgvector）削除。A-09（Postgres SoT）→ run directory。新設: サブスク CLI の headless 利用は公式推奨外で規約・利用枠が変わり得る |
| 3 非目的 | 維持 | 追加: 第三者にサブスク利用枠や claude.ai ログインを提供しない |
| 4 基本原則 | 変更 | 原則 8「One source of truth」の正を run directory に置換。他 9 原則は維持 |

### 2.3 PRD.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 2 ユーザー | 変更 | MVP は P-01 のみ。P-02/P-04 は Phase 2 viewer、P-03 は Phase 3 |
| 3 JTBD | 維持 | |
| 4.1〜4.3、4.6 機能要件 | 維持 | FR-005 の「表示」は `STATE.md` / `dfy run status` |
| 4.4 Novelty | 変更 | FR-302 の embedding を optional に。lexical + field overlap が必須 |
| 4.5 Gate/Evaluation | 維持 + 新設 | 新設: referee ベンダー分散、anchor 2 packet の混入とドリフト観測 |
| 4.7 Export/Audit/Cost | 変更 | FR-603 tokens は取得可能時のみ。FR-604 予算はリクエスト数と利用枠 |
| 5 非機能要件 | 変更 | NFR-05 RLS → ファイル権限 + git。NFR-07 可用性 → git remote へのバックアップ。NFR-09 UI p95 → 削除（CLI 応答は非目標） |
| 6 MVP 範囲 | 変更 | Web UI を Out of Scope に移動。Phase 2/3 を明記 |
| 7 主要フロー | 変更 | 画面操作 → 端末 / Claude Code |
| 8 受け入れ条件 | 変更 | AC-08 は「`dfy` プロセス kill → resume」。AC-13 は `budget_paused` / `quota_paused`。AC-15 は「終了コード 4 `APPROVAL_REQUIRED`」 |
| 9 製品分析イベント | 削除 | journal に統合。分析専用イベントは持たない |

### 2.4 ARCHITECTURE.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1 構成案比較 | 変更 | 案A = v1 採用構成、案B = CLI + run directory（採用）、案C = IdeaForge 型（不採用） |
| 2 採用構成、2.2 デプロイ単位 | 変更 | 単一 package。`src/` モジュール境界と依存方向を新設 |
| 3 データの正 | 変更 | run directory |
| 4 Run と Stage、5 Job 管理 | 変更 | 状態集合は `CONTRACTS.md §11`。claim SQL → `dfy next` の lease。冪等性・retry 表は維持し error class を追加（quota、injection、lease） |
| 6 Stage データフロー | 維持 | stage_key で書き直し |
| 7 LLM Gateway | 削除 | executor 契約（`docs/EXECUTORS.md`）に置換。context isolation の規則は維持 |
| 8 Research Gateway | 変更 | `dfy source add / fetch / upload` の 3 モードとして維持 |
| 9 Evidence 処理 | 維持 | `docs/EVIDENCE.md` |
| 10 Cost 管理 | 変更 | USD 階層 → requests / capacity / quota。early stop は維持 |
| 11 Resume、12 Error handling、14 監視、15 拡張境界 | 変更 | journal ベースに書き直し。監視に anchor gap、quota、usage unknown を追加 |
| 13 Object Storage layout | 削除 | `snapshots/` と `stage-io/` |

### 2.5 AGENTS.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1 設計原則、共通 Envelope | 変更 | Envelope → `request.json`（`CONTRACTS.md §10.1`）。共通出力要件は維持 |
| 2 職務分離 | 維持 | 新設: `generator_evaluator_separation: agent | vendor` |
| 3 A-00〜A-20 | 変更 | `agent_key` へ改名（`CONTRACTS.md §8.1`）。A-02 / A-18 / A-20 は deterministic 処理へ移行し agent ではなくなる。新設 `anchor_author` |
| 4 Tool Capability Matrix | 変更 | executor 別 tool policy（WebSearch/WebFetch/none）。DB write は無い |
| 5 品質メトリクス | 維持 | anchor gap を追加 |
| — | 新設 | prompt source 規約（`prompts/<agent_key>/`）、subagent 生成規則（`dfy sync-agents`） |

### 2.6 PIPELINE.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1 全体図 | 維持 | stage_key で書き直し |
| 2 Stage 共通契約 | 変更 | `budget_limit`（USD）→ `budget.requests`。`kind: llm / deterministic / human` を追加 |
| 3〜16 Stage 0〜13 | 変更 | 27 の stage_key に分割（`CONTRACTS.md §7`）。通過・失格・再実行条件、ファネル目安、Learning の状態イベントと n 閾値は維持 |
| 17 Pause/Resume/Fork | 変更 | `dfy run pause / resume / fork / cancel`。意味は維持 |
| 18 Run completion | 維持 | 「cost ledger 確定」→「journal と projection の整合」 |

### 2.7 EVIDENCE.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1〜12、15 | 維持 | 用語、分類、trust class、confidence 式、数値検査、citation、鮮度 TTL、反証、coverage 0.65 |
| 13 injection 対策 | 変更 | ツール付き CLI（WebSearch / WebFetch / google_web_search）を持つ executor の制限を追加。`untrusted_content` の隔離は `request.json` で行う |
| 14 review UI rule | 変更 | `dfy evidence review` と `/dfy-review` の表示項目として維持 |
| — | 新設 | `evidence_verifier` は tool none。extracted text は payload で渡す |

### 2.8 EVALUATION.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1〜4、6〜12 | 維持 | 原則、Gate 表、weights、rubric anchor、集計式、pairwise、Red Team、final score、portfolio、bias 防止、market override |
| 5 独立評価 | 変更 | 評価者 = `agent_key` + executor。referee 3 Stage は異なる executor を 2 以上含む |
| 13 出力例 | 変更 | `evaluation-record.schema.json` |
| — | 新設 | ANCHOR-WEAK / ANCHOR-STRONG の全 referee バッチへの混入、gap < 3.0 で `miscalibrated` 警告、`policies.anchors: observe | apply` |

### 2.9 DATA_MODEL.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1 方針 | 変更 | JSONL 追記のみ。revision と projection の考え方は維持 |
| 2 共通列 | 変更 | `workspace_id`、`created_by`（uuid）を削除。`schema_version`、`content_hash`、`logical_id + version`、`is_current`（projection）は維持 |
| 3 Identity / Access | 削除 | Phase 3 |
| 4 Versioned configuration | 変更 | テーブル → ファイル + hash（§3.1） |
| 5 Run / Pipeline | 変更 | journal / `jobs.jsonl` / `model-calls.jsonl` / `costs.json`（§3.1） |
| 6〜10 Evidence〜Learning | 維持 | フィールドは維持し JSONL 化。link table は埋め込み配列 |
| 11 FK chain | 維持 | `dfy verify` が ID 参照の存在を検査 |
| 12 RLS | 削除 | §3.4 |
| 13 Retention | 変更 | ローカル保持。`stage-io/` と `snapshots/` は git 対象外 |
| 14 Migration | 維持 | `schema_version` と 2 major version の reader |

### 2.10 API_SPEC.md → CLI_SPEC.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1 方針 | 変更 | Route Handler → `dfy` サブコマンド。`Idempotency-Key` ヘッダ → `idempotency_key`（Job）と `content_hash`（エンティティ） |
| 2 共通 Response | 維持 | `--json` の `{data, meta}` / `{error}` |
| 3 Error codes | 変更 | HTTP → 終了コード（`CONTRACTS.md §12.1`）。`UNAUTHENTICATED` / `FORBIDDEN` / `VERSION_CONFLICT` / `PROVIDER_ERROR` / `JOB_QUEUE_UNAVAILABLE` 削除。`QUOTA_LIMIT_REACHED` / `EXECUTOR_*` / `LEASE_EXPIRED` / `LOCK_HELD` / `PROMPT_INJECTION_SUSPECTED` 新設 |
| 4〜15 各 API | 変更 | §3.2 |
| 16 Idempotency | 維持 | key 保持期間（30 日）は不要（journal に永続） |
| 17 Pagination | 削除 | `dfy show --json` + `jq` |

### 2.11 UI_UX.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1 UX 原則、20 状態表示標準、21 エラー文標準 | 維持 | 色は使えないため text ラベルのみ |
| 2 ロール | 削除 | 単一運営者 |
| 3〜19 画面 | 変更 | 端末出力、`STATE.md` / `FINAL.md`、`/dfy-review` の動線として書き直し。Phase 2 の `dfy report` / viewer の構成は `docs/UI_UX.md` |

### 2.12 VALIDATION_SYSTEM.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1〜10、13、14 | 維持 | 行動証拠レベル、実験タイプ、plan schema、質問、sales message、sample size、success/hold/kill、Learning 反映、MVP 着手 Gate |
| 11 Human approval、12 Result 登録 | 変更 | `dfy approval *`、`dfy experiment *` |

### 2.13 SECURITY_AND_RISK.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 1 目的 | 維持 | 目的 6（workspace 間分離）は Phase 3 |
| 2〜4、7、9〜11、17 | 維持 | データ分類、PII、顧客データ、citation laundering、外部実行禁止、法務、liability、incident |
| 5 Auth/Authz | 変更 | Supabase → ローカル CLI 資格情報（Claude Code / Codex / Gemini のログイン）、ファイル権限、git |
| 6 Prompt injection | 変更 | ツール付き CLI を持つ executor の攻撃面（WebFetch 経由の連鎖、subagent の Write 範囲）を追加 |
| 8 LLM data handling | 変更 | サブスク CLI の規約・保持条件、headless 利用が公式推奨外である注意 |
| 12 Threat model | 変更 | 「Workspace data leak」→ Phase 3。「利用枠枯渇 / 規約変更」「subagent の越権書込」を追加 |
| 13 監査整合性 | 変更 | journal hash chain + `dfy verify` + git commit |
| 14 Secrets | 変更 | API key を使わない。CLI 資格情報ファイルを run directory・git に入れない |
| 15 Backup | 変更 | git remote。RPO/RTO 目標は削除（ローカル） |
| 16 受け入れ試験 | 変更 | RLS / signed URL / client bundle の項目を削除。lock / lease / chain / subagent write 範囲を追加 |

### 2.14 MVP_PLAN.md / BACKLOG.md

| v1 節 | 状態 | v2 |
|---|---|---|
| 実装戦略（縦切り）、Team 想定、縦切り順、AT matrix | 維持 | AT の語彙置換（worker → `dfy` プロセス、422/409 → 終了コード） |
| 12 週計画、Milestones | 変更 | Week 1 の Auth/RLS/migration → CLI skeleton / journal / store。Web UI の週を executor / orchestration / anchors に振り替え |
| テスト戦略 | 変更 | RLS / signed URL / DB transaction を削除。executor fixture、import 境界、journal chain、resume chaos を追加 |
| リスク、削る順、Release criteria | 変更 | 利用枠・規約変更・構造化出力不安定（Gemini/Codex）を追加 |
| BACKLOG E1（Access） | 変更 | CLI foundation（store / journal / lock） |
| E2（Run/Config/Execution）、E3（LLM/Cost） | 変更 | E2 は `dfy next/exec/complete`、E3 は executors / quota |
| E4〜E10 | 維持 | UI story は CLI / Markdown story に置換 |
| E11（Export/Audit）、E12（Acceptance） | 変更 | journal chain、`dfy verify`、mock 再現試験 |
| — | 新設 | Orchestration（`/dfy-run`、Courier Rule テスト）、Anchors、Executors epic |

### 2.15 DECISIONS.md / STATE.md / RED_TEAM_REVIEW.md / FINAL_ANSWERS.md

| 文書 | 状態 | v2 |
|---|---|---|
| DECISIONS.md | 変更 | D-001〜D-028 の状態更新（§4）+ v2 ADR（D-029〜） |
| STATE.md | 変更 | 全面書き直し |
| RED_TEAM_REVIEW.md | 変更 | 7 視点は維持。攻撃対象に「サブスク規約と利用枠」「CLI 構造化出力の不安定さ」「単一運営者の自己承認」を追加 |
| FINAL_ANSWERS.md | 変更 | 10 問は維持。Q3（ベンダー分散・anchors）、Q9（削るもの）、Q10（12 週）の回答を更新 |

### 2.16 文書以外

| v1 | 状態 | v2 |
|---|---|---|
| `db/core.sql` | 削除 | Phase 3 の参考として v1 に残す |
| `schemas/*.schema.json`（5 件） | 変更 | `oneOf` → `anyOf`、`$ref` インライン。新規 schema 13 件（`CONTRACTS.md §13`） |
| `scripts/validate_package.py` | 変更 | `dfy verify` + パッケージ validator（TS） |
| `runs/run-2026-09-04-01/` | 維持 | fixture。`model-calls.jsonl` は読込時に `stage → stage_key`、`agent_id → agent_key` を変換 |

## 3. 対応表

### 3.1 DB テーブル → run directory

| v1 テーブル | v2 | 備考 |
|---|---|---|
| `workspaces` | `dfy.config.yaml` | Workspace = git リポジトリ 1 つ |
| `profiles`, `workspace_memberships` | 削除 | `operator_name` と `--by <name>` |
| `prompt_versions` | `prompts/<agent_key>/` + `prompts.snapshot.json` | `prompt_version` + `prompt_hash`。承認は git commit |
| `rubric_versions` | `rubric.yaml` + `rubric.snapshot.yaml` | `rubric_version` + `rubric_hash` |
| `agent_versions` | `prompts/<agent_key>/meta.yaml` | `agent_version`、tool_policy |
| `model_policies` | `executors.yaml` + `executors.snapshot.yaml` | model alias、capacity |
| `runs` | `manifest.json` + journal `run.created` / `run.status` + snapshot ファイル | `parent_run_id` は `run.created` payload |
| `run_stages` | journal `stage.status`（projection: `STATE.md`） | |
| `pipeline_jobs` | `jobs.jsonl` + journal `job.*` | `dispatched` と `lease` を追加 |
| `artifacts` | `stage-io/`、`snapshots/`、エンティティ JSONL の `content_hash`、`manifest.json` の file inventory | |
| `model_calls` | `model-calls.jsonl` | `usage.known`、`cost_estimate` null 可 |
| `cost_entries` | `costs.json`（projection） | requests 中心。USD は推計 |
| `approvals` | `approvals.jsonl` | |
| `audit_logs` | `journal.jsonl` | hash chain |
| `sources`, `source_snapshots` | `sources.jsonl` + `snapshots/<source_id>/<content_hash>/` | レコード形は `docs/DATA_MODEL.md` |
| `claims`, `evidence_items`, `claim_evidence_links` | `claims.jsonl`, `evidence.jsonl`（link は埋め込み） | |
| `research_tasks` | `research-tasks.jsonl` | |
| `signals`, `signal_evidence_links` | `signals.jsonl`（`evidence_ids` 埋め込み） | |
| `problems`, `problem_evidence_links` | `problems.jsonl` | |
| `opportunities` | `opportunities.jsonl` | |
| `ideas`, `idea_origins` | `ideas.jsonl`（version 付き追記、origin 埋め込み） | |
| `idea_status_events` | `docs/DATA_MODEL.md` が確定（`ideas.jsonl` の status 行または journal） | v2 でも append-only |
| `idea_features`, `idea_embeddings`, `novelty_clusters`, `idea_similarity_links` | `novelty.json` | embedding は optional。pgvector 無し |
| `hard_gate_runs`, `hard_gate_checks` | `gates.jsonl`（1 行 = 1 run + checks） | |
| `evaluation_packets` | `packets/<idea_id>.v<version>.json` | |
| `evaluator_runs`, `criterion_scores` | `evaluations.jsonl` | anchors 観測行を追加 |
| `pairwise_matches` | `pairs/pNN.json` + `pNN.result.json` + `final-ranking.json` | |
| `red_team_reviews` | `red-team.jsonl` | |
| `portfolio_decisions` | `decisions.jsonl` | |
| `validation_experiments` | `validation-plans.jsonl` + `experiments/<id>/plan.json` | |
| `experiment_events`, `experiment_results` | `experiments/<id>/events.jsonl`, `result.json` | |
| `mvp_projects` | `mvp-projects.jsonl` | |
| `prediction_snapshots` | `predictions.jsonl` | |
| `learning_snapshots`, `rule_change_proposals` | `learning/` | |

### 3.2 API ルート → `dfy` コマンド

| v1 API | v2 |
|---|---|
| `POST /api/runs`, `GET /api/runs`, `GET /api/runs/{id}` | `dfy run new`, `dfy run list`, `dfy run status` |
| `POST .../start` / `pause` / `resume` / `fork` / `cancel` | `dfy run start` / `pause` / `resume` / `fork` / `cancel` |
| `GET .../stages`, `POST .../stages/{key}/retry`, `GET /api/jobs/{id}` | `dfy run status`, `dfy requeue`, `dfy show JOB-NNNN` |
| `brief` / `compile` / `finalize` | `dfy run new`（`brief_compile` Stage を含む。確定 = snapshot 固定） |
| `prompt-versions`, `rubric-versions` | `prompts/` と `rubric.yaml` の git 管理 + `dfy sync-agents` + `dfy anchors generate` |
| `sources`, `sources/upload`, `source-snapshots/{id}/view` | `dfy source add` / `upload` / `fetch` / `list`、`dfy show SRC-NNN` |
| `evidence`, `evidence/{id}/review`, `claims`, `claims/{id}/links` | `dfy evidence list` / `review`、`dfy claim add` / `link` |
| `signals|problems|opportunities|ideas/generate`、`revise`、`status` | `dfy next` → executor → `dfy complete`（Stage として実行）。revise は `red_team_improve` または人間の `dfy show`/追記コマンド |
| `novelty/compute`, `novelty-links/{id}/review` | `dfy novelty compute` / `review` |
| `ideas/{id}/hard-gate` | `dfy gate run` / `show` / `override` |
| `evaluations/start`, `pairwise/start`, `red-team` | `dfy next`（`blind_packet` → referee → `aggregate`）、`dfy pairs make` / `tally`、`red_team_*` Stage |
| `portfolio/compute`, `decisions/finalize` | `dfy portfolio compute`, `dfy decision finalize` |
| `validation-plans/generate`, `request-approval`, `events`, `complete` | `validation_design` Stage、`dfy approval request`、`dfy experiment event` / `complete` |
| `mvp-projects` | `dfy mvp create` |
| `learning/*`, `rule-change-proposals` | `dfy learning snapshot` / `calibration` / `propose` |
| `approvals/*` | `dfy approval request` / `approve` / `reject` / `revoke` / `list` |
| `exports` | `dfy export`、`dfy verify` |
| 無し | `dfy init`、`dfy doctor`、`dfy next` / `exec` / `complete` / `fail`、`dfy state`、`dfy report` |

### 3.3 Worker claim → `dfy next` / `exec` / `complete`

| v1（Worker） | v2（CLI） |
|---|---|
| `SELECT … FOR UPDATE SKIP LOCKED` で 1 Job を claim | `dfy next --max N` が `.lock` 下で実行可能 Job を選び `queued → dispatched`、lease を journal に記録 |
| 同一 transaction で `running`、`locked_by`、`locked_until` | `dfy exec` が `dispatched → running`（`holder.pid`）。subagent は `dispatched` のまま |
| Heartbeat で lease 延長 | 無し。TTL 30 分固定（`--lease-ttl`）。長い Stage は TTL を伸ばす |
| Worker が Job 完了 transaction で artifact / cost / stage progress を確定 | `dfy complete`（headless は `dfy exec` 内部）が検証 → journal → JSONL → projection |
| reaper が期限切れ `running` を `queued` へ | `dfy next` / `dfy run resume` 冒頭の reaper（lease 失効、holder pid 死亡） |
| Worker 水平追加 | 同一マシンの `max_parallel` 並列（子プロセス / subagent）。複数マシンは Phase 3 |

### 3.4 RLS → ファイル権限 + git

| v1 | v2 |
|---|---|
| 全 domain 行に `workspace_id`、RLS で分離 | Workspace = ディレクトリ。OS のファイル権限（運営者のみ rw）。他 Workspace は別ディレクトリ・別リポジトリ |
| role（owner / operator / reviewer / approver / viewer） | 単一運営者。人間操作は `--by <name>` + `reason` を journal に残す（自己承認の記録） |
| service role は Worker のみ | 書込は `dfy` プロセスのみ（INV-1）。executor は `output_path` 以外に書けない |
| viewer に raw model calls 非表示 | `stage-io/` と `snapshots/` は git 対象外、export は `--include-raw` 時のみ同梱 |
| 監査テーブルの UPDATE/DELETE 禁止 | journal hash chain + `dfy verify`。git の履歴で改変を検出 |

### 3.5 USD ledger → requests / quota

| v1 | v2 |
|---|---|
| `cost_entries`（commit / debit / release）、`runs.spent_amount` | `model-calls.jsonl` の `usage.requests` を集計した `costs.json`（projection） |
| Run / Stage / Agent / Model / Idea / Retry reserve の USD 階層 | `capacity.max_requests_per_run`（executor）、`budget.requests`（run / stage）、`capacity.max_parallel` |
| `spent + committed + estimated_job_max <= hard_limit` | `docs/ARCHITECTURE.md §8.1` の preflight（リクエスト数。USD は cost table がある executor のみ） |
| `budget_paused` | `budget_paused`（上限到達）と `quota_paused`（利用枠エラー）を区別 |
| 90% warning、95% 高価モデル停止 | 90% warning は維持。高価モデル停止は executors.yaml の model alias 切替として人間が行う |

### 3.6 Supabase Auth → 単一運営者

| v1 | v2 |
|---|---|
| Supabase Auth / OIDC、MFA | 無し。LLM 側の認証は各 CLI のログイン（Claude Code / `codex login` / Gemini CLI） |
| `created_by uuid` | `actor: {type, id}`（`cli` / `orchestrator` / `human` / `executor` / `system`） |
| approver と operator の分離 | 同一人物。承認は journal と `approvals.jsonl` に記録し、自己承認であることを隠さない |
| Phase 3 | マルチユーザー・RLS・承認者分離を DB import と同時に再検討 |

### 3.7 Object Storage → ローカルディレクトリ

| v1 | v2 |
|---|---|
| `sources/{source_id}/{snapshot_id}/original`, `extracted.txt` | `snapshots/<source_id>/<content_hash>/original.<ext>`, `extracted.txt`, `meta.json` |
| `model-calls/{call_id}/request.json.enc`, `response.json.enc` | `stage-io/<stage_key>/<job_id>/request.json`, `output.raw.txt`, `response.json`, `repairs/`。暗号化なし（ローカル、git 対象外） |
| `exports/{run_id}/{export_id}/…zip` | `export/<export_id>/` |
| 短時間 signed URL | 無し |

### 3.8 v1 エージェント → `agent_key`

対応は `CONTRACTS.md §8.1`。A-02 Source Snapshotter → `source_snapshot`（deterministic）、A-18 Portfolio Manager → `portfolio`（deterministic）、A-20 Exporter → `export`（deterministic）。新設 `anchor_author`。

## 4. v1 ADR の状態

| ADR | v2 状態 | 理由 / 後継 |
|---|---|---|
| D-001 モジュラーモノリス | superseded | CLI + run directory。後継 ADR は `docs/DECISIONS.md` |
| D-002 PostgreSQL を唯一の正 | superseded | run directory（journal + JSONL）。Postgres は Phase 3 の import 先 |
| D-003 DB lease 式 job queue | superseded | `dfy next` の lease を journal に記録。reaper は CLI 起動時 |
| D-004 Route Handlers へ集約 | superseded | Route Handler が無い。業務処理は `src/cli` → 層 2 モジュール |
| D-005 1 LLM provider から開始 | superseded | フェーズ別 executor + referee ベンダー分散 |
| D-006 Zod + JSON Schema | accepted（維持） | 互換サブセット（`oneOf` 禁止等）を追加 |
| D-007 Generator/Evaluator 分離 | accepted（維持・強化） | `generator_evaluator_separation: agent | vendor` |
| D-008 Hard Gate 先行 | accepted | |
| D-009 FACT に Snapshot + locator | accepted | |
| D-010 bottom-up sizing | accepted | |
| D-011 Novelty 複合判定 | amended | embedding を optional に。lexical + field overlap + human review は必須 |
| D-012 pgvector | superseded | MVP に vector store 無し。Phase 3 で再検討 |
| D-013 Python を置かない | accepted | forge.py 相当も TS で実装 |
| D-014 自動 crawler を作らない | accepted | Signal Scout の WebSearch/WebFetch は「承認済み query 集合」に限定 |
| D-015 外部 action executor 無し | accepted | |
| D-016 Validation success を MVP 着手条件 | accepted | |
| D-017 Learning は manual proposal | accepted | |
| D-018 append-only event | accepted | journal と `experiments/*/events.jsonl` |
| D-019 median/MAD | accepted | |
| D-020 Pairwise ±5 | accepted | |
| D-021〜D-025 Red Team 反映 | accepted | |
| D-026 Export は DB から再生成 | amended | run directory から再生成。`FINAL.md` は `decisions.jsonl` の転記 |
| D-027 UI は table/detail | amended | MVP は端末 + Markdown。table/detail は Phase 2 の `dfy report` / viewer |
| D-028 Sample run の金額は推計 | accepted | fixture として維持 |

v2 で新設する ADR の主題（番号は `docs/DECISIONS.md` が確定）: CLI + run directory を正にする / サブスク CLI を executor にし API key を使わない / オーケストレーターを配達人に限定する / journal hash chain / anchors 2 packet / referee ベンダー分散 / 予算をリクエスト数・利用枠中心にする / 単一運営者と Phase 3 / GPT は Codex CLI 経由 / Gemini の JSON 抽出 + 修復 / schema 互換サブセット / v1 サンプル run を fixture にする。

## 5. 削除したものと復活条件

| 削除 | 復活条件 |
|---|---|
| Next.js Web UI、Route Handlers | Phase 2 は静的 report と読み取り専用 viewer まで。書込 UI は Phase 3 |
| PostgreSQL、migration、`db/core.sql` | Phase 3（`docs/ARCHITECTURE.md §11.3` の条件） |
| Supabase Auth、role、RLS、MFA | Phase 3 |
| Worker、heartbeat | 複数マシン実行が必要になったとき |
| LLM Gateway（API key、provider adapter） | executor 契約に吸収。API key 利用は headless の選択肢として残る |
| pgvector、embedding 必須 | labeled duplicate pair が蓄積し lexical + field overlap で不足したとき |
| USD ledger の階層予算 | cost table を持つ headless 運用が主になったとき |
| Object Storage、signed URL、暗号化 raw | Phase 3 |
| 製品分析イベント | Phase 2 viewer |
| Pagination API | 不要 |

## 6. 新設したもの

`CONTRACTS.md`（上位契約）、`dfy` CLI と終了コード、run directory（journal、`stage-io/`、`packets/`、`pairs/`）、Executor 抽象と `executors.yaml`、`request.json` / `request.md` / `response.json`、Prompt Source と `dfy sync-agents`、`/dfy-run`（Courier Rule）と `/dfy-review`、anchors 2 packet とドリフト観測、referee ベンダー分散、`quota_paused`、mock executor と fixture 互換、`dfy verify`。

## 7. 将来 PostgreSQL へ移す際に必要なもの

Phase 3 の import（一方向）を可能にするため、v2 は次を守る。

| 必要なもの | v2 での担保 | import 先（v1 DATA_MODEL） |
|---|---|---|
| グローバル一意キー | `run_id` は日付連番、他 ID は run 内一意。import 時は `(workspace_id, run_id, id)` の複合キーにし、UUID は import 側で採番 | 各テーブルの `id` + 人間可読 ID 列 |
| 監査台帳 | `journal.jsonl`（`seq`、`actor`、`type`、`payload`、`prev_hash`、`hash`） | `audit_logs`（`before_hash`/`after_hash` は `payload` から導出）。chain の検証は import 後も `hash` 列で可能 |
| 状態履歴 | journal の `run.status` / `stage.status` / `job.*` | `runs.status`、`run_stages`、`pipeline_jobs`（projection として再構築） |
| Revision | `logical_id + version`、`content_hash` | `unique(logical_id, version)`、`is_current` は import 時に計算 |
| 再現性 | snapshot ファイルと hash、`prompt_hash` / `rubric_hash` / `executors.snapshot.yaml.content_hash` | `prompt_versions` / `rubric_versions` / `model_policies` に hash を主キー相当で登録 |
| LLM 呼び出し記録 | `model-calls.jsonl`（`usage.known`、`cost_estimate` null 可） | `model_calls`（`input_tokens` 等は NULL 許容にする） |
| 予算 | requests ベースの `costs.json` | `cost_entries` は `amount` を requests 単位でも記録できるよう `cost_category` を拡張 |
| 原文・raw | `snapshots/`、`stage-io/`（git 対象外） | Object Storage へコピー。`manifest.json` の hash で照合 |
| スキーマ版 | 全レコード `schema_version: "2.0.0"` | reader を 2 major version 維持（v1 D-014 相当の Migration 原則） |
| 整合性検査 | `dfy verify`（chain、manifest、schema、参照存在） | import 前後で同じ検査を走らせ、件数と hash が一致すること |
| 権限 | 単一運営者、`--by` | `workspace_memberships` を import 時に作成。journal の `actor.id` を user にマップ |

import コマンド（例: `dfy import --postgres`）は Phase 3 で `CONTRACTS.md §12` に追加する。v2 MVP では実装しない。

## 8. v1 パッケージからの移行手順

1. `design/v1.0.0/` はそのまま残す。編集しない。
2. `schemas/` は v2 で再生成する（`oneOf` → `anyOf`、`$ref` インライン）。v1 の 5 schema に対する v1 サンプル run の適合は保つ。
3. `runs/run-2026-09-04-01/` は mock executor の fixture として `executors.yaml` の `mock.fixtures` から参照する。読込時に v2 の必須フィールドは既定値で補う。
4. 受け入れ基準線: mock executor で v1 サンプル run を新規 Run として再現し、Hard Gate 結果（PASS 5 / HOLD 8 / FAIL 7）と上位 3 案（I-001, I-003, I-010）が一致すること。
5. `validate_package.py` の検査項目（必須文書、JSON/JSONL 構文、20 案、全案 Gate、3 件の 30 日計画、weights 合計）は v2 の validator に引き継ぐ。

## 9. 用語の置換表

| v1 | v2 |
|---|---|
| Worker | `dfy` CLI（`dfy exec` / `dfy run auto`）または オーケストレーター `/dfy-run` |
| Job claim | `dfy next`（lease） |
| Artifact | エンティティ JSONL の行、`stage-io/` のファイル、`snapshots/` |
| LLM Gateway / provider | Executor（`claude-code` / `codex` / `gemini-cli` / `mock`） |
| model policy | `executors.yaml` の Stage 割当と model alias |
| agent_id（`evidence-verifier`） | `agent_key`（`evidence_verifier`） |
| Stage 番号（Stage 0〜13） | `stage_key`（27 件） |
| audit_logs | `journal.jsonl` |
| cost ledger / budget（USD） | requests / capacity / quota（USD は推計） |
| `awaiting_approval` | `awaiting_human` |
| `queued`（Run） | `ready` |
| workspace / membership | Workspace（ディレクトリ）/ 単一運営者 |
| Route Handler / 画面 | `dfy` サブコマンド / `STATE.md` / `FINAL.md` / `/dfy-review` |
| Evaluator | referee（`referee_evidence` / `referee_commercial` / `referee_technical`） |
