import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase設定
///
/// 環境変数から読み込み。ビルド時に --dart-define で指定:
/// flutter run --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
class SupabaseConfig {
  // --dart-define から読み込み
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Supabaseの初期化
  static Future<void> initialize() async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Supabase設定が見つかりません。\n'
        'flutter run --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx\n'
        'でビルドしてください。',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
