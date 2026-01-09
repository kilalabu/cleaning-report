import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../../core/utils/dialog_utils.dart';

class ExpenseReportScreen extends StatelessWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('立替費用報告'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: ExpenseReportForm(),
          ),
        ),
      ),
    );
  }
}

class ExpenseReportForm extends HookConsumerWidget {
  final Map<String, dynamic>? initialItem;
  final VoidCallback? onSuccess;

  const ExpenseReportForm({super.key, this.initialItem, this.onSuccess});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialDate = initialItem != null
        ? initialItem!['date'] as String
        : DateTime.now().toIso8601String().substring(0, 10);

    final dateController = useState(initialDate);
    final itemController = useTextEditingController(
        text: initialItem != null ? initialItem!['item'] : '');
    final amountController = useTextEditingController(
        text: initialItem != null ? initialItem!['amount'].toString() : '');
    final noteController = useTextEditingController(
        text: initialItem != null ? initialItem!['note'] : '');
    final isSubmitting = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;

      isSubmitting.value = true;
      final api = ref.read(apiClientProvider);

      try {
        final data = {
          'date': dateController.value,
          'type': 'expense',
          'item': itemController.text,
          'unitPrice': 0,
          'duration': 0,
          'amount': int.parse(amountController.text),
          'note': noteController.text,
        };

        if (initialItem != null) {
          await api.updateReport({'id': initialItem!['id'], ...data});
        } else {
          await api.saveReport(data);
        }

        isSubmitting.value = false;

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
            await showSuccessDialog(context, '報告を送信しました');
            // リセット
            itemController.clear();
            amountController.clear();
            noteController.clear();
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

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date
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
                dateController.value =
                    picked.toIso8601String().substring(0, 10);
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

          TextFormField(
            controller: itemController,
            decoration: const InputDecoration(
              labelText: '品目名',
              hintText: '例: 洗剤、スポンジなど',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.isEmpty ? '必須です' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: amountController,
            decoration: const InputDecoration(
              labelText: '金額 (税込)',
              suffixText: '円',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return '必須です';
              if (int.tryParse(v) == null) return '数値を入力してください';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: '備考',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            maxLength: 200,
          ),
          const SizedBox(height: 32),

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
      ),
    );
  }
}
