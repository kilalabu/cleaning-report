# Phase 3.3: 認証実装 実装手順書

## 概要

このドキュメントでは、KtorでSupabase Auth JWTを検証し、ユーザー認証を実装します。

**ゴール**: Supabase Authで発行されたJWTを検証し、APIを保護する

---

## 認証方式

### 選択: オプションA（Supabase Auth JWT検証）

Flutter側は引き続きSupabase Authを使用し、KtorではJWTトークンを検証します。

**メリット**:
- Flutter側のコード変更が最小限
- Supabase Authの機能（パスワードリセット等）を継続利用可能
- セキュリティはSupabaseに委譲

---

## 認証フロー

```
[Flutterアプリ]
    ↓ Supabase Authでログイン
[JWTトークン取得]
    ↓ Authorization: Bearer <token>
[Ktor API]
    ↓ JWTを検証（Supabase公開鍵で）
[認証OK → user_id取得 → 処理続行]
```

---

## 実装手順

### Step 1: 依存関係追加

#### `server/build.gradle.kts` に追加

```kotlin
dependencies {
    // 既存の依存関係...
    
    // === 新規追加: JWT認証 ===
    implementation("io.ktor:server-auth-jvm")
    implementation("io.ktor:server-auth-jwt-jvm")
}
```

---

### Step 2: 環境変数追加

#### `server/.env` に追加

```bash
# 既存の設定...

# Supabase JWT設定
SUPABASE_JWT_SECRET=your-jwt-secret
SUPABASE_URL=https://xxxx.supabase.co
```

> **JWT Secretの取得方法**:
> Supabase Dashboard → Project Settings → API → JWT Secret

---

### Step 3: 認証プラグイン設定

#### `server/src/main/kotlin/com/cleaning/plugins/Authentication.kt`

```kotlin
package com.cleaning.plugins

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.response.*

/**
 * JWT認証設定
 * 
 * Supabase Authで発行されたJWTを検証する
 */
fun Application.configureAuthentication() {
    val jwtSecret = System.getenv("SUPABASE_JWT_SECRET")
        ?: throw IllegalStateException("SUPABASE_JWT_SECRET is not set")
    val supabaseUrl = System.getenv("SUPABASE_URL")
        ?: throw IllegalStateException("SUPABASE_URL is not set")
    
    install(Authentication) {
        jwt("supabase-jwt") {
            realm = "cleaning-report-api"
            
            verifier(
                JWT.require(Algorithm.HMAC256(jwtSecret))
                    .withIssuer("$supabaseUrl/auth/v1")
                    .build()
            )
            
            validate { credential ->
                // JWTの有効期限チェック
                val expiresAt = credential.payload.expiresAt
                if (expiresAt != null && expiresAt.time < System.currentTimeMillis()) {
                    null  // 期限切れ
                } else {
                    // subクレームからuser_idを取得
                    val userId = credential.payload.subject
                    if (userId != null) {
                        JWTPrincipal(credential.payload)
                    } else {
                        null
                    }
                }
            }
            
            challenge { _, _ ->
                call.respond(
                    HttpStatusCode.Unauthorized,
                    mapOf("error" to "Token is invalid or expired")
                )
            }
        }
    }
}
```

**解説**:
- `Algorithm.HMAC256`: SupabaseのJWT署名アルゴリズム
- `withIssuer`: 発行元チェック（Supabase Auth）
- `credential.payload.subject`: ユーザーID（UUID）

---

### Step 4: ユーザー情報取得ヘルパー

#### `server/src/main/kotlin/com/cleaning/auth/AuthUtils.kt`

```kotlin
package com.cleaning.auth

import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import java.util.UUID

/**
 * 認証済みリクエストからユーザーIDを取得
 */
fun ApplicationCall.getUserId(): UUID {
    val principal = principal<JWTPrincipal>()
        ?: throw IllegalStateException("No JWT principal found")
    
    val userId = principal.payload.subject
        ?: throw IllegalStateException("No user ID in token")
    
    return UUID.fromString(userId)
}

/**
 * ユーザーロールを取得
 */
fun ApplicationCall.getUserRole(): String {
    val principal = principal<JWTPrincipal>()
        ?: throw IllegalStateException("No JWT principal found")
    
    // Supabase JWTのapp_metadataからロールを取得
    val appMetadata = principal.payload.getClaim("app_metadata").asMap()
    return appMetadata?.get("role")?.toString() ?: "staff"
}

/**
 * 管理者かどうかチェック
 */
fun ApplicationCall.isAdmin(): Boolean {
    return getUserRole() == "admin"
}
```

**解説**:
- `principal<JWTPrincipal>()`: 認証情報を取得
- `payload.subject`: SupabaseではこれがユーザーID
- `app_metadata.role`: Supabaseのカスタムロール

---

### Step 5: Application.kt更新

#### `server/src/main/kotlin/com/cleaning/Application.kt`

```kotlin
package com.cleaning

import com.cleaning.database.DatabaseFactory
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import com.cleaning.plugins.*

fun main() {
    DatabaseFactory.init()
    
    val port = System.getenv("PORT")?.toInt() ?: 8080
    
    embeddedServer(Netty, port = port, host = "0.0.0.0") {
        configureKoin()
        configureAuthentication()  // 追加: 認証設定
        configureRouting()
        configureSerialization()
    }.start(wait = true)
}
```

---

### Step 6: APIルートに認証を適用

