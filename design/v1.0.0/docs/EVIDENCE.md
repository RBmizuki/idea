# EVIDENCE.md

## 1. 目的

Evidence Systemは、LLMが文章をもっともらしく整える機能と、外部世界の事実確認を切り離す。LLM出力は証拠ではない。証拠は、存在が確認されたSource Snapshotの特定箇所である。

## 2. 用語

- **Source**: 文書・ページ・データセットという論理的出典。
- **Source Snapshot**: 特定時点に取得した不変コピーとhash。
- **Evidence Item**: Source Snapshotの特定箇所から取り出した、あるclaimを支持/反証する内容。
- **Claim**: システムが扱う検証可能な主張。
- **Locator**: page/line/section/table/cell/quote hash等の位置情報。
- **Evidence Link**: ClaimとEvidence Itemのsupport/refute/context関係。

## 3. 主張分類

### FACT

Source Snapshotの該当箇所が直接支持する主張。

必須:

- `evidence_id`
- locator
- geography / date scope
- source trust class
- contradiction status

禁止:

- sourceの相関記述から因果を作る
- sourceにない精度へ丸め直す
- 二次記事の要約を一次資料の内容として扱う

### ESTIMATE

再計算可能な推計。

必須:

```json
{
  "formula": "target_customers * annual_price * reachable_rate",
  "inputs": [
    {"name":"target_customers","value":500,"type":"ESTIMATE","source_ids":["E-..."]},
    {"name":"annual_price","value":1200000,"type":"ASSUMPTION"},
    {"name":"reachable_rate","value":0.05,"type":"HYPOTHESIS"}
  ],
  "result": 30000000,
  "unit": "JPY/year",
  "range": [12000000, 60000000]
}
```

### ASSUMPTION

設計を前へ進めるために置く未検証前提。ownerと期限を持つ。

### HYPOTHESIS

市場実験または技術実験で判定すべき予測。success/hold/kill metricへ接続する。

### UNKNOWN

現時点で推定も置けない事項。無理に数字を埋めず、Research Taskを作る。

## 4. Source trust class

| Class | 例 | 初期信頼 | 注意 |
|---|---|---:|---|
| A1 | 法令、政府統計、自治体仕様書、裁判文書、公開入札結果 | 0.95 | 適用範囲・改定日を確認 |
| A2 | 査読論文、標準規格、監査済み決算 | 0.90 | 研究条件・会計期間を確認 |
| B1 | 業界団体、企業公式製品/IR、専門機関 | 0.80 | 自己利益バイアス |
| B2 | 信頼できる報道、専門誌、調査会社 | 0.65 | 一次資料へ遡る |
| C1 | 求人、レビュー、SNS、掲示板、営業資料 | 0.45 | Signalには有用、FACT確定は補助 |
| D | AI生成要約、出典不明転載 | 0.00 | 証拠として使用禁止 |

信頼度はsource classだけで決めず、directness、specificity、freshness、corroboration、conflictを加味する。

## 5. Evidence confidence

```text
confidence =
  source_quality * 0.30
+ directness     * 0.25
+ specificity    * 0.15
+ freshness      * 0.10
+ corroboration  * 0.10
+ extraction_quality * 0.10
- conflict_penalty
```

0.85以上: high、0.65〜0.84: medium、0.40〜0.64: low、未満: unusable。これは真実確率ではなく、当該claimに使える根拠の品質指標である。

## 6. Source取り込み

### 必須metadata

- title
- source_type
- publisher
- canonical_url or document identifier
- published_at
- retrieved_at
- geography
- industry
- language
- mime_type
- content_hash
- access status
- licensing/terms note

### Snapshot rule

- 同じURLでもcontent hashが変われば新snapshot。
- 過去snapshotを上書きしない。
- 動的ページは取得日時とrender methodを保存。
- PDF/画像の抽出不良は`extraction_quality=low`とし、人間がページ画像を確認する。

## 7. Claim extraction rule

Claimは原則として一文一命題へ分割する。

悪い例:

> 空き家は増えており、自治体は人手不足で、AI導入に年間300万円払う。

良い分割:

