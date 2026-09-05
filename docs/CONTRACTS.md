# CONTRACTS.md — 固定語彙・ID・配置・コマンド・スキーマの契約

設計版: `design-v2.0.0`  
位置づけ: **本書は v2.0.0 設計パッケージ全文書の上位契約である。** 他文書は本書の語彙・ID体系・ファイル配置・コマンド名・状態名・スキーマ名に従い、矛盾する場合は本書が優先する。本書に無い事項は各文書の「所有」節（§17）に従って当該文書が定義する。

---

## 1. v1.0.0 からの変更の要約

| 項目 | v1.0.0 | v2.0.0 |
|---|---|---|
| 実行基盤 | Next.js Web + PostgreSQL + TypeScript Worker | **`dfy` CLI（TypeScript）+ run ディレクトリ**。Web/DB は後段オプション |
| データの正 | PostgreSQL | **run ディレクトリ（JSONL + append-only journal）** |
| LLM 呼び出し | 1 API プロバイダー（API key） | **フェーズ別 executor**: Claude Code / Codex(GPT) / Gemini CLI をサブスクリプションで利用。API key 不要 |
| オーケストレーション | Worker が DB ジョブを claim | **CLI が状態機械を所有**。Claude Code 内では `/dfy-run` が「配達人」としてサブエージェントを起動 |
| 予算 | USD ledger | **リクエスト数・利用枠（quota）中心**。USD は cost table 設定時のみ推計 |
| 評価者 | 同一プロバイダー3評価者 | **ベンダー分散**（最低2ベンダー）+ **アンカー基準器**でドリフト観測 |
| 認証・RLS | Supabase Auth + RLS | **単一運営者・ローカル**。マルチユーザーは Phase 3 |
| 削除・変更なし | Evidence/Claim 型、15 Hard Gate、生成/評価分離、30日検証、承認、監査、export | 同左を**全て維持** |

---

## 2. 固定語彙

| 語 | 定義 |
|---|---|
| **Workspace** | `dfy init` で初期化した git リポジトリ。設定・プロンプト・rubric・anchors・runs を持つ |
| **Run** | 1つの Brief に対する探索の単位。`runs/<run_id>/` 配下が唯一の正 |
| **Run Directory** | Run の全状態を保持するディレクトリ。JSONL エンティティ・journal・snapshot・stage-io・export |
| **Journal** | `journal.jsonl`。append-only の状態遷移・監査台帳。ハッシュチェーン付き |
| **Projection** | Journal と JSONL から機械的に再計算される現在状態（`STATE.md`, `costs.json`, `manifest.json` の一部） |
| **Snapshot** | Run 開始時に固定される不変入力（brief / rubric / executors / prompts / anchors / constraints） |
| **Stage** | パイプラインの工程。`stage_key` で識別。kind は `llm` / `deterministic` / `human` |
| **Job** | Stage の実行単位。entity ごとに fan-out する。`job_id` と `idempotency_key` を持つ |
| **Agent** | LLM に与える役割契約（prompt source + output schema + tool policy）。`agent_key` で識別。人格ではない |
| **Prompt Source** | `prompts/<agent_key>/` 配下の正本。ここから subagent 定義と headless 用 request が生成される |
| **Executor** | Job を実際に LLM で実行する手段。`claude-code` / `codex` / `gemini-cli` / `mock` |
| **Executor Mode** | `claude-code` の `subagent`（Claude Code 内で起動）と `headless`（`claude -p`）。他 executor は headless のみ |
| **Orchestrator** | Claude Code 内の slash command `/dfy-run`。**配達人**であり、判断・要約・上書きをしない |
| **Request** | `dfy next` が Job ごとに描画する実行依頼。`request.json`（機械用）と `request.md`（subagent 用） |
| **Response** | executor の出力を `dfy complete` が検証・確定した結果。`response.json` |
| **Packet** | 評価者に渡すブラインド化済み入力（title / origin / rank / generator 情報を除去） |
| **Anchor** | 採点基準器。`ANCHOR-WEAK` と `ANCHOR-STRONG` の2 packet。全 referee バッチに匿名で混入 |
| **Capacity / Quota** | サブスクリプション利用枠。`quota_paused` の原因。USD 予算（`budget_paused`）と区別 |
| **Approval** | 外部行為・顧客データ利用等に対する人間承認オブジェクト。payload hash に紐づく |
| **Mock Executor** | fixture（v1 サンプル run 等）から応答を返す executor。テスト・再現・オフライン用 |
| **Courier Rule** | オーケストレーターがサブエージェントへ渡してよいものをパス・ID・CLI 出力の無改変転記に限定する規則（IdeaForge 由来） |

---

## 3. バージョン

- 設計版: `design-v2.0.0`（`manifest.json.design_version`）
- レコード共通: `schema_version: "2.0.0"`
- Stage 実装版: `handler_version`（例 `hard_gate@2.0.0`）
- Prompt 版: `prompt_version`（例 `referee_commercial@2.0.1`）+ `prompt_hash`（本文 sha256）
- Rubric 版: `rubric_version`（例 `rubric-2.0.0`）+ `rubric_hash`
- Gate policy 版: `gate_policy_version`（例 `hg-2.0.0`）
- Executors 設定版: `executors.snapshot.yaml` の `content_hash`
- v1.0.0 サンプル run（`design/v1.0.0/runs/run-2026-09-04-01/`）は **fixture として読める互換性を維持**する（§15）

---

## 4. 実行形態

| 形態 | 起動 | claude-code job | codex / gemini-cli job | 想定 |
|---|---:|---|---|---|
| **interactive** | Claude Code 内で `/dfy-run <run_id>` | `subagent` として起動 | オーケストレーターが `dfy exec` を Bash 実行 | Claude サブスクを使う標準形 |
| **headless** | ターミナルで `dfy run auto <run_id>` | `claude -p`（サブスク資格情報または API key） | `dfy exec` | 無人実行・CI・夜間 |
| **mock** | 上記いずれか + executors.yaml で `mock` 指定 | fixture | fixture | テスト・再現 |

どの形態でも **状態機械・検証・冪等性・記録は `dfy` CLI が所有**する。オーケストレーターや executor は状態を直接書かない。

