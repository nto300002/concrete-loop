# D-05：Entity Cardinality / Domain Model

> **改訂状況（2026-09-28）**：本書のimmutable Event、Version、Relationの設計は維持する。正式なD-05は[統合仕様](Concrete_Loop_プロダクト仕様_改訂版.md)を優先し、次を追加する：`ExternalArtifact / ExternalArtifactVersion`、`ImportBatch`、`Insight / InsightVersion`、`LearningNote / LearningNoteVersion / LearningNoteReference`、`AIRequest / AIRequestOutcome`。ExternalArtifactはNotion、外部AI Conversation、Import File等を統一し、外部SourceのSnapshotとVersionを保持する。

## 基本方針

Concrete LoopのEntityを次の4種に分ける。

- **Root Entity**：同じ対象であることを示すIdentity。current versionと削除状態等のLifecycle Metadataだけを変更可能とする。
- **Version Entity**：ある時点の内容・定義。作成後は原則immutableとする。
- **Event Entity**：測定、変換、分析実行、AI提案、ユーザー判断等の出来事。原則immutableとする。
- **Relation Entity**：Evidence、Transformationの入力・出力など、多対多関係を明示するデータ。

```text
Root
 ↓
Version
 ↓
Event
 ↓
Evidence / Transformation
```

## 中核Entity

| Domain | Root / Identity | Version / Event | 主な関係 |
| --- | --- | --- | --- |
| 日記 | JournalEntry | JournalEntryVersion | Entry 1:N Version |
| 日記断片 | — | JournalFragment | Version 1:N Fragment |
| 読書記録 | ReadingRecord | ReadingRecordVersion | Record 1:N Version |
| 読書断片 | — | ReadingFragment | Version 1:N Fragment |
| コード | CodeDefinition | CodeDefinitionVersion | Definition 1:N Version |
| コード付与 | — | CodeAssignment | Fragment N:M CodeVersion |
| 変数 | VariableDefinition | VariableDefinitionVersion | Definition 1:N Version |
| 測定 | — | Measurement | VariableVersion 1:N Measurement |
| 問い | Question | QuestionVersion | Question 1:N Version |
| 仮説 | Hypothesis | HypothesisVersion | Hypothesis 1:N Version |
| 変換 | — | Transformation | Input N:M Output |
| データ集合 | — | DatasetSnapshot | Snapshot 1:N Member |
| 分析計画 | AnalysisPlan | AnalysisPlanVersion | Plan 1:N Version |
| 分析実行 | — | AnalysisRun | PlanVersion 1:N Run |
| 分析結果 | — | AnalysisResult | Run 1:N Result |
| AI提案 | — | AIProposal | Proposal 1:N Decision |
| AI判断 | — | UserDecision | Proposal 1:N Decision |
| 外部概念 | ExternalConcept | ExternalConceptVersion | Concept 1:N Version |
| 出典 | Source | SourceVersion | Source 1:N Version |

## 日記と読書記録

```text
JournalEntry 1 ─< JournalEntryVersion 1 ─< JournalFragment
ReadingRecord 1 ─< ReadingRecordVersion 1 ─< ReadingFragment
```

`JournalEntry`は日記というIdentityであり、本文を持たない。`current_version_id`、`created_at`、`trashed_at`等を持つ。

本文は`JournalEntryVersion`に保存する。

```text
id
journal_entry_id
version_no
body
written_at
created_at
previous_version_id
```

本文の修正はUPDATEでなく新Versionの追加とする。`JournalFragment`は特定のVersionへ固定し、過去の分析根拠を最新版の編集で変化させない。

ReadingRecordVersionは`source_id`、`summary`、`user_interpretation`、`personal_relation`を分離して持つ。外部資料、本人の要約・解釈、本人の経験を混同しない。

## コードと変数

```text
CodeDefinition 1 ─< CodeDefinitionVersion
JournalFragment ─┐
ReadingFragment ─┼─< CodeAssignment >─ CodeDefinitionVersion
                 └────────────────────────────────────────
```

CodeDefinitionは概念のIdentity、CodeDefinitionVersionはその定義、CodeAssignmentは特定断片への付与判断である。Assignmentには`assigned_by`、`origin`、`created_at`を保持し、定義の変更で過去の意味を書き換えない。

```text
VariableDefinition 1 ─< VariableDefinitionVersion 1 ─< Measurement
Measurement N ─< MeasurementEvidence >─ N JournalFragment / ReadingFragment / CodeAssignment
```

Measurementは特定のVariableDefinitionVersionを必ず参照する。直接入力はEvidenceなしでも許容するが、`source_type = DIRECT_USER_INPUT`を保持する。

## Question・Hypothesis

```text
Question 1 ─< QuestionVersion
QuestionVersion 1 ─< Hypothesis
Hypothesis 1 ─< HypothesisVersion
```

HypothesisVersionは`created_at`と`created_phase`を持ち、`PRE_ANALYSIS`、`EXPLORATORY`、`POST_ANALYSIS`を区別する。AnalysisPlanは特定のQuestionVersionとHypothesisVersionを参照する。

## TransformationとDatasetSnapshot

Transformationは最初からN:Mとする。

```text
TransformationInput N ─< Transformation >─ N TransformationOutput
```

Transformation本体は`type`、`reason`、`gain`、`loss`、`assumption`、`executed_by`、`method`、`created_at`を持つ。入出力にはEntity type、ID、Version IDを記録する。訂正時は既存Transformationを更新せず、新しいTransformationを作る。

