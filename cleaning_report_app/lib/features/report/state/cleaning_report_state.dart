import 'package:freezed_annotation/freezed_annotation.dart';
import '../domain/cleaning_item.dart';

part 'cleaning_report_state.freezed.dart';

@freezed
abstract class CleaningReportState with _$CleaningReportState {
  const factory CleaningReportState({
    required List<CleaningItem> items,
    required String date,
    @Default(false) bool isSubmitting,
    @Default(1) int idCounter,
  }) = _CleaningReportState;
}
