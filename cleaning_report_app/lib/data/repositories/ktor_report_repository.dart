import '../../domain/entities/cleaning_report_type.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/ktor_api_client.dart';

/// Ktor API実装のReportRepository
class KtorReportRepository implements ReportRepository {
  final KtorApiClient _apiClient;

  KtorReportRepository(this._apiClient);

  @override
  Future<List<Report>> getReports({required String month}) async {
    final response = await _apiClient.get(
      '/api/v1/reports',
      queryParams: {'month': month},
    );

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => _fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<Report> createReport(Report report) async {
    final response = await _apiClient.post(
      '/api/v1/reports',
      body: _toJson(report),
    );

    return _fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Report> updateReport(Report report) async {
    final response = await _apiClient.put(
      '/api/v1/reports/${report.id}',
      body: _toJson(report),
    );

    return _fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteReport(String id) async {
    await _apiClient.delete('/api/v1/reports/$id');
  }

  /// JSON → Report変換
  Report _fromJson(Map<String, dynamic> json) {
    final type = ReportTypeExtension.fromString(json['type'] as String);
    final itemStr = json['item'] as String;

    CleaningReportType? cleaningType;
    String? expenseItem;

    if (type == ReportType.work) {
      cleaningType =
          CleaningReportType.fromLabel(itemStr) ?? CleaningReportType.regular;
    } else {
      expenseItem = itemStr;
    }

    return Report(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      type: type,
      cleaningType: cleaningType,
      expenseItem: expenseItem,
      unitPrice: json['unit_price'] as int?,
      duration: json['duration'] as int?,
      amount: json['amount'] as int,
      note: json['note'] as String?,
      month: json['month'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Report → Request JSON変換
  Map<String, dynamic> _toJson(Report report) {
    String itemStr;
    if (report.type == ReportType.work) {
      itemStr = report.cleaningType?.displayName ?? '通常清掃';
    } else {
      itemStr = report.expenseItem ?? '';
    }

    return {
      'date': report.date.toIso8601String().split('T')[0], // "yyyy-MM-dd"
      'type': report.type.value,
      'item': itemStr,
      'unit_price': report.unitPrice,
      'duration': report.duration,
      'amount': report.amount,
      'note': report.note,
      'month': report.month,
    };
  }
}
