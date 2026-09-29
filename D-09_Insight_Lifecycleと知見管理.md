# D-09：Insight Lifecycle / 知見管理

## 目的と原則

Concrete LoopにおけるInsightは、複数の記録、分析、読書、AI対話を検討して形成された、現時点での理解・解釈・仮説である。真実、人格、心理属性、因果関係を確定するものではない。

```text
Observation ≠ Interpretation
Interpretation ≠ Cause
Association ≠ Causation
Insight ≠ Truth
AI Proposal ≠ Insight
```

Insightには、対象、期間・データ範囲、支持Evidence、反証Evidence、Evidenceと主張を結ぶ仮定、未解決の点を関連付ける。

## Insight Type

| Type | 意味 |
| --- | --- |
| DESCRIPTIVE | データ上で観測されたパターン |
| INTERPRETIVE | パターンに対する解釈・仮説 |
| METHODOLOGICAL | 分析方法について得た知見 |
| CONCEPTUAL | 読書・理論と経験の関係 |

DESCRIPTIVEとINTERPRETIVEを混在させず、観測と説明を分ける。

## Domain構造

```text
Insight
   ├─< InsightVersion
   ├─< InsightAssessment
   └─< InsightRelation >─ Insight

InsightVersion >─< EvidenceLink
```

既存の`EvidenceLink`をInsightでも再利用し、Insight専用Evidenceテーブルを重複して作らない。

### Insight Root

Insightは継続的に更新される理解のIdentityであり、主張本文を持たない。

```text
id
current_version_id
created_at
lifecycle_status: ACTIVE | ARCHIVED | TRASHED
archived_at
trashed_at
last_reviewed_at
```

### InsightVersion

InsightVersionはimmutableとし、少なくとも次を持つ。

```text
id
insight_id
version_no
insight_type
claim
scope
warrant
qualifier
uncertainty_note
created_by
origin_type
created_at
previous_version_id
change_type
change_reason
```

`claim`は固定的な人格属性でなく、「このDatasetでは〜が観測された」「〜の可能性がある」といったスコープ付き表現を基本とする。

`scope`にはSubject、Period、Sources、Questionを記録する。`warrant`にはEvidenceからClaimを検討する論理を、`qualifier`には未統制の条件や限定を保存する。

## EvidenceとCounter-Evidence

EvidenceLinkは、最低限以下を扱う。

```text
SUPPORTS
CONTRADICTS
CONTEXT
QUALIFIES
SOURCE
```

対象にはExternalArtifactVersion、Fragment、CodeAssignment、Measurement、AnalysisResult、ReadingRecordVersion、ExternalConceptVersion、LearningNoteVersion等を使用できる。

`CONTRADICTS`は一級のRelationとし、支持Evidenceだけを表示して反証を隠すUIにしない。

新しいEvidenceやCounter-Evidenceが追加されても、既存InsightVersionの本文は更新しない。Evidence Baseの変化とClaimの変更を分離する。

## InsightAssessment

現在のEvidenceを踏まえた評価は、別のimmutable Eventとして保存する。

```text
InsightAssessment
  insight_version_id
  evidence_posture
  uncertainty_level
  assessment_note
  created_by
  created_at
```

Evidence Postureは以下を使用する。

```text
UNASSESSED
INSUFFICIENT
SUPPORT_LEANING
MIXED
CONTRADICTION_LEANING
```

Uncertaintyは`LOW | MEDIUM | HIGH | UNKNOWN`を任意記録できるが、AIやEvidence件数だけから自動決定しない。`PROVEN`、`TRUE`、Evidence件数からのConfidence Scoreは使用しない。

LifecycleとAssessmentを分離し、`ACTIVE + MIXED`のような状態を許容する。

## Version改訂とRelation

Claim、Scope、Warrant、Qualifierの意味が変わる場合は、新しいInsightVersionを作る。過去Versionは削除せず、その時点の理解として保存する。

