# UI_UX.md

設計版: design-v2.0.0 / 所有範囲: 端末・Markdown・Claude Code 上の体験、`STATE.md` / `FINAL.md` / `report.html` の構成、各 v1 画面の置換先、レビュー動線、状態表示標準、エラー文標準、空状態標準

語彙・状態名・コマンド名・終了コードは `docs/CONTRACTS.md` に従う。各コマンドの引数と出力の完全形は `docs/CLI_SPEC.md`、`/dfy-run` と `/dfy-review` の手順は `docs/ORCHESTRATION.md`、レコードのフィールドと export 形式は `docs/DATA_MODEL.md` が所有する。

## 1. UX 原則

v1 の 6 原則を維持し、v2 の実行基盤に合わせて 4 つを足す。

1. 華美さより、証拠・仮定・失格理由・次の行動を優先する。
2. 色だけで状態を表さず、文字ラベルを必須にする。端末では色は補助であり、`NO_COLOR` を尊重する。
3. `FACT / ESTIMATE / ASSUMPTION / HYPOTHESIS / UNKNOWN` を常時表示する。
4. score は根拠を折り畳まない。score → evaluation → packet → evidence → source snapshot → model call を ID で辿れる（`dfy show <ID>`）。
5. AI が自動確定したように見せない。`generated`（LLM 出力が schema を通過）/ `verified`（dfy の決定的検査を通過）/ `human-approved`（`--by` 付き journal レコードがある）を分けて表示する。
6. 破壊的操作と外部行為は二段階（Approval オブジェクト + 人間の実行）。システムは外部行為を実行しない。
7. **Markdown と端末が UI である。** 状態は `STATE.md`、結果は `FINAL.md`、詳細は `dfy show`、全コマンドに `--json`。Web は Phase 2 の読み取り専用 viewer まで作らない（`docs/ARCHITECTURE.md §11`）。
8. **projection は結果であって入力ではない。** `STATE.md` / `FINAL.md` / `costs.json` は `dfy` が再生成する。手編集は `dfy verify` が警告する。
9. **オーケストレーターは配達人。** `/dfy-run` の報告は `STATE.md` の転記であり、案の評価語を含まない。`/dfy-review` は dfy の出力を表示しコマンドを組み立てるだけで、判断を述べない。
10. **利用枠と予算を別物として見せる。** `quota_paused`（利用枠。待てば戻る）と `budget_paused`（上限。fork が要る）を同じ「停止」に丸めない。

## 2. 役割

v2 MVP は**単一運営者**である。権限分離は Phase 3（`docs/ARCHITECTURE.md §11.3`）。監査は `--by <name>` と `reason` で行う。

| v1 role | v2 | 監査上の識別 |
|---|---|---|
| owner / operator | 運営者本人。全コマンドを実行できる | `dfy.config.yaml` の `operator_name` が `--by` の既定値 |
| reviewer（Domain Reviewer） | export package / `report.html` を読み、指摘は運営者が代理で記録する | `--by <reviewer_name> --reason "…"` で journal に名前を残す（`actor.type=human`、`id=<name>`） |
| approver | 運営者本人 | `dfy approval approve --by <name>`。名前を分けることで「誰が承認したか」を残す |
| viewer（Auditor / Investor） | export package、`FINAL.md`、`dfy verify` の結果を読む。読み取り専用 | — |

- 人間操作の全コマンドは `--by` を必須にする（`CONTRACTS.md §11.2`、INV-7）。省略時は `operator_name` を使い、`operator_name` も無ければ `VALIDATION_ERROR`。
- `--by` は認証ではない。ファイル権限と git で run directory を守る（`docs/SECURITY_AND_RISK.md`）。

## 3. 画面の置換

v1 の global navigation を v2 の表面に置き換える。表面は 5 種類: (a) `STATE.md` の節、(b) `dfy show` / `dfy state` / 各 list コマンドの出力、(c) `/dfy-review` の対話、(d) `FINAL.md`、(e) `report.html`（P1）。

| v1 画面 | v2 表面 | 主コマンド |
|---|---|---|
| Dashboard | `STATE.md` §1〜4、§9 | `dfy run status` |
| Runs | `dfy run list` / `dfy run status`、`STATE.md` §1〜2 | `dfy run *` |
| Evidence Library | `dfy evidence list`、`dfy show E-/C-/SRC-`、`/dfy-review evidence` | `dfy evidence review` |
| Signals / Problems / Opportunities | `dfy show S-/P-/O-`、各 JSONL | `dfy research *` |
| Ideas | `STATE.md` §5、`dfy show I-NNN` | `dfy gate *`、`dfy novelty *` |
| Evaluations | `STATE.md` §6・§10、`dfy eval show` | `dfy eval aggregate`、`dfy pairs *` |
| Red Team | `STATE.md` §7、`dfy show RT-NNN` | `dfy gate override` |
| Validation Experiments | `STATE.md` §8、`dfy experiment show`、`/dfy-review approval|experiment` | `dfy approval *`、`dfy experiment *` |
| MVP Projects | `dfy show MVP-NNN`（ASSUMPTION: ID 形式。§9.11） | `dfy mvp create` |
| Portfolio | `dfy show D-S-NNN`、`/dfy-review decision`、`FINAL.md` | `dfy portfolio compute`、`dfy decision finalize` |
| Learning | `learning/` 配下、`dfy learning *` の出力 | `dfy learning *` |
| Prompt / Rubric Versions | `prompts/<agent_key>/meta.yaml`、`rubric.yaml`、`anchors/`、`executors.yaml`、各 snapshot、git log | `dfy sync-agents`、`dfy anchors generate`、`dfy doctor` |
| Cost Dashboard | `STATE.md` §4、`costs.json`、`dfy show MC-NNNN` | `dfy run pause`、`dfy run fork` |
| Audit Log | `journal.jsonl`、`dfy verify` | `dfy verify`、`dfy export` |