- executor の `mode` は `executors.snapshot.yaml` に固定される Run 属性である。snapshot の claude-code が `mode: subagent` の Run に対して `dfy run auto` を実行した場合、claude-code Job に当たった時点で `EXECUTOR_UNAVAILABLE`（終了コード 6、reason `subagent_mode_requires_claude_code`）で停止し `/dfy-run` を案内する。`dfy run auto --headless-only` は claude-code 以外の Job だけを進め、残りが subagent Job のみになった時点で同じ終了コードで止まる。mode を変えたい場合は `dfy run fork`。
- Claude Code の Bash ツールには実行時間上限があるため、`/dfy-run` から呼ぶ `dfy exec` は `--detach`（子プロセスをバックグラウンドで起動し即時終了。完了時に detached プロセス自身が `dfy complete` 相当の確定を行う）を使う。進行中 Job は `dfy next --json` の `in_flight` に現れる。

---

## 5. ディレクトリ配置

### 5.1 実装リポジトリ（single package）

```text
demand-foundry/
  package.json                # name: demand-foundry, bin: { dfy: dist/cli/main.js }
  src/
    cli/                      # コマンド定義（§12）
    schemas/                  # Zod + JSON Schema 生成（§13）
    domain/                   # ID、hash、状態遷移、不変条件
    store/                    # run directory I/O、journal、lock、projection
    executors/                # contract、claude-code、codex、gemini-cli、mock
    prompts/                  # prompt source loader、request renderer、sync-agents
    evidence/                 # fetch、snapshot、extract、injection scan、numeric validator
    evaluation/               # hard gate、packet、anchors、aggregation、pairwise、portfolio
    novelty/                  # lexical + field overlap (+ optional embedding)
    validation/               # plan validator、experiment events、result calculator
    learning/                 # prediction snapshot、calibration、proposals
    export/                   # run package、manifest、FINAL/STATE 生成
  prompts/<agent_key>/        # §8
  schemas/*.schema.json       # 公開 JSON Schema（§13）
  config/executors.example.yaml
  config/executors.mock.yaml  # 全 llm Stage を mock にした受け入れ試験用設定
  config/cost-table.example.yaml  # optional。headless + API key 利用時の USD 推計表（cost_table_version を持つ）
  design/v1.0.0/              # 旧設計（参照のみ）
  docs/                       # 本設計 v2.0.0
  tests/
```

### 5.2 Workspace（`dfy init` の出力）

```text
<workspace>/
  dfy.config.yaml             # workspace 既定（timezone, currency, runs_dir, operator_name）
  executors.yaml              # フェーズ別 executor 割当（§9）
  rubric.yaml                 # 現行 rubric（weights 合計 100、gate policy）
  anchors/
    anchor-weak.packet.json
    anchor-strong.packet.json
  prompts/<agent_key>/        # 正本（実装リポジトリからコピーまたは参照）
  .claude/
    agents/dfy-<agent_key>.md   # 生成物（`dfy sync-agents`）。手編集禁止
    commands/dfy-run.md         # オーケストレーター（配達人）
    commands/dfy-review.md      # Evidence/Gate/Portfolio の人間レビュー補助
  runs/<run_id>/              # §5.3
```

### 5.3 Run Directory（唯一の正）

```text
runs/<run_id>/
  manifest.json                 # run 識別、design_version、snapshot hashes、file inventory（export 時に確定）
  brief.snapshot.yaml
  rubric.snapshot.yaml
  executors.snapshot.yaml
  prompts.snapshot.json         # agent_key -> {prompt_version, prompt_hash}
  anchors.snapshot.json         # 2 packet + hash
  constraints.json
  search_queries.json
  journal.jsonl                 # §11。append-only、hash chain
  STATE.md                      # projection（`dfy state` が再生成。手編集禁止）
  costs.json                    # projection（requests / tokens / 推計 USD）
  model-calls.jsonl             # §10.4
  jobs.jsonl                    # job レコード（projection ではなく append。現在状態は journal から）
  sources.jsonl
  snapshots/<source_id>/<content_hash>/
    original.<ext> | extracted.txt | meta.json
  evidence.jsonl
  claims.jsonl
  signals.jsonl
  problems.jsonl
  opportunities.jsonl
  ideas.jsonl                   # revision は version 付き追記
  novelty.json                  # clusters + similarity links + human review
  gates.jsonl                   # hard gate run + checks（1 行 = 1 run）
  packets/<idea_id>.v<version>.json   # blinded evaluation packet
  evaluations.jsonl             # referee 出力 + aggregation + anchors 観測
  pairs/                        # p01.json … + p01.result.json + index.json + final-ranking.json
  red-team.jsonl
  decisions.jsonl               # portfolio 計算結果と finalize
  validation-plans.jsonl
  experiments/<experiment_id>/
    plan.json | events.jsonl | result.json
  mvp-projects.jsonl            # MVP-NNN。dfy mvp create の出力
  approvals.jsonl
  predictions.jsonl             # prediction snapshots
  learning/                     # calibration snapshots、proposals
  research-tasks.jsonl
  stage-io/<stage_key>/<job_id>/
    request.json | request.md | output.raw.txt | response.json | repairs/<n>.json
    exec/                       # headless executor の作業領域: system.md | prompt.txt | schema.json | cwd/
  FINAL.md                      # export 生成物（decisions.jsonl の転記）
  export/<export_id>/           # zip + manifest
  .lock                         # 同一 run の同時 CLI 実行防止（pid, started_at）
```

規則:

- エンティティ JSONL は **追記のみ**。修正は新 version の追記。`is_current` は projection。
- `STATE.md` / `costs.json` / `FINAL.md` は projection。手編集した場合 `dfy verify` が警告する。
- `stage-io/` と `snapshots/` は容量が大きいため `.gitignore` 対象。export には hash のみ含める（`--include-raw` で同梱可）。

---

## 6. ID 体系

| 種別 | 形式 | 例 |
|---|---|---|
| Run | `run-YYYY-MM-DD-NN` | `run-2026-09-04-01` |
| Job | `JOB-NNNN`（run 内連番） | `JOB-0031` |
| Model call | `MC-NNNN` | `MC-0007` |
| Source / Snapshot | `SRC-NNN` / `SS-NNN` | `SRC-001` / `SS-001` |
| Evidence / Claim | `E-NNN` / `C-NNN` | `E-005` / `C-014` |
| Signal / Problem / Opportunity / Idea | `S-NNN` / `P-NNN` / `O-NNN` / `I-NNN` | `I-001` |
| Idea revision | `I-NNN` + `version`（整数） | `I-001` v2 |
| Novelty cluster / link | `NC-NN` / `NL-NNN` | `NC-04` |
| Hard gate run | `HG-RUN-NNN`、check code は `HG-01`..`HG-15` | |
| Blinded packet | `BP-NN` | `BP-09` |
| Evaluator run | `EV-NNN` | |
| Pairwise match | `pNN` | `p03` |
| Red team review | `RT-NNN` | |
| Decision | `D-S-NNN` | `D-S-001` |
| Validation plan / Experiment | `V-NNN` / `EXP-NNN` | |
| MVP project | `MVP-NNN` | |
| Approval | `APR-NNN` | |
| Research task | `RQ-NNN` | |
| Journal seq | 整数、1 から単調増加 | |
| Anchor | `ANCHOR-WEAK` / `ANCHOR-STRONG` | |

