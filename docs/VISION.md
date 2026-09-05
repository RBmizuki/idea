# VISION.md

設計版: design-v2.0.0 / 所有範囲: 目的、成功定義、初期制約、最大リスク、重要仮定、非目的、基本原則、北極星、運用像（`docs/CONTRACTS.md` §17）

## 1. 依頼の構造化

### 1.1 目的

Demand Foundry の目的は、次の閉ループを再現可能なソフトウェアとして運用することである。v2.0.0 では、このループを**単一運営者がローカルで動かす `dfy` CLI** として実装し、LLM は API key ではなく**サブスクリプションで動く CLI**（Claude Code / Codex CLI / Gemini CLI）をフェーズ別に使う。

```text
変化・一次情報
  -> 未充足問題
  -> 支払者・予算・代替手段
  -> 事業機会
  -> 構造の異なるサービス案
  -> Hard Gate / 独立評価 / Red Team
  -> 顧客行動による検証
  -> 検証通過案だけMVP化
  -> 売上・利用・継続結果
  -> 予測と実績の比較
  -> 評価ルールの人間承認付き更新
```

成果物は「良さそうな案」ではなく、次のいずれかである。

- 有料PoCまたは本契約へ進める案
- 次の検証で最大不確実性を潰せる保留案
- 失格理由と再考条件が明示された撤退案

v1.0.0 からの変更は実行基盤（Web + PostgreSQL → CLI + run ディレクトリ）と LLM 呼び出し（API key → サブスクリプション CLI）に限る。Evidence/Claim 型、15 Hard Gate、生成/評価分離、30 日検証、承認、監査、export は全て維持する（`docs/CONTRACTS.md` §1）。

### 1.2 成功の定義

#### 市場成果

| 指標 | MVP目標 | 製品化後の目標 |
|---|---:|---:|
| 上位案の30日以内行動検証率 | 100% | 100% |
| 顧客検証3〜5案から有料PoC | 0〜1件でも計測可能にする | 20〜40% |
| 有料PoCから本契約 | 計測可能にする | 30%以上を仮説 |
| 最初の有料顧客までの日数 | 計測可能にする | 中央値90日未満を仮説 |
| 撤退案の失格理由記録率 | 100% | 100% |

数値目標のうち市場転換率は現時点では `HYPOTHESIS` であり、実績が蓄積するまで製品性能の事実として扱わない。

#### 証拠品質

- `FACT` の100%に `evidence_id` と抽出位置を必須化する。
- 主要主張のEvidence Coverageを90%以上にする。
- 数値主張の100%に単位、地域、時点、母数または計算式を持たせる。
- 反証証拠を削除せず、競合する主張として保存する。
- 出典の存在確認に失敗した主張を `FACT` に昇格させない。
- ツール付き CLI（WebSearch / google_web_search）が持ち帰った内容も、Source snapshot を経由しない限り `FACT` にしない。

#### 運用品質

- 1回のrunで20件以上の構造的に異なる案を出力できる。
- 支払者不明、決裁者不明、データ取得不能、30日検証不能は自動で `HOLD` または `FAIL` にする。
- 完了済み Job を再計算せず、journal から Resume できる。利用枠停止（`quota_paused`）からの再開でも同じ。
- すべての LLM 呼び出しについて executor、mode、`model_requested` / `model_reported`、prompt hash、入力ハッシュ、出力ハッシュ、usage（取得不能な場合は「不明」と記録）、latency を追跡する。
- 同じ snapshot（brief / rubric / executors / prompts / anchors）、同じ prompt 版、同じ executor / model 条件で再現試行できる。mock executor では決定的に再現できる。
- 3 referee のアンカー差（ANCHOR-STRONG − ANCHOR-WEAK）を全 referee run で観測し、3.0 未満を警告する。

### 1.3 初期制約

