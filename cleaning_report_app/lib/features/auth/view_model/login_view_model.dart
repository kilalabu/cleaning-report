import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/di/providers.dart';

import '../state/login_state.dart';
export '../state/login_state.dart';

// LoginState class moved to login_state.dart

class LoginViewModel extends AutoDisposeNotifier<LoginState> {
  @override
  LoginState build() {
    return LoginState();
  }

  Future<void> login({
    required String email,
    required String password,
    required VoidCallback onSuccess,
  }) async {
    // バリデーション
    if (email.isEmpty || password.isEmpty) {
      state = LoginState(errorMessage: 'メールアドレスとパスワードを入力してください');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    // エラーメッセージをクリアしたいが、copyWithの実装が簡易なため注意。
    // errorMessage引数を `String?` として受け取り、省略されたら `this.errorMessage` を使う実装になっていると、null をセットできない。
    // 上記の copyWith では `errorMessage: errorMessage` としているので、引数に null を渡せば null になるが、引数省略時が困る。
    // 引数省略時は `this.errorMessage` を使いたいが、引数に `errorMessage` が渡されたかどうかを区別できない（null許容型なので）。
    // 正しくは `Object? errorMessage = const Object()` のような番兵を使うか、毎回全フィールド指定するか。
    // ここでは単純に新しい State を生成する。

    state = LoginState(isLoading: true, errorMessage: null);

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signIn(email: email, password: password);

      // 成功時
      state = LoginState(isLoading: false, errorMessage: null);
      onSuccess();
    } catch (e) {
      state = LoginState(
        isLoading: false,
        errorMessage: 'ログインに失敗しました。メールアドレスとパスワードを確認してください。',
      );
    }
  }
}

final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
        LoginViewModel.new);
