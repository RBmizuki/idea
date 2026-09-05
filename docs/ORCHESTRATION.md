# ORCHESTRATION.md

設計版: design-v2.0.0 / 所有範囲: `/dfy-run` の手順、Courier Rule、`dfy next` / `dfy exec` / `dfy complete` の協調、lease と reaper のオーケストレーター側規則、並列 fan-out、再開、失敗時の扱い、報告形式、`/dfy-review`、`dfy run auto`（headless ループ）、slash command 本文の骨子

語彙・状態名・コマンド名・終了コードは `docs/CONTRACTS.md` に従う。store 側の lease・冪等性・復旧規則は `docs/ARCHITECTURE.md §4`、各コマンドの引数と出力の完全形は `docs/CLI_SPEC.md`、subagent 定義（`.claude/agents/dfy-<agent_key>.md`）の生成規則は `docs/AGENTS.md`、executor の起動方法と利用枠検知は `docs/EXECUTORS.md`、端末表示と `STATE.md` の構成は `docs/UI_UX.md` が所有する。

## 1. 位置づけ

- Claude Code 内の `/dfy-run` は**配達人（Courier）**である。IdeaForge v3.1 の `/ideate` が `forge.py` の出力を無改変で転記した役割を継承し、さらに狭めた。`/ideate` はオーケストレーター（LLM）が手順の順序・ペルソナ設計・ラウンド管理を担ったため手順遵守が確率的だった。v2 では「次に何をするか」も `dfy next` の出力であり、オーケストレーターは Stage の順序も DAG も知る必要がない。
- 判断・検証・記録は全て `dfy` CLI が行う（`CONTRACTS.md §4`）。オーケストレーターは「`dfy next` が描画した Request のパスをサブエージェントに渡し、出力パスを `dfy complete` に渡す」以外の情報経路を持たない。
- オーケストレーターは状態を持たない。会話が切れても、`/dfy-run` を再実行すれば `dfy` が journal から続きを出す。

| 主体 | 持つもの | 持たないもの |
|---|---|---|
| `dfy` CLI | 状態機械、DAG、lease、schema 検証と修復依頼、不変条件検査、journal / JSONL 記録、projection | 内容の生成 |
| `/dfy-run` | `dfy` の JSON 出力（その場限り）、サブエージェントを起動する権限、`dfy` を Bash 実行する権限 | 状態、記憶、判断、Run の内容 |
| subagent（`dfy-<agent_key>`） | `request.md` と `output_path` | 他 Job の入出力、順位、他評価者の出力、生成元情報 |
| 人間 | human Stage の判断、override、requeue、pause / cancel / fork | projection・journal の手編集 |

## 2. Courier Rule（越権禁止。最重要）

### 2.1 渡してよいもの / 禁止

サブエージェントに渡してよいのは以下**のみ**。

| 渡してよいもの | 形 |
|---|---|
| `request.md` の絶対パス | `dfy next --json` の `jobs[].request_md` をそのまま |
| `output_path` の絶対パス | `dfy next --json` の `jobs[].output_path` をそのまま |
| `job_id` | `jobs[].job_id` をそのまま（ラベルとして） |
| `dfy` の JSON 出力の無改変転記 | 修復依頼時の `error` オブジェクト等。要約・言い換えをしない |

**禁止**（いずれも journal に `incident` として残る違反であり、実装のテスト対象。§2.5）:

- payload（packet、evidence、idea、講評）の要約・言い換え・抜粋を prompt に書くこと。
- 採点姿勢の追加指示（「厳しめに」「payer を重視して」等）。
- 特定案の名指し・強調、他案との比較の示唆。
- `dfy` の判定（gate、集計、選抜、勝敗、`miscalibrated` 警告、`failed` / `dead`）の上書き・解釈。
- referee 系（`referee_*`、`pairwise_referee`）、Red Team 系（`red_team_killer`、`red_team_improver`）、監査に相当する `evidence_verifier` へ、順位・スコア・他評価者の出力・生成元・系譜を渡すこと。
- schema 不適合時に「こう直せ」という追加指示を書くこと。渡すのは `dfy complete` が返した誤り一覧（`request.md` の `## Repair` 節に dfy が描画する。§4.3）だけである。
- `stage-io/`、`packets/`、`pairs/`、エンティティ JSONL、`journal.jsonl` を読むこと。オーケストレーターが読んでよいのは `dfy` の JSON 出力と `STATE.md` だけである。
- run directory への書込。ファイルを作らない、編集しない。
- `dfy next` が返していない Job を起動すること、返した Job を起動しないこと（「この Stage は不要」等の判断）。

### 2.2 実行してよい `dfy` コマンド

| 許可 | 禁止（人間または `dfy` 内部の領分） |
|---|---|
| `dfy run status`、`dfy run resume`、`dfy run list` | `dfy run start` / `pause` / `cancel` / `fork` / `new` |
| `dfy next`、`dfy exec`、`dfy complete` | `dfy fail`、`dfy requeue` |
| `dfy state`、`dfy show JOB-NNNN --json`（Job 状態のポーリングのみ。他 ID の `show` は不可） | `dfy evidence review`、`dfy gate override`、`dfy novelty review`、`dfy decision finalize`、`dfy approval *`、`dfy experiment *`、`dfy mvp create`、`dfy research resolve` |
| `dfy doctor`（前提確認のみ） | `dfy anchors generate`、`dfy sync-agents`、`dfy export`、`dfy learning *` |

`/dfy-run` の全 `dfy` 呼び出しは `--actor orchestrator` を付け、journal の `actor.type` を `orchestrator` にする（`CONTRACTS.md §11.2`。フラグの詳細は `docs/CLI_SPEC.md`）。禁止列のコマンドは `--actor orchestrator` を拒否する（`VALIDATION_ERROR`）。

