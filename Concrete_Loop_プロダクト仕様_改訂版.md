# Concrete Loop：プロダクト仕様（D-01〜D-07 改訂版）

本書を、既存のプロダクト原則およびD-01〜D-07に対する**正式な上位仕様**とする。既存文書と矛盾する場合は本書を優先する。

技術実装上の責務境界は[技術構成 v1](技術構成_v1.md)を参照する。

## プロダクトの再定義

Concrete Loopは汎用の日記・ノートエディタではない。Notion、外部生成AI、自身の分析活動など複数の情報源から生まれる記録を、出自、取得時点、変更履歴とともに統合し、思考と理解の変化を長期的に追跡・分析する**Personal Knowledge Analysis環境**である。

```text
External Source
Notion / 外部AI Conversation / Import File / Concrete Loop独自データ
        ↓
Source Snapshot → Structure → Transformation → Dataset → Analysis
        ↓                                      ↓
Learning Note ← Reflection ← Insight ← Evidence / Counter-Evidence
        ↓
新しいQuestion・Notion・生成AI
```

Concrete Loopが担うのは、Source統合、Snapshot、Version、Provenance、Fragment、Coding、Variable、Measurement、Transformation Ledger、Dataset Snapshot、Python、基礎統計、可視化、Evidence、Counter-Evidence、Insight、不確実性、Traceabilityである。

Notion等には汎用日記エディタ、Wiki、高度なMarkdown編集、長文Knowledge Management、一般的な読書ノート管理を委ねる。

## 上位原則

1. **分析ハブ**：既存ツールを再実装せず、複数Sourceの統合・関係付け・分析・理解の変化の追跡に集中する。
2. **外部正本の尊重**：Notion PageはNotion、外部AI会話は外部サービスが正本。Concrete Loopは取得時Snapshotを分析対象として保持する。独自データはConcrete Loopが正本である。
3. **原文・Snapshotの非上書き**：ExternalArtifactとExternalArtifactVersionを用い、外部更新で過去Versionを変えない。
4. **具体への復帰**：原文 → Fragment → Code → Variable → Dataset → Analysis → Insight → Evidence → 原文の往復を保つ。
5. **モデル非同一視**：統計、AI、Embedding等は特定の問い・Source・前処理・定義・仮定から生まれる表現であり、本人そのものではない。
6. **情報損失の保存**：TransformationにReason、Gain、Loss、Assumptionを保存し、不明・未検討も明示する。
7. **出自の分離**：RAW、USER_DERIVED、AI_PROPOSED、EXTERNAL、SYSTEMと、作成者・確定者・着想元・根拠を分ける。
8. **AIは思考を代替しない**：候補、反証、矛盾、学習解説を示すが、心理・人格・疾患・因果を確定しない。
9. **Pythonは過程を隠さない**：GUIに対応するPythonを見せ、安全な分析Runnerとして提供する。
10. **Question First**：問いからデータ、Code、Variable、前処理、分析方法を導く。
11. **データ量と真実性を混同しない**：文章量、記録頻度、選択的記録、欠損、Source Biasを同時に扱う。
12. **Insightは仮説**：InsightはHYPOTHESIS、SUPPORTED、CONTESTED、SUPERSEDED等の検討状態とEvidence・Counter-Evidenceを持つ。
13. **思考変化の保存**：Insight、Learning Note、Question、ConceptはVersion管理し、理解の変化を分析対象とする。

## D-01〜D-04：プラットフォーム、鍵、Backup、削除

- React + TypeScript + ViteによるSPAを、Web BrowserとTauri 2 / Rust Desktopで共有する。
- MVPのConcrete Loop内部データの正式SSOTはmacOS Desktop版のSQLite + SQLCipher。Web版はUI、学習、限定的ローカル分析、サンプルデータに用い、正式SSOTにしない。
- Database、File System、Backup、Secret Store、External Connector、AI GatewayはPlatform Adapterへ隔離し、Domain/ApplicationからTauri APIを直接呼ばない。
- Desktop起動はTouch ID優先、App Passwordをフォールバックとする。DB Keyは乱数生成しKeychain等に保護し、App Passwordと分離する。Recovery Keyを発行可能にする。
- BackupはExportと別の暗号化`.clbackup`であり、Recovery Key由来の鍵で別Macへ復元できる完全Snapshotとする。1日1回の自動Backup、任意の手動Backup、Daily 7 / Weekly 4 / Monthly 6の世代管理、復号・整合性・Schema検証を行う。
- Primary DataはACTIVE → TRASHED → PERMANENTLY_DELETED。30日後も自動完全削除せず、明示操作を要する。従属する個人データをCascade Deleteし、共有定義は残す。Backup、Export、外部AI、外部コピーは自動削除保証の対象外である。

## D-05：Domain Model