## 4. 端末出力の標準

- **ヘッダ行**: Run を扱うコマンドは先頭に 1 行 `run-2026-09-04-01  status: running  stage: referee_commercial (12/15 succeeded)  requests: 212/600 (35%)` を出す。
- **表**: ID を第 1 列、状態を第 2 列に置く。幅 100 桁を超える長文は `…` で切り、全文は `dfy show <ID>` で見せる。
- **状態語**: 状態は `CONTRACTS.md §11.1` の語をそのまま出す（`quota_paused` を「停止中」と訳さない）。記号を添える場合も語を省かない（§11）。
- **時刻**: ファイルは ISO 8601 UTC。端末は `dfy.config.yaml` の `timezone` で表示し、オフセットを添える（`2026-09-05 10:12 +09:00`）。
- **数値**: 通貨は `JPY 300,000` の形。USD 推計は必ず `推計` を付け、cost table が無ければ `—` を出す。usage 不明は `usage: unknown (1 request)`。
- **`--json`**: 全コマンドに用意し、`{ "data", "meta" }` / `{ "error": { code, message, details, retryable, action } }`（`CONTRACTS.md §12`）。人間向け出力とフィールドの意味を一致させる。
- **終了コード**: 非 0 のときは最終行に `exit 5 (QUOTA_LIMIT_REACHED)` を出す。
- **進行行**（`dfy run auto`、`dfy exec`）: 1 Job 1 行。`[10:12:03] JOB-0031 referee_commercial claude-code/sonnet started` → `[10:12:45] JOB-0031 succeeded (42s, repairs 0, usage unknown)`。
- **`dfy show <ID>`**: 見出し行（ID、種別、version、状態、`generated` / `verified` / `human-approved`）→ 本文（schema の順）→ 参照（`evidence_ids`、`job_id`、`call_id`）→ 履歴（journal の該当レコード）。Idea では score より先に Gate 結果・最大不確実性・次の行動を出す（§9.7）。
- **色**: PASS / FAIL 等に色を付けてよいが、`NO_COLOR` または `--no-color` で無色にし、文字情報を落とさない。

## 5. `STATE.md` の節構成

`dfy state` が journal と JSONL から再生成する projection。`store.commit()` の後に自動更新される（`docs/ARCHITECTURE.md §4.1`）。節番号・見出し・表の列は固定し、`/dfy-run` の報告は §1・§3・§9 をそのまま転記する（`docs/ORCHESTRATION.md §9`）。

