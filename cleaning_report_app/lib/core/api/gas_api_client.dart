import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Client for Google Apps Script backend
class GasApiClient {
  // TODO: Replace with your deployed GAS Web App URL
  static const String baseUrl = 'https://script.google.com/macros/s/AKfycbyh2EtK3gNo-xlgzaf_oD6btA-YzYUtVJXTRqpg4CwyqT6HfxXwqcuscR7LfhrUDgKFsw/exec';

  /// GET request helper
  Future<Map<String, dynamic>> get(String action, {Map<String, String>? params}) async {
    final queryParams = {'action': action, ...?params};
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    try {
      // GAS redirects, so we need to follow redirects
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// POST request helper
  Future<Map<String, dynamic>> post(String action, Map<String, dynamic> data) async {
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
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
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

  Future<Map<String, dynamic>> saveReport(Map<String, dynamic> reportData) async {
    return post('saveReport', reportData);
  }

  Future<Map<String, dynamic>> deleteData(String id) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({'action': 'deleteData', 'id': id});
    
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> generatePdf({String? month}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = month;
    return get('generatePDF', params: params);
  }
}
