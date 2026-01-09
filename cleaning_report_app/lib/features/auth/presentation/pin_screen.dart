import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class PinScreen extends HookConsumerWidget {
  const PinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinController = useState('');
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    void onKeyTap(String key) {
      if (pinController.value.length < 4) {
        pinController.value += key;
        errorMessage.value = null;

        if (pinController.value.length == 4) {
          _verifyPin(context, ref, pinController.value, isLoading, errorMessage,
              pinController);
        }
      }
    }

    void onDelete() {
      if (pinController.value.isNotEmpty) {
        pinController.value =
            pinController.value.substring(0, pinController.value.length - 1);
        errorMessage.value = null;
      }
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primary.withOpacity(0.05),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ロゴエリア
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primary, AppTheme.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cleaning Report',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.foreground,
                                letterSpacing: -0.5,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '暗証番号を入力',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mutedForeground,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // PINドット
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < pinController.value.length;
                        final hasError = errorMessage.value != null;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled
                                ? (hasError
                                    ? AppTheme.destructive
                                    : AppTheme.primary)
                                : AppTheme.border,
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: (hasError
                                              ? AppTheme.destructive
                                              : AppTheme.primary)
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),

                    // エラーメッセージ
                    SizedBox(
                      height: 40,
                      child: errorMessage.value != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                errorMessage.value!,
                                style: TextStyle(
                                  color: AppTheme.destructive,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(height: 24),

                    // テンキー
                    if (isLoading.value)
                      const CircularProgressIndicator()
                    else
                      _buildKeypad(context, onKeyTap, onDelete),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(BuildContext context, void Function(String) onKeyTap,
      VoidCallback onDelete) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['1', '2', '3']
              .map((k) => _keyButton(context, k, onKeyTap))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['4', '5', '6']
              .map((k) => _keyButton(context, k, onKeyTap))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['7', '8', '9']
              .map((k) => _keyButton(context, k, onKeyTap))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _keyButton(context, '0', onKeyTap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Material(
                  color: AppTheme.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppTheme.border.withOpacity(0.5)),
                  ),
                  child: InkWell(
                    onTap: onDelete,
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.backspace_outlined,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyButton(
      BuildContext context, String key, void Function(String) onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.border.withOpacity(0.5)),
        ),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () => onTap(key),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          splashColor: AppTheme.primary.withOpacity(0.1),
          highlightColor: AppTheme.primary.withOpacity(0.05),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPin(
    BuildContext context,
    WidgetRef ref,
    String pin,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> errorMessage,
    ValueNotifier<String> pinController,
  ) async {
    isLoading.value = true;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = await authNotifier.verifyPin(pin);

    isLoading.value = false;

    if (success && context.mounted) {
      context.go('/report/cleaning');
    } else {
      errorMessage.value = '暗証番号が違います';
      pinController.value = '';
    }
  }
}
