# Phase 3.2: データベース接続 & CRUD + DI導入 実装手順書

## 概要

このドキュメントでは、Supabase Postgresに直接接続し、レポートのCRUD APIを実装します。同時に**Koin**による依存性注入を導入し、テスト可能な設計にします。

**ゴール**: Ktor経由でレポートのCRUD操作ができるAPIを構築

---

## 前提条件

- Phase 3.1が完了していること
- Supabase Postgresへの接続情報を持っていること

---

## 技術解説

### Exposedとは？
JetBrains製のKotlin ORMライブラリ。SQLを型安全に書けます。

**Flutterでの比較**:
| 概念 | Flutter/Dart | Kotlin/Exposed |
|:---|:---|:---|
| ORM | drift, floor | Exposed |
| DBクライアント | supabase_flutter | JDBC + Exposed |

### Koinとは？
Kotlinの軽量なDIフレームワーク。Riverpodと似た役割です。

| Riverpod | Koin |
|:---|:---|
| `Provider` | `single { }` |
| `ref.watch()` | `inject()` または `get()` |
| `ProviderScope` | `startKoin { }` |

---

## 実装手順

### Step 1: 依存関係追加

#### `server/build.gradle.kts` を更新

```kotlin
dependencies {
    // === 既存の依存関係 ===
    implementation("io.ktor:server-core-jvm")
    implementation("io.ktor:server-netty-jvm")
    implementation("io.ktor:server-content-negotiation-jvm")
    implementation("io.ktor:ktor-serialization-kotlinx-json-jvm")
    implementation("ch.qos.logback:logback-classic:1.4.14")
    
    // === 新規追加: Koin (DI) ===
    // 💡 Ktor 3系を使う場合は Koin 4.1.1 以上が必要です
    implementation("io.insert-koin:koin-ktor:4.1.1")
    implementation("io.insert-koin:koin-logger-slf4j:4.1.1")
    
    // === 新規追加: Database ===
    implementation("org.jetbrains.exposed:exposed-core:0.46.0")
    implementation("org.jetbrains.exposed:exposed-dao:0.46.0")
    implementation("org.jetbrains.exposed:exposed-jdbc:0.46.0")
    implementation("org.jetbrains.exposed:exposed-java-time:0.46.0")
    implementation("org.postgresql:postgresql:42.7.1")
    implementation("com.zaxxer:HikariCP:5.1.0")
    
    // Testing
    testImplementation("io.ktor:server-tests-jvm")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:1.9.22")
    testImplementation("io.insert-koin:koin-test:4.1.1")
}
```

---

### Step 2: 環境変数設定ファイル作成

#### `server/.env.example`

```bash
# Supabase Database接続情報
DATABASE_URL=jdbc:postgresql://db.xxxx.supabase.co:5432/postgres
DATABASE_USER=postgres
DATABASE_PASSWORD=your-password
```

#### `server/.env`（実際の値を設定、Gitにはコミットしない）

```bash
DATABASE_URL=jdbc:postgresql://db.xxxx.supabase.co:5432/postgres
DATABASE_USER=postgres
DATABASE_PASSWORD=実際のパスワード
```

> **Supabaseの接続情報取得方法**:
> Supabase Dashboard → Project Settings → Database → Connection string (JDBC)

---

### Step 3: データベース設定クラス

#### `server/src/main/kotlin/com/cleaning/database/DatabaseFactory.kt`

