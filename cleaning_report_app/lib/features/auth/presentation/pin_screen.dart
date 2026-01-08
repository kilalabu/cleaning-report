import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          _verifyPin(context, ref, pinController.value, isLoading, errorMessage, pinController);
        }
      }
    }

    void onDelete() {
      if (pinController.value.isNotEmpty) {
        pinController.value = pinController.value.substring(0, pinController.value.length - 1);
        errorMessage.value = null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Cleaning Report',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'かんたん清掃報告システム',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 48),
                  
                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < pinController.value.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade200,
                          border: Border.all(
                            color: isFilled
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade400,
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  if (errorMessage.value != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      errorMessage.value!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  
                  const SizedBox(height: 48),
                  
                  // Keypad
                  if (isLoading.value)
                    const CircularProgressIndicator()
                  else
                    _buildKeypad(onKeyTap, onDelete),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(void Function(String) onKeyTap, VoidCallback onDelete) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['1', '2', '3'].map((k) => _keyButton(k, onKeyTap)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['4', '5', '6'].map((k) => _keyButton(k, onKeyTap)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['7', '8', '9'].map((k) => _keyButton(k, onKeyTap)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 88), // 他のボタンと同じ幅 (64 + 12*2)
            _keyButton('0', onKeyTap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.backspace_outlined, color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyButton(String key, void Function(String) onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.grey.shade100,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => onTap(key),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
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
