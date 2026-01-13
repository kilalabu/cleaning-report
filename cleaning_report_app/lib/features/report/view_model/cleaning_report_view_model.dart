import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../domain/entities/cleaning_report_type.dart';
import '../../../domain/entities/report.dart';
import '../../history/view_model/history_view_model.dart';
import '../domain/cleaning_item.dart';
import '../domain/report_calculator.dart';

import '../state/cleaning_report_state.dart';
export '../state/cleaning_report_state.dart';

// CleaningReportState class moved to cleaning_report_state.dart

class CleaningReportViewModel extends AutoDisposeNotifier<CleaningReportState> {
  @override
  CleaningReportState build() {
    final now = DateTime.now();
    return CleaningReportState(
      items: [CleaningItem(id: 0)],
      date: now.toIso8601String().substring(0, 10),
    );
  }

  void initialize({Map<String, dynamic>? initialItem}) {
    if (initialItem != null) {
      final item = CleaningItem(
        id: 0,
        type: _mapItemNameToType(initialItem['item']),
        duration: initialItem['duration'] as int? ?? 15,
        note: initialItem['note'] as String?,
      );
      state = state.copyWith(
        items: [item],
        date: initialItem['date'] as String,
        idCounter: 1,
      );
    } else {
      // リセットが必要な場合
      final now = DateTime.now();
      state = CleaningReportState(
        items: [CleaningItem(id: 0)],
        date: now.toIso8601String().substring(0, 10),
      );
    }
  }

  void updateDate(DateTime date) {
    state = state.copyWith(date: date.toIso8601String().substring(0, 10));
  }

  void addItem() {
    if (state.items.length >= 2) return;

    final newItem =
        CleaningItem(id: state.idCounter, type: CleaningReportType.extra);
    state = state.copyWith(
      items: [...state.items, newItem],
      idCounter: state.idCounter + 1,
    );
  }

  void removeItem(int index) {
    if (state.items.length <= 1) return;

    final newList = List<CleaningItem>.from(state.items);
    newList.removeAt(index);
    state = state.copyWith(items: newList);
  }

  void updateItem(int index, CleaningItem item) {
    final newList = List<CleaningItem>.from(state.items);
    newList[index] = item;
    state = state.copyWith(items: newList);
  }

  Future<void> submit(BuildContext context,
      {Map<String, dynamic>? initialItem, VoidCallback? onSuccess}) async {
    // バリデーション
    for (int i = 0; i < state.items.length; i++) {
      final item = state.items[i];
      if (item.type != CleaningReportType.regular &&
          (item.note == null || item.note!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${i + 1}番目の業務: 備考を入力してください')),
        );
        return;
      }
    }

    state = state.copyWith(isSubmitting: true);
    final repository = ref.read(reportRepositoryProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    try {
      for (final item in state.items) {
        final calculatedData = ReportCalculator.calculateWorkItem(item);
        final date = DateTime.parse(state.date);
        final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';

        final report = Report(
          id: initialItem?['id'] ?? '',
          userId: userId,
          date: date,
          type: ReportType.work,
          cleaningType: calculatedData['cleaningType'] as CleaningReportType?,
          amount: calculatedData['amount'] as int,
          unitPrice: calculatedData['unitPrice'] as int?,
          duration: calculatedData['duration'] as int?,
          note: calculatedData['note'] as String?,
          month: month,
          createdAt: DateTime.now(),
        );

        if (initialItem != null) {
          await repository.updateReport(report);
        } else {
          await repository.createReport(report);
        }
      }

      state = state.copyWith(isSubmitting: false);

      // 履歴の更新
      // historyViewModelProvider がもし使われていれば更新する
      // HistoryScreen が表示されていなければ、次回表示時にロードされるので問題ないが、
      // 戻ったときに古いデータだと困る。
      // HistoryViewModel は autoDispose なので、画面がなければ破棄される？
      // もし破棄されていれば次回 fetch なのでOK。
      // 画面が残っている場合 (Tabなど) は refresh が必要。
      // ここでは念のため refresh を試みるが、プロバイダーが破棄されている場合は何もしない（あるいは再生成される）
      // ただし、月が変わった場合なども考慮が必要。

      // 簡易的に 現在の月だけ refresh する
      try {
        ref.read(historyViewModelProvider.notifier).refresh();
      } catch (_) {
        // HistoryViewModel がまだ生成されていないか、破棄されている場合は無視
      }

      if (context.mounted) {
        if (initialItem != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('更新しました')));
          if (onSuccess != null) onSuccess();
        } else {
          await showSuccessDialog(context, '報告を送信しました\nお疲れ様でした');
          // リセット
          final now = DateTime.now();
          state = CleaningReportState(
            items: [CleaningItem(id: state.idCounter)],
            date: now.toIso8601String().substring(0, 10),
            idCounter: state.idCounter + 1,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(isSubmitting: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  CleaningReportType _mapItemNameToType(String? itemName) {
    if (itemName == null) return CleaningReportType.regular;
    return CleaningReportType.fromLabel(itemName) ?? CleaningReportType.regular;
  }
}

final cleaningReportViewModelProvider =
    NotifierProvider.autoDispose<CleaningReportViewModel, CleaningReportState>(
        CleaningReportViewModel.new);
