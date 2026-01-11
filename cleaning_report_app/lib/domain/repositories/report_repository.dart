import '../entities/report.dart';

/// ReportRepository インターフェース
///
/// レポートデータの永続化操作を定義する抽象クラス。
/// Data Layer で SupabaseReportRepository として実装される。
/// Phase 3 では KtorReportRepository に差し替え可能。
abstract class ReportRepository {
  /// 指定月のレポート一覧を取得
  ///
  /// [month] - 'yyyy-MM' 形式（例: '2026-01'）
  /// RLSにより、スタッフは自分のデータのみ、管理者は全データを取得
  Future<List<Report>> getReports({required String month});

  /// レポートを新規作成
  ///
  /// [report] - 作成するレポート（idは空でOK、サーバーで生成）
  /// 戻り値: 作成されたレポート（id付き）
  Future<Report> createReport(Report report);

  /// レポートを更新
  ///
  /// [report] - 更新するレポート（id必須）
  /// 戻り値: 更新後のレポート
  Future<Report> updateReport(Report report);

  /// レポートを削除
  ///
  /// [id] - 削除するレポートのID
  Future<void> deleteReport(String id);
}
