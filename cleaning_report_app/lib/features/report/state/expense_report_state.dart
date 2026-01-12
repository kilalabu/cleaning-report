import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense_report_state.freezed.dart';

@freezed
abstract class ExpenseReportState with _$ExpenseReportState {
  const factory ExpenseReportState({
    required String date,
    @Default('') String item,
    @Default('') String amount,
    String? note,
    @Default(false) bool isSubmitting,
  }) = _ExpenseReportState;
}
