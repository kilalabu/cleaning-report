# Phase 3.6: gRPC/Connect RPC移行 実装手順書

## 概要

このドキュメントでは、REST APIをConnect RPC（gRPC互換）に移行し、型安全な通信を実現します。

**ゴール**: Protocol BuffersでAPI定義し、Ktor/Flutter両方でコード生成

---

## Connect RPCとは？

Buf社が開発したgRPC互換のプロトコル。HTTP/JSONでも使えるため、Webアプリでも利用しやすい。

### REST vs Connect RPC

| 項目 | REST | Connect RPC |
|:---|:---|:---|
| 型安全性 | 手動でDTO定義 | .protoから自動生成 |
| コード共有 | なし | クライアント/サーバー共通 |
| ドキュメント | OpenAPI等で別途作成 | .protoがドキュメント |
| バリデーション | 手動 | 自動生成可能 |

---

## 技術スタック

- **Protocol Buffers**: スキーマ定義言語
- **Buf**: Protobufツールチェーン
- **Connect-Kotlin**: Ktor用Connect実装
- **connect-dart**: Flutter用Connect実装

---

## 実装手順

### Step 1: Bufセットアップ

#### Bufをインストール

```bash
brew install bufbuild/buf/buf
```

#### プロジェクトルートにBuf設定

```bash
cd /Users/kuwa/Develop/studio/cleaning-report
mkdir -p proto
```

#### `buf.yaml`

```yaml
version: v2
modules:
  - path: proto
lint:
  use:
    - DEFAULT
breaking:
  use:
    - FILE
```

#### `buf.gen.yaml`

```yaml
version: v2
plugins:
  # Kotlin用
  - remote: buf.build/connectrpc/kotlin
    out: server/src/main/kotlin
    opt:
      - generateCallbackMethods=true
      - generateCoroutineMethods=true
      
  # Dart用
  - remote: buf.build/connectrpc/dart
    out: cleaning_report_app/lib/generated
```

---

### Step 2: Protocol Buffers定義

#### `proto/cleaning/v1/report.proto`

```protobuf
syntax = "proto3";

package cleaning.v1;

import "google/protobuf/timestamp.proto";

// ========================================
// メッセージ定義
// ========================================

// レポートタイプ
enum ReportType {
  REPORT_TYPE_UNSPECIFIED = 0;
  REPORT_TYPE_WORK = 1;
  REPORT_TYPE_EXPENSE = 2;
}

// レポート
message Report {
  string id = 1;
  string user_id = 2;
  string date = 3;  // "yyyy-MM-dd"
  ReportType type = 4;
  string item = 5;
  optional int32 unit_price = 6;
  optional int32 duration = 7;
  int32 amount = 8;
  optional string note = 9;
  string month = 10;  // "yyyy-MM"
  google.protobuf.Timestamp created_at = 11;
  optional google.protobuf.Timestamp updated_at = 12;
}

// ========================================
// リクエスト/レスポンス
// ========================================

// レポート一覧取得
message ListReportsRequest {
  string month = 1;
}

message ListReportsResponse {
  repeated Report reports = 1;
}

// レポート作成
message CreateReportRequest {
  string date = 1;
  ReportType type = 2;
  string item = 3;
  optional int32 unit_price = 4;
  optional int32 duration = 5;
  int32 amount = 6;
  optional string note = 7;
}

message CreateReportResponse {
  Report report = 1;
}

// レポート更新
message UpdateReportRequest {
  string id = 1;
  string date = 2;
  ReportType type = 3;
  string item = 4;
  optional int32 unit_price = 5;
  optional int32 duration = 6;
  int32 amount = 7;
  optional string note = 8;
}

message UpdateReportResponse {
  Report report = 1;
}

// レポート削除
message DeleteReportRequest {
  string id = 1;
}

message DeleteReportResponse {}

// ========================================
// サービス定義
// ========================================

service ReportService {
  // レポート一覧取得
  rpc ListReports(ListReportsRequest) returns (ListReportsResponse);
  
  // レポート作成
  rpc CreateReport(CreateReportRequest) returns (CreateReportResponse);
  
  // レポート更新
  rpc UpdateReport(UpdateReportRequest) returns (UpdateReportResponse);
  
  // レポート削除
  rpc DeleteReport(DeleteReportRequest) returns (DeleteReportResponse);
}
```

---

#### `proto/cleaning/v1/pdf.proto`

