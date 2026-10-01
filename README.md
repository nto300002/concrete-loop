# Concrete Loop

Concrete Loopは、外部ソース・自分の記録・分析結果を往復しながら、データ分析を学ぶためのmacOS Desktopアプリです。人間を数値で定義するのではなく、原文・構造化データ・数値・モデルを行き来し、常に具体的な原文へ戻れることを最上位原則にします。

## 現在の段階

現在はMVP実装前の仕様確定・TDD準備段階です。実装はGitHub Issueの受入条件を満たすテストから開始します。

仕様の正本、優先順位、MVP境界、文書の状態は[仕様文書索引とMVPスコープ](仕様文書索引とMVPスコープ.md)を参照してください。実装時に参照する文書は、同索引で`CONFIRMED`かつMVP対象として登録されたものに限ります。

## MVPの要約

- macOS Desktopを正式SSOTとし、SQLite + SQLCipherでローカルに保存する。
- TXT・Markdown・JSONと、ユーザー起点のNotion Pullを取り込み、原文・版・由来を保持する。
- Question Workspaceで、原文、コード、変数、Dataset、分析、Evidence、Insight、Reflectionを往復する。
- AIは明示的な操作によるコード候補、別解釈、学習チューターだけを補助する。
- Pythonは同梱Pyodideの固定Templateによる基礎分析だけを実行する。
- Backup / Restore、Permanent Delete、Lock、Import、AI Request `UNKNOWN`をMVP必須品質Gateで検証する。

## リポジトリ構成

- `*.md`：確定・候補の仕様文書
- `design/mockups/`：画面遷移の静的モック
- `仕様文書索引とMVPスコープ.md`：実装開始時の唯一の文書入口

## 実装上の原則

「Reactは操作する。Rustは守る。Pythonは分析する。」

詳細は[技術構成 v1](技術構成_v1.md)を参照してください。
