# PRD.md

設計版: design-v2.0.0 / 所有範囲: ユーザー、JTBD、機能要件、非機能要件、MVP 範囲、主要フロー、受け入れ条件（`docs/CONTRACTS.md` §17）

## 1. Product Summary

Demand Foundryは、根拠収集から市場検証、MVP候補選定、学習記録までを一つのRunとして管理する、証拠駆動型のAI事業創造OSである。v2.0.0 は **TypeScript の `dfy` CLI と run ディレクトリ**を唯一の正とし、LLM は API key ではなく**サブスクリプション CLI**（`claude-code` / `codex` / `gemini-cli`）をフェーズ別に使う。Claude Code 内では `/dfy-run` が配達人（Courier）としてサブエージェントを起動し、状態機械・検証・冪等性・記録は全て `dfy` CLI が持つ（`docs/CONTRACTS.md` §4）。

## 2. ユーザー

### P-01 Venture Operator

- 主利用者であり、v2 MVP では**唯一の利用者**。探索Briefを作成し、Runを開始し、証拠をレビューし、検証を実行する。
- 自分のマシンで `dfy` と各ベンダー CLI（ログイン済み）を使う。初期は創業者・新規事業担当・一人ベンチャースタジオを想定。

### P-02 Domain Reviewer

- 特定業界の証拠、規制、現場業務をレビューする。
- MVPでは export package（zip / Markdown）または静的 HTML report（P1）を読み、指摘は Operator が `dfy evidence review --by <name>` 等で代理記録する。閲覧権限の分離は Phase 3。

### P-03 Approver

- 外部連絡、顧客データ利用、支出を承認する。
- MVPでは Operator 本人。`dfy approval approve --by <name>` で承認者名と reason を journal に残す。ロール分離は Phase 3。

### P-04 Auditor / Investor

- どの証拠から何が生成され、なぜ落ち、何が市場で反証されたかを読む。
- export package と `dfy verify` の結果（hash chain、manifest）を読む。読み取り専用。

## 3. Jobs to be Done

1. 探索条件を機械可読なBriefへ変換したい。
2. 一次情報から変化を収集し、サービス案になる前のSignalとして保存したい。
3. 抽象的な社会課題を、特定担当者・特定業務・現在支出へ落としたい。
4. 支払者と代替手段が明確なOpportunityだけを残したい。
5. 構造の違う複数案を出し、類似言い換えを数えたくない。
6. Hard Gate、独立評価、Red Teamで弱い案を早く落としたい。
7. 完成品開発前に、行動証拠を得る最小実験を作りたい。
8. 顧客反応、データ提供、LOI、支払い、継続を記録したい。
9. 予測と実績の差から評価ルールを改善したい。
10. Runを再現・Resume・監査・エクスポートしたい。
11. 既に契約しているサブスクリプション CLI だけで、API key を新たに用意せずに Run を回したい。
12. Claude Code の中で Run を進め、利用枠に達したら止まり、後で続きから再開したい。

## 4. 機能要件

### 4.1 Run / Brief

| ID | 要件 | 優先度 |
|---|---|---|
| FR-001 | Brief入力（自由記述を含む `brief.yaml`）を `brief_compile` Stage で brief / rubric / constraints / search_queries の snapshot 候補へコンパイルする | P0 |
| FR-002 | Brief、Rubric、Prompts、Executors、Anchors を `dfy run new` 時に snapshot し、hash を `manifest.json` に記録する。Run 途中の変更は当該 Run に反映せず `dfy run fork` を要求する | P0 |
| FR-003 | Runに予算（`budget.requests`、optional `budget.usd`）、期限、対象地域、除外領域を設定する | P0 |
| FR-004 | `dfy run start / pause / resume / cancel / fork` で Run を操作する | P0 |
| FR-005 | Stage ごとの状態と進捗を `dfy run status`（`--json` 可）と projection `STATE.md`（`dfy state`）で表示する | P0 |

### 4.2 Source / Evidence