- 地域は日本中心。海外対応のため地域・通貨・法域をデータ列で分離する。
- 初期領域は公共データ、行政DX、インフラ、建設、エネルギー、防災、モビリティ、高齢化、医療周辺、地域産業、B2B業務。
- 開発者1〜3人、MVP 8〜12週間。
- 大型設備投資、全国一括データ整備、完全自律営業を前提にしない。
- B2B/B2Gを優先し、狭い地域・顧客・業務から開始する。
- **単一運営者・ローカル実行**。認証・RLS・マルチユーザーは Phase 3。保護はファイルシステム権限と git で行う。
- **LLM はサブスクリプション CLI をフェーズ別に使う**（`claude-code` / `codex` / `gemini-cli`。`docs/CONTRACTS.md` §9）。**API key は不要**とし、headless 実行時の任意手段にとどめる。referee のベンダー分散のため、運営者は 2 ベンダー以上の CLI にログインできること（A-03）。
- **実行環境は Node 22+、macOS / Linux / WSL**。実装は TypeScript の単一 npm package（`dfy`）。Python は GIS・分析が必要なジョブだけに限定する（v1 継承）。
- Web UI と PostgreSQL は MVP に含めない。静的 HTML report は Phase 2、Postgres import は Phase 3。

### 1.4 最大リスク

| リスク | 失敗の形 | 設計上の抑止 |
|---|---|---|
| 証拠の幻覚 | 存在しない出典で案が高評価 | Source Snapshot、抽出位置、存在確認、FACT昇格条件。web tool の結果も snapshot 経由でのみ Evidence 化 |
| 評価者の相関 | 複数AIが同じ誤りを反復 | 役割別プロンプト、生成元秘匿、独立コンテキスト、**3 referee のベンダー分散（異なる executor 2 以上）**、アンカー観測、MAD 減点 |
| 支払者不在 | 社会的意義だけ高い案が残る | Hard Gateでpayer/decision maker/budget source必須 |
| 過剰開発 | 顧客行動前に8週間作り込む | Validation Gate、MVP着手に行動証拠最低水準 |
| B2G営業の長期化 | 30日で需要検証不能 | 民間受託会社・専門家を初期wedgeとして評価可能にする |
| コスト・利用枠暴走 | 低価値案にリクエストを反復し、利用枠を食い潰す | Run / Stage / executor 別のリクエスト上限、`capacity`、早期停止（Gate FAIL 案に評価 call を出さない）、retry cap、schema repair 最大 2 回 |
| 自動学習の誤最適化 | 少数結果に合わせ閾値が壊れる | n閾値、human approval、shadow評価、時系列holdout |
| 外部行為の誤実行 | 無承認メール・契約・個人情報取得 | Approval Object がなければ実行してよい記録を残さない。v2 は外部行為の実行機能自体を持たない（D-015 維持） |
| **利用枠枯渇による Run 中断** | 5 時間枠・日次上限に達して Run が途中停止し、再開時に完了 Job を再実行して枠を二重消費する、または状態が食い違う | `capacity` と `budget.requests` による事前停止、利用枠エラーの `QUOTA_LIMIT_REACHED` への正規化と `quota_paused`、cooldown 後の `dfy run resume`、journal + `idempotency_key` + lease による完了 Job のスキップ、deterministic / human Stage は LLM 枠を消費しない |
| **CLI 仕様変更** | flag・出力形式・終了コードの変更で executor が黙って壊れる、または誤った出力を取り込む | executor 抽象（`src/executors/`）、公式文書で確認済みの flag のみ使用、`dfy doctor` による存在・version・ログイン・capability の診断、CLI 出力を信用せず dfy 側で JSON 抽出・schema 検証・不変条件検査、mock executor による回帰試験 |
| **ベンダー混在の較正ずれ** | 3 referee が別モデルで採点基準が異なり、median が特定ベンダーの癖に引きずられる。ベンダー差を案の差と誤認する | ANCHOR-WEAK / ANCHOR-STRONG を全 referee バッチに匿名混入、差 3.0 未満で `miscalibrated` 警告、MAD 減点と disagreement flag、絶対採点の小数点差に頼らない pairwise（提示順入替 ×2）、`policies.anchors: apply` は実績蓄積後にのみ有効化 |
| **headless サブスク利用の規約リスク** | `claude -p` 等をサブスクリプション資格情報で無人実行することは公式推奨外。規約・利用枠の変更で突然止まる、または利用制限を受ける | `subagent` モード（Claude Code 内で `/dfy-run` が起動）を標準形にする、headless は運営者本人が自分のマシンで選ぶ構成に限る、executor 抽象で API key・別ベンダーへ切替可能、規約・利用枠の監視は `docs/SECURITY_AND_RISK.md` |

