# トランザクション / 並行制御 理解度チェックリスト

複数の更新を安全に行い、同時アクセスによるデータ不整合を防げるようになることを目指します。
「なぜデッドロックが起きたのか」「どの分離レベルを選ぶべきか」が判断できるようになることがゴールです。

---

## 📚 セクション1: ACID特性

### Q1. データベースの「ACID」のうち「Atomicity（原子性）」の意味は？

- A) トランザクション内の操作は「全て成功」か「全て失敗」のどちらかになる
- B) データは常に整合性のある状態を保つ
- C) 並行するトランザクションは互いに干渉しない
- D) コミットされたデータは永続化される

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
**Atomicity（原子性）**は「All or Nothing」の保証です。

```kotlin
transaction {
    // 操作1: レポートを保存
    ReportsTable.insert { ... }
    
    // 操作2: ユーザーの投稿数をインクリメント
    UsersTable.update({ UsersTable.id eq userId }) {
        it[postCount] = postCount + 1
    }
    
    // 操作2が失敗したら、操作1も取り消される（ロールバック）
}
```

**ACID 全体:**
| 特性 | 意味 |
|---|---|
| **A**tomicity（原子性） | 全成功 or 全失敗 |
| **C**onsistency（一貫性） | 制約違反を許さない |
| **I**solation（分離性） | 並行トランザクションの独立 |
| **D**urability（永続性） | コミット後は消えない |

</details>

---

### Q2. 「Isolation（分離性）」が守られていない場合に起きる問題は？

- A) データが消失する
- B) 他のトランザクションの途中結果が見えてしまう（Dirty Read等）
- C) サーバーがクラッシュする
- D) インデックスが壊れる

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
分離性が不完全だと、以下のような問題が発生します。

**Dirty Read（汚い読み取り）:**
```
Tx1: UPDATE balance = 0     (まだ COMMIT してない)
Tx2: SELECT balance → 0    ← コミット前の値を読んでしまう
Tx1: ROLLBACK              ← 取り消し
Tx2: (0 を信じて処理続行)   ← 不整合！
```

**Non-Repeatable Read（反復不能読み取り）:**
```
Tx1: SELECT balance → 100
Tx2: UPDATE balance = 50; COMMIT
Tx1: SELECT balance → 50  ← 同じトランザクション内で値が変わった
```

**Phantom Read（ファントムリード）:**
```
Tx1: SELECT COUNT(*) → 10
Tx2: INSERT ...; COMMIT
Tx1: SELECT COUNT(*) → 11  ← 行数が変わった
```

</details>

---

### Q3. PostgreSQL のデフォルトの分離レベルは？

- A) READ COMMITTED
- B) READ UNCOMMITTED
- C) REPEATABLE READ
- D) SERIALIZABLE

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
PostgreSQL のデフォルトは **READ COMMITTED** です。

| 分離レベル | Dirty Read | Non-Repeatable Read | Phantom Read |
|---|---|---|---|
| READ UNCOMMITTED | 発生する | 発生する | 発生する |
| **READ COMMITTED** | **防止** | 発生する | 発生する |
| REPEATABLE READ | 防止 | 防止 | 発生する（※PostgreSQLでは防止） |
| SERIALIZABLE | 防止 | 防止 | 防止 |

**READ COMMITTED の特徴:**
- 各 SQL 文の実行時点でコミット済みのデータだけ見える
- つまり同じ SELECT を2回実行すると、間に他のトランザクションが COMMIT した変更は見える

**設定方法:**
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- または
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

</details>

---

## 📚 セクション2: ロックの仕組み

### Q4. 「楽観的ロック」と「悲観的ロック」の違いは？

- A) 楽観的は早い、悲観的は遅い
- B) 楽観的は更新時に競合チェック、悲観的は読み取り時にロック取得
- C) 楽観的はメモリ上、悲観的はディスク上
- D) PostgreSQL は楽観的ロックのみサポート

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

**悲観的ロック（Pessimistic Lock）:**
「競合するだろう」と想定して、読み取り時にロックを取得