```protobuf
syntax = "proto3";

package cleaning.v1;

// PDF生成リクエスト
message GeneratePdfRequest {
  string month = 1;
  optional string billing_date = 2;
}

// PDF生成レスポンス
message GeneratePdfResponse {
  bool success = 1;
  optional string pdf_base64 = 2;
  optional string file_name = 3;
  optional string message = 4;
}

service PdfService {
  rpc GeneratePdf(GeneratePdfRequest) returns (GeneratePdfResponse);
}
```

---

### Step 3: コード生成

```bash
cd /Users/kuwa/Develop/studio/cleaning-report
buf generate
```

生成されるファイル:
- `server/src/main/kotlin/cleaning/v1/` - Kotlinコード
- `cleaning_report_app/lib/generated/cleaning/v1/` - Dartコード

---

### Step 4: Ktor側 Connect実装

#### `build.gradle.kts` に依存関係追加

```kotlin
dependencies {
    // 既存...
    
    // Connect RPC
    implementation("com.connectrpc:connect-kotlin:0.5.0")
    implementation("com.connectrpc:connect-kotlin-google-java-ext:0.5.0")
    
    // Protobuf
    implementation("com.google.protobuf:protobuf-kotlin:3.25.1")
}
```

---

#### `server/src/main/kotlin/com/cleaning/rpc/ReportServiceImpl.kt`

```kotlin
package com.cleaning.rpc

import cleaning.v1.*
import com.cleaning.models.Report
import com.cleaning.models.ReportType
import com.cleaning.repositories.ReportRepository
import com.connectrpc.Code
import com.connectrpc.ConnectException
import com.connectrpc.headers.Headers
import com.google.protobuf.Timestamp
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.UUID

class ReportServiceImpl(
    private val reportRepository: ReportRepository
) : ReportServiceInterface {
    
    override suspend fun listReports(
        request: ListReportsRequest,
        headers: Headers
    ): ListReportsResponse {
        val userId = headers.getUserId()
        val reports = reportRepository.findByMonth(request.month, userId)
        
        return ListReportsResponse.newBuilder()
            .addAllReports(reports.map { it.toProto() })
            .build()
    }
    
    override suspend fun createReport(
        request: CreateReportRequest,
        headers: Headers
    ): CreateReportResponse {
        val userId = headers.getUserId()
        val date = LocalDate.parse(request.date)
        val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
        
        val report = Report(
            id = UUID.randomUUID(),
            userId = userId,
            date = date,
            type = request.type.toDomain(),
            item = request.item,
            unitPrice = if (request.hasUnitPrice()) request.unitPrice else null,
            duration = if (request.hasDuration()) request.duration else null,
            amount = request.amount,
            note = if (request.hasNote()) request.note else null,
            month = month,
            createdAt = LocalDateTime.now(),
            updatedAt = null
        )
        
        val created = reportRepository.create(report)
        
        return CreateReportResponse.newBuilder()
            .setReport(created.toProto())
            .build()
    }
    
    override suspend fun updateReport(
        request: UpdateReportRequest,
        headers: Headers
    ): UpdateReportResponse {
        val userId = headers.getUserId()
        val id = UUID.fromString(request.id)
        
        val existing = reportRepository.findById(id)
            ?: throw ConnectException(Code.NOT_FOUND, "Report not found")
        
        if (existing.userId != userId) {
            throw ConnectException(Code.PERMISSION_DENIED, "Not authorized")
        }
        
        val date = LocalDate.parse(request.date)
        val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
        
        val updated = reportRepository.update(
            existing.copy(
                date = date,
                type = request.type.toDomain(),
                item = request.item,
                unitPrice = if (request.hasUnitPrice()) request.unitPrice else null,
                duration = if (request.hasDuration()) request.duration else null,
                amount = request.amount,
                note = if (request.hasNote()) request.note else null,
                month = month
            )
        )
        
        return UpdateReportResponse.newBuilder()
            .setReport(updated.toProto())
            .build()
    }
    
    override suspend fun deleteReport(
        request: DeleteReportRequest,
        headers: Headers
    ): DeleteReportResponse {
        val userId = headers.getUserId()
        val id = UUID.fromString(request.id)
        
        val existing = reportRepository.findById(id)
            ?: throw ConnectException(Code.NOT_FOUND, "Report not found")
        
        if (existing.userId != userId) {
            throw ConnectException(Code.PERMISSION_DENIED, "Not authorized")
        }
        
        reportRepository.delete(id)
        
        return DeleteReportResponse.getDefaultInstance()
    }
    
    // ========================================
    // ヘルパー関数
    // ========================================
    
    private fun Headers.getUserId(): UUID {
        val token = this["authorization"]?.firstOrNull()
            ?: throw ConnectException(Code.UNAUTHENTICATED, "No token")
        // TODO: JWT検証してuser_idを取得
        return UUID.fromString("...")
    }
    
    private fun cleaning.v1.ReportType.toDomain(): ReportType = when (this) {
        cleaning.v1.ReportType.REPORT_TYPE_WORK -> ReportType.work
        cleaning.v1.ReportType.REPORT_TYPE_EXPENSE -> ReportType.expense
        else -> throw IllegalArgumentException("Unknown type")
    }
    
    private fun Report.toProto(): cleaning.v1.Report {
        val builder = cleaning.v1.Report.newBuilder()
            .setId(id.toString())
            .setUserId(userId.toString())
            .setDate(date.toString())
            .setType(type.toProto())
            .setItem(item)
            .setAmount(amount)
            .setMonth(month)
            .setCreatedAt(createdAt.toTimestamp())
        
        unitPrice?.let { builder.setUnitPrice(it) }
        duration?.let { builder.setDuration(it) }
        note?.let { builder.setNote(it) }
        updatedAt?.let { builder.setUpdatedAt(it.toTimestamp()) }
        
        return builder.build()
    }
    
    private fun ReportType.toProto(): cleaning.v1.ReportType = when (this) {
        ReportType.work -> cleaning.v1.ReportType.REPORT_TYPE_WORK
        ReportType.expense -> cleaning.v1.ReportType.REPORT_TYPE_EXPENSE
    }
    
    private fun LocalDateTime.toTimestamp(): Timestamp {
        val instant = this.toInstant(ZoneOffset.UTC)
        return Timestamp.newBuilder()
            .setSeconds(instant.epochSecond)
            .setNanos(instant.nano)
            .build()
    }
}
```

