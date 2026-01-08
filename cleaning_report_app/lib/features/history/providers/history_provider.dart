import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/gas_api_client.dart';
import '../../auth/providers/auth_provider.dart';

// History provider that accepts month as parameter
final historyProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, month) async {
  final api = ref.read(apiClientProvider);
  
  final result = await api.getData(month: month);
  
  if (result['success'] == true) {
    final data = result['data'] as List<dynamic>?;
    return data?.map((e) => e as Map<String, dynamic>).toList() ?? [];
  }
  
  throw Exception(result['message'] ?? 'Failed to load history');
});

// Total amount for specified month
final totalAmountProvider = Provider.family<int, String>((ref, month) {
  final historyAsync = ref.watch(historyProvider(month));
  
  return historyAsync.when(
    data: (items) => items.fold(0, (sum, item) => sum + ((item['amount'] as num?)?.toInt() ?? 0)),
    loading: () => 0,
    error: (_, __) => 0,
  );
});