```kotlin
package com.cleaning.database

// ───────────────────────────────────────────────────────────────
// 🔍 import文の解説
// ───────────────────────────────────────────────────────────────
import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import org.jetbrains.exposed.sql.Database

// ───────────────────────────────────────────────────────────────
// 🗄️ DatabaseFactory - データベース接続の管理元
// ───────────────────────────────────────────────────────────────
// 💡 Android的に言うと: RoomDatabase インスタンスを生成する処理に相当
//    ただし、サーバーでは「コネクションプール」という仕組みを使います
object DatabaseFactory {
    
    fun init() {
        // 📌 HikariConfig: データベース接続の詳細設定
        //    HikariCP（ヒカリシーピー）はJava界隈で最も標準的な高速コネクションプールです
        val config = HikariConfig().apply {
            // 環境変数から接続情報を取得
            jdbcUrl = System.getenv("DATABASE_URL") 
                ?: throw IllegalStateException("DATABASE_URL is not set")
            username = System.getenv("DATABASE_USER") 
                ?: throw IllegalStateException("DATABASE_USER is not set")
            password = System.getenv("DATABASE_PASSWORD") 
                ?: throw IllegalStateException("DATABASE_PASSWORD is not set")
            
            // 使用するDBドライバー（今回はPostgreSQL）
            driverClassName = "org.postgresql.Driver"
            
            // ─────────────────────────────────────────────
            // 🌊 コネクションプールの設定
            // ─────────────────────────────────────────────
            // 💡 なぜ「プール」が必要か？
            //    サーバーは同時に多数のリクエストをさばくため、
            //    リクエストのたびにDBに繋ぐと遅くなります。
            //    あらかじめ数本の「接続（Connection）」を繋ぎっぱなしにしておき、
            //    使い回すことで高速化します。
            
            maximumPoolSize = 3        // 最大接続数（Supabase無料枠は同時接続制限があるため少なめに）
            minimumIdle = 1           // 待機させておく最小接続数
            idleTimeout = 60000       // 未使用接続を破棄するまでの時間（1分）
            connectionTimeout = 10000 // 接続待ちのタイムアウト（10秒）
            maxLifetime = 300000      // 接続の寿命（5分）
            
            // Supabase接続用SSL設定
            addDataSourceProperty("sslmode", "require")
        }
        
        // 📌 DataSourceの作成とExposedへの紐付け
        val dataSource = HikariDataSource(config)
        Database.connect(dataSource) // Exposedライブラリにこの設定を使わせる
    }
}
```

**サーバーサイドのポイント**:
- **コネクションプール**: AndroidアプリではSQLiteに1つの接続で十分ですが、サーバーでは多数のリクエストを並列処理するために「接続のプール（溜まり場）」を管理します。
- **SSL接続**: クラウド上のDB（Supabase）に繋ぐ際は、セキュリティのため `sslmode=require` が必須です。
- **標準的なSQL**: ここで設定した接続は、ExposedというORMを通じて標準的なSQL（SELECT, INSERT等）に変換されて発行されます。

---

### Step 4: テーブル定義

#### `server/src/main/kotlin/com/cleaning/database/tables/ReportsTable.kt`

```kotlin
package com.cleaning.database.tables

// ───────────────────────────────────────────────────────────────
// 🔍 import文の解説
// ───────────────────────────────────────────────────────────────
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.date
import org.jetbrains.exposed.sql.javatime.datetime

// ───────────────────────────────────────────────────────────────
// 📝 ReportsTable - データベースのスキーマ定義
// ───────────────────────────────────────────────────────────────
// 💡 Android的に言うと: Room の @Entity クラスに相当
//    ただし、Exposedでは「テーブル定義用オブジェクト」を個別に作ります
object ReportsTable : Table("reports") {
    // 各カラムの定義
    // ここで定義した型が、SQL実行時の型安全性を担保します
    val id = uuid("id")                               // UUID型
    val userId = uuid("user_id")
    val date = date("date")                           // LocalDate対応
    val type = varchar("type", 50)                    // VARCHAR(50)
    val item = varchar("item", 255)
    val unitPrice = integer("unit_price").nullable()   // NULL許可
    val duration = integer("duration").nullable()     // 分単位
    val amount = integer("amount")
    val note = text("note").nullable()                // 文字数制限なし
    val month = varchar("month", 7)                   // "yyyy-MM"（集計用）
    val createdAt = datetime("created_at")            // LocalDateTime対応
    val updatedAt = datetime("updated_at").nullable()
    
    // 主キーの設定
    override val primaryKey = PrimaryKey(id)
}
```

**解説**:
- **型安全なDSL**: `int("column")` や `varchar("column")` と書くことで、Kotlin側で型を合わせないとコンパイルエラーになります。
- **Roomとの違い**: RoomはClassにアノテーションを付けますが、Exposedは `Table` オブジェクトで定義します。

---

### Step 5: ドメインモデル

### Step 5: ドメインモデル & DTO

モデルは役割ごとにファイルを分割します。

#### 5-1. ドメインモデル（アプリ内部用）
`server/src/main/kotlin/com/cleaning/models/Report.kt`