---

### Step 5: Ktor Connectプラグイン設定

#### `server/src/main/kotlin/com/cleaning/plugins/Connect.kt`

```kotlin
package com.cleaning.plugins

import cleaning.v1.ReportServiceInterface
import com.cleaning.rpc.ReportServiceImpl
import com.cleaning.repositories.ReportRepository
import com.connectrpc.protocols.ConnectProtocol
import io.ktor.server.application.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Application.configureConnect() {
    val reportRepository by inject<ReportRepository>()
    
    val reportService = ReportServiceImpl(reportRepository)
    
    routing {
        // Connect RPCエンドポイント（REST APIと並行運用可能）
        route("/connect") {
            // /connect/cleaning.v1.ReportService/ListReports
            // など
        }
    }
}
```

> **Note**: Connect-Kotlinの正式なKtor統合はまだ発展途上のため、
> 実際の実装時は最新のドキュメントを参照してください。

---

### Step 6: Flutter側 Connect実装

#### `pubspec.yaml` に依存関係追加

```yaml
dependencies:
  # 既存...
  connectrpc: ^0.3.0
  protobuf: ^3.1.0
```

#### `lib/data/repositories/connect_report_repository.dart`

```dart
import 'package:connectrpc/connectrpc.dart';
import '../../generated/cleaning/v1/report.pb.dart';
import '../../generated/cleaning/v1/report.connect.dart';
import '../../domain/entities/report.dart' as domain;
import '../../domain/repositories/report_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectReportRepository implements ReportRepository {
  final ReportServiceClient _client;
  
  ConnectReportRepository({required String baseUrl})
      : _client = ReportServiceClient(
          ConnectClient(
            baseUrl: baseUrl,
            interceptors: [_AuthInterceptor()],
          ),
        );
  
  @override
  Future<List<domain.Report>> getReports({required String month}) async {
    final request = ListReportsRequest()..month = month;
    final response = await _client.listReports(request);
    
    return response.reports.map(_toDomain).toList();
  }
  
  @override
  Future<domain.Report> createReport(domain.Report report) async {
    final request = CreateReportRequest()
      ..date = report.date.toIso8601String().split('T')[0]
      ..type = _toProtoType(report.type)
      ..item = report.item
      ..amount = report.amount;
    
    if (report.unitPrice != null) request.unitPrice = report.unitPrice!;
    if (report.duration != null) request.duration = report.duration!;
    if (report.note != null) request.note = report.note!;
    
    final response = await _client.createReport(request);
    return _toDomain(response.report);
  }
  
  @override
  Future<domain.Report> updateReport(domain.Report report) async {
    final request = UpdateReportRequest()
      ..id = report.id
      ..date = report.date.toIso8601String().split('T')[0]
      ..type = _toProtoType(report.type)
      ..item = report.item
      ..amount = report.amount;
    
    if (report.unitPrice != null) request.unitPrice = report.unitPrice!;
    if (report.duration != null) request.duration = report.duration!;
    if (report.note != null) request.note = report.note!;
    
    final response = await _client.updateReport(request);
    return _toDomain(response.report);
  }
  
  @override
  Future<void> deleteReport(String id) async {
    final request = DeleteReportRequest()..id = id;
    await _client.deleteReport(request);
  }
  
  // ========================================
  // 変換ヘルパー
  // ========================================
  
  domain.Report _toDomain(Report proto) {
    return domain.Report(
      id: proto.id,
      userId: proto.userId,
      date: DateTime.parse(proto.date),
      type: _toDomainType(proto.type),
      item: proto.item,
      unitPrice: proto.hasUnitPrice() ? proto.unitPrice : null,
      duration: proto.hasDuration() ? proto.duration : null,
      amount: proto.amount,
      note: proto.hasNote() ? proto.note : null,
      month: proto.month,
      createdAt: proto.createdAt.toDateTime(),
      updatedAt: proto.hasUpdatedAt() ? proto.updatedAt.toDateTime() : null,
    );
  }
  
  ReportType _toProtoType(domain.ReportType type) {
    switch (type) {
      case domain.ReportType.work:
        return ReportType.REPORT_TYPE_WORK;
      case domain.ReportType.expense:
        return ReportType.REPORT_TYPE_EXPENSE;
    }
  }
  
  domain.ReportType _toDomainType(ReportType type) {
    switch (type) {
      case ReportType.REPORT_TYPE_WORK:
        return domain.ReportType.work;
      case ReportType.REPORT_TYPE_EXPENSE:
        return domain.ReportType.expense;
      default:
        throw ArgumentError('Unknown type: $type');
    }
  }
}

/// 認証インターセプター
class _AuthInterceptor implements Interceptor {
  @override
  UnaryFn wrapUnary(UnaryFn next) {
    return (request) async {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token != null) {
        request.headers['authorization'] = 'Bearer $token';
      }
      return next(request);
    };
  }
  
  @override
  StreamFn wrapStream(StreamFn next) => next;
}
```