### 2.3 サブエージェント起動の固定テンプレート

サブエージェント起動ツール（Claude Code の Task / Agent ツール。`subagent_type: dfy-<agent_key>`）に渡す prompt は次の 3 行**のみ**。`{}` は `dfy next --json` の値をそのまま埋める。

```text
Job {job_id}
Read the request: {request_md}
Write JSON only to: {output_path}
```

- `agent_key` は `jobs[].agent_key`、subagent 名は `dfy-<agent_key>` である。model は subagent 定義の frontmatter（`executors.snapshot.yaml` 由来。`docs/AGENTS.md`）で決まり、オーケストレーターは指定しない。
- サブエージェントの最終メッセージ（「保存した」「失敗した」）はオーケストレーターの判断材料にしない。成否は `dfy complete` が決める。
- サブエージェントは `request.md` 単体で Job を実行できるよう dfy が描画している（`CONTRACTS.md §10.2`、PRD FR-710）。オーケストレーターが文脈を補う必要はなく、補ってはならない。

### 2.4 隔離は dfy が保証する（二重の防壁）

referee が他評価者の出力を見ない、generator が順位を見ない、Red Team Killer と Improver が互いの出力を先に見ない、Source 本文が `untrusted_content` に隔離される——これらは `dfy next` の Request 描画（`CONTRACTS.md §10`）と `dfy complete` の packet leak validator が保証する。Courier Rule はその上に置く第二の防壁であり、オーケストレーターの自制だけに依存する隔離は一つもない。

### 2.5 違反の検知

| 違反 | 検知 |
|---|---|
| subagent prompt にテンプレート外の文字列 | 実装リポジトリの Courier Rule テスト（`/dfy-run` の transcript を固定入力で検査。`docs/MVP_PLAN.md` / `docs/BACKLOG.md`） |
| run directory への直接書込 | `git status` と `dfy verify`（journal に無い変更を `INVARIANT_VIOLATION` として報告） |
| 禁止コマンドの `--actor orchestrator` 実行 | `dfy` が拒否し journal に `incident` |
| `dfy next` が返していない Job の `complete` | `INVALID_STATE_TRANSITION`（終了コード 3） |
| 同一 Job への異なる出力の `complete` | `IDEMPOTENCY_CONFLICT` |

## 3. 状態管理（レジューム対応）

- 状態の正は `journal.jsonl` である。IdeaForge が `STATE.md` を再開の入力にしたのに対し、v2 の `STATE.md` は projection（結果）であり、`dfy run resume` も `dfy next` も `STATE.md` を読まない（`ARCHITECTURE.md §7.1`）。
- オーケストレーターは会話内にも進捗を持たない。「どこまで終わったか」は毎回 `dfy run status --json` / `dfy next --json` に聞く。
- 各ステップ完了直後に `STATE.md` は `dfy` の `store.commit()` が自動再生成する（`ARCHITECTURE.md §4.1`）。オーケストレーターは `dfy state` を明示的に呼ぶ必要はないが、報告直前に呼んでよい。

### 3.1 `dfy next --json` のうち本書が依存する最小フィールド

完全形は `docs/CLI_SPEC.md` が所有する。以下は ORCHESTRATION が前提とする部分集合であり、CLI_SPEC はこれを満たす。

```json
{
  "data": {
    "run_id": "run-2026-09-04-01",
    "run_status": "running",
    "jobs": [
      {
        "job_id": "JOB-0031",
        "stage_key": "referee_commercial",
        "agent_key": "referee_commercial",
        "entity_id": "BP-09",
        "executor": { "name": "claude-code", "mode": "subagent", "model_alias": "sonnet" },
        "request_md": "/abs/runs/run-2026-09-04-01/stage-io/referee_commercial/JOB-0031/request.md",
        "request_json": "/abs/runs/run-2026-09-04-01/stage-io/referee_commercial/JOB-0031/request.json",
        "output_path": "/abs/runs/run-2026-09-04-01/stage-io/referee_commercial/JOB-0031/output.json",
        "lease": { "dispatched_at": "…", "expires_at": "…" },
        "attempt": 1,
        "repair": 0
      }
    ],
    "in_flight": [ { "job_id": "JOB-0029", "status": "dispatched", "executor": "codex", "lease_expires_at": "…" } ],
    "capacity": { "claude-code": { "max_parallel": 4, "in_flight": 1 }, "codex": { "max_parallel": 2, "in_flight": 1 } },
    "empty_reason": null,
    "next_available_at": null
  },
  "meta": { "run_id": "run-2026-09-04-01", "command": "next", "dfy_version": "2.0.0" }
}
```

`jobs` が空のとき `empty_reason` は次のいずれか: `waiting_in_flight`（lease 中の Job が他にある）/ `backoff`（`available_at` 未到来。`next_available_at` を持つ）/ `draft_brief_done`（`brief_compile` 完了。`dfy run start` 待ち）/ `blocked`（Stage `blocked` または `needs_review` で人間の requeue 待ち）/ `paused` / `completed`。`awaiting_human` と `quota_paused` / `budget_paused` は空配列ではなく終了コード 10 / 5 で返る（§4.5）。

### 3.2 Run 状態とオーケストレーターの動作