1. 空き家数は特定期間に増加した。`FACT`
2. 一部自治体は空き家把握の人員・予算確保が難しい。`FACT`またはscope限定。
3. 対象自治体が年間300万円を支払う。`HYPOTHESIS`

## 8. 数値主張バリデーション

すべての数値に以下を要求する。

| field | 例 |
|---|---|
| value | 9,002,000 |
| unit | dwellings |
| time_scope | 2023-10-01 |
| geography | Japan |
| population/denominator | all housing stock |
| statistic_type | count / ratio / mean / estimate |
| source/equation | E-001 or formula |
| precision_note | rounded to nearest 1,000 |

### 自動検査

- 通貨と期間の欠落
- percentの分母欠落
- 人/社/施設/契約の単位混同
- 月額と年額の混同
- 税込/税抜不明
- 全国統計を初期wedgeにそのまま適用
- CAGRの開始・終了年不一致
- TAM/SAM/SOMの包含関係逆転
- 10/100/1000顧客売上の乗算誤り

## 9. Citation管理

Evidence Itemは次を持つ。

```json
{
  "evidence_id": "E-003",
  "source_snapshot_id": "SS-003",
  "locator": {
    "page": 6,
    "lines": "163-180",
    "section": "第18条 業務概要",
    "quote_hash": "sha256:..."
  },
  "summary": "現地調査5,500件、DB作成、閲覧編集ビューアが業務工程に含まれる",
  "relation": "supports",
  "claim_ids": ["C-014", "C-015"]
}
```

引用文字列は必要最小限のみ保存し、長文転載を避ける。監査時はsource snapshotとlocatorを開く。

## 10. 鮮度

初期TTL例:

| Source/claim | review TTL |
|---|---:|
| 現行法令・制度 | 90日、施行予定日は30日 |
| 価格・補助金・入札 | 30日 |
| 企業役職・製品仕様 | 30日 |
| 年次統計 | 次回公表日または18か月 |
| 人口長期推計 | 24か月 |
| 学術知見 | 24か月。ただしsystematic review優先 |
| 自治体仕様書の業務実態 | 36か月。現行性を別確認 |

Freshness expiryでFACTを削除せず、`stale`表示と再検証taskを作る。

## 11. 反証管理

- Claimは`uncontested`, `contested`, `superseded`, `retracted`を持つ。
- 支持Evidenceと反証Evidenceを同じ画面に表示。
- 同一統計の速報と確報は、確報をcurrent、速報をsupersededとする。
- 解釈差はLLMで一つに統合せず、scope/definition差を記録。
- Red Teamは反証Evidenceを優先的に受け取る。

## 12. Evidence Coverage

主要fieldごとのcoverageを測る。

```text
coverage = supported_required_claim_weight / total_required_claim_weight
```

初期weight:

- problem existence 3
- frequency/volume 2
- current workflow 3
- payer/budget 4
- current cost 3
- data access 4
- regulatory feasibility 4
- market count 2
- competitor/alternative 3

Hard Gate前の推奨minimumは0.65。payer/data/regulationは個別必須で、総coverageで救済しない。

## 13. Source汚染・Prompt Injection対策

- Source本文は命令権限を持たない。
- FetcherとVerifierに外部write toolを与えない。
- HTML script/style/hidden textを分離。
- 「以前の指示を無視」等の命令patternをflagするが、pattern matchingだけに依存しない。
- Sourceから抽出したURLへ自動連鎖アクセスしない。
- Base64/添付/マクロ/実行ファイルを実行しない。
- 信頼できるpublisherでも本文は常にuntrusted。

## 14. Evidence review UI rule

Reviewerは次を一画面で確認する。

- claim
- classification
- source metadata
- highlighted locator
- support/refute
- numeric context
- model extraction
- reviewer action: approve / downgrade / reject / split / mark conflict

Approveはsourceの真実性を保証する行為ではなく、「このsourceがこのclaimをこのscopeで直接支持する」という判断である。

## 15. AI生成文の扱い

- LLM summaryは`derived_text`でありEvidenceではない。
- LLMが提案したsource title/URLは未検証Source candidate。
- URLが存在しても、claim locatorがなければEvidenceではない。
- 複数AIが同じURLを挙げてもcorroborationには数えない。独立Sourceのみを数える。