```markdown
# STATE.md — run-2026-09-04-01

<!-- projection. generated by dfy state 2.0.0 at 2026-09-05T01:12:03Z. 手編集禁止（dfy verify が警告） -->

## 1. Run ヘッダ

| 項目 | 値 |
|---|---|
| run_id | run-2026-09-04-01 |
| status | running |
| mode | interactive（最終 dispatch: /dfy-run）/ fixture: no |
| design_version / dfy | design-v2.0.0 / 2.0.0 |
| brief · rubric · executors · prompts · anchors | sha256:3f1a… · sha256:9c02… · sha256:71de… · sha256:a4b8… · sha256:e0c1… |
| parent_run_id | — |
| created / updated | 2026-09-04T09:00:00Z / 2026-09-05T01:12:03Z |
| journal | seq 412, head sha256:5aa1… |
| lock | none |
| 現在 Stage | referee_commercial（12/15 succeeded） |
| 完了条件 | 未達（decision_finalize 未実施） |

## 2. Stage 台帳

| # | stage_key | kind | status | jobs q/d/r/s/f/dead | executor / model | started | finished |
|---:|---|---|---|---|---|---|---|
| 0 | brief_compile | llm | [x] passed | 0/0/0/1/0/0 | claude-code subagent / sonnet | 09-04 09:01 | 09-04 09:03 |
| 4 | evidence_review | human | [x] passed | — | human: mizuki | 09-04 10:20 | 09-04 11:05 |
| 13 | referee_commercial | llm | [>] running | 0/2/0/12/1/0 | claude-code subagent / sonnet | 09-05 00:40 | — |
| 20 | decision_finalize | human | [ ] pending | — | human | — | — |
（全 27 Stage を #順に。skipped は [-]）

## 3. Blocking items

- [!] needs_review JOB-0031 referee_commercial — SCHEMA_INVALID ×3（repairs 2）→ `dfy requeue JOB-0031 --by <name> --reason "…"`
- [!] contested E-019 — 反証 C-014 と衝突 → `/dfy-review run-2026-09-04-01 evidence E-019`
- [!] quota codex — cooldown_until 2026-09-05T01:40:00Z（QUOTA_LIMIT_REACHED ×1）
- dead jobs: none / dispatched（lease 中）: JOB-0033, JOB-0034（expires 01:42Z）

## 4. 容量・予算

| executor | requests used / max | in_flight / max_parallel | QUOTA events | cooldown_until |
|---|---:|---:|---:|---|
| claude-code (subagent) | 118 / 400 | 2 / 4 | 0 | — |
| codex | 61 / 300 | 0 / 2 | 1 | 01:40Z |
| gemini-cli | 33 / 300 | 0 / 2 | 0 | — |

| budget | used / limit | 状態 |
|---|---:|---|
| budget.requests (run) | 212 / 600 (35%) | normal |
| budget.requests (stage: referee_*) | 45 / 90 | normal |
| budget.usd | — | cost table なし（推計不可） |

（90% 以上の行には `warning`、100% で `budget_paused` を表示）

## 5. Idea 一覧

| idea | v | one-liner | cluster | gate | final | pairwise | status | largest unknown |
|---|---:|---|---|---|---:|---|---|---|
| I-001 | 2 | 空家差分キュー | NC-01 | PASS | 65.8 | 7-1 (1位) | red_teamed | 受託会社が 30 万円の試行に支払うか |
| I-005 | 1 | 汎用空き家 AI 推定 | NC-01 | FAIL (HG-07) | — | — | rejected | — |
（全 Idea。gate は結果 + fatal コード。final は aggregate + pairwise 補正 + red team 減点後） 

## 6. 評価

| idea | referee_evidence (codex/gpt-5.5) | referee_commercial (claude-code/sonnet) | referee_technical (gemini-cli/pro) | median | MAD | disagreement | anchors |
|---|---:|---:|---:|---:|---:|---|---|
| I-001 | 6.1 | 6.4 | 7.0 | 6.4 | 0.3 | economic_value (range 3–7) | ok |
| I-003 | 5.8 | 6.0 | — (dispatched) | — | — | — | EV-007 miscalibrated |
（criterion 別の内訳は `dfy eval show I-NNN`）

## 7. Red Team

| idea | findings S1/S2/S3/S4 | fatal | resolved | revision | re-gate |
|---|---|---|---|---|---|
| I-001 | 2/1/1/0 | no | 4/4 | v2 | PASS |
| I-010 | 1/2/0/1 | yes (RT-006) | 3/4 | — | FAIL |

## 8. Validation

| plan | idea | biggest uncertainty | approval | experiment | day | events (L4+) | verdict |
|---|---|---|---|---|---:|---:|---|
| V-001 | I-001 | 有料試行への支払意思 | APR-001 requested | — | — | 0 | — |

## 9. 次の操作

1. `dfy requeue JOB-0031 --by <name> --reason "…"`（schema 不適合 ×3 の referee_commercial）
2. `/dfy-review run-2026-09-04-01 evidence E-019`（contested）
3. 01:40Z 以降に `/dfy-run run-2026-09-04-01`（codex cooldown）

## 10. アンカー観測

| referee run | stage | executor / model | ANCHOR-WEAK | ANCHOR-STRONG | gap | flag |
|---|---|---|---:|---:|---:|---|
| EV-004 | referee_evidence | codex / gpt-5.5 | 2.4 | 7.9 | 5.5 | ok |
| EV-007 | referee_commercial | claude-code / sonnet | 4.1 | 6.8 | 2.7 | miscalibrated (< 3.0) |
（policies.anchors: observe。点数は変更していない）

## 11. 実際に使った executor / model

| stage_key | executor | mode | model_requested | model_reported | requests | usage known | repairs | schema valid |
|---|---|---|---|---|---:|---|---:|---|
| signal_scout | claude-code | subagent | opus | unknown | 6 | 0/6 | 0 | 6/6 |
| evidence_verify | codex | headless | gpt-5.5 | gpt-5.5 | 24 | 24/24 | 2 | 22/24 |
| referee_technical | gemini-cli | headless | pro | gemini-2.5-pro | 15 | 15/15 | 3 | 15/15 |
（環境: CLAUDE_CODE_SUBAGENT_MODEL = unset（dfy doctor 2026-09-04T09:00Z））

## 12. Caveat

Source 事実は snapshot と locator を持つ approved Evidence に基づく。価格、顧客数、削減率、粗利、販売期間は ESTIMATE / ASSUMPTION / HYPOTHESIS であり実績ではない。本ファイルは projection であり、正は journal.jsonl と各 JSONL である。
```

規則:

- §1〜§4 と §9 は常に出す。§5〜§8、§10〜§11 は該当レコードが無ければ「（なし）」の 1 行にする。
- §3 の各行は `[!] <種別> <ID> — <原因> → <次の操作コマンド>` の形にし、§9 と同じコマンドを使う。
- §9 は実行可能なコマンドのみを書く（人間が貼り付けて実行できる）。`<name>` はそのまま置き、reason は空にしておく。
- §11 の `model_reported` は subagent モードで必ず `unknown`。`CLAUDE_CODE_SUBAGENT_MODEL` が設定されていた場合は `WARNING` を添える。
- 評価語（有望、弱い、面白い）を含めない。

## 6. `FINAL.md` の構成

`dfy export` が `decisions.jsonl`（finalized）と参照先レコードから決定的に生成する。LLM は関与しない（v1 A-20 Exporter は deterministic 処理へ移行）。`decision_finalize` 前は生成しない（export は `STATE.md` のみを含む）。v1 サンプル `FINAL.md` の節を維持し、v2 で 3 節を足す。

