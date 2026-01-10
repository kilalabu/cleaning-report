import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Client for Google Apps Script backend
class GasApiClient {
  static const String baseUrl =
      'https://script.google.com/macros/s/AKfycbyQ9AazjlpRyc4zAiHuXLudYN5Fa5Vwnwe96n2NvRat3lrqcVY4sKcoJ5yqtr4OEF0mUA/exec';

  /// GET request helper with structured error handling
  Future<Map<String, dynamic>> get(String action,
      {Map<String, String>? params}) async {
    final queryParams = {'action': action, ...?params};
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;

        // Log errors from API
        if (decoded['success'] == false) {
          _logApiError(action, decoded);
        }

        return decoded;
      } else {
        final error = {
          'success': false,
          'message': 'HTTP Error: ${response.statusCode}',
          'errorDetail':
              'Status: ${response.statusCode}, Body: ${response.body}'
        };
        _logApiError(action, error);
        return error;
      }
    } catch (e) {
      final error = {
        'success': false,
        'message': 'ネットワークエラーが発生しました',
        'errorDetail': e.toString()
      };
      _logApiError(action, error);
      return error;
    }
  }

  /// Log API errors with details
  void _logApiError(String action, Map<String, dynamic> response) {
    final errorId = response['errorId'] ?? 'N/A';
    final message = response['message'] ?? 'Unknown error';
    final detail = response['errorDetail'] ?? '';

    print('🔴 [API Error] Action: $action');
    print('   Error ID: $errorId');
    print('   Message: $message');
    if (detail.isNotEmpty) {
      print('   Detail: $detail');
    }
  }

  /// POST request helper (kept for compatibility)
  Future<Map<String, dynamic>> post(
      String action, Map<String, dynamic> data) async {
    final uri = Uri.parse(baseUrl);

    try {
      final body = jsonEncode({'action': action, 'data': data});
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'HTTP Error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // === API Methods ===

  Future<Map<String, dynamic>> verifyPin(String pin) async {
    return get('verifyPin', params: {'pin': pin});
  }

  Future<Map<String, dynamic>> getData({String? month}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = month;
    return get('getData', params: params);
  }

  Future<Map<String, dynamic>> saveReport(
      Map<String, dynamic> reportData) async {
    final dataJson = jsonEncode(reportData);
    return get('saveReport', params: {'data': dataJson});
  }

  Future<Map<String, dynamic>> deleteData(String id) async {
    return get('deleteData', params: {'id': id});
  }

  Future<Map<String, dynamic>> updateReport(
      Map<String, dynamic> reportData) async {
    final dataJson = jsonEncode(reportData);
    return get('updateReport', params: {'data': dataJson});
  }

  Future<Map<String, dynamic>> generatePdf(
      {String? month, DateTime? billingDate}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = month;
    if (billingDate != null) {
      params['billingDate'] =
          "${billingDate.year}-${billingDate.month.toString().padLeft(2, '0')}-${billingDate.day.toString().padLeft(2, '0')}";
    }
    return get('generatePDF', params: params);
  }
}
