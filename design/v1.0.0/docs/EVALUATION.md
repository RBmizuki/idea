# EVALUATION.md

## 1. 評価原則

1. Hard Gateを先に実行する。
2. Generatorは評価しない。
3. 評価packetから名称、origin、過去順位を除く。
4. 高い社会的意義はpayer不在を補わない。
5. scoreとconfidenceを分ける。
6. Red Team fatalは平均点で相殺しない。
7. 最終選定は期待値だけでなく検証コストと学習価値を見る。

## 2. Hard Gate

### 判定値

- `PASS`: 次段階へ。
- `HOLD`: 追加証拠またはwedge変更で通過可能。
- `FAIL`: 現構造では次段階へ進めない。

### Gate一覧

| Code | Gate | PASS条件 | HOLD | FAIL |
|---|---|---|---|---|
| HG-01 | Problem evidence | 直接支持Evidenceあり | 弱い/古い | なし/反証優勢 |
| HG-02 | Payer | 組織/役職が特定 | 仮説のみ | 受益者しかいない |
| HG-03 | Decision maker | 購入権限者/会議が特定 | 候補複数 | 不明 |
| HG-04 | Budget source | 予算科目/現支出原資 | 隣接予算仮説 | 新規予算しかなく根拠なし |
| HG-05 | Current alternative | workflowと代替が具体 | 一部不明 | 無との比較のみ |
| HG-06 | Cost/loss | 金額または時間/人員を推計 | volumeのみ | 全く推計不能 |
| HG-07 | Data access | 合法な取得経路 | LOI/協議待ち | 取得不能/違法 |
| HG-08 | Customer reach | 30日で対象へ接触可能 | 紹介待ち | 経路なし |
| HG-09 | Validation | 行動証拠を30日以内 | proxyのみ | 完成開発必須 |
| HG-10 | Narrow MVP | 8〜12週に狭められる | 追加設計要 | 本質的に大規模設備 |
| HG-11 | Behavior change | 既存flow内で導入 | 軽い変更 | 多数人の習慣同時変更 |
| HG-12 | Network dependency | 片側だけで価値 | anchor候補あり | 多組織同時参加必須 |
| HG-13 | Unit economics | priceがdelivery/supportを上回る仮説 | 不確実 | 構造的赤字 |
| HG-14 | Regulation/liability | review可能、責任境界あり | 専門家確認待ち | 解消不能 |
| HG-15 | Improvement | current alternative比で測定可能 | target未検証 | 明確な改善なし |

### 集約規則

```text
if any fatal FAIL in HG-07, HG-14 -> FAIL
else if any FAIL -> FAIL
else if any HOLD -> HOLD
else -> PASS
```

Human overrideは可能だが、`override_reason`, `approver_id`, `expires_at`, `required_experiment`を必須にする。override案は最終選定前に再Gateする。

## 3. 絶対評価軸

初期weightは設定ファイル化する。

| Criterion | Weight |
|---|---:|
| demand_evidence | 20 |
| payer_and_budget | 15 |
| economic_value | 15 |
| customer_reachability | 10 |
| feasibility | 10 |
| validation_speed | 10 |
| recurring_margin | 8 |
| expansion | 5 |
| defensibility | 4 |
| strategic_fit | 3 |
| **Total** | **100** |

補助scoreとしてseverity、frequency、data access、regulatory risk等を保存するが、二重加点しない。

## 4. Score rubric

0〜10。anchorを固定する。

### demand_evidence例

- 0: Problem evidenceなし。
- 2: anecdoteのみ。
- 4: 一次資料で問題存在、購買行動なし。
- 6: 現支出/委託/入札/データ提供の証拠。
- 8: 複数顧客の紹介、データ提供、LOI。
- 10: 有料PoC、継続、紹介実績。

### payer_and_budget例

- 0: payer不明。
- 3: payer仮説のみ。
- 5: payer/decision maker/隣接予算が特定。
- 7: 現行支出または具体的budget line。
- 9: 稟議開始/見積依頼。
- 10: 支払済み。

他criterionもRubric JSONにanchorを持つ。自由解釈を減らす。

## 5. 独立評価

### 評価者

- Evidence Referee
- Commercial Referee
- Technical Referee

各評価者は同じ全criterionを採点せず、専門criterionにprimary責任を持つ。重複criterionは相関検査用に一部重ねる。

### Blind packet

除外:

- title/brand name
- idea IDの意味あるprefix
- generation method
- generator model
- past rank/winner language
-他評価者のscore

保持:

- problem、customer roles、workflow、evidence refs
- economics、technology、risk、validation
- source qualityとunknowns

## 6. 集約

各criterionについて評価者scoreのmedianを使い、意見分散とEvidence uncertaintyを減点する。

```text
criterion_effective
= max(0,
    median(score_0_to_10)
    - 0.35 * MAD(scores)
    - evidence_uncertainty_penalty
  )
```

