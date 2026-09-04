# Demand Foundry — 証拠駆動型ベンチャービルダー OS 設計パッケージ

バージョン: `design-v2.0.0`  
作成日: `2026-09-04`  
対象: 日本中心、B2B/B2G、1〜3人開発、8〜12週間 MVP、**単一運営者・ローカル実行・サブスクリプション CLI**

## このパッケージの位置づけ

Demand Foundry は、アイデアを大量生成するチャットボットではない。社会変化と一次情報から問題を見つけ、支払者・予算・代替手段・検証可能性を確認し、弱い案を早く落とし、顧客行動を次の評価へ戻すための**証拠駆動型ベンチャービルダー OS**である。

v2.0.0 は、v1.0.0（`design/v1.0.0/`）の事業ロジックを維持したまま、実行基盤を次のように置き換えた設計である。

- **`dfy` CLI（TypeScript）と run ディレクトリ**が唯一の正。Next.js / PostgreSQL / Worker は後段オプション。
- LLM は **API key ではなく、サブスクリプションで動く CLI** をフェーズごとに選ぶ: Claude Code（Claude サブスク）、Codex CLI 経由の GPT（ChatGPT プラン）、Gemini CLI（Google アカウント / AI Pro / Ultra）。
- Claude Code の中では `/dfy-run` が**配達人**としてサブエージェントを起動する。状態機械・検証・冪等性・記録はすべて `dfy` が所有する。
- 3 評価者は**異なるベンダーを 2 以上**含め、**アンカー基準器**で採点ドリフトを観測する。

本パッケージは実装コードそのものではなく、実装に着手できる粒度の仕様である。語彙・ID・ファイル配置・コマンド・状態・スキーマは `docs/CONTRACTS.md` で固定している。

## 最重要の設計判断

- run ディレクトリ（JSONL + append-only journal）を唯一の正とし、`STATE.md` / `costs.json` / `FINAL.md` は再生成可能な projection とする。
- 状態遷移・検証・冪等性・lease・記録は `dfy` CLI が所有する。LLM オーケストレーターは Courier Rule に従い、パス・ID・CLI 出力の無改変転記以外を行わない。
- executor（`claude-code` / `codex` / `gemini-cli` / `mock`）はフェーズ単位で `executors.yaml` に割り当て、Run 開始時に snapshot として固定する。
- 生成者、証拠検証者、評価者、Red Team、最終選定（deterministic）を分離する。評価者にはベンダー分散とアンカーを課す。
- Hard Gate は加点評価より先に deterministic に実行し、支払者・データ・検証手段がない案を高得点で救済しない。
- 予算は USD ではなくリクエスト数と利用枠で管理し、`quota_paused` と `budget_paused` を区別する。
- 外部連絡、広告、契約、課金、個人情報、顧客データ、本番デプロイは Human Approval なしに実行しない。実行機能自体を持たない。
- 「学習」は予測・根拠・実績・差分・ルール更新を永続化した場合だけを指す。MVP では自動学習しない。

## 文書一覧

| 文書 | 内容 |
|---|---|
| `docs/CONTRACTS.md` | **上位契約**。語彙、ID、配置、stage/agent/executor 名、状態、コマンド、スキーマ、終了コード、固定数値 |
| `docs/VISION.md` | 目的、成功定義、非目的、原則、重要仮定 |
| `docs/PRD.md` | ユーザー、ユースケース、要件、MVP、受け入れ条件 |
| `docs/ARCHITECTURE.md` | 3 構成比較、採用構成、モジュール境界、データフロー、Resume、拡張境界 |
| `docs/EXECUTORS.md` | executor ごとの起動・認証・能力・構造化出力・tool 制限・利用枠検知・mock 対応表 |
| `docs/ORCHESTRATION.md` | `/dfy-run` の手順、Courier Rule、`dfy next/exec/complete` の協調、lease、並列、再開 |
| `docs/AGENTS.md` | エージェント契約、prompt source 規約、subagent 生成規則、tool matrix |
| `docs/PIPELINE.md` | Stage DAG、通過・失格・再実行、早期停止、Run 完了条件 |
| `docs/EVIDENCE.md` | 証拠ポリシー、出典、分類、鮮度、反証、数値検査、injection 対策 |
| `docs/EVALUATION.md` | Hard Gate、独立評価、アンカー、ベンダー分散、ペア比較、Red Team、選定式 |
| `docs/DATA_MODEL.md` | run ディレクトリの各レコード、revision、projection、manifest、v1 互換 |
| `docs/CLI_SPEC.md` | `dfy` コマンド、引数、出力、エラー、冪等性 |
| `docs/UI_UX.md` | 端末・Markdown・Claude Code 上の体験、STATE.md / FINAL.md、レビュー動線 |
| `docs/VALIDATION_SYSTEM.md` | 市場実験、行動証拠、成功・保留・撤退、承認、学習連携 |
| `docs/SECURITY_AND_RISK.md` | ローカル資格情報、prompt injection、規約、データ分類、監査 |
| `docs/MVP_PLAN.md` | 12 週間計画、縦切り順、テスト、リスク |
| `docs/BACKLOG.md` | Epic / Story / 優先度 / 依存 / DoD |
| `docs/DECISIONS.md` | ADR。v1 D-001〜D-028 の状態更新と v2 D-029〜 |
| `docs/STATE.md` | 現在地、完了、未完、次作業、ブロッカー |
| `docs/RED_TEAM_REVIEW.md` | 7 視点の攻撃と反映済み修正 |
| `docs/FINAL_ANSWERS.md` | 最終 13 問への実装仕様としての回答 |
| `docs/CHANGES_FROM_V1.md` | v1 → v2 の差分一覧と移行方針 |
| `schemas/` | 公開 JSON Schema（Gemini / Codex 互換サブセット） |
| `config/executors.example.yaml` | フェーズ別 executor 割当の例 |
| `design/v1.0.0/` | 旧設計パッケージ（参照。サンプル run は v2 の fixture として使う） |

## サンプル run

v1.0.0 の `design/v1.0.0/runs/run-2026-09-04-01/`（自治体・受託調査会社の空き家再調査）を v2 でも fixture として使う。`mock` executor はこれを読み、v2 の受け入れ試験は「mock で新規 run として再現し、Hard Gate PASS 5 / HOLD 8 / FAIL 7 と上位 3 案（I-001, I-003, I-010）が一致すること」を基準線とする。

## 推奨実装順

1. store / journal / schemas / `dfy run new` / `dfy state` の縦切り
2. mock executor と claude-code subagent、`/dfy-run`、`brief_compile` の縦切り
3. Source snapshot → Evidence verify（codex）→ Evidence review の証拠縦切り
4. Signal → Problem → Opportunity → 20 Ideas → Novelty
5. Hard Gate → 3 referee（3 ベンダー）+ anchors → Red Team → Portfolio
6. Validation → Approval → Experiment events → Learning → Export / Verify

詳細は `docs/MVP_PLAN.md` を参照する。

## パッケージ検証

```bash
python3 -m venv .venv && .venv/bin/pip install pyyaml jsonschema
.venv/bin/python scripts/validate_package.py
.venv/bin/python scripts/make_manifest.py
```

検証は、必須文書、JSON Schema の妥当性と互換サブセット、`executors.example.yaml` の整合、v1 サンプル run の v2 schema 互換、rubric weights 合計、manifest の hash を確認する。
