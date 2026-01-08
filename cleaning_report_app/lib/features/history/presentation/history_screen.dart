import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;
import 'dart:convert';

import '../providers/history_provider.dart';
import '../../auth/providers/auth_provider.dart';

class HistoryScreen extends HookConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = useState(_getCurrentMonth());
    final isGeneratingPdf = useState(false);
    final historyAsync = ref.watch(historyProvider(selectedMonth.value));
    final totalAmount = ref.watch(totalAmountProvider(selectedMonth.value));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('履歴・編集'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total Summary
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_getMonthLabel(selectedMonth.value)}の請求合計 (税込)',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${_formatNumber(totalAmount)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // PDF Generation Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '請求書発行',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedMonth.value,
                                    isExpanded: true,
                                    items: _generateMonthOptions().map((m) {
                                      return DropdownMenuItem(value: m, child: Text(m));
                                    }).toList(),
                                    onChanged: (v) => selectedMonth.value = v ?? selectedMonth.value,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: isGeneratingPdf.value
                                  ? null
                                  : () => _generatePdf(context, ref, selectedMonth.value, isGeneratingPdf),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isGeneratingPdf.value
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.download),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // History List
                historyAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('${_getMonthLabel(selectedMonth.value)}の履歴はありません', style: const TextStyle(color: Colors.grey)),
                        ),
                      );
                    }
                    return Column(
                      children: items.map((item) => _HistoryItemTile(
                        item: item,
                        onDelete: () => _deleteItem(context, ref, item['id'] as String, selectedMonth.value),
                      )).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('エラー: $e', style: const TextStyle(color: Colors.red)),
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
    return n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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

      // Trigger download
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

  Future<void> _deleteItem(BuildContext context, WidgetRef ref, String id, String month) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このデータを削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = ref.read(apiClientProvider);
      await api.deleteData(id);
      ref.invalidate(historyProvider(month));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
      }
    }
  }
}

class _HistoryItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  const _HistoryItemTile({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isWork = item['type'] == 'work';
    final icon = isWork ? Icons.cleaning_services : Icons.receipt_long;
    final color = isWork ? Theme.of(context).colorScheme.primary : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['item'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '${item['date'] ?? ''}${item['note'] != null && item['note'].isNotEmpty ? ' ・ ${item['note']}' : ''}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '¥${item['amount'] ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
