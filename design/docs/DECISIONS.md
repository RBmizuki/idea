# DECISIONS.md

Format: ADR summary。Statusは`accepted`, `rejected`, `deferred`, `superseded`。

## D-001 — モジュラーモノリスを採用

- Status: accepted
- Decision: Next.js Web + PostgreSQL +単一TypeScript Worker。
- Rejected: 同期file-only orchestrator、Temporal/Kafka microservices。
- Reason: 12週・一人開発でResume/監査/UIを満たす最小構成。
- Revisit: 同時Run 50超、日次10万job、独立デプロイ要求。

## D-002 — PostgreSQLを唯一の正とする

- Status: accepted
- Decision: JSONL/Markdownはexport snapshot。
- Rejected: runs directoryをprimary store。
- Reason: 参照整合性、RLS、queue、検索、status event。
- Revisit: なし。必要ならevent storeを併用。

## D-003 — DB lease式job queue

- Status: accepted
- Decision: `FOR UPDATE SKIP LOCKED`、locked_until、heartbeat、reaper。
- Rejected: Redis/Kafka/TemporalをMVP導入。
- Reason: 外部基盤を減らし、Postgres transactionでartifact/costを確定。
- Revisit: queue latency/SLO超過。

## D-004 — Route Handlersへ業務処理を集約

- Status: accepted
- Decision: `app/api/*` + application service。page.tsxは薄い。
- Rejected: Server Actions中心、RSC内でbusiness logic。
- Reason: API contract、idempotency、worker連携、テストを明確化。
- Revisit: 単純UI mutationのみ局所採用を検討可能。

## D-005 — 1 LLM providerから開始

- Status: accepted
- Decision: provider adapterは作るが、自動routingはしない。
- Rejected: 初日から複数provider/fallback。
- Reason: 再現性と実装範囲。
- Revisit: provider outage/quality/costの実測差が大きい場合。

## D-006 — Structured outputはZod + JSON Schema

- Status: accepted
- Decision: domain input/outputをschema-first。
- Rejected: Markdown自由出力を後からparse。
- Reason: machine readable、Gate、API、export整合性。
- Revisit: なし。

## D-007 — GeneratorとEvaluatorを分離

- Status: accepted
- Decision: 別agent version、別context、blinded packet。
- Rejected: 一つのLLM callで案とscore。
- Reason: self-preferenceとnarrative lock-inを低減。
- Revisit: なし。

## D-008 — Hard Gateをscoreより先にする

- Status: accepted
- Decision: 15 gate、fatal precedence。
- Rejected: weighted scoreのみ。
- Reason: payer/data/regulation欠陥を他項目で救済しない。
- Revisit: gate閾値は市場結果でversion更新可能。

## D-009 — FACT確定にはSource Snapshot + locator

- Status: accepted
- Decision: URLだけ、LLM引用だけでは不可。
- Rejected: model confidenceによるverify。
- Reason: citation hallucination防止。
- Revisit: なし。

## D-010 — Market sizingはbottom-up優先

- Status: accepted
- Decision: customer count × price × reach rate + sensitivity。
- Rejected: large TAM narrativeのみ。
- Reason: initial wedgeと現実売上に接続。
- Revisit: top-downはcontext用に併記可。

## D-011 — Noveltyは複合判定

- Status: accepted
- Decision: lexical + embedding + structured field overlap + human difference review。
- Rejected: title embedding thresholdだけ。
- Reason: 商流/支払者/価格差を見落とさない。
- Revisit: labeled duplicate dataが1000pair超でreranker検討。

## D-012 — pgvectorを使用

- Status: accepted
- Decision: Postgres内vector。
- Rejected: dedicated vector DB。
- Reason: dataset規模と運用簡素化。
- Revisit: 数百万ideas/latency問題。

## D-013 — Python serviceをMVPに置かない

- Status: accepted
- Decision: TypeScript中心。GIS/ML taskが出た時だけbatchとして追加。
- Rejected: 最初からFastAPI microservice。
- Reason: stack/運用を増やさない。
- Revisit: geopandas/raster/MLが本質になった時。

