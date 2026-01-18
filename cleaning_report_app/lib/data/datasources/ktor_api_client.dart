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
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response = await _httpClient.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  /// POSTリクエスト
  Future<dynamic> post(String path,
      {required Map<String, dynamic> body}) async {
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
  UnauthorizedException(String message)
      : super(statusCode: 401, message: message);
}

class ForbiddenException extends ApiException {
  ForbiddenException(String message) : super(statusCode: 403, message: message);
}

class NotFoundException extends ApiException {
  NotFoundException(String message) : super(statusCode: 404, message: message);
}
