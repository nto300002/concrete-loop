# Recovery最終確定追記

## 1. Candidate専用Local Security

新しいLocal Securityは、Commit前に既存Generationの認証情報へ上書きしてはならない。

Candidate Generationごとに、次を対応付けたCandidate専用のKeychain項目・鍵ラップとして新規作成する。

```text
candidate_generation_id
candidate_keychain_entry_id
candidate_wrapped_key
```

既存Macでは、Commit完了まで既存GenerationとCandidateを並存させる。

```text
Generation A
├─ DB-A
└─ Key-A

Candidate B
├─ DB-B
└─ Candidate Key-B
```

以下はCommit前に禁止する。

```text
Key-A
↓ overwrite
Key-B
```

### Commit前Crash

```text
active_generation_id = A
```

を維持する。Candidate BとCandidate Key-Bは未確定状態として扱い、Restore Journalからの再開またはCandidateだけを安全に破棄して再試行する。旧Generation AとKey-Aは影響を受けない。

### Commit後

Candidate Bが正式Generationになっても、旧AとKey-Aは既定の保持条件を満たすまで残す。

## 2. 新MacでのPointer未設定状態

新Macなど、既存Generationが一度も存在しない環境では、次を正規状態として許容する。

```text
active_generation_id = null
```

Recovery開始時の流れ：

```text
active_generation_id = null
↓
Candidate B作成
↓
Recovery Key検証
↓
Candidate Integrity Check
↓
Candidate用Local Security作成
↓
Candidate Unlock検証
```

この途中でCrashしても`active_generation_id = null`を維持し、Candidate Bを自動的に正式Generationへ昇格させない。

## 3. 新MacでのCrash Recovery

起動時に、以下の状態であれば`RECOVERY_REQUIRED`へ入る。

```text
active_generation_id = null
+
Restore Journalあり
```

以後、ユーザーはRestore JournalからRecoveryを再開するか、CandidateとCandidate Securityを破棄してRecoveryを最初から実行する。

正常に開けるCandidateが存在しても、それだけを理由に自動採用してはならない。

## 4. Commit条件

正式Commitは、以下をすべて満たした場合だけ許可する。

```text
Candidate DB検証成功
AND Recovery資格確認済み
AND Candidate専用Local Security作成済み
AND Candidate Local SecurityによるUnlock検証成功
AND ユーザー明示確認
```

これらを満たした後に初めて、`active_generation_id`をCandidate Generationへ更新する。

## 5. 受入条件

### 既存Mac

Candidate用Local Security作成中にCrashしても、以下を満たす。

```text
active_generation_id = old generation
old Keychain entry = intact
```

旧Generationを通常どおりUnlockできる。

### 新Mac

Candidate作成中にCrashしても、`active_generation_id = null`である。次回起動では通常Workspaceへ入らず、Recoveryへ戻る。

### CandidateがOpen可能な場合

Pointerが未設定、または旧Generationを指している場合、Candidateを自動的に正式化しない。

### Commit後

旧Generationおよび旧Keyは、保持条件を達成する前に削除しない。

## 最終原則

> **正式Pointerの切替前に、旧世代の復旧能力を壊さない。**

> **正式Pointerが未設定なら、Candidateを推測で正式化しない。**
