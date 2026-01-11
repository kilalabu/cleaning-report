import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../domain/entities/report.dart';

/// 履歴データを取得するProvider（月指定）
///
/// RLSにより:
/// - staff: 自分のレポートのみ取得
/// - admin: 全レポートを取得
final historyProvider =
    FutureProvider.family<List<Report>, String>((ref, month) async {
  final repository = ref.read(reportRepositoryProvider);
  return repository.getReports(month: month);
});

/// 指定月の合計金額
final totalAmountProvider = Provider.family<int, String>((ref, month) {
  final historyAsync = ref.watch(historyProvider(month));

  return historyAsync.when(
    data: (items) => items.fold(0, (sum, item) => sum + item.amount),
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// レポート削除用のNotifier
class HistoryNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// レポートを削除し、キャッシュを無効化
  Future<void> deleteReport(String id, String month) async {
    final repository = ref.read(reportRepositoryProvider);
    await repository.deleteReport(id);
    ref.invalidate(historyProvider(month));
  }
}

final historyNotifierProvider =
    AutoDisposeAsyncNotifierProvider<HistoryNotifier, void>(
  () => HistoryNotifier(),
);