| # | 節 | 出所 | 規則 |
|---:|---|---|---|
| 0 | 判定範囲 | `brief.snapshot.yaml`、`decisions.jsonl` の scope 文 | 固定文 + Run の `mode`（fixture / 実 Run）、外部行為の有無 |
| 1 | 確認された事実 | `claims.jsonl`（FACT、approved）と `evidence.jsonl` | 1 行 1 事実、末尾に `[E-NNN]`。推論部分は「推論」と明記 |
| 2 | Hard Gate 結果 | `gates.jsonl` | PASS / HOLD / FAIL の件数と主な理由（check code 別の集計） |
| 3 | 検証へ送る上位案 | `decisions.jsonl`（selected）、`ideas.jsonl`（current version）、`evaluations.jsonl`、`pairs/final-ranking.json`、`red-team.jsonl`、`validation-plans.jsonl` | 順位は `final-ranking.json` が正。各案: 一言、利用者、payer 仮説、予算仮説、current alternative、選定理由（decision record の `reason`）、Red Team で修正した点（resolved findings の転記）、最大不確実性、成功 / kill 条件。数値に分類ラベルを付ける |
| 4 | 選ばなかった重要案 | `decisions.jsonl`（held / rejected）、`gates.jsonl` | Gate コードまたは decision reason を 1 行で |
| 5 | 市場規模・価格の扱い | `claims.jsonl`（ESTIMATE / ASSUMPTION） | 固定文 + 置き換え手順（validation plan の該当項目） |
| 6 | 次の 30 日 | `validation-plans.jsonl`（selected 案） | plan の手順を番号付きで転記。承認が要る手順に `[APPROVAL: action_type]` |
| 7 | Final decision | `decisions.jsonl` の finalize レコード | 判断文、`--by` 名、時刻、reason。「市場検証へ進める / 開発へは進めない」の別を明記 |
| 8 | 評価者と executor（v2 新設） | `executors.snapshot.yaml`、`model-calls.jsonl` | referee 3 Stage の executor / model、ベンダー数、pairwise の executor、Red Team の executor |
| 9 | アンカー観測（v2 新設） | `evaluations.jsonl`（anchors 行） | `STATE.md` §10 と同じ表。`miscalibrated` があれば当該 referee run を明記 |
| 10 | 監査情報（v2 新設） | `manifest.json`、journal | `design_version`、snapshot hash 5 つ、`journal_head_hash`、seq、export_id、`dfy verify` の結果、生成時刻 |

規則: 順位変更・主張の追加・監査結果の要約をしない（IdeaForge finalizer の禁止事項を deterministic 処理として実装する）。レコードの文をそのまま転記し、ID 参照を落とさない。

## 7. `/dfy-review` の動線

手順の所有は `docs/ORCHESTRATION.md §10`。UX として守ること:

- 1 件ずつ表示し、1 件ずつ確認する。一括承認の UI を作らない。
- 表示順は固定: ID と状態 → claim / 対象 → `classification_recommendation` または dfy の判定 → 根拠（Source、locator、snapshot 抜粋、numeric 属性）→ 反証 / 衝突 → 提案コマンド。
- 提案コマンドは全文を表示し、人間が「実行」と言うまで実行しない。reason は人間の言葉をそのまま入れる。
- 実行結果は dfy の出力を転記する。成功しても「承認されました」等の言い換えをせず、journal seq と `--by` 名を示す。
- 端末で同じことを直接行える（`dfy evidence review …`）。`/dfy-review` は入力の補助であり、必須経路ではない。

## 8. `report.html`（P1）

- `dfy report` が `export/report.html` を生成する。単一ファイル、外部リクエストなし、JavaScript は折り畳みと目次のみ。`dfy export` は最新の `report.html` を package に含める。
- 構成: `STATE.md` の全節 → `FINAL.md` の全節 → エンティティ索引（Idea / Evidence / Source / Evaluation / Red Team / Validation / Decision / Approval を ID 順）→ journal 抜粋（human と incident のみ）→ manifest。
- 各 ID はページ内リンク。score は必ず evidence ID へのリンクを持つ（原則 4）。
- 分類ラベル・状態語は §12 と同一の文字列。色は補助。ダークテーマ非対応でよい（印刷を想定）。
- 読み取り専用。フォーム・ボタンを置かない。レビュー操作は CLI と `/dfy-review`（`docs/ARCHITECTURE.md §11.2`）。
- 想定読者: Domain Reviewer、Auditor / Investor（PRD P-02 / P-04）。

## 9. 各画面の定義

v1 §4〜§19 の 16 画面を v2 表面で定義する。「操作」は人間が実行するコマンド。LLM Stage の実行は全て `/dfy-run` / `dfy run auto` であり各画面の操作には含めない。

### 9.1 Dashboard

| 項目 | v2 |
|---|---|
| 目的 | 現在の Run、詰まり、利用枠・予算、次の human action を一目で把握 |
| 表示 | `STATE.md` §1（ヘッダ）、§2（Stage 台帳）、§3（Blocking items）、§4（容量・予算）、§9（次の操作）。`dfy run status` は §1 + §3 + §9 の短縮版 |
| 操作 | `dfy run new` / `dfy run start` / `dfy run resume` / `/dfy-run` / `/dfy-review` |
| 状態 | Run 状態（`RunStatus`） |
| エラー | projection 再生成失敗は §番号ごとに `（生成失敗: <error.code>）` を出し、他節は出す |
| 空状態 | Run が無い: 「`brief.yaml` を書き `dfy run new` を実行」 |

### 9.2 Runs

