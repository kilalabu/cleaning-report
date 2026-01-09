import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('清掃報告'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: CleaningReportForm(),
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
    // 編集時は初期アイテムの日付を使用、そうでなければ今日の日付を使用
    final initialDate = initialItem != null
        ? initialItem!['date'] as String
        : DateTime.now().toIso8601String().substring(0, 10);

    final dateController = useState(initialDate);
    final idCounter = useState(1);

    // 編集時は初期アイテムをCleaningItemリストにマップ（単一アイテム）
    // そうでなければ通常の単一アイテム（空）で開始
    final initialList = useState<List<CleaningItem>>([]);

    useEffect(() {
      if (initialItem != null) {
        // APIレスポンス形式からCleaningItemへマップ
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
    // キー変更などで再構築される場合はuseStateの初期化で十分ですが、念のため

    final isSubmitting = useState(false);

    // 編集時は初期アイテムの変更を監視して再初期化
    // 簡単のため、このプランではWidgetが再構築されるかkeyが変更されると仮定します。

    Future<void> submit() async {
      // バリデーション
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
            // 更新モード
            await api.updateReport({'id': initialItem!['id'], ...data});
          } else {
            // 作成モード
            await api.saveReport(data);
          }
        }

        isSubmitting.value = false;

        // 履歴を更新
        final newMonth = dateController.value.substring(0, 7);
        ref.invalidate(historyProvider(newMonth));

        // 編集モードかつ月が変わった場合、元の月の履歴も更新する
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
            // フォームをリセット
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

    // 作成モードのみ追加/削除を許可するためのヘルパー
    final isEditing = initialItem != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date picker
        Text('日付', style: Theme.of(context).textTheme.labelLarge),
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
              dateController.value = picked.toIso8601String().substring(0, 10);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 12),
                Text(dateController.value),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Dynamic items
        ...items.value.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return CleaningItemCard(
            key: ValueKey(item.id),
            item: item,
            showRemove: !isEditing && items.value.length > 1, // 削除ロジックの開始/終了
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
          );
        }),

        const SizedBox(height: 16),

        // Add button (only for create mode)
        if (!isEditing)
          OutlinedButton.icon(
            onPressed: () {
              final newItem = CleaningItem(id: idCounter.value, type: 'extra');
              idCounter.value++;
              items.value = [...items.value, newItem];
            },
            icon: const Icon(Icons.add),
            label: const Text('業務を追加'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

        const SizedBox(height: 32),

        // Submit
        ElevatedButton(
          onPressed: isSubmitting.value ? null : submit,
          child: isSubmitting.value
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? '更新する' : '報告する'),
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

class CleaningItemCard extends StatelessWidget {
  final CleaningItem item;
  final bool showRemove;
  final ValueChanged<CleaningItem> onChanged;
  final VoidCallback onRemove;

  const CleaningItemCard({
    super.key,
    required this.item,
    required this.showRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('業務内容', style: Theme.of(context).textTheme.titleSmall),
                if (showRemove)
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red.shade400),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Type dropdown
            DropdownButtonFormField<String>(
              value: item.type,
              decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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

            // Duration (only for non-regular)
            if (item.type != 'regular') ...[
              const SizedBox(height: 12),
              Text('作業時間', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: item.duration,
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
            ],

            if (item.type != 'regular') ...[
              const SizedBox(height: 12),
              Text(
                '備考',
                style: Theme.of(context).textTheme.labelMedium,
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
