# D-08：External Source Integration / Sync Contract

## 位置づけ

Notion、生成AI、ファイル等が主要な入力Sourceとなる改訂後のConcrete Loopにおいて、外部データを何として、いつ、どこまで取り込むかを定める。

外部Sourceからの削除とConcrete Loop内部の削除は別操作とし、外部の正本を尊重しながら、分析根拠となる取得時Snapshotと履歴を保持する。

## 決定一覧

| 項目 | 決定 |
| --- | --- |
| Source Identity | `provider + external_id`で外部対象を識別し、内部UUIDとは分離する。 |
| Import単位 | Source種類ごとに固定する。 |
| Version判定 | `external_updated_at`と`content_hash`で判定する。 |
| Sync方式 | MVPはユーザー起点のPull。 |
| Sync範囲 | ユーザーが選択した範囲のみ。Workspace全体を暗黙に取得しない。 |
| 外部削除 | Concrete Loopでは`SOURCE_MISSING`として履歴・Snapshotを保持する。 |
| Write-back | 明示的なPublishだけ。双方向自動同期はMVP外。 |
| Credential | OS Secure Storeで保護する。 |
| Partial failure | ImportBatchに項目単位で成功・失敗を記録する。 |
| AI会話 | ConversationとMessageの構造を保持する。 |

## SourceごとのImport単位

Source固有の構造を単なる文章へ潰さない。

```text
NotionDatabase
    ↓
NotionPage
    ↓
Page Snapshot

Conversation
    ↓
Message
    ↓
Message Snapshot

File
    ↓
File Version
```

AI会話はConversation全体を巨大な一枚の文章にせず、User MessageとAssistant Messageを個別に保持する。これにより、本人の発言、AIの提案、特定Questionに関係するMessageを分けて扱える。

## IdentityとVersion

External IDを内部Primary Keyにしない。

```text
ExternalArtifact
  id: Concrete Loop内部UUID
  source_type: NOTION | AI_CONVERSATION | FILE | ...
  provider: Notion | ChatGPT | Claude | LocalFile | ...
  external_id: Source側のID
```

同期時のVersion判定は以下とする。

```text
Sync
 ↓
external_updated_at確認
 ↓
content_hash比較
 ↓
変更なし → ExternalArtifactVersionを追加しない
変更あり → ExternalArtifactVersionを追加する
```

ExternalArtifactVersionには、少なくとも`source_type`、`external_id`、`source_created_at`、`source_updated_at`、`imported_at`、`content_hash`を保持する。

## 外部削除と内部削除

外部Sourceで削除されたArtifactは、Concrete Loopから自動削除しない。

```text
Notion Page: DELETED
        ↓
Concrete Loop: ExternalArtifact.source_status = SOURCE_MISSING
```

過去のSnapshotと分析根拠を保持する。一方、ユーザーがConcrete Loop内でPermanent Deleteを実行した場合は、D-04の削除規則に従う。

> Sourceから消えたことと、Concrete Loopから消すことは別操作である。

## Pull SyncとImportBatch

MVPの同期はユーザー操作で行うPull型とする。

```text
同期
 ↓
更新確認
 ↓
変更Page / Message / Fileのみ取得
 ↓
ExternalArtifactVersionを作成
 ↓
ImportBatchとして結果を保存
```

同期結果は、たとえば以下を表示・保存する。

```text
新規        3
更新        2
変更なし   18
削除検出    1
失敗        0
```

`ImportBatch`は`source`、`started_at`、`finished_at`、`new_count`、`updated_count`、`unchanged_count`、`failed_count`等を持つEventとする。`ImportBatchItem`で個々のArtifactごとの結果、失敗理由、作成されたVersion参照を保持する。

## Publish

Concrete LoopからNotion等への書き戻しはSyncではなく、明示的な**Publish**とする。

```text
Insight
↓
Learning Note生成
↓
ユーザー確認
↓
Publish to Notion
```

バックグラウンドの双方向同期、Conflict解消、MergeはMVP外とする。

## 共通Schema

```text
ExternalSource
   │
   └─< ExternalArtifact
           │
           └─< ExternalArtifactVersion

ImportBatch
   │
   └─< ImportBatchItem
           │
           └─ ExternalArtifactVersion

SourceReference
```

この共通SchemaとProvider Adapterにより、Notion、ChatGPT、Claude、Markdown、JSON、PDF等を将来追加できる。

## 受入条件

```text
AC-SOURCE-01  ユーザーが選択していないWorkspace、Database、Page、Conversationを取得しない。
AC-SOURCE-02  同一のproviderとexternal_idに対応する内部Artifactを一意に特定できる。
AC-SOURCE-03  変更のない同期では新しいVersionを作成しない。
AC-SOURCE-04  外部更新時も既存Snapshotを上書きしない。
AC-SOURCE-05  外部削除はSOURCE_MISSINGとして記録し、過去Snapshotを自動削除しない。
AC-SOURCE-06  ImportBatchから項目単位の成功、更新、未変更、削除検出、失敗を確認できる。
AC-SOURCE-07  一部Import失敗時にも、成功済みItemと既存データを失わない。
AC-SOURCE-08  Publishはユーザーの明示操作でのみ実行する。
AC-SOURCE-09  Source CredentialをDB、ログ、Frontendへ平文保存しない。
AC-SOURCE-10  AI会話はConversationとMessageの階層を保持してImportできる。
```

## 次の設計判断

D-08の次はD-09「Insight Lifecycle」、続いてD-10「Learning Note / Reflection Model」、D-11「状態遷移全体」を定める。
