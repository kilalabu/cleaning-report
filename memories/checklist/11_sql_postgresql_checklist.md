# SQL / PostgreSQL 理解度チェックリスト

バックエンド開発で必須となる **SQL の読み書き** と **PostgreSQL の特性** を理解するための問題集です。
バグ修正や新機能実装で「クエリが読めない」「なぜ遅いかわからない」を解消することを目指します。

---

## 📚 セクション1: SELECT文の基礎

### Q1. 以下のSQLで `INNER JOIN` と `LEFT JOIN` の結果が異なるケースはどれ？

```sql
SELECT u.name, r.title
FROM users u
??? JOIN reports r ON u.id = r.user_id;
```

- A) すべてのユーザーがレポートを持っている場合
- B) レポートを持たないユーザーが存在する場合
- C) 1人のユーザーが複数のレポートを持っている場合
- D) レポートの `user_id` が NULL の行がある場合

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
- **INNER JOIN**: 両方のテーブルにマッチする行のみを返す。レポートを持たないユーザーは**結果に含まれない**。
- **LEFT JOIN**: 左テーブル（users）の全行を返す。マッチしない場合、右側のカラムは `NULL` になる。

```
INNER JOIN の場合:
┌──────────┬────────────┐
│ name     │ title      │
├──────────┼────────────┤
│ 田中     │ 報告書A    │  ← レポート持ちのみ
└──────────┴────────────┘

LEFT JOIN の場合:
┌──────────┬────────────┐
│ name     │ title      │
├──────────┼────────────┤
│ 田中     │ 報告書A    │
│ 山田     │ NULL       │  ← レポートなしも含む
└──────────┴────────────┘
```

**モバイル開発での類似概念:**
Room の `@Relation` で `associateBy` を使う際、1対多のリレーションで「子がいない親」をどう扱うかに相当します。

</details>

---

### Q2. サブクエリと JOIN、どちらを使うべきケースとして正しいのは？

```sql
-- パターンA: サブクエリ
SELECT * FROM reports
WHERE user_id IN (SELECT id FROM users WHERE role = 'admin');

-- パターンB: JOIN
SELECT r.* FROM reports r
JOIN users u ON r.user_id = u.id
WHERE u.role = 'admin';
```

- A) 結果が異なるため、用途に応じて選ぶ
- B) パターンAの方が常に高速
- C) パターンAの方がメモリ効率が良い
- D) 結果は同じだが、パターンBの方が一般的に高速で、実行計画の最適化がしやすい

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
多くの場合、**JOIN** の方がデータベースの最適化が効きやすいです。

**サブクエリの問題点:**
- `IN (SELECT ...)` 形式は、サブクエリの結果を一時的に保持する必要がある
- 相関サブクエリ（外側の行ごとにサブクエリ実行）は特に遅い

**JOINの利点:**
- オプティマイザがより効率的な実行計画を選べる
- インデックスが効きやすい

**ただし例外あり:**
- `EXISTS` サブクエリは早期終了できるため高速なことがある
- 小さなテーブルへの `IN` は問題ない

</details>

---

### Q3. `GROUP BY` と `HAVING` の違いとして正しいのは？

```sql
SELECT user_id, COUNT(*) as report_count
FROM reports
WHERE created_at >= '2026-01-01'
GROUP BY user_id
HAVING COUNT(*) >= 5;
```

- A) `WHERE` は集約前のフィルタ、`HAVING` は集約後のフィルタ
- B) `WHERE` と `HAVING` は同じ意味で、どちらを使っても良い
- C) `HAVING` は `GROUP BY` なしでも使える
- D) `WHERE` に `COUNT(*)` を書くこともできる

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
SQLの実行順序を理解することが重要です。

```
1. FROM        ← テーブルを選択
2. WHERE       ← 行をフィルタ（集約前）
3. GROUP BY    ← グループ化
4. 集約関数     ← COUNT, SUM などを計算
5. HAVING      ← グループをフィルタ（集約後）
6. SELECT      ← カラムを選択
7. ORDER BY    ← ソート
```

**つまり:**
- `WHERE created_at >= '2026-01-01'`：まず日付で絞り込む
- `GROUP BY user_id`：ユーザーごとにまとめる
- `HAVING COUNT(*) >= 5`：5件以上のグループだけ残す

