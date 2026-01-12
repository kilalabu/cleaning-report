import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/di/providers.dart';

/// Email/Password ログイン画面
class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final obscurePassword = useState(true);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withOpacity(0.1),
              AppTheme.accent.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ロゴ・タイトル
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cleaning_services,
                      size: 64,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'かんたん清掃報告',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ログインしてください',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 48),

                  // ログインフォーム
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // メールアドレス
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'メールアドレス',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // パスワード
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword.value,
                          decoration: InputDecoration(
                            labelText: 'パスワード',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword.value
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                obscurePassword.value = !obscurePassword.value;
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _login(
                            context,
                            ref,
                            emailController.text,
                            passwordController.text,
                            isLoading,
                            errorMessage,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // エラーメッセージ
                        if (errorMessage.value != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage.value!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ログインボタン
                        ElevatedButton(
                          onPressed: isLoading.value
                              ? null
                              : () => _login(
                                    context,
                                    ref,
                                    emailController.text,
                                    passwordController.text,
                                    isLoading,
                                    errorMessage,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading.value
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'ログイン',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login(
    BuildContext context,
    WidgetRef ref,
    String email,
    String password,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> errorMessage,
  ) async {
    // バリデーション
    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'メールアドレスとパスワードを入力してください';
      return;
    }

    errorMessage.value = null;
    isLoading.value = true;

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signIn(email: email, password: password);

      if (context.mounted) {
        context.go('/report/cleaning');
      }
    } catch (e) {
      errorMessage.value = 'ログインに失敗しました。メールアドレスとパスワードを確認してください。';
    } finally {
      isLoading.value = false;
    }
  }
}
