# Concrete Loop UIモック索引

画面構成は [`画面遷移設計_説明資料.md`](../../画面遷移設計_説明資料.md) に基づく。画像はレイアウトと情報量を検討するためのモックであり、表示データ・日時・数値は例示である。

## 採用済みの基準画面

- [問いのワークスペース：知見（ソースを閉じた初期状態）](question-workspace-insights-compact.png)

以前の高密度案 [`question-workspace-insights.png`](question-workspace-insights.png) は比較用に残す。以後の画面は、採用済みの低密度案に合わせる。

## トップレベル画面：提案モック

| 画面 | 主な初期表示 |
| --- | --- |
| [Home](home.png) | 最近の問いから再開する |
| [Sources](sources.png) | ソースと版の一覧。本文は閉じる |
| [Questions](questions.png) | 問いを選んでワークスペースへ入る |
| [Insights](insights.png) | 問いをまたぐ知見の一覧 |
| [Learning](learning.png) | 学習ノートと任意の振り返り |
| [Settings](settings.png) | Security、Backup、Notion、AI設定への入口 |

## 問いのワークスペース：提案モック

| 領域 | 主な初期表示 |
| --- | --- |
| [Overview](workspace-overview.png) | 問いと作業の再開地点 |
| [Sources](workspace-sources.png) | この問いに関連するソース |
| [Fragments & Codes](workspace-fragments-codes.png) | 抽出したフラグメントとコード |
| [Variables & Measurements](workspace-variables-measurements.png) | 変数定義と測定件数 |
| [Dataset](workspace-dataset.png) | 確定済みSnapshotの要約 |
| [Analysis](workspace-analysis.png) | 分析Runの要約と詳細への入口 |
| [Evidence](workspace-evidence.png) | 支持・反証の根拠を分けた要約 |
| Insights | 上記の採用済み基準画面 |
| [Reflection](workspace-reflection.png) | 任意の振り返り入力 |

## 共通UIの状態

- [Source Version Viewerを開いた状態](workspace-source-open.png)：必要なときにだけ右パネルを開く。閉じた状態を初期表示とする。

## 共通の表示方針

1. 初期表示は、その画面の主な作業と少数の要約に絞る。詳細は行・カードを開いて確認する。
2. Source Version Viewerは初期状態で閉じる。開いた場合もワークスペースを離れずに閉じられる。
3. ワークスペースの9領域は自由に移動でき、一本道の手順として表示しない。
4. 知見の支持・反証と不確実性を隠さず、断定的な真偽判定や自動信頼度スコアは表示しない。
5. 分析の履歴閲覧と再実行可能性は区別する。入力削除後の再実行を無条件に約束しない。

画像生成ツールで作成した静的モックのため、実装時の文言・状態・操作の正本は各仕様文書とする。
