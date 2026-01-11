import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/auth_repository.dart';

/// Supabase を使った AuthRepository の実装
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Future<domain.User?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;

    return await _fetchUserProfile(authUser.id, authUser.email ?? '');
  }

  @override
  Future<domain.User> signIn(
      {required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final authUser = response.user;
    if (authUser == null) {
      throw Exception('ログインに失敗しました');
    }

    final user = await _fetchUserProfile(authUser.id, authUser.email ?? '');
    if (user == null) {
      throw Exception('ユーザープロフィールが見つかりません');
    }

    return user;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Stream<domain.User?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final authUser = event.session?.user;
      if (authUser == null) return null;

      return await _fetchUserProfile(authUser.id, authUser.email ?? '');
    });
  }

  /// profilesテーブルからユーザー情報を取得
  Future<domain.User?> _fetchUserProfile(String userId, String email) async {
    try {
      final response =
          await _client.from('profiles').select().eq('id', userId).single();

      return domain.User(
        id: response['id'] as String,
        email: email,
        displayName: response['display_name'] as String,
        role: domain.UserRoleExtension.fromString(response['role'] as String),
      );
    } catch (e) {
      // プロフィールが見つからない場合
      return null;
    }
  }
}