| 項目 | v2 |
|---|---|
| 目的 | Run 一覧と再現・fork・resume |
| 表示 | `dfy run list`: run_id、brief summary、status、現在 Stage、Idea 数、requests、created / updated、parent_run_id。`dfy run status <run_id>`: `STATE.md` §1〜§3 |
| 操作 | `dfy run new` / `start` / `pause` / `resume` / `fork` / `cancel` / `dfy export` / `dfy verify` |
| 状態 | `draft → ready → running → paused / quota_paused / budget_paused / awaiting_human → completed / failed / cancelled` |
| エラー | `FORK_REQUIRED`（snapshot 変更）、`LOCK_HELD`、`VERIFY_FAILED`、`BUDGET_LIMIT_REACHED`、`CAPABILITY_MISSING`（start 時）、`referee_vendor_diversity_min` 違反 |
| 空状態 | `runs/` が空: `brief.yaml` の雛形パスを示す |

### 9.3 Evidence Library

| 項目 | v2 |
|---|---|
| 目的 | Source、Evidence、Claim の支持関係を確認し review する |
| 表示 | `dfy evidence list [--status]`、`dfy show E-NNN`（claim、classification、recommendation、confidence、Source の class / publisher / date / 鮮度、locator と snapshot 抜粋、support / refute link、numeric 属性、injection / quarantine flag）、`dfy show SRC-NNN` / `C-NNN`、`/dfy-review evidence` |
| 操作 | `dfy evidence review --action approve\|downgrade\|reject\|split\|conflict --by --reason`、`dfy claim add / link`、`dfy source add / fetch / upload`（re-fetch は `fetch`） |
| 状態 | `proposed → approved / contested / rejected / stale / superseded`（`ReviewStatus`） |
| エラー | Source unavailable（`NOT_FOUND`）、抽出品質低（`extraction_quality` を表示し Evidence を `proposed` のまま保留）、locator drift（再 fetch で hash 変化。`stale`）、`PROMPT_INJECTION_SUSPECTED`（quarantine 表示） |
| 空状態 | 「`dfy source add <url>` または `dfy source upload <file>` で Source を登録」 |

### 9.4 Signals

| 項目 | v2 |
|---|---|
| 目的 | サービス案になる前の変化を確認する |
| 表示 | `dfy show S-NNN`: change type、from / to、effective date、affected actor、Source 候補、Evidence 数、confidence |
| 操作 | MVP では閲覧のみ。採否は Source の approved Evidence 有無で決まる。重複統合・却下コマンドは無い（UNKNOWN: Phase 2 候補） |
| 状態 | `candidate → verified → used / retired`（projection。`docs/DATA_MODEL.md`） |
| エラー | Source stale、change date の衝突（`STATE.md` §3 に `contested` として出す） |
| 空状態 | 「`signal_scout` 未実行。`/dfy-run` で実行」または「`search_queries.json` を確認」 |

### 9.5 Problems

| 項目 | v2 |
|---|---|
| 目的 | 抽象的 Signal を具体的業務問題として確認する |
| 表示 | `dfy show P-NNN`: actor / trigger / task / failure / frequency / current workflow / cost / root cause / evidence coverage / UNKNOWN 項目 |
| 操作 | `dfy research list / resolve`（UNKNOWN 項目の Research task）。Evidence 追加後は `input_hash` が変わり再実行 Job が queued される。人手 revise は MVP に無い |
| 状態 | `draft → evidence_pending → verified → mapped / rejected` |
| エラー | actor 不明、current workflow 欠落（schema 上は UNKNOWN として通し、Gate HG-05 で HOLD） |
| 空状態 | 「approved Evidence が無い。`evidence_review` を完了」 |

### 9.6 Opportunities

| 項目 | v2 |
|---|---|
| 目的 | 支払可能な構造かを確認する |
| 表示 | `dfy show O-NNN`: user / payer / decision maker / champion / blocker / data owner / beneficiary、budget source、current alternative と cost、why now / purchase trigger、initial wedge / expansion、field 別 evidence coverage |
| 操作 | `dfy research list / resolve`。閲覧のみ（Problems と同じ） |
| 状態 | `draft → payer_pending → ready → generated / rejected` |
| エラー | payer = user の混同、budget 空、data owner 空（表示上 `UNKNOWN` を強調し、HG-02 / HG-04 / HG-07 で HOLD / FAIL） |
| 空状態 | 「Problem が無い」 |

### 9.7 Ideas

| 項目 | v2 |
|---|---|
| 目的 | Idea Card、類似、Gate、次行動を比較する |
| 表示 | `STATE.md` §5（一覧）。`dfy show I-NNN [--version n]`: 見出し（Gate 結果と fatal コード → 最大不確実性 → 次の行動）を score より先に出し、次に one-liner、wedge、payer、alternative、分類ラベル、cluster、score、revision 履歴。`dfy show NC-NN` で cluster |
| 操作 | `dfy novelty compute / review --by`、`dfy gate run / show / override --by`、`dfy requeue`（revision 後の再実行は dfy が自動 queue） |
| 状態 | `IdeaStatus`（`generated → rejected / research_pending / evaluating → red_teamed → selected / held → …`） |
| エラー | `SCHEMA_INVALID`（Job failed、`STATE.md` §3）、`EVIDENCE_REQUIRED`（FACT に evidence 無し）、`HARD_GATE_BLOCKED`、duplicate unresolved（`novelty.json` の human review 未了） |
| 空状態 | 「Opportunity が無い」または「`service_generate` 未実行」 |

`dfy show I-001` の見出し例:

```text
I-001 v2  idea  status: red_teamed  [generated → verified(numeric) → human: gate override none]
Gate: PASS (HG-RUN-003)
Largest unknown: 受託会社が 30 万円の試行に支払い、匿名 sample を共有するか
Next action: V-001（APR-001 requested）
```

