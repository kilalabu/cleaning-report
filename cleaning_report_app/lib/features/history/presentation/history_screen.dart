import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../domain/entities/report.dart';
import '../../report/presentation/cleaning_report_screen.dart';
import '../../report/presentation/expense_report_screen.dart';
import '../view_model/history_view_model.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModelState = ref.watch(historyViewModelProvider);
    final viewModel = ref.read(historyViewModelProvider.notifier);

    // 権限制御などはViewModel内で処理、またはここでstateに基づいて表示制御
    // ...

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('履歴'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 合計サマリーカード
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.summaryCardDecoration,
                  child: Column(
                    children: [
                      Text(
                        '${viewModel.getMonthLabel(viewModelState.selectedMonth)}の請求合計',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${viewModel.formatNumber(viewModelState.totalAmount)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // PDF発行カード
                Container(
                  decoration: AppTheme.cardDecoration,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: AppTheme.inputDecoration,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: viewModelState.selectedMonth,
                              isExpanded: true,
                              icon: Icon(Icons.expand_more,
                                  color: AppTheme.mutedForeground),
                              items: viewModel.monthOptions.map((m) {
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(viewModel.getMonthLabel(m)),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  viewModel.updateMonth(v);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: viewModelState.isGeneratingPdf
                                ? null
                                : () => _showDownloadDialog(context, ref),
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: viewModelState.isGeneratingPdf
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.download,
                                        color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 履歴リスト
                viewModelState.reports.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.border,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'この月の履歴はありません',
                            style: TextStyle(color: AppTheme.mutedForeground),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: items.map((report) {
                        final canEdit = viewModel.isEditable(report.date);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HistoryItemTile(
                            report: report,
                            onDelete: canEdit
                                ? () => _deleteItem(context, ref, report.id)
                                : null,
                            onEdit: canEdit
                                ? () => _editItem(context, ref, report)
                                : null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'エラー: $e',
                        style: TextStyle(color: AppTheme.destructive),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDownloadDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final now = DateTime.now();
    DateTime selectedDate = now;
    final viewModelState = ref.watch(historyViewModelProvider);
    final viewModel = ref.read(historyViewModelProvider.notifier);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final dateStr =
              '${selectedDate.year}年${selectedDate.month}月${selectedDate.day}日';
          final monthParts = viewModelState.selectedMonth.split('-');
          final formattedMonth =
              '${monthParts[0]}年${int.parse(monthParts[1])}月分';

          return AlertDialog(
            title: const Text('請求書の発行'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('対象: $formattedMonth',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('請求日を選択してください', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      locale: const Locale('ja'),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateStr, style: const TextStyle(fontSize: 16)),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  viewModel.generatePdf(context, selectedDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('発行する'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteItem(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDeleteConfirmDialog(context: context);

    if (confirmed == true) {
      await ref
          .read(historyViewModelProvider.notifier)
          .deleteReport(id, context);
    }
  }

  Future<void> _editItem(
      BuildContext context, WidgetRef ref, Report report) async {
    final isWork = report.type == ReportType.work;

    // Report EntityをMap<String, dynamic>に変換（既存のフォームとの互換性のため）
    final item = {
      'id': report.id,
      'date': report.date.toIso8601String().split('T')[0],
      'type': report.type.value,
      'item': report.item,
      'unit_price': report.unitPrice,
      'duration': report.duration,
      'amount': report.amount,
      'note': report.note,
      'month': report.month,
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.background,
      builder: (ctx) => Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(isWork ? '業務内容の修正' : '立替費用の修正'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: isWork
                  ? CleaningReportForm(
                      initialItem: item,
                      onSuccess: () {
                        Navigator.pop(ctx);
                        ref.read(historyViewModelProvider.notifier).refresh();
                      },
                    )
                  : ExpenseReportForm(
                      initialItem: item,
                      onSuccess: () {
                        Navigator.pop(ctx);
                        ref.read(historyViewModelProvider.notifier).refresh();
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryItemTile extends StatelessWidget {
  final Report report;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _HistoryItemTile({
    required this.report,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isWork = report.type == ReportType.work;
    final icon = isWork ? Icons.cleaning_services : Icons.receipt_long;
    final iconColor = isWork ? AppTheme.primary : AppTheme.accent;
    final iconBgColor = isWork
        ? AppTheme.primary.withOpacity(0.15)
        : AppTheme.accent.withOpacity(0.15);

    final dateStr =
        '${report.date.year}-${report.date.month.toString().padLeft(2, '0')}-${report.date.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // アイコンバッジ
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),

          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.item,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: report.item == '追加業務'
                        ? AppTheme.accent
                        : report.item == '緊急対応'
                            ? AppTheme.destructive
                            : null,
                  ),
                ),
                Text(
                  '$dateStr${report.note != null && report.note!.isNotEmpty ? ' ・ ${report.note}' : ''}',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 金額
          Text(
            '¥${report.amount}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          // 編集ボタン
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 20, color: AppTheme.mutedForeground),
              onPressed: onEdit,
              tooltip: '編集',
              splashRadius: 20,
            ),

          // 削除ボタン
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: AppTheme.destructive.withOpacity(0.7)),
              onPressed: onDelete,
              tooltip: '削除',
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}