Evidence uncertainty penalty:

| 根拠状態 | penalty |
|---|---:|
| verified behavior / paid | 0.0 |
| verified FACT/current spend | 0.2 |
| supported ESTIMATE | 0.4 |
| ASSUMPTION with test | 0.8 |
| UNKNOWN | 1.5 |

```text
base_score_0_to_100
= sum(criterion_effective / 10 * weight)
```

### Disagreement flag

- MAD >= 2.0
- max-min >= 4
- confidence差 >= 0.5

Flag時は平均化で閉じず、争点をhuman reviewへ出す。

## 7. Pairwise comparison

対象: base score上位8案以内、Hard Gate PASS、fatalなし。

### 実行

- A/B順をseedでrandomize。
- 各pairを2回、順序反転して実行。
- 同一Novelty cluster内の比較を優先し、代表案を決める。
- 比較質問: 「限られた次の検証予算をどちらへ投じるか」。

### 集約

Bradley-Terryまたは簡易Eloを使用。MVPはEloで十分。

```text
pairwise_adjustment = clamp((elo - 1500) / 100, -5, +5)
```

Pairwiseは絶対評価を置き換えず、最大±5点の補正だけにする。

## 8. Red Team

### finding severity

| Severity | 定義 | 効果 |
|---|---|---|
| S1 minor | 検証文面・UX修正 | -0〜2 |
| S2 material | 価格、wedge、data flowの修正必須 | -3〜7 |
| S3 severe | Gate再評価が必要 | -8〜15 |
| S4 fatal | 合法データ不能、payer不在、構造赤字、責任解消不能 | FAIL |

Killer findingには次を必須とする。

- attacked assumption
- why it matters
- supporting evidence or missing evidence
- falsification test
- severity
- whether design can resolve it

Improverが修正した場合も、元Ideaを上書きせず`parent_idea_id`付きrevisionを作り、Hard Gateを再実行する。

## 9. Final score

Eligibility:

```text
Hard Gate PASS
AND no unresolved S4
AND evidence coverage >= configured minimum
AND validation plan valid
```

Eligible案のみ:

```text
final_score = clamp(
  base_score
  + pairwise_adjustment
  + validation_efficiency_bonus   # 0..3
  + upside_optionality_bonus      # 0..2
  - red_team_penalty              # 0..15
  - portfolio_overlap_penalty,    # 0..5
  0, 100
)
```

`validation_efficiency_bonus`は低コスト・短期間・強い行動証拠を取れる案に付く。`upside_optionality`は成功時の拡張性だが、需要証拠を上回る最大2点に制限する。

## 10. Portfolio selection

単純上位3件ではなく、制約付き選定。

目的関数例:

```text
maximize Σ(selected_i * [
  0.55 * final_score_i
+ 0.20 * learning_value_i
+ 0.15 * upside_i
+ 0.10 * speed_i
])
```

制約:

- total validation cost <= budget
- 同一clusterから原則1案
- S3 unresolvedは最大1案
- 3案の最大不確実性が完全同一にならない
- 少なくとも1案は強い行動証拠（data/LOI/payment）を30日以内に問える

## 11. Bias prevention

- ブラインド化。
- generator/evaluator分離。
- 固定Rubric anchor。
- random A/B順。
- 過去winner文言の除去。
- modelのself-confidenceをscoreに使わない。
- evaluator outputを互いに見せない。
- 重要数値はcalculatorで再計算。
- 最終理由に反対Evidenceを最低1件含める。
- 人間overrideの履歴を監査し、特定案への一貫した甘さを検出。

## 12. Market evidence overrides

市場行動が増えたらscoreを更新するが、原scoreを上書きしない。

| Event | scoreへの扱い |
|---|---|
| positive comment | 原則更新なし |
| detailed request | demand evidence補助 |
| internal referral | reachability/demandを更新 |
| data shared | data access/demandを強く更新 |
| procurement/approval started | payer/budgetを強く更新 |
| LOI/reservation | willingnessを更新 |
| paid pilot | demand/payerを最高水準へ近づける |
| retained/expanded | recurring/economic valueを更新 |
| churn | risk/economic assumptionsを反証 |

各更新は新しいevaluation versionとして保存する。

## 13. 評価出力例

```json
{
  "idea_id": "I-001",
  "evaluation_round": 1,
  "blinded_packet_id": "BP-09",
  "evaluator_id": "commercial-referee@1.0.0",
  "scores": {
    "payer_and_budget": {"score": 6, "confidence": 0.70, "reason_codes": ["CURRENT_OUTSOURCING_EVIDENCE"]},
    "economic_value": {"score": 5, "confidence": 0.45, "reason_codes": ["COST_UNKNOWN"]}
  },
  "unknowns": ["actual contract value", "software budget discretion"],
  "prompt_version": "cr-2026-09-04.1",
  "model": "configured-model",
  "input_hash": "sha256:..."
}
```
