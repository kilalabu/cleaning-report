// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'history_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HistoryState {
  String get selectedMonth;
  AsyncValue<List<Report>> get reports;
  bool get isGeneratingPdf;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HistoryStateCopyWith<HistoryState> get copyWith =>
      _$HistoryStateCopyWithImpl<HistoryState>(
          this as HistoryState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HistoryState &&
            (identical(other.selectedMonth, selectedMonth) ||
                other.selectedMonth == selectedMonth) &&
            (identical(other.reports, reports) || other.reports == reports) &&
            (identical(other.isGeneratingPdf, isGeneratingPdf) ||
                other.isGeneratingPdf == isGeneratingPdf));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, selectedMonth, reports, isGeneratingPdf);

  @override
  String toString() {
    return 'HistoryState(selectedMonth: $selectedMonth, reports: $reports, isGeneratingPdf: $isGeneratingPdf)';
  }
}

/// @nodoc
abstract mixin class $HistoryStateCopyWith<$Res> {
  factory $HistoryStateCopyWith(
          HistoryState value, $Res Function(HistoryState) _then) =
      _$HistoryStateCopyWithImpl;
  @useResult
  $Res call(
      {String selectedMonth,
      AsyncValue<List<Report>> reports,
      bool isGeneratingPdf});
}

/// @nodoc
class _$HistoryStateCopyWithImpl<$Res> implements $HistoryStateCopyWith<$Res> {
  _$HistoryStateCopyWithImpl(this._self, this._then);

  final HistoryState _self;
  final $Res Function(HistoryState) _then;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedMonth = null,
    Object? reports = null,
    Object? isGeneratingPdf = null,
  }) {
    return _then(_self.copyWith(
      selectedMonth: null == selectedMonth
          ? _self.selectedMonth
          : selectedMonth // ignore: cast_nullable_to_non_nullable
              as String,
      reports: null == reports
          ? _self.reports
          : reports // ignore: cast_nullable_to_non_nullable
              as AsyncValue<List<Report>>,
      isGeneratingPdf: null == isGeneratingPdf
          ? _self.isGeneratingPdf
          : isGeneratingPdf // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [HistoryState].
extension HistoryStatePatterns on HistoryState {
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
    TResult Function(_HistoryState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HistoryState() when $default != null:
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
    TResult Function(_HistoryState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HistoryState():
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
    TResult? Function(_HistoryState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HistoryState() when $default != null:
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
    TResult Function(String selectedMonth, AsyncValue<List<Report>> reports,
            bool isGeneratingPdf)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HistoryState() when $default != null:
        return $default(
            _that.selectedMonth, _that.reports, _that.isGeneratingPdf);
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
    TResult Function(String selectedMonth, AsyncValue<List<Report>> reports,
            bool isGeneratingPdf)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HistoryState():
        return $default(
            _that.selectedMonth, _that.reports, _that.isGeneratingPdf);
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
    TResult? Function(String selectedMonth, AsyncValue<List<Report>> reports,
            bool isGeneratingPdf)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HistoryState() when $default != null:
        return $default(
            _that.selectedMonth, _that.reports, _that.isGeneratingPdf);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _HistoryState extends HistoryState {
  const _HistoryState(
      {required this.selectedMonth,
      required this.reports,
      this.isGeneratingPdf = false})
      : super._();

  @override
  final String selectedMonth;
  @override
  final AsyncValue<List<Report>> reports;
  @override
  @JsonKey()
  final bool isGeneratingPdf;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HistoryStateCopyWith<_HistoryState> get copyWith =>
      __$HistoryStateCopyWithImpl<_HistoryState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HistoryState &&
            (identical(other.selectedMonth, selectedMonth) ||
                other.selectedMonth == selectedMonth) &&
            (identical(other.reports, reports) || other.reports == reports) &&
            (identical(other.isGeneratingPdf, isGeneratingPdf) ||
                other.isGeneratingPdf == isGeneratingPdf));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, selectedMonth, reports, isGeneratingPdf);

  @override
  String toString() {
    return 'HistoryState(selectedMonth: $selectedMonth, reports: $reports, isGeneratingPdf: $isGeneratingPdf)';
  }
}

/// @nodoc
abstract mixin class _$HistoryStateCopyWith<$Res>
    implements $HistoryStateCopyWith<$Res> {
  factory _$HistoryStateCopyWith(
          _HistoryState value, $Res Function(_HistoryState) _then) =
      __$HistoryStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String selectedMonth,
      AsyncValue<List<Report>> reports,
      bool isGeneratingPdf});
}

/// @nodoc
class __$HistoryStateCopyWithImpl<$Res>
    implements _$HistoryStateCopyWith<$Res> {
  __$HistoryStateCopyWithImpl(this._self, this._then);

  final _HistoryState _self;
  final $Res Function(_HistoryState) _then;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? selectedMonth = null,
    Object? reports = null,
    Object? isGeneratingPdf = null,
  }) {
    return _then(_HistoryState(
      selectedMonth: null == selectedMonth
          ? _self.selectedMonth
          : selectedMonth // ignore: cast_nullable_to_non_nullable
              as String,
      reports: null == reports
          ? _self.reports
          : reports // ignore: cast_nullable_to_non_nullable
              as AsyncValue<List<Report>>,
      isGeneratingPdf: null == isGeneratingPdf
          ? _self.isGeneratingPdf
          : isGeneratingPdf // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
