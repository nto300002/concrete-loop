# D-12：DB Schema補完仕様 A〜E

## 位置づけ

本書は、DB Schema正式化前に補完する最終仕様である。D-01〜D-11とDB Schemaレビューを前提に、削除、鍵ライフサイクル、再現性、外部Source状態、MVP範囲と文書索引を定める。

## A. Delete & Derived Content Policy

Permanent Deleteは、Source RootやFragmentだけでなく、削除対象の内容を保持・引用・実質的に再構成できる派生データまで影響範囲を確認する。

対象例は、Fragment、Measurement Evidence、AnalysisResult、InsightVersion、Reflection、LearningNoteVersion、AIProposal、AI Context、Error Log、その他の自由記述である。

原文引用、行単位データ、削除対象内容を実質的に再構成できる文章は削除または欠損化する。集約統計や非機微メタデータで、削除対象を再構成できないものは保持可能とする。

`USER_DERIVED`または独立解釈であっても、内容から削除対象を再構成できる場合は無条件に保持しない。自動判定できない自由記述は、Permanent Delete前の影響範囲確認対象としてユーザーへ提示する。

`input_hash`等も短文照合に利用できる可能性がある。不要なら削除し、保持が必要な場合は単純Hashでなく鍵付きHMAC等を検討する。

```text
ACTIVE → TRASHED → Permanent Delete要求 → 派生Content影響範囲確認
→ 削除 / Redact / 欠損化 → Primary Data物理削除
→ 必要最小限の監査情報のみ残存
```

原文削除後、集約統計のみの過去AnalysisResultは閲覧可能とする。原文引用・行単位値を含むResultは削除または欠損化する。必要な入力Recordが削除済みなら、過去条件で新しいAnalysisRunは作成できない。

## B. Recovery / Backup Key Lifecycle

各Backupは、`backup_id`、`key_id`、`created_at`、`encryption_version`を持つ。

Recovery Key未発行、発行済み、再発行後を区別する。Recovery Key未発行時に自動Backupを許可するなら、そのBackupをどの方法で復元できるか明示する。

Recovery Key再発行後、旧Backupが新Keyで自動復元できるとはみなさない。旧Backupについては「旧Keyを安全に保持」「新Keyで再暗号化」「旧世代を復元対象外」のいずれかを明示的に選ぶ。

```text
Recovery Key未発行 → Recovery Key発行（key_id = K1）
BackupはK1で復元可能 → Recovery Key再発行（key_id = K2）
旧BackupはK1依存、新BackupはK2依存
```

Backup一覧では`key_id`と復元可能状態を確認できる。対応Keyを保持するBackupのみ復元でき、復元不能なBackupはUIで明示する。

## C. Reproducibility Contract

再現性を次の2軸に分ける。

### Execution Reproducibility

過去Runと同じ条件で、新しいAnalysisRunを作成できること。必要条件は、同じDatasetSnapshot参照条件、必要な元Recordの残存、同じCode Artifact、同じExecution Environment、同じParametersである。

### Historical Verifiability

過去Runについて、何を入力し、何を実行し、何が得られたかを確認できること。AnalysisRunはimmutableな履歴として保持する。

入力Recordの一部がPermanent Deleteされた場合、Historical Verifiabilityは全部または一部を維持できるが、Execution Reproducibilityは失われ得る。残存Recordだけで再分析する場合は、過去Runの部分再実行ではなく、新DatasetSnapshotと新AnalysisRunを作る。

```text
全入力・Code・Environmentが存在 → Execution Reproducible
入力の一部削除 → Execution Not Reproducible
Run / Result / Metadataが残存 → Historical Verifiabilityは維持または部分維持
```

「同一Runの再実行」という表現は使用しない。AnalysisRunはimmutableであり、再度分析する場合は必ず新しいAnalysisRunを作る。

## D. External Source Missing Contract

「今回取得できなかった」と「削除を確認した」を区別する。ExternalArtifact系の外部状態は、`AVAILABLE`、`NOT_OBSERVED`、`ACCESS_LOST`、`OUT_OF_SCOPE`、`DELETION_CONFIRMED`を区別する。

Providerが削除を明示するなど、十分な根拠がある場合だけ`DELETION_CONFIRMED`とする。API通信失敗、Token期限切れ、権限喪失、Sync対象範囲変更、Provider側Filter変更、一時的な不可視状態は削除扱いしない。

```text
AVAILABLE → 今回見つからない → NOT_OBSERVED
NOT_OBSERVED → 権限問題ならACCESS_LOST
NOT_OBSERVED → 対象外化ならOUT_OF_SCOPE
NOT_OBSERVED → Provider削除確認ならDELETION_CONFIRMED
```

過去Snapshotは保持する。Notion Pageが一覧から消えただけで、Concrete Loop側のArtifactを削除しない。

## E. MVP Scope / Document Index

各機能を`MVP`、`LATER`、`OUT_OF_SCOPE`のいずれかに分類する。

仕様文書は、`document_id`、`title`、`storage_location`、`version`、`commit / revision`、`status`、`supersedes`、`referenced_by`で索引化する。

文書statusは`DRAFT`、`CANDIDATE`、`CONFIRMED`、`SUPERSEDED`を扱い、`DRAFT → CANDIDATE → CONFIRMED → SUPERSEDED`の遷移を追跡可能にする。

最新版だけを残すのでなく、どの仕様が何に置き換えられたかを追跡可能にする。リポジトリから追跡できない仕様については、欠落と断定せず「このリポジトリ単体では保存場所・最新版・確定状態を追跡できない」と表現する。

## 共通検証シナリオ

A〜Cでは、次を独立して判定する。

1. 過去結果を閲覧できるか。
2. 過去結果の根拠を確認できるか。
3. 過去Runと同じ条件で、新しいAnalysisRunを作成できるか。

## 最終優先順位

```text
A. Delete & Derived Content Policy
B. Recovery / Backup Key Lifecycle
C. Reproducibility Contract
↓
D. External Source Missing Contract
E. MVP Scope / Document Index
↓
Application / Rust境界
Test Strategy
実装
```
