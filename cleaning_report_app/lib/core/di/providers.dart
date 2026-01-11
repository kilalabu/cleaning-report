import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/report_repository.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/supabase_report_repository.dart';

/// Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth Repository Provider
///
/// Phase 3 で KtorAuthRepository に差し替える場合はここを変更するだけ
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});

/// Report Repository Provider
///
/// Phase 3 で KtorReportRepository に差し替える場合はここを変更するだけ
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseReportRepository(client);
});

/// 現在のユーザー（認証状態）を監視するProvider
///
/// 認証状態が変わるたびに自動更新される
final currentUserProvider = StreamProvider<domain.User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges();
});

/// 現在のユーザーが管理者かどうか
final isAdminProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user?.isAdmin ?? false) ?? false;
});
