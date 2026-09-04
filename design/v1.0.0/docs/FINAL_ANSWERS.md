# FINAL_ANSWERS.md

## 1. 普通のアイデア生成AIと本質的に違う点

普通のアイデア生成AIは「入力→案」で終わる。Demand Foundryは、`Source Snapshot → Evidence → Claim → Signal → Problem → Opportunity → Idea → Gate → 行動実験 → 実績`を外部キーでつなぐ。Ideaは中心ではなく途中のartifactであり、最終出力は有料行動証拠、保留Evidence task、または監査可能な撤退判断である。

実装上の差は次の4点。

- FACTにlocator付きEvidenceを強制するDB/API invariant。
- payer/data/validationをscore前に判定するHard Gate。
- generator/evaluator/Red Teamのjobとcontext分離。
- prediction snapshotとactual behavior eventのappend-only比較。

## 2. 需要のない案が上位に残ることをどう防ぐか

1. Problem evidenceがない案はHG-01でfail。
2. 現行支出・委託・時間・損失が推計不能ならHG-06でhold/fail。
3. demand scoreの20点はEvidence RefereeがEvidence ID付きで採点。
4. 好意的発言はscoreをほぼ更新せず、紹介・データ・稟議・LOI・支払い・継続を強く扱う。
5. 最終選定には30日Validation planを必須にし、実績が出なければkill。

市場前のscoreは仮説順位にすぎず、顧客行動が反証した時点で選定を更新する。

## 3. AI同士が互いの誤りを強化することをどう防ぐか

- Source raw textをGeneratorへ渡さず、Verifierが作ったapproved Evidence packetだけを渡す。
- GeneratorはEvaluatorになれないapplication invariant。
- 評価者は互いのscore、過去順位、生成元を見ない。
- 同じAIが挙げた同じ転載Sourceを複数証拠として数えない。
- medianだけでなくMADとunknown penaltyを使う。
- Red Team KillerをImproverより先に独立実行。
- 最後はAI多数決ではなく、市場行動とHuman approvalで確定。

## 4. 支払者のいない案をどう除外するか

Idea Cardに`payer`, `decision_maker`, `budget_source`, `purchase_trigger`を必須fieldとして持たせる。空欄ならAPI保存はできてもHard Gate PASSにはならない。

- payerなし: HG-02 fail
- decision makerなし: HG-03 hold/fail
- budget sourceなし: HG-04 hold/fail
- 受益者とpayerが異なる場合: 価値移転・商流を明示しない限りhold

「行政が払うだろう」「企業が欲しがるだろう」はASSUMPTIONであり、入札、現行委託、予算科目、稟議開始、価格提示反応で検証する。

## 5. 根拠のない数字をどう検出するか

数値claimにvalueだけを許さず、`unit`, `time_scope`, `geography`, `denominator`, `source_id or formula`を必須にする。

- FACT数字: Evidence locator必須。
- ESTIMATE: formulaと各inputの型・source必須。
- ASSUMPTION: owner/期限/検証方法。
- TAM/SAM/SOM: 包含関係とbottom-up式を検査。
- 10/100/1000社売上: calculatorで再計算。
- 月/年、税込/税抜、%分母、全国/地域の不一致をvalidatorでflag。

検出できないものはUNKNOWNのままにし、見栄えのために埋めない。

## 6. 類似案の言い換えをどう検出するか

タイトルembeddingだけでなく、以下を正規化して比較する。

- customer
- problem
- payer
- solution mechanism
- required data
- pricing/contract
- current alternative
- GTM/wedge

`lexical similarity + embedding similarity + structured field overlap`で候補を出し、同じ点と異なる点を表示する。顧客・payer・商流・契約等にmaterial differenceがなければduplicate/near-duplicate cluster。同じ技術でもpayerや商流が変われば別案として保持できる。

## 7. 市場検証前の過剰開発をどう防ぐか

MVP Project作成APIにValidation Gateを置く。

必須:

- Hard Gate PASS、fatalなし
- price ask済み
- payer/decision maker確認
- data依存案はsample/access commitment
- Level 5以上の行動1件、または複数Level 4
- scope/manual/excluded/kill dateのHuman approval

これを満たさないbuildは最大5営業日の`technical spike`にしかできず、本格MVP statusへ遷移できない。

## 8. 実際の顧客行動をどう学習へ反映するか

評価時点で`prediction_snapshot`を固定し、その後の`experiment_events`をappendする。次を比較する。

- demand score vs qualified meeting/referral/data/paid
- payer score vs approval started/LOI/payment
- reachability vs reply/meeting
- technical score vs build days/data failure
- recurring score vs retention/churn

n<30ではルールを変えず、差分を表示。30〜99で変更候補、100以上でもtime-split backtestとshadow運用を経てHuman approvalで新Rubric versionにする。過去scoreは上書きしない。

## 9. 一人の開発者でも運用可能にするには何を削るか

削る:

- multi-provider
- crawler
- Python service
- real-time UI
- graph canvas
- full CRM
- auto email/payment
- sophisticated ML learning
- complex role workflow
- full pairwise round-robin

残す:

- Source/Evidence/Claim
- payer Hard Gate
- generator/evaluator分離
- 30日Validation + kill metric
- Job idempotency/Resume
- Cost/Audit
- Human approval
- JSONL/Markdown export

## 10. 最初の12週間でどこまで完成させるべきか

完成ラインは「一人の運営者が1Runを最後まで回せること」。

- Briefをsnapshot
- Source/PDFを取り込み、FACTをlocator付きverify
- Signal/Problem/Opportunityを生成
- 20 Idea CardsとNovelty cluster
- Hard Gateで支払者/データ/検証不能案を落とす
- 3独立評価、上位Red Team、上位3件のValidation plan
- Human approval後に行動eventを登録
- 予測scoreと実績を比較
- Stop/Resume、Cost、Audit、JSONL/Markdown export

12週間で有料顧客獲得を保証するのではなく、**有料顧客へ最短で到達する探索・撤退・記録の機械**を完成させる。市場検証そのものはWeek 10から実行し、可能なら1件の有料診断/PoCを得るが、それは製品受け入れ条件ではなく市場成果である。