| ID | 要件 | 優先度 |
|---|---|---|
| FR-101 | URL、PDF、HTML、手動メモを `dfy source add / upload` で Source として登録し、`dfy source fetch` で snapshot を取得する（deterministic、LLM を使わない） | P0 |
| FR-102 | Source Snapshot（`snapshots/<source_id>/<content_hash>/`）に取得日時、hash、mime、publisher を保存する | P0 |
| FR-103 | Evidence Itemに抽出位置、要約、claim support/refuteを持たせる | P0 |
| FR-104 | FACTにはEvidence Linkを必須とする（`EVIDENCE_REQUIRED`） | P0 |
| FR-105 | 数値に単位、時点、地域、母数または式を要求し、dfy が再検算する | P0 |
| FR-106 | 反証、競合証拠、鮮度切れを `dfy evidence list` と report で表示する | P1 |
| FR-107 | Source内容を `untrusted_content` として Request 内で隔離し、命令として扱わない | P0 |

### 4.3 Signal / Problem / Opportunity / Idea

| ID | 要件 | 優先度 |
|---|---|---|
| FR-201 | Signalをサービス案ではなく変化カードとして生成する | P0 |
| FR-202 | Problemを5W1H、頻度、現行対処、支出、根本原因付きで生成する | P0 |
| FR-203 | Opportunityにuser/payer/decision maker/budget/alternativeを必須化する | P0 |
| FR-204 | 1Runで20件以上のIdea Cardを生成する | P0 |
| FR-205 | 発想構造を複数指定し、同じ構造の名称変更を抑制する | P0 |
| FR-206 | 出力 schema に合わない LLM 出力は `repairs/<n>.json` を付けて最大 2 回修復依頼し、なお不適合なら Job を failed にして人間レビューへ送る（エンティティ JSONL に追記しない） | P0 |
| FR-207 | IdeaのoriginからSignal/Problem/Evidence/Job/Model call へ遡れる | P0 |

### 4.4 Novelty Archive

| ID | 要件 | 優先度 |
|---|---|---|
| FR-301 | 顧客、課題、支払者、解決構造、データ、課金構造を正規化する | P0 |
| FR-302 | lexical + field overlap で類似候補を出す（`dfy novelty compute`、deterministic）。embedding は optional | P0 |
| FR-303 | 類似でも差分軸が明確なら別案として保持できる（`dfy novelty review --by`） | P0 |
| FR-304 | cluster_idとsimilar_idea_idsを `novelty.json` に保存する | P0 |

### 4.5 Gate / Evaluation / Red Team

| ID | 要件 | 優先度 |
|---|---|---|
| FR-401 | Hard Gate（HG-01〜HG-15、deterministic）をscore前に実行する | P0 |
| FR-402 | PASS/HOLD/FAIL とコード、根拠、必要追加証拠を `gates.jsonl` に保存する。override は `--by` と `reason` を必須にする | P0 |
| FR-403 | 生成元、title、過去順位、generator 情報を隠した評価 packet を作る（`blind_packet`、deterministic） | P0 |
| FR-404 | 商業・証拠・技術の独立評価を、それぞれ別 executor 割当で実行する | P0 |
| FR-405 | 同一案について評価者の分散（MAD、range、confidence 差）と根拠を `dfy eval show` で比較する | P0 |
| FR-406 | 上位案のペア比較を提示順入替 ×2 で実行し、勝ち数で順位、同数は加重合計でタイブレークする（`dfy pairs make / tally`、deterministic 集計） | P1 |
| FR-407 | Red Team KillerとImproverを別 Job・別 agent として実行する | P0 |
| FR-408 | fatal finding（S4）は総合点に関係なく FAIL へ戻し、material revision は再 Gate する | P0 |

### 4.6 Validation / MVP / Learning

| ID | 要件 | 優先度 |
|---|---|---|
| FR-501 | 上位3案に30日以内の検証計画を作る | P0 |
| FR-502 | success/hold/kill metricを必須にし、成功条件に行動証拠（Level 4 以上）を最低 1 つ含める | P0 |
| FR-503 | 行動証拠イベントを `dfy experiment event --by` で時系列に登録する | P0 |
| FR-504 | 外部行為を含む計画の実行登録前に Approval を要求する（`APPROVAL_REQUIRED`）。外部行為の実行機能は持たない | P0 |
| FR-505 | 検証通過案だけ `dfy mvp create` で MVP Project へ昇格できる（`VALIDATION_THRESHOLD_NOT_MET`） | P0 |
| FR-506 | 予測scoreと返信・紹介・データ・LOI・支払い・継続を `dfy learning snapshot` で比較する | P0 |
| FR-507 | ルール変更候補を `dfy learning propose` で作るが、自動適用しない | P0 |
| FR-508 | nが少ない場合（n < 30）に過剰最適化警告を出す | P0 |

