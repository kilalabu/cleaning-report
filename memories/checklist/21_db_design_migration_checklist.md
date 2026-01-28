# DB設計 / マイグレーション 理解度チェックリスト

新しいテーブルを作成し、既存のスキーマを安全に変更できるようになることを目指します。
「どんなカラムを作るべきか」「マイグレーションをどう管理するか」が判断できるようになることがゴールです。

---

## 📚 セクション1: テーブル設計の基礎

### Q1. 主キー（Primary Key）の設計として推奨されるのは？

- A) 意味のあるデータ（例: メールアドレス、電話番号）を主キーにする
- B) 連番の整数（SERIAL/BIGSERIAL）を主キーにする
- C) UUID を主キーにする
- D) BとCは両方とも有効な選択肢で、ユースケースによる

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**

| 方式 | メリット | デメリット |
|---|---|---|
| **SERIAL** | 小さい、ソート済み、インデックス効率◎ | 推測可能、分散システムで衝突リスク |
| **UUID** | 推測不可、分散生成OK | 大きい（16byte）、ランダムでインデックス効率△ |

**使い分け:**
- **内部テーブル**（ログ等）: SERIAL で十分
- **外部公開API**（URLに含む等）: UUID が安全
- **マイクロサービス**: UUID（各サービスで独立生成可能）

**PostgreSQL での使い方:**
```sql
-- SERIAL
CREATE TABLE reports (
    id BIGSERIAL PRIMARY KEY
);

-- UUID
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);
```

**❌ 避けるべき:**
- メールアドレスや電話番号を主キーにする → 変更時に大変

</details>

---

### Q2. 外部キー（Foreign Key）制約を設定する目的は？

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    title TEXT NOT NULL
);
```

- A) クエリのパフォーマンスを向上させる
- B) 存在しないユーザーのレポートが作成されることを防ぐ（参照整合性）
- C) テーブルのサイズを小さくする
- D) 自動でインデックスが作成される

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
外部キー制約は**参照整合性（Referential Integrity）**を保証します。

```sql
-- user_id = 'nonexistent' のレポートを作ろうとすると...
INSERT INTO reports (id, user_id, title)
VALUES (gen_random_uuid(), 'nonexistent-user-id', 'Test');

-- → ERROR: insert or update on table "reports" violates foreign key constraint
```

**注意点:**
- PostgreSQL では外部キーに**自動でインデックスは作られない**
- パフォーマンスのために明示的にインデックスを作成すべき

```sql
CREATE INDEX idx_reports_user_id ON reports(user_id);
```

**ON DELETE の挙動:**
```sql
-- ユーザー削除時にレポートも削除
REFERENCES users(id) ON DELETE CASCADE

-- ユーザー削除を禁止（レポートがある場合）
REFERENCES users(id) ON DELETE RESTRICT

-- レポートの user_id を NULL に（NOT NULL なら使えない）
REFERENCES users(id) ON DELETE SET NULL
```

</details>

---

### Q3. 正規化（Normalization）の目的として正しいのは？

- A) データの重複を排除し、更新時の不整合を防ぐ
- B) クエリのパフォーマンスを最大化する
- C) テーブル数を減らしてシンプルにする
- D) JOINを不要にする

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
正規化は**データの重複を排除**することで、更新時の不整合（更新異常）を防ぎます。

**Before（非正規化）:**
```
reports:
| id | title    | user_name | user_email     |
|----|----------|-----------|----------------|
| 1  | Report A | 田中      | tanaka@ex.com  |
| 2  | Report B | 田中      | tanaka@ex.com  | ← 重複
```
→ 田中さんのメールが変わったら全行更新が必要

**After（正規化）:**
```
users:
| id | name | email         |
|----|------|---------------|
| 1  | 田中 | tanaka@ex.com |