### 9.8 Evaluations

| 項目 | v2 |
|---|---|
| 目的 | 独立評価と disagreement、アンカー較正を可視化する |
| 表示 | `STATE.md` §6・§10。`dfy eval show I-NNN`: criterion × referee の行列（各 cell に score / confidence / executor）、median、MAD、effective score、disagreement 行、reason と evidence refs、`dfy show BP-NN` で packet、`dfy show EV-NNN` で referee run |
| 操作 | `dfy eval aggregate`、`dfy pairs make / tally`、無効化は `dfy fail JOB --by --reason` → `dfy requeue`（再評価は Evidence 追加・revision・rubric 変更時のみ。rubric 変更は fork） |
| 状態 | Job 状態 + aggregation 行の有無。`disagreement` flag、`miscalibrated` flag |
| エラー | packet leak（`INVARIANT_VIOLATION`。Job dead）、packet 不一致（`IDEMPOTENCY_CONFLICT`）、score 欠落（`SCHEMA_INVALID`）、ベンダー分散違反（start 時に拒否） |
| 空状態 | 「PASS 案が無い」 |

```text
Criterion            evidence(codex)  commercial(claude)  technical(gemini)  median  MAD  effective
demand_evidence            6 (0.7)          5 (0.6)             -             5.5    0.5    5.3
payer_and_budget           5 (0.6)          6 (0.7)             -             5.5    0.5    5.1
feasibility                  -                -               8 (0.8)         8.0    0.0    7.6
Disagreement: economic_value (range 3–7, MAD 2.0)   → dfy show EV-004 / EV-007
Anchors: EV-007 gap 2.7 miscalibrated (observe: 点数は未補正)
```

### 9.9 Red Team

| 項目 | v2 |
|---|---|
| 目的 | 上位案の致命傷と修正可否を管理する |
| 表示 | `STATE.md` §7。`dfy show RT-NNN`: finding、severity（S1〜S4）、attacked assumption、evidence、falsification test、resolution、Improver の revision 参照、再 Gate 結果 |
| 操作 | 閲覧。Improver の revision → 再 Gate は dfy が自動で行う。fatal（S4）の override は `dfy gate override --by --reason`（最終選定前に再 Gate） |
| 状態 | `open → accepted / disputed → resolved / unresolved / fatal` |
| エラー | S3 / S4 解決後の再 Gate 未実施は dfy が許さない（portfolio が `INVARIANT_VIOLATION`）。未解決 fatal は `selected` にならない（PRD AC-12） |
| 空状態 | 「上位案未選定（aggregate 未完）」 |

### 9.10 Validation Experiments

| 項目 | v2 |
|---|---|
| 目的 | 30 日実験と行動証拠を実行・記録する |
| 表示 | `STATE.md` §8。`dfy show V-NNN`: biggest uncertainty、target、day、cost、success / hold / kill、必要 approval。`dfy experiment show EXP-NNN`: 状態、日数、event timeline（level、verified flag、証拠 artifact） |
| 操作 | `dfy approval request / approve / reject / revoke --by`、`dfy experiment start / event / complete --by`、`/dfy-review approval|experiment` |
| 状態 | plan `draft → approval_required → approved → running → success / hold / kill / inconclusive`（`docs/VALIDATION_SYSTEM.md`）。Approval `requested → approved / rejected / expired / revoked / executed` |
| エラー | `APPROVAL_REQUIRED`（終了コード 4）、approval expired、PII flag 未処理、metric 未設定（`VALIDATION_ERROR`）、`VALIDATION_THRESHOLD_NOT_MET` |
| 空状態 | 「selected Idea が無い（`decision_finalize` 未実施）」 |

Event 登録は事実どおりの種別を選ばせる（強い順に並べない）。証拠 artifact が無い event は `verified: false` と表示する（v1 維持）。

### 9.11 MVP Projects

| 項目 | v2 |
|---|---|
| 目的 | Validation 通過案の最小実装を管理する |
| 表示 | `dfy show MVP-NNN`（ASSUMPTION: ID 形式 `MVP-NNN`、ファイル `mvp-projects.jsonl`。`CONTRACTS.md §5.3 / §6` への追記を提案）: value moment、payment moment、scope、manual ops、excluded、acceptance criteria、customer commitment |
| 操作 | `dfy mvp create I-NNN --by`（Validation gate 通過時のみ）。milestone 更新・pause / kill は Phase 2（UNKNOWN） |
| 状態 | `proposed → approved → building → pilot → converted / paused / killed` |
| エラー | `VALIDATION_THRESHOLD_NOT_MET`、customer data の Approval 無し（`APPROVAL_REQUIRED`） |
| 空状態 | 「まだ作らない」が正常状態であることを表示する（v1 維持） |

### 9.12 Portfolio

| 項目 | v2 |
|---|---|
| 目的 | 限られた検証予算の配分を決める |
| 表示 | `dfy portfolio compute --json` の結果、`dfy show D-S-NNN`: final score、cluster、最大不確実性、validation cost / time、upside、selected / held / rejected と制約充足、`FINAL.md` §3〜§4、`/dfy-review decision` |
| 操作 | `dfy portfolio compute [--validation-budget]`、`dfy decision finalize --by --reason`（手動変更は理由必須） |
| 状態 | `draft → computed → finalized` |
| エラー | fatal 案の選択（`INVARIANT_VIOLATION`）、同一 cluster 重複、budget 超過（`VALIDATION_ERROR`） |
| 空状態 | 「aggregate / red team 未完」 |

