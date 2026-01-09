import 'package:flutter/material.dart';

/// アプリケーションのカラーテーマ定義
class AppTheme {
  // ==========================================================================
  // カラーパレット（サンプルUIベース - ライトモードのみ）
  // ==========================================================================

  /// Primary: Indigo系 (oklch 0.55 0.2 260)
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  /// Accent: Orange系 (oklch 0.65 0.2 30)
  static const Color accent = Color(0xFFF97316);
  static const Color accentLight = Color(0xFFFB923C);

  /// 背景色
  static const Color background = Color(0xFFF8FAFC); // Slate-50
  static const Color surface = Color(0xFFFFFFFF); // White

  /// カード・入力フィールド
  static const Color card = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFF1F5F9); // Slate-100
  static const Color mutedForeground = Color(0xFF64748B); // Slate-500

  /// ボーダー
  static const Color border = Color(0xFFE2E8F0); // Slate-200
  static const Color borderLight = Color(0xFFF1F5F9); // Slate-100

  /// テキスト
  static const Color foreground = Color(0xFF1E293B); // Slate-800
  static const Color foregroundMuted = Color(0xFF64748B); // Slate-500

  /// 危険・エラー
  static const Color destructive = Color(0xFFEF4444); // Red-500
  static const Color destructiveLight = Color(0xFFFEE2E2); // Red-100

  /// 成功
  static const Color success = Color(0xFF22C55E); // Green-500
  static const Color successLight = Color(0xFFDCFCE7); // Green-100

  // ==========================================================================
  // テーマデータ
  // ==========================================================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // カラースキーム
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: destructive,
      ),

      // 背景色
      scaffoldBackgroundColor: background,

      // テキストテーマ（システムフォントをベースにし、フォント読み込み中の文字化けを防止）
      fontFamily: 'Hiragino Sans',
      fontFamilyFallback: const [
        'Hiragino Kaku Gothic ProN',
        'Meiryo',
        'sans-serif'
      ],
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        bodyLarge: TextStyle(color: foreground),
        bodyMedium: TextStyle(color: foreground),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w500,
          color: mutedForeground,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        iconTheme: const IconThemeData(color: foreground),
      ),

      // Card
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border.withOpacity(0.5)),
        ),
        margin: EdgeInsets.zero,
      ),

      // 入力フィールド
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted.withOpacity(0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.5), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: destructive),
        ),
        labelStyle: const TextStyle(color: mutedForeground),
        hintStyle: TextStyle(color: mutedForeground.withOpacity(0.7)),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primary.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: primary.withOpacity(0.3), width: 2),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card.withOpacity(0.95),
        elevation: 0,
        height: 70,
        indicatorColor: primary.withOpacity(0.15),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: mutedForeground,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: primary, size: 24);
          }
          return IconThemeData(color: mutedForeground, size: 24);
        }),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: border.withOpacity(0.5),
        thickness: 1,
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // DropdownMenu
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: muted.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // カスタムデコレーション
  // ==========================================================================

  /// 標準カードデコレーション
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  /// グラデーションボタンデコレーション
  static BoxDecoration get gradientButtonDecoration => BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, primaryLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// サマリーカード（グラデーション）デコレーション
  static BoxDecoration get summaryCardDecoration => BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// 入力フィールドデコレーション
  static BoxDecoration get inputDecoration => BoxDecoration(
        color: muted.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withOpacity(0.5)),
      );

  /// アイコンバッジデコレーション（Primary）
  static BoxDecoration get primaryIconBadge => BoxDecoration(
        color: primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      );

  /// アイコンバッジデコレーション（Accent）
  static BoxDecoration get accentIconBadge => BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      );

  /// 破線ボーダーのボタンスタイル
  static BoxDecoration dashedBorderDecoration({Color? color}) => BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (color ?? primary).withOpacity(0.3),
          width: 2,
        ),
      );
}