### 4.7 Export / Audit / Cost

| ID | 要件 | 優先度 |
|---|---|---|
| FR-601 | Runを `dfy export` で Markdown / JSON / JSONL / zip へ export する | P0 |
| FR-602 | run directory の `manifest.json`（file inventory、snapshot hashes、`journal_head_hash`）を作り、`dfy verify` で検証する | P0 |
| FR-603 | LLM call ごとに executor、mode、`model_requested`、`model_reported`、usage（`known`、requests、tokens）、latency、`schema_valid`、`repair_count` を `model-calls.jsonl` に記録する。USD は cost table 設定時のみ推計する | P0 |
| FR-604 | Run / Stage / executor 別のリクエスト上限と `capacity` を停止条件に使う（`budget_paused`）。Gate FAIL 案に評価 call を出さない | P0 |
| FR-605 | status変更、手動編集、承認、override を append-only の `journal.jsonl`（hash chain）へ記録する。人間操作は `--by` と `reason` を必須にする | P0 |

### 4.8 Executor / Orchestration（新設）

| ID | 要件 | 優先度 |
|---|---|---|
| FR-701 | `executors.yaml` でフェーズ（stage_key）別に executor と model を割り当て、`dfy run new` で `executors.snapshot.yaml` に固定する。`capabilities_required` を満たさない割当は `CAPABILITY_MISSING` で拒否する | P0 |
| FR-702 | `dfy doctor` が各 CLI の存在・version・ログイン状態・capability・`executors.yaml` 整合・referee ベンダー分散・anchors の存在・`.claude/agents/` 生成物と prompt_hash の一致を診断する | P0 |
| FR-703 | 各 CLI の利用枠エラーを `QUOTA_LIMIT_REACHED` に正規化し、Job を `queued`（`available_at = now + cooldown`）へ戻し、Run を `quota_paused` にする。`dfy run resume` で再開し、`budget_paused` と区別して表示する | P0 |
| FR-704 | `mock` executor が fixture（v1 サンプル run）から応答を返し、外部ネットワークなしで Run を新規 run として再現する。Hard Gate PASS 5 / HOLD 8 / FAIL 7 と上位 3 案（I-001, I-003, I-010）が一致する | P0 |
| FR-705 | `dfy sync-agents` が `prompts/<agent_key>/` から `.claude/agents/dfy-<agent_key>.md` を再生成する。生成物の手編集は `dfy doctor` が検出する | P0 |
| FR-706 | `dfy complete` が subagent の出力ファイルを JSON 抽出・schema 検証（Zod）・不変条件検査し、`response.json` と `model-calls.jsonl` と journal を記録する。lease 期限切れ（`LEASE_EXPIRED`）と `idempotency_key` 不一致（`IDEMPOTENCY_CONFLICT`）は拒否する | P0 |
| FR-707 | `ANCHOR-WEAK` / `ANCHOR-STRONG` を全 referee バッチに匿名で混入し、`dfy eval aggregate` が総合点差を `evaluations.jsonl` に記録する。差 3.0 未満は referee run を `miscalibrated` として警告する。`policies.anchors: observe` では点数を変更しない | P0 |
| FR-708 | 3 referee のうち異なる executor が `referee_vendor_diversity_min`（既定 2）以上であることを `dfy doctor` と `dfy run start` で検査し、違反は start を拒否する | P0 |
| FR-709 | `dfy run auto` が headless ループ（`next` → `exec` → `complete`）を回し、human Stage で終了コード 10（`AWAITING_HUMAN`）で停止する。snapshot が `subagent` モードの claude-code Job は実行せず `/dfy-run` を案内して停止する（詳細は `docs/ORCHESTRATION.md`） | P0 |
| FR-710 | `/dfy-run` は Courier Rule に従う。サブエージェントへ渡すのは `request.md` のパス、`job_id`、`dfy` 出力の無改変転記のみとし、`request.md` 単体で Job を実行できるよう dfy が描画する。オーケストレーターの追加文脈・要約・判定上書きを前提にしない | P0 |
| FR-711 | `dfy anchors generate` が rubric ごとに anchors 2 packet を生成し、hash を `anchors.snapshot.json` に固定する。既存 anchors がある場合は明示指定なしに再生成しない | P0 |

