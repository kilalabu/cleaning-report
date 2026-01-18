# Phase 3.2: DB接続 & CRUD + DI導入 理解度チェックリスト

Phase 3.2（データベース接続、CRUD実装、DI導入）に関する本質的な理解を確認するための問題集です。

---

## 📚 セクション1: 基礎理解（4択問題）

### Q1. トランザクション（transaction）の役割として正しいのはどれ？

```kotlin
transaction {
    val user = UsersTable.insert { ... }
    val report = ReportsTable.insert { ... }
}
```

- A) 処理を高速化する
- B) 複数のDB操作を「まとめて成功/失敗」させる（一部だけ成功は防ぐ）
- C) 並列処理を可能にする
- D) データベース接続を確立する

<details>
<summary>答えを見る</summary>

**正解: B**

トランザクションは「複数のDB操作をまとめて成功/失敗させる」仕組みです。

```
transaction {
    ① 在庫を減らす
    ② 注文レコードを作成
    ③ 決済処理
}
```

もし③で失敗したら、①と②も自動的に取り消される（ロールバック）。
これにより「在庫だけ減って代金がない」などの不整合を防ぎます。

**Android（Room）での類似概念:**
```kotlin
@Transaction
suspend fun transferMoney(from: Account, to: Account, amount: Int) {
    // すべて成功 or すべて失敗
}
```

</details>

---

### Q2. コネクションプール（Connection Pool）が必要な理由は？

```kotlin
maximumPoolSize = 3
minimumIdle = 1
```

- A) データベースのバックアップを保持するため
- B) サーバーは同時に多数のリクエストを処理するため、接続を使い回して高速化
- C) データベースの容量を拡張するため
- D) SSL接続を暗号化するため

<details>
<summary>答えを見る</summary>

**正解: B**

**Android（1ユーザー）vs サーバー（多数のユーザー）:**

```
Androidアプリ:
  ユーザーの操作 → DB → 結果表示
  （同時に1つの操作しか起きない）
  → SQLite接続は1つで十分

サーバー:
  ユーザーA → [接続1] → DB
  ユーザーB → [接続2] → DB
  ユーザーC → [接続3] → DB
  → 同時に複数の接続が必要！
```

毎回接続を作ると遅い（約100ms）ため、あらかじめ接続を作っておき使い回すのがコネクションプールです。

**Android（OkHttp）での類似概念:**
```kotlin
OkHttpClient.Builder()
    .connectionPool(ConnectionPool(5, 5, TimeUnit.MINUTES))
```

</details>

---

### Q3. DTO（Data Transfer Object）とEntity（Domain Model）を分ける理由として正しくないのはどれ？

- A) セキュリティ（パスワードなど返してはいけない情報を除外）
- B) 型安全性（内部ではUUID/LocalDateを使い、ミスを防ぐ）
- C) パフォーマンスの向上
- D) クライアントに返す形式を自由に変更可能

<details>
<summary>答えを見る</summary>

**正解: C**

DTO/Entity分離は**パフォーマンス向上が主目的ではありません**。

```
Request DTO  →  Domain Entity  →  Response DTO
  (入力用)        (内部処理用)      (出力用)

CreateReportRequest  →  Report  →  ReportDto
・JSONから変換          ・UUID型       ・String型（ISO）
・idなし                ・LocalDate型   ・機密情報除外
```

**分ける理由:**
- ✅ セキュリティ: パスワード等を含めない
- ✅ 型安全性: 内部でUUID/LocalDateを使う
- ✅ 柔軟性: クライアント向け形式を変更しても内部に影響なし

**Android的に言うと:**
- UIモデル（画面表示用）とドメインモデル（ビジネスロジック用）の分離

</details>

---

### Q4. HTTPステータスコードの使い分けとして正しいのはどれ？

- A) POST成功時は 200 OK を返す
- B) DELETE成功時は 204 No Content を返す（返す内容がない）
- C) リソースが見つからない時は 500 Internal Server Error を返す
- D) 認証エラー時は 400 Bad Request を返す

<details>
<summary>答えを見る</summary>

**正解: B**

| コード | 意味 | 使用例 |
|:---|:---|:---|
| 200 OK | 成功（データを返す） | GET成功時 |
| 201 Created | 作成成功 | **POST成功時** |
| 204 No Content | 成功（返す内容なし） | **DELETE成功時** |
| 400 Bad Request | クライアントの入力が不正 | 必須パラメータなし |
| 401 Unauthorized | 認証されていない | ログインしてない |
| 404 Not Found | リソースが存在しない | ID該当なし |
| 500 Internal Error | サーバー側のバグ | catch漏れ等 |

