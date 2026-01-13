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
    implementation("io.insert-koin:koin-ktor:3.5.3")
    implementation("io.insert-koin:koin-logger-slf4j:3.5.3")
    
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
    testImplementation("io.insert-koin:koin-test:3.5.3")
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

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import org.jetbrains.exposed.sql.Database

object DatabaseFactory {
    
    fun init() {
        val config = HikariConfig().apply {
            jdbcUrl = System.getenv("DATABASE_URL") 
                ?: throw IllegalStateException("DATABASE_URL is not set")
            username = System.getenv("DATABASE_USER") 
                ?: throw IllegalStateException("DATABASE_USER is not set")
            password = System.getenv("DATABASE_PASSWORD") 
                ?: throw IllegalStateException("DATABASE_PASSWORD is not set")
            driverClassName = "org.postgresql.Driver"
            
            // コネクションプール設定
            maximumPoolSize = 3  // 無料枠では少なめに
            minimumIdle = 1
            idleTimeout = 60000  // 1分
            connectionTimeout = 10000  // 10秒
            maxLifetime = 300000  // 5分
            
            // Supabase接続用SSL設定
            addDataSourceProperty("sslmode", "require")
        }
        
        val dataSource = HikariDataSource(config)
        Database.connect(dataSource)
    }
}
```

**解説**:
- `HikariCP`: 高性能なコネクションプール
- `maximumPoolSize = 3`: Supabase無料枠はコネクション数に制限あり
- `sslmode = require`: Supabaseへの接続はSSL必須

---

### Step 4: テーブル定義

#### `server/src/main/kotlin/com/cleaning/database/tables/ReportsTable.kt`

```kotlin
package com.cleaning.database.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.date
import org.jetbrains.exposed.sql.javatime.datetime

/**
 * reportsテーブル定義
 * 
 * Supabaseに既存のテーブルに対応
 */
object ReportsTable : Table("reports") {
    val id = uuid("id")
    val userId = uuid("user_id")
    val date = date("date")
    val type = varchar("type", 50)  // "work" or "expense"
    val item = varchar("item", 255)
    val unitPrice = integer("unit_price").nullable()
    val duration = integer("duration").nullable()  // 分単位
    val amount = integer("amount")
    val note = text("note").nullable()
    val month = varchar("month", 7)  // "yyyy-MM"
    val createdAt = datetime("created_at")
    val updatedAt = datetime("updated_at").nullable()
    
    override val primaryKey = PrimaryKey(id)
}
```

**解説**:
- `Table("reports")`: 既存のSupabaseテーブル名を指定
- 各カラムはSupabaseの`setup.sql`と対応

---

### Step 5: ドメインモデル

#### `server/src/main/kotlin/com/cleaning/models/Report.kt`

```kotlin
package com.cleaning.models

import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.UUID

/**
 * レポートエンティティ
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
    val month: String,  // "yyyy-MM"
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime?
)

enum class ReportType {
    work, expense
}

/**
 * APIリクエスト/レスポンス用DTO
 */
@Serializable
data class ReportDto(
    val id: String,
    val userId: String,
    val date: String,  // "yyyy-MM-dd"
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
 * レポート作成リクエスト
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

/**
 * エンティティ → DTO変換
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

---

### Step 6: リポジトリ実装

#### `server/src/main/kotlin/com/cleaning/repositories/ReportRepository.kt`

```kotlin
package com.cleaning.repositories

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
 * レポートリポジトリインターフェース
 */
interface ReportRepository {
    fun findByMonth(month: String, userId: UUID): List<Report>
    fun findById(id: UUID): Report?
    fun create(report: Report): Report
    fun update(report: Report): Report
    fun delete(id: UUID): Boolean
}

/**
 * PostgreSQL実装
 */
class ReportRepositoryImpl : ReportRepository {
    
    override fun findByMonth(month: String, userId: UUID): List<Report> = transaction {
        ReportsTable
            .selectAll()
            .where { (ReportsTable.month eq month) and (ReportsTable.userId eq userId) }
            .orderBy(ReportsTable.date, SortOrder.DESC)
            .map { it.toReport() }
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
    single<ReportRepository> { ReportRepositoryImpl() }
}
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
    val reportRepository by inject<ReportRepository>()
    
    route("/api/v1/reports") {
        
        // GET /api/v1/reports?month=2026-01
        get {
            val month = call.parameters["month"]
            if (month == null) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "month parameter is required"))
                return@get
            }
            
            // TODO: Phase 3.3で認証から取得する
            val userId = UUID.fromString("00000000-0000-0000-0000-000000000000")
            
            val reports = reportRepository.findByMonth(month, userId)
            call.respond(reports.map { it.toDto() })
        }
        
        // POST /api/v1/reports
        post {
            val request = call.receive<CreateReportRequest>()
            
            // TODO: Phase 3.3で認証から取得する
            val userId = UUID.fromString("00000000-0000-0000-0000-000000000000")
            
            val date = LocalDate.parse(request.date)
            val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
            
            val report = Report(
                id = UUID.randomUUID(),  // 仮ID（create内で上書き）
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
        
        // PUT /api/v1/reports/{id}
        put("/{id}") {
            val id = call.parameters["id"]?.let { UUID.fromString(it) }
            if (id == null) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                return@put
            }
            
            val existing = reportRepository.findById(id)
            if (existing == null) {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                return@put
            }
            
            val request = call.receive<CreateReportRequest>()
            val date = LocalDate.parse(request.date)
            val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
            
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
        
        // DELETE /api/v1/reports/{id}
        delete("/{id}") {
            val id = call.parameters["id"]?.let { UUID.fromString(it) }
            if (id == null) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                return@delete
            }
            
            val deleted = reportRepository.delete(id)
            if (deleted) {
                call.respond(HttpStatusCode.NoContent)
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
            }
        }
    }
}
```

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
    // データベース初期化
    DatabaseFactory.init()
    
    val port = System.getenv("PORT")?.toInt() ?: 8080
    
    embeddedServer(Netty, port = port, host = "0.0.0.0") {
        configureKoin()  // 追加: Koin初期化
        configureRouting()
        configureSerialization()
    }.start(wait = true)
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
│   │   └── AppModule.kt          # NEW: Koinモジュール
│   ├── database/
│   │   ├── DatabaseFactory.kt    # NEW: DB接続
│   │   └── tables/
│   │       └── ReportsTable.kt   # NEW: テーブル定義
│   ├── models/
│   │   └── Report.kt             # NEW: ドメインモデル
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