**❌ 不正解の解説:**
- **D**: `WHERE COUNT(*) >= 5` は**構文エラー**になります。集約関数は `HAVING` でしか使えません。

</details>

---

## 📚 セクション2: パフォーマンスとインデックス

### Q4. `EXPLAIN ANALYZE` の結果で最も注目すべき指標は？

```sql
EXPLAIN ANALYZE SELECT * FROM reports WHERE user_id = 'abc123';
```

- A) 返却される行数（rows）
- B) 使用メモリ量
- C) 実行時間（actual time）とスキャン方法（Seq Scan vs Index Scan）
- D) クエリのハッシュ値

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
`EXPLAIN ANALYZE` は実際にクエリを実行して、実測値を表示します。

**注目ポイント:**

```
Seq Scan on reports  (cost=0.00..1000.00 rows=1 width=100) 
  (actual time=50.123..100.456 rows=1 loops=1)
  Filter: (user_id = 'abc123')
  Rows Removed by Filter: 99999
```

1. **Seq Scan（シーケンシャルスキャン）**: テーブル全体を舐めている → 遅い
2. **Index Scan**: インデックスを使っている → 速い
3. **actual time**: 実際にかかった時間
4. **Rows Removed by Filter**: フィルタで除外された行数（多いと無駄が多い）

**改善例:**
```sql
CREATE INDEX idx_reports_user_id ON reports(user_id);
```
→ `Seq Scan` が `Index Scan` に変わり高速化

</details>

---

### Q5. 複合インデックス（Composite Index）の設計で正しいのは？

```sql
-- インデックス定義
CREATE INDEX idx_reports_user_month ON reports(user_id, month);
```

このインデックスが**効果的に使われる**クエリはどれ？

- A) `WHERE month = '2026-01'`
- B) `WHERE user_id = 'abc' AND month = '2026-01'`
- C) `WHERE user_id = 'abc' OR month = '2026-01'`
- D) `WHERE month = '2026-01' AND user_id = 'abc'`

<details>
<summary>答えを見る</summary>

**正解: B, D**（複数正解）

**解説:**
複合インデックスは**左から順に**使われます（B-Treeの場合）。

```
インデックス: (user_id, month)

✅ 効く:
- WHERE user_id = 'abc'                        ← 左端だけでもOK
- WHERE user_id = 'abc' AND month = '2026-01'  ← 両方使える
- WHERE month = '2026-01' AND user_id = 'abc'  ← 順序は関係ない

❌ 効かない:
- WHERE month = '2026-01'                      ← 左端をスキップ
- WHERE user_id = 'abc' OR month = '2026-01'   ← OR は部分的にしか使えない
```

**モバイル開発での類似概念:**
Room の `@Index(value = ["user_id", "month"])` と同じです。

</details>

---

### Q6. 以下のクエリが遅い原因として考えられるのは？

```sql
SELECT * FROM reports
WHERE EXTRACT(YEAR FROM created_at) = 2026;
```

- A) `EXTRACT` 関数が重いから
- B) `2026` が文字列でないから
- C) `SELECT *` を使っているから
- D) カラムに関数を適用すると、インデックスが効かなくなるから

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
**インデックスはカラムの値に対して作られています**。
関数を適用すると、インデックスの値とは別の値になるため、インデックスが使えません。

```sql
-- ❌ インデックスが効かない
WHERE EXTRACT(YEAR FROM created_at) = 2026

-- ✅ インデックスが効く（範囲検索に書き換え）
WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01'
```

**他の例:**
```sql
-- ❌ 効かない
WHERE LOWER(name) = 'tanaka'

-- ✅ 関数インデックスを作る（PostgreSQL固有）
CREATE INDEX idx_name_lower ON users(LOWER(name));
```

</details>

---

## 📚 セクション3: データ更新とトランザクション

### Q7. `UPSERT（INSERT ... ON CONFLICT）`の用途として正しいのは？

```sql
INSERT INTO user_settings (user_id, theme, notifications)
VALUES ('abc123', 'dark', true)
ON CONFLICT (user_id) 
DO UPDATE SET theme = EXCLUDED.theme, notifications = EXCLUDED.notifications;
```

