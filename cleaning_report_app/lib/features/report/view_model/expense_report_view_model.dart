import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../domain/entities/report.dart';
import '../../history/view_model/history_view_model.dart';

import '../state/expense_report_state.dart';
export '../state/expense_report_state.dart';

// ExpenseReportState class moved to expense_report_state.dart

class ExpenseReportViewModel extends AutoDisposeNotifier<ExpenseReportState> {
  @override
  ExpenseReportState build() {
    final now = DateTime.now();
    return ExpenseReportState(
      date: now.toIso8601String().substring(0, 10),
    );
  }

  void initialize({Map<String, dynamic>? initialItem}) {
    if (initialItem != null) {
      state = ExpenseReportState(
        date: initialItem['date'] as String,
        item: initialItem['item'] as String,
        amount: initialItem['amount'].toString(),
        note: initialItem['note'] as String?,
      );
    } else {
      final now = DateTime.now();
      state = ExpenseReportState(
        date: now.toIso8601String().substring(0, 10),
      );
    }
  }

  void updateDate(DateTime date) {
    state = state.copyWith(date: date.toIso8601String().substring(0, 10));
  }

  void updateItem(String item) {
    state = state.copyWith(item: item);
  }

  void updateAmount(String amount) {
    state = state.copyWith(amount: amount);
  }

  void updateNote(String note) {
    state = state.copyWith(note: note.isEmpty ? null : note);
  }

  Future<void> submit(BuildContext context,
      {Map<String, dynamic>? initialItem,
      VoidCallback? onSuccess,
      VoidCallback? onReset}) async {
    // バリデーション
    if (state.item.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('品目名を入力してください')),
      );
      return;
    }
    if (state.amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額を入力してください')),
      );
      return;
    }
    if (int.tryParse(state.amount) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額は数値で入力してください')),
      );
      return;
    }

    state = state.copyWith(isSubmitting: true);
    final repository = ref.read(reportRepositoryProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    try {
      final date = DateTime.parse(state.date);
      final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      final report = Report(
        id: initialItem?['id'] ?? '',
        userId: userId,
        date: date,
        type: ReportType.expense,
        expenseItem: state.item,
        unitPrice: null,
        duration: null,
        amount: int.parse(state.amount),
        note: state.note,
        month: month,
        createdAt: DateTime.now(),
      );

      if (initialItem != null) {
        await repository.updateReport(report);
      } else {
        await repository.createReport(report);
      }

      state = state.copyWith(isSubmitting: false);

      // 履歴の更新
      try {
        ref.read(historyViewModelProvider.notifier).refresh();
      } catch (_) {}

      if (context.mounted) {
        if (initialItem != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('更新しました')));
          if (onSuccess != null) onSuccess();
        } else {
          await showSuccessDialog(context, '報告を送信しました');
          // リセットコールバック呼び出し
          if (onReset != null) onReset();
          // State リセット
          final now = DateTime.now();
          state = ExpenseReportState(
            date: now.toIso8601String().substring(0, 10),
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
}

final expenseReportViewModelProvider =
    NotifierProvider.autoDispose<ExpenseReportViewModel, ExpenseReportState>(
        ExpenseReportViewModel.new);
