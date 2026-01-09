import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../../core/utils/dialog_utils.dart';
import '../domain/cleaning_item.dart';
import '../domain/report_calculator.dart';

class CleaningReportScreen extends StatelessWidget {
  const CleaningReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('清掃報告'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const CleaningReportForm(),
          ),
        ),
      ),
    );
  }
}

class CleaningReportForm extends HookConsumerWidget {
  final Map<String, dynamic>? initialItem;
  final VoidCallback? onSuccess;

  const CleaningReportForm({super.key, this.initialItem, this.onSuccess});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialDate = initialItem != null
        ? initialItem!['date'] as String
        : DateTime.now().toIso8601String().substring(0, 10);

    final dateController = useState(initialDate);
    final idCounter = useState(1);

    final initialList = useState<List<CleaningItem>>([]);

    useEffect(() {
      if (initialItem != null) {
        final item = CleaningItem(
          id: 0,
          type: _mapItemNameToType(initialItem!['item']),
          duration: initialItem!['duration'] as int? ?? 15,
          note: initialItem!['note'] as String?,
        );
        initialList.value = [item];
      } else {
        initialList.value = [CleaningItem(id: 0)];
      }
      return null;
    }, []);

    final items = useState<List<CleaningItem>>(initialList.value);
    final isSubmitting = useState(false);

    Future<void> submit() async {
      for (int i = 0; i < items.value.length; i++) {
        final item = items.value[i];
        if (item.type != 'regular' &&
            (item.note == null || item.note!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${i + 1}番目の業務: 備考を入力してください')),
          );
          return;
        }
      }

      isSubmitting.value = true;
      final api = ref.read(apiClientProvider);

      try {
        for (final item in items.value) {
          final calculatedData = ReportCalculator.calculateWorkItem(item);

          final data = {
            'date': dateController.value,
            ...calculatedData,
          };

          if (initialItem != null) {
            await api.updateReport({'id': initialItem!['id'], ...data});
          } else {
            await api.saveReport(data);
          }
        }

        isSubmitting.value = false;

        final newMonth = dateController.value.substring(0, 7);
        ref.invalidate(historyProvider(newMonth));

        if (initialItem != null) {
          final oldDate = initialItem!['date'] as String;
          final oldMonth = oldDate.substring(0, 7);
          if (oldMonth != newMonth) {
            ref.invalidate(historyProvider(oldMonth));
          }
        }

        if (context.mounted) {
          if (initialItem != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('更新しました')));
            if (onSuccess != null) onSuccess!();
          } else {
            await showSuccessDialog(context, '報告を送信しました\nお疲れ様でした');
            items.value = [CleaningItem(id: idCounter.value)];
            idCounter.value++;
          }
        }
      } catch (e) {
        isSubmitting.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('エラー: $e')));
        }
      }
    }

    final isEditing = initialItem != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        // 日付カード
        Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '日付',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final initial =
                      DateTime.tryParse(dateController.value) ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    dateController.value =
                        picked.toIso8601String().substring(0, 10);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: AppTheme.inputDecoration,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 20, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        dateController.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 業務アイテム
        ...items.value.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CleaningItemCard(
              key: ValueKey(item.id),
              item: item,
              showRemove: !isEditing && items.value.length > 1,
              onChanged: (updated) {
                final newList = List<CleaningItem>.from(items.value);
                newList[index] = updated;
                items.value = newList;
              },
              onRemove: () {
                if (isEditing) return;
                final newList = List<CleaningItem>.from(items.value);
                newList.removeAt(index);
                items.value = newList;
              },
            ),
          );
        }),

        // 業務追加ボタン（作成モードのみ）
        if (!isEditing) ...[
          InkWell(
            onTap: () {
              final newItem = CleaningItem(id: idCounter.value, type: 'extra');
              idCounter.value++;
              items.value = [...items.value, newItem];
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppTheme.primary, size: 20),
                  SizedBox(width: 6),
                  Text(
                    '業務を追加',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // 送信ボタン
        Container(
          decoration: AppTheme.gradientButtonDecoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSubmitting.value ? null : submit,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: isSubmitting.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? '更新する' : '報告する',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _mapItemNameToType(String? itemName) {
    if (itemName == '通常清掃') return 'regular';
    if (itemName == '追加業務') return 'extra';
    if (itemName == '緊急対応') return 'emergency';
    return 'regular';
  }
}

class _CleaningItemCard extends StatelessWidget {
  final CleaningItem item;
  final bool showRemove;
  final ValueChanged<CleaningItem> onChanged;
  final VoidCallback onRemove;

  const _CleaningItemCard({
    super.key,
    required this.item,
    required this.showRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '業務内容',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                if (showRemove)
                  Material(
                    color: AppTheme.destructive.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.delete_outline,
                          color: AppTheme.destructive,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // タイプ選択
            Container(
              decoration: AppTheme.inputDecoration,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: item.type,
                  isExpanded: true,
                  icon:
                      Icon(Icons.expand_more, color: AppTheme.mutedForeground),
                  items: const [
                    DropdownMenuItem(
                        value: 'regular', child: Text('通常清掃 (1,100円)')),
                    DropdownMenuItem(
                        value: 'extra', child: Text('追加業務 (時給1,800円)')),
                    DropdownMenuItem(
                        value: 'emergency', child: Text('緊急対応 (時給2,000円)')),
                  ],
                  onChanged: (v) => onChanged(item.copyWith(type: v)),
                ),
              ),
            ),

            // 作業時間（通常清掃以外）
            if (item.type != 'regular') ...[
              const SizedBox(height: 12),
              Text(
                '作業時間',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: AppTheme.inputDecoration,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: item.duration,
                    isExpanded: true,
                    icon: Icon(Icons.expand_more,
                        color: AppTheme.mutedForeground),
                    items: List.generate(12, (i) {
                      final min = (i + 1) * 15;
                      final hours = min ~/ 60;
                      final mins = min % 60;
                      final label = hours > 0
                          ? '$hours時間${mins > 0 ? '$mins分' : ''}'
                          : '$mins分';
                      return DropdownMenuItem(value: min, child: Text(label));
                    }),
                    onChanged: (v) => onChanged(item.copyWith(duration: v)),
                  ),
                ),
              ),
            ],

            // 備考（通常清掃以外）
            if (item.type != 'regular') ...[
              const SizedBox(height: 12),
              Text(
                '備考',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: item.note,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(hintText: '内容を入力'),
                onChanged: (v) => onChanged(item.copyWith(note: v)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
