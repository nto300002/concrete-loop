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