## 2. 設計上の重要仮定

| ID | 仮定 | 区分 | 破れた場合 |
|---|---|---|---|
| A-01 | 初期利用者は一人の運営者（v2 では設計制約に昇格） | FACT（要件） | Phase 3 で Postgres import・認証・レビュー割当を有効化。run ディレクトリと journal はそのまま移行元になる |
| A-02 | 1回のrunは数時間〜数日でよく、秒応答不要。利用枠による中断を含んでよい | ASSUMPTION | `capacity.max_parallel` を増やす、headless を API key に切替。複数マシン分散は非目的のまま |
| A-03 | 運営者は Claude / ChatGPT / Google のうち 2 ベンダー以上のサブスクリプション CLI にログインできる | ASSUMPTION | `referee_vendor_diversity_min` を 1 に下げ、相関リスクを `STATE.md` に明記して Run する。または headless + API key で第 2 ベンダーを補う |
| A-04 | 一次資料は検索（Claude Code / Gemini CLI の web tool）・URL登録・PDF/HTML取り込みで集められる | ASSUMPTION | 専門データ契約または手動アップロードを追加 |
| A-05 | 外部への営業行為は人間が行う | FACT（要件） | 変更不可。将来自動化してもapproval必須 |
| A-06 | 市場結果は少数から始まる | FACTに近い運用前提 | 自動最適化を禁止し、記述統計から開始 |
| A-07 | JSON Schema（互換サブセット、`docs/CONTRACTS.md` §13）で主要出力を拘束できる。構造化出力 flag のない CLI でも、抽出 + Zod 検証 + 修復 2 回で足りる | ASSUMPTION | 修復回数と人手レビュー比率を上げる。当該 Stage の executor を構造化出力対応 executor へ再割当 |
| A-08 | MVPでは lexical + field overlap で Novelty 判定に足りる（embedding は optional） | ASSUMPTION | embedding を optional executor として追加。reranker は後付け |
| A-09 | run ディレクトリ（JSONL + append-only journal）を唯一の正にできる | DESIGN DECISION | Postgres import（Phase 3）。journal は import 後も監査台帳として保持 |
| A-10 | 各 CLI の flag・出力形式・利用枠は変わり得る | FACTに近い運用前提 | executor adapter を更新し、`dfy doctor` が非対応 version を報告する。mock で再現性を保つ。`executors.snapshot.yaml` により過去 Run の解釈は変わらない |
| A-11 | サブスクリプション規約はベンダー都合で変わる | FACTに近い運用前提 | headless を API key へ切替、当該 executor を他ベンダーへ再割当（`dfy run fork`）。規約上不可となった形態は使わない |
| A-12 | ベンダー混在の採点差はアンカー 2 packet で観測できる | ASSUMPTION | `policies.anchors: apply` で線形正規化、pairwise の比重を上げる、referee を同一ベンダー別モデルにして相関を受け入れる |

## 3. 非目的

MVPでは次を実現しない。

- AIが会社を設立すること
- AIが無承認でメール、広告、契約、決済を行うこと
- AIが医療・法務・金融判断を確定すること
- 日本全業界・全自治体を自動クロールすること
- 生成した案をすべて存続させること
- LLM同士の多数決を真実判定に用いること
- 実績の少ない段階でモデルを自己更新すること
- 本格CRM、請求、決済、マーケットプレイスを作ること
- Web UI と PostgreSQL を MVP で作ること（Phase 2 / Phase 3）
- API key を必須にすること（headless 時の任意手段にとどめる）
- ベンダーのログイン・利用枠を第三者に提供するサービスにすること（本人が自分のマシンで使う範囲に限る）
- 複数 executor の自動ルーティング・自動フォールバック
- Agent SDK による組込み（CLI で足りる）