| `run_status` | `/dfy-run` の動作 |
|---|---|
| `draft` | `dfy next`（`brief_compile` Job のみ返る）。完了後は `empty_reason: draft_brief_done` を受け、「brief を確認して `dfy run start <run_id>`」を報告して停止 |
| `ready` / `running` | `dfy run resume`（no-op 復旧 + reaper）→ ループ（§4.2） |
| `paused` | `dfy run resume` を 1 回試みる。`EXECUTOR_UNAVAILABLE`（6）なら `dfy doctor` の出力を転記して停止 |
| `quota_paused` | `dfy run resume`。cooldown 未経過なら終了コード 5 → 残り時間を転記して停止 |
| `budget_paused` | 報告して停止。再開は fork または新 Run（人間） |
| `awaiting_human` | 停止条件（10）。human Stage と `/dfy-review` の案内を転記して停止 |
| `completed` / `failed` / `cancelled` | `STATE.md` の要約を転記して停止 |

`dfy run resume` は `draft` / `ready` / `running` に対して状態を変えず復旧規則と reaper のみ実行する（終了コード 0。`docs/CLI_SPEC.md`）。オーケストレーターは状態ごとに分岐せず、常に `dfy run resume` を呼び、終了コードに従う。

## 4. `/dfy-run` の手順

### 4.0 引数と前提

- 形式: `/dfy-run <run_id> [--max N]`。`run_id` が無ければ `dfy run list --json` を転記して停止する（選ばない）。
- 前提（違反時は `dfy` が拒否する。オーケストレーターは判定しない）: `dfy doctor` が 0 で終わる、`.claude/agents/dfy-*.md` が `prompts/` と一致する、`CLAUDE_CODE_SUBAGENT_MODEL` が未設定（設定されていると frontmatter の model が全 subagent で上書きされる。`dfy doctor` が警告）。
- `--max N` の既定は `executors.snapshot.yaml` の全 executor の `capacity.max_parallel` 合計（既定設定で 4 + 2 + 2 = 8）。`dfy next` は executor ごとの `max_parallel` を超えて lease しないため、N は上限でしかない。

### 4.1 準備

1. `dfy run status <run_id> --json --actor orchestrator`。`NOT_FOUND` なら停止。
2. `dfy run resume <run_id> --json --actor orchestrator`。終了コード 0 以外は §4.5 の表に従って停止。
3. `STATE.md` の Run ヘッダ（`docs/UI_UX.md §5`）を転記して開始を告げる（1 回だけ）。

### 4.2 ループ

```text
loop:
  R = dfy next <run_id> --max N --json --actor orchestrator
  if exit(R) == 10: 報告（§9）して停止           # awaiting_human
  if exit(R) == 5:  cooldown / 上限を転記して停止  # quota_paused / budget_paused
  if exit(R) == 8:  10 秒待って再試行（最大 3 回）  # LOCK_HELD
  if exit(R) not in {0}: error を転記して停止
  if R.data.jobs が空:
      empty_reason == waiting_in_flight → in_flight を転記して停止（§5）
      empty_reason == backoff          → next_available_at を転記して停止
      それ以外                          → 報告（§9）して停止
  S = jobs のうち executor.name == "claude-code" かつ executor.mode == "subagent"
  X = jobs − S
  S を全て並列起動（1 メッセージで複数の起動。§2.3 テンプレート）
  X を各 `dfy exec <job_id> --json --actor orchestrator`（§4.4）
  S の各 Job が戻り次第 `dfy complete <job_id> --output <output_path> --json --actor orchestrator`（§4.3）
  全 Job の complete / exec の結果を §7 の表で処理
  continue
```

ループは `dfy next` が新しい Job を返す限り続く。1 回のループで扱う Job は `dfy next` が返したものだけであり、返された Job を残さず、返されていない Job を起動しない。

### 4.3 subagent Job の処理

1. 起動: §2.3 のテンプレートで `dfy-<agent_key>` を起動する。複数あれば同じメッセージで並列起動する。
2. 完了: 戻り次第 `dfy complete <job_id> --output <output_path> --json --actor orchestrator`。`--usage` / `--model` は付けない（subagent モードは usage を取れない。`usage.known=false`、`requests=1`。`CONTRACTS.md §10.3`）。
3. `dfy complete` の結果:

| 終了コード / `error.code` | dfy が行ったこと | オーケストレーターの動作 |
|---|---|---|
| 0 | schema 検証・不変条件検査・記録・エンティティ追記 | 次へ |
| 0（同一 `output_hash` の再 complete） | no-op | 次へ |
| 7 `SCHEMA_INVALID`、`retryable: true` | `repairs/<n>.json` を書き、`request.md` 末尾に `## Repair <n>` 節（誤り一覧の転記と「`output_path` を全文書き直す」固定文）を描画。Job は `dispatched` のまま、lease 延長 | **同じ 3 行テンプレート・同じ 2 パス**で同じ subagent を再起動 → 再度 `dfy complete`。指示を足さない |
| 7 `SCHEMA_INVALID`、`retryable: false` | `max_schema_repairs`（2）超過。Job `failed`、Stage `needs_review` | `error` を転記して次の Job へ。人間が `dfy requeue --by` する |
| 2 `VALIDATION_ERROR`（`output_path` にファイルが無い） | 修復 1 回分として扱い `## Repair <n>` を描画 | 上の retryable 行と同じ |
| `LEASE_EXPIRED` | 出力を `output.raw.txt` に保存。状態は進めない | 次の `dfy next` で同 `job_id` が再 lease されたら、subagent を起動せず `dfy complete <job_id> --output <同じ output_path>` を先に試す。`IDEMPOTENCY_CONFLICT` なら通常どおり再起動 |
| 3 `INVALID_STATE_TRANSITION` | Job が `dispatched` / `running` でない | `error` を転記して次へ |
| `INVARIANT_VIOLATION`（packet leak、FACT に evidence 無し等） | Job `dead`、journal `incident` | `error` を転記して次へ。再起動しない |
| `PROMPT_INJECTION_SUSPECTED` | quarantine、Stage `needs_review` | `error` を転記して次へ |
| 8 `LOCK_HELD` | — | 10 秒待って同じコマンドを再試行（最大 3 回） |

