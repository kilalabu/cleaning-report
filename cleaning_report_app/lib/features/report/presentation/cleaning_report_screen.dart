import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../history/providers/history_provider.dart';

class CleaningReportScreen extends HookConsumerWidget {
  const CleaningReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateController = useState(DateTime.now().toIso8601String().substring(0, 10));
    final idCounter = useState(1);
    final items = useState<List<CleaningItem>>([CleaningItem(id: 0)]);
    final isSubmitting = useState(false);

    Future<void> submit() async {
      // Validation
      for (int i = 0; i < items.value.length; i++) {
        final item = items.value[i];
        if (item.type != 'regular' && (item.note == null || item.note!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${i + 1}番目の業務: 備考を入力してください')),
          );
          return;
        }
      }

      isSubmitting.value = true;

      final api = ref.read(apiClientProvider);

      for (final item in items.value) {
        int amount;
        int unitPrice;
        String itemName;

        switch (item.type) {
          case 'regular':
            amount = 1100;
            unitPrice = 1100;
            itemName = '通常清掃';
            break;
          case 'extra':
            unitPrice = 1800;
            amount = (unitPrice * item.duration / 60).floor();
            itemName = '追加業務';
            break;
          case 'emergency':
            unitPrice = 2000;
            amount = (unitPrice * item.duration / 60).floor();
            itemName = '緊急対応';
            break;
          default:
            continue;
        }

        await api.saveReport({
          'date': dateController.value,
          'type': 'work',
          'item': itemName,
          'unitPrice': unitPrice,
          'duration': item.duration,
          'amount': amount,
          'note': item.note ?? '',
        });
      }

      isSubmitting.value = false;
      
      // Refresh history for the specific month
      final month = dateController.value.substring(0, 7);
      ref.invalidate(historyProvider(month));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告を送信しました')),
        );
        // Reset form
        items.value = [CleaningItem(id: idCounter.value)];
        idCounter.value++;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('清掃報告'),
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
                // Date picker
                Text('日付', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.parse(dateController.value),
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
                    showRemove: items.value.length > 1,
                    onChanged: (updated) {
                      final newList = List<CleaningItem>.from(items.value);
                      newList[index] = updated;
                      items.value = newList;
                    },
                    onRemove: () {
                      final newList = List<CleaningItem>.from(items.value);
                      newList.removeAt(index);
                      items.value = newList;
                    },
                  );
                }),

                const SizedBox(height: 16),

                // Add button
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('報告する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CleaningItem {
  final int id;
  String type;
  int duration;
  String? note;

  CleaningItem({required this.id, this.type = 'regular', this.duration = 15, this.note});

  CleaningItem copyWith({String? type, int? duration, String? note}) {
    return CleaningItem(
      id: this.id,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      note: note ?? this.note,
    );
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
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: const [
                DropdownMenuItem(value: 'regular', child: Text('通常清掃 (1,100円)')),
                DropdownMenuItem(value: 'extra', child: Text('追加業務 (時給1,800円)')),
                DropdownMenuItem(value: 'emergency', child: Text('緊急対応 (時給2,000円)')),
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
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: List.generate(12, (i) {
                  final min = (i + 1) * 15;
                  final hours = min ~/ 60;
                  final mins = min % 60;
                  final label = hours > 0 ? '$hours時間${mins > 0 ? '$mins分' : ''}' : '$mins分';
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
