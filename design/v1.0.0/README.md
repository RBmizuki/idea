# Demand Foundry — AI事業創造OS 設計パッケージ

バージョン: `design-v1.0.0`  
作成日: `2026-09-04`  
対象: 日本中心、B2B/B2G、1〜3人開発、8〜12週間MVP

## このパッケージの位置づけ

Demand Foundryは、アイデアを大量生成するチャットボットではない。社会変化と一次情報から問題を見つけ、支払者・予算・代替手段・検証可能性を確認し、弱い案を早く落とし、顧客行動を次の評価へ戻すための**証拠駆動型ベンチャービルダーOS**である。

本パッケージは実装コードそのものではなく、実装に着手できる粒度の仕様である。主要な状態、スキーマ、API、ジョブの冪等性、Human-in-the-loop、受け入れ試験まで固定している。

## 最重要の設計判断

- MVPは「Next.js + PostgreSQL + 1本のTypeScriptワーカー」による**モジュラーモノリス**とする。
- PostgreSQLを唯一の正とし、JSONL/Markdownは監査・移送用スナップショットとして出力する。
- 長時間処理はVercel Request内で実行せず、DBリース式ジョブキューを読むワーカーで処理する。
- LLMは1プロバイダーから開始し、`LLMProvider`インターフェースだけを固定する。
- 生成者、証拠検証者、評価者、Red Team、最終選定者を分離する。
- Hard Gateは加点評価より先に実行し、支払者・データ・検証手段がない案を高得点で救済しない。
- 外部連絡、広告、契約、課金、個人情報、顧客データ、本番デプロイはHuman Approvalなしに実行しない。
- 「学習」は予測・根拠・実績・差分・ルール更新を永続化した場合だけを指す。MVPでは自動学習しない。

## 文書一覧

| 文書 | 内容 |
|---|---|
| `docs/VISION.md` | 目的、成功定義、非目的、原則、重要仮定 |
| `docs/PRD.md` | ユーザー、ユースケース、要件、MVP、受け入れ条件 |
| `docs/ARCHITECTURE.md` | 3構成比較、採用構成、データフロー、ジョブ、Resume、コスト |
| `docs/AGENTS.md` | エージェント契約、入出力、権限、禁止事項、停止条件 |
| `docs/PIPELINE.md` | Stage 0〜13、状態遷移、通過・失格・再実行 |
| `docs/EVIDENCE.md` | 証拠ポリシー、出典、分類、鮮度、反証、数値検査 |
| `docs/EVALUATION.md` | Hard Gate、独立評価、ペア比較、Red Team、選定式 |
| `docs/DATA_MODEL.md` | テーブル、キー、状態、監査、RLS、バージョン |
| `docs/API_SPEC.md` | Route Handler API、検証、エラー、冪等性 |
| `docs/UI_UX.md` | 画面、フロー、ワイヤーフレーム、状態、権限 |
| `docs/VALIDATION_SYSTEM.md` | 市場実験、行動証拠、成功・保留・撤退、学習連携 |
| `docs/SECURITY_AND_RISK.md` | 情報保護、AI攻撃、法務、承認、監査 |
| `docs/MVP_PLAN.md` | 12週間計画、縦切り順、テスト、リスク |
| `docs/BACKLOG.md` | Epic / Story / Task / 優先度 / 依存 / DoD |
| `docs/DECISIONS.md` | ADR形式の採否・理由・見直し条件 |
| `docs/STATE.md` | 現在地、完了、未完、次作業、ブロッカー |
| `docs/RED_TEAM_REVIEW.md` | 7視点の攻撃と反映済み修正 |
| `docs/FINAL_ANSWERS.md` | 最終10問への実装仕様としての回答 |
| `runs/run-2026-09-04-01/` | 一貫したサンプルrun |
| `schemas/` | 主要JSON Schema |
| `db/core.sql` | MVP中核テーブルの参考DDL |

## サンプルrun

サンプルは「自治体・受託調査会社の空き家再調査」を探索テーマとし、国・自治体の一次資料を証拠として、20案生成、Hard Gate、独立評価、Red Team、30日検証計画、最終選定までを示す。市場規模・価格・効果は、事実ではなく `ESTIMATE` / `ASSUMPTION` / `HYPOTHESIS` として分離した。

## 推奨実装順

1. Run・Stage・Job・Artifact・Costの縦切り
2. Source・Evidence・Claimの証拠縦切り
3. Problem → Opportunity → Ideaの生成縦切り
4. Hard Gate → Independent Evaluation → Red Team
5. Validation結果 → Outcome Event → Learning比較
6. Export・Resume・監査・受け入れ試験

詳細は `docs/MVP_PLAN.md` を参照する。

## パッケージ検証

```bash
python3 scripts/validate_package.py
```

この検証は、必須文書、JSON/JSONL構文、20案、全案のHard Gate、3件の30日検証計画、評価ウェイト合計を確認する。`schemas/`はサンプルrunのIdea/Evidence/Validationに対してJSON Schema検証済みである。`db/core.sql`は参考DDLであり、実DBへのmigration適用は実装フェーズで行う。
