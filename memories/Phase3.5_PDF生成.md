# Phase 3.5: PDF生成のKtor経由化 実装手順書

## 概要

このドキュメントでは、PDF生成フローを `Flutter → Ktor → GAS` に変更します。
現在のSupabase Edge Functions経由からKtor経由に切り替えます。

**ゴール**: Ktor経由でPDF生成ができ、Edge Functionsが不要になる

---

## 現在のフロー

```
[Flutter] → [Supabase Edge Functions] → [GAS] → [PDF Base64]
```

## 新しいフロー

```
[Flutter] → [Ktor API] → [GAS] → [PDF Base64]
```

---

## 実装手順

### Step 1: 依存関係追加（Ktor側）

#### `ktor-server/build.gradle.kts` に追加

```kotlin
dependencies {
    // 既存の依存関係...
    
    // === 新規追加: HTTPクライアント（GAS呼び出し用） ===
    implementation("io.ktor:ktor-client-core-jvm")
    implementation("io.ktor:ktor-client-cio-jvm")
    implementation("io.ktor:ktor-client-content-negotiation-jvm")
}
```

---

### Step 2: 環境変数追加

#### `ktor-server/.env` に追加

```bash
# 既存の設定...

# GAS Endpoint
GAS_ENDPOINT=https://script.google.com/macros/s/xxxxx/exec
```

---

### Step 3: GAS APIクライアント作成

#### `ktor-server/src/main/kotlin/com/cleaning/external/GasApiClient.kt`

```kotlin
package com.cleaning.external

import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * GAS API クライアント
 */
class GasApiClient {
    
    private val gasEndpoint = System.getenv("GAS_ENDPOINT")
        ?: throw IllegalStateException("GAS_ENDPOINT is not set")
    
    private val client = HttpClient(CIO) {
        install(ContentNegotiation) {
            json(Json {
                ignoreUnknownKeys = true
                isLenient = true
            })
        }
    }
    
    /**
     * PDF生成リクエスト
     */
    suspend fun generatePdf(request: PdfGenerateRequest): PdfGenerateResponse {
        val response = client.post(gasEndpoint) {
            contentType(ContentType.Application.Json)
            setBody(request)
        }
        
        return response.body()
    }
}

/**
 * PDF生成リクエスト
 */
@Serializable
data class PdfGenerateRequest(
    val action: String = "generatePDFFromData",
    val data: List<ReportData>,
    val monthStr: String,
    val billingDate: String? = null
)

/**
 * レポートデータ（GASに送る形式）
 */
@Serializable
data class ReportData(
    val type: String,
    val item: String,
    val duration: Int?,
    val amount: Int
)

/**
 * PDF生成レスポンス
 */
@Serializable
data class PdfGenerateResponse(
    val success: Boolean,
    val pdfBase64: String? = null,
    val fileName: String? = null,
    val message: String? = null
)
```

---

### Step 4: PDFサービス作成

#### `ktor-server/src/main/kotlin/com/cleaning/services/PdfService.kt`

```kotlin
package com.cleaning.services

import com.cleaning.external.GasApiClient
import com.cleaning.external.PdfGenerateRequest
import com.cleaning.external.PdfGenerateResponse
import com.cleaning.external.ReportData
import com.cleaning.repositories.ReportRepository
import java.util.UUID

/**
 * PDF生成サービス
 */
class PdfService(
    private val reportRepository: ReportRepository,
    private val gasClient: GasApiClient
) {
    
    /**
     * 指定月のPDFを生成
     */
    suspend fun generatePdf(
        month: String,
        userId: UUID,
        billingDate: String?
    ): PdfGenerateResponse {
        // DBからレポートを取得
        val reports = reportRepository.findByMonth(month, userId)
        
        if (reports.isEmpty()) {
            return PdfGenerateResponse(
                success = false,
                message = "対象月のデータがありません"
            )
        }
        
        // GAS形式に変換
        val reportData = reports.map { report ->
            ReportData(
                type = report.type.name,
                item = report.item,
                duration = report.duration,
                amount = report.amount
            )
        }
        
        // GAS APIを呼び出し
        val request = PdfGenerateRequest(
            data = reportData,
            monthStr = month,
            billingDate = billingDate
        )
        
        return gasClient.generatePdf(request)
    }
}
```

---

### Step 5: Koinモジュール更新

#### `ktor-server/src/main/kotlin/com/cleaning/di/AppModule.kt`

```kotlin
package com.cleaning.di

import com.cleaning.external.GasApiClient
import com.cleaning.repositories.ReportRepository
import com.cleaning.repositories.ReportRepositoryImpl
import com.cleaning.services.PdfService
import org.koin.dsl.module

val appModule = module {
    // Repository
    single<ReportRepository> { ReportRepositoryImpl() }
    
    // External Clients
    single { GasApiClient() }
    
    // Services
    single { PdfService(get(), get()) }
}
```

---

### Step 6: PDF生成APIルート作成

#### `ktor-server/src/main/kotlin/com/cleaning/routes/PdfRoutes.kt`