**Android（Retrofit）での経験:**
```kotlin
when (response.code()) {
    200 -> // データ取得成功
    201 -> // 作成成功
    401 -> // 再ログイン誘導
    404 -> // 「データが見つかりません」表示
}
```

</details>

---

## 📚 セクション2: 実装パターン選択問題

### Q5. Exposed DSLでのクエリ実装として正しいのはどれ？（月ごとのレポート取得）

**A)**
```kotlin
fun findByMonth(month: String, userId: UUID): List<Report> {
    val results = ReportsTable.selectAll()
    return results.filter { it.month == month && it.userId == userId }
        .map { it.toReport() }
}
```

**B)**
```kotlin
fun findByMonth(month: String, userId: UUID): List<Report> = transaction {
    ReportsTable
        .selectAll()
        .where { (ReportsTable.month eq month) and (ReportsTable.userId eq userId) }
        .orderBy(ReportsTable.date, SortOrder.DESC)
        .map { it.toReport() }
}
```

**C)**
```kotlin
fun findByMonth(month: String, userId: UUID): List<Report> = transaction {
    val sql = "SELECT * FROM reports WHERE month = ? AND user_id = ?"
    ReportsTable.exec(sql, month, userId) { ... }
}
```

**D)**
```kotlin
fun findByMonth(month: String, userId: UUID): List<Report> {
    ReportsTable.select { month eq month }
}
```

<details>
<summary>答えを見る</summary>

**正解: B**

```kotlin
transaction {  // ← トランザクション内で実行
    ReportsTable
        .selectAll()  // SELECT *
        .where { (ReportsTable.month eq month) and (ReportsTable.userId eq userId) }
        // ↑ WHERE month = ? AND user_id = ?
        .orderBy(ReportsTable.date, SortOrder.DESC)
        // ↑ ORDER BY date DESC
        .map { it.toReport() }  // ResultRow → Report変換
}
```

**間違いの解説:**
- A: `transaction { }` がない、filterはメモリ上で実行（非効率）
- C: Exposedでは型安全なDSLを使う（生SQLは極力避ける）
- D: 構文エラー、`userId` の条件がない

**Android（Room）との比較:**
```kotlin
// Room
@Query("SELECT * FROM reports WHERE month = :month AND user_id = :userId ORDER BY date DESC")
suspend fun findByMonth(month: String, userId: String): List<Report>

// Exposed
fun findByMonth(month: String, userId: UUID): List<Report> = transaction {
    ReportsTable.selectAll()
        .where { (ReportsTable.month eq month) and (ReportsTable.userId eq userId) }
        .orderBy(ReportsTable.date, SortOrder.DESC)
        .map { it.toReport() }
}
```

</details>

---

### Q6. Repositoryでのレコード作成実装として正しいのはどれ？

**A)**
```kotlin
override fun create(report: Report): Report {
    ReportsTable.insert {
        it[id] = report.id
        it[userId] = report.userId
        // ...
    }
    return report
}
```

**B)**
```kotlin
override fun create(report: Report): Report = transaction {
    val newId = UUID.randomUUID()
    val now = LocalDateTime.now()
    
    ReportsTable.insert {
        it[id] = newId
        it[userId] = report.userId
        // ...
        it[createdAt] = now
    }
    
    report.copy(id = newId, createdAt = now, updatedAt = now)
}
```

**C)**
```kotlin
override fun create(report: Report): Report = transaction {
    ReportsTable.insert {
        it[id] = null  // 自動生成
        it[userId] = report.userId
        // ...
    }
    return report
}
```

**D)**
```kotlin
override fun create(report: Report): Report {
    val sql = "INSERT INTO reports VALUES (?, ?, ...)"
    ReportsTable.exec(sql, report.id, report.userId, ...)
    return report
}
```

<details>
<summary>答えを見る</summary>

**正解: B**

**サーバーサイドのベストプラクティス:**
- ID（UUID）と時刻（createdAt）は**Repository内で**確定させる
- `transaction { }` で囲む
- 新しく作成された値を反映したオブジェクトを返す

```kotlin
transaction {
    val newId = UUID.randomUUID()  // ← サーバー側で生成
    val now = LocalDateTime.now()   // ← サーバー側で生成
    
    ReportsTable.insert {
        it[id] = newId
        it[createdAt] = now
        // ...
    }
    
    report.copy(id = newId, createdAt = now)  // ← 最新値を返す
}
```

