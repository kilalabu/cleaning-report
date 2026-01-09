import 'cleaning_item.dart';

class ReportCalculator {
  static Map<String, dynamic> calculateWorkItem(CleaningItem item) {
    int amount;
    int unitPrice;
    String itemName;

    switch (item.type) {
      case 'regular':
        amount = 1100;
        unitPrice = 1100;
        itemName = '通常清掃';
        break;
      case 'extra':
        unitPrice = 1800;
        amount = (unitPrice * item.duration / 60).floor();
        itemName = '追加業務';
        break;
      case 'emergency':
        unitPrice = 2000;
        amount = (unitPrice * item.duration / 60).floor();
        itemName = '緊急対応';
        break;
      default:
        // Default fallback, though should ideally be handled
        amount = 1100;
        unitPrice = 1100;
        itemName = '通常清掃';
    }

    return {
      'type': 'work',
      'item': itemName,
      'unitPrice': unitPrice,
      'duration': item.duration,
      'amount': amount,
      'note': item.note ?? '',
    };
  }
}