### 4.4 exec Job の処理

- `codex`、`gemini-cli`、`mock`、および `mode: headless` の `claude-code` は `dfy exec <job_id> --json --actor orchestrator` で実行する。`dfy exec` は起動から `complete` までを内部で完結する（`CONTRACTS.md §9.3`）。
- `dfy exec` は `limits.timeout_s`（既定 900 秒）まで子プロセスを待つ。Claude Code の Bash ツールのタイムアウト（既定 2 分、最大 10 分）より長いため、**前景実行しない**。Bash のバックグラウンド実行（完了時に通知される）で起動し、通知を待つ。バックグラウンド実行が使えない環境では `dfy exec <job_id> --detach`（子プロセスを切り離して即時復帰。完了処理は dfy 自身が行う。ASSUMPTION: `docs/CLI_SPEC.md` が採否を決める）で起動し、`dfy show <job_id> --json` を 30 秒間隔でポーリングする。
- 同一 executor の `dfy exec` は `capacity.max_parallel` まで同時に起動してよい（`.lock` はコミット中のみ保持され、子プロセス待機中は保持しない。`ARCHITECTURE.md §4.1`）。逐次実行しても結果は変わらない。

| 終了コード / `error.code` | dfy が行ったこと | オーケストレーターの動作 |
|---|---|---|
| 0 | 実行・検証・記録 | 次へ |
| 5 `QUOTA_LIMIT_REACHED` | Job `queued`（`available_at = now + cooldown`）、Run `quota_paused` | 残る Job の起動をやめ、cooldown を転記して停止 |
| 5 `BUDGET_LIMIT_REACHED` | Run `budget_paused` | 同上 |
| 6 `EXECUTOR_ERROR`（retryable） | backoff 付きで `queued`、attempt 加算 | 次へ（次の `dfy next` が `available_at` 後に返す） |
| 6 `EXECUTOR_UNAVAILABLE` | Run `paused` | `dfy doctor` を実行し出力を転記して停止 |
| 7 `SCHEMA_INVALID` | 修復 2 回後も不適合。Job `failed`、Stage `needs_review` | `error` を転記して次へ |
| `INVARIANT_VIOLATION` / `PROMPT_INJECTION_SUSPECTED` | §4.3 と同じ | 同じ |
| 8 `LOCK_HELD` | — | 10 秒待って再試行（最大 3 回） |

### 4.5 停止条件と終了コード

| 条件 | 検知 | 動作 |
|---|---|---|
| human Stage（`evidence_review`、`decision_finalize`、`approval`、`experiment`） | `dfy next` / `dfy run resume` が終了コード 10（`AWAITING_HUMAN`。`error.details.stage_key`、`pending_items`、`action`） | `error.action` と `STATE.md` の「次の操作」を転記して停止。`/dfy-review <run_id> <stage>` を案内 |
| 利用枠 | 終了コード 5（`QUOTA_LIMIT_REACHED`。`details.executor`、`cooldown_until`） | executor 名と `cooldown_until` を転記して停止。「cooldown 後に `/dfy-run <run_id>` を再実行」と案内 |
| 予算 | 終了コード 5（`BUDGET_LIMIT_REACHED`。`details.scope`、`limit`） | 転記して停止。fork / 新 Run を案内 |
| executor 不在・認証切れ | 6 `EXECUTOR_UNAVAILABLE` | `dfy doctor` 出力を転記して停止 |
| journal 破損 | 9 `VERIFY_FAILED` | 転記して停止。何も変更しない |
| Stage `blocked` / `needs_review` のみ残る | `empty_reason: blocked` | 転記して停止。人間の `dfy requeue --by` / `dfy gate override --by` 待ち |
| Run 完了 | `empty_reason: completed` | `STATE.md` 要約と `FINAL.md` のパス（export 済みなら）を転記して停止 |
| lease 中の Job のみ残る | `empty_reason: waiting_in_flight` | `in_flight` を転記して停止（§5） |

`/dfy-run` は自分から待機（sleep によるポーリング）で cooldown や lease 失効を待たない。待つのは人間である。

## 5. lease と reaper（オーケストレーター視点）

store 側の規則は `ARCHITECTURE.md §4.2`。オーケストレーターが守ること:

- `dfy next` が返した Job には lease（TTL 30 分。`--lease-ttl` で変更可）が付いている。subagent の実行時間を lease で縛ることはできないため、TTL を超えた subagent の出力は `LEASE_EXPIRED` として扱われる（§4.3 の行）。web tool を使う Stage（`signal_scout`）は 10〜15 分かかり得るので、`dfy next` は lease TTL を `max(30 分, limits.timeout_s)` 以上にする（要求: `docs/CLI_SPEC.md`）。
- reaper は `dfy next` と `dfy run resume` の冒頭で動く。オーケストレーターは lease 失効を自分で判定せず、`dfy requeue` も呼ばない。
- `empty_reason: waiting_in_flight` は「前回の `/dfy-run`（別の会話）が dispatch した Job の lease がまだ有効」を意味する。オーケストレーターは待たずに停止し、`in_flight[]`（`job_id`、`lease_expires_at`）を転記する。人間は (a) 前回の subagent 出力が `output_path` にあるなら `dfy complete <job_id> --output <path>` を自分で実行する、(b) 無ければ lease 失効を待って `/dfy-run` を再実行する、(c) 急ぐなら `dfy requeue <job_id> --by <name> --reason …` する。
- 同一 Run で `/dfy-run` を 2 つの会話から同時に動かさない。`.lock` が `LOCK_HELD`（8）で守るが、lease の取り合いは無駄な待ちを生む。

