# D-11：State Model

## 基本方針

Concrete Loopでは、状態を単一の`status`へ押し込まない。次の独立した状態軸として扱う。

```text
Lifecycle
External Source State
Process State
Draft State
Insight Assessment
Evidence Integrity Projection
Workspace Context
Security / App Lock
```

この分離により、`ACTIVE + SOURCE_MISSING + Draftあり`のような複数状態を同時に表現する。

## Lifecycle

通常Entityの内部Lifecycleは次を基本とする。

```text
ACTIVE
↓
TRASHED
↓ Permanent Delete実行
Primary DBから物理削除
```

`PERMANENTLY_DELETED`は通常Entityの永続statusではない。概念上の終端または削除コマンドの完了結果として扱う。必要な場合だけ、削除済み内容を含まない`DeleteCompleted` Eventまたは最小Tombstoneを残す。

## External Source State

`SOURCE_MISSING`はExternalArtifact系だけに適用し、Lifecycleとは分離する。

```text
UNKNOWN
AVAILABLE
SOURCE_MISSING
```

通信障害、認証エラー、Provider障害は`SOURCE_MISSING`としない。最終確認時刻、最終成功同期時刻、失敗理由はImportBatch等の実行履歴で扱う。

```text
ExternalArtifact
Lifecycle: ACTIVE
External Source State: SOURCE_MISSING
```

は正常に成立する。

## Workspace ContextとApp Lock

Workspace Contextは、Question Workspaceから画面遷移・App Lockを経ても作業位置を戻すための参照情報である。

```text
question_id
question_version_id
selected_tab
source_version_id
scroll_position
draft_id
```

App Lock時には以下をFrontendの平文メモリから破棄・非表示化する。

```text
原文
Fragment本文
Draft本文
AI Context
Source Viewer内容
```

Unlock後に、Rust側から必要な内容を再取得する。DB KeyはRust側でのみ利用し、Reactへ渡さない。

## DraftとVersion

Draftの編集状態とVersion作成Eventを分離する。

```text
CLEAN
↓ 編集
DIRTY
↓ Draft保存
DRAFT_SAVED
↓ Checkpoint
LearningNoteVersion V1作成
↓
Draftは継続
↓
DRAFT_SAVED / CLEAN
↓
再編集
```

`VERSION_CREATED`はDraftの終端statusではない。Checkpointはimmutable Versionを作るEventであり、DraftはVersion作成後も継続編集できる。

画面離脱、Source切替、App Lock時に`DIRTY`なら、Draft保存またはユーザー確認を行う。

## Process State

### AnalysisRun

```text
PENDING → RUNNING → SUCCEEDED | FAILED | CANCELLED
```

Run作成前にDatasetSnapshot、PythonCodeArtifact、ExecutionEnvironment、Parametersを固定する。Retryは必ず新しいAnalysisRunを作る。

`CANCELLED`後にWorkerから結果が返っても保存しない。取消の結果、既存データ・過去Runを変更しない。

### ImportBatch

```text
PENDING → RUNNING → SUCCEEDED | PARTIAL_SUCCESS | FAILED | CANCELLED
```

Retryは既存ImportBatchを更新せず、新しいImportBatchとして記録する。項目単位の成功・未変更・更新・削除検出・失敗をImportBatchItemで扱う。

### Dataset

```text
PREVIEW_BUILDING → PREVIEW_READY | PREVIEW_FAILED
PREVIEW_READY → CONFIRMING → SNAPSHOT_CREATED | SNAPSHOT_FAILED
```

Previewは一時状態、Snapshotはimmutable Entityである。Snapshot生成はTransactionで原子的に完了させ、失敗時に部分的Snapshotを残さない。Filter・Variable等の変更は既存Snapshotを更新せず、新Previewから新Snapshotを作る。

## Insight AssessmentとEvidence Integrity

Insight RootのLifecycle、InsightVersionのsemantic payload、Assessment、Evidence Integrityを混同しない。

```text
Insight Root
Lifecycle: ACTIVE | ARCHIVED | TRASHED

Current InsightVersion
Assessment: UNASSESSED | INSUFFICIENT | SUPPORT_LEANING |
            MIXED | CONTRADICTION_LEANING

Evidence Projection
Integrity: COMPLETE | PARTIALLY_MISSING | EVIDENCE_MISSING
```

Evidence IntegrityはInsightVersionのstatusではない。EvidenceLink群の参照可能性から導出するProjectionである。Evidenceの削除・復元で変化しても、InsightVersionのimmutableな本文を更新しない。

## 状態設計の原則

```text
Lifecycle
≠ External Availability
≠ Process Result
≠ Draft State
≠ Evidence Assessment
≠ Evidence Integrity
≠ UI Context
≠ Security State
```

各状態はRoot、Version、Event、Projectionの責務を越えて流用しない。これにより、Versioning、削除、復元、分析履歴、Source Missing、App Lockが互いに干渉せず管理できる。

## 根拠

確定済みConcrete Loop D-01〜D-10、R-01〜R-08、Domain詳細定義、主要Sequence、画面遷移設計、およびState Modelレビューを基準とする。外部論文・外部データは使用していない。
