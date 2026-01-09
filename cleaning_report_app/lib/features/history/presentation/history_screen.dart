import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'dart:html' as html;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../providers/history_provider.dart';
import '../../auth/providers/auth_provider.dart';

import '../../report/presentation/cleaning_report_screen.dart';
import '../../report/presentation/expense_report_screen.dart';

class HistoryScreen extends HookConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = useState(_getCurrentMonth());
    final isGeneratingPdf = useState(false);
    final historyAsync = ref.watch(historyProvider(selectedMonth.value));
    final totalAmount = ref.watch(totalAmountProvider(selectedMonth.value));

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
                        '${_getMonthLabel(selectedMonth.value)}の請求合計',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${_formatNumber(totalAmount)}',
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
                              value: selectedMonth.value,
                              isExpanded: true,
                              icon: Icon(Icons.expand_more,
                                  color: AppTheme.mutedForeground),
                              items: _generateMonthOptions().map((m) {
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(_getMonthLabel(m)),
                                );
                              }).toList(),
                              onChanged: (v) => selectedMonth.value =
                                  v ?? selectedMonth.value,
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
                            onTap: isGeneratingPdf.value
                                ? null
                                : () => _generatePdf(context, ref,
                                    selectedMonth.value, isGeneratingPdf),
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: isGeneratingPdf.value
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
                historyAsync.when(
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
                      children: items
                          .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _HistoryItemTile(
                                  item: item,
                                  onDelete: () => _deleteItem(
                                      context,
                                      ref,
                                      item['id'] as String,
                                      selectedMonth.value),
                                  onEdit: () => _editItem(
                                      context, ref, item, selectedMonth.value),
                                ),
                              ))
                          .toList(),
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

  String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  List<String> _generateMonthOptions() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _getMonthLabel(String month) {
    final currentMonth = _getCurrentMonth();
    if (month == currentMonth) {
      return '今月';
    }
    final parts = month.split('-');
    final year = parts[0];
    final monthNum = int.parse(parts[1]);
    return '$year年${monthNum}月';
  }

  Future<void> _generatePdf(
    BuildContext context,
    WidgetRef ref,
    String month,
    ValueNotifier<bool> isGenerating,
  ) async {
    isGenerating.value = true;

    final api = ref.read(apiClientProvider);
    final result = await api.generatePdf(month: month);

    isGenerating.value = false;

    if (result['success'] == true) {
      final dataUrl = result['data'] as String;
      final filename = result['filename'] as String;

      final anchor = html.AnchorElement(href: dataUrl)
        ..setAttribute('download', filename)
        ..click();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ダウンロードを開始しました')),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: ${result['message']}')),
        );
      }
    }
  }

  Future<void> _deleteItem(
      BuildContext context, WidgetRef ref, String id, String month) async {
    final confirmed = await showDeleteConfirmDialog(context: context);

    if (confirmed == true) {
      final api = ref.read(apiClientProvider);
      await api.deleteData(id);
      ref.invalidate(historyProvider(month));

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('削除しました')));
      }
    }
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref,
      Map<String, dynamic> item, String month) async {
    final isWork = item['type'] == 'work';

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
                      onSuccess: () => Navigator.pop(ctx),
                    )
                  : ExpenseReportForm(
                      initialItem: item,
                      onSuccess: () => Navigator.pop(ctx),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _HistoryItemTile({
    required this.item,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isWork = item['type'] == 'work';
    final icon = isWork ? Icons.cleaning_services : Icons.receipt_long;
    final iconColor = isWork ? AppTheme.primary : AppTheme.accent;
    final iconBgColor = isWork
        ? AppTheme.primary.withOpacity(0.15)
        : AppTheme.accent.withOpacity(0.15);

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
                  item['item'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item['date'] ?? ''}${item['note'] != null && item['note'].isNotEmpty ? ' ・ ${item['note']}' : ''}',
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
            '¥${item['amount'] ?? 0}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          // 編集ボタン
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 20, color: AppTheme.mutedForeground),
            onPressed: onEdit,
            tooltip: '編集',
            splashRadius: 20,
          ),

          // 削除ボタン
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
