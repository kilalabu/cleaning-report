import 'package:freezed_annotation/freezed_annotation.dart';
import 'cleaning_report_type.dart';

part 'report.freezed.dart';

@freezed
abstract class Report with _$Report {
  const factory Report({
    required String id,
    required String userId,
    required DateTime date,
    required ReportType type,
    CleaningReportType? cleaningType, // 清掃業務の場合にセット
    String? expenseItem, // 立替経費の場合にセット
    int? unitPrice,
    int? duration, // 分単位
    required int amount,
    String? note,
    required String month, // 'yyyy-MM' 形式
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Report;

  const Report._();

  /// 新規レポート作成用ファクトリ（IDとタイムスタンプは後で付与）
  factory Report.create({
    required String userId,
    required DateTime date,
    required ReportType type,
    CleaningReportType? cleaningType,
    String? expenseItem,
    int? unitPrice,
    int? duration,
    required int amount,
    String? note,
  }) {
    final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    return Report(
      id: '', // Data Layerで生成
      userId: userId,
      date: date,
      type: type,
      cleaningType: cleaningType,
      expenseItem: expenseItem,
      unitPrice: unitPrice,
      duration: duration,
      amount: amount,
      note: note,
      month: month,
      createdAt: DateTime.now(),
    );
  }
}

/// レポートの種類
enum ReportType {
  work, // 清掃業務
  expense, // 立替経費
}

extension ReportTypeExtension on ReportType {
  String get displayName {
    switch (this) {
      case ReportType.work:
        return '清掃業務';
      case ReportType.expense:
        return '立替経費';
    }
  }

  String get value {
    switch (this) {
      case ReportType.work:
        return 'work';
      case ReportType.expense:
        return 'expense';
    }
  }

  static ReportType fromString(String value) {
    switch (value) {
      case 'work':
        return ReportType.work;
      case 'expense':
        return ReportType.expense;
      default:
        throw ArgumentError('Unknown ReportType: $value');
    }
  }
}