## 6. 並列 fan-out

| Stage | fan-out 単位 | executor（既定） | 並列 |
|---|---|---|---|
| `evidence_verify` | Source snapshot ごと | codex | `dfy exec` × `max_parallel`（2） |
| `service_generate` | Opportunity ごと | claude-code subagent | subagent × `max_parallel`（4） |
| `referee_evidence` / `referee_commercial` / `referee_technical` | packet ごと × 3 Stage | codex / claude-code subagent / gemini-cli | 3 executor が同時に進む。同じ packet の 3 referee が同じループ内で起動されてよい（互いの出力は Request に含まれない） |
| `pairwise` | ペア（提示順入替 ×2）ごと | codex | `dfy exec` × 2 |
| `red_team_kill` → `red_team_improve` | Idea ごと。Improver は同じ Idea の Killer 完了後にのみ `dfy next` が返す | claude-code subagent | 4 |

- 並列度の上限は `executors.snapshot.yaml` の `capacity.max_parallel` であり、`dfy next --max N` が executor ごとに守る。オーケストレーターは `dfy next` が返した Job を全て起動するだけでよく、自分で本数を数えない。
- 起動順・完了順は結果に影響しない。`dfy complete` の順序も問わない（各 Job は独立に検証・記録され、集計は deterministic Stage が後で行う）。
- 同じ Stage の複数 subagent を 1 メッセージで起動する。1 体ずつ逐次起動しても正しいが遅い。

## 7. 失敗時の扱い（同じ request で再依頼のみ）

- 再依頼は常に**同じ `request.md`・同じ `output_path`・同じテンプレート**で行う。dfy が `## Repair <n>` 節を描画済みであり、それ以上の情報を足さない。IdeaForge の「同じ指示で出力の修正だけを依頼する。指示を足さない」を継承する。
- 再依頼の回数は dfy が数える（`max_schema_repairs`）。オーケストレーターは数えず、`retryable` に従う。
- `failed` / `dead` になった Job をオーケストレーターが復活させることはない。人間が `dfy requeue <job_id> --by <name> --reason …` するか、`dfy gate override` / `dfy evidence review` で入力を変える（`input_hash` が変われば新 Job になる。`ARCHITECTURE.md §4.3`）。
- 同じ `agent_key` が 3 回連続 `SCHEMA_INVALID` なら dfy が Stage を `blocked` にする（`ARCHITECTURE.md §4.4`、`docs/PIPELINE.md`）。オーケストレーターは `empty_reason: blocked` を転記して止まる。

## 8. 再開

- `/dfy-run <run_id>` を再実行すれば journal から続く。会話の履歴、前回の報告、`STATE.md` の内容は再開の入力ではない。
- `dfy run resume` の復旧規則（`job.succeeded` あり `entity.written` なし → 再適用、lease 失効 → requeue、holder 死亡 → requeue）は dfy が行う。`succeeded` Job は再実行されない（PRD AC-08）。
- `quota_paused` からの再開: cooldown 後に `/dfy-run` を再実行する。`dfy run resume` が cooldown 経過を判定する。
- snapshot（brief / rubric / executors / prompts / anchors）を変えた場合は `FORK_REQUIRED` で再開できない。人間が `dfy run fork` する。
- 実行形態の切替: 同じ Run を昼は `/dfy-run`（subagent）、夜は `dfy run auto`（headless）で進めてよいのは、`executors.snapshot.yaml` の claude-code `mode` が `headless` の Run だけである。`mode: subagent` の Run は `dfy run auto` では claude-code Job を実行しない（§11.3）。

## 9. 報告

オーケストレーターの報告は **`STATE.md` の転記**に限る（`docs/UI_UX.md §5` の節構成）。

- 転記する節: §1 Run ヘッダ、§3 Blocking items、§9 次の操作。停止理由が終了コード 10 / 5 / 6 の場合は `dfy` の `error.action` をその上に転記する。
- `STATE.md` のパスを必ず示す。`FINAL.md` は export 済みのときだけパスを示す。
- 書かないもの: 案の内容、講評、採点、順位の解釈、「良さそう」「有望」等の評価語、次に何を選ぶべきかの助言。IdeaForge の「上位 3 案のワンフレーズ + 勝ち数 + 構造タグのみ」より狭い。順位や案の要約が必要なら人間が `FINAL.md` / `dfy show` を読む。
- 途中停止（`waiting_in_flight`、`backoff`、`blocked`）でも同じ形式で報告する。

## 10. `/dfy-review`

### 10.1 目的と規則

human Stage の CLI 操作を対話で補助する。**判断は人間**であり、`/dfy-review` は (a) `dfy` の出力を表示し、(b) 人間の入力を CLI コマンドに組み立てて提示し、(c) 明示の確認後に実行する。

- 自分の評価・推奨・要約を述べない。表示するのは `dfy` の出力（`evidence_verifier` の `classification_recommendation`、`dfy gate show` の check 一覧、`dfy portfolio compute` の結果を含む）だけである。
- 書込コマンドは全て `--by <name>`（`dfy.config.yaml` の `operator_name` を既定、人間が上書き可）と `--reason "<人間が入力した文>"` を付ける。reason を代筆しない。
- 実行前に組み立てたコマンド全文を表示し、人間の「実行」の一言を待つ。「全部承認して」「残りは同じで」等の一括指示は、対象 ID を列挙して 1 件ずつ確認する。
- 実行後は `dfy` の出力（終了コードと `data` / `error`）を転記する。journal の `actor` は `{type: human, id: <--by>}` である。
- `/dfy-review` は human Stage 以外の状態を変えない。`dfy next` / `dfy exec` / `dfy complete` を呼ばない（それは `/dfy-run` の仕事）。

