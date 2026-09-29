# D-06 / D-07：AI機能とPython学習機能（最終仕様）

> **改訂状況（2026-09-28）**：本書のAIイベント連鎖、Context Boundary、Pyodide Worker、固定Template、オフライン分析の仕様は維持する。正式な上位仕様は[Concrete Loop：プロダクト仕様（D-01〜D-07 改訂版）](Concrete_Loop_プロダクト仕様_改訂版.md)とする。D-06には、ユーザーが取得・選択したChatGPT等の外部会話を`ExternalArtifact`としてImportする拡張点、およびCross-source Candidateを追加する。

## 共通原則

AIは「考える作業」を奪わず、Pythonは「分析する作業」を隠さない。

- AIは、構造化、代替解釈、反証、学習の候補を示す補助者であり、心理分析の主体ではない。
- Pythonは、GUI上の分析をどのデータ・前処理・コード・環境で実行したかを理解するための学習機能である。
- AIは**追跡可能性（traceability）**を目標とし、外部LLMの出力を必ずしも再現可能とは扱わない。
- Pythonは、DatasetSnapshot、CodeArtifact、ExecutionEnvironmentを固定して、可能な限りの**計算再現性（computational reproducibility）**を目標とする。

---

# D-06：AI機能

## 役割とMVP機能

AIは、次の3機能のみを提供する。

1. 選択されたJournalFragmentまたはReadingFragmentに対するコード候補の提示
2. ユーザーが作った解釈・コードに対する別解釈または反証候補の提示
3. 統計、データ分析、質的研究、Python操作を説明するLearning Tutor

確率値を心理的事実の確率として誤解させる表示は原則使用しない。

心理診断、疾患推定、深層心理・人格の確定、日記全体の自動分析、コード・変数の自動確定、治療的CBT介入、認知の歪みの自動判定、因果関係の確定、バックグラウンドでの日記全件解析はMVP外とする。

Learning Tutorでは、心理原文が不要な質問に日記原文をContextへ含めない。

## AIイベントモデル

AIの各段階をimmutable Eventとして分離する。

```text
AIRequest [immutable]
   ↓
AIRequestOutcome [immutable]
   ↓ 成功時
AIProposal [immutable]
   ↓
UserDecision [immutable]
```

`AIRequest`は依頼した事実であり、結果状態を更新しない。`AIRequestOutcome`が`SUCCEEDED`、`FAILED`、`CANCELLED`のいずれかを表す。AIProposalは成功したRequestの結果であり、UserDecisionは`ACCEPT`、`MODIFY_AND_ACCEPT`、`REJECT`等の本人の判断を表す。

`MODIFY_AND_ACCEPT`ではProposalを更新せず、新しいCodeAssignmentまたはUserInterpretationを作成し、`origin_ai_proposal_id`を持たせる。

## Context Boundaryとデータ最小化

Context Scopeを次の3段階に固定する。

| Scope | 内容 |
| --- | --- |
| S1 | 選択したFragmentのみ。既定値。 |
| S2 | Fragmentと、ユーザーが選択したCodeDefinition / VariableDefinition。 |
| S3 | ユーザーが明示選択した複数FragmentまたはReading Record。 |

日記全体や他の日記を暗黙に取得しない。実行前には送信するEntity・Versionと送信しない範囲を確認でき、ユーザーの明示操作でのみRequestを行う。

AIRequestには送信本文を複製保存しない。代わりに次を保存する。

```text
input_refs
input_entity_versions
input_hash
context_scope
provider
model_identifier
prompt_template_version
parameters
consented_at
requested_at
```

原文をPermanent Deleteした後は、参照を`MISSING`とし、hashだけを残す。これにより送信の事実は追跡できるが、削除した文章をAI監査データから復元できない。

AIのエラー、監査ログ、分析履歴に原文・送信本文・応答中の引用断片を重複保存しない。削除対象の断片がAIProposalやログに含まれる場合、その内容を削除または欠損化する。

## AI Provider境界

```text
Application
     ↓
AiGateway
     ↓
AiProviderAdapter
     ↓
External AI API
```

Frontendから外部AI APIを直接呼ばない。Desktop MVPではReact → Tauri Command → Rust AiGateway → External AIの経路を使い、API KeyはOS Secure Storeで管理する。Web版では開発者所有の秘密API Keyを使用しないため、正式なAI機能はDesktop版を基本とする。

日記・読書本文はAIへの命令ではなく分析対象データである。Request Builderは`INSTRUCTION`、`TASK`、`USER_DATA`を分離し、本文中の命令らしい文字列を上位指示として扱わない。

## D-06受入条件

```text
AC-AI-01  選択されていない日記を暗黙にContextへ含めない。
AC-AI-02  AI実行前に送信対象とVersionを確認できる。
AC-AI-03  AI Proposalはユーザー承認なしに正式データへ変換されない。
AC-AI-04  AIRequest、Outcome、Proposal、UserDecisionを別Recordとして保存する。
AC-AI-05  修正採用後も元Proposalを保持する。
AC-AI-06  心理診断・疾患判定を正式分析結果として保存できない。
AC-AI-07  AI出力からInput Versionまで追跡できる。
AC-AI-08  Provider、Model Identifier、Prompt Version、Parametersを記録する。
AC-AI-09  失敗・取消時に元データや既存分析を変更しない。
AC-AI-10  Learning Tutorは不要な心理データをContextへ含めない。
AC-AI-11  Permanent Deleteされた本文をAI監査Recordから復元できない。
```

---

# D-07：Python学習機能

## 目的とRuntime

Python機能は任意のPython開発環境ではない。GUI上の分析に対応するデータ、前処理、Pythonコード、結果を理解し、一部の安全な操作を自分で行えるようにする。

