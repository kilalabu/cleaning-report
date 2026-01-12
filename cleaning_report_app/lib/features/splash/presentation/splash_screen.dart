import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// スプラッシュ画面
///
/// Supabaseのセッション復元を待機し、認証状態に応じて適切な画面へ遷移する
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    // onAuthStateChange の最初のイベントを待機
    // これにより、セッション復元が完了したことを確認できる
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        _authSubscription?.cancel();

        if (!mounted) return;

        final session = data.session;
        if (session != null) {
          // セッションあり → メイン画面へ
          context.go('/report/cleaning');
        } else {
          // セッションなし → ログイン画面へ
          context.go('/login');
        }
      },
      onError: (error) {
        // エラー時はログイン画面へ
        if (mounted) {
          context.go('/login');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アプリロゴ
            Icon(
              Icons.cleaning_services,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'かんたん清掃報告',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