## D-014 — 自動Web crawlerを作らない

- Status: accepted
- Decision: approved search/URL/file import。
- Rejected: 全国全サイトcrawl。
- Reason: terms、品質、範囲、12週制約。
- Revisit: 特定sourceの安定API/feedsが確認された時。

## D-015 — 外部action executorをMVPに含めない

- Status: accepted
- Decision: 文面/plan生成まで。送信・契約・決済は人間。
- Rejected: autonomous sales。
- Reason:安全、誤送信、法務、brand risk。
- Revisit: approval/capability/receipt基盤完成後も限定。

## D-016 — Validation successをMVP着手条件にする

- Status: accepted
- Decision: Level 5相当または複数Level 4、price ask、data access等。
- Rejected: top scoreだけでbuild。
- Reason: 過剰開発防止。
- Revisit: 5日以内のtechnical spikeは別枠。

## D-017 — Learningはmanual rule proposal

- Status: accepted
- Decision: prediction/outcome差を保存し、人間承認でversion更新。
- Rejected: prompt自動書換え、online learning。
- Reason: 小標本過剰最適化と監査不能を防ぐ。
- Revisit: n>=100、time-split backtest、shadow運用後。

## D-018 — 市場行動をappend-only eventで保存

- Status: accepted
- Decision: 状態上書きではなくevent + projection。
- Rejected: idea.current_statusのみ更新。
- Reason: 時系列・滞在時間・反転・監査。
- Revisit: なし。

## D-019 — Score aggregationはmedian/MAD

- Status: accepted
- Decision: meanのみを使わず、分散とuncertaintyを減点。
- Rejected: 単純平均、多数決。
- Reason: evaluator相関と極端値を可視化。
- Revisit: 実績データでcalibration。

## D-020 — Pairwise補正を最大±5に制限

- Status: accepted
- Decision: 絶対評価を置換しない。
- Rejected: pairwise順位のみ。
- Reason: どちらも悪い案の相対勝者を過大評価しない。
- Revisit: なし。

## D-021 — B2Gでは民間受託者wedgeも評価する

- Status: accepted after Red Team
- Decision: 自治体直販だけでなく、既存調査/コンサル受託会社をpayer候補に分離。
- Reason: 30日検証とsales cycleを現実化。
- Risk: end payer/value distributionを混同しない。

## D-022 — Raw SourceをGeneratorへ直接渡さない

- Status: accepted after Red Team
- Decision: verified Evidence packetのみ。
- Reason: prompt injection、未検証claimの拡散、context bloat。
- Exception: Scout/Verifierのみrawを読む。

## D-023 — Fatal Red Teamは再Gate必須

- Status: accepted after Red Team
- Decision: Improverが修正しても自動復帰しない。
- Reason: narrative repairで致命傷を隠すことを防ぐ。

## D-024 — Evidence Coverageを総合点だけで扱わない

- Status: accepted after Red Team
- Decision: payer/data/regulationは個別必須、coverage平均で救済不可。
- Reason: load-bearing claimの欠落を平均で隠さない。

## D-025 — 実験対象のPIIは外部CRM参照を基本

- Status: accepted after Red Team
- Decision: Demand Foundryには匿名referenceとeventを保存。
- Reason: MVPでのprivacy surface削減。
- Revisit: integrated CRMが本質要件になった時。

## D-026 — ExportはDBから再生成

- Status: accepted
- Decision: FINAL.mdは順位や文章を独自に改善せず、current DB decisionを転記。
- Reason: export drift防止。

## D-027 — UIはtable/detailを優先

- Status: accepted
- Decision: graph canvas、agent theater、リアルタイムanimationは削る。
- Reason: 一人運用で必要なのは証拠、理由、next action。

## D-028 — Sample runの金額は推計として分離

- Status: accepted
- Decision: 公開仕様書から業務量はFACT、契約単価や削減率はASSUMPTION/HYPOTHESIS。
- Reason: 公開資料にない数字を市場事実に見せない。