## 5. 非機能要件

| ID | 要件 | 目標 |
|---|---|---|
| NFR-01 | 再現性 | prompt / rubric / executors / anchors / input / source snapshot と各 hash を追跡可能。同一 snapshot + mock executor で決定的に再現 |
| NFR-02 | 冪等性 | 同一 `idempotency_key` で重複 entity / Job を作らない。異なる payload は `IDEMPOTENCY_CONFLICT` |
| NFR-03 | Resume | CLI 中断後、journal から状態を再構築し lease 切れ Job から再開可能。succeeded Job を再実行しない |
| NFR-04 | 監査性 | 最終判断 → decision → evaluation → packet → evidence → source snapshot → model call へ逆引き可能。journal の hash chain を `dfy verify` で検証 |
| NFR-05 | セキュリティ | 各 CLI の資格情報は各 CLI が管理し dfy は保存・出力しない。run ディレクトリはファイル権限と git で保護。秘密情報を `stage-io/` と export に出力しない。Source 内容は `untrusted_content` として隔離（詳細は `docs/SECURITY_AND_RISK.md`） |
| NFR-06 | コスト・利用枠 | `budget.requests` の 90% で警告、100% 前に新規 call 停止（`budget_paused`）。`capacity` 到達・利用枠エラーで `quota_paused` |
| NFR-07 | 耐久性 | run ディレクトリが唯一の正。各コマンドは journal 追記後に終了し、クラッシュ時も journal 末尾までの状態を再構築できる。`.lock` で同一 Run の同時実行を防ぐ（`LOCK_HELD`） |
| NFR-08 | Schema | 全 LLM 出力を Zod で検証。JSON Schema は Zod から生成し同一性テストを行う。互換サブセット（`oneOf` 禁止等）を守る |
| NFR-09 | Performance | 20 案規模の Run で `dfy run status` / `dfy state` / `dfy show` は 2 秒未満、`dfy verify` は 10 秒未満。LLM Job は lease 付きの非同期実行 |
| NFR-10 | Explainability | gate / score / decision に reason と evidence refs 必須 |
| NFR-11 | Accessibility | 端末出力は状態を色だけで表さず記号・文字を併用し、`NO_COLOR` を尊重する。全コマンドに `--json` を用意する |
| NFR-12 | Internationalization | region / currency / jurisdiction / timezone をデータ化 |
| NFR-13 | 実行記録 | 全 model call に executor / mode / `model_requested` / `model_reported`（取得不能は `null`）/ `usage.known` を記録。subagent モードで usage 不明の場合は `requests = 1` で計上（`usage_unknown_policy`） |
| NFR-14 | 移植性 | Node 22+、macOS / Linux / WSL。単一 npm package、ネイティブ依存なし。run ディレクトリ内の参照は相対パス。各 CLI の `bin` は `executors.yaml` で差し替え可能 |
| NFR-15 | オフライン再現 | mock executor と fixture のみで、全 deterministic Stage と受け入れ試験が外部ネットワークなしで動く |

## 6. MVP範囲

### In Scope（Phase 1）

