// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'expense_report_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExpenseReportState {
  String get date;
  String get item;
  String get amount;
  String? get note;
  bool get isSubmitting;

  /// Create a copy of ExpenseReportState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExpenseReportStateCopyWith<ExpenseReportState> get copyWith =>
      _$ExpenseReportStateCopyWithImpl<ExpenseReportState>(
          this as ExpenseReportState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExpenseReportState &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.item, item) || other.item == item) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, date, item, amount, note, isSubmitting);

  @override
  String toString() {
    return 'ExpenseReportState(date: $date, item: $item, amount: $amount, note: $note, isSubmitting: $isSubmitting)';
  }
}

/// @nodoc
abstract mixin class $ExpenseReportStateCopyWith<$Res> {
  factory $ExpenseReportStateCopyWith(
          ExpenseReportState value, $Res Function(ExpenseReportState) _then) =
      _$ExpenseReportStateCopyWithImpl;
  @useResult
  $Res call(
      {String date,
      String item,
      String amount,
      String? note,
      bool isSubmitting});
}

/// @nodoc
class _$ExpenseReportStateCopyWithImpl<$Res>
    implements $ExpenseReportStateCopyWith<$Res> {
  _$ExpenseReportStateCopyWithImpl(this._self, this._then);

  final ExpenseReportState _self;
  final $Res Function(ExpenseReportState) _then;

  /// Create a copy of ExpenseReportState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? item = null,
    Object? amount = null,
    Object? note = freezed,
    Object? isSubmitting = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      item: null == item
          ? _self.item
          : item // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as String,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      isSubmitting: null == isSubmitting
          ? _self.isSubmitting
          : isSubmitting // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [ExpenseReportState].
extension ExpenseReportStatePatterns on ExpenseReportState {
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
    TResult Function(_ExpenseReportState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExpenseReportState() when $default != null:
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
    TResult Function(_ExpenseReportState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExpenseReportState():
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
    TResult? Function(_ExpenseReportState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExpenseReportState() when $default != null:
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
    TResult Function(String date, String item, String amount, String? note,
            bool isSubmitting)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExpenseReportState() when $default != null:
        return $default(_that.date, _that.item, _that.amount, _that.note,
            _that.isSubmitting);
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
    TResult Function(String date, String item, String amount, String? note,
            bool isSubmitting)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExpenseReportState():
        return $default(_that.date, _that.item, _that.amount, _that.note,
            _that.isSubmitting);
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
    TResult? Function(String date, String item, String amount, String? note,
            bool isSubmitting)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExpenseReportState() when $default != null:
        return $default(_that.date, _that.item, _that.amount, _that.note,
            _that.isSubmitting);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ExpenseReportState implements ExpenseReportState {
  const _ExpenseReportState(
      {required this.date,
      this.item = '',
      this.amount = '',
      this.note,
      this.isSubmitting = false});

  @override
  final String date;
  @override
  @JsonKey()
  final String item;
  @override
  @JsonKey()
  final String amount;
  @override
  final String? note;
  @override
  @JsonKey()
  final bool isSubmitting;

  /// Create a copy of ExpenseReportState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExpenseReportStateCopyWith<_ExpenseReportState> get copyWith =>
      __$ExpenseReportStateCopyWithImpl<_ExpenseReportState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExpenseReportState &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.item, item) || other.item == item) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, date, item, amount, note, isSubmitting);

  @override
  String toString() {
    return 'ExpenseReportState(date: $date, item: $item, amount: $amount, note: $note, isSubmitting: $isSubmitting)';
  }
}

/// @nodoc
abstract mixin class _$ExpenseReportStateCopyWith<$Res>
    implements $ExpenseReportStateCopyWith<$Res> {
  factory _$ExpenseReportStateCopyWith(
          _ExpenseReportState value, $Res Function(_ExpenseReportState) _then) =
      __$ExpenseReportStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String date,
      String item,
      String amount,
      String? note,
      bool isSubmitting});
}

/// @nodoc
class __$ExpenseReportStateCopyWithImpl<$Res>
    implements _$ExpenseReportStateCopyWith<$Res> {
  __$ExpenseReportStateCopyWithImpl(this._self, this._then);

  final _ExpenseReportState _self;
  final $Res Function(_ExpenseReportState) _then;

  /// Create a copy of ExpenseReportState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? item = null,
    Object? amount = null,
    Object? note = freezed,
    Object? isSubmitting = null,
  }) {
    return _then(_ExpenseReportState(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      item: null == item
          ? _self.item
          : item // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as String,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      isSubmitting: null == isSubmitting
          ? _self.isSubmitting
          : isSubmitting // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
