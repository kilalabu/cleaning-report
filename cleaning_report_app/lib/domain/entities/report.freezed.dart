// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Report {
  String get id;
  String get userId;
  DateTime get date;
  ReportType get type;
  CleaningReportType? get cleaningType; // 清掃業務の場合にセット
  String? get expenseItem; // 立替経費の場合にセット
  int? get unitPrice;
  int? get duration; // 分単位
  int get amount;
  String? get note;
  String get month; // 'yyyy-MM' 形式
  DateTime get createdAt;
  DateTime? get updatedAt;

  /// Create a copy of Report
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReportCopyWith<Report> get copyWith =>
      _$ReportCopyWithImpl<Report>(this as Report, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Report &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.cleaningType, cleaningType) ||
                other.cleaningType == cleaningType) &&
            (identical(other.expenseItem, expenseItem) ||
                other.expenseItem == expenseItem) &&
            (identical(other.unitPrice, unitPrice) ||
                other.unitPrice == unitPrice) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      date,
      type,
      cleaningType,
      expenseItem,
      unitPrice,
      duration,
      amount,
      note,
      month,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'Report(id: $id, userId: $userId, date: $date, type: $type, cleaningType: $cleaningType, expenseItem: $expenseItem, unitPrice: $unitPrice, duration: $duration, amount: $amount, note: $note, month: $month, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $ReportCopyWith<$Res> {
  factory $ReportCopyWith(Report value, $Res Function(Report) _then) =
      _$ReportCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String userId,
      DateTime date,
      ReportType type,
      CleaningReportType? cleaningType,
      String? expenseItem,
      int? unitPrice,
      int? duration,
      int amount,
      String? note,
      String month,
      DateTime createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$ReportCopyWithImpl<$Res> implements $ReportCopyWith<$Res> {
  _$ReportCopyWithImpl(this._self, this._then);

  final Report _self;
  final $Res Function(Report) _then;

  /// Create a copy of Report
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? date = null,
    Object? type = null,
    Object? cleaningType = freezed,
    Object? expenseItem = freezed,
    Object? unitPrice = freezed,
    Object? duration = freezed,
    Object? amount = null,
    Object? note = freezed,
    Object? month = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as ReportType,
      cleaningType: freezed == cleaningType
          ? _self.cleaningType
          : cleaningType // ignore: cast_nullable_to_non_nullable
              as CleaningReportType?,
      expenseItem: freezed == expenseItem
          ? _self.expenseItem
          : expenseItem // ignore: cast_nullable_to_non_nullable
              as String?,
      unitPrice: freezed == unitPrice
          ? _self.unitPrice
          : unitPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      duration: freezed == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int?,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      month: null == month
          ? _self.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Report].
extension ReportPatterns on Report {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_Report value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Report() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_Report value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Report():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_Report value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Report() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            String userId,
            DateTime date,
            ReportType type,
            CleaningReportType? cleaningType,
            String? expenseItem,
            int? unitPrice,
            int? duration,
            int amount,
            String? note,
            String month,
            DateTime createdAt,
            DateTime? updatedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Report() when $default != null:
        return $default(
            _that.id,
            _that.userId,
            _that.date,
            _that.type,
            _that.cleaningType,
            _that.expenseItem,
            _that.unitPrice,
            _that.duration,
            _that.amount,
            _that.note,
            _that.month,
            _that.createdAt,
            _that.updatedAt);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
            String userId,
            DateTime date,
            ReportType type,
            CleaningReportType? cleaningType,
            String? expenseItem,
            int? unitPrice,
            int? duration,
            int amount,
            String? note,
            String month,
            DateTime createdAt,
            DateTime? updatedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Report():
        return $default(
            _that.id,
            _that.userId,
            _that.date,
            _that.type,
            _that.cleaningType,
            _that.expenseItem,
            _that.unitPrice,
            _that.duration,
            _that.amount,
            _that.note,
            _that.month,
            _that.createdAt,
            _that.updatedAt);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            String userId,
            DateTime date,
            ReportType type,
            CleaningReportType? cleaningType,
            String? expenseItem,
            int? unitPrice,
            int? duration,
            int amount,
            String? note,
            String month,
            DateTime createdAt,
            DateTime? updatedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Report() when $default != null:
        return $default(
            _that.id,
            _that.userId,
            _that.date,
            _that.type,
            _that.cleaningType,
            _that.expenseItem,
            _that.unitPrice,
            _that.duration,
            _that.amount,
            _that.note,
            _that.month,
            _that.createdAt,
            _that.updatedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Report extends Report {
  const _Report(
      {required this.id,
      required this.userId,
      required this.date,
      required this.type,
      this.cleaningType,
      this.expenseItem,
      this.unitPrice,
      this.duration,
      required this.amount,
      this.note,
      required this.month,
      required this.createdAt,
      this.updatedAt})
      : super._();

  @override
  final String id;
  @override
  final String userId;
  @override
  final DateTime date;
  @override
  final ReportType type;
  @override
  final CleaningReportType? cleaningType;
// 清掃業務の場合にセット
  @override
  final String? expenseItem;
// 立替経費の場合にセット
  @override
  final int? unitPrice;
  @override
  final int? duration;
// 分単位
  @override
  final int amount;
  @override
  final String? note;
  @override
  final String month;
// 'yyyy-MM' 形式
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  /// Create a copy of Report
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReportCopyWith<_Report> get copyWith =>
      __$ReportCopyWithImpl<_Report>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Report &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.cleaningType, cleaningType) ||
                other.cleaningType == cleaningType) &&
            (identical(other.expenseItem, expenseItem) ||
                other.expenseItem == expenseItem) &&
            (identical(other.unitPrice, unitPrice) ||
                other.unitPrice == unitPrice) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      date,
      type,
      cleaningType,
      expenseItem,
      unitPrice,
      duration,
      amount,
      note,
      month,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'Report(id: $id, userId: $userId, date: $date, type: $type, cleaningType: $cleaningType, expenseItem: $expenseItem, unitPrice: $unitPrice, duration: $duration, amount: $amount, note: $note, month: $month, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$ReportCopyWith<$Res> implements $ReportCopyWith<$Res> {
  factory _$ReportCopyWith(_Report value, $Res Function(_Report) _then) =
      __$ReportCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      DateTime date,
      ReportType type,
      CleaningReportType? cleaningType,
      String? expenseItem,
      int? unitPrice,
      int? duration,
      int amount,
      String? note,
      String month,
      DateTime createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$ReportCopyWithImpl<$Res> implements _$ReportCopyWith<$Res> {
  __$ReportCopyWithImpl(this._self, this._then);

  final _Report _self;
  final $Res Function(_Report) _then;

  /// Create a copy of Report
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? date = null,
    Object? type = null,
    Object? cleaningType = freezed,
    Object? expenseItem = freezed,
    Object? unitPrice = freezed,
    Object? duration = freezed,
    Object? amount = null,
    Object? note = freezed,
    Object? month = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_Report(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as ReportType,
      cleaningType: freezed == cleaningType
          ? _self.cleaningType
          : cleaningType // ignore: cast_nullable_to_non_nullable
              as CleaningReportType?,
      expenseItem: freezed == expenseItem
          ? _self.expenseItem
          : expenseItem // ignore: cast_nullable_to_non_nullable
              as String?,
      unitPrice: freezed == unitPrice
          ? _self.unitPrice
          : unitPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      duration: freezed == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int?,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      month: null == month
          ? _self.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