- `dfy` CLI（`docs/CONTRACTS.md` §12 の全コマンド。`dfy report` は P1）と Workspace（`dfy init`）
- executor: `claude-code`（subagent / headless）、`codex`、`gemini-cli`、`mock`
- `/dfy-run`（配達人）と `/dfy-review`（人間レビュー補助）
- Brief Compiler
- URL / PDF / 手動 Source 登録と snapshot
- Evidence 抽出・人手確認（CLI）
- Signal → Problem → Opportunity → 20 Ideas
- Novelty（lexical + field overlap）
- Hard Gate（15 規則）
- 3 referee（ベンダー分散）+ anchors 観測 + median/MAD 集計
- 上位案の pairwise と Red Team
- 上位3案の Validation Plan、Approval、Behavior Event 登録
- Portfolio 計算と人間による決定確定
- 予測と実績の比較（記述統計）
- Run Resume（journal + lease + idempotency）、quota / budget pause
- `model-calls.jsonl` / `journal.jsonl` / JSONL / Markdown / zip export と `dfy verify`
- mock executor による v1 サンプル run の再現

### Out of Scope

- Web UI（読み取り専用 viewer は Phase 2。静的 HTML report `dfy report` のみ P1 として In Scope）
- PostgreSQL（Phase 3 で run ディレクトリから import）
- API key を必須にする構成（headless の任意手段としてのみ許容）
- 自動メール送信、広告、契約、課金、その他の外部行為の実行（D-015 維持）
- 認証、RLS、マルチユーザー、共同編集（Phase 3）
- 複数 executor の自動ルーティング・フォールバック（割当は `executors.yaml` で明示）
- Agent SDK 組込み
- embedding による Novelty（optional。MVP 必須ではない）
- CRM 全機能、20 以上の業界テンプレート
- Temporal / Kafka 等の分散基盤
- モデル fine-tuning、自動ルール更新
- 全国サイトの常時クローリング、顧客本番データの常時同期

## 7. 主要フロー

LLM Job の実行主体は 2 通りある（`docs/CONTRACTS.md` §4）。人間 Stage と deterministic Stage の操作はどちらでも同じ。

| 形態 | 起動 | claude-code Job | codex / gemini-cli Job | 停止 |
|---|---|---|---|---|
| Claude Code 内 | `/dfy-run <run_id>` | `dfy next --json` の結果を受け、`dfy-<agent_key>` サブエージェントに `request.md` パスを渡して起動 → `dfy complete <job_id>` | オーケストレーターが Bash で `dfy exec <job_id>` | human Stage、`quota_paused`、`budget_paused` で報告して停止 |
| ターミナル | `dfy run auto <run_id>` | `claude -p`（`mode: headless`） | `dfy exec` | 同上。終了コード 10 / 5 |

以下、`[LLM]` は上記いずれかで実行される Job、`[dfy]` は deterministic 処理、`[人間]` は CLI で記録する人間操作を示す。コマンドの引数は `docs/CLI_SPEC.md` が所有する。

### Flow A: 新規Run

1. `[人間]` 初回のみ `dfy init` で Workspace を作り、`dfy doctor` で CLI のログイン・capability・referee ベンダー分散を確認する。anchors が無ければ `dfy anchors generate`。
2. `[人間]` `brief.yaml` を書き、`dfy run new`（`brief.yaml` を指定）で draft Run を作る。`brief_compile` Job が queued になる。
3. `[LLM]` Claude Code では `/dfy-run <run_id>`、ターミナルでは `dfy run auto <run_id>` が `brief_compile` を実行し、brief / rubric / constraints / search_queries の snapshot 候補を書く。
4. `[人間]` 候補を確認し、修正が要れば `brief.yaml` を直して再実行する。`dfy run start <run_id>` で snapshot と hash を固定する。start 時に capability と referee ベンダー分散を検査し、違反は拒否する。
5. `[dfy]` Stage DAG（`docs/PIPELINE.md`）に従い Job が queued される。`/dfy-run` または `dfy run auto` が `next → 実行 → complete` を繰り返す。

### Flow B: 証拠レビュー