### 10.2 モード

| モード | 対象 Stage | 表示に使うコマンド | 提示する書込コマンド |
|---|---|---|---|
| `evidence` | `evidence_review` | `dfy evidence list --status proposed --json`、`dfy show E-NNN --json`（claim、locator、source、snapshot 抜粋、numeric 属性、injection flag） | `dfy evidence review E-NNN --action approve\|downgrade\|reject\|split\|conflict [--classification …] --by --reason` |
| `gate` | `hard_gate` の HOLD / FAIL の override | `dfy gate show I-NNN --json`（HG-01〜HG-15 の check、根拠、必要追加証拠） | `dfy gate override I-NNN --result PASS\|HOLD --expires-at --required-experiment --by --reason`（override 案は最終選定前に再 Gate される。`docs/EVALUATION.md`） |
| `decision` | `decision_finalize` | `dfy show D-S-NNN --json`、`dfy portfolio compute --json` の結果（selected / held / rejected と制約） | `dfy decision finalize --by --reason`。手動変更は `--select I-NNN` / `--hold I-NNN` 等（`docs/CLI_SPEC.md`）、理由必須 |
| `approval` | `approval` | `dfy approval list --status requested --json`（action type、payload hash、対象計画、PII 有無、費用） | `dfy approval approve\|reject APR-NNN --by --reason`、`dfy approval revoke` |
| `novelty` | `novelty` の人間確認 | `dfy show NC-NN --json`、`NL-NNN` | `dfy novelty review NL-NNN --verdict duplicate\|related\|distinct --by --reason` |
| `research` | HOLD 案の Research task | `dfy research list --json` | `dfy research resolve RQ-NNN --by --reason`（Evidence 追加は `dfy source add` → `dfy claim add / link`） |
| `experiment` | `experiment` | `dfy experiment show EXP-NNN --json` | `dfy experiment start\|event\|complete --by --reason` |

### 10.3 対話手順（`evidence` の例）

1. `dfy run status <run_id> --json` を表示し、`awaiting_human` かつ `stage_key = evidence_review` であることを確認する。違えば当該 Stage の案内を表示して終わる。
2. `dfy evidence list <run_id> --status proposed --json` を転記する（件数と ID）。
3. 人間が指定した ID（未指定なら先頭から順に）について `dfy show E-NNN --json` を転記する。表示項目: claim 文、`classification_recommendation`、confidence、Source（publisher、published_at、trust class）、locator と snapshot 抜粋、numeric 属性（unit / as_of / geography / denominator / formula）、support / refute link、injection flag。
4. 人間が action と reason を述べる。組み立てたコマンドを表示する。

   ```text
   dfy evidence review E-019 --action downgrade --classification ESTIMATE \
     --by mizuki --reason "該当ページの数値は推計値と明記されている"
   ```

5. 「実行」を受けて Bash 実行し、結果を転記する。終了コード 0 以外はそのまま表示し、次の ID へ進むかを聞く。
6. proposed が尽きたら `dfy run status --json` を表示し、「`/dfy-run <run_id>` で再開」を案内する。`dfy run resume` は呼ばない。

## 11. `dfy run auto`（headless ループ）

### 11.1 ループ

`dfy run auto <run_id>` は §4.2 と同じループを `dfy` 内部で回す。オーケストレーター（LLM）は介在しない。

```text
resume(run_id)                                  # 復旧 + reaper
loop:
  jobs = next(max = Σ max_parallel)
  if empty: break with empty_reason
  for job in jobs (executor ごとに max_parallel まで並列):
      if job.executor == claude-code && mode == subagent: stop(6)   # §11.3
      exec(job)                                  # 起動 → 取得 → 検証 → 修復 → 記録
  on QUOTA_LIMIT_REACHED: stop(5) or, if --wait-quota, sleep until cooldown_until then continue
  on BUDGET_LIMIT_REACHED: stop(5)
  on AWAITING_HUMAN: stop(10)
```

- headless の `claude-code` は `claude -p`（`--output-format json --json-schema … --disallowedTools "*"` 等。`docs/EXECUTORS.md`）で起動する。`--bare` は使わない（サブスク資格情報を読まない）。
- 引数は `docs/CLI_SPEC.md` が所有する。本書が要求するもの: `--max N`（1 ループの lease 上限）、`--wait-quota`（cooldown を待って続行。既定 off）、`--until <stage_key>`（当該 Stage 完了で終了コード 0）、`--json`（イベントを JSONL で stdout に流す）。
- 各 Job の開始・完了・失敗を 1 行ずつ stdout に出す（`docs/UI_UX.md §7` の端末出力標準）。journal の `actor.type` は `cli`。

### 11.2 停止条件・終了コード

