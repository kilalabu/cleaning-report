/// Report Entity
///
/// 清掃報告・経費報告のデータモデル。
/// Data Layer の実装詳細に依存しない純粋なDartクラス。

class Report {
  final String id;
  final String userId;
  final DateTime date;
  final ReportType type;
  final String item;
  final int? unitPrice;
  final int? duration; // 分単位
  final int amount;
  final String? note;
  final String month; // 'yyyy-MM' 形式
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Report({
    required this.id,
    required this.userId,
    required this.date,
    required this.type,
    required this.item,
    this.unitPrice,
    this.duration,
    required this.amount,
    this.note,
    required this.month,
    required this.createdAt,
    this.updatedAt,
  });

  /// 新規レポート作成用ファクトリ（IDとタイムスタンプは後で付与）
  factory Report.create({
    required String userId,
    required DateTime date,
    required ReportType type,
    required String item,
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
      item: item,
      unitPrice: unitPrice,
      duration: duration,
      amount: amount,
      note: note,
      month: month,
      createdAt: DateTime.now(),
    );
  }

  /// コピーして一部フィールドを変更
  Report copyWith({
    String? id,
    String? userId,
    DateTime? date,
    ReportType? type,
    String? item,
    int? unitPrice,
    int? duration,
    int? amount,
    String? note,
    String? month,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Report(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      type: type ?? this.type,
      item: item ?? this.item,
      unitPrice: unitPrice ?? this.unitPrice,
      duration: duration ?? this.duration,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      month: month ?? this.month,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Report(id: $id, date: $date, type: $type, item: $item, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Report && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
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