変更種別は以下を扱う。

```text
REFINED
SCOPE_CHANGED
QUALIFIED
REINTERPRETED
REVERSED
```

Insight同士は`InsightRelation`で関連付ける。

```text
DERIVED_FROM
RELATED_TO
CONTRADICTS
REFINES
```

同一InsightのVersion更新と、別Insightから派生した新しい問いを混同しない。

## AI・Source追加との関係

AIはInsightを直接作成・更新しない。

```text
Source
↓
AIRequest
↓
AIProposal (INSIGHT_CANDIDATE)
↓
UserDecision
↓
Insight作成
```

AI由来の文章を採用しても、`origin_type = AI_PROPOSED`等で起源を保持する。AIは関連Insight、Counter-Evidence、矛盾候補を提示できるが、InsightVersionやEvidence Postureを自動更新しない。

NotionやAI Conversation等の新規Import後も全Insightを自動再計算しない。関連Evidence候補・Counter-Evidence候補をReview Queueへ提示し、ユーザーのReview後にEvidenceLinkを追加する。

## 作成、Learning Note、Publish、削除

Insightの基本フロー：

```text
Question
↓
Source / Datasetを検討
↓
Analysisと原文への復帰
↓
Insight Candidate
↓
Claim / Scope / Evidence / Counter-Evidence / Warrant / Qualifier / Uncertainty
↓
InsightVersion v1
```

Analysisなしで、読書と日記の質的比較からInsightを作ることも許可する。Learning Noteは`LearningNoteReference`を通じてInsightを参照し、本文への過剰な複製を避ける。

NotionへのPublishはPreviewとユーザー確認を経る明示操作とする。Publish後もInsightの正本はConcrete Loopにあり、Notion側の編集を自動でInsightVersionへ取り込まない。

Insightの通常削除はSoft Deleteとし、Permanent DeleteはD-04に従う。Insightを削除してもJournal、ExternalArtifact、AnalysisResult、Evidence Sourceは削除しない。

## 検索とTimeline

Keyword、Insight Type、Question、Concept、Evidence Posture、Period、Source Type、Related Insightで絞り込める構造とする。

Version、Evidence追加、Assessment、Analysis追加を時系列に表示し、「自分の理解がどのように変化したか」を再構築できるようにする。

## 受入条件

```text
AC-INSIGHT-01  Insightは少なくともClaimとScopeを持つ。
AC-INSIGHT-02  InsightVersion作成後のsemantic payloadは変更できない。
AC-INSIGHT-03  Claim変更時は新しいInsightVersionが作成される。
AC-INSIGHT-04  過去Versionを閲覧できる。
AC-INSIGHT-05  支持EvidenceとCounter-Evidenceを同時に保持できる。
AC-INSIGHT-06  Evidence追加だけでは過去InsightVersionを書き換えない。
AC-INSIGHT-07  Evidence PostureはInsightAssessmentとして別保存する。
AC-INSIGHT-08  Evidence件数からConfidence Scoreを自動生成しない。
AC-INSIGHT-09  AI Proposalはユーザー承認なしにInsightにならない。
AC-INSIGHT-10  Insightから根拠Sourceの特定Versionまで辿れる。
AC-INSIGHT-11  Insightから関連AnalysisResultとCounter-Evidenceへ辿れる。
AC-INSIGHT-12  新Version作成理由を確認できる。
AC-INSIGHT-13  Insight Timelineを再構築できる。
AC-INSIGHT-14  Insight削除によってEvidence Source自体を削除しない。
AC-INSIGHT-15  Notion Publishはユーザーの明示操作を必要とする。
```

## 中心原則

Insightは、**現在どこまでそう考える理由があり、どこから先はまだ分からないか**を記録するものである。画面の中心は結論ではなく、Claim、Scope、Warrant、Supports、Contradicts、Uncertainty、Historyとする。