**なぜサーバー側で生成？**
- クライアントからの値は信用できない（時刻のずれ、不正なID等）
- 一貫性を保証できる
- DBの制約（UNIQUE等）を確実に守れる

</details>

---

### Q7. Koin DIモジュールの定義として正しいのはどれ？

**A)**
```kotlin
val appModule = module {
    factory<ReportRepository> { ReportRepositoryImpl() }
}
```

**B)**
```kotlin
val appModule = module {
    single<ReportRepository> { ReportRepositoryImpl() }
}
```

**C)**
```kotlin
val appModule = module {
    viewModel { ReportRepositoryImpl() }
}
```

**D)**
```kotlin
val appModule = module {
    bind(ReportRepository::class) to ReportRepositoryImpl()
}
```

<details>
<summary>答えを見る</summary>

**正解: B**

```kotlin
val appModule = module {
    single<ReportRepository> { ReportRepositoryImpl() }
    // ↑ シングルトン（アプリ全体で1つのインスタンスを使い回す）
}
```

**Koinのスコープ:**
| スコープ | 説明 | Riverpod/Hilt との比較 |
|:---|:---|:---|
| `single { }` | シングルトン | Riverpod の `Provider` |
| `factory { }` | 毎回新しいインスタンス | - |
| `viewModel { }` | Android ViewModelスコープ | Hilt の `@ViewModelScoped` |

**Repositoryはシングルトンが適切:**
- 状態を持たない（ステートレス）
- 複数インスタンスは不要
- メモリ効率が良い

</details>

---

## 📚 セクション3: サーバーサイド特有の概念

### Q8. 以下のコードの問題点は？

```kotlin
get("/api/reports") {
    val month = call.parameters["month"]
    val userId = UUID.fromString("00000000-0000-0000-0000-000000000000")
    
    val reports = reportRepository.findByMonth(month, userId)
    call.respond(reports)  // ← 問題箇所
}
```

- A) `transaction { }` がない
- B) DTOに変換せずにEntityをそのまま返すと、UUID等の型がシリアライズできず500エラーになる
- C) `month` のnullチェックがない
- D) HTTPステータスコードを明示すべき

<details>
<summary>答えを見る</summary>

**正解: B**

```kotlin
// ❌ 間違い
call.respond(reports)
// ReportのままだとUUID, LocalDate等がJSONにできない

// ✅ 正しい
call.respond(reports.map { it.toDto() })
// DTOに変換してからレスポンス
```

**なぜEntityをそのまま返せない？**
```kotlin
// Entity（内部用）
data class Report(
    val id: UUID,              // ← JSONシリアライズできない
    val date: LocalDate,       // ← JSONシリアライズできない
    val userId: UUID,          // ← JSONシリアライズできない
    // ...
)

// DTO（レスポンス用）
@Serializable
data class ReportDto(
    val id: String,            // UUID.toString()
    val date: String,          // LocalDate.toString() → "2026-01-18"
    val userId: String,        // UUID.toString()
    // ...
)
```

**変換関数:**
```kotlin
fun Report.toDto(): ReportDto = ReportDto(
    id = id.toString(),
    date = date.toString(),
    userId = userId.toString(),
    // ...
)
```

</details>

---

### Q9. 環境変数によるデータベース接続情報の管理について正しいのはどれ？

```kotlin
val dbPassword = System.getenv("DATABASE_PASSWORD")
    ?: throw IllegalStateException("DATABASE_PASSWORD is not set")
```

- A) ハードコードの方が安全
- B) 環境変数は本番/開発環境で異なる値を使える、秘密情報をコードに書かない
- C) 環境変数は起動時のパフォーマンスを向上させる
- D) 環境変数は必須ではない

<details>
<summary>答えを見る</summary>

**正解: B**

**環境変数を使う理由:**

```
本番環境:
  DATABASE_PASSWORD=production-secret

開発環境:
  DATABASE_PASSWORD=dev-password

ローカル環境:
  DATABASE_PASSWORD=local-password
```

**メリット:**
- ✅ 本番/開発環境で異なる値を使える
- ✅ 秘密情報をコードに書かない（Git履歴に残らない）
- ✅ Cloud Runなどが自動で設定してくれる（PORTなど）

**Android（BuildConfig）との類似概念:**
```kotlin
// Android: build.gradle.kts で設定
buildConfigField("String", "API_KEY", "\"${localProperties['api.key']}\"")

// サーバー: 環境変数で設定
val apiKey = System.getenv("API_KEY")
```

</details>

---

### Q10. HikariCPのコネクションプール設定について正しいのはどれ？

