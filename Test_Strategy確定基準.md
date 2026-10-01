# Test Strategyの確定基準

本戦略は、次の条件を満たした時点で**実装計画の正本**として確定する。

1. 本文と採用済み修正を一つの版へ統合し、MVP対象機能と後続機能のGateを区別している。
2. MVPの主要受入条件について、テスト層、Fixture、観測する結果、実行タイミングを対応付けている。
3. Pyodideの統計規約を固定したうえで期待値Fixtureを作成し、演算ごとに適切な数値比較の許容誤差を定めている。
4. Lock、Crash、Retry、Restore、外部送信について、Fault地点と期待状態を一対一で定義している。Provider応答を受信していても永続化前に失われた場合は`UNKNOWN`として扱う。
5. Permanent Deleteでは、Provenanceが明確な既知の派生内容に対する自動削除・Redactと、関係を機械判定できない自由記述のImpact Reviewを分離して検証する。
6. AI Requestの`UNKNOWN`処理をMVP必須Gateに含める。MVP外の外部書き込み機能は、その機能を追加する際のRelease Gateへ割り当てる。

## 文書確定とMVP完成の違い

Test Strategyを確定する時点で、定義されたテストが実装済み・Pass済みである必要はない。

```text
Test Strategy確定
= 何を、どう、いつ検証するかが決まっている

MVP完成
= 定義したMVP必須Gateが実際にPassしている
```

## MVP完成の必須Gate

```text
Pyodide計算正当性
暗号化Backup
空の別環境への完全Restore
Restore Crash Recovery
Permanent Delete
Lock中Command拒否
Analysis Complete冪等性
Import Retry / Version整合
Source Sanitization
AI Request UNKNOWN処理
```

これらの必須Gateに失敗している状態では、MVP完成扱いとしない。

## テスト層・Fixture・観測・実行時点

| Gate | 層 | Fixture / Fault | 期待結果 | 実行時点 |
| --- | --- | --- | --- | --- |
| Schema / Version | Rust SQLCipher integration | 同Root/別Root Version、空本文、Migration世代 | FK・Trigger・原子rollback・新Schema拒否 | 各PR |
| 暗号化DB / Backup | Rust security integration | 正鍵・誤鍵・無鍵・平文を含むDB | 無鍵/誤鍵は読めず、平文がファイルに残らない | 各PR / Release |
| Pyodide計算 | Worker contract | 欠損、同順位mode、variance、rolling、相関 | 固定統計規約・演算別tolerance | 各PR |
| Permanent Delete | Rust integration + E2E | 既知派生・自由記述・過去Run | delete/redact、Impact Review、Evidence導出 | 各PR / Release |
| Restore / Crash | Fault integration | Candidate作成、Keychain作成、Commit前後Crash | 旧pointer維持、新Macは自動採用しない | Release |
| Lock | Security contract | Lock中query/mutation、Frontend cache | Command拒否、平文非返却 | 各PR |
| Analysis Complete | Rust contract | 同一completionを重複配送 | Resultは一度だけ保存、Retryは新Run | 各PR |
| Import | Adapter contract | 更新、未観測、権限喪失、Retry | 新Batch、Version整合、削除誤判定なし | 各PR |
| Sanitization | UI / E2E | HTML/URLを含む外部本文 | 実行されずSafe Presentationのみ | 各PR |
| AI `UNKNOWN` | Fault integration | 応答後・Outcome保存前Crash | `UNKNOWN`、重複送信なし | 各PR / Release |

Pyodideは欠損規則・標本/母分散をTemplate IDに固定する。mode同順位は昇順全件、rolling window未満は`null`。count/mean/medianは完全一致、分散・標準偏差・相関は絶対誤差`1e-12`、複合演算は`1e-9`以下とする。

## Fault地点

| Fault地点 | 期待状態 |
| --- | --- |
| Candidate DB / Candidate Keychain作成中 | active pointerは旧Generationまたはnull、旧Keyは未変更 |
| Import item保存前 | Retryは新Batch |
| Analysis結果保存前 / 後 | 未保存または一回だけ保存 |
| Provider応答受信後・Outcome保存前 | `UNKNOWN` |
| Permanent Deleteの派生走査中 | Primary Dataを先に物理削除しない |

MVP外のPublish等の外部書き込みは、同形式のRelease Gateを追加するまで実装しない。