```kotlin
package com.cleaning.routes

import com.cleaning.auth.getUserId
import com.cleaning.auth.isAdmin
import com.cleaning.services.PdfService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import org.koin.ktor.ext.inject

@Serializable
data class PdfRequest(
    val month: String,
    val billingDate: String? = null
)

fun Route.pdfRoutes() {
    val pdfService by inject<PdfService>()
    
    authenticate("supabase-jwt") {
        route("/api/v1/reports/pdf") {
            
            // POST /api/v1/reports/pdf
            post {
                // 管理者のみPDF生成可能
                if (!call.isAdmin()) {
                    call.respond(
                        HttpStatusCode.Forbidden,
                        mapOf("error" to "Admin only")
                    )
                    return@post
                }
                
                val request = call.receive<PdfRequest>()
                val userId = call.getUserId()
                
                val result = pdfService.generatePdf(
                    month = request.month,
                    userId = userId,
                    billingDate = request.billingDate
                )
                
                if (result.success) {
                    call.respond(
                        HttpStatusCode.OK,
                        mapOf(
                            "success" to true,
                            "pdfBase64" to result.pdfBase64,
                            "fileName" to result.fileName
                        )
                    )
                } else {
                    call.respond(
                        HttpStatusCode.BadRequest,
                        mapOf(
                            "success" to false,
                            "message" to (result.message ?: "PDF生成に失敗しました")
                        )
                    )
                }
            }
        }
    }
}
```

---

### Step 7: Routing更新

#### `ktor-server/src/main/kotlin/com/cleaning/plugins/Routing.kt`

```kotlin
package com.cleaning.plugins

import io.ktor.server.application.*
import io.ktor.server.routing.*
import com.cleaning.routes.healthRoutes
import com.cleaning.routes.pdfRoutes
import com.cleaning.routes.reportRoutes

fun Application.configureRouting() {
    routing {
        healthRoutes()
        reportRoutes()
        pdfRoutes()  // 追加
    }
}
```

---

### Step 8: Flutter側のPDFリポジトリ更新

#### `lib/data/repositories/ktor_pdf_repository.dart`

```dart
import '../../domain/repositories/pdf_repository.dart';
import '../datasources/ktor_api_client.dart';

/// Ktor API実装のPdfRepository
class KtorPdfRepository implements PdfRepository {
  final KtorApiClient _apiClient;

  KtorPdfRepository(this._apiClient);

  @override
  Future<PdfResult> generatePdf({
    required String month,
    String? billingDate,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/reports/pdf',
        body: {
          'month': month,
          if (billingDate != null) 'billingDate': billingDate,
        },
      );

      final data = response as Map<String, dynamic>;
      
      if (data['success'] == true) {
        return PdfResult(
          success: true,
          pdfBase64: data['pdfBase64'] as String?,
          fileName: data['fileName'] as String?,
        );
      } else {
        return PdfResult(
          success: false,
          message: data['message'] as String?,
        );
      }
    } catch (e) {
      return PdfResult(
        success: false,
        message: 'PDF生成エラー: $e',
      );
    }
  }
}

class PdfResult {
  final bool success;
  final String? pdfBase64;
  final String? fileName;
  final String? message;

  PdfResult({
    required this.success,
    this.pdfBase64,
    this.fileName,
    this.message,
  });
}
```

---

### Step 9: providers.dart更新

#### `lib/core/di/providers.dart` に追加

```dart
import '../../data/repositories/ktor_pdf_repository.dart';
import '../../data/repositories/supabase_pdf_repository.dart';
import '../../domain/repositories/pdf_repository.dart';

// ========================================
// PDF Repository（切り替え可能）
// ========================================

final pdfRepositoryProvider = Provider<PdfRepository>((ref) {
  if (useKtorApi) {
    final apiClient = ref.watch(ktorApiClientProvider);
    return KtorPdfRepository(apiClient);
  } else {
    final client = ref.watch(supabaseClientProvider);
    return SupabasePdfRepository(client);
  }
});
```

---

### Step 10: 動作確認

```bash
# Ktorサーバー起動
cd /Users/kuwa/Develop/studio/cleaning-report/ktor-server
export $(cat .env | xargs) && ./gradlew run

# PDF生成テスト（管理者トークンが必要）
curl -X POST http://localhost:8080/api/v1/reports/pdf \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"month": "2026-01"}'
```

---

## ディレクトリ構成（Phase 3.5完了後）

```
ktor-server/src/main/kotlin/com/cleaning/
├── Application.kt
├── auth/
│   └── AuthUtils.kt
├── di/
│   └── AppModule.kt              # 更新
├── database/...
├── external/
│   └── GasApiClient.kt           # NEW
├── models/...
├── plugins/...
├── repositories/...
├── routes/
│   ├── HealthRoute.kt
│   ├── PdfRoutes.kt              # NEW
│   └── ReportRoutes.kt
└── services/
    └── PdfService.kt             # NEW
```

---

## 成功基準チェックリスト

- [ ] Ktor経由でPDF生成APIが動作
- [ ] 管理者のみPDF生成可能（権限チェック）
- [ ] Flutter → Ktor → GAS → PDFの流れが動作
- [ ] Supabase Edge Functionsを使わずにPDF生成可能

---

## Edge Functionsの扱い

Phase 3.5完了後、Supabase Edge Functions（`generate-pdf`）は不要になります。

**オプション**:
1. **削除する**: `supabase/functions/generate-pdf/` を削除
2. **残す**: フォールバック用として残しておく

---

## 次のステップ

Phase 3.5が完了したら、[Phase 3.6: gRPC/Connect RPC移行](./Phase3.6_gRPC移行.md)に進んでください。
