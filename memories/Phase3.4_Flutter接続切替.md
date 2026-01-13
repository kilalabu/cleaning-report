# Phase 3.4: Flutter側接続切り替え 実装手順書

## 概要

このドキュメントでは、FlutterアプリのAPIリクエスト先をSupabase → Ktorへ切り替えます。
既存のリポジトリパターンを活用し、Data Layer実装のみ差し替えます。

**ゴール**: 環境変数でSupabase/Ktorを切り替え可能にする

---

## 前提条件

- Phase 3.3が完了していること（Ktor APIが認証付きで動作）
- 現在のFlutterアプリが正常に動作していること

---

## 既存アーキテクチャの確認

現在のFlutterアプリは以下の構造です：

```
lib/
├── domain/
│   └── repositories/
│       └── report_repository.dart      # インターフェース
├── data/
│   └── repositories/
│       └── supabase_report_repository.dart  # Supabase実装
└── core/
    └── di/
        └── providers.dart              # DI設定
```

**ポイント**: UI層は`ReportRepository`インターフェースのみに依存しているため、実装クラスを差し替えるだけでOK。

---

## 実装手順

### Step 1: HTTPクライアントクラス作成

#### `lib/data/datasources/ktor_api_client.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ktor APIクライアント
///
/// Supabase Auth JWTをヘッダーに付与してKtor APIを呼び出す
class KtorApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  KtorApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// 認証ヘッダーを取得
  Map<String, String> get _headers {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GETリクエスト
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response = await _httpClient.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  /// POSTリクエスト
  Future<dynamic> post(String path, {required Map<String, dynamic> body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  /// PUTリクエスト
  Future<dynamic> put(String path, {required Map<String, dynamic> body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.put(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  /// DELETEリクエスト
  Future<void> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.delete(uri, headers: _headers);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Delete failed: ${response.body}',
      );
    }
  }

  /// レスポンスハンドリング
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (response.statusCode == 403) {
      throw ForbiddenException('Forbidden');
    } else if (response.statusCode == 404) {
      throw NotFoundException('Not found');
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.body,
      );
    }
  }
}

/// API例外クラス
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(statusCode: 401, message: message);
}

class ForbiddenException extends ApiException {
  ForbiddenException(String message) : super(statusCode: 403, message: message);
}

class NotFoundException extends ApiException {
  NotFoundException(String message) : super(statusCode: 404, message: message);
}
```

**解説**:
- `Supabase.instance.client.auth.currentSession?.accessToken`: 既存のSupabase認証トークンを使用
- Ktor APIはこのトークンを検証してユーザーを識別

---

### Step 2: Ktorリポジトリ実装

#### `lib/data/repositories/ktor_report_repository.dart`

```dart
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/ktor_api_client.dart';

/// Ktor API実装のReportRepository
class KtorReportRepository implements ReportRepository {
  final KtorApiClient _apiClient;

  KtorReportRepository(this._apiClient);

