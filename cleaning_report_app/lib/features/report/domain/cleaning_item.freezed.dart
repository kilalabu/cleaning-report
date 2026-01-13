// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cleaning_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CleaningItem {
  int get id;
  CleaningReportType get type;
  int get duration;
  String? get note;

  /// Create a copy of CleaningItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CleaningItemCopyWith<CleaningItem> get copyWith =>
      _$CleaningItemCopyWithImpl<CleaningItem>(
          this as CleaningItem, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CleaningItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.note, note) || other.note == note));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, type, duration, note);

  @override
  String toString() {
    return 'CleaningItem(id: $id, type: $type, duration: $duration, note: $note)';
  }
}

/// @nodoc
abstract mixin class $CleaningItemCopyWith<$Res> {
  factory $CleaningItemCopyWith(
          CleaningItem value, $Res Function(CleaningItem) _then) =
      _$CleaningItemCopyWithImpl;
  @useResult
  $Res call({int id, CleaningReportType type, int duration, String? note});
}

/// @nodoc
class _$CleaningItemCopyWithImpl<$Res> implements $CleaningItemCopyWith<$Res> {
  _$CleaningItemCopyWithImpl(this._self, this._then);

  final CleaningItem _self;
  final $Res Function(CleaningItem) _then;

  /// Create a copy of CleaningItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? duration = null,
    Object? note = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as CleaningReportType,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CleaningItem].
extension CleaningItemPatterns on CleaningItem {
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
    TResult Function(_CleaningItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CleaningItem() when $default != null:
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
    TResult Function(_CleaningItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CleaningItem():
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
    TResult? Function(_CleaningItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CleaningItem() when $default != null:
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
            int id, CleaningReportType type, int duration, String? note)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CleaningItem() when $default != null:
        return $default(_that.id, _that.type, _that.duration, _that.note);
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
            int id, CleaningReportType type, int duration, String? note)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CleaningItem():
        return $default(_that.id, _that.type, _that.duration, _that.note);
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
            int id, CleaningReportType type, int duration, String? note)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CleaningItem() when $default != null:
        return $default(_that.id, _that.type, _that.duration, _that.note);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CleaningItem implements CleaningItem {
  const _CleaningItem(
      {required this.id,
      this.type = CleaningReportType.regular,
      this.duration = 15,
      this.note});

  @override
  final int id;
  @override
  @JsonKey()
  final CleaningReportType type;
  @override
  @JsonKey()
  final int duration;
  @override
  final String? note;

  /// Create a copy of CleaningItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CleaningItemCopyWith<_CleaningItem> get copyWith =>
      __$CleaningItemCopyWithImpl<_CleaningItem>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CleaningItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.note, note) || other.note == note));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, type, duration, note);

  @override
  String toString() {
    return 'CleaningItem(id: $id, type: $type, duration: $duration, note: $note)';
  }
}

/// @nodoc
abstract mixin class _$CleaningItemCopyWith<$Res>
    implements $CleaningItemCopyWith<$Res> {
  factory _$CleaningItemCopyWith(
          _CleaningItem value, $Res Function(_CleaningItem) _then) =
      __$CleaningItemCopyWithImpl;
  @override
  @useResult
  $Res call({int id, CleaningReportType type, int duration, String? note});
}

/// @nodoc
class __$CleaningItemCopyWithImpl<$Res>
    implements _$CleaningItemCopyWith<$Res> {
  __$CleaningItemCopyWithImpl(this._self, this._then);

  final _CleaningItem _self;
  final $Res Function(_CleaningItem) _then;

  /// Create a copy of CleaningItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? duration = null,
    Object? note = freezed,
  }) {
    return _then(_CleaningItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as CleaningReportType,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
