# PRD.md

## 1. Product Summary

Demand Foundryは、根拠収集から市場検証、MVP候補選定、学習記録までを一つのRunとして管理する、証拠駆動型のAI事業創造OSである。

## 2. ユーザー

### P-01 Venture Operator

- 主利用者。探索Briefを作成し、Runを開始し、証拠をレビューし、検証を実行する。
- 初期は創業者・新規事業担当・一人ベンチャースタジオを想定。

### P-02 Domain Reviewer

- 特定業界の証拠、規制、現場業務をレビューする。
- MVPでは招待された閲覧・コメント権限のみ。

### P-03 Approver

- 外部連絡、顧客データ利用、支出、本番デプロイを承認する。
- MVPではOperator本人と分離可能な簡易ロール。

### P-04 Auditor / Investor

- どの証拠から何が生成され、なぜ落ち、何が市場で反証されたかを読む。
- 読み取り専用。

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

## 4. 機能要件

### 4.1 Run / Brief

| ID | 要件 | 優先度 |
|---|---|---|
| FR-001 | Brief入力をYAML/JSONへコンパイルする | P0 |
| FR-002 | Brief、Rubric、PromptをRun開始時にsnapshotする | P0 |
| FR-003 | Runに予算、期限、対象地域、除外領域を設定する | P0 |
| FR-004 | Runの開始・一時停止・Resume・取消を行う | P0 |
| FR-005 | Stageごとの状態と進捗を表示する | P0 |

### 4.2 Source / Evidence

| ID | 要件 | 優先度 |
|---|---|---|
| FR-101 | URL、PDF、HTML、手動メモをSourceとして登録する | P0 |
| FR-102 | Source Snapshotに取得日時、hash、mime、publisherを保存する | P0 |
| FR-103 | Evidence Itemに抽出位置、要約、claim support/refuteを持たせる | P0 |
| FR-104 | FACTにはEvidence Linkを必須とする | P0 |
| FR-105 | 数値に単位、時点、地域、母数または式を要求する | P0 |
| FR-106 | 反証、競合証拠、鮮度切れを表示する | P1 |
| FR-107 | Source内容を非信頼データとして隔離する | P0 |

### 4.3 Signal / Problem / Opportunity / Idea

| ID | 要件 | 優先度 |
|---|---|---|
| FR-201 | Signalをサービス案ではなく変化カードとして生成する | P0 |
| FR-202 | Problemを5W1H、頻度、現行対処、支出、根本原因付きで生成する | P0 |
| FR-203 | Opportunityにuser/payer/decision maker/budget/alternativeを必須化する | P0 |
| FR-204 | 1Runで20件以上のIdea Cardを生成する | P0 |
| FR-205 | 発想構造を複数指定し、同じ構造の名称変更を抑制する | P0 |
| FR-206 | Required schemaに合わないLLM出力を修復またはreviewへ送る | P0 |
| FR-207 | IdeaのoriginからSignal/Problem/Evidenceへ遡れる | P0 |

### 4.4 Novelty Archive

| ID | 要件 | 優先度 |
|---|---|---|
| FR-301 | 顧客、課題、支払者、解決構造、データ、課金構造を正規化する | P0 |
| FR-302 | lexical + embedding + field overlapで類似候補を出す | P0 |
| FR-303 | 類似でも差分軸が明確なら別案として保持できる | P0 |
| FR-304 | cluster_idとsimilar_idea_idsを保存する | P0 |

### 4.5 Gate / Evaluation / Red Team

| ID | 要件 | 優先度 |
|---|---|---|
| FR-401 | Hard Gateをscore前に実行する | P0 |
| FR-402 | fail/hold/passとコード、根拠、必要追加証拠を保存する | P0 |
| FR-403 | 生成元と過去順位を隠した評価packetを作る | P0 |
| FR-404 | 商業・証拠・技術の独立評価を実行する | P0 |
| FR-405 | 同一案について評価者の分散と根拠を比較する | P0 |
| FR-406 | 上位案のペア比較を固定seedで実行する | P1 |
| FR-407 | Red Team KillerとImproverを別jobとして実行する | P0 |
| FR-408 | fatal findingは総合点に関係なくfailへ戻せる | P0 |

### 4.6 Validation / MVP / Learning

| ID | 要件 | 優先度 |
|---|---|---|
| FR-501 | 上位3案に30日以内の検証計画を作る | P0 |
| FR-502 | success/hold/kill metricを必須にする | P0 |
| FR-503 | 行動証拠イベントを時系列で登録する | P0 |
| FR-504 | 外部行為前にApprovalを要求する | P0 |
| FR-505 | 検証通過案だけMVP Projectへ昇格できる | P0 |
| FR-506 | 予測scoreと返信・紹介・データ・LOI・支払い・継続を比較する | P0 |
| FR-507 | ルール変更候補を作るが、自動適用しない | P0 |
| FR-508 | nが少ない場合に過剰最適化警告を出す | P0 |

### 4.7 Export / Audit / Cost

| ID | 要件 | 優先度 |
|---|---|---|
| FR-601 | RunをMarkdown/JSON/JSONLでexportする | P0 |
| FR-602 | run directory形式のmanifestを作る | P0 |
| FR-603 | LLM callごとのtoken、cost、latencyを記録する | P0 |
| FR-604 | stage/agent/model/idea別の予算を停止条件に使う | P0 |
| FR-605 | status変更、手動編集、承認をappend-only audit logへ記録する | P0 |