| 条件 | 終了コード | 再開 |
|---|---:|---|
| human Stage に到達 | 10 `AWAITING_HUMAN` | 人間が CLI / `/dfy-review` で処理後、`dfy run auto` 再実行 |
| `QUOTA_LIMIT_REACHED`（`--wait-quota` なし） | 5 | cooldown 後に再実行 |
| `BUDGET_LIMIT_REACHED` | 5 | fork / 新 Run |
| `mode: subagent` の claude-code Job に遭遇 | 6 `EXECUTOR_UNAVAILABLE`（`action`: 「Claude Code 内で `/dfy-run <run_id>` を実行するか、`mode: headless` で `dfy run fork`」） | 案内どおり |
| `EXECUTOR_UNAVAILABLE`（CLI 不在・未ログイン） | 6 | `dfy doctor` → 再ログイン → 再実行 |
| `VERIFY_FAILED` | 9 | 人間が調査 |
| `LOCK_HELD` | 8 | 他プロセス終了後 |
| Stage `blocked` / `needs_review` のみ残る | 0（`empty_reason: blocked` を表示） | 人間が requeue / override |
| `--until` 到達、または Run `completed` | 0 | — |

### 11.3 human Stage での停止と再開

- `awaiting_human` は Run 状態であり、`dfy run auto` はそこで必ず止まる。夜間実行で人間の判断を飛ばす手段は無い（Evidence review、Decision finalize、Approval、Experiment 登録の 4 Stage）。
- 再開は `dfy run auto <run_id>` の再実行。`succeeded` Job は再実行されない。
- `mode: subagent` の Run を夜間に進めたい場合は、claude-code の Job が無い区間（例: `evidence_verify`（codex）、`referee_evidence`（codex）、`referee_technical`（gemini-cli）、`pairwise`（codex））だけ `dfy run auto` が進み、claude-code Job に当たった時点で 6 で止まる。翌朝 `/dfy-run` で続きを回す。この混在は journal 上区別され（`executor.mode`）、結果の形式は同じ（PRD AC-16）。

### 11.4 中断（SIGINT / SIGTERM）

新規 dispatch を止め、実行中の子プロセスを `timeout_s` まで待ってから終了する。待ちきれなかった Job は `running` のまま残り、次の `resume` の reaper が `holder_dead` で `queued` に戻す。journal に `note`（reason `interrupted`）を残す。

### 11.5 注意（サブスクリプションでの headless）

`claude -p` をサブスク資格情報で無人実行することは Claude Code 公式がスクリプト用途に推奨する形ではない（公式は API key を推奨）。Codex CLI も自動化には `CODEX_API_KEY` を推奨し、Gemini CLI は自動化トラフィックの優先度を下げる運用告知を出している。本人が自分のマシンで使う限り規約上の問題は想定しないが、**利用枠と規約は変わり得る**。`dfy doctor` が直近の `QUOTA_LIMIT_REACHED` 回数を表示し、`quota_paused` の頻発は `executors.yaml` の割当見直し（`docs/EXECUTORS.md`）の合図とする。方針は `docs/SECURITY_AND_RISK.md`。

## 12. slash command 本文の骨子

`dfy init` が生成する。`prompts/` とは独立で、`dfy sync-agents` の対象ではない。

### 12.1 `.claude/commands/dfy-run.md`

```markdown
---
description: dfy の状態機械に従い、Job を subagent / dfy exec で実行して complete する配達人。判断・要約・上書きをしない
---

あなたは Demand Foundry の**配達人（Courier）**です。引数: $ARGUMENTS（`<run_id> [--max N]`）。
以下の手順を正確に実行します。判断・要約・追加指示は一切しません。

# 越権禁止（最重要）

サブエージェントに渡してよいのは次の 3 行の prompt **のみ**です（値は `dfy next --json` の出力をそのまま使う）:

    Job {job_id}
    Read the request: {request_md}
    Write JSON only to: {output_path}

禁止: payload の要約・言い換え、採点姿勢の追加指示、特定案の名指し、dfy の判定の上書き・解釈、
referee / red team / evidence_verifier への順位・スコア・他評価者出力の提供、schema 不適合時の追加指示、
`stage-io/` `packets/` `pairs/` `*.jsonl` の読取、run directory への書込、
`dfy next` が返していない Job の起動、返した Job の未起動。
実行してよい dfy コマンド: run status / run resume / run list / next / exec / complete / state / show（JOB-NNNN のみ）/ doctor。
全て `--actor orchestrator --json` を付ける。他の dfy コマンドは実行しない。

# 状態管理

状態は dfy が journal に持ちます。あなたは何も記憶しません。中断後は本コマンドの再実行で続きます。

# 手順

1. `dfy run status <run_id> --json --actor orchestrator`。run_id が無ければ `dfy run list --json` を転記して停止。
2. `dfy run resume <run_id> --json --actor orchestrator`。終了コード 0 以外は error を転記して停止。
3. ループ:
   a. `dfy next <run_id> --max N --json --actor orchestrator`。
      終了コード 10 → 手順 4 へ。5 → error（cooldown / 上限）を転記して停止。8 → 10 秒後に再試行（最大 3 回）。
      `jobs` が空 → `empty_reason` と（あれば）`in_flight` / `next_available_at` を転記し手順 4 へ。
   b. `executor.name == "claude-code"` かつ `executor.mode == "subagent"` の Job は、
      subagent `dfy-{agent_key}` を上のテンプレートで**全て同時に**起動する。
   c. それ以外の Job は `dfy exec <job_id> --json --actor orchestrator` をバックグラウンドで起動し、完了通知を待つ。
   d. subagent が戻り次第 `dfy complete <job_id> --output <output_path> --json --actor orchestrator`。
      終了コード 7 で `retryable: true`（または output 欠落の 2）→ 同じテンプレート・同じパスで同じ subagent を再起動し、再度 complete。
      `LEASE_EXPIRED` → 次の next で同じ job_id が返ったら、起動せず同じ output_path で complete を先に試す。
      それ以外の非 0 → error を転記して次の Job へ。
   e. exec の終了コード 5 → 残りを起動せず error を転記して停止。6 EXECUTOR_UNAVAILABLE → `dfy doctor` を転記して停止。
      他の非 0 → error を転記して次へ。
   f. a へ戻る。
4. 報告: `<run_dir>/STATE.md` の「Run ヘッダ」「Blocking items」「次の操作」を**そのまま転記**し、STATE.md のパスを示す。
   停止理由が 10 / 5 / 6 のときは dfy の `error.action` を先頭に転記する。

# 注意

- 案の内容・講評・順位を要約・評価しない。報告は STATE.md の転記だけ。
- subagent の最終メッセージで成否を判断しない。成否は `dfy complete` が決める。
- sleep で cooldown や lease 失効を待たない。待つのは人間。
- 同じ Run を別の会話から同時に動かさない。
```