MVPのRuntimeは**Pyodide + Web Worker**とする。

```text
React Application
      ↓
PythonRunner Interface
      ↓
PyodidePythonRunner
      ↓
Pyodide Worker
      ↓
Python / 固定許可Package
```

PythonRunnerはApplication層に置く。React画面からPyodideを直接呼び出さず、将来はDesktopPythonSidecarRunnerへ交換可能とする。

## 配布・オフライン方針

Pyodide Full Distributionや全パッケージの同梱は避ける。固定バージョンのPyodide Coreと、MVPで許可する最小パッケージ集合（基本はNumPy、pandas）をアプリへ同梱する。

実行時にCDN、PyPI、`micropip`等から外部パッケージを追加取得しない。SciPy等は、統計検定や高度な機能が必要になった段階で明示的に追加する。

Desktop版では、初回起動時から次をNetworkなしで実行可能とする。

```text
日記・読書記録
Coding
Variable
Transformation Ledger
Python基礎分析
過去Analysis閲覧
```

外部AIはオンラインが必要であり、Offline対応の対象外である。

## DB・原文・Capability境界

```text
SQLCipher
   ↓
Application Service
   ↓
DatasetSnapshot
   ↓
必要なTabular Dataのみ生成
   ↓
Pyodide Worker
```

Python RuntimeはPrimary DB、SQLCipher、日記本文、読書本文、Tauri Command、Keychain、Backup、AI Secretを直接参照できない。MVPではMeasurement、Code count、date、category、numeric feature等の構造化済みデータだけを渡す。

Workerの入出力を以下に限定する。

```text
Input:  dataset, analysis_type, validated_parameters, generated_code
Output: result, stdout, warnings, execution_metadata
```

## 許可コードと構造化Parameter

MVPで自由なPythonコード編集・実行は許可しない。実行できるのはアプリが生成・許可した固定Templateだけとする。

ユーザー入力はPythonコードではなく、検証済みの構造化Parameterとして受け取る。

```text
Analysis Type: MEAN
Parameters: { columnId: VARIABLE_123 }
       ↓
Applicationが型・範囲・許可リストを検証
       ↓
columnIdを許可済みColumn名へ解決
       ↓
固定Python Templateを選択
```

ユーザー入力をコード文字列へ直接補間してはならない。

MVPの対象は、データ確認、欠損・件数・頻度、平均、中央値、最頻値、分散、標準偏差、割合、Pearson・Spearman相関、時系列の並べ替え・移動平均とする。回帰、機械学習、Network Analysis、Topic Modeling等はMVP外とする。

## 多層的なNetwork・Secret保護

PyodideはHTTP APIやJavaScript連携を持つため、WebAssemblyまたはCSPだけをSecurity Sandboxとみなさない。以下を同時に適用する。

```text
1. 自由Pythonを実行させない
2. pyfetch等を含むTemplateを生成しない
3. 外部Package取得を禁止する
4. CSPのconnect-srcを必要最小限に制限する
5. WorkerへTauri APIを渡さない
6. WorkerへSecretを渡さない
```

Workerはローカルに同梱したPyodide assetsだけを使用し、Python分析処理は外部Networkを必要としない。

## 学習段階

```text
P1 Observe
GUI操作と対応Pythonコードを見る。

P2 Guided Edit
column、window等の安全なParameterだけを変更する。

P3 Predict & Run
実行前の予想を任意で記録し、結果と比較する。
```

## 再現性と実行履歴

```text
Question
↓
AnalysisPlanVersion
↓
DatasetSnapshot
↓
PythonCodeArtifact
↓
ExecutionEnvironment
↓
AnalysisRun
↓
AnalysisResult
```

`PythonCodeArtifact`は、`analysis_plan_version_id`、`code`、`code_hash`、`generator_version`、`created_at`を持つimmutable Entityとする。

`ExecutionEnvironment`は、`runtime = PYODIDE`、runtime version、Python version、package versions、environment hashを持つ。AnalysisRunはDatasetSnapshot、CodeArtifact、ExecutionEnvironmentを参照する。

Pythonによる前処理はTransformation Ledgerにも記録し、Reason、Gain、Loss、Assumptionを対応付ける。実行に成功したRunはimmutableであり、再実行は新しいRunを作る。

## D-07受入条件

```text
AC-PY-01  GUI処理に対応するPythonコードを確認できる。
AC-PY-02  実行対象は必ずDatasetSnapshotとして固定される。
AC-PY-03  RuntimeからPrimary DBを直接参照できない。
AC-PY-04  MVPでは許可済みの固定Templateだけを実行する。
AC-PY-05  Guided Editは許可されたParameterだけを変更できる。
AC-PY-06  Parameterは検証済み構造化データとして扱い、コードへ直接補間しない。
AC-PY-07  RunからCodeArtifact、Snapshot、Environmentへ追跡できる。
AC-PY-08  結果から元データ・Transformationへ戻れる。
AC-PY-09  失敗・取消時に既存データを変更しない。
AC-PY-10  Pyodide処理はWeb Workerで実行しUIを長時間Blockしない。
AC-PY-11  Python分析は外部Networkを必要としない。
AC-PY-12  Runtime・Python・Package Versionを記録する。
AC-PY-13  同じSnapshot・Code・Environmentによる再実行が可能である。
AC-PY-14  初回起動時から基礎Python分析をオフラインで実行できる。
AC-PY-15  実行時の外部Package追加取得を行わない。
```

## 関連するD-05拡張

次のEntityをD-05のDomain Modelへ追加する。

```text
AIRequest
AIRequestOutcome
PythonCodeArtifact
ExecutionEnvironment
```

AIのRecordは追跡可能性を、PythonのRecordは追跡可能性と計算再現性を担保する。