```kotlin
package com.cleaning.models

import java.time.LocalDate
import java.time.LocalDateTime
import java.util.UUID

/**
 * 🛡️ Report - ドメインエンティティ
 * 💡 DBの型をそのまま保持する、アプリの核となるデータクラス
 */
data class Report(
    val id: UUID,
    val userId: UUID,
    val date: LocalDate,
    val type: ReportType,
    val item: String,
    val unitPrice: Int?,
    val duration: Int?,
    val amount: Int,
    val note: String?,
    val month: String,
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime?
)

enum class ReportType {
    work, expense
}
```

#### 5-2. DTO（レスポンス用）
`server/src/main/kotlin/com/cleaning/models/ReportDto.kt`

```kotlin
package com.cleaning.models

import kotlinx.serialization.Serializable

/**
 * 📦 ReportDto - レスポンス用
 * 💡 JSONに変換しやすい形式。Androidアプリに返却するデータ
 */
@Serializable
data class ReportDto(
    val id: String,
    val userId: String,
    val date: String,
    val type: String,
    val item: String,
    val unitPrice: Int? = null,
    val duration: Int? = null,
    val amount: Int,
    val note: String? = null,
    val month: String,
    val createdAt: String,
    val updatedAt: String? = null
)

/**
 * 🔄 変換関数 (Extension)
 */
fun Report.toDto(): ReportDto = ReportDto(
    id = id.toString(),
    userId = userId.toString(),
    date = date.toString(),
    type = type.name,
    item = item,
    unitPrice = unitPrice,
    duration = duration,
    amount = amount,
    note = note,
    month = month,
    createdAt = createdAt.toString(),
    updatedAt = updatedAt?.toString()
)
```

#### 5-3. Requestモデル（リクエスト受信用）
`server/src/main/kotlin/com/cleaning/models/ReportRequests.kt`

```kotlin
package com.cleaning.models

import kotlinx.serialization.Serializable

/**
 * 📥 CreateReportRequest - 更新・作成時の受信用
 * 💡 クライアント（Android）から POST/PUT で送られてくる値
 */
@Serializable
data class CreateReportRequest(
    val date: String,
    val type: String,
    val item: String,
    val unitPrice: Int? = null,
    val duration: Int? = null,
    val amount: Int,
    val note: String? = null
)
```

---

### Step 6: リポジトリ実装

#### `server/src/main/kotlin/com/cleaning/repositories/ReportRepository.kt`