### 9.13 Learning

| 項目 | v2 |
|---|---|
| 目的 | 予測と実績の差を見る |
| 表示 | `dfy learning snapshot / calibration` の出力と `learning/` 配下: score decile × reply / referral / data / paid / retention、predicted vs actual duration、cohort と n、calibration error、proposals |
| 操作 | `dfy learning snapshot`、`dfy learning calibration`、`dfy learning propose`。rubric 変更は人間が `rubric.yaml` を更新し新 Run（自動適用なし） |
| 状態 | `insufficient_data（n < 30）→ descriptive → calibration_candidate（30〜99）→ shadow（≥ 100）` |
| エラー | n 不足（warning、生成は行う）、outcome 未検証（`verified: false` の event を除外して表示） |
| 空状態 | 「まず `dfy experiment event` で結果を登録」 |

### 9.14 Prompt / Rubric Versions

| 項目 | v2 |
|---|---|
| 目的 | 変更と再現性 |
| 表示 | `prompts/<agent_key>/meta.yaml`（`prompt_version`）、`rubric.yaml`、`anchors/`、`executors.yaml`、各 Run の `*.snapshot.*`、`prompts.snapshot.json`、git log。`dfy doctor` が prompt_hash と `.claude/agents/` の一致、weights 合計、capability を表示 |
| 操作 | ファイル編集 + git commit、`dfy sync-agents`、`dfy anchors generate`（既存があれば明示指定なしに再生成しない）、`dfy run fork`（Run に反映） |
| 状態 | git の履歴。active / retired は無く「どの Run がどの hash を使ったか」で追う |
| エラー | weights ≠ 100、schema 互換サブセット違反（`oneOf` 等）、prompt_hash 不一致（生成物の手編集）、`CAPABILITY_MISSING` |
| 空状態 | `dfy init` の既定 |

### 9.15 Cost Dashboard

| 項目 | v2 |
|---|---|
| 目的 | Run / Stage / executor 別のリクエスト数・利用枠・推計 USD と停止 |
| 表示 | `STATE.md` §4、`costs.json`（requests / tokens / usd_estimated を分離）、`dfy show MC-NNNN`（call 単位）。retry waste（repairs、requeue 回数）と usage unknown 率 |
| 操作 | `dfy run pause`、`dfy run fork`（上限変更）、`executors.yaml` の `capacity` 変更（次 Run から） |
| 状態 | `normal → warning（90%）→ budget_paused`。利用枠は `quota_paused`（cooldown 表示） |
| エラー | usage 不明はエラーではなく `unknown` 表示。cost table 無しは `—`。ledger 不整合は `dfy verify` |
| 空状態 | 「model call なし」 |

### 9.16 Audit Log

| 項目 | v2 |
|---|---|
| 目的 | 誰が何をなぜ変えたか |
| 表示 | `journal.jsonl`（seq、ts、type、actor、payload、prev_hash、hash）。`jq 'select(.actor.type=="human")'` 等で絞る。`dfy show <ID>` の履歴節、`report.html` の journal 抜粋 |
| 操作 | `dfy verify`（chain、manifest、projection 整合）、`dfy export`。変更・削除不可 |
| 状態 | — |
| エラー | `VERIFY_FAILED`（chain 断絶、manifest 不一致）、projection 遅延（`dfy state` で再生成を案内） |
| 空状態 | あり得ない。`run.created` から始まる |

## 10. 空状態の標準

空状態は「何が無いか」と「次のコマンド」の 2 行で出す。

```text
proposed Evidence はありません。
次の操作: dfy source add <url> --run run-2026-09-04-01 で Source を登録し、/dfy-run で evidence_verify を実行してください。
```

「まだ作らない」（MVP Projects）のように空が正常な画面は、その旨を 1 行目に書く。

## 11. 状態表示の標準

色は補助。文字ラベルを必須とする（`NO_COLOR` で無色）。

| 対象 | 表示 |
|---|---|
| Claim 分類 | `FACT` / `ESTIMATE` / `ASSUMPTION` / `HYPOTHESIS` / `UNKNOWN`。review 状態が `approved` 以外なら `FACT·proposed` のように `·<review_status>` を添える。反証・衝突は `REFUTED` / `CONFLICT` |
| 確定の段階 | `generated`（schema 通過）/ `verified`（dfy の決定的検査通過）/ `human: <name>`（`--by` レコードあり） |
| Run 状態 | 状態語をそのまま。`quota_paused` は `cooldown_until` を、`budget_paused` は `scope / limit` を、`awaiting_human` は `stage_key` を添える |
| Stage 状態 | `[ ] pending` / `[.] ready` / `[>] running` / `[!] needs_review`（human 待ちを含む）/ `[x] passed` / `[B] blocked` / `[F] failed` / `[-] skipped` |
| Job 状態 | `queued / dispatched / running / succeeded / failed / dead / cancelled` の語。台帳は `q/d/r/s/f/dead` の件数 |
| Gate | `PASS` / `HOLD` / `FAIL`。FAIL には fatal コード（`FAIL (HG-07)`）、HOLD には必要証拠の数（`HOLD (2 evidence required)`） |
| Red Team severity | `S1` / `S2` / `S3` / `S4 fatal` |
| Approval | `requested / approved / rejected / expired / revoked / executed` + `action_type` |
| Experiment 行動証拠 | `L1`〜`L6` + `verified` / `unverified` |
| 利用枠・予算 | `normal` / `warning (92%)` / `budget_paused` / `quota_paused (until 01:40Z)` |
| 評価者 | `executor/model` を常に併記（`codex/gpt-5.5`）。subagent は `claude-code/sonnet (reported: unknown)` |