1. `[LLM]` `signal_scout` が Signal 候補と Source 候補を出す。`[人間]` 追加の URL / ファイルは `dfy source add` / `dfy source upload` で登録する。
2. `[dfy]` `dfy source fetch` が snapshot を取得し、hash・mime・publisher を保存する（`source_snapshot`）。
3. `[LLM]` `evidence_verify`（codex）が extracted text から claim 候補と locator を抽出する。`[dfy]` 存在確認・数値属性検査・injection scan を行う。
4. `[dfy]` Run は `awaiting_human` になる（`evidence_review`）。`[人間]` `dfy evidence list`（proposed を表示）で確認し、`dfy evidence review <id>`（approve / downgrade / reject / split / conflict のいずれか。`--by <name>` と reason 必須）で判断を記録する。Claude Code では `/dfy-review` が CLI 呼び出しを補助するが、判断は人間が行う。
5. `[dfy]` 低信頼・矛盾は `contested` または Research task（`dfy research list`）へ。approved Evidence だけが `problem_mine` 以降の FACT として使われる。`[人間]` `dfy run resume`（または `/dfy-run` 再実行）で続行する。

### Flow C: 選定

1. `[LLM]` `problem_mine` → `opportunity_map` → `service_generate` → `business_model` が順に走り、20 件以上の Idea Card ができる。数値は dfy が再検算する。
2. `[dfy]` `dfy novelty compute` が cluster と差分軸を出す。`[人間]` 必要なら `dfy novelty review`。
3. `[dfy]` `dfy gate run` が PASS / HOLD / FAIL を出す。HOLD は Research task へ。override は `dfy gate override --by <name>`（reason 必須）で記録し、最終選定前に再 Gate する。
4. `[dfy]` `blind_packet` が PASS 案の packet を作る。`[LLM]` `referee_evidence`（codex）/ `referee_commercial`（claude-code）/ `referee_technical`（gemini-cli）が anchors 混入バッチを採点する。`[dfy]` `dfy eval aggregate` が median/MAD、disagreement、anchors 差を記録し、差 3.0 未満は `miscalibrated` を警告する。
5. `[dfy]` `dfy pairs make` が提示順入替 ×2 のペアを作る。`[LLM]` `pairwise_referee` が各ペアを判定。`[dfy]` `dfy pairs tally` が勝ち数で順位を決める。
6. `[LLM]` `red_team_kill` → `red_team_improve`。`[dfy]` fatal（S4）は FAIL、material revision は再 Gate。
7. `[dfy]` `dfy portfolio compute` が制約付きで上位 3 件と追加証拠候補を出す。`[人間]` `dfy decision finalize --by <name>` で確定する。

### Flow D: 市場結果

1. `[LLM]` `validation_design` が上位 3 案の 30 日以内検証計画（V-NNN）を作る。
2. `[人間]` 外部行為を含む計画は `dfy approval request` → `dfy approval approve --by <name>`（reason 必須）で承認を記録する。未承認のまま `dfy experiment start` は `APPROVAL_REQUIRED` で拒否される。
3. `[人間]` 人間が外部接触を行う。システムは送信・契約・決済を実行しない。
4. `[人間]` `dfy experiment start V-001` → `dfy experiment event --by` で行動イベントを時系列に登録 → `dfy experiment complete`。
5. `[dfy]` success / hold / kill を判定する。success のみ `dfy mvp create` が通る。
6. `[dfy]` `dfy learning snapshot` が予測と実績を比較し、`dfy learning calibration` / `propose` がルール変更候補を出す（自動適用しない）。`dfy export` で run package を作り、`dfy verify` で検証する。

## 8. MVP受け入れ条件