- A) 存在すれば更新、なければ挿入を1つのSQLで行う
- B) 重複行を削除する
- C) 複数テーブルを同時に更新する
- D) トランザクションなしでも安全に更新できる

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
`UPSERT` は **"UPdate or inSERT"** の略で、PostgreSQLでは `INSERT ... ON CONFLICT` で実現します。

**なぜ便利？**
アプリ側で「存在確認→分岐→INSERT or UPDATE」を書くと、レースコンディション（同時アクセス問題）が発生しやすいです。

```kotlin
// ❌ アンチパターン（アプリ側で分岐）
val existing = repository.findById(userId)
if (existing != null) {
    repository.update(settings)
} else {
    repository.insert(settings)
}
// → 同時に2つのリクエストが来ると、両方 insert しようとしてエラー

// ✅ DB側で原子的に処理
INSERT ... ON CONFLICT DO UPDATE ...
```

**`EXCLUDED` とは？**
INSERT しようとした値（VALUES の中身）を参照するためのキーワードです。

</details>

---

### Q8. 以下のSQLで `RETURNING` 句の役割は？

```sql
INSERT INTO reports (user_id, title, month)
VALUES ('abc123', 'Monthly Report', '2026-01')
RETURNING id, created_at;
```

- A) INSERT の結果を別テーブルにも挿入する
- B) INSERT で自動生成されたカラム（ID、タイムスタンプ等）の値を返す
- C) INSERT に失敗した場合のフォールバック値を指定する
- D) INSERT 後に自動でログを出力する

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`RETURNING` は PostgreSQL 固有の機能で、INSERT/UPDATE/DELETE の結果を直接取得できます。

**なぜ便利？**
```kotlin
// ❌ 2回クエリを投げる必要がある
repository.insert(report)
val created = repository.findByUserIdAndMonth(userId, month)

// ✅ 1回で完結
val created = repository.insertAndReturn(report)
```

**Exposed (Ktor) での使い方:**
```kotlin
val id = ReportsTable.insertReturning(listOf(ReportsTable.id)) {
    it[userId] = "abc123"
    it[title] = "Monthly Report"
    it[month] = "2026-01"
}.single()[ReportsTable.id]
```

</details>

---

## 📚 セクション4: PostgreSQL 固有機能

### Q9. `JSONB` 型を使うべきケースとして適切なのは？

- A) 厄密なスキーマが決まっていて、頻繁に検索・集計する構造化データ
- B) 画像や動画などのバイナリデータ
- C) スキーマが柔軟で、ネストした構造を持ち、一部のフィールドだけ検索する半構造化データ
- D) 大量のテキストデータ（全文検索が必要）

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
`JSONB` は JSON を効率的に保存・検索できる PostgreSQL 固有の型です。

**使いどころ:**
- 設定値（プラットフォームごとに異なるフィールド）
- メタデータ（拡張可能なフィールドセット）
- 外部APIのレスポンスキャッシュ

**使い方例:**
```sql
-- テーブル定義
CREATE TABLE user_preferences (
    user_id UUID PRIMARY KEY,
    settings JSONB NOT NULL DEFAULT '{}'
);

-- 検索（GINインデックスが効く）
SELECT * FROM user_preferences
WHERE settings @> '{"theme": "dark"}';

-- 特定のキーを取得
SELECT settings->>'theme' FROM user_preferences;
```

**❌ 使うべきでないケース:**
- 頻繁に集計する数値データ → 通常のカラムにすべき
- リレーションが必要なデータ → 別テーブルにすべき

</details>

---

### Q10. 以下のクエリの意味として正しいのは？

```sql
SELECT * FROM reports
WHERE metadata @> '{"priority": "high"}';
```

- A) `metadata` カラムに `{"priority": "high"}` が**完全一致**する行を取得
- B) `metadata` カラムが `{"priority": "high"}` を**含む**（包含する）行を取得
- C) `metadata` カラムから `priority` キーだけを抽出する
- D) `priority` が `"high"` より大きい行を取得

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`@>` は「**包含（contains）**」演算子です。

