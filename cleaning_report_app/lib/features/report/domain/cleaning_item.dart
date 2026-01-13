import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../domain/entities/cleaning_report_type.dart';

part 'cleaning_item.freezed.dart';

@freezed
abstract class CleaningItem with _$CleaningItem {
  const factory CleaningItem({
    required int id,
    @Default(CleaningReportType.regular) CleaningReportType type,
    @Default(15) int duration,
    String? note,
  }) = _CleaningItem;
}
