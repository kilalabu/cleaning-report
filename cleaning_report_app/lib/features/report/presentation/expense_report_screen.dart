import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../../core/utils/dialog_utils.dart';

class ExpenseReportScreen extends StatelessWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('立替費用報告'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const ExpenseReportForm(),
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
                    final initial = DateTime.tryParse(dateController.value) ??
                        DateTime.now();
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
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

          // 品目名カード
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '品目名',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: itemController,
                  decoration: const InputDecoration(
                    hintText: '例: 洗剤、ゴミ袋など',
                  ),
                  validator: (v) => v == null || v.isEmpty ? '必須です' : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 金額カード
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '金額（税込）',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: amountController,
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Text(
                        '¥',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return '必須です';
                    if (int.tryParse(v) == null) return '数値を入力してください';
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 備考カード
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '備考（任意）',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    hintText: 'メモがあれば入力',
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
              ],
            ),
          ),

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
      ),
    );
  }
}