#### `server/src/main/kotlin/com/cleaning/routes/ReportRoutes.kt` を更新

```kotlin
package com.cleaning.routes

import com.cleaning.auth.getUserId
import com.cleaning.auth.isAdmin
import com.cleaning.models.*
import com.cleaning.repositories.ReportRepository
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject
import java.time.LocalDate

fun Route.reportRoutes() {
    val reportRepository by inject<ReportRepository>()
    
    // 認証が必要なルート
    authenticate("supabase-jwt") {
        route("/api/v1/reports") {
            
            // GET /api/v1/reports?month=2026-01
            get {
                val month = call.parameters["month"]
                if (month == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "month parameter is required"))
                    return@get
                }
                
                // JWTからユーザーIDを取得
                val userId = call.getUserId()
                
                val reports = reportRepository.findByMonth(month, userId)
                call.respond(reports.map { it.toDto() })
            }
            
            // POST /api/v1/reports
            post {
                val request = call.receive<CreateReportRequest>()
                val userId = call.getUserId()
                
                val date = LocalDate.parse(request.date)
                val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
                
                val report = Report(
                    id = java.util.UUID.randomUUID(),
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
                val id = call.parameters["id"]?.let { java.util.UUID.fromString(it) }
                if (id == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                    return@put
                }
                
                val existing = reportRepository.findById(id)
                if (existing == null) {
                    call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                    return@put
                }
                
                // 権限チェック: 自分のレポートまたは管理者のみ編集可能
                val userId = call.getUserId()
                if (existing.userId != userId && !call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Not authorized"))
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
                val id = call.parameters["id"]?.let { java.util.UUID.fromString(it) }
                if (id == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                    return@delete
                }
                
                val existing = reportRepository.findById(id)
                if (existing == null) {
                    call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                    return@delete
                }
                
                // 権限チェック
                val userId = call.getUserId()
                if (existing.userId != userId && !call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Not authorized"))
                    return@delete
                }
                
                reportRepository.delete(id)
                call.respond(HttpStatusCode.NoContent)
            }
        }
    }
}
```

**主な変更点**:
- `authenticate("supabase-jwt") { }` でルート全体を保護
- `call.getUserId()` でJWTからユーザーID取得
- `call.isAdmin()` で権限チェック

---

### Step 7: 管理者用ルート追加（オプション）

#### `server/src/main/kotlin/com/cleaning/routes/AdminRoutes.kt`

```kotlin
package com.cleaning.routes

import com.cleaning.auth.getUserId
import com.cleaning.auth.isAdmin
import com.cleaning.models.toDto
import com.cleaning.repositories.ReportRepository
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Route.adminRoutes() {
    val reportRepository by inject<ReportRepository>()
    
    authenticate("supabase-jwt") {
        route("/api/v1/admin") {
            
            // 全ユーザーのレポート取得（管理者のみ）
            get("/reports") {
                if (!call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Admin only"))
                    return@get
                }
                
                val month = call.parameters["month"]
                if (month == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "month is required"))
                    return@get
                }
                
                // TODO: 全ユーザーのレポート取得メソッドをリポジトリに追加
                call.respond(mapOf("message" to "Not implemented yet"))
            }
        }
    }
}
```

---

### Step 8: 動作確認

#### Supabaseでトークン取得

```bash
# Supabase CLIまたはFlutterアプリでログインしてトークンを取得
# Flutter側: Supabase.instance.client.auth.currentSession?.accessToken
```

#### APIテスト

```bash
# トークンなし → 401
curl http://localhost:8080/api/v1/reports?month=2026-01
# {"error":"Token is invalid or expired"}

# トークンあり → 200
curl http://localhost:8080/api/v1/reports?month=2026-01 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## ディレクトリ構成（Phase 3.3完了後）

```
server/src/main/kotlin/com/cleaning/
├── Application.kt
├── auth/
│   └── AuthUtils.kt             # NEW: 認証ヘルパー
├── di/
│   └── AppModule.kt
├── database/
│   ├── DatabaseFactory.kt
│   └── tables/
│       └── ReportsTable.kt
├── models/
│   └── Report.kt
├── plugins/
│   ├── Authentication.kt        # NEW: JWT認証
│   ├── Koin.kt
│   ├── Routing.kt
│   └── Serialization.kt
├── repositories/
│   └── ReportRepository.kt
└── routes/
    ├── AdminRoutes.kt           # NEW: 管理者API
    ├── HealthRoute.kt
    └── ReportRoutes.kt          # 認証追加
```

---

## 成功基準チェックリスト

- [ ] JWTなしのリクエストが401エラーになる
- [ ] 有効なJWTでuser_idが正しく取得できる
- [ ] 自分のレポートのみ取得/編集/削除できる
- [ ] 管理者は全レポートにアクセスできる

---

## トラブルシューティング

### Q: JWTが常に無効と判定される

**A**: 以下を確認:
1. JWT Secretが正しいか
2. トークンの有効期限が切れていないか
3. Issuerの形式が `https://xxx.supabase.co/auth/v1` になっているか

### Q: app_metadataにroleがない

**A**: Supabaseでユーザー作成時にapp_metadataを設定:
```sql
UPDATE auth.users 
SET raw_app_meta_data = '{"role": "admin"}'::jsonb 
WHERE email = 'admin@example.com';
```

---

## 次のステップ

Phase 3.3が完了したら、[Phase 3.4: Flutter側接続切り替え](./Phase3.4_Flutter接続切替.md)に進んでください。