```kotlin
package com.cleaning.repositories

// ───────────────────────────────────────────────────────────────
// 🔍 import文の解説
// ───────────────────────────────────────────────────────────────
import com.cleaning.database.tables.ReportsTable
import com.cleaning.models.Report
import com.cleaning.models.ReportType
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.transactions.transaction
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.UUID

/**
 * 💡 Android的に言うと: Room の @Dao インターフェースに相当
 */
interface ReportRepository {
    fun findByMonth(month: String, userId: UUID): List<Report>
    fun findById(id: UUID): Report?
    fun create(report: Report): Report
    fun update(report: Report): Report
    fun delete(id: UUID): Boolean
}

class ReportRepositoryImpl : ReportRepository {
    
    // 📌 transaction { } ブロック
    //    DB操作はこのブロックの中で行う必要があります。
    //    途中でエラーが起きると自動的にロールバックされます。
    
    override fun findByMonth(month: String, userId: UUID): List<Report> = transaction {
        // 📌 DSLによるクエリ作成
        //    Androidの Room では `@Query("SELECT * FROM ...")` と書きますが、
        //    Exposed では Kotlin のメソッドチェーンで書きます。
        ReportsTable
            .selectAll()
            .where { (ReportsTable.month eq month) and (ReportsTable.userId eq userId) }
            .orderBy(ReportsTable.date, SortOrder.DESC)
            .map { it.toReport() } // ResultRow（生の1行）を Report オブジェクトに変換
    }
    
    override fun findById(id: UUID): Report? = transaction {
        ReportsTable
            .selectAll()
            .where { ReportsTable.id eq id }
            .map { it.toReport() }
            .singleOrNull()
    }
    
    override fun create(report: Report): Report = transaction {
        val newId = UUID.randomUUID()
        val now = LocalDateTime.now()
        
        // 📌 insert { }
        //    各カラムに値をセットします
        ReportsTable.insert {
            it[id] = newId
            it[userId] = report.userId
            it[date] = report.date
            it[type] = report.type.name
            it[item] = report.item
            it[unitPrice] = report.unitPrice
            it[duration] = report.duration
            it[amount] = report.amount
            it[note] = report.note
            it[month] = report.month
            it[createdAt] = now
            it[updatedAt] = now
        }
        
        report.copy(id = newId, createdAt = now, updatedAt = now)
    }
    
    override fun update(report: Report): Report = transaction {
        val now = LocalDateTime.now()
        
        ReportsTable.update({ ReportsTable.id eq report.id }) {
            it[date] = report.date
            it[type] = report.type.name
            it[item] = report.item
            it[unitPrice] = report.unitPrice
            it[duration] = report.duration
            it[amount] = report.amount
            it[note] = report.note
            it[month] = report.month
            it[updatedAt] = now
        }
        
        report.copy(updatedAt = now)
    }
    
    override fun delete(id: UUID): Boolean = transaction {
        ReportsTable.deleteWhere { ReportsTable.id eq id } > 0
    }
    
    // 📌 ResultRow → Domain Model 変換
    //    DBから取得した生の1行を、アプリで扱うデータクラスに詰め替えます
    private fun ResultRow.toReport(): Report = Report(
        id = this[ReportsTable.id],
        userId = this[ReportsTable.userId],
        date = this[ReportsTable.date],
        type = ReportType.valueOf(this[ReportsTable.type]),
        item = this[ReportsTable.item],
        unitPrice = this[ReportsTable.unitPrice],
        duration = this[ReportsTable.duration],
        amount = this[ReportsTable.amount],
        note = this[ReportsTable.note],
        month = this[ReportsTable.month],
        createdAt = this[ReportsTable.createdAt],
        updatedAt = this[ReportsTable.updatedAt]
    )
}
```

---

### Step 7: Koinモジュール定義

#### `server/src/main/kotlin/com/cleaning/di/AppModule.kt`

```kotlin
package com.cleaning.di

import com.cleaning.repositories.ReportRepository
import com.cleaning.repositories.ReportRepositoryImpl
import org.koin.dsl.module

/**
 * アプリケーションのDIモジュール
 * 
 * Riverpodでいう providers.dart に相当
 */
val appModule = module {
    // Repository
    // 💡 single { } はシングルトン。アプリ全体で1つのインスタンスを使い回します
    single<ReportRepository> { ReportRepositoryImpl() }
}

/**
 * 💡 補足：サーバーサイドでのデータ生成
 * 
 * Androidではクライアント側でIDや時刻を決めることもありますが、
 * サーバーサイドでは「DBに書き込む直前（Repository内）」で
 * 確定させるのが最も安全で標準的です。
 */
```

**解説**:
- `single { }`: シングルトン（Riverpodの`Provider`に相当）
- `single<ReportRepository>`: インターフェースにバインド

---

### Step 8: Koinプラグイン設定

#### `server/src/main/kotlin/com/cleaning/plugins/Koin.kt`

```kotlin
package com.cleaning.plugins

import com.cleaning.di.appModule
import io.ktor.server.application.*
import org.koin.ktor.plugin.Koin
import org.koin.logger.slf4jLogger

fun Application.configureKoin() {
    install(Koin) {
        slf4jLogger()
        modules(appModule)
    }
}
```

---

### Step 9: APIルート実装

#### `server/src/main/kotlin/com/cleaning/routes/ReportRoutes.kt`

