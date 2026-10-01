# Concrete Loop Application / Rust境界契約 v1.0

## 権限境界

React/TypeScriptはユーザー意図を表現し、Rust Application Serviceが認可、不変条件、Transactionを実行し、SQLCipher Repositoryだけが正本を変更する。

```text
React Component → TypeScript Use Case / Port → Tauri Command
→ Rust Application Service → Domain Rule → Repository → SQLCipher
```

- ReactはSQL、DB鍵、Keychain値、SQLCipher connection、外部Provider秘密情報を扱わない。
- Tauri CommandはDTO変換と呼出しだけを担い、Domain判断を持たない。
- Root/Version/Event/Relationの作成、`current_version_id`更新、削除影響判定、Import、Analysis完了、AI Outcomeの永続化はRustの単一Transactionで行う。
- RustはLock状態と権限に応じたPresentation DTOだけを返す。Lock中は保護Commandを拒否し、Frontendは参照ID・画面位置以外の平文を保持しない。
- ユーザー入力をSQL、Python、Prompt文字列へ直接補間しない。ApplicationでAllowlist・型・範囲検証して固定Templateへ渡す。

## Command契約

| 種別 | Request | Rustが検証すること | Response |
| --- | --- | --- | --- |
| Mutation | ID、構造化Parameter、明示操作 | Unlock、Lifecycle、FK/Version所有、入力範囲、Transaction | 新規ID・Version・状態 |
| Query | ID、表示範囲 | Unlock、参照可能性、Redaction | Safe Presentation DTO |
| External effect | Scope、同意、idempotency key | Unlock、同意、送信対象、Outcome永続化 | immutable Request/Outcome ID |
| Lock / Unlock | 明示要求 | Keychain/Local Authentication、メモリ破棄 | lock stateのみ |

失敗時は部分永続化を残さない。外部AIは応答受信後かつ永続化前にCrashした場合`UNKNOWN` Outcomeを残す。各契約はTEST-01のRust Contract / Security Contract層で検証する。
