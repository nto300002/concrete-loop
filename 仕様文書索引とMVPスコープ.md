# Concrete Loop 仕様文書索引とMVPスコープ v1.1

## 1. 目的と適用範囲

本書は、Concrete Loopの実装開始時に参照する文書の正本、優先順位、状態、MVP境界を定める。GitHub Issue #1の完了条件である「このリポジトリ単体で、実装対象とその根拠文書を追跡できること」を満たすための索引である。

本書は機能仕様そのものを重複記載しない。仕様間に差分または矛盾がある場合の解決順序と、実装可能なMVP境界を定める。

## 2. 文書の状態と優先順位

### 状態

| 状態 | 意味 | 実装での扱い |
| --- | --- | --- |
| `CONFIRMED` | 採用済みの仕様 | 実装・テストの根拠にする |
| `CANDIDATE` | 採用判断前の候補 | 実装根拠にしない |
| `SUPERSEDED` | 後継文書に置き換えられた仕様 | 履歴として保持し、後継文書を優先する |
| `REFERENCE` | 補助説明またはUI検討資料 | 明示的に参照された範囲だけを利用する |
| `UNTRACKED` | リポジトリ内で保存場所・最新版を追跡できない参照 | 実装根拠にしない |

### 解決順序

1. [Concrete Loop プロダクト仕様 改訂版](Concrete_Loop_プロダクト仕様_改訂版.md)の最上位原則を優先する。
2. D-08〜D-12、Recovery最終確定追記、Test Strategy確定基準は、対象領域について先行するD-01〜D-07を補完・上書きする。
3. D-11は状態の責務分離、D-12は削除・鍵・再現性・External Source状態・文書管理の境界を優先して定める。
4. [Application / Rust境界契約](Application_Rust境界契約.md)はDesktopの権限・Transaction・DTO境界を定め、[技術構成 v1](技術構成_v1.md)は実装構成を定める。
5. [Test Strategy確定基準](Test_Strategy確定基準.md)のMVP必須Gateは、個別仕様の受入条件より優先して満たす。
6. 同一優先度で矛盾する場合は実装を開始せず、差分を新しいDecision文書として記録する。

### 明示的な差分解決

| 領域 | 優先する仕様 | 置き換え・補完される内容 |
| --- | --- | --- |
| 派生内容を含む完全削除 | D-12 A | D-04の削除規則を、内容再構成可能な派生データまで拡張する |
| Recovery / Backup鍵世代 | D-12 B、Recovery最終確定追記 | D-02・D-03の鍵管理を、Candidate GenerationとCommit安全性まで補完する |
| 再現性 | D-12 C | D-07等の「再現可能」をExecution ReproducibilityとHistorical Verifiabilityへ分離する |
| 外部ソースの欠損 | D-12 D | D-08・D-11の`SOURCE_MISSING`相当を、未観測・権限喪失・対象外・削除確認へ分離する |
| 文書管理・機能範囲 | D-12 E、本書 | 文書の追跡方法とMVP / LATER / OUT_OF_SCOPEを確定する |
| 外部書き込み | Test Strategy確定基準 | MVP外とし、機能追加時のRelease Gateへ割り当てる |

## 3. MVPスコープ

### MVP

| 領域 | MVPで提供する範囲 | 根拠 |
| --- | --- | --- |
| 実行基盤 | macOS Desktop、Tauri 2、SQLite + SQLCipherを正式SSOTとする | D-01、プロダクト仕様改訂版、技術構成 v1 |
| 保護 | App Unlock、Keychain利用、DB鍵分離、Lock時の平文破棄 | D-02、D-11、Recovery最終確定追記 |
| 入力 | TXT・Markdown・JSON Import、ユーザー起点のNotion Pull | D-08、技術構成 v1 |
| Source管理 | External Source / Artifact / Version / ImportBatch、原文・版・由来の追跡 | D-05、D-08、D-12 D |
| Question Workspace | Question、Source、Fragment / Code、Variable / Measurement、Dataset、Analysis、Evidence、Insight、Reflectionの往復 | プロダクト仕様改訂版、D-09、D-10、画面遷移設計 |
| AI補助 | 明示操作によるCode Proposal、Alternative Interpretation、Learning Tutor | プロダクト仕様改訂版、D-06 |
| AI安全性 | immutableなRequest / Outcome / Proposal / UserDecision、送信前同意、`UNKNOWN`処理 | D-06、Test Strategy確定基準 |
| Python分析 | 同梱Pyodide Worker、許可済み固定Template、基礎集計・相関・移動平均 | D-06、D-07、技術構成 v1 |
| データ保護 | 暗号化Backup、空の別環境へのRestore、Restore Crash Recovery、Permanent Delete | D-03、D-04、D-12 A-B、Recovery最終確定追記 |
| 知見と学習 | Evidenceを伴うInsight、構造化Reflection、Learning Note | D-09、D-10 |

