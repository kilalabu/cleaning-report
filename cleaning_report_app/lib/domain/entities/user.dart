/// User Entity
///
/// ユーザー情報のデータモデル。
/// Data Layer の実装詳細に依存しない純粋なDartクラス。

class User {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  /// 管理者かどうか
  bool get isAdmin => role == UserRole.admin;

  /// スタッフかどうか
  bool get isStaff => role == UserRole.staff;

  /// コピーして一部フィールドを変更
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// ユーザーロール
enum UserRole {
  admin, // 管理者
  staff, // 清掃スタッフ
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return '管理者';
      case UserRole.staff:
        return 'スタッフ';
    }
  }

  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.staff:
        return 'staff';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      default:
        throw ArgumentError('Unknown UserRole: $value');
    }
  }
}