```sql
BEGIN;
SELECT * FROM reports WHERE id = 'xxx' FOR UPDATE;  -- ロック取得
-- 他のトランザクションはここでブロック
UPDATE reports SET status = 'APPROVED' WHERE id = 'xxx';
COMMIT;  -- ロック解放
```

**楽観的ロック（Optimistic Lock）:**
「競合しないだろう」と想定して、更新時に競合チェック

```sql
-- version カラムを使う
SELECT id, title, version FROM reports WHERE id = 'xxx';
-- → version = 3

UPDATE reports SET title = 'New', version = 4
WHERE id = 'xxx' AND version = 3;  -- 競合チェック
-- → 0件更新なら「他で更新された」と判断
```

**使い分け:**
| 方式 | 向いている場面 |
|---|---|
| 悲観的 | 競合が多い、確実にロックしたい（在庫管理等） |
| 楽観的 | 競合が少ない、スケーラビリティ重視 |

</details>

---

### Q5. `SELECT ... FOR UPDATE` の効果は？

```sql
SELECT * FROM reports WHERE id = 'xxx' FOR UPDATE;
```

- A) レポートを更新する
- B) その行を読み取り専用にする
- C) その行に排他ロックをかけ、他のトランザクションの更新/ロックをブロックする
- D) 自動的に COMMIT する

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
`FOR UPDATE` は**排他ロック（Exclusive Lock）**を取得します。

```
Tx1: SELECT * FROM reports WHERE id = 'xxx' FOR UPDATE;
     → ロック取得

Tx2: SELECT * FROM reports WHERE id = 'xxx' FOR UPDATE;
     → Tx1 がコミットするまで待機（ブロック）

Tx1: UPDATE ... ; COMMIT;
     → ロック解放

Tx2: → ロック取得、処理続行
```

**バリエーション:**
| 構文 | 効果 |
|---|---|
| `FOR UPDATE` | 排他ロック（更新予定） |
| `FOR SHARE` | 共有ロック（他の FOR SHARE は可、FOR UPDATE はブロック） |
| `FOR UPDATE NOWAIT` | ロック取れなければ即エラー（待たない） |
| `FOR UPDATE SKIP LOCKED` | ロックされてる行はスキップ（キュー処理向け） |

**Exposed での使い方:**
```kotlin
transaction {
    val report = ReportsTable
        .select { ReportsTable.id eq reportId }
        .forUpdate()  // FOR UPDATE
        .single()
}
```

</details>

---

### Q6. デッドロック（Deadlock）が発生する条件は？

- A) トランザクションが長すぎる
- B) SELECT クエリが多すぎる
- C) インデックスがない
- D) 2つ以上のトランザクションが、互いに相手がロックしているリソースを待っている状態

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
デッドロックは**循環待ち**で発生します。

```
Tx1: LOCK reports (id=1)                  → 成功
Tx2: LOCK reports (id=2)                  → 成功
Tx1: LOCK reports (id=2)                  → Tx2 待ち
Tx2: LOCK reports (id=1)                  → Tx1 待ち
→ 永久に待ち続ける = デッドロック
```

**PostgreSQL の対処:**
- デッドロックを検出すると、一方のトランザクションを自動でロールバック
- エラー: `ERROR: deadlock detected`

**防止策:**
1. **ロック順序を統一**: 必ず id 昇順でロック等
2. **トランザクションを短く**: 長いほどデッドロックリスク増
3. **タイムアウト設定**: `lock_timeout = '5s'`

```sql
-- 必ず id 昇順でロック
SELECT * FROM reports WHERE id IN ('1', '2') ORDER BY id FOR UPDATE;
```

</details>

---

## 📚 セクション3: 実践パターン

### Q7. 二重登録を防ぐ（冪等性を保証する）方法として正しいのは？

ユーザーが「送信」ボタンを連打した場合に、重複データが作られるのを防ぎたい。

- A) アプリ側でボタンを disable にする
- B) ユニーク制約 + UPSERT、または冪等性キー（Idempotency Key）を使う
- C) INSERT 前に SELECT で存在確認する
- D) A だけで十分

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
アプリ側の制御だけでは不十分です（ネットワーク再送、APIの再試行等）。

