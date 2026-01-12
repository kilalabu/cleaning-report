import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/pdf_repository.dart';

/// Supabase Edge Function を使った PDF生成リポジトリ実装
class SupabasePdfRepository implements PdfRepository {
  final SupabaseClient _client;

  SupabasePdfRepository(this._client);

  @override
  Future<Map<String, dynamic>> generatePdf({
    required String month,
    required DateTime billingDate,
  }) async {
    final billingDateStr =
        '${billingDate.year}-${billingDate.month.toString().padLeft(2, '0')}-${billingDate.day.toString().padLeft(2, '0')}';

    try {
      final response = await _client.functions.invoke(
        'generate-pdf',
        body: {
          'month': month,
          'billingDate': billingDateStr,
        },
      );

      if (response.status == 200) {
        final result = response.data as Map<String, dynamic>;

        if (result['success'] == true) {
          return {
            'success': true,
            'dataUrl': result['data'] as String,
            'filename': result['filename'] as String,
          };
        } else {
          return {
            'success': false,
            'message': result['message'] ?? '不明なエラー',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'PDF生成エラー: ${response.status}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
