class CleaningItem {
  final int id;
  String type;
  int duration;
  String? note;

  CleaningItem({required this.id, this.type = 'regular', this.duration = 15, this.note});

  CleaningItem copyWith({String? type, int? duration, String? note}) {
    return CleaningItem(
      id: this.id,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      note: note ?? this.note,
    );
  }
}
