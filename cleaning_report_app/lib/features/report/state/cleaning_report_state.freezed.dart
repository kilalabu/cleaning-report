// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cleaning_report_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CleaningReportState {
  List<CleaningItem> get items;
  String get date;
  bool get isSubmitting;
  int get idCounter;

  /// Create a copy of CleaningReportState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CleaningReportStateCopyWith<CleaningReportState> get copyWith =>
      _$CleaningReportStateCopyWithImpl<CleaningReportState>(
          this as CleaningReportState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CleaningReportState &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting) &&
            (identical(other.idCounter, idCounter) ||
                other.idCounter == idCounter));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(items),
      date,
      isSubmitting,
      idCounter);

  @override
  String toString() {
    return 'CleaningReportState(items: $items, date: $date, isSubmitting: $isSubmitting, idCounter: $idCounter)';
  }
}

/// @nodoc
abstract mixin class $CleaningReportStateCopyWith<$Res> {
  factory $CleaningReportStateCopyWith(
          CleaningReportState value, $Res Function(CleaningReportState) _then) =
      _$CleaningReportStateCopyWithImpl;
  @useResult
  $Res call(
      {List<CleaningItem> items,
      String date,
      bool isSubmitting,
      int idCounter});
}

/// @nodoc
class _$CleaningReportStateCopyWithImpl<$Res>
    implements $CleaningReportStateCopyWith<$Res> {
  _$CleaningReportStateCopyWithImpl(this._self, this._then);

  final CleaningReportState _self;
  final $Res Function(CleaningReportState) _then;

  /// Create a copy of CleaningReportState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? date = null,
    Object? isSubmitting = null,
    Object? idCounter = null,
  }) {
    return _then(_self.copyWith(
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<CleaningItem>,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      isSubmitting: null == isSubmitting
          ? _self.isSubmitting
          : isSubmitting // ignore: cast_nullable_to_non_nullable
              as bool,
      idCounter: null == idCounter
          ? _self.idCounter
          : idCounter // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [CleaningReportState].
extension CleaningReportStatePatterns on CleaningReportState {
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
    TResult Function(_CleaningReportState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CleaningReportState() when $default != null:
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
    TResult Function(_CleaningReportState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CleaningReportState():
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
    TResult? Function(_CleaningReportState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CleaningReportState() when $default != null:
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
    TResult Function(List<CleaningItem> items, String date, bool isSubmitting,
            int idCounter)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CleaningReportState() when $default != null:
        return $default(
            _that.items, _that.date, _that.isSubmitting, _that.idCounter);
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
    TResult Function(List<CleaningItem> items, String date, bool isSubmitting,
            int idCounter)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CleaningReportState():
        return $default(
            _that.items, _that.date, _that.isSubmitting, _that.idCounter);
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
    TResult? Function(List<CleaningItem> items, String date, bool isSubmitting,
            int idCounter)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CleaningReportState() when $default != null:
        return $default(
            _that.items, _that.date, _that.isSubmitting, _that.idCounter);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CleaningReportState implements CleaningReportState {
  const _CleaningReportState(
      {required final List<CleaningItem> items,
      required this.date,
      this.isSubmitting = false,
      this.idCounter = 1})
      : _items = items;

  final List<CleaningItem> _items;
  @override
  List<CleaningItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String date;
  @override
  @JsonKey()
  final bool isSubmitting;
  @override
  @JsonKey()
  final int idCounter;

  /// Create a copy of CleaningReportState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CleaningReportStateCopyWith<_CleaningReportState> get copyWith =>
      __$CleaningReportStateCopyWithImpl<_CleaningReportState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CleaningReportState &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting) &&
            (identical(other.idCounter, idCounter) ||
                other.idCounter == idCounter));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_items),
      date,
      isSubmitting,
      idCounter);

  @override
  String toString() {
    return 'CleaningReportState(items: $items, date: $date, isSubmitting: $isSubmitting, idCounter: $idCounter)';
  }
}

/// @nodoc
abstract mixin class _$CleaningReportStateCopyWith<$Res>
    implements $CleaningReportStateCopyWith<$Res> {
  factory _$CleaningReportStateCopyWith(_CleaningReportState value,
          $Res Function(_CleaningReportState) _then) =
      __$CleaningReportStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<CleaningItem> items,
      String date,
      bool isSubmitting,
      int idCounter});
}

/// @nodoc
class __$CleaningReportStateCopyWithImpl<$Res>
    implements _$CleaningReportStateCopyWith<$Res> {
  __$CleaningReportStateCopyWithImpl(this._self, this._then);

  final _CleaningReportState _self;
  final $Res Function(_CleaningReportState) _then;

  /// Create a copy of CleaningReportState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
    Object? date = null,
    Object? isSubmitting = null,
    Object? idCounter = null,
  }) {
    return _then(_CleaningReportState(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<CleaningItem>,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      isSubmitting: null == isSubmitting
          ? _self.isSubmitting
          : isSubmitting // ignore: cast_nullable_to_non_nullable
              as bool,
      idCounter: null == idCounter
          ? _self.idCounter
          : idCounter // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
