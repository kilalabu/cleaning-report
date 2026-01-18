import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/ktor_api_client.dart';
import '../../data/repositories/ktor_report_repository.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/supabase_pdf_repository.dart';
import '../../data/repositories/supabase_report_repository.dart';
import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/pdf_repository.dart';
import '../../domain/repositories/report_repository.dart';

// ========================================
// 環境変数
// ========================================

/// Ktor APIを使用するかどうか
/// flutter run --dart-define=USE_KTOR_API=true で有効化
const bool useKtorApi =
    bool.fromEnvironment('USE_KTOR_API', defaultValue: false);

/// Ktor APIのベースURL
const String ktorApiUrl = String.fromEnvironment(
  'KTOR_API_URL',
  defaultValue: 'http://localhost:8080',
);

// ========================================
// Supabase
// ========================================

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ========================================
// Ktor API Client
// ========================================

final ktorApiClientProvider = Provider<KtorApiClient>((ref) {
  return KtorApiClient(baseUrl: ktorApiUrl);
});

// ========================================
// Auth Repository Provider
// ========================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});

// ========================================
// Report Repository Provider
// ========================================

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (useKtorApi) {
    // Ktor API経由
    final apiClient = ref.watch(ktorApiClientProvider);
    return KtorReportRepository(apiClient);
  } else {
    // Supabase直接接続
    final client = ref.watch(supabaseClientProvider);
    return SupabaseReportRepository(client);
  }
});

// ========================================
// PDF Repository Provider
// ========================================

final pdfRepositoryProvider = Provider<PdfRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabasePdfRepository(client);
});

// ========================================
// ユーザー情報
// ========================================

/// 現在のユーザー（認証状態）を監視するProvider
final currentUserProvider = StreamProvider<domain.User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges();
});

/// 現在のユーザーが管理者かどうか
final isAdminProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user?.isAdmin ?? false) ?? false;
});
