import 'package:flutter_test/flutter_test.dart';
import 'package:cleaning_report_app/features/report/domain/cleaning_item.dart';
import 'package:cleaning_report_app/features/report/domain/report_calculator.dart';

void main() {
  group('ReportCalculator', () {
    test('通常清掃 (Regular) の計算が正しいこと', () {
      final item = CleaningItem(id: 1, type: 'regular');
      final result = ReportCalculator.calculateWorkItem(item);

      expect(result['item'], '通常清掃');
      expect(result['unitPrice'], 1100);
      expect(result['amount'], 1100);
    });

    test('追加業務 (Extra) の計算が正しいこと - 60分', () {
      final item = CleaningItem(id: 2, type: 'extra', duration: 60);
      final result = ReportCalculator.calculateWorkItem(item);

      expect(result['item'], '追加業務');
      expect(result['unitPrice'], 1800);
      expect(result['amount'], 1800);
    });

    test('追加業務 (Extra) の計算が正しいこと - 30分', () {
      final item = CleaningItem(id: 3, type: 'extra', duration: 30);
      final result = ReportCalculator.calculateWorkItem(item);

      expect(result['item'], '追加業務');
      expect(result['unitPrice'], 1800);
      expect(result['amount'], 900); // 1800 * 30/60 = 900
    });

    test('緊急対応 (Emergency) の計算が正しいこと - 60分', () {
      final item = CleaningItem(id: 4, type: 'emergency', duration: 60);
      final result = ReportCalculator.calculateWorkItem(item);

      expect(result['item'], '緊急対応');
      expect(result['unitPrice'], 2000);
      expect(result['amount'], 2000);
    });

    test('通常清掃から追加業務へ変更された場合の計算 (Regular -> Extra)', () {
      // User changes type from regular to extra in UI
      // This creates a new CleaningItem with type='extra' and default duration (e.g. 15 or whatever user picks)
      final regularItem = CleaningItem(id: 5, type: 'regular');

      // Simulate change: copied with new type and duration
      final changedItem = regularItem.copyWith(type: 'extra', duration: 45);

      final result = ReportCalculator.calculateWorkItem(changedItem);

      expect(result['item'], '追加業務');
      expect(result['unitPrice'], 1800);
      expect(result['amount'], 1350); // 1800 * 45/60 = 1350
    });

    test('追加業務から通常清掃へ変更された場合の計算 (Extra -> Regular)', () {
      // User changes type from extra to regular
      // Duration might remain in the object state but should be ignored by calculator
      final extraItem = CleaningItem(id: 6, type: 'extra', duration: 90);

      // Simulate change: copied with new type
      final changedItem = extraItem.copyWith(type: 'regular');

      final result = ReportCalculator.calculateWorkItem(changedItem);

      expect(result['item'], '通常清掃');
      expect(result['unitPrice'], 1100);
      expect(result['amount'], 1100); // Duration 90 should be ignored
    });

    test('通常清掃から緊急対応へ変更された場合の計算 (Regular -> Emergency)', () {
      final regularItem = CleaningItem(id: 7, type: 'regular');
      final changedItem = regularItem.copyWith(type: 'emergency', duration: 45);
      final result = ReportCalculator.calculateWorkItem(changedItem);

      expect(result['item'], '緊急対応');
      expect(result['unitPrice'], 2000);
      expect(result['amount'], 1500); // 2000 * 45/60 = 1500
    });

    test('緊急対応から通常清掃へ変更された場合の計算 (Emergency -> Regular)', () {
      final emergencyItem =
          CleaningItem(id: 8, type: 'emergency', duration: 90);
      final changedItem = emergencyItem.copyWith(type: 'regular');
      final result = ReportCalculator.calculateWorkItem(changedItem);

      expect(result['item'], '通常清掃');
      expect(result['unitPrice'], 1100);
      expect(result['amount'], 1100); // Duration 90 should be ignored
    });

    test('追加業務から緊急対応へ変更された場合の計算 (Extra -> Emergency)', () {
      final extraItem = CleaningItem(id: 9, type: 'extra', duration: 45);
      final changedItem = extraItem.copyWith(type: 'emergency');
      final result = ReportCalculator.calculateWorkItem(changedItem);

      expect(result['item'], '緊急対応');
      expect(result['unitPrice'], 2000);
      expect(result['amount'], 1500); // 2000 * 45/60 = 1500
    });

    test('緊急対応から追加業務へ変更された場合の計算 (Emergency -> Extra)', () {
      final emergencyItem =
          CleaningItem(id: 10, type: 'emergency', duration: 90);
      final changedItem = emergencyItem.copyWith(type: 'extra');
      final result = ReportCalculator.calculateWorkItem(changedItem);

      expect(result['item'], '追加業務');
      expect(result['unitPrice'], 1800);
      expect(result['amount'], 2700); // 1800 * 90/60 = 2700
    });
  });
}
