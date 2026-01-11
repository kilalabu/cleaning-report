import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';

/// Supabase を使った ReportRepository の実装
///
/// RLSにより権限制御は自動で適用される:
/// - staff: 自分のレポートのみ
/// - admin: 全レポート
class SupabaseReportRepository implements ReportRepository {
  final SupabaseClient _client;

  SupabaseReportRepository(this._client);

  @override
  Future<List<Report>> getReports({required String month}) async {
    final response = await _client
        .from('reports')
        .select()
        .eq('month', month)
        .order('date', ascending: false);

    return (response as List).map((json) => _fromJson(json)).toList();
  }

  @override
  Future<Report> createReport(Report report) async {
    final data = _toJson(report);
    // idとcreated_atはサーバーで生成されるので除外
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');

    final response =
        await _client.from('reports').insert(data).select().single();

    return _fromJson(response);
  }

  @override
  Future<Report> updateReport(Report report) async {
    final data = _toJson(report);
    // id, created_atは更新しない
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');

    final response = await _client
        .from('reports')
        .update(data)
        .eq('id', report.id)
        .select()
        .single();

    return _fromJson(response);
  }

  @override
  Future<void> deleteReport(String id) async {
    await _client.from('reports').delete().eq('id', id);
  }

  /// JSONからReportエンティティに変換
  Report _fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      type: ReportTypeExtension.fromString(json['type'] as String),
      item: json['item'] as String,
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

  /// ReportエンティティからJSONに変換
  Map<String, dynamic> _toJson(Report report) {
    return {
      'id': report.id,
      'user_id': report.userId,
      'date': report.date.toIso8601String().split('T')[0], // DATE型用
      'type': report.type.value,
      'item': report.item,
      'unit_price': report.unitPrice,
      'duration': report.duration,
      'amount': report.amount,
      'note': report.note,
      'month': report.month,
      'created_at': report.createdAt.toIso8601String(),
      'updated_at': report.updatedAt?.toIso8601String(),
    };
  }
}