EntityをRoot、Version、Event、Relationに分け、意味を持つVersion/Eventは原則immutableとする。

```text
Root + Version
ExternalArtifact / ExternalArtifactVersion
JournalEntry / JournalEntryVersion
ReadingRecord / ReadingRecordVersion
CodeDefinition / CodeDefinitionVersion
VariableDefinition / VariableDefinitionVersion
Question / QuestionVersion
Hypothesis / HypothesisVersion
AnalysisPlan / AnalysisPlanVersion
Insight / InsightVersion
LearningNote / LearningNoteVersion
ExternalConcept / ExternalConceptVersion
```

- ExternalArtifactはNotion、外部AI Conversation、Import File等の外部Sourceを統一的に表す。Versionにはsource type、external ID、Sourceの作成・更新時刻、取り込み時刻、content hashを保存する。
- ImportBatchは取り込みをEvent化し、件数・成否・時刻を保存する。
- Fragmentは特定のSource Versionへ固定する。CodeAssignmentはFragmentとCodeDefinitionVersionを結ぶRelation、MeasurementはVariableDefinitionVersionを参照するimmutable Eventとする。
- TransformationはN:MのInput / Outputを取り、DatasetSnapshotはimmutable record IDとVersion参照を固定する。
- AnalysisPlanVersion → DatasetSnapshot → AnalysisRun → AnalysisResultを基本とし、EvidenceはSUPPORTS / CONTRADICTS / SOURCE / CONTEXT等を持つ独立Relationとする。
- AIはAIRequest → AIRequestOutcome → AIProposal → UserDecisionのimmutable Event連鎖とする。
- LearningNoteReferenceにより、ReflectionとSource・Insight・Analysisを結び付ける。

## D-06：AI

MVPではCode Proposal、Alternative Interpretation、Learning Tutorを許可する。将来的には、関連する過去記録・Insight・反証・矛盾の候補提示も行えるが、正式採用はユーザーだけが行う。

ContextはS1（選択Fragment）、S2（Fragment + 選択定義）、S3（明示選択した複数Source）に限定し、既定はS1とする。AI Requestはユーザー操作でのみ開始し、送信本文を複製保存しない。input refs、input versions、input hash、Scope、同意時刻、Provider、Model、Prompt version、要求時刻を保存し、AIには追跡可能性を求めるが同一出力の再現性を保証しない。

ProviderはApplication → AiGateway → AiProviderAdapterの経路とし、Frontendから直接呼ばない。ChatGPT等の外部会話も、Export、Connector、Markdown、JSON、手動Import等でExternalArtifactとして取り込める設計とする。

## D-07：Python / Analysis Runtime

MVPでは固定VersionのPyodide Core、NumPy、pandas等の最小許可Packageをアプリに同梱し、Web Workerで実行する。Full Distribution、実行時のCDN・`micropip.install()`・外部Package取得を前提にしない。

Python RuntimeはSQLCipher DB、原文、Tauri API、Keychain、Backup、AI Secretへ直接アクセスしない。ApplicationがDatasetSnapshotから必要なTabular Dataだけを生成してWorkerへ渡す。MVPでは自由Python Editorを提供せず、Allowlist、型・範囲検証済みの構造化Parameterから固定Python Templateを選ぶ。入力をPythonコード文字列へ直接補間しない。

Workerは外部Networkを必要とせず、自由コード禁止、固定Template、Parameter検証、外部Package取得禁止、狭いCSP、Worker分離、Tauri API・Secret非公開を多層的に適用する。

AnalysisRunにはDatasetSnapshot、PythonCodeArtifact、ExecutionEnvironment、Parametersを固定する。CodeArtifactにはcode、hash、generator versionを、Environmentにはruntime、Python、Package versions、environment hashを保存し、Python前処理はTransformation Ledgerに記録する。

Desktopでは日記・Source閲覧、Coding、Transformation、基礎Python分析、Analysis閲覧をオフラインで利用可能とする。外部AIとNotion同期はオンライン機能として分離する。

## Notion / External Source統合

- Notionを日記、読書記録、Question、Concept、Learning Note、長文思考の主要外部Sourceとして利用可能にする。
- MVPのNotion同期はPull型。ユーザーが選んだDatabase / Pageだけを対象にし、変更Pageを取得してExternalArtifactVersionを作る。
- Concrete LoopからNotionへの書き戻しは明示的なPublish操作とする。バックグラウンド双方向同期はMVP外。

## 一文定義

> **Concrete Loopは、Notion・生成AI・自分自身の分析活動から生まれる記録を、出自と時間的変化を保持したまま個人知識DBへ統合し、質的記述と数学的分析を往復しながら、仮説・反証・知見・理解の変化を長期的に育てるPersonal Knowledge Analysis環境である。**