| AC | Given | When | Then |
|---|---|---|---|
| AC-01 | 有効なBrief | Run が `completed` | `ideas.jsonl` に schema valid な Idea Card が 20 件以上存在する |
| AC-02 | FACT claim に `evidence_id` と locator が無い | `dfy claim add` または `dfy complete` | `EVIDENCE_REQUIRED` / `VALIDATION_ERROR` で拒否され、JSONL に追記されない |
| AC-03 | payer 空欄 | `dfy gate run` | HG-02 が PASS にならず HOLD / FAIL になる |
| AC-04 | current alternative が空 | `dfy gate run` | HG-05 が HOLD / FAIL になる |
| AC-05 | 上位案 | `validation_design` 完了 | duration ≤ 30 日、success / hold / kill がすべてあり、成功条件に Level 4 以上の行動証拠が 1 つ以上ある。欠けると Job は succeeded にならない |
| AC-06 | 3 referee | `dfy eval show` | 個別 score、理由、confidence、executor、MAD、disagreement flag が比較できる |
| AC-07 | 類似案 | `dfy novelty compute` | `novelty.json` に cluster と差分軸が記録される |
| AC-08 | CLI 中断で dispatched Job の lease が失効 | `dfy run resume` | succeeded Job を再実行せず、lease 切れ Job が `queued` に戻り、未完了から続く。journal の seq と hash chain が連続する |
| AC-09 | LLM call | `dfy complete` / `dfy exec` 完了 | `model-calls.jsonl` に executor / mode / `model_requested` / `model_reported` / `prompt_hash` / `input_hash` / `output_hash` / usage / latency が残る |
| AC-10 | 行動結果 | `dfy experiment event` 登録 | `predictions.jsonl` の predicted score と event を同一 `idea_id` で `dfy learning snapshot` が比較できる |
| AC-11 | Run 完了 | `dfy export` | `export/<export_id>/` に zip と manifest、`FINAL.md` が生成され、`dfy verify` が終了コード 0 を返す |
| AC-12 | fatal Red Team（S4） | `dfy portfolio compute` | score が高くても `selected` にならない |
| AC-13 | `budget.requests` 超過見込み | `dfy next` | Job を dispatch せず Run が `budget_paused` になり、終了コード 5（`BUDGET_LIMIT_REACHED`）を返す |
| AC-14 | Source 本文に命令文 | `signal_scout` / `evidence_verify` | 本文は `untrusted_content` に隔離され、tool 実行や system prompt の変更が起きない。検出時は `PROMPT_INJECTION_SUSPECTED` が記録される |
| AC-15 | Approval 未承認 | 外部行為を含む計画で `dfy experiment start` | 終了コード 4（`APPROVAL_REQUIRED`）を返し、experiment は開始されない |
| AC-16 | 同一 Stage の Job を `claude-code`（subagent）と `codex` で実行 | `dfy complete` | `response.json` とエンティティレコードが同一 schema で書かれ、差分は `executor` / `model_*` / `usage` / `session_id` フィールドのみ。後続 Stage は executor に依存しない |
| AC-17 | 利用枠エラー発生 | `quota_paused` → cooldown 後 `dfy run resume` | Run は `budget_paused` ではなく `quota_paused` になり、resume 後に succeeded Job は再実行されず `queued` Job のみ再開する |
| AC-18 | subagent が schema 不適合 JSON を `output_path` に書いた | `dfy complete` | Job は succeeded にならず `repairs/<n>.json` が生成され再依頼される。`max_schema_repairs`（2）超過で終了コード 7（`SCHEMA_INVALID`）、Job は failed、エンティティ JSONL に追記されない |
| AC-19 | referee バッチで ANCHOR-STRONG − ANCHOR-WEAK < 3.0 | `dfy eval aggregate` | 当該 referee run に `miscalibrated` 警告が付き、`evaluations.jsonl` に anchors 観測が記録される。`policies.anchors: observe` では score は変わらない |
| AC-20 | `executors.yaml` で 3 referee が同一 executor（`referee_vendor_diversity_min: 2`） | `dfy run start` | start が拒否され、`VALIDATION_ERROR` の details に `referee_vendor_diversity_min` 違反が示される。`dfy doctor` も事前に警告する |

## 9. 製品分析イベント

v2 では分析イベントを外部送信しない。journal（`docs/CONTRACTS.md` §11.2）から `dfy state` / `dfy report` が派生集計する。監査ログ（journal）は完全性、分析イベントはプロダクト改善を目的とし、分析イベントは監査ログを書き換えない。

- `run_created`, `run_started`, `stage_started`, `stage_completed`, `stage_failed`
- `evidence_approved`, `evidence_rejected`, `claim_downgraded`
- `idea_generated`, `idea_clustered`, `hard_gate_failed`
- `evaluation_completed`, `anchor_miscalibrated`, `red_team_fatal_found`
- `validation_plan_approved`, `behavior_event_recorded`
- `idea_promoted`, `idea_killed`, `mvp_project_created`
- `rule_change_proposed`, `rule_change_approved`
- `budget_warning`, `budget_paused`, `quota_paused`, `schema_repair`, `executor_unavailable`, `run_exported`
