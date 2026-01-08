import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/gas_api_client.dart';
import '../../auth/providers/auth_provider.dart';

final historyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  
  // Get current month
  final now = DateTime.now();
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  
  final result = await api.getData(month: month);
  
  if (result['success'] == true) {
    final data = result['data'] as List<dynamic>?;
    return data?.map((e) => e as Map<String, dynamic>).toList() ?? [];
  }
  
  throw Exception(result['message'] ?? 'Failed to load history');
});

// Total amount for current month
final totalAmountProvider = Provider<int>((ref) {
  final historyAsync = ref.watch(historyProvider);
  
  return historyAsync.when(
    data: (items) => items.fold(0, (sum, item) => sum + ((item['amount'] as num?)?.toInt() ?? 0)),
    loading: () => 0,
    error: (_, __) => 0,
  );
});
