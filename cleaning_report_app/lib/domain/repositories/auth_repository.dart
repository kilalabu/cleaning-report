import '../entities/user.dart';

/// AuthRepository インターフェース
///
/// 認証操作を定義する抽象クラス。
/// Data Layer で SupabaseAuthRepository として実装される。
/// Phase 3 では KtorAuthRepository に差し替え可能。
abstract class AuthRepository {
  /// 現在ログイン中のユーザーを取得
  ///
  /// 未認証時は null を返す
  Future<User?> getCurrentUser();

  /// Email/Password でログイン
  ///
  /// [email] - メールアドレス
  /// [password] - パスワード
  /// 戻り値: ログインしたユーザー
  /// 認証失敗時は例外をスロー
  Future<User> signIn({required String email, required String password});

  /// ログアウト
  Future<void> signOut();

  /// 認証状態の変更を監視
  ///
  /// ログイン/ログアウト時に新しい User（または null）を emit
  Stream<User?> authStateChanges();
}