### LATER

| 領域 | 後続に回す範囲 | 境界 |
| --- | --- | --- |
| Notion等へのPublish | Learning Note / Insightの外部書き込み | 明示操作であっても外部書き込みのRelease Gateを別途定義する |
| AIによるInsight Candidate | 複数Source・過去Insight・矛盾候補を横断した候補生成 | MVPのAI 3機能には含めない |
| AIによる文章整理 | Learning Noteの文章構成提案 | User Draftを上書きしない原則は維持し、追加時にAI安全性を検証する |
| 高度な分析 | 回帰、機械学習、Network Analysis、Topic Modeling、自由Python編集 | MVPの固定Template分析の外側として扱う |
| Windows Desktop | Platform Adapterを利用したWindows対応 | macOS Desktop MVPの後に検証する |
| Webのローカル保存 | IndexedDBを正式SSOTにしない限定的なWeb利用 | Desktopとの役割・データ移送を別途設計する |

### OUT_OF_SCOPE

| 領域 | 対象外の範囲 |
| --- | --- |
| モバイル | Android、iOS |
| Cloud Sync | 自動クラウド同期、マルチデバイス同期 |
| 双方向同期 | バックグラウンド同期、Conflict解消、Merge |
| 心理の自動診断 | 疾患推定、深層心理・人格の確定、治療的CBT介入、認知の歪みの自動判定 |
| 自由実行 | 任意Python、任意外部Package取得、Workerからのネットワーク・DB・Secretアクセス |

## 4. MVP必須品質Gate

以下は実装済みかつPassしたときにだけMVP完成と判定する。Test Strategyの確定は、これらのテストが実装済みであることを意味しない。

| Gate | 実装前に固定する観測対象 |
| --- | --- |
| Pyodide計算正当性 | 固定統計規約、期待値Fixture、演算別の許容誤差 |
| 暗号化Backup | 暗号化済みBackupと鍵世代の対応 |
| 空の別環境への完全Restore | `active_generation_id = null`からの明示Commit |
| Restore Crash Recovery | Candidate / Candidate Security作成中のCrash後の状態 |
| Permanent Delete | 既知派生内容の削除・Redactと自由記述のImpact Review |
| Lock中Command拒否 | 平文破棄と、Lock中の保護Command拒否 |
| Analysis Complete冪等性 | 同一完了通知で結果が重複保存されないこと |
| Import Retry / Version整合 | Retryが新しいImportBatchを作り、Versionを不整合にしないこと |
| Source Sanitization | 表示・処理経路で外部ソースを安全に扱うこと |
| AI Request `UNKNOWN` | Provider応答を受信しても永続化前に失われた場合を`UNKNOWN`として記録・解決すること |

## 5. 文書索引

`revision`は文書内の版番号、`commit`はGit履歴（`git log -- <path>`）で追跡する。実装Issueは、`CONFIRMED`文書集合をGit tag `spec-baseline-v1.1`で固定して参照する。表中の`Git history`は履歴追跡用であり、実装時の可変参照ではない。最新版だけを残すのではなく、`supersedes`で置換関係を表す。