```sql
-- metadata = {"priority": "high", "status": "open", "tags": ["urgent"]}

-- ✅ マッチ（部分一致でOK）
WHERE metadata @> '{"priority": "high"}'

-- ✅ マッチ（複数キーも可）
WHERE metadata @> '{"priority": "high", "status": "open"}'

-- ❌ マッチしない（値が違う）
WHERE metadata @> '{"priority": "low"}'
```

**その他の JSONB 演算子:**
- `->`: キーで値を取得（JSON型で返る）
- `->>`: キーで値を取得（TEXT型で返る）
- `?`: キーが存在するか
- `@>`: 包含チェック

</details>

---

## 📚 セクション5: 実践的なクエリパターン

### Q11. ユーザーごとの最新レポート1件を取得するクエリとして正しいのは？

- A)
```sql
SELECT * FROM reports
GROUP BY user_id;
```

- B)
```sql
SELECT DISTINCT ON (user_id) *
FROM reports
ORDER BY user_id, created_at DESC;
```

- C)
```sql
SELECT * FROM reports
WHERE created_at = (SELECT MAX(created_at) FROM reports);
```

- D)
```sql
SELECT * FROM reports
ORDER BY created_at DESC
LIMIT 1;
```

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`DISTINCT ON` は PostgreSQL 固有の機能で、指定したカラムごとに最初の1行だけを返します。

```sql
SELECT DISTINCT ON (user_id) *
FROM reports
ORDER BY user_id, created_at DESC;
```

**動作:**
1. `ORDER BY user_id, created_at DESC` で、ユーザーごとに日付降順でソート
2. `DISTINCT ON (user_id)` で、各ユーザーの最初の行（= 最新）だけ取得

**❌ 不正解の解説:**
- **A**: PostgreSQL では `GROUP BY` に含まれないカラムを SELECT できない
- **C**: 全体の最新1件しか取れない
- **D**: 全ユーザー合わせて1件だけ

**代替手法（WINDOW関数）:**
```sql
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) as rn
    FROM reports
) sub WHERE rn = 1;
```

</details>

---

### Q12. ページネーション実装で「オフセット方式」の問題点は？

```sql
-- オフセット方式
SELECT * FROM reports
ORDER BY created_at DESC
OFFSET 10000 LIMIT 20;
```

- A) 構文エラーになる
- B) OFFSET が大きいと、スキップする行も読み込むため遅くなる
- C) ORDER BY と併用できない
- D) 行の重複が発生する

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`OFFSET 10000` は「最初の10000行をスキップ」ですが、実際には**10000行を読んでから捨てている**ため、遅くなります。

**カーソル方式（推奨）:**
```sql
-- 最初のページ
SELECT * FROM reports
ORDER BY created_at DESC
LIMIT 20;

-- 次のページ（前ページの最後の created_at を使う）
SELECT * FROM reports
WHERE created_at < '2026-01-15T12:34:56Z'
ORDER BY created_at DESC
LIMIT 20;
```

**比較:**
| 方式 | 10000件目以降のパフォーマンス | 途中での挿入/削除 |
|---|---|---|
| OFFSET | ❌ 遅い | ❌ ズレる |
| カーソル | ✅ 速い | ✅ 影響なし |

**モバイルでの類似:**
Android の `Paging3` ライブラリはカーソル方式をサポートしています。

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 SQL力は十分。パフォーマンスチューニングに進める |
| 8-10問 | 👍 基礎はOK。インデックスとパフォーマンスを復習 |
| 5-7問 | 📖 JOIN と GROUP BY を重点的に復習 |
| 4問以下 | 📚 SQL基礎から学び直しを推奨 |

---

## 📝 復習用キーワード

- **INNER JOIN / LEFT JOIN**: マッチしない行の扱いの違い
- **GROUP BY / HAVING**: 集約前後のフィルタ
- **EXPLAIN ANALYZE**: Seq Scan vs Index Scan
- **複合インデックス**: 左から順に効く
- **関数インデックス**: カラムに関数を適用するとインデックスが効かない
- **UPSERT**: INSERT ... ON CONFLICT DO UPDATE
- **RETURNING**: 自動生成値を即座に取得
- **JSONB**: 半構造化データ用、@> で包含検索
- **DISTINCT ON**: グループごとの最初の1行
- **カーソル方式ページネーション**: OFFSET の代替