### 12.2 `.claude/commands/dfy-review.md`

```markdown
---
description: Evidence review / Gate override / Decision finalize / Approval / Novelty / Research / Experiment の CLI 操作を対話で補助する。判断は人間
---

あなたは Demand Foundry の**レビュー補助**です。引数: $ARGUMENTS（`<run_id> [evidence|gate|decision|approval|novelty|research|experiment] [ID…]`）。

# 規則

- 判断は人間が行う。あなたは dfy の出力を表示し、人間の入力をコマンドに組み立て、明示の確認後に実行する。
- 自分の評価・推奨・要約を述べない。表示は `dfy … --json` の出力の転記だけ。
- 書込コマンドには必ず `--by <name>`（既定: dfy.config.yaml の operator_name）と `--reason "<人間の言葉>"` を付ける。reason を代筆しない。
- 実行前にコマンド全文を表示し、「実行」の返答を待つ。一括指示は ID を列挙して 1 件ずつ確認する。
- `dfy next` / `dfy exec` / `dfy complete` / `dfy run resume` は呼ばない（/dfy-run の仕事）。

# 手順

1. `dfy run status <run_id> --json`。モード未指定なら `awaiting_human` の stage_key から選ぶ（evidence_review → evidence、decision_finalize → decision、approval → approval、experiment → experiment）。
2. 一覧: evidence → `dfy evidence list <run_id> --status proposed --json` / gate → `dfy gate show <run_id> --result HOLD,FAIL --json` /
   decision → `dfy show D-S-* --json` / approval → `dfy approval list <run_id> --status requested --json` /
   novelty → `dfy show NC-* --json` / research → `dfy research list <run_id> --json` / experiment → `dfy experiment show <id> --json`。
3. 各 ID: `dfy show <ID> --json` を転記し、人間の action と reason を待つ。
4. コマンドを組み立てて表示 → 「実行」→ Bash 実行 → 結果を転記。
5. 対象が尽きたら `dfy run status <run_id> --json` を表示し、`/dfy-run <run_id>` での再開を案内する。
```

## 13. 注意

- generator に採点をさせない。referee に案を出させない。オーケストレーターに判断をさせない。役割の混合はプール全体を凡庸にする（IdeaForge 原則 1・8）。v2 では役割の分離を prompt source と Request 描画が固定し、オーケストレーターの分離を Courier Rule が固定する。
- referee / red team / evidence_verifier に見せてよいのは dfy が描画した `request.md` だけである。順位・スコア・他評価者の出力・系譜が subagent の入力に入る経路をオーケストレーターが作ってはならない。
- `dfy` がエラーで止まった場合（schema 不適合、出力欠落、lease 失効）は、該当 subagent に**同じ request で**再依頼するだけである。指示を足さない。直らなければ人間の仕事である。
- `CLAUDE_CODE_SUBAGENT_MODEL` を設定したシェルで Claude Code を起動しない。全 subagent の model が上書きされ、`model_reported` が取れない subagent モードでは journal からも判別できない（`dfy doctor` が環境変数を検査する）。
- `/dfy-run` の報告に評価語を入れない。「有望」「弱い」の一語が次の human Stage の判断に漏れる。
- headless（`dfy run auto`）とサブスク資格情報の組合せは公式推奨外である（§11.5）。

## 14. 検証項目（Courier Rule テスト）

`docs/MVP_PLAN.md` / `docs/BACKLOG.md` の受け入れ試験に含める。

| # | 試験 | 期待 |
|---|---|---|
| OR-01 | mock executor の Run で `/dfy-run` を 1 周させ、subagent 起動 prompt を記録する | 全 prompt が §2.3 テンプレートと完全一致 |
| OR-02 | `dfy complete` が `SCHEMA_INVALID`（retryable）を返す fixture | 同じテンプレート・同じパスで再起動され、`request.md` の `## Repair 1` 以外に差分が無い |
| OR-03 | `/dfy-run` の途中で会話を切り、再実行 | `succeeded` Job が再実行されず、lease 失効 Job が requeue され、journal の seq が連続する |
| OR-04 | `dfy next` が終了コード 10 を返す fixture | `/dfy-run` が `error.action` と `STATE.md` の 3 節を転記して停止し、`dfy evidence review` 等を実行しない |
| OR-05 | `--actor orchestrator` で `dfy gate override` を実行 | `VALIDATION_ERROR` で拒否、journal に `incident` |
| OR-06 | `mode: subagent` の Run で `dfy run auto` | codex / gemini-cli Job のみ進み、claude-code Job で終了コード 6 と `/dfy-run` 案内 |
| OR-07 | `dfy run auto` 実行中に SIGINT | 実行中 Job が `timeout_s` まで待たれ、残りは次の `resume` で `queued` に戻る |
| OR-08 | referee 3 Stage を同一ループで起動 | 各 `request.json.payload` に他 referee の出力・順位・title が含まれない（packet leak validator が 0 件） |
