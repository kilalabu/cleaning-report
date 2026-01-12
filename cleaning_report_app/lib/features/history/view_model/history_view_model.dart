import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:html' as html;

import '../../../core/utils/dialog_utils.dart';

import '../../../core/di/providers.dart';
import '../state/history_state.dart';
export '../state/history_state.dart';

// HistoryState class moved to history_state.dart

class HistoryViewModel extends AutoDisposeNotifier<HistoryState> {
  @override
  HistoryState build() {
    final now = DateTime.now();
    final initialMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // 副作用としてデータ取得を開始
    // buildメソッド内での非同期処理呼び出しは推奨されない場合もあるが、
    // 初期化トリガーとして microtask で実行する
    Future.microtask(() => _fetchReports(initialMonth));

    return HistoryState(
      selectedMonth: initialMonth,
      reports: const AsyncValue.loading(),
    );
  }

  Future<void> _fetchReports(String month) async {
    state = state.copyWith(reports: const AsyncValue.loading());
    try {
      final repository = ref.read(reportRepositoryProvider);
      final reports = await repository.getReports(month: month);
      state = state.copyWith(reports: AsyncValue.data(reports));
    } catch (e, stack) {
      state = state.copyWith(reports: AsyncValue.error(e, stack));
    }
  }

  void updateMonth(String newMonth) {
    if (state.selectedMonth == newMonth) return;
    state = state.copyWith(selectedMonth: newMonth);
    _fetchReports(newMonth);
  }

  List<String> get monthOptions {
    final now = DateTime.now();
    final start = DateTime(2025, 12);

    int diff = (now.year - start.year) * 12 + now.month - start.month + 1;
    if (diff < 1) diff = 1;

    return List.generate(diff, (i) {
      final d = DateTime(now.year, now.month - i);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  String getMonthLabel(String month) {
    final parts = month.split('-');
    final year = parts[0];
    final monthNum = int.parse(parts[1]);
    return '$year年$monthNum月';
  }

  String formatNumber(int n) {
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  bool isEditable(DateTime date) {
    final now = DateTime.now();
    // 許可される最も古い月の1日（先月の1日）
    final cutoff = DateTime(now.year, now.month - 1, 1);
    return !date.isBefore(cutoff);
  }

  Future<void> deleteReport(String id, BuildContext context) async {
    // 削除処理
    try {
      final repository = ref.read(reportRepositoryProvider);
      await repository.deleteReport(id);

      // 再読み込み
      await _fetchReports(state.selectedMonth);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }

  Future<void> generatePdf(
    BuildContext context,
    DateTime billingDate,
  ) async {
    if (state.isGeneratingPdf) return;

    state = state.copyWith(isGeneratingPdf: true);

    try {
      final pdfRepository = ref.read(pdfRepositoryProvider);
      final result = await pdfRepository.generatePdf(
        month: state.selectedMonth,
        billingDate: billingDate,
      );

      state = state.copyWith(isGeneratingPdf: false);

      if (result['success'] == true) {
        final dataUrl = result['dataUrl'] as String;
        final filename = result['filename'] as String;

        // ダウンロード開始
        html.AnchorElement(href: dataUrl)
          ..setAttribute('download', filename)
          ..click();

        if (context.mounted) {
          await showSuccessDialog(context, '請求書のダウンロードが\n完了しました');
        }
        return; // 成功
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: ${result['message']}')),
          );
        }
      }
    } catch (e) {
      state = state.copyWith(isGeneratingPdf: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  // 外部からの再読み込み要求（レポート追加・更新時など）
  Future<void> refresh() async {
    await _fetchReports(state.selectedMonth);
  }
}

final historyViewModelProvider =
    NotifierProvider.autoDispose<HistoryViewModel, HistoryState>(
        HistoryViewModel.new);