## 4. 基本原則

1. **Evidence before Ideation**: 変化、問題、現在支出、支払者を先に取る。
2. **Claims are typed**: FACT / ESTIMATE / ASSUMPTION / HYPOTHESIS / UNKNOWNを混ぜない。
3. **Behavior beats opinion**: 発言より紹介、データ提供、稟議、LOI、支払い、継続を重くする。
4. **Gate before score**: 致命欠陥を平均点で救わない。
5. **Generator is not judge**: 生成と評価を分離し、評価入力をブラインド化する。referee はベンダーも分散させる。
6. **Current alternative is the competitor**: Excel、電話、委託、放置、保険、既存機能を必ず比較する。
7. **Smallest falsifiable test**: 開発ではなく最大不確実性を最安で反証する。
8. **One source of truth**: run ディレクトリを正とし、`STATE.md` / `FINAL.md` / `costs.json` は journal と JSONL から再計算される projection とする。export はバージョン付き成果物とする。
9. **Human controls consequence**: 外部影響と高リスク判断は人間が承認する。
10. **Learning is audited change**: 予測と結果の差分、更新ルール、理由が残る場合だけ学習と呼ぶ。
11. **CLI owns the state**: `dfy` CLI が状態機械・検証・冪等性・記録を所有する。LLM は配達人（オーケストレーター `/dfy-run`）と作業者（サブエージェント / headless executor）にとどまり、状態を直接書かず、判断・要約・上書きをしない（Courier Rule）。

## 5. 製品の北極星

単一の総合点ではなく、次の複合指標を北極星とする。

```text
Validated Opportunity Yield
= 一定期間内に有料行動証拠へ到達した案数
  / 検証に投入した総費用と総人日
```

補助指標は、失格の早さ、Evidence Coverage、payer特定率、30日検証可能率、検証単価、予測校正誤差、Run あたり LLM リクエスト数（executor 別）、referee のアンカー差である。

## 6. 成功時の運用像

一人の運営者が次を行う。

1. `dfy init` で Workspace を作り、`dfy doctor` で 2 ベンダー以上の CLI ログインと capability、referee のベンダー分散を確認する。
2. `brief.yaml` を書き、`dfy run new` → `dfy run start` で snapshot を固定する。
3. Claude Code で `/dfy-run <run_id>` を実行する。無人で回す場合はターミナルで `dfy run auto <run_id>` を実行する。

24〜72時間以内（利用枠による停止時間を含む）に次を得る。

- 出典付きSignal 50〜100件
- 具体的Problem 20〜40件
- 支払者・予算付きOpportunity 20件以上
- Hard Gate通過案5〜8件
- ブラインド評価（3 ベンダー referee + アンカー観測）とRed Team後の上位3件
- 各案の30日以内検証パッケージ
- 1件あたりの追加検証費用と最大不確実性
- 全 LLM 呼び出しの executor / model / usage を持つ `model-calls.jsonl` と、hash chain 付き `journal.jsonl`

Run は人間 Stage（Evidence review、Decision finalize、Approval、Experiment 登録）で停止し、運営者は CLI（`dfy evidence review`、`dfy decision finalize` 等）で判断を記録する。利用枠に達した場合は `quota_paused` で止まり、cooldown 後の `dfy run resume` で完了 Job を再実行せず続きから動く。運営者が席を外しても `STATE.md` と journal だけで現在地が分かる。

その後、人間が顧客接触を行い、行動結果を `dfy experiment event` で登録する。システムは「何を予測し、何が外れたか」を比較し、次回の評価ルール候補を提示するが、勝手に変更しない。