---

### Step 7: providers.dart更新

```dart
// Connect RPC使用時
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (useConnectRpc) {
    return ConnectReportRepository(baseUrl: ktorApiUrl);
  } else if (useKtorApi) {
    return KtorReportRepository(ref.watch(ktorApiClientProvider));
  } else {
    return SupabaseReportRepository(ref.watch(supabaseClientProvider));
  }
});
```

---

## ディレクトリ構成（Phase 3.6完了後）

```
cleaning-report/
├── proto/
│   └── cleaning/
│       └── v1/
│           ├── report.proto      # NEW
│           └── pdf.proto         # NEW
├── buf.yaml                      # NEW
├── buf.gen.yaml                  # NEW
├── server/
│   └── src/main/kotlin/
│       └── com/cleaning/
│           └── rpc/
│               └── ReportServiceImpl.kt  # NEW
└── cleaning_report_app/
    └── lib/
        ├── generated/            # 自動生成
        │   └── cleaning/v1/
        └── data/repositories/
            └── connect_report_repository.dart  # NEW
```

---

## 成功基準チェックリスト

- [ ] .protoファイルからKotlin/Dartコード生成成功
- [ ] Ktor側でConnect RPCエンドポイント動作
- [ ] Flutter側からConnect RPC呼び出し成功
- [ ] 型安全な通信が実現

---

## 備考

### gRPCへの発展

Connect RPCはHTTP/JSONで動作しますが、本格的なgRPC（HTTP/2 + Protobuf binary）にも発展可能です。

### 段階的移行

REST APIとConnect RPCは並行運用可能です。まずはConnect RPCを追加し、安定したらREST APIを廃止する流れがおすすめです。

---

## Phase 3 完了！

おめでとうございます！Phase 3.6まで完了すると、以下が達成されています：

- ✅ Ktorでビジネスロジック再構築
- ✅ Google Cloud Runでホスティング
- ✅ Supabase Postgres直接接続
- ✅ Koinによる依存性注入
- ✅ gRPC（Connect RPC）通信
- ✅ 無料で運用

### 次のステップ: Phase 4

Phase 4では、以下のようなライブラリを使ってさらに発展させることができます：

- JDBI（DB接続）
- Apache PDFBox（PDF生成をKtor内製化）
- FreeMarker（メールテンプレート）

詳細は[phase概要.md](./phase概要.md)を参照してください。
