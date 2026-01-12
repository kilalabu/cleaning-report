import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../domain/entities/report.dart';

part 'history_state.freezed.dart';

@freezed
abstract class HistoryState with _$HistoryState {
  const HistoryState._();

  const factory HistoryState({
    required String selectedMonth,
    required AsyncValue<List<Report>> reports,
    @Default(false) bool isGeneratingPdf,
  }) = _HistoryState;

  // 合計金額を計算するゲッター
  int get totalAmount {
    return reports.when(
      data: (items) => items.fold(0, (sum, item) => sum + item.amount),
      loading: () => 0,
      error: (_, __) => 0,
    );
  }
}