**方法1: ユニーク制約 + UPSERT**
```sql
CREATE UNIQUE INDEX idx_reports_user_month 
ON reports(user_id, month);

INSERT INTO reports (user_id, month, data)
VALUES ('abc', '2026-01', '...')
ON CONFLICT (user_id, month) DO NOTHING;  -- 重複は無視
```

**方法2: 冪等性キー（Idempotency Key）**
```sql
CREATE TABLE requests (
    idempotency_key UUID PRIMARY KEY,
    result JSONB
);

-- リクエストごとにクライアントが UUID を生成
-- 同じ UUID なら既存の結果を返す
```

**❌ アンチパターン:**
```kotlin
// SELECT → INSERT の間に他のリクエストが INSERT する可能性
if (repository.findByUserAndMonth(userId, month) == null) {
    repository.insert(report)  // 競合！
}
```

</details>

---

### Q8. 在庫管理で「売り切れなのに注文が通る」問題を防ぐ方法は？

```kotlin
fun purchaseItem(itemId: String, quantity: Int) {
    val item = repository.findById(itemId)
    if (item.stock >= quantity) {
        repository.updateStock(itemId, item.stock - quantity)
        // 注文処理...
    }
}
```

上記コードの問題点と解決策は？

- A) if文の条件が間違っている
- B) quantity のバリデーションが必要
- C) 読み取りと更新の間に他のトランザクションが在庫を減らす可能性がある。FOR UPDATE で排他ロックすべき
- D) 例外処理がない

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
**Race Condition（競合状態）**が発生します。

```
在庫 = 1

Tx1: SELECT stock → 1
Tx2: SELECT stock → 1
Tx1: UPDATE stock = 0 (1 - 1)
Tx2: UPDATE stock = 0 (1 - 1)  ← 本来は在庫切れで失敗すべき
```

**解決策1: 悲観的ロック**
```kotlin
transaction {
    val item = ItemsTable
        .select { ItemsTable.id eq itemId }
        .forUpdate()  // ロック取得
        .single()
    
    if (item[ItemsTable.stock] >= quantity) {
        ItemsTable.update({ ItemsTable.id eq itemId }) {
            it[stock] = item[ItemsTable.stock] - quantity
        }
    }
}
```

**解決策2: 条件付き UPDATE（楽観的）**
```sql
UPDATE items 
SET stock = stock - 1 
WHERE id = 'xxx' AND stock >= 1;  -- 条件が満たされなければ 0件更新
```

</details>

---

### Q9. 長時間かかる処理をトランザクション内で行うべきでない理由は？

```kotlin
transaction {
    val data = repository.findAll()
    
    // 外部API呼び出し（5秒かかる）
    val result = externalApi.process(data)
    
    repository.save(result)
}
```

- A) タイムアウトになる
- B) 他のトランザクションをブロックし続け、パフォーマンス低下やデッドロックの原因になる
- C) メモリを大量消費する
- D) 問題はない

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
トランザクション中はロックを保持し続けます。

**問題点:**
1. 他のトランザクションが同じ行を更新しようとすると待たされる
2. 接続プールの接続を1つ占有し続ける
3. デッドロックのリスクが増加

**解決策:**
```kotlin
// 1. トランザクション外でデータ準備
val data = transaction { repository.findAll() }

// 2. 外部API呼び出し（トランザクション外）
val result = externalApi.process(data)

// 3. 短いトランザクションで保存
transaction { repository.save(result) }
```

**原則:**
- トランザクションは**できるだけ短く**
- I/O待ち（外部API、ファイル処理等）はトランザクション外で

</details>

---

## 📚 セクション4: エラーハンドリング

### Q10. トランザクション内で例外が発生した場合の動作は？

```kotlin
transaction {
    repository.insert(report1)
    throw RuntimeException("Something went wrong")
    repository.insert(report2)  // ここには到達しない
}
```

- A) 両方とも保存されない（ロールバック）
- B) report1 は保存され、report2 は保存されない
- C) report1 だけ保存され、例外は無視される
- D) データベース全体がリセットされる

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
Exposed（および多くのDBライブラリ）では、例外発生時に**自動ロールバック**されます。