```kotlin
package com.cleaning.routes

// ───────────────────────────────────────────────────────────────
// 🔍 import文の解説
// ───────────────────────────────────────────────────────────────
import com.cleaning.models.*
import com.cleaning.repositories.ReportRepository
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject
import java.time.LocalDate
import java.util.UUID

fun Route.reportRoutes() {
    // 📌 依存性の注入 (DI)
    //    Koinを使ってリポジトリを取得します。Androidの `by viewModels()` 等と同じ感覚です
    val reportRepository by inject<ReportRepository>()
    
    route("/api/v1/reports") {
        
        // ─────────────────────────────────────────────────────
        // 🔍 GET /api/v1/reports?month=2026-01
        // ─────────────────────────────────────────────────────
        get {
            // クエリパラメータの取得
            val month = call.parameters["month"]
            if (month == null) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "month parameter is required"))
                return@get
            }
            
            // 💡 ユーザーIDの扱い
            //    現在は仮のIDを入れています。Phase 3.3でログインユーザーのIDを使うよう修正します
            val userId = UUID.fromString("00000000-0000-0000-0000-000000000000")
            
            // 💡 selectAll().where { ... } の挙動
            //    記述上は All ですが、実際に発行されるSQLは WHERE 句で絞り込まれたものになります。
            //    全てのデータをメモリに載せてからフィルターするわけではないので高速です。
            val reports = reportRepository.findByMonth(month, userId)
            
            // 📌 DTOに変換してレスポンス（自動でJSON化される）
            //    ※ .toDto() を忘れると、UUIDなどの型がシリアライズできず500エラーになります。
            call.respond(reports.map { it.toDto() })
        }
        
        // ─────────────────────────────────────────────────────
        // 🔍 POST /api/v1/reports
        // ─────────────────────────────────────────────────────
        post {
            // 📌 call.receive()
            //    Ktorがヘッダー（application/json）を見て、自動的にデシリアライズしてくれます。
            //    Retrofitの @Body と同じ仕組みです。
            val request = call.receive<CreateReportRequest>()
            
            val userId = UUID.fromString("00000000-0000-0000-0000-000000000000")
            
            val date = LocalDate.parse(request.date)
            val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
            
            // 💡 Entityの作成
            //    この時点では id や createdAt が未確定ですが、インスタンス生成のために
            //    仮の値を入れます。実際にはこの後の Repository.create 内で最新の値に上書きされます。
            val report = Report(
                id = UUID.randomUUID(),
                userId = userId,
                date = date,
                type = ReportType.valueOf(request.type),
                item = request.item,
                unitPrice = request.unitPrice,
                duration = request.duration,
                amount = request.amount,
                note = request.note,
                month = month,
                createdAt = java.time.LocalDateTime.now(),
                updatedAt = null
            )
            
            val created = reportRepository.create(report)
            call.respond(HttpStatusCode.Created, created.toDto())
        }
        
        // ─────────────────────────────────────────────────────
        // 🔍 PUT /api/v1/reports/{id}
        // ─────────────────────────────────────────────────────
        put("/{id}") {
            // URLパラメータからIDを取得
            // 💡 なぜ try-catch を使うのか？
            //    UUID.fromString() は不正な文字列（例: "abc"）が来ると例外を投げます。
            //    そのままにするとサーバーが 500 エラーでクラッシュしてしまうため、
            //    例外をキャッチして 400 Bad Request を返すようにします。
            val id = try {
                call.parameters["id"]?.let { UUID.fromString(it) }
            } catch (e: Exception) {
                null
            }

            if (id == null) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                return@put
            }
            
            // 存在チェック
            val existing = reportRepository.findById(id)
            if (existing == null) {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                return@put
            }
            
            val request = call.receive<CreateReportRequest>()
            val date = LocalDate.parse(request.date)
            val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
            
            // 既存のデータを上書きして更新
            val updated = reportRepository.update(
                existing.copy(
                    date = date,
                    type = ReportType.valueOf(request.type),
                    item = request.item,
                    unitPrice = request.unitPrice,
                    duration = request.duration,
                    amount = request.amount,
                    note = request.note,
                    month = month
                )
            )
            
            call.respond(updated.toDto())
        }
        
        // ─────────────────────────────────────────────────────
        // 🔍 DELETE /api/v1/reports/{id}
        // ─────────────────────────────────────────────────────
        delete("/{id}") {
            val id = call.parameters["id"]?.let { UUID.fromString(it) }
            if (id == null) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                return@delete
            }
            
            val deleted = reportRepository.delete(id)
            if (deleted) {
                // 💡 204 No Content: 削除成功（返す中身がない）を意味する標準的なステータス
                call.respond(HttpStatusCode.NoContent)
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
            }
        }
    }
}
```

**サーバーサイドのポイント**:
- **`call.receive<T>()`**: クライアントから送られてきたJSONをパースします。型が合わないと `400 Bad Request` になります。
- **`call.respond(status, body)`**: HTTPステータスコードとデータを一緒に返します。
- **バリデーション**: 本来は入力値のチェックが必要ですが、今回はシンプルにするため省略しています。

