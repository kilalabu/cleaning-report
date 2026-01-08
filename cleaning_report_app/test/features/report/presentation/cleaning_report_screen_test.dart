import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cleaning_report_app/features/report/presentation/cleaning_report_screen.dart';
import 'package:cleaning_report_app/features/auth/providers/auth_provider.dart';
import 'package:cleaning_report_app/core/api/gas_api_client.dart';

class MockGasApiClient extends GasApiClient {
  @override
  Future<Map<String, dynamic>> saveReport(Map<String, dynamic> reportData) async {
    return {'success': true};
  }
}

void main() {
  testWidgets('中間の業務を削除した際、残った業務の入力内容が正しく維持されることを検証', (WidgetTester tester) async {
    // モックの設定
    final mockApi = MockGasApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
        child: const MaterialApp(
          home: CleaningReportScreen(),
        ),
      ),
    );

    // 初期状態では1つの業務があるはず
    expect(find.text('業務内容'), findsOneWidget);

    // 「通常清掃」を「追加業務」に変更（備考入力欄を出すため）
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加業務 (時給1,800円)').last);
    await tester.pumpAndSettle();

    // 1番目の業務の備考に入力
    await tester.enterText(find.byType(TextFormField).first, '備考1');

    // 2つ目の業務を追加
    final addButton = find.text('業務を追加');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // 2番目の業務の備考に入力
    final textFields2 = find.byType(TextFormField);
    await tester.enterText(textFields2.at(1), '備考2');

    // 3つ目の業務を追加
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // 3番目の業務の備考に入力
    final textFields3 = find.byType(TextFormField);
    await tester.enterText(textFields3.at(2), '備考3');

    // 確認
    expect(find.text('備考1'), findsOneWidget);
    expect(find.text('備考2'), findsOneWidget);
    expect(find.text('備考3'), findsOneWidget);

    // 2番目の業務を削除（中間の削除）
    final closeButtons = find.byIcon(Icons.close);
    expect(closeButtons, findsNWidgets(3));
    
    // 2番目の削除ボタンまでスクロールしてタップ
    await tester.ensureVisible(closeButtons.at(1));
    await tester.tap(closeButtons.at(1));
    await tester.pumpAndSettle();

    // 検証：
    // - 2番目の業務が削除され、合計2つになっていること
    // - 「備考1」と「備考3」が残っていること（「備考2」が消えていること）
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('備考1'), findsOneWidget);
    expect(find.text('備考3'), findsOneWidget);
    expect(find.text('備考2'), findsNothing);
  });
}
