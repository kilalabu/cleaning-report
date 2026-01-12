import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../view_model/expense_report_view_model.dart';

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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

class ExpenseReportForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialItem;
  final VoidCallback? onSuccess;

  const ExpenseReportForm({super.key, this.initialItem, this.onSuccess});

  @override
  ConsumerState<ExpenseReportForm> createState() => _ExpenseReportFormState();
}

class _ExpenseReportFormState extends ConsumerState<ExpenseReportForm> {
  late TextEditingController _itemController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _itemController =
        TextEditingController(text: widget.initialItem?['item'] ?? '');
    _amountController = TextEditingController(
        text: widget.initialItem?['amount']?.toString() ?? '');
    _noteController =
        TextEditingController(text: widget.initialItem?['note'] ?? '');

    _itemController.addListener(_onItemChanged);
    _amountController.addListener(_onAmountChanged);
    _noteController.addListener(_onNoteChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(expenseReportViewModelProvider.notifier)
          .initialize(initialItem: widget.initialItem);
    });
  }

  @override
  void dispose() {
    _itemController.removeListener(_onItemChanged);
    _amountController.removeListener(_onAmountChanged);
    _noteController.removeListener(_onNoteChanged);
    _itemController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onItemChanged() {
    ref
        .read(expenseReportViewModelProvider.notifier)
        .updateItem(_itemController.text);
  }

  void _onAmountChanged() {
    ref
        .read(expenseReportViewModelProvider.notifier)
        .updateAmount(_amountController.text);
  }

  void _onNoteChanged() {
    ref
        .read(expenseReportViewModelProvider.notifier)
        .updateNote(_noteController.text);
  }

  void _resetForm() {
    _itemController.clear();
    _amountController.clear();
    _noteController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expenseReportViewModelProvider);
    final viewModel = ref.read(expenseReportViewModelProvider.notifier);
    final isEditing = widget.initialItem != null;

    return Form(
      key: _formKey,
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
                    final initial =
                        DateTime.tryParse(state.date) ?? DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('ja'),
                    );
                    if (picked != null) {
                      viewModel.updateDate(picked);
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
                          state.date,
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
                  controller: _itemController,
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
                  controller: _amountController,
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
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'メモすることがあれば入力',
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
                onTap: state.isSubmitting
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          viewModel.submit(
                            context,
                            initialItem: widget.initialItem,
                            onSuccess: widget.onSuccess,
                            onReset: _resetForm,
                          );
                        }
                      },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: state.isSubmitting
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