  @override
  Future<List<Report>> getReports({required String month}) async {
    final response = await _apiClient.get(
      '/api/v1/reports',
      queryParams: {'month': month},
    );
    
    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => _fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<Report> createReport(Report report) async {
    final response = await _apiClient.post(
      '/api/v1/reports',
      body: _toCreateRequest(report),
    );
    
    return _fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Report> updateReport(Report report) async {
    final response = await _apiClient.put(
      '/api/v1/reports/${report.id}',
      body: _toCreateRequest(report),
    );
    
    return _fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteReport(String id) async {
    await _apiClient.delete('/api/v1/reports/$id');
  }

  /// JSON → Report変換
  Report _fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      userId: json['userId'] as String,
      date: DateTime.parse(json['date'] as String),
      type: ReportType.values.byName(json['type'] as String),
      item: json['item'] as String,
      unitPrice: json['unitPrice'] as int?,
      duration: json['duration'] as int?,
      amount: json['amount'] as int,
      note: json['note'] as String?,
      month: json['month'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  /// Report → リクエストJSON変換
  Map<String, dynamic> _toCreateRequest(Report report) {
    return {
      'date': report.date.toIso8601String().split('T')[0],  // "yyyy-MM-dd"
      'type': report.type.name,
      'item': report.item,
      if (report.unitPrice != null) 'unitPrice': report.unitPrice,
      if (report.duration != null) 'duration': report.duration,
      'amount': report.amount,
      if (report.note != null) 'note': report.note,
    };
  }
}
```

---

### Step 3: providers.dart更新

#### `lib/core/di/providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/ktor_api_client.dart';
import '../../data/repositories/ktor_report_repository.dart';
import '../../data/repositories/supabase_report_repository.dart';
import '../../domain/repositories/report_repository.dart';

// ========================================
// 環境変数
// ========================================

/// Ktor APIを使用するかどうか
/// flutter run --dart-define=USE_KTOR_API=true で有効化
const bool useKtorApi = bool.fromEnvironment('USE_KTOR_API', defaultValue: false);

/// Ktor APIのベースURL
const String ktorApiUrl = String.fromEnvironment(
  'KTOR_API_URL',
  defaultValue: 'http://localhost:8080',
);

// ========================================
// Supabase
// ========================================

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ========================================
// Ktor API Client
// ========================================

final ktorApiClientProvider = Provider<KtorApiClient>((ref) {
  return KtorApiClient(baseUrl: ktorApiUrl);
});

// ========================================
// Report Repository（切り替え可能）
// ========================================

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (useKtorApi) {
    // Ktor API経由
    final apiClient = ref.watch(ktorApiClientProvider);
    return KtorReportRepository(apiClient);
  } else {
    // Supabase直接接続
    final client = ref.watch(supabaseClientProvider);
    return SupabaseReportRepository(client);
  }
});

// ========================================
// 既存のその他のProviderはそのまま維持
// ========================================
// authRepositoryProvider, pdfRepositoryProvider など
```

**解説**:
- `bool.fromEnvironment`: ビルド時に環境変数を埋め込み
- `useKtorApi`がtrueの場合のみKtorリポジトリを使用
- 既存のSupabaseリポジトリはそのまま残す（フォールバック用）

---

### Step 4: ビルドコマンド

#### Supabase版（既存）

```bash
flutter run -d chrome
```

#### Ktor版（新規）

```bash
# ローカル開発
flutter run -d chrome \
  --dart-define=USE_KTOR_API=true \
  --dart-define=KTOR_API_URL=http://localhost:8080

# 本番（Cloud Run）
flutter run -d chrome \
  --dart-define=USE_KTOR_API=true \
  --dart-define=KTOR_API_URL=https://cleaning-report-api-xxxxx-an.a.run.app
```

#### プロダクションビルド

```bash
flutter build web \
  --dart-define=USE_KTOR_API=true \
  --dart-define=KTOR_API_URL=https://your-cloud-run-url
```

---

### Step 5: 環境切り替え用スクリプト

#### `cleaning_report_app/run_ktor.sh`

```bash
#!/bin/bash
# Ktor API接続モードで起動

export USE_KTOR_API=true
export KTOR_API_URL=${KTOR_API_URL:-http://localhost:8080}

flutter run -d chrome \
  --dart-define=USE_KTOR_API=true \
  --dart-define=KTOR_API_URL=$KTOR_API_URL
```

```bash
chmod +x run_ktor.sh
./run_ktor.sh
```

---

### Step 6: 動作確認

#### 1. Ktorサーバー起動（別ターミナル）

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/server
export $(cat .env | xargs) && ./gradlew run
```

#### 2. Flutter起動（Ktorモード）

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/cleaning_report_app
./run_ktor.sh
```

#### 3. 確認項目

- [ ] ログイン成功（Supabase Auth経由のまま）
- [ ] レポート一覧取得成功
- [ ] レポート作成成功
- [ ] レポート更新成功
- [ ] レポート削除成功

---

## CORS設定（Ktor側）

FlutterアプリからKtor APIにアクセスする際、CORSエラーが発生する場合があります。

#### `server/src/main/kotlin/com/cleaning/plugins/Cors.kt`

```kotlin
package com.cleaning.plugins

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.plugins.cors.routing.*

fun Application.configureCors() {
    install(CORS) {
        // 開発用
        allowHost("localhost:8080")
        allowHost("localhost:3000")
        allowHost("127.0.0.1:8080")
        
        // 本番用（GitHub Pages）
        allowHost("yourusername.github.io")
        
        // Cloud Run URL
        allowHost("cleaning-report-api-xxxxx-an.a.run.app")
        
        // 許可するヘッダー
        allowHeader(HttpHeaders.ContentType)
        allowHeader(HttpHeaders.Authorization)
        
        // 許可するメソッド
        allowMethod(HttpMethod.Get)
        allowMethod(HttpMethod.Post)
        allowMethod(HttpMethod.Put)
        allowMethod(HttpMethod.Delete)
        allowMethod(HttpMethod.Options)
        
        // 認証情報を含める
        allowCredentials = true
    }
}
```

#### `Application.kt`に追加

```kotlin
embeddedServer(Netty, port = port, host = "0.0.0.0") {
    configureCors()  // 追加
    configureKoin()
    configureAuthentication()
    configureRouting()
    configureSerialization()
}.start(wait = true)
```

---

## ディレクトリ構成（Phase 3.4完了後）

```
cleaning_report_app/lib/
├── core/
│   └── di/
│       └── providers.dart              # 更新: 切り替えロジック
├── data/
│   ├── datasources/
│   │   └── ktor_api_client.dart        # NEW
│   └── repositories/
│       ├── supabase_report_repository.dart  # 既存
│       └── ktor_report_repository.dart      # NEW
└── domain/
    └── repositories/
        └── report_repository.dart      # 変更なし
```

---

## 成功基準チェックリスト

- [ ] `USE_KTOR_API=false`でSupabase直接接続が動作
- [ ] `USE_KTOR_API=true`でKtor API経由が動作
- [ ] Flutter → Ktor API経由でCRUD操作成功
- [ ] CORSエラーなし

---

## トラブルシューティング

### Q: CORSエラーが発生

**A**: 
1. Ktor側のCORS設定を確認
2. `allowHost`にFlutterアプリのホストを追加
3. ローカル開発時は`localhost`のポート番号も一致させる

### Q: 401 Unauthorized

**A**: 
1. Supabaseにログイン済みか確認
2. トークンの有効期限を確認
3. Ktor側のJWT Secret設定を確認

---

## 次のステップ

Phase 3.4が完了したら、[Phase 3.5: PDF生成のKtor経由化](./Phase3.5_PDF生成.md)に進んでください。