```text
DatasetSnapshot 1 ─< DatasetSnapshotMember
```

DatasetSnapshotはデータ本文を複製せず、AnalysisRun時点で選ばれたimmutable Recordの集合を固定する。Permanent Delete後はMemberを残して`source_status = MISSING`とし、AnalysisResultのEvidence状態に反映する。

## 分析とEvidence

```text
AnalysisPlan 1 ─< AnalysisPlanVersion 1 ─< AnalysisRun
AnalysisRun N ─1 DatasetSnapshot
AnalysisRun 1 ─< AnalysisResult
AnalysisResult N ─< EvidenceLink >─ N Fragment / Assignment / Measurement / ExternalConceptVersion
```

AnalysisPlanVersionには、変数、対象期間、分析方法、除外規則、パラメータ、Question、Hypothesisを持たせる。AnalysisRunは実行事実として、`run_at`、`code_version`、`environment_version`、`dataset_snapshot_id`、`status`を保存する。

AnalysisResultはimmutableとする。削除等で後から変化する根拠の状態は`AnalysisEvidenceStatus`のような別Entityで管理する。

EvidenceLinkは`SUPPORTS`、`CONTRADICTS`、`SOURCE`、`CONTEXT`等のrelationshipを持つ。支持証拠だけでなく、反証となる具体的記録も保存できる。

## Provenance、AI、外部概念

主要な派生Entityは少なくとも`created_by`、`origin_type`、`created_at`を持ち、EvidenceLinkとTransformationを通じて由来を追跡する。これはEntity・Activity・Agentを分けるW3C PROVの考え方を参考にするが、MVPでPROV-Oそのものは実装しない。

```text
AIProposal 1 ─< UserDecision
```

AIProposalとUserDecisionはともにimmutableである。修正採用時は`MODIFIED_AND_ACCEPTED`を記録し、生成されたCodeAssignment等に`origin_ai_proposal_id`を保持する。AI提案を本人が作ったデータに書き換えない。

```text
Source 1 ─< SourceVersion
ExternalConcept 1 ─< ExternalConceptVersion
```

ExternalConceptと本人の観察・測定を分離する。ExternalConceptと日記断片のEvidenceLinkは「関連する可能性」を表すだけで、本人の属性・診断を表さない。

## 削除と参照整合性

明確に従属する`JournalEntry → JournalEntryVersion → JournalFragment`等に限りDBのCascade Deleteを利用する。CodeAssignment、Evidence、分析履歴等を伴う削除はDomain Serviceが影響範囲を判断する。

SQLiteのForeign Key制約を有効化し、全接続の初期化時に`PRAGMA foreign_keys = ON`を実行する。親KeyはPrimary KeyまたはUNIQUEとし、検索頻度に応じて子側Foreign KeyにIndexを設定する。

## Cardinality原則

- Root → Version：原則1:N
- Version → 固有Fragment：1:N
- CodeDefinitionVersion → CodeAssignment：1:N。FragmentとCodeはCodeAssignmentを介した実質N:M
- VariableDefinitionVersion → Measurement：1:N
- TransformationのInput / Output：ともにN:M
- AnalysisPlanVersion → AnalysisRun：1:N
- AnalysisRun → AnalysisResult：1:N
- DatasetSnapshot → Member：1:N
- AnalysisResult ↔ Evidence：N:M
- AIProposal → UserDecision：1:N
- ExternalConcept ↔ Journal / Reading Fragment：EvidenceLink等を介したN:M

## 確定要件

```text
DOMAIN-01  Root EntityとVersion Entityを分離する。
DOMAIN-02  意味を持つVersion/Eventのsemantic payloadはimmutableとする。
DOMAIN-03  Root Entityはcurrent_versionやlifecycle情報のみ変更可能とする。
DOMAIN-04  主要概念はRoot + Version構成を基本とする。
DOMAIN-05  Fragmentは特定の原文Versionへ固定参照する。
DOMAIN-06  CodeAssignmentはFragmentとCodeDefinitionVersionを結ぶ中間Entityとする。
DOMAIN-07  Measurementは特定のVariableDefinitionVersionを参照する。
DOMAIN-08  Transformationは複数Input / Outputを扱えるN:M構造とする。
DOMAIN-09  AnalysisRunは特定のAnalysisPlanVersionとDatasetSnapshotを参照する。
DOMAIN-10  AnalysisResultはAnalysisRunから生成されるimmutable Eventとする。
DOMAIN-11  Evidenceは独立Relationとして保持し、支持・反証・根拠・文脈を区別する。
DOMAIN-12  AIProposalとUserDecisionを分離する。
DOMAIN-13  外部理論上のConceptと本人の観察・測定を分離する。
DOMAIN-14  SQLite Foreign Key制約をDBとApplication層の双方で守る。
DOMAIN-15  単純な従属EntityのみDB Cascade Deleteを許可し、分析履歴等の削除はDomain Serviceが制御する。
```

この構成により、`JournalEntryVersion → JournalFragment → CodeAssignment → Measurement → Transformation → DatasetSnapshot → AnalysisRun → AnalysisResult → Evidence → JournalEntryVersion`の循環が成立する。これは「具体 → 抽象 → 分析 → 具体」というConcrete Loopの原則をデータ構造として表したものである。