## 12. エラー文の標準

端末の人間向けエラーは **見出し + 4 行**（原因 / 影響 / 再試行 / 次の操作）で出す（`docs/ARCHITECTURE.md §10`）。`--json` では `message` = 見出し、`details` = 原因の構造化、`retryable` = 再試行、`action` = 次の操作、に対応させる。executor の raw エラーと資格情報は出さない（`output.raw.txt` に残す）。

悪い例: `処理に失敗しました`。

v1 の例を dfy 出力に置換したもの:

```text
dfy exec JOB-0012 (evidence_verify, codex/gpt-5.5) を完了できませんでした。 [EXECUTOR_ERROR, exit 6]
原因: SS-003 の抽出テキストが空です（PDF から文字を抽出できません。extraction_quality 0.02）。
影響: E-019 は FACT として利用されず、依存する 3 案（I-004, I-007, I-011）が Hard Gate HOLD になります。
再試行: 同じ入力では再試行しません（retryable: false）。
次の操作: ページ画像を確認して locator を手動登録する（dfy claim link C-014 --evidence E-019 --locator "p.12 表 3"）か、Source を差し替えてください（dfy source add <url> --replaces SRC-003）。
```

利用枠:

```text
dfy next run-2026-09-04-01 を続行できません。 [QUOTA_LIMIT_REACHED, exit 5]
原因: codex が利用枠エラーを返しました（5 時間枠）。
影響: Run は quota_paused。JOB-0033, JOB-0034 は queued に戻り、succeeded Job は保持されます。
再試行: cooldown 後に可能（cooldown_until 2026-09-05T01:40:00Z）。
次の操作: 01:40Z 以降に dfy run resume run-2026-09-04-01 または /dfy-run run-2026-09-04-01 を実行してください。
```

承認:

```text
dfy experiment start V-001 を実行できません。 [APPROVAL_REQUIRED, exit 4]
原因: V-001 は external_contact と pii_collection を含み、APR-001 が requested のままです。
影響: 実験は開始されず、event は登録できません。
再試行: 承認後に可能。
次の操作: dfy approval approve APR-001 --by <name> --reason "…"（または /dfy-review run-2026-09-04-01 approval）。
```

schema 不適合（修復上限）:

```text
dfy complete JOB-0031 (referee_commercial, claude-code/sonnet) を確定できません。 [SCHEMA_INVALID, exit 7]
原因: 修復 2 回後も output.json が schema に適合しません（scores[3].confidence: 数値必須、evidence_refs: 必須）。
影響: JOB-0031 は failed、referee_commercial は needs_review。BP-09 の集計は 2 referee のみでは行われません。
再試行: 自動再試行はしません。
次の操作: dfy requeue JOB-0031 --by <name> --reason "…" で再投入するか、stage-io/referee_commercial/JOB-0031/repairs/ を確認してください。
```

lease 失効:

```text
dfy complete JOB-0028 を受け付けられません。 [LEASE_EXPIRED, exit 3]
原因: lease は 2026-09-05T00:58:00Z に失効しました（TTL 30 分）。
影響: 出力は output.raw.txt に保存しました。状態は変更していません。
再試行: 可能。
次の操作: dfy next で JOB-0028 が再 lease されたら、dfy complete JOB-0028 --output <同じパス> を実行してください（/dfy-run はこれを自動で行います）。
```

規則:

- 見出しは「何を（コマンドと対象 ID、Stage、executor/model）」「できなかったか」+ `[CODE, exit n]`。
- 「影響」には ID を列挙する（何案が、どの Job が）。
- 「次の操作」は貼り付けて実行できるコマンドにする。`<name>` と reason は空欄で残す。
- 同じ `error.code` でも文面は対象ごとに変える。テンプレート語（「エラーが発生しました」）を禁じる。

## 13. アクセシビリティと国際化

- 端末は記号 + 語で状態を表し、色に依存しない（NFR-11）。表は等幅を前提とし、絵文字を使わない。
- `--json` を全コマンドに用意し、スクリーンリーダーや他ツールから読めるようにする。
- region / currency / jurisdiction / timezone はデータとして持ち（NFR-12）、表示時に `dfy.config.yaml` の設定で整形する。文言は日本語、技術語・状態語・ID は英語のまま。

## 14. 受け入れ条件（UX）

| # | 条件 |
|---|---|
| UX-01 | `dfy state` の出力が §5 の節番号・見出し・列を持ち、`/dfy-run` の報告が §1・§3・§9 の転記と一致する |
| UX-02 | `NO_COLOR=1` で全コマンドを実行しても、状態・分類・Gate 結果の情報が失われない |
| UX-03 | 全エラー（`CONTRACTS.md §12.2` の各コード）が見出し + 4 行を持ち、「次の操作」がコマンドである |
| UX-04 | `dfy show I-NNN` の見出しが Gate 結果 → 最大不確実性 → 次の行動の順で score より先に出る |
| UX-05 | `FINAL.md` が §6 の 11 節を持ち、`decisions.jsonl` の finalize レコードの `--by` と時刻を含む |
| UX-06 | `--json` の `error.action` と人間向け「次の操作」が同じコマンド文字列である |
| UX-07 | 数値に分類ラベルが無い表示が無い（`STATE.md` §5、`FINAL.md` §3・§5、`dfy show I-NNN`） |
