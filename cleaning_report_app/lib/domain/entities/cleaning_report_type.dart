enum CleaningReportType {
  regular('通常清掃'),
  extra('追加業務'),
  emergency('緊急対応');

  final String displayName;
  const CleaningReportType(this.displayName);

  static CleaningReportType? fromLabel(String label) {
    for (final type in CleaningReportType.values) {
      if (type.displayName == label) {
        return type;
      }
    }
    return null;
  }
}
