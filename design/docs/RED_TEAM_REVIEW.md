# RED_TEAM_REVIEW.md

## 1. 一人の開発者視点

### 攻撃

- 17文書の理想を全部実装すると12週を超える。
- RLS、worker、source parser、LLM、evaluation、UIを同時に作ると広すぎる。
- Pairwise、vector、Learning dashboardは価値が出る前に時間を使う。

### 修正

- モジュラーモノリスと単一workerへ固定。
- UIはtable/detail、polling、owner中心。
- Python、multi-provider、crawler、CRM connectorを除外。
- Week 2でBrief→Artifactの縦切り、Week 4でEvidence縦切りを完成。
- 削ってはいけないcoreをMVP_PLANに明記。

### 残存リスク

Source parserとEvidence reviewが想定以上に重い。対策としてmanual locatorをfirst-classにする。

## 2. 新規事業責任者視点

### 攻撃

- 良い資料を作るだけで顧客接触が遅れる可能性。
- B2Gは30日で支払行動が取りにくい。
- scoreの精密化が営業を代替してしまう。

### 修正

- Validation planを上位3案に必須化。
- B2G直販だけでなく既存受託会社をinitial wedgeにできる設計。
- Portfolio bonusを検証効率へ付与。
- MVP着手条件にprice askとdata/LOI等の行動を追加。

### 残存リスク

運営者が外部接触を先延ばしにする。Dashboardにapproval待ちより「未接触日数」を表示する拡張をP1候補とする。

## 3. 顧客視点

### 攻撃

- 顧客にとってAIやscoreは価値ではない。
- データ提供、説明、導入作業が増えるなら現行Excelの方が楽。
- 「精度」だけでなく責任と既存workflowへの接続が必要。

### 修正

- Idea Cardにcurrent workflow/alternative、integration、manual operations、value momentを必須。
- Red Teamに導入担当者の仕事増、個別開発、誤判定責任を必須攻撃として追加。
- Validationで実資料提供とworkflow artifactを行動証拠に採用。

### 残存リスク

サンプル出力の価値を事前に見せられない案は検証が弱い。PDF/CSV/conciergeを優先する。

## 4. 投資家視点

### 攻撃

- 小さく売れる案でも、受託化して粗利・拡張性が低い可能性。
- 20案生成は供給過多で、quality signalにならない。
- top-down TAMの誇張が残りやすい。

### 修正

- 10/100/1000社売上、必要人員、delivery bottleneckを必須。
- ボトムアップ式とrange/sensitivity。
- Portfolioにrecurring margin、support cost、expansionを残すが、需要証拠よりweightを低く維持。
- 一社個別開発化をRed Team material/fatal候補にする。

### 残存リスク

初期顧客の狭さと大市場への拡張が物語でしかない可能性。Expansionはscore 5点に抑え、actual adjacent demandまで過大評価しない。

## 5. セキュリティ担当視点

### 攻撃

- Source本文経由prompt injection。
- 顧客データがLLM providerへ流れる。
- approval後payload差替え。
- service roleの横断アクセス。

### 修正

- raw SourceはVerifierのみ、Generatorはverified packet。
- PIIは外部CRM参照、redaction、separate vault。
- Approvalをpayload hashとcapabilityへ紐づけ。
- worker writeにworkspace/job context、RLSとintegration test。
- Prompt injection canaryをAcceptanceへ追加。

### 残存リスク

LLM providerの保持条件は契約依存。provider選定時のDPA reviewがblocker。

## 6. 法務担当視点

### 攻撃

- 法令・補助金・入札情報の鮮度。
- 公開Sourceを再配布する権利。
- 医療/金融/行政判断の責任。
- 顧客データ目的外利用。

### 修正

- Source terms note、snapshot retention policy。
- 法令/価格/入札に短いfreshness TTL。
- regulated claim approval。
- liability fieldsとhuman review point。
- B2Gの公開仕様書は購入意思ではなく業務存在Evidenceに限定。

### 残存リスク

個別法域・業界ごとの専門家確認はシステムで代替できない。Hard Gate HOLDとapprovalで止める。

## 7. AI品質担当視点

### 攻撃

- 3評価者が同じmodelなら誤りが相関する。
- Blind packet自体にGeneratorの framingが残る。
- LLMのscore精度が見せかけになる。
- 小標本でrubricを過剰調整する。

### 修正

- 評価者ごとに責任criterionとpromptを分離。
- packet leak validator、title/origin/rank削除。
- median/MADとevidence uncertainty penalty。
- Market eventをscoreより上位に扱う。
- n<30でweight変更禁止、n>=100でもshadow/backtest。
- 同一Source転載を独立corroborationに数えない。

### 残存リスク

同一modelの世界知識biasは残る。MVP後、異なるprovider/model、人間専門家、実顧客結果の組み合わせで軽減する。

## 8. Red Team反映による主要変更

1. 自治体直販だけでなく民間受託者wedgeを許容。
2. Raw SourceのGenerator直渡しを禁止。
3. Fatal修正後の再Gateを必須化。
4. Evidence Coverage平均でpayer/data/regulationを救済しない。
5. PIIを外部CRM参照中心に変更。
6. Pairwise補正を±5に制限。
7. Learning自動化を明確にMVP外へ。
8. Manual locatorとpartial completionをfirst-class化。
9. 価格提示なしでMVP昇格できない条件を追加。
10. B2G仕様書を需要証拠ではなく現行支出/業務Evidenceとして限定。

## 9. 最終判定

設計はMVP実装へ進める。ただし、Week 4時点でEvidence縦切りが完成しない場合、Signal Scout自動探索、Pairwise、Learning chartを削り、**手動Source登録→Evidence→Opportunity→Gate→Validation**の核を守る。