```kotlin
transaction {
    ReportsTable.insert { it[title] = "Report 1" }  // 一時的に挿入
    
    throw RuntimeException("Error!")  // 例外発生
    
    // → 自動的に ROLLBACK が実行される
    // → Report 1 の挿入も取り消される
}
```

**これが Atomicity（原子性）です:**
- 全ての操作が成功すれば COMMIT
- 1つでも失敗すれば全て ROLLBACK

**明示的なロールバック:**
```kotlin
transaction {
    ReportsTable.insert { ... }
    
    if (someCondition) {
        rollback()  // 明示的にロールバック
    }
}
```

</details>

---

### Q11. トランザクションのリトライが必要になるケースは？

- A) 構文エラーが発生した場合
- B) 常にリトライすべき
- C) デッドロック検出やシリアライズ失敗で、DBが自動ロールバックした場合
- D) リトライは不要

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
一部のエラーは**一時的な競合**が原因であり、リトライで成功することがあります。

**リトライすべきエラー:**
- `40001`: Serialization failure（SERIALIZABLE分離レベル）
- `40P01`: Deadlock detected

**リトライすべきでないエラー:**
- `23505`: Unique violation（データの問題）
- `42601`: Syntax error（コードの問題）

**リトライ実装例:**
```kotlin
fun <T> retryTransaction(maxRetries: Int = 3, block: () -> T): T {
    repeat(maxRetries) { attempt ->
        try {
            return transaction { block() }
        } catch (e: Exception) {
            if (isRetryable(e) && attempt < maxRetries - 1) {
                delay(100 * (attempt + 1))  // 指数バックオフ
            } else {
                throw e
            }
        }
    }
    error("Should not reach here")
}
```

</details>

---

### Q12. セーブポイント（SAVEPOINT）の使いどころは？

```sql
BEGIN;
INSERT INTO reports ...;
SAVEPOINT before_notification;
-- 通知送信（失敗するかも）
INSERT INTO notifications ...;
-- 失敗したら通知だけロールバック
ROLLBACK TO SAVEPOINT before_notification;
COMMIT;
```

- A) トランザクション全体をロールバックせずに、一部の操作だけ取り消したい場合
- B) パフォーマンスを向上させる
- C) デッドロックを防ぐ
- D) セーブポイントは使うべきでない

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
**SAVEPOINT** はトランザクション内に「チェックポイント」を作り、部分的なロールバックを可能にします。

**ユースケース:**
- メイン処理は成功させたいが、付随処理（通知など）は失敗してもOK
- バッチ処理で1件失敗しても他は続行したい

**Exposed での使い方:**
```kotlin
transaction {
    // メイン処理
    ReportsTable.insert { ... }
    
    // オプショナルな処理
    val savepoint = connection.setSavepoint("notifications")
    try {
        NotificationsTable.insert { ... }
    } catch (e: Exception) {
        connection.rollback(savepoint)
        // ログだけ残して続行
    }
}
```

**注意:**
- セーブポイントはオーバーヘッドがある
- シンプルなケースでは使わない方が良い

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 トランザクション制御を十分に理解している |
| 8-10問 | 👍 基礎はOK。ロックの詳細を復習 |
| 5-7問 | 📖 ACID と分離レベルを復習 |
| 4問以下 | 📚 トランザクションの基礎から学び直し |

---

## 📝 復習用キーワード

- **ACID**: Atomicity, Consistency, Isolation, Durability
- **分離レベル**: READ COMMITTED（PostgreSQLデフォルト）, REPEATABLE READ, SERIALIZABLE
- **Dirty Read / Non-Repeatable Read / Phantom Read**: 分離性の問題
- **楽観的ロック**: version カラムで競合検出
- **悲観的ロック**: FOR UPDATE で排他ロック
- **デッドロック**: 循環待ち、ロック順序の統一で防止
- **冪等性キー**: 二重登録防止
- **Race Condition**: 読み取りと更新の間の競合
- **トランザクションは短く**: 外部API呼び出しは外で
- **リトライ**: デッドロックやシリアライズ失敗時