```kotlin
maximumPoolSize = 3
minimumIdle = 1
idleTimeout = 60000
```

- A) `maximumPoolSize` は大きいほど良い
- B) Supabase無料枠には同時接続数制限があるため、少なめ（3程度）に設定
- C) `minimumIdle` は必ず `maximumPoolSize` と同じ値にすべき
- D) `idleTimeout` は無限に設定すべき

<details>
<summary>答えを見る</summary>

**正解: B**

**Supabase無料枠の制限:**
- 同時接続数に上限がある（無料枠では少ない）
- 多数のコネクションを張りすぎると接続エラーになる

```kotlin
maximumPoolSize = 3        // 最大3接続（制限内）
minimumIdle = 1           // 最低1接続を待機
idleTimeout = 60000       // 未使用接続は1分後に破棄
```

**適切な設定:**
- 無料枠: `maximumPoolSize = 3`
- 有料枠: `maximumPoolSize = 10〜20`

**なぜ小さい値？**
- Supabaseの接続数制限を超えないため
- リクエスト数が少ない場合、多数のコネクションは不要

</details>

---

### Q11. Exposed の `selectAll().where { ... }` の挙動として正しいのはどれ？

```kotlin
ReportsTable.selectAll().where { ReportsTable.month eq "2026-01" }
```

- A) 全データをメモリに読み込んでからフィルタリング（遅い）
- B) SQL の WHERE 句で絞り込まれたクエリが発行される（高速）
- C) キャッシュがあればそれを使う
- D) トランザクションが必須

<details>
<summary>答えを見る</summary>

**正解: B**

**Exposed DSL の仕組み:**

```kotlin
// Kotlin DSL
ReportsTable.selectAll().where { month eq "2026-01" }

// ↓ 内部で以下のSQLに変換される

SELECT * FROM reports WHERE month = '2026-01'
```

**メモリ効率:**
- ❌ 全データをメモリに読み込んでから `filter()` するわけではない
- ✅ DBレベルでWHERE句によって絞り込まれる
- ✅ 必要なデータだけがメモリに載る

**Android（Room）との類似性:**
```kotlin
// Room: アノテーションでSQL
@Query("SELECT * FROM reports WHERE month = :month")
suspend fun findByMonth(month: String): List<Report>

// Exposed: DSLでSQL
ReportsTable.selectAll().where { month eq month }
```

どちらも最終的にはSQLが発行される点で同じです。

</details>

---

### Q12. Koin の `inject()` と `get()` の違いは？

```kotlin
// パターン1
val reportRepository by inject<ReportRepository>()

// パターン2
val reportRepository = get<ReportRepository>()
```

- A) 機能的な違いはない（どちらでもOK）
- B) `inject()` は遅延初期化（Kotlin の `by lazy` と同じ）、`get()` は即座に取得
- C) `inject()` はシングルトン、`get()` はfactory
- D) `inject()` の方が高速

<details>
<summary>答えを見る</summary>

**正解: B**

| メソッド | 初期化タイミング | Kotlinでの類似概念 |
|:---|:---|:---|
| `by inject<T>()` | 最初に使われた時 | `by lazy { }` |
| `get<T>()` | 即座に取得 | 通常の初期化 |

```kotlin
// 遅延初期化（推奨）
val repository by inject<ReportRepository>()
// repositoryが最初にアクセスされたときに取得

// 即座に取得
val repository = get<ReportRepository>()
// この行で即座に取得
```

**どちらを使うべき？**
- Ktorルート内: `by inject()` が推奨（必要になるまで取得しない）
- 初期化処理: `get()` でも可

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 完全に理解している |
| 9-10問 | 👍 概ね理解している。復習推奨箇所あり |
| 6-8問 | 📖 基礎は理解しているが、深い理解が必要 |
| 5問以下 | 📚 Phase3.2_DB接続_CRUD_DI.md を再度読み込むことを推奨 |

---

## 📝 復習用キーワード

- **トランザクション**: 複数のDB操作をまとめて成功/失敗させる
- **コネクションプール**: DB接続を使い回して高速化
- **DTO vs Entity**: 入出力用 vs 内部処理用
- **HTTPステータスコード**: 200/201/204/400/401/404/500の使い分け
- **Exposed**: Kotlin ORM（型安全なSQL DSL）
- **HikariCP**: Java標準の高速コネクションプール
- **Koin**: Kotlinの軽量DIフレームワーク
- **single vs factory**: シングルトン vs 毎回新規
- **inject() vs get()**: 遅延初期化 vs 即座に取得
- **環境変数**: 秘密情報やデプロイ環境ごとの設定