## 5. 非機能要件

| ID | 要件 | 目標 |
|---|---|---|
| NFR-01 | 再現性 | prompt/rubric/model/input/source snapshotを追跡可能 |
| NFR-02 | 冪等性 | 同一idempotency keyで重複entityを作らない |
| NFR-03 | Resume | worker停止後、lease切れjobから再開可能 |
| NFR-04 | 監査性 | 最終判断から証拠とLLM callへ逆引き可能 |
| NFR-05 | セキュリティ | workspace分離、RLS、秘密情報非出力 |
| NFR-06 | コスト | budgetの90%で警告、100%前に新規call停止 |
| NFR-07 | 可用性 | MVPはRPO 24h以下、RTO 4h以下を目標 |
| NFR-08 | Schema | 全主要LLM出力をZod/JSON Schema検証 |
| NFR-09 | Performance | UI一般操作p95 1.5秒未満、長時間処理は非同期 |
| NFR-10 | Explainability | gate/score/decisionにreasonとevidence refs必須 |
| NFR-11 | Accessibility | キーボード操作、状態を色だけで表現しない |
| NFR-12 | Internationalization | region/currency/jurisdiction/timezoneをデータ化 |

## 6. MVP範囲

### In Scope

- 単一workspaceと簡易認証
- Brief Compiler
- URL/PDF/手動Source登録
- Evidence抽出・人手確認
- Signal → Problem → Opportunity → 20 Ideas
- Novelty候補表示
- Hard Gate
- 3種類の独立評価
- 上位案のRed Team
- 上位3案のValidation Plan
- Behavior Event登録
- 予測と実績の比較
- Run Resume
- Cost / Audit / JSONL / Markdown export

### Out of Scope

- 自動メール送信、広告、契約、課金
- CRM全機能
- 高度な共同編集
- 20以上の業界テンプレート
- 複数LLMの自動ルーティング
- Temporal/Kafka等の分散基盤
- モデルfine-tuning
- 自動ルール更新
- 全国サイトの常時クローリング
- 顧客本番データの常時同期

## 7. 主要フロー

### Flow A: 新規Run

1. Operatorが探索条件を入力。
2. SystemがBrief/Rubric/Constraints/Search Queriesを提示。
3. Operatorが確定し、snapshotを作成。
4. Run budgetを確認し開始。
5. Stage jobsが順次作成される。

### Flow B: 証拠レビュー

1. Sourceを取り込み、Snapshotを保存。
2. Evidence Verifierがclaim候補とlocatorを抽出。
3. 存在確認・分類・数値属性を検査。
4. 低信頼または矛盾はReview Queueへ。
5. 承認済EvidenceだけがProblem生成のFACTとして使われる。

### Flow C: 選定

1. Opportunityから複数Ideaを生成。
2. Novelty Archiveが類似clusterを提示。
3. Hard Gateがpass/hold/fail。
4. Passのみブラインド評価。
5. 上位候補をPairwiseとRed Teamへ。
6. Portfolio Managerが上位3件と追加証拠候補を選ぶ。

### Flow D: 市場結果

1. Validation Planを人間が承認。
2. 人間が外部接触。
3. 行動イベントを登録。
4. Success/Hold/Killを判定。
5. 予測と実績をLearningへ記録。

## 8. MVP受け入れ条件

| AC | Given | When | Then |
|---|---|---|---|
| AC-01 | 有効なBrief | Run完了 | 20件以上のIdea Cardが存在する |
| AC-02 | FACT claim | 保存時 | evidence_idとlocatorなしではvalidation error |
| AC-03 | payer空欄 | Hard Gate | passにならずhold/failになる |
| AC-04 | Idea生成済み | Gate実行 | current alternativeが空ならhold/failになる |
| AC-05 | 上位案 | Validation生成 | 30日以内、success/hold/killがすべてある |
| AC-06 | 3評価者 | 評価完了 | 個別score、理由、分散が比較できる |
| AC-07 | 類似案 | Novelty実行 | clusterと差分軸が表示される |
| AC-08 | worker停止 | lease失効後resume | completed jobを再実行せず未完了から続く |
| AC-09 | LLM call | 完了 | model/prompt/tokens/cost/input hashが残る |
| AC-10 | 行動結果 | 登録 | predicted scoreとactual eventを同一ideaで比較できる |
| AC-11 | Run完了 | export | required directoryとJSONL/Markdownが生成される |
| AC-12 | fatal Red Team | 最終選定 | scoreが高くてもselectedにならない |
| AC-13 | budget超過見込み | job開始前 | callせずrunがbudget_pausedになる |
| AC-14 | Source本文に命令文 | 抽出 | tool実行やsystem instruction変更が起きない |
| AC-15 | Approval未承認 | 外部action要求 | 409 APPROVAL_REQUIREDを返す |

## 9. 製品分析イベント

- `run_created`, `run_started`, `stage_started`, `stage_completed`, `stage_failed`
- `evidence_approved`, `evidence_rejected`, `claim_downgraded`
- `idea_generated`, `idea_clustered`, `hard_gate_failed`
- `evaluation_completed`, `red_team_fatal_found`
- `validation_plan_approved`, `behavior_event_recorded`
- `idea_promoted`, `idea_killed`, `mvp_project_created`
- `rule_change_proposed`, `rule_change_approved`
- `budget_warning`, `budget_paused`, `run_exported`

分析イベントは監査ログと分離する。監査ログは完全性、分析イベントはプロダクト改善を目的とする。
