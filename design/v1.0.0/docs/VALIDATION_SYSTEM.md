# VALIDATION_SYSTEM.md

## 1. 目的

Validation Systemは、顧客の好意的な発言ではなく、時間・情報・社内信用・予算を実際に差し出した行動で需要仮説を更新する。完成システムの開発はValidation success後に限定する。

## 2. 行動証拠レベル

| Level | Event | 意味 | Demand weight |
|---:|---|---|---:|
| 1 | positive_comment | 面白いと言われた | 0 |
| 2 | wants_more_detail | 詳細説明を求めた | 1 |
| 3 | follow_up_scheduled | 次回時間を確保 | 2 |
| 4 | internal_referral | 決裁/実務担当を紹介 | 4 |
| 5 | data_shared | データ/仕様/現行資料を提供 | 6 |
| 6 | approval_started | PoC稟議・調達相談を開始 | 7 |
| 7 | LOI_received | 条件付き意向、予約、申込 | 8 |
| 8 | paid_pilot | 有料PoC契約/支払い | 10 |
| 9 | converted | 本契約・継続課金 | 12 |
| 10 | retained_or_referred | 継続、拡張、他社紹介 | 14 |

Weightは機械的な真実値ではなく、portfolio比較の補助。Level 1のみでsuccessにしてはならない。

## 3. 最大不確実性の選び方

Ideaごとに不確実性を列挙し、次で優先順位を付ける。

```text
priority = fatality_if_false * probability_of_false * cost_if_delayed / test_cost
```

典型:

- payerが本当に予算を持つか
- current workflowの痛みが十分か
- データを合法に取得できるか
- 既存代替より改善が大きいか
- 価格を払うか
- MVPを8〜12週で作れるか

技術的不確実性が最大でない限り、技術PoCを最初にしない。

## 4. 実験タイプ

### E-01 Problem interview

用途: workflow、trigger、current alternative、costを確認。  
弱点: 支払意思は証明しない。  
成功metric例: 10人中7人が同じ具体的workflowと過去事例を語る。  
Kill例: 問題が年1未満かつ損失が小さく、現行対処に満足。

### E-02 Workflow artifact request

用途: Excel、仕様書、帳票、匿名データを提供する行動を見る。  
Success: 対象組織2社以上が実資料/匿名データを提供。  
強度: interviewより高い。

### E-03 Price ask / paid diagnostic

用途: payerと価格帯。  
方法: 仮見積、固定範囲の手動分析、PDF report。  
Success: 有料診断1件、または価格入りLOI 2件。  
禁止: 「いくらなら払うか」だけで成功判定。

### E-04 Concierge MVP

人間が裏側で処理し、顧客には価値出力を渡す。  
測る: time saved、decision changed、repeat request、payment。

### E-05 Wizard of Oz

UIは動くがアルゴリズムを手動代替。誤認を招く説明は禁止し、実験であると明示。

### E-06 Landing page / outbound response

B2Bでは母数と対象品質を記録。clickよりqualified reply/meeting/referralを重視。

### E-07 Data feasibility test

匿名sampleでschema、欠損、join rate、latency、精度上限を測る。顧客データ利用approval必須。

### E-08 Procurement path test

決裁者、予算時期、契約方式、セキュリティ要件、PoC可否を実際の担当者と確認。紹介・仕様書提供・見積依頼を行動証拠とする。

## 5. Experiment Plan schema

```yaml
experiment_id: EXP-001
idea_id: I-001
biggest_uncertainty: "受託調査会社がプロジェクト原価から支払うか"
hypothesis: "地域GIS/調査会社は300物件の有料試行に30万円以上払う"
target:
  segment: "過去3年に自治体空き家調査を受託した会社"
  roles: [project_manager, business_unit_manager]
  sample_size: 15
contact_method: "公開窓口への人間による個別連絡"
offer: "匿名CSVを使う2週間の差分優先度・品質確認"
price_ask: "JPY 300,000 excluding tax"
duration_days: 30
budget: "JPY 80,000"
success:
  - "2社が匿名データを提供"
  - "1社が有料PoCまたは価格入りLOI"
hold:
  - "5商談以上だが支払権限者未接触"
kill:
  - "20 qualified contactsで商談2未満"
  - "10 interview全社が既存GISで十分かつ切替理由なし"
approvals: [external_contact, customer_data_use, regulated_claim_review]
```