- ID は run 内で一意。連番は journal の `id.allocated` で確定する。`mock` executor が fixture の ID（例 `I-001`）をそのまま採用した場合は `id.allocated` に `hinted: true` を付ける。mock 以外の executor が出力に含めた ID ヒントは無視し、dfy が採番する。
- `content_hash` は正規化 JSON（キーソート、UTF-8、改行なし）の sha256。表記は `sha256:<hex>`。
- `idempotency_key = sha256(run_id | stage_key | entity_id | handler_version | input_hash)`。

---

## 7. Stage キー

`stage_key` / v1 対応 / kind / `agent_key` / 既定 executor / 主入力 / 主出力。kind が `deterministic` の Stage は LLM を呼ばない。`human` は人間の CLI 操作で完了する。

| # | stage_key | v1 Stage | kind | agent_key | 既定 executor | 主入力 | 主出力 |
|---:|---|---|---|---|---|---|---|
| 0 | `brief_compile` | 0 | llm | `brief_compiler` | claude-code / sonnet | brief.yaml（自由記述含む） | brief/rubric/constraints/search_queries snapshot |
| 1 | `signal_scout` | 1 | llm（web） | `signal_scout` | claude-code / opus | brief, search_queries | signals(candidate), source candidates |
| 2 | `source_snapshot` | 2 | deterministic | — | dfy | source candidates / 人手登録 URL・ファイル | sources.jsonl, snapshots/ |
| 3 | `evidence_verify` | 2 | llm | `evidence_verifier` | codex / gpt-5.5 | snapshot extracted text, claim candidates | evidence.jsonl, claims.jsonl |
| 4 | `evidence_review` | 2 | human | — | 人間 | evidence(proposed) | evidence(approved/…) |
| 5 | `problem_mine` | 3 | llm | `problem_miner` | claude-code / sonnet | approved evidence, signals | problems.jsonl |
| 6 | `opportunity_map` | 4 | llm | `opportunity_mapper` | claude-code / sonnet | problems, evidence | opportunities.jsonl |
| 7 | `service_generate` | 5 | llm | `service_generator` | claude-code / sonnet | opportunities, approved evidence, novelty summary | ideas.jsonl |
| 8 | `business_model` | 6 | llm | `business_model_engineer` | codex / gpt-5.5 | ideas | ideas.jsonl（economics 補完 revision） |
| 9 | `novelty` | 5 | deterministic（+ optional llm） | `novelty_analyst`（optional） | dfy（+ gemini-cli / flash） | ideas | novelty.json |
| 10 | `hard_gate` | 7 | deterministic（+ optional llm explanation） | `hard_gate_explainer`（optional） | dfy（+ claude-code / sonnet） | ideas, evidence coverage | gates.jsonl |
| 11 | `blind_packet` | 8 | deterministic | — | dfy | PASS ideas, evidence | packets/ |
| 12 | `referee_evidence` | 8 | llm | `referee_evidence` | codex / gpt-5.5 | packet + anchors | evaluations.jsonl |
| 13 | `referee_commercial` | 8 | llm | `referee_commercial` | claude-code / sonnet | packet + anchors | evaluations.jsonl |
| 14 | `referee_technical` | 8 | llm | `referee_technical` | gemini-cli / pro | packet + anchors | evaluations.jsonl |
| 15 | `aggregate` | 8 | deterministic | — | dfy | evaluations | evaluations.jsonl（aggregation 行） |
| 16 | `pairwise` | 8 | llm | `pairwise_referee` | codex / gpt-5.5 | pairs/pNN.json | pairs/*.result.json, final-ranking.json |
| 17 | `red_team_kill` | 9 | llm | `red_team_killer` | claude-code / opus | top ideas + evidence + eval | red-team.jsonl |
| 18 | `red_team_improve` | 9 | llm | `red_team_improver` | claude-code / opus | idea + killer findings | ideas.jsonl（revision）, red-team.jsonl |
| 19 | `portfolio` | 12 | deterministic | — | dfy | scores, pairwise, red team, costs | decisions.jsonl |
| 20 | `decision_finalize` | 12 | human | — | 人間 | decisions | decisions.jsonl（finalized） |
| 21 | `validation_design` | 10 | llm | `validation_designer` | codex / gpt-5.5 | selected ideas, red team | validation-plans.jsonl |
| 22 | `approval` | 10 | human | — | 人間 | plan payload | approvals.jsonl |
| 23 | `experiment` | 10 | human | — | 人間 | events | experiments/ |
| 24 | `mvp_design` | 11 | llm | `mvp_architect` | claude-code / sonnet | validation success | mvp-projects.jsonl |
| 25 | `learning` | 13 | deterministic（+ optional llm） | `learning_analyst`（optional） | dfy（+ gemini-cli / pro） | predictions, events | learning/ |
| 26 | `export` | — | deterministic | — | dfy | run directory | export/, FINAL.md, manifest |

補助 Stage（Run 外、rubric 単位）: `anchor_author`（llm、agent_key `anchor_author`、既定 claude-code / opus）。`dfy anchors generate` で実行。

依存関係（DAG）は `docs/PIPELINE.md` が所有する。既定 executor は `config/executors.example.yaml` と同一でなければならない。

---

## 8. Agent キーと Prompt Source

### 8.1 Agent 一覧（v1 A-00〜A-20 との対応）

| agent_key | v1 | 役割 | tool policy（既定） |
|---|---|---|---|
| `brief_compiler` | A-00 | Brief → snapshot 候補 | none |
| `signal_scout` | A-01 | 変化・兆候と Source 候補の収集 | web_search, web_fetch |
| `evidence_verifier` | A-03 | Claim と Source 該当箇所の結合、分類推奨 | none（extracted text は payload で渡す） |
| `problem_miner` | A-04 | 具体的 Problem card | none |
| `opportunity_mapper` | A-05 | 支払構造への変換 | none |
| `service_generator` | A-06 | 構造の異なる Idea 生成 | none |
| `business_model_engineer` | A-07 | 価格・原価・10/100/1000 経済性 | none（計算は dfy が再検算） |
| `novelty_analyst` | A-08 | 構造差の説明（optional） | none |
| `hard_gate_explainer` | A-09 | Gate 結果の説明文（optional） | none |
| `referee_evidence` | A-10 | 需要・予算証拠の採点 | none |
| `referee_commercial` | A-11 | payer/GTM/unit economics の採点 | none |
| `referee_technical` | A-12 | data/MVP/integration の採点 | none |
| `pairwise_referee` | A-13 | 2案比較 | none |
| `red_team_killer` | A-14 | 致命欠陥探索 | none（競合 packet は事前に用意） |
| `red_team_improver` | A-15 | 修正案 | none |
| `validation_designer` | A-16 | 30日実験計画 | none |
| `mvp_architect` | A-17 | MVP scope | none |
| `learning_analyst` | A-19 | calibration 所見（optional） | none |
| `anchor_author` | 新規 | rubric ごとの基準器 2 packet | none |

v1 の A-02 Source Snapshotter、A-18 Portfolio Manager、A-20 Exporter は **LLM を使わない dfy の deterministic 処理**へ移行した。

### 8.2 Prompt Source の配置

```text
prompts/<agent_key>/
  meta.yaml            # agent_version, prompt_version, description, tool_policy, model_hint, capabilities_required
  system.md            # 役割・禁止事項・出力規律（executor 非依存の本文）
  instructions.md      # 手順（Handlebars。payload のキーを参照可）
  output.schema.json   # 出力 JSON Schema（§13 互換サブセット）
  examples/            # optional few-shot（fixture 由来）
```

- `prompt_hash = sha256(system.md + instructions.md + output.schema.json + meta.yaml)`。
- `dfy sync-agents` は `.claude/agents/dfy-<agent_key>.md` を生成する。frontmatter: `name: dfy-<agent_key>`、`description`、`tools`（tool_policy から: 常に `Read, Write`。web_search → `WebSearch`、web_fetch → `WebFetch`）、`model`（`executors.yaml` の該当 stage の model alias。未指定は `inherit`）。本文は `system.md` + 「request.md を読み、output_path に JSON のみを書く」固定手順。
- headless / codex / gemini-cli では同じ `system.md` を system prompt、`instructions.md` の描画結果と payload を user prompt として渡す。

### 8.3 Slash command

| ファイル | 役割 |
|---|---|
| `.claude/commands/dfy-run.md` | オーケストレーター。`dfy next` → subagent 起動 / `dfy exec` → `dfy complete` を繰り返す。Courier Rule 遵守。`docs/ORCHESTRATION.md` が所有 |
| `.claude/commands/dfy-review.md` | 人間レビュー補助（Evidence review、Gate override、Decision finalize の CLI 呼び出しを対話で支援）。判断は人間 |

---

## 9. Executor

### 9.1 名称・モード・能力

| executor | 実体 | mode | 認証 | 構造化出力 | web_search | web_fetch | usage 取得 | model 指定 |
|---|---|---|---|---|---|---|---|---|
| `claude-code` | Claude Code CLI | `subagent` | Claude サブスク（Claude Code ログイン） | なし（ファイル出力を dfy が検証） | あり（WebSearch tool） | あり | 不可（`unknown`） | frontmatter `model` |
| `claude-code` | Claude Code CLI | `headless` | サブスク資格情報 または `ANTHROPIC_API_KEY` | `--json-schema` → `structured_output` | `--allowedTools WebSearch,WebFetch` | 同左 | `usage`, `total_cost_usd` | `--model` |
| `codex` | Codex CLI（GPT） | headless のみ | ChatGPT プラン（`codex login`）または `CODEX_API_KEY` | `--output-schema` | executor 設定依存（既定 off） | なし | `turn.completed.usage` | `-m` |
| `gemini-cli` | Gemini CLI | headless のみ | Google アカウント / AI Pro / Ultra（対話ログイン済み資格情報）または `GEMINI_API_KEY` | なし（JSON 抽出 + 検証） | あり（google_web_search） | あり | `stats` | `--model` |
| `mock` | fixture | `headless`（記録上。`dfy exec` が起動する） | 不要 | fixture そのまま | 擬似 | 擬似 | fixture 値 | 記録のみ |

Capability 名: `structured_output`, `web_search`, `web_fetch`, `usage_report`, `model_pin`, `no_tools`（ツール完全無効化が可能）。Stage の `capabilities_required`（meta.yaml）を満たさない executor 割当は `dfy doctor` / `dfy run start` が `CAPABILITY_MISSING` で拒否する。

### 9.2 `executors.yaml`（`schemas/executors-config.schema.json`）

```yaml
version: 1
defaults:
  executor: claude-code
  model: sonnet
  timeout_s: 900
  max_schema_repairs: 2
executors:
  claude-code:
    bin: claude
    mode: subagent                 # subagent | headless
    models: { opus: opus, sonnet: sonnet, haiku: haiku }   # alias -> CLI に渡す値
    headless:
      disallowed_tools_no_tools: "*"
      max_turns_no_tools: 1
      max_turns_with_tools: 25
    capacity: { max_parallel: 4, max_requests_per_run: 400, cooldown_on_limit_s: 900 }
  codex:
    bin: codex
    model: gpt-5.5
    sandbox: read-only
    ephemeral: true
    web_search: false              # MVP では true を VALIDATION_ERROR で拒否する（有効化 flag が未検証のため）
    capacity: { max_parallel: 2, max_requests_per_run: 300, cooldown_on_limit_s: 900 }
  gemini-cli:
    bin: gemini
    model: pro                     # pro | flash | flash-lite | 具体名
    approval_mode: plan
    capacity: { max_parallel: 2, max_requests_per_run: 300, cooldown_on_limit_s: 900 }
  mock:
    fixtures: design/v1.0.0/runs/run-2026-09-04-01
stages:
  brief_compile:      { executor: claude-code, model: sonnet }
  signal_scout:       { executor: claude-code, model: opus }
  evidence_verify:    { executor: codex }
  problem_mine:       { executor: claude-code, model: sonnet }
  opportunity_map:    { executor: claude-code, model: sonnet }
  service_generate:   { executor: claude-code, model: sonnet }
  business_model:     { executor: codex }
  novelty:            { executor: gemini-cli, model: flash, llm_assist: false }   # deterministic。llm_assist: true で novelty_analyst を追加実行
  hard_gate:          { executor: claude-code, model: sonnet, llm_assist: false } # deterministic。llm_assist: true で hard_gate_explainer を追加実行
  referee_evidence:   { executor: codex }
  referee_commercial: { executor: claude-code, model: sonnet }
  referee_technical:  { executor: gemini-cli, model: pro }
  pairwise:           { executor: codex }
  red_team_kill:      { executor: claude-code, model: opus }
  red_team_improve:   { executor: claude-code, model: opus }
  validation_design:  { executor: codex }
  mvp_design:         { executor: claude-code, model: sonnet }
  learning:           { executor: gemini-cli, model: pro, llm_assist: false }     # deterministic。llm_assist: true で learning_analyst を追加実行
  anchor_author:      { executor: claude-code, model: opus }                     # Run 外（rubric 単位）。dfy anchors generate が使う
policies:
  referee_vendor_diversity_min: 2       # 3 referee のうち異なる executor の最小数
  generator_evaluator_separation: agent # agent | vendor
  anchors: observe                      # observe | apply
  usage_unknown_policy: count_requests  # subagent モードで usage 不明時の扱い
```

`dfy run new` は解決後の割当を `executors.snapshot.yaml` に固定する。Run 途中で executors.yaml を変えても当該 run には反映しない（変更したい場合は `dfy run fork`）。

- `llm_assist`: kind が `deterministic（+ optional llm）` の Stage にのみ有効。`false`（既定）では LLM Job を作らず deterministic 処理だけで完了する。`true` で当該 agent の説明・所見 Job を追加する。
- `stages` に無い llm Stage は `defaults` を使う。§7 表の「既定 executor」列は本 YAML と一致していなければならない。

### 9.3 実行時の固定手順（全 executor 共通、`dfy exec` / `dfy complete` が実施）

1. 容量チェック（`capacity`、`quota_paused` でないこと）。
2. `request.json` / `request.md` の描画（§10）。`untrusted_content` は `UNTRUSTED_SOURCE_CONTENT` として JSON フィールドに隔離。
3. executor 起動（tool policy 反映。tool 不要 Stage は完全無効化）。
4. 出力の取得 → JSON 抽出 → JSON Schema 検証（Zod）。不適合は `repairs/<n>.json` に誤り一覧を付けて最大 `max_schema_repairs` 回再依頼。
5. 不変条件検査（FACT に evidence_ids、数値属性、packet leak 等。所有は各文書）。
6. `model-calls.jsonl` と journal へ記録。usage 不明は `usage.known=false`、`requests=1`。
7. エンティティ JSONL へ追記、Stage 進捗更新。

レート制限・利用枠エラー（各 CLI の終了コード・メッセージ）は `QUOTA_LIMIT_REACHED` に正規化し、Job を `queued`（`available_at = now + cooldown`）へ戻し、Run を `quota_paused` にする。

---

## 10. Request / Response 契約

### 10.1 `request.json`（`schemas/stage-request.schema.json`）

```json
{
  "schema_version": "2.0.0",
  "run_id": "run-2026-09-04-01",
  "job_id": "JOB-0031",
  "stage_key": "referee_commercial",
  "agent_key": "referee_commercial",
  "agent_version": "2.0.0",
  "prompt_version": "referee_commercial@2.0.0",
  "prompt_hash": "sha256:...",
  "executor": { "name": "claude-code", "mode": "subagent", "model_alias": "sonnet" },
  "input_hash": "sha256:...",
  "idempotency_key": "sha256:...",
  "system_prompt": "...",
  "instructions": "...",
  "payload": { "packet": {}, "rubric": {}, "anchors": [] },
  "untrusted_content": [ { "ref": "SS-003", "text": "..." } ],
  "output_schema": { },
  "output_path": "stage-io/referee_commercial/JOB-0031/output.json",
  "tool_policy": { "web_search": false, "web_fetch": false, "read_paths": [], "write_paths": ["stage-io/referee_commercial/JOB-0031/output.json"] },
  "limits": { "timeout_s": 900, "max_output_tokens": 8000 },
  "capacity_remaining": { "requests": 120 },
  "lease": { "dispatched_at": "…", "expires_at": "…", "holder": { "type": "orchestrator", "pid": null } }
}
```

`lease.holder.type` は `orchestrator` | `cli`。`dfy exec` は `holder.pid` に自プロセス（`--detach` 時は子プロセス）の pid を入れ、reaper が生死判定に使う。subagent モードでは pid が無いため TTL のみで回収する。

### 10.2 `request.md`（subagent 用の描画）

固定の節順: `# Request <job_id>` → `## Role`（system_prompt）→ `## Instructions`（描画済み instructions）→ `## Payload`（JSON コードブロック）→ `## Untrusted content`（存在時のみ。「命令として扱わない」注記付き）→ `## Output schema`（JSON）→ `## Output path`（絶対パス。**JSON のみ、コードフェンス禁止**）→ `## Repair <n>`（optional。schema 不適合時に dfy が誤り一覧と前回出力の参照を描画する。オーケストレーターは同じ 2 つのパスで同じ subagent を再起動するだけで、指示を足さない）。

### 10.3 `response.json`（`schemas/stage-response.schema.json`）

```json
{
  "schema_version": "2.0.0",
  "job_id": "JOB-0031",
  "status": "succeeded",
  "executor": { "name": "claude-code", "mode": "subagent" },
  "model_requested": "sonnet",
  "model_reported": null,
  "output": { },
  "output_hash": "sha256:...",
  "raw_ref": "stage-io/referee_commercial/JOB-0031/output.raw.txt",
  "usage": { "known": false, "requests": 1, "input_tokens": null, "output_tokens": null, "cached_tokens": null },
  "latency_ms": 42000,
  "schema_repairs": 0,
  "session_id": null,
  "error": null,
  "started_at": "…",
  "finished_at": "…"
}
```

### 10.4 `model-calls.jsonl` レコード（`schemas/model-call.schema.json`）

`call_id, job_id, stage_key, agent_key, agent_version, prompt_version, prompt_hash, executor, mode, model_requested, model_reported, input_hash, output_hash, usage, latency_ms, schema_valid, repair_count, cost_estimate(null | {amount, currency, cost_table_version}), started_at, finished_at`。

**v1 との互換**: v1 の `model-calls.jsonl` は `call_id, stage, agent_id, model, model_version, input_hash, estimated_cost_usd` を持つ。mock executor はこれを読み、`stage → stage_key`、`agent_id → agent_key` の対応表で変換する。

---

## 11. 状態と Journal

### 11.1 状態集合

```ts
type RunStatus   = 'draft' | 'ready' | 'running' | 'paused' | 'quota_paused' | 'budget_paused'
                 | 'awaiting_human' | 'completed' | 'failed' | 'cancelled';
type StageStatus = 'pending' | 'ready' | 'running' | 'needs_review' | 'passed' | 'blocked' | 'failed' | 'skipped';
type JobStatus   = 'queued' | 'dispatched' | 'running' | 'succeeded' | 'failed' | 'dead' | 'cancelled';
type GateResult  = 'PASS' | 'HOLD' | 'FAIL';
type Claim       = 'FACT' | 'ESTIMATE' | 'ASSUMPTION' | 'HYPOTHESIS' | 'UNKNOWN';
type ReviewStatus= 'proposed' | 'approved' | 'contested' | 'stale' | 'rejected' | 'superseded';
type ApprovalStatus = 'requested' | 'approved' | 'rejected' | 'expired' | 'revoked' | 'executed';
type IdeaStatus  = 'generated' | 'rejected' | 'research_pending' | 'evaluating' | 'red_teamed'
                 | 'selected' | 'held' | 'interview_requested' | 'interview_completed' | 'internal_referral'
                 | 'data_shared' | 'LOI_received' | 'paid_pilot' | 'converted' | 'retained' | 'expanded'
                 | 'churned' | 'killed';
```

- `dispatched`: `dfy next` が Request を描画し lease を付与した状態。`lease.expires_at` 超過で `queued` へ戻す（reaper は `dfy next` / `dfy run resume` 実行時に動く）。
- `running`: `dfy exec` が子プロセスを起動中。
- `awaiting_human`: Evidence review、Decision finalize、Approval、Experiment 登録など human Stage で停止中。このとき当該 human Stage の StageStatus は `needs_review` とする（`running` は使わない）。
- Job の `max_attempts` 既定は 3。一時的な `EXECUTOR_ERROR` の再投入は `available_at = now + min(60 × 2^(attempt−1), 900) 秒 + jitter(0〜30 秒)`。`QUOTA_LIMIT_REACHED` は attempt を消費しない。

### 11.2 Journal レコード（`schemas/journal-record.schema.json`）

```json
{ "seq": 120, "ts": "2026-09-04T10:00:00Z", "run_id": "run-…", "type": "job.succeeded",
  "actor": { "type": "cli", "id": "dfy@2.0.0" },
  "payload": { "job_id": "JOB-0031", "output_hash": "sha256:…" },
  "prev_hash": "sha256:…", "hash": "sha256:…" }
```

`type` 一覧: `run.created`, `run.status`, `id.allocated`, `stage.status`, `job.queued`, `job.dispatched`, `job.started`, `job.succeeded`, `job.failed`, `job.dead`, `job.requeued`, `job.cancelled`, `entity.written`, `model_call.recorded`, `review.recorded`, `override.recorded`, `approval.requested`, `approval.approved`, `approval.rejected`, `approval.revoked`, `experiment.event`, `experiment.result`, `decision.finalized`, `export.created`, `incident`, `note`。

`actor.type`: `cli` | `orchestrator` | `human` | `executor` | `system`。人間操作は `--by <name>` を必須とし、`reason` を持つ。`hash = sha256(prev_hash + canonical(record without hash))`。`dfy verify` がチェーンを検証する。

payload の最低限:

| type | 必須 payload |
|---|---|
| `run.created` | `run_key`, `parent_run_id`(null 可), `snapshot_hashes` {brief, rubric, executors, prompts, anchors, constraints} |
| `run.status` | `from`, `to`, `reason`（`quota` の場合は `executor`, `cooldown_s`, `available_at`。`budget` の場合は `scope`, `limit`） |
| `stage.status` | `stage_key`, `from`, `to`, `metrics`(optional) |
| `job.*` | `job_id`, `stage_key`, `attempt`。`job.requeued` は `reason` ∈ {`lease_expired`, `holder_dead`, `quota`, `manual`, `transient_error`} |
| `id.allocated` | `kind`, `id`, `hinted`(bool) |
| `entity.written` | `file`, `count`, `content_hashes[]` |
| `model_call.recorded` | `call_id`, `job_id` |
| `review.recorded` / `override.recorded` / `decision.finalized` / `approval.*` / `experiment.*` | 対象 ID、`by`, `reason`、payload hash（approval） |

---

## 12. CLI コマンド（`dfy`）

名前は固定。詳細な引数・出力・エラーは `docs/CLI_SPEC.md` が所有する。

| コマンド | 役割 | kind |
|---|---|---|
| `dfy init` | Workspace 初期化（config、prompts、.claude 生成） | setup |
| `dfy doctor` | CLI の存在・ログイン・capability・executors.yaml 整合の診断 | setup |
| `dfy sync-agents` | prompts/ から `.claude/agents/dfy-*.md` を再生成 | setup |
| `dfy anchors generate` | rubric ごとの ANCHOR-WEAK / STRONG を生成（LLM） | setup |
| `dfy run new` | Run 作成（draft）。snapshot 固定 | run |
| `dfy run start` / `pause` / `resume` / `cancel` / `fork` / `status` / `list` | Run 操作 | run |
| `dfy run auto` | headless ループ（next → exec → complete）。human Stage で停止 | run |
| `dfy next` | 実行可能 Job を lease し Request を描画。`--max N` `--json` `--lease-ttl` | job |
| `dfy exec` | Job を headless executor で実行し complete まで行う。`--detach` で背景実行 | job |
| `dfy complete` | subagent 出力を検証・確定。`--output` `--usage` `--model` | job |
| `dfy fail` / `dfy requeue` | Job の失敗記録・再投入 | job |
| `dfy source add` / `fetch` / `upload` / `list` | Source 登録と snapshot 取得（deterministic） | evidence |
| `dfy evidence list` / `review` | Evidence review（approve / downgrade / reject / split / conflict） | evidence |
| `dfy claim add` / `link` | Claim 作成と support/refute link | evidence |
| `dfy research list` / `resolve` | Research task | evidence |
| `dfy signal review` | Signal の approve / reject / merge（P1。MVP は閲覧のみ） | evidence |
| `dfy gate run` / `show` / `override` | Hard Gate | evaluation |
| `dfy novelty compute` / `review` | Novelty | evaluation |
| `dfy eval aggregate` / `show` | median/MAD 集計、disagreement、anchor 観測 | evaluation |
| `dfy pairs make` / `tally` | ペア比較の生成・集計 | evaluation |
| `dfy portfolio compute` | 制約付き選定 | evaluation |
| `dfy decision finalize` | 人間による確定 | human |
| `dfy approval request` / `approve` / `reject` / `revoke` / `list` | 承認 | human |
| `dfy experiment start` / `event` / `complete` / `show` | 検証実験と行動イベント | human |
| `dfy mvp create` / `update` | Validation gate を満たす場合のみ MVP project 作成。`update` は milestone / pause / kill（P1） | run |
| `dfy learning snapshot` / `calibration` / `propose` | 学習 | learning |
| `dfy export` | run package 生成（md / jsonl / json / zip）+ manifest | export |
| `dfy verify` | hash chain、manifest、schema、projection 整合の検証 | export |
| `dfy state` | STATE.md 再生成 | projection |
| `dfy show` | エンティティ表示（`--json`） | projection |
| `dfy report` | 静的 HTML レポート生成（P1） | projection |
| `dfy import` | 予約（Phase 3: run ディレクトリ → PostgreSQL の一方向 import）。MVP では実装しない | reserved |

グローバル引数（全コマンド共通）: `--json`、`--run <run_id>`（省略時は `dfy.config.yaml` の current run）、`--by <name>`（human 操作で必須）、`--reason <text>`、`--actor orchestrator`（`/dfy-run` が付ける。journal の `actor.type=orchestrator` になり、human 判断系コマンド（review / override / finalize / approval / experiment）はこの actor を拒否する）、`--dry-run`、`--yes`。

### 12.1 終了コード

| code | 意味 |
|---:|---|
| 0 | 成功 |
| 1 | 一般エラー |
| 2 | 引数・スキーマ検証エラー（`VALIDATION_ERROR` / `POLICY_VIOLATION`） |
| 3 | 状態遷移違反（`INVALID_STATE_TRANSITION` / `LEASE_EXPIRED` / `IDEMPOTENCY_CONFLICT`） |
| 4 | 承認必要（`APPROVAL_REQUIRED`） |
| 5 | 利用枠・予算停止（`QUOTA_LIMIT_REACHED` / `BUDGET_LIMIT_REACHED`） |
| 6 | executor エラー（`EXECUTOR_ERROR` / `EXECUTOR_UNAVAILABLE` / `CAPABILITY_MISSING`） |
| 7 | 修復後もスキーマ不適合（`SCHEMA_INVALID`） |
| 8 | ロック競合（`LOCK_HELD`） |
| 9 | 検証失敗（`VERIFY_FAILED`） |
| 10 | 人間待ち（`AWAITING_HUMAN`。`dfy run auto` が human Stage で停止した場合） |

### 12.2 エラーコード（安定文字列）

`VALIDATION_ERROR`, `POLICY_VIOLATION`（`referee_vendor_diversity_min` 等の policies 違反）, `NOT_FOUND`, `INVALID_STATE_TRANSITION`, `APPROVAL_REQUIRED`, `EVIDENCE_REQUIRED`, `HARD_GATE_BLOCKED`, `QUOTA_LIMIT_REACHED`, `BUDGET_LIMIT_REACHED`, `EXECUTOR_ERROR`, `EXECUTOR_UNAVAILABLE`, `CAPABILITY_MISSING`, `SCHEMA_INVALID`, `LEASE_EXPIRED`, `IDEMPOTENCY_CONFLICT`, `LOCK_HELD`, `FORK_REQUIRED`, `PROMPT_INJECTION_SUSPECTED`, `INVARIANT_VIOLATION`, `VALIDATION_THRESHOLD_NOT_MET`, `VERIFY_FAILED`, `AWAITING_HUMAN`。

`--json` 指定時の出力は常に `{ "data": …, "meta": { "run_id", "command", "dfy_version" } }` または `{ "error": { "code", "message", "details", "retryable", "action" } }`。

---

## 13. スキーマ

`schemas/` に公開する JSON Schema（draft 2020-12）。実装は Zod を正本とし、JSON Schema はそこから生成して同一性テストを行う。

| ファイル | 内容 | v1 との関係 |
|---|---|---|
| `idea-card.schema.json` | Idea Card | v1 を継承。`oneOf` → `anyOf` に変更 |
| `evidence-item.schema.json` | Evidence Item | v1 継承 |
| `validation-plan.schema.json` | Validation Plan | v1 継承 |
| `signal.schema.json` / `problem.schema.json` / `opportunity.schema.json` | 各 card | 新規（v1 サンプルの形を正式化） |
| `claim.schema.json` | Claim + numeric 属性 | 新規 |
| `hard-gate-run.schema.json` | gate run + checks | 新規（v1 evaluations の `record_type: hard_gate` を正式化） |
| `evaluation-record.schema.json` | referee 出力 / aggregation / pairwise | 新規 |
| `red-team-review.schema.json` | killer / improver | 新規 |
| `decision.schema.json` | portfolio 決定 | 新規 |
| `approval.schema.json` | 承認 | 新規 |
| `experiment-event.schema.json` | 行動イベント | 新規 |
| `pipeline-job.schema.json` | Job | v1 継承 + `dispatched`, `lease` |
| `stage-request.schema.json` / `stage-response.schema.json` | §10 | 新規 |
| `model-call.schema.json` | §10.4 | 新規 |
| `journal-record.schema.json` | §11.2 | 新規 |
| `executors-config.schema.json` | §9.2 | 新規 |
| `run-manifest.schema.json` | export manifest | v1 継承 + `design_version: design-v2.0.0`, `journal_head_hash` |

**互換サブセット（全 output.schema.json に適用）**: `oneOf` 禁止（`anyOf` を使う）、`$ref` は生成時にインライン展開、`format` は `date-time` / `date` / `uri` のみ、`additionalProperties` は明示、ネスト深さ 6 以内。これは Gemini と Codex の構造化出力制約に合わせるためである。

---

## 14. 予算・利用枠の語彙

| 語 | 定義 |
|---|---|
| `capacity.max_requests_per_run` | executor ごとの Run 内リクエスト上限 |
| `capacity.max_parallel` | executor ごとの同時実行数 |
| `capacity.cooldown_on_limit_s` | 利用枠エラー後の待機秒 |
| `budget.requests` | Run 全体・Stage 別のリクエスト上限（brief で設定） |
| `budget.usd`（optional） | cost table がある executor（headless API key 利用時）だけの推計上限。cost table は `config/cost-table.yaml`（`cost_table_version` を持つ）。未設定なら USD 推計は `null` |
| `quota_paused` | 利用枠エラーで停止した Run 状態。cooldown 後 `dfy run resume` で再開 |
| `budget_paused` | リクエスト数または USD 推計が上限に達した Run 状態 |

早期停止規則（Gate FAIL 案に評価 call を出さない等）は v1 を継承し `docs/PIPELINE.md` が所有する。

---

## 15. Fixture 互換

- v1 サンプル run の各 JSONL は v2 schema の**読込互換**を保つ（v2 で追加された必須フィールドは読込時に既定値を補う。書込は v2 形式）。
- `mock` executor は `stage_key` ごとに fixture ファイルと対応表を持つ（例 `service_generate` → `ideas.jsonl` の該当 opportunity 分）。対応表は `docs/EXECUTORS.md` が所有する。
- 受け入れ試験の基準線: mock executor で v1 サンプル run を **新規 run として再現**し、Hard Gate 結果（PASS 5 / HOLD 8 / FAIL 7）と上位3案（I-001, I-003, I-010）が一致すること。

---

## 16. 承認の action type（v1 継承）

`external_contact`, `email_send`, `ad_spend`, `contract`, `payment`, `pii_collection`, `customer_data_use`, `production_deploy`, `regulated_claim`, `high_budget`, `business_launch`。

v2 でも**外部行為の実行機能は実装しない**（D-015 維持）。承認は「人間が実行してよい」ことを記録し、payload hash に紐づく。

---

## 17. 文書の所有（重複定義の禁止）

| 文書 | 所有する定義 |
|---|---|
| `CONTRACTS.md` | 本書。語彙、ID、配置、stage/agent/executor 名、状態集合、コマンド名、schema 名、終了コード |
| `VISION.md` | 目的、成功定義、非目的、原則、重要仮定 |
| `PRD.md` | ユーザー、JTBD、機能要件、非機能要件、MVP 範囲、受け入れ条件 |
| `ARCHITECTURE.md` | 構成案比較、採用構成、モジュール境界、データフロー、Resume、拡張境界 |
| `EXECUTORS.md` | executor ごとの起動コマンド・引数、認証、能力、構造化出力、tool 制限、利用枠検知、mock 対応表 |
| `ORCHESTRATION.md` | `/dfy-run` の手順、Courier Rule、`dfy next/exec/complete` の協調、lease、並列、再開、`dfy run auto` |
| `AGENTS.md` | 各 agent の入出力・品質基準・停止条件、prompt source 規約、subagent 生成規則、tool matrix |
| `PIPELINE.md` | Stage DAG、各 Stage の通過・失格・再実行条件、早期停止、Run 完了条件 |
| `EVIDENCE.md` | Source/Evidence/Claim ポリシー、trust class、confidence、数値検査、injection 対策 |
| `EVALUATION.md` | Hard Gate 15 規則、rubric、referee、anchors、median/MAD、pairwise、Red Team、final score、portfolio |
| `DATA_MODEL.md` | 各 JSONL レコードのフィールド、revision、projection、manifest、export 形式、v1 互換 |
| `CLI_SPEC.md` | 各コマンドの引数・出力・エラー・冪等性 |
| `UI_UX.md` | 端末・Markdown・Claude Code 上の体験、STATE.md/FINAL.md/report の構成、レビュー動線 |
| `VALIDATION_SYSTEM.md` | 実験タイプ、行動証拠レベル、success/hold/kill、承認、学習連携 |
| `SECURITY_AND_RISK.md` | ローカル資格情報、prompt injection（ツール付き CLI）、規約、データ分類、監査整合性 |
| `MVP_PLAN.md` | 12 週計画、縦切り、テスト戦略、受け入れ試験、削る順 |
| `BACKLOG.md` | Epic / Story / 優先度 / 依存 / DoD |
| `DECISIONS.md` | ADR（v1 D-001〜D-028 の状態更新 + v2 D-029〜） |
| `STATE.md` | 現在地、完了、未完、次作業、ブロッカー |
| `RED_TEAM_REVIEW.md` | 7 視点の攻撃と反映 |
| `FINAL_ANSWERS.md` | 最終 10 問への回答（v2 更新） |
| `CHANGES_FROM_V1.md` | v1 → v2 の差分一覧と移行方針 |

---

## 18. 固定数値（v1 継承。所有は EVALUATION / EVIDENCE / VALIDATION_SYSTEM）

- Rubric weights: demand_evidence 20 / payer_and_budget 15 / economic_value 15 / customer_reachability 10 / feasibility 10 / validation_speed 10 / recurring_margin 8 / expansion 5 / defensibility 4 / strategic_fit 3（合計 100）
- Hard Gate: HG-01〜HG-15。fatal 優先は HG-07（data access）と HG-14（regulation/liability）
- 集計: `max(0, median − 0.35 × MAD − uncertainty_penalty)`、penalty 0.0 / 0.2 / 0.4 / 0.8 / 1.5
- Disagreement: MAD ≥ 2.0 または range ≥ 4 または confidence 差 ≥ 0.5
- Pairwise 補正: `clamp((elo − 1500) / 100, −5, +5)`
- Red Team 減点: S1 0〜2 / S2 3〜7 / S3 8〜15 / S4 FAIL
- Evidence coverage 最低 0.65（payer / data / regulation は個別必須）
- Validation: duration ≤ 30 日、成功条件に行動証拠（Level 4 以上）を最低 1 つ
- Learning: n < 30 は記述統計のみ、30〜99 は提案のみ、≥ 100 で shadow
- Anchors: ANCHOR-STRONG − ANCHOR-WEAK の総合点差が **3.0 未満**なら referee run を `miscalibrated` として警告（`policies.anchors: observe`）、`apply` 時は線形正規化
- Referee ベンダー分散: 3 referee のうち **異なる executor が 2 以上**（`referee_vendor_diversity_min`）
- Lease TTL: 30 分（`dfy next --lease-ttl` で変更可。常に `limits.timeout_s` 以上）
- Job `max_attempts`: 3。backoff は §11.1
- Schema repair: 最大 2 回。同一 `agent_key` で 3 回連続 `SCHEMA_INVALID` なら当該 Stage を `blocked`
- Referee batch: 1 Job あたり packet 4 件 + anchors 2 件（`referee_batch_size`。所有は EVALUATION）
