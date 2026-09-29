# D-10：Learning / Reflection Model

## 目的

Reflectionは分析結果の文章要約ではない。何を問うたか、何を観察したか、どう解釈したか、何が未解決か、数値化で何を失ったか、以前の理解から何が変わったか、次に何を問うかを明示する工程である。

```text
Analysis → Insight → Reflection → Learning Note → Next Question
```

## InsightとLearning Note

```text
Insight       = What I currently think
Learning Note = How and why my understanding changed
```

Insightは現在時点の主張・仮説、Learning NoteはInsightやAnalysisに至る過程の振り返りである。両者を同じ文章として扱わない。

MVPでは`QUESTION`、`ANALYSIS`、`INSIGHT_REVIEW`、`TOPIC`、`PERIOD`のNote Typeを扱い、中心は`QUESTION`とする。

## Domain Model

```text
LearningNote
     ├── 1:1 LearningNoteDraft
     └── 1:N LearningNoteVersion
                 └── 1:N LearningNoteReference

ReflectionSession ── N:M Input Reference
     └── 0..1 LearningNoteVersion

LearningEvent
LearningSelfAssessment
ReflectionPromptTemplate
```

`LearningNote` RootはIdentityとLifecycleを持つ。本文は持たず、本文はVersionへ保存する。

```text
LearningNote
  id, note_type, current_version_id, created_at,
  lifecycle_status, archived_at, trashed_at

LearningNoteVersion
  id, learning_note_id, version_no, markdown_body,
  created_at, created_by, origin_type,
  previous_version_id, change_reason
```

Draftはmutable、Versionはimmutableとする。Auto SaveはDraftへの保存であり、Version確定ではない。Versionはユーザーの明示保存、Reflection終了、Notion Publish、重要Insight変更後などで作成できる。

## Reflection構造

次の観点を利用可能にするが、すべてへの回答を強制しない。

```markdown
## 今回の問い
## 最初に考えていたこと
## 実際に行ったこと
## 観測されたこと
## 自分の解釈
## 反例・違和感
## まだ分からないこと
## モデル化によって失われた可能性のあるもの
## 以前の理解から変わったこと
## 次に確かめたいこと
```

System FactとUser Reflectionを分離する。Question、対象期間、N、欠損、変数、Transformation、PythonCodeArtifact、AnalysisResult、Insight、不確実性は既存Recordを参照するSystem Factであり、本人の意味づけはUser Reflectionである。

System FactをMarkdownへ固定コピーしすぎず、`LearningNoteReference`として関連を保存する。ReferenceはQuestionVersion、HypothesisVersion、ExternalArtifactVersion、Fragment、Transformation、DatasetSnapshot、AnalysisRun、AnalysisResult、InsightVersion、ExternalConceptVersion、PythonCodeArtifact、LearningEvent等を対象とできる。

```text
SOURCE | ANALYZED | LEARNED_FROM | SUPPORTS_REFLECTION |
CONTRADICTS | RELATED | NEXT_STEP
```

## ReflectionSessionとPrompt

ReflectionSessionは振り返った活動自体を表すimmutable Eventとする。

```text
id, trigger_type, started_at, completed_at,
prompt_set_version, input_refs, ai_assisted,
created_learning_note_version_id
```

Triggerは`USER_INITIATED`、`ANALYSIS_COMPLETED`、`INSIGHT_REVIEW`、`QUESTION_REVIEW`、`PERIODIC_REVIEW`を扱う。ただし自動で画面遷移・入力強制しない。

Promptは2〜4個程度を提示し、Analysis Type、Insight Type、Counter-Evidence、不確実性、既存Reflection、Learning Conceptに応じて選ぶ。`ReflectionPromptTemplate`はVersion管理し、固定Ruleだけで生成できる。スキップ、「後で考える」、短文を許容し、Prompt Fatigueを避ける。

## AIの役割

AIは質問、反例の問い返し、過去Insight・Learning Noteとの差分候補、統計概念の説明を補助できる。本人に代わる学びの確定、Reflection全文の自動確定、Insightの自動更新は行わない。

ユーザーが明示依頼した文章整理は、`AIProposal → UserDecision → LearningNoteVersion`の経路を通す。User Draftを上書きしない。

## Learning Eventと理解度

`LearningEvent`は内面の理解ではなく、実際の操作事実をimmutableに記録する。

```text
VIEWED_EXPLANATION, CREATED_VARIABLE, CHECKED_MISSING_VALUES,
RAN_PEARSON, RAN_SPEARMAN, VIEWED_PYTHON, MODIFIED_PARAMETER,
REVIEWED_EVIDENCE, REVIEWED_COUNTER_EVIDENCE, COMPLETED_REFLECTION
```

ConceptとSkillを分け、Learning StateはEventから`NOT_STARTED`、`EXPOSED`、`PRACTICED`として導出するProjectionとする。Systemは`UNDERSTOOD`や`MASTERED`を自動判定しない。

本人の理解度は`LearningSelfAssessment`として別Eventに保存し、`UNCLEAR`、`PARTIAL`、`COMFORTABLE`、`CAN_EXPLAIN`等を記録できる。

Prerequisiteは弱いRelationとし、未学習Conceptを理由に分析機能を原則ロックしない。Questionから必要な分析、Concept、Skillを提示するQuestion Firstの導線とする。

## 次の問い、Notion、Export

Reflectionから`QuestionCandidate`と`InsightCandidate`を作成可能とする。いずれもユーザーReview前に正式Question・Insightへ昇格しない。

Concrete Loop内部のLearning Noteは、分析と直接結びついた構造化Reflectionの正本とする。NotionへのPublishは明示操作とし、Publish後のNotion編集は内部Versionを自動更新しない。再利用する場合はD-08のExternalArtifactとしてPull Importする。

LearningNoteVersionはMarkdown Export可能とする。本文、Question・Analysis・Insightの概要、不確実性、関連Conceptを展開できるが、日記原文は既定で含めない。

## 受入条件

```text
AC-LEARN-01  Learning Noteを内部で作成・編集できる。
AC-LEARN-02  Draftとimmutable Versionを分離する。
AC-LEARN-03  過去Versionを閲覧できる。
AC-LEARN-04  NoteからQuestion、Analysis、Insight、Transformation、Evidenceへ辿れる。
AC-LEARN-05  System FactとUser Reflectionを区別できる。
AC-LEARN-06  Prompt回答を強制しない。
AC-LEARN-07  使用したPrompt Versionを記録できる。
AC-LEARN-08  AIが学習内容を自動確定しない。
AC-LEARN-09  操作事実をLearningEventとして記録できる。
AC-LEARN-10  SystemがUNDERSTOOD / MASTEREDを自動判定しない。
AC-LEARN-11  LearningSelfAssessmentを別途記録できる。
AC-LEARN-12  ReflectionからQuestionCandidateとInsightCandidateを作成できる。
AC-LEARN-13  候補は承認なしに正式Entityにならない。
AC-LEARN-14  Markdown Exportできる。
AC-LEARN-15  Notion Publishは明示操作を必要とする。
AC-LEARN-16  Publish後のNotion変更が内部Versionを自動上書きしない。
AC-LEARN-17  Reflection履歴から理解の時間的変化を再構築できる。
```

## 中心原則

Learning Noteは単なるメモ帳ではない。**具体から抽象へ進んだ分析を人間の言葉へ戻し、次の問いを生む場所**である。