## 6. Interview質問

未来の意向より過去行動を聞く。

- 直近でこの業務を行ったのはいつか。
- そのとき最初から最後まで何をしたか。
- 誰が何時間使ったか。外注費/再作業はどこに出たか。
- どの帳票、Excel、GIS、電話、現地確認を使ったか。
- 誤りや遅延が起きた具体例は何か。
- その問題を解くために既に何を購入・委託したか。
- 次回の予算は誰がいつ決めるか。
- 小さな試行に必要なセキュリティ・契約条件は何か。
- 匿名sampleを今週共有できるか。
- 価格入りの試行提案を誰に出せばよいか。

避ける:

- 「このサービス欲しいですか」だけ。
- solution説明後の誘導質問。
- 仮想的な将来予算を事実扱い。

## 7. Sales message構造

```text
Subject: [特定業務]の[具体的再作業]を、既存データのまま小さく検証するご相談

1. 相手の実在業務を一文で示す
2. 現行方法を否定せず、測りたいボトルネックを示す
3. 完成製品ではなく限定試行を提示
4. 必要データ、期間、出力、価格を明示
5. 20分の確認または匿名sample提供を一つだけ依頼
6. 自動送信せずHuman approval後に人間が送る
```

## 8. LP / Mock構成

- 対象者とtrigger
- 現在の業務
- before/after
- sample output
- 使うデータ/使わないデータ
- security / responsibility boundary
- pilot scope、期間、価格
- CTA: meetingではなく「匿名sampleで適合確認」等、強い行動へ

## 9. Sample size

MVPの市場検証は統計的有意差を目的にしない。意思決定に足るminimumを明示する。

- Problem interview: 5〜15 qualified people。
- Outreach: 20〜50 narrowly targeted organizations。
- Data feasibility: 2〜3 independent datasets。
- Paid pilot: 1件でも強い証拠。ただし一般化はしない。
- Conversion/retention: cohort n<30では率を断定せず件数と区間を併記。

## 10. Success / Hold / Kill

### Success

- 最大不確実性を直接下げる行動証拠。
- metricが事前登録済み。
- source artifactまたはverified eventがある。

### Hold

- 対象者が違った、決裁者へ未到達、データ形式だけ未確認等、追加実験が低コストで可能。
- Hold期限と必要Evidenceを必須。

### Kill

- payer不在。
- current alternativeの方が明確に安く簡単。
- 合法なdata access不能。
- 価格よりdelivery/support costが高い。
- qualified customerが行動を示さない。
- 重大責任が解消不能。

Killは失敗ではなく、資源回収の成功としてCost Dashboardに表示する。

## 11. Human approval

次を含む実験は`approval_id`がなければstartできない。

- external contact / email
- ad spend
- paid tool or contractor
- contract / invoice / payment
- PII collection
- customer data use
- regulated domain claim
- production deployment

Approvalはpayload hashに紐づく。文面、対象、費用、データ用途が変われば再承認。

## 12. Result登録

最低限:

- planned vs actual target count
- responses/meetings/referrals/data/LOI/paid
- price presented
- actual cost/time
- qualitative objections coded
- evidence artifacts
- success/hold/kill decision
- decision maker and date

## 13. Learningへの反映

予測snapshotと結果をjoinする。

```text
Demand score       -> qualified meeting / referral / data / paid rate
Payer score        -> price acceptance / approval started / paid rate
Reachability score -> reply / meeting rate
Technical score    -> actual build days / data failure
Recurring score    -> 30/90-day retention
```

### 小標本ルール

- n<30: グラフ、件数、事例、反証。weight変更なし。
- 30〜99: calibration candidate、human review。
- n>=100: time-split backtest後、shadow score。
- 新ruleは過去runの原scoreを上書きしない。

## 14. MVP着手Gate

次を全て満たすこと。

1. Hard Gate PASS、unresolved fatalなし。
2. payer/decision makerが実在確認済み。
3. priceを少なくとも1回提示。
4. data依存案はsample dataまたはaccess commitmentあり。
5. Level 5以上の行動証拠1件、またはLevel 4を複数件。
6. MVP acceptance criteriaとkill dateをHumanが承認。

例外は`experimental build`として最大5営業日/固定費上限を設定し、本格MVPと区別する。