reports:
| id | title    | user_id |
|----|----------|---------|
| 1  | Report A | 1       |
| 2  | Report B | 1       |
```
→ メール変更は users の1行だけ

**トレードオフ:**
- 正規化しすぎるとJOINが増えてパフォーマンス低下
- 読み取りが多い場合は意図的に**非正規化（Denormalization）**することも

</details>

---

### Q4. NULL を許容すべきカラムはどれ？

- A) 主キー (`id`)
- B) 外部キー (`user_id`) で、関連が必須でない場合
- C) 作成日時 (`created_at`)
- D) 必ず値が入るビジネス上の必須項目 (`title`)

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
NULL は「値がない/不明」を表し、ビジネスロジック上「あってもなくてもいい」場合に使います。

**NULL を許容すべき例:**
```sql
-- 削除日時（削除されていなければ NULL）
deleted_at TIMESTAMP NULL,

-- 任意の関連（担当者未割り当て）
assigned_user_id UUID NULL REFERENCES users(id),

-- オプショナルなメタデータ
metadata JSONB NULL
```

**NULL を許容すべきでない例:**
```sql
-- 主キー
id UUID NOT NULL PRIMARY KEY,

-- 必須の外部キー
user_id UUID NOT NULL REFERENCES users(id),

-- ビジネス上必須の項目
title TEXT NOT NULL,

-- 監査用タイムスタンプ
created_at TIMESTAMP NOT NULL DEFAULT now()
```

**NULL の落とし穴:**
```sql
-- NULL との比較は常に UNKNOWN（TRUE でも FALSE でもない）
SELECT * FROM reports WHERE deleted_at = NULL;  -- ❌ 0件になる
SELECT * FROM reports WHERE deleted_at IS NULL; -- ✅ 正しい
```

</details>

---

## 📚 セクション2: インデックス設計

### Q5. インデックスを**作るべきでない**カラムはどれ？

- A) WHERE句で頻繁に使われるカラム
- B) JOINの結合条件に使われるカラム
- C) ほとんどの行で同じ値が入っているカラム（例: `is_active = true` が99%）
- D) ORDER BY で使われるカラム

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
**カーディナリティ（値の種類の多さ）**が低いカラムはインデックスの効果が薄いです。

```sql
-- ❌ 効果が薄い（ほとんど true）
CREATE INDEX idx_reports_is_active ON reports(is_active);
-- → 99%の行がヒットするので、全件スキャンと変わらない

-- ✅ 効果がある（値がバラバラ）
CREATE INDEX idx_reports_user_id ON reports(user_id);
-- → 特定ユーザーの行だけに絞り込める
```

**インデックスのコスト:**
- ディスク容量を消費
- INSERT/UPDATE/DELETE が遅くなる（インデックスも更新するため）

**インデックスを作るかの判断:**
1. そのカラムを WHERE/JOIN/ORDER BY で使う？
2. 値の種類が十分に多い？
3. テーブルの行数が多い？

</details>

---

### Q6. 複合インデックスの設計で「カラム順序」が重要な理由は？

```sql
CREATE INDEX idx_reports_user_month ON reports(user_id, month);
```

- A) 順序はパフォーマンスに影響しない
- B) WHERE句で最初に書くカラムと順序を合わせる必要がある
- C) インデックスは左から順に使われるため、絞り込みが強いカラムを先に置くべき
- D) アルファベット順に並べる決まりがある

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
複合インデックスは**左から順に**使われます（B-Treeの特性）。

```sql
CREATE INDEX idx ON reports(user_id, month, status);

-- ✅ 効く
WHERE user_id = 'abc'
WHERE user_id = 'abc' AND month = '2026-01'
WHERE user_id = 'abc' AND month = '2026-01' AND status = 'OPEN'

-- ❌ 効かない（左端をスキップ）
WHERE month = '2026-01'
WHERE status = 'OPEN'
```

**設計方針:**
1. **等価条件（=）** で使うカラムを先に
2. **範囲条件（<, >, BETWEEN）** で使うカラムは後に
3. **カーディナリティが高い**（絞り込みが強い）カラムを先に

```sql
-- 良い例: user_id で大きく絞り込み、month で追加絞り込み
CREATE INDEX idx ON reports(user_id, month);

