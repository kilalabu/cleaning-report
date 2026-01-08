import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../history/providers/history_provider.dart';

class ExpenseReportScreen extends HookConsumerWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateController = useState(DateTime.now().toIso8601String().substring(0, 10));
    final itemController = useTextEditingController();
    final amountController = useTextEditingController();
    final noteController = useTextEditingController();
    final isSubmitting = useState(false);

    Future<void> submit() async {
      if (itemController.text.isEmpty || amountController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('品目名と金額を入力してください')),
        );
        return;
      }

      final amount = int.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有効な金額を入力してください')),
        );
        return;
      }

      isSubmitting.value = true;

      final api = ref.read(apiClientProvider);
      await api.saveReport({
        'date': dateController.value,
        'type': 'expense',
        'item': itemController.text,
        'unitPrice': 0,
        'duration': 0,
        'amount': amount,
        'note': noteController.text,
      });

      isSubmitting.value = false;
      
      final month = dateController.value.substring(0, 7);
      ref.invalidate(historyProvider(month));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('経費報告を送信しました')),
        );
        // Reset form
        itemController.clear();
        amountController.clear();
        noteController.clear();
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('立替費用報告'),
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
                Text('品目名', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: itemController,
                  decoration: const InputDecoration(hintText: '例: ゴミ袋、洗剤'),
                ),

                const SizedBox(height: 24),
                Text('金額 (税込)', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '例: 1000'),
                ),

                const SizedBox(height: 24),
                Text('備考 (任意)', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLength: 200,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'メモを入力'),
                ),

                const SizedBox(height: 32),

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