| document_id | title / storage_location | version | commit / revision | status | supersedes / referenced_by |
| --- | --- | --- | --- | --- | --- |
| P-01 | [Concrete Loop プロダクト仕様 改訂版](Concrete_Loop_プロダクト仕様_改訂版.md) | 改訂版 | Git history | CONFIRMED | 既存の上位原則・D-01〜D-07を統合。全実装仕様が参照 |
| D-01 | [プラットフォーム構成](プラットフォーム構成_確定事項.md) | 1.0 | Git history | CONFIRMED | TECH-01が実装境界を補完 |
| D-02 | [起動時保護方式と暗号鍵管理](D-02_起動時保護方式と暗号鍵管理.md) | 1.0 | Git history | CONFIRMED | D-12 B・SEC-01がRecoveryの詳細を補完 |
| D-03 | [ポータブル暗号化バックアップと復元](D-03_ポータブル暗号化バックアップと復元.md) | 1.0 | Git history | CONFIRMED | D-12 B・SEC-01が鍵世代を補完 |
| D-04 | [削除と保持モデル](D-04_削除と保持モデル.md) | 1.0 | Git history | CONFIRMED | D-12 Aが派生内容の削除規則を補完 |
| D-05 | [Entity CardinalityとDomain Model](D-05_Entity_CardinalityとDomain_Model.md) | 1.0 | Git history | CONFIRMED | DOMAIN-01・D-11・D-12により詳細化 |
| D-06-D-07 | [AIとPython学習機能 最終仕様](D-06_D-07_AIとPython学習機能_最終仕様.md) | 最終版 | Git history | CONFIRMED | P-01、D-12 C、TECH-01、TEST-01が補完 |
| D-08 | [External Source IntegrationとSync Contract](D-08_External_Source_IntegrationとSync_Contract.md) | 1.0 | Git history | CONFIRMED | D-12 D・本書のPublish境界が補完 |
| D-09 | [Insight Lifecycleと知見管理](D-09_Insight_Lifecycleと知見管理.md) | 1.0 | Git history | CONFIRMED | 本書がAI Insight CandidateをLATERに限定 |
| D-10 | [LearningとReflection Model](D-10_LearningとReflection_Model.md) | 1.0 | Git history | CONFIRMED | 本書がAI文章整理・PublishをLATERに限定 |
| D-11 | [State Model](D-11_State_Model.md) | 0.1 | Git history | CONFIRMED | Root / Version / Event / Projectionの責務分離を定義 |
| D-12 | [DB Schema補完仕様 A-E](D-12_DB_Schema補完仕様_A-E.md) | 最終版 | Git history | CONFIRMED | D-01〜D-11の補完仕様 |
| SEC-01 | [Recovery最終確定追記](Recovery最終確定追記.md) | 最終確定 | Git history | CONFIRMED | D-02・D-03・D-12 BのRecovery Commit安全性を補完 |
| TEST-01 | [Test Strategy](Test_Strategy確定基準.md) | 1.0 | spec-baseline-v1.1 | CONFIRMED | Gate、Fixture、期待結果、実行時点。全実装Issueが参照 |
| TECH-01 | [技術構成 v1](技術構成_v1.md) | 1.0 | spec-baseline-v1.1 | CONFIRMED | D-01・D-06-D-07の実装構成を補完 |
| APP-01 | [Application / Rust境界契約](Application_Rust境界契約.md) | 1.0 | spec-baseline-v1.1 | CONFIRMED | Desktopの権限・Transaction・DTO境界。TECH-01を具体化 |
| DOMAIN-01 | Concrete Loop Domain詳細定義 v0.1（保存場所未登録） | 0.1 | — | UNTRACKED | このリポジトリ単体では保存場所・最新版・確定状態を追跡できない。追加・索引化されるまで実装根拠にしない |
| UI-01 | [画面遷移設計 説明資料](画面遷移設計_説明資料.md) | 1.0 | Git history | CONFIRMED | P-01、D-08〜D-11をUIへ接続 |
| UI-02 | [UIモック索引](design/mockups/README.md) | 1.0 | Git history | REFERENCE | UI-01に従属する静的モック |
| LEGACY-01 | [心理データ分析学習アプリ プロダクト原則](心理データ分析学習アプリ_プロダクト原則.md) | 1.0 | Git history | SUPERSEDED | P-01へ統合。原則の履歴として保持 |
| LEGACY-02 | [要件定義書v0.1 原則整合性レビュー](要件定義書v0.1_原則整合性レビュー.md) | 0.1 | Git history | REFERENCE | 初期レビュー。現行仕様との衝突時はP-01以降を優先 |
| R-01〜R-08 | 保存場所未登録 | 不明 | — | UNTRACKED | リポジトリ単体では保存場所・最新版・確定状態を追跡できない。追加・索引化されるまで実装根拠にしない |

## 6. TDDへの接続

各実装Issueは、着手前に本書のMVP項目と対応する`CONFIRMED`文書をIssue本文へ記載する。次に、受入条件を満たさない状態を再現するテストを先に追加し、そのテストを通す最小実装を行う。

仕様だけを変更するIssueでは、コードテストの代わりに次を完了条件とする。

1. 文書索引にID、保存場所、版、状態、後継・参照関係がある。
2. 各機能が`MVP`、`LATER`、`OUT_OF_SCOPE`のいずれか一つに分類される。
3. 既存仕様との差分と優先順位が明記される。
4. `git diff --check`とリンク先ファイルの存在確認に成功する。

## 7. Issue #1の完了判定

- [x] リポジトリだけでMVP対象・後続対象・対象外を判別できる。
- [x] AI MVP 3機能、AI Insight Candidate、AI文章整理、Notion Publishの境界を明記した。
- [x] 文書の正本、優先順位、状態、後継関係、未追跡R-01〜R-08を記録した。
- [x] 実装Issueが参照すべき確定文書とMVP必須品質Gateを固定した。

## 8. 更新規則

新しい仕様は、本文書の索引行を追加した後にのみ`CONFIRMED`として扱う。既存文書を変更して意味のある差分が生じる場合は、`version`を更新し、置き換えられた仕様には`SUPERSEDED`または補完関係を記録する。