-- 悪い例: status（OPEN/CLOSED の2種類）では絞り込めない
CREATE INDEX idx ON reports(status, user_id);
```

</details>

---

## 📚 セクション3: マイグレーション

### Q7. マイグレーションツール（Flyway等）を使う目的は？

- A) SQLを書かなくて済むようにする
- B) スキーマ変更の履歴を管理し、全環境で同じスキーマを再現できるようにする
- C) データベースのバックアップを自動化する
- D) クエリのパフォーマンスを向上させる

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
マイグレーションツールは**スキーマ変更をバージョン管理**します。

```
db/migrations/
├── V001__create_users_table.sql
├── V002__create_reports_table.sql
├── V003__add_status_to_reports.sql
└── V004__add_index_on_user_id.sql
```

**メリット:**
- 開発/ステージング/本番で同じスキーマを再現
- いつ、誰が、何を変更したか追跡可能
- ロールバック可能（場合による）

**Flyway の動作:**
1. `flyway_schema_history` テーブルで適用済みバージョンを管理
2. 未適用のマイグレーションだけを順番に実行

**Exposed (Ktor) でのマイグレーション:**
```kotlin
// 開発時のみ: テーブル自動作成
SchemaUtils.create(UsersTable, ReportsTable)

// 本番: Flyway等で明示的に管理すべき
```

</details>

---

### Q8. 本番DBでカラムを追加する際、ダウンタイムを避けるために重要なことは？

```sql
ALTER TABLE reports ADD COLUMN priority TEXT;
```

- A) 深夜に実行する
- B) `NOT NULL` 制約なしで追加し、後からデフォルト値を設定する
- C) テーブルを削除して作り直す
- D) カラム追加はダウンタイムなしでは不可能

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
PostgreSQL では `NOT NULL` 制約付きでカラムを追加すると、**全行をロック**してしまう可能性があります。

**安全なカラム追加手順:**

```sql
-- Step 1: NULL許容で追加（高速）
ALTER TABLE reports ADD COLUMN priority TEXT;

-- Step 2: デフォルト値でバックフィル（バッチ処理）
UPDATE reports SET priority = 'NORMAL' WHERE priority IS NULL;

-- Step 3: NOT NULL制約を追加（必要なら）
ALTER TABLE reports ALTER COLUMN priority SET NOT NULL;
```

**PostgreSQL 11以降:**
```sql
-- デフォルト値付きの追加も高速になった
ALTER TABLE reports ADD COLUMN priority TEXT NOT NULL DEFAULT 'NORMAL';
-- → 実際に全行更新せず、メタデータだけ変更
```

**危険な操作:**
- カラムの型変更（全行書き換え）
- 大きいテーブルへのインデックス追加（`CONCURRENTLY` を使う）

</details>

---

### Q9. マイグレーションファイルの命名規則として推奨されるのは？

- A) `create_reports.sql`
- B) `V001__create_reports_table.sql`
- C) `2026-01-26_reports.sql`
- D) `migration_1.sql`

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
Flyway の命名規則 `V{version}__{description}.sql` が広く使われています。

```
V001__create_users_table.sql
V002__create_reports_table.sql
V003__add_status_column_to_reports.sql
V004__create_index_on_reports_user_id.sql
```

**ルール:**
- `V` + バージョン番号（ゼロ埋め推奨）
- アンダースコア2つ `__` で区切る
- 説明は snake_case
- **一度適用したファイルは変更しない**（新しいマイグレーションを作る）

**なぜ日付より連番？**
- 日付だと複数人が同じ日に作ると順序が不定
- 連番なら明確な順序を保証

</details>

---

## 📚 セクション4: 実践的なパターン

### Q10. 論理削除（Soft Delete）と物理削除（Hard Delete）の使い分けは？

```sql
-- 論理削除
UPDATE reports SET deleted_at = now() WHERE id = 'xxx';

-- 物理削除
DELETE FROM reports WHERE id = 'xxx';
```

- A) 常に論理削除を使うべき
- B) 常に物理削除を使うべき
- C) 監査要件やデータ復旧の必要性に応じて選択する
- D) 論理削除はパフォーマンスが悪いので避けるべき

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**

| 方式 | メリット | デメリット |
|---|---|---|
| **論理削除** | 復旧可能、監査証跡残る | WHERE句に条件追加が必要、データ肥大化 |
| **物理削除** | シンプル、容量節約 | 復旧不可、監査証跡なし |

**論理削除を使うべきケース:**
- 法的に一定期間保持が必要（GDPR対応等）
- 誤削除からの復旧が必要
- 監査ログとして必要

**物理削除を使うべきケース:**
- ユーザーによる「完全削除」要求（GDPR の忘れられる権利）
- 一時的なデータ（セッション、キャッシュ）
- 容量が問題になる大量データ

**論理削除の実装:**
```sql
-- テーブル設計
CREATE TABLE reports (
    id UUID PRIMARY KEY,
    deleted_at TIMESTAMP NULL
);