**解説**:
- `by inject<ReportRepository>()`: Koinから依存を取得（Riverpodの`ref.watch()`に相当）
- TODOコメント: Phase 3.3で認証からuserIdを取得するよう修正

---

### Step 10: Application.ktを更新

#### `server/src/main/kotlin/com/cleaning/Application.kt`

```kotlin
package com.cleaning

import com.cleaning.database.DatabaseFactory
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import com.cleaning.plugins.*

fun main() {
    val port = System.getenv("PORT")?.toInt() ?: 8080
    
    // 💡 module = Application::module を指定するのが重要！
    //    これにより、下の module() 関数が起動時に実行され、Koin 等が初期化されます。
    embeddedServer(Netty, port = port, host = "0.0.0.0", module = Application::module)
        .start(wait = true)
}

/**
 * アプリケーションのメインモジュール
 * 💡 ここに初期化処理を集約することで、ローカル実行と本番（EngineMain）で挙動を統一できます。
 */
fun Application.module() {
    // データベース初期化
    DatabaseFactory.init()
    
    configureKoin()
    configureSerialization()
    configureRouting()
}
```

---

### Step 11: Routingを更新

#### `server/src/main/kotlin/com/cleaning/plugins/Routing.kt`

```kotlin
package com.cleaning.plugins

import io.ktor.server.application.*
import io.ktor.server.routing.*
import com.cleaning.routes.healthRoutes
import com.cleaning.routes.reportRoutes

fun Application.configureRouting() {
    routing {
        healthRoutes()
        reportRoutes()  // 追加
    }
}
```

---

### Step 12: ローカルで動作確認

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/server

# 環境変数を読み込んで起動
export $(cat .env | xargs) && ./gradlew run
```

#### API動作確認（別ターミナル）

```bash
# レポート一覧取得
curl "http://localhost:8080/api/v1/reports?month=2026-01"

# レポート作成
curl -X POST http://localhost:8080/api/v1/reports \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-01-12",
    "type": "work",
    "item": "通常清掃",
    "duration": 60,
    "amount": 2000
  }'

# レポート更新
curl -X PUT http://localhost:8080/api/v1/reports/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-01-12",
    "type": "work",
    "item": "通常清掃",
    "duration": 90,
    "amount": 3000
  }'

# レポート削除
curl -X DELETE http://localhost:8080/api/v1/reports/{id}
```

---

## ディレクトリ構成（Phase 3.2完了後）

```
server/
├── src/main/kotlin/com/cleaning/
│   ├── Application.kt
│   ├── di/
│   │   └── AppModule.kt
│   ├── database/
│   │   ├── DatabaseFactory.kt
│   │   └── tables/
│   │       └── ReportsTable.kt
│   ├── models/
│   │   ├── Report.kt             # Domain Entity
│   │   ├── ReportDto.kt          # DTO
│   │   └── ReportRequests.kt     # Request DTO
│   ├── plugins/
│   │   ├── Koin.kt               # NEW: Koin設定
│   │   ├── Routing.kt
│   │   └── Serialization.kt
│   ├── repositories/
│   │   └── ReportRepository.kt   # NEW: リポジトリ
│   └── routes/
│       ├── HealthRoute.kt
│       └── ReportRoutes.kt       # NEW: CRUD API
└── .env
```

---

## 成功基準チェックリスト

- [ ] Koinでの依存性注入が機能
- [ ] Supabase DBに接続成功
- [ ] GET `/api/v1/reports?month=xxxx-xx` が動作
- [ ] POST `/api/v1/reports` が動作
- [ ] PUT `/api/v1/reports/{id}` が動作
- [ ] DELETE `/api/v1/reports/{id}` が動作

---

## トラブルシューティング

### Q: DB接続でSSLエラー

**A**: `.env`のDATABASE_URLに`?sslmode=require`を追加:
```
DATABASE_URL=jdbc:postgresql://db.xxx.supabase.co:5432/postgres?sslmode=require
```

### Q: コネクション数超過エラー

**A**: HikariCPの`maximumPoolSize`を2に減らす

---

## 次のステップ

Phase 3.2が完了したら、[Phase 3.3: 認証実装](./Phase3.3_認証実装.md)に進んでください。
