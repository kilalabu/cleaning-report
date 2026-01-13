import '../../../../domain/entities/cleaning_report_type.dart';
import 'cleaning_item.dart';

class ReportCalculator {
  static Map<String, dynamic> calculateWorkItem(CleaningItem item) {
    int amount;
    int unitPrice;

    // CleaningReportType自体はdisplayNameを持っているので、
    // ここで文字列に変換して返す必要はあるが、UI側での表示にはEnumを使うのが望ましい。
    // ただし、このメソッドはReport生成のためのデータを計算して返すものなので、
    // Report.createに合わせてパラメータを返す必要がある。
    // Report.createは CleaningReportType を受け取るようになったので、
    // ここで String item を返すのではなく CleaningReportType を返すように変更する。

    switch (item.type) {
      case CleaningReportType.regular:
        amount = 1100;
        unitPrice = 1100;
        break;
      case CleaningReportType.extra:
        unitPrice = 1800;
        amount = (unitPrice * item.duration / 60).floor();
        break;
      case CleaningReportType.emergency:
        unitPrice = 2000;
        amount = (unitPrice * item.duration / 60).floor();
        break;
    }

    return {
      'type': 'work',
      'cleaningType': item.type, // Enumをそのまま渡す
      'unitPrice': unitPrice,
      'duration': item.duration,
      'amount': amount,
      'note': item.note,
    };
  }
}