-- 取得時に除外
SELECT * FROM reports WHERE deleted_at IS NULL;

-- 部分インデックス（削除済みを除外）
CREATE INDEX idx_reports_active ON reports(user_id) WHERE deleted_at IS NULL;
```

</details>

---

### Q11. タイムスタンプカラムの設計で推奨されるのは？

- A) `created_at` と `updated_at` の両方を全テーブルに入れる
- B) アプリ側で日時を生成して INSERT する
- C) `created_at` はDB側でデフォルト設定、`updated_at` はトリガーまたはアプリで更新
- D) タイムスタンプは不要

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- updated_at 自動更新トリガー（PostgreSQL）
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_reports_updated_at
    BEFORE UPDATE ON reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
```

**なぜ DB 側で生成？**
- クライアントの時計がズレていると信頼できない
- サーバー（DB）の時刻が信頼できる唯一のソース

**Exposed での実装:**
```kotlin
object ReportsTable : Table("reports") {
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp())
    val updatedAt = timestamp("updated_at").defaultExpression(CurrentTimestamp())
}
```

</details>

---

### Q12. Enum 型を DB で表現する方法として正しいのは？

```kotlin
enum class ReportStatus { DRAFT, SUBMITTED, APPROVED, REJECTED }
```

- A) PostgreSQL の ENUM 型を使う
- B) TEXT 型 + CHECK 制約を使う
- C) INTEGER でマッピングする
- D) すべて有効で、トレードオフがある

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**

| 方式 | メリット | デメリット |
|---|---|---|
| **PostgreSQL ENUM** | 型安全、ドキュメント的 | 値の追加/削除が面倒 |
| **TEXT + CHECK** | 柔軟、変更しやすい | 制約を忘れるとゴミが入る |
| **INTEGER** | 高速、省容量 | 可読性が低い |
| **別テーブル** | 動的に追加可能 | JOIN が必要 |

**PostgreSQL ENUM の落とし穴:**
```sql
-- 作成
CREATE TYPE report_status AS ENUM ('DRAFT', 'SUBMITTED', 'APPROVED');

-- 値の追加は簡単
ALTER TYPE report_status ADD VALUE 'REJECTED';

-- 値の削除・変更は面倒（型を作り直しが必要）
```

**TEXT + CHECK（推奨パターン）:**
```sql
CREATE TABLE reports (
    status TEXT NOT NULL CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED'))
);

-- 値の追加時は CHECK 制約を変更
ALTER TABLE reports DROP CONSTRAINT reports_status_check;
ALTER TABLE reports ADD CONSTRAINT reports_status_check 
    CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'CANCELLED'));
```

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 DB設計の基礎を十分に理解している |
| 8-10問 | 👍 基礎はOK。インデックス設計を復習 |
| 5-7問 | 📖 正規化とマイグレーションを復習 |
| 4問以下 | 📚 テーブル設計の基礎から学び直し |

---

## 📝 復習用キーワード

- **主キー**: SERIAL vs UUID のトレードオフ
- **外部キー**: 参照整合性、ON DELETE CASCADE/RESTRICT
- **正規化**: データ重複の排除、更新異常の防止
- **NULL**: ビジネス上「なくてもいい」場合のみ許容
- **インデックス**: カーディナリティが高いカラムに作成
- **複合インデックス**: 左から順に使われる
- **マイグレーション**: スキーマ変更のバージョン管理
- **ダウンタイムなしのカラム追加**: NOT NULL なしで追加 → バックフィル
- **論理削除 vs 物理削除**: 監査要件と容量のトレードオフ
- **タイムスタンプ**: DB側で now() をデフォルト設定
