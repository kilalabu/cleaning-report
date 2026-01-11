# Phase 2：Supabase移行 要件書

## 1. フェーズ概要

### 目的
- データ管理をスプレッドシート（GAS）からRDB（Supabase Postgres）へ移行
- PIN認証からSupabase Authへ移行し、ユーザー管理を実現
- RDBの設計やBaaSを利用したモダンなアプリ開発のフローを習得

### 必須要件
- **無料で運用する**（Supabase Free Tier内で運用）

### 技術構成
| レイヤー | 技術 | 備考 |
| :--- | :--- | :--- |
| フロントエンド | Flutter Web | 既存コードを継続 |
| 認証 | Supabase Auth | Email/Password認証 |
| データベース | Supabase Postgres | RLS（Row Level Security）で権限管理 |
| PDF生成 | GAS | Supabase Edge Functions → GAS を叩く |

---

## 2. ユーザー・権限モデル

### ユーザーロール
| ロール | 説明 |
| :--- | :--- |
| `admin` | 管理者。全データの閲覧・編集・削除・PDF発行が可能 |
| `staff` | 清掃スタッフ。自分のデータのみ閲覧・編集・削除が可能 |

### 初期ユーザー
- 管理者: 1名（桑原さん）
- 清掃スタッフ: 1名

### 権限マトリクス
| 操作 | admin | staff |
| :--- | :---: | :---: |
| 自分のレポート作成 | ✅ | ✅ |
| 自分のレポート閲覧 | ✅ | ✅ |
| 自分のレポート編集 | ✅ | ✅ |
| 自分のレポート削除 | ✅ | ✅ |
| 他ユーザーのレポート閲覧 | ✅ | ❌ |
| 他ユーザーのレポート編集 | ✅ | ❌ |
| 他ユーザーのレポート削除 | ✅ | ❌ |
| PDF請求書発行 | ✅ | ❌ |
| ユーザー管理 | ✅ | ❌ |

---

## 3. 認証設計

### 認証方式
- Supabase Auth（Email/Password）
- セッション管理はSupabase SDKが自動で行う

### 移行前後の比較
| 項目 | Phase 1（現状） | Phase 2（移行後） |
| :--- | :--- | :--- |
| 認証方式 | 4桁PIN（共通PIN） | Email/Password |
| セッション維持 | SessionStorage（30分） | Supabase Session（自動更新） |
| ユーザー識別 | なし | user_id で識別 |

### 認証フロー
```
[アプリ起動]
    ↓
[セッション確認] ─ あり → [メイン画面へ]
    │
    └─ なし → [ログイン画面]
                   ↓
              [Email/Password入力]
                   ↓
              [Supabase Auth認証]
                   ↓
              [成功] → [メイン画面へ]
```

---

## 4. データベース設計

### テーブル一覧

#### `users` テーブル（Supabase Auth連携）
```sql
-- Supabase Authのauth.usersを拡張
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `reports` テーブル
```sql
CREATE TABLE public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('work', 'expense')),
  item TEXT NOT NULL,
  unit_price INTEGER,
  duration INTEGER,  -- 分単位
  amount INTEGER NOT NULL,
  note TEXT,
  month TEXT NOT NULL,  -- 'yyyy-MM' 形式
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- インデックス
CREATE INDEX idx_reports_user_id ON public.reports(user_id);
CREATE INDEX idx_reports_month ON public.reports(month);
CREATE INDEX idx_reports_date ON public.reports(date);
```

### 現行データモデルとの対応
| Phase 1 (スプレッドシート) | Phase 2 (Postgres) |
| :--- | :--- |
| ID | id (UUID) |
| Date | date (DATE) |
| Type | type (TEXT) |
| Item | item (TEXT) |
| UnitPrice | unit_price (INTEGER) |
| Duration | duration (INTEGER) |
| Amount | amount (INTEGER) |
| Note | note (TEXT) |
| CreatedAt | created_at (TIMESTAMPTZ) |
| Month | month (TEXT) |
| *なし* | user_id (UUID) ← **新規追加** |
| *なし* | updated_at (TIMESTAMPTZ) ← **新規追加** |

---

## 5. Row Level Security (RLS)

### profiles テーブル
```sql
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 自分のプロフィールのみ閲覧可能
CREATE POLICY "Users can view own profile"
ON public.profiles FOR SELECT
USING (auth.uid() = id);

-- 管理者は全員のプロフィールを閲覧可能
CREATE POLICY "Admins can view all profiles"
ON public.profiles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

### reports テーブル
```sql
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- スタッフ: 自分のレポートのみ全操作可
CREATE POLICY "Users can manage own reports"
ON public.reports FOR ALL
USING (auth.uid() = user_id);

-- 管理者: 全レポートに対して全操作可
CREATE POLICY "Admins can manage all reports"
ON public.reports FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

---

## 6. アーキテクチャ設計

### 設計方針

> [!IMPORTANT]
> **将来のKtor移行を見据え、UI層（Presentation Layer）がデータ層（Data Layer）の実装詳細に依存しない設計とする。**

バックエンドをSupabase → Ktor、DBをPostgres → Cloud SQLなどに変更する際、**Data Layerの実装クラスのみ差し替え**で対応できるようにする。

### レイヤー構成

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (UI: Screens, Widgets, Providers/Controllers)               │
│  ※ Domain層のEntityとRepositoryインターフェースのみ参照      │
└─────────────────────────────────────────────────────────────┘
                              ↓ 依存
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  - Entities: Report, User などの純粋なデータモデル           │
│  - Repository Interfaces: ReportRepository, AuthRepository   │
│  ※ 外部依存なし（Pure Dart）                                 │
└─────────────────────────────────────────────────────────────┘
                              ↑ 実装
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  - Repository Impls: SupabaseReportRepository など           │
│  - Data Sources: Supabase SDK, HTTP Client                   │
│  ※ Phase 3ではKtorApiReportRepositoryに差し替え             │
└─────────────────────────────────────────────────────────────┘
```

### ディレクトリ構成

```
lib/
├── core/
│   ├── di/                      # 依存性注入
│   │   └── providers.dart       # Riverpod Providers（Repository注入）
│   └── ...
│
├── domain/                      # Domain Layer（Pure Dart）
│   ├── entities/
│   │   ├── report.dart          # Report Entity
│   │   └── user.dart            # User Entity
│   └── repositories/
│       ├── report_repository.dart    # ReportRepository Interface
│       └── auth_repository.dart      # AuthRepository Interface
│
├── data/                        # Data Layer
│   ├── repositories/
│   │   ├── supabase_report_repository.dart
│   │   └── supabase_auth_repository.dart
│   └── datasources/
│       └── supabase_client.dart
│
└── features/                    # Presentation Layer
    ├── auth/
    │   ├── presentation/
    │   └── providers/
    ├── report/
    │   ├── presentation/
    │   └── providers/
    └── history/
        ├── presentation/
        └── providers/
```

### Domain Layer

#### Entity: Report
```dart
// lib/domain/entities/report.dart
class Report {
  final String id;
  final String userId;
  final DateTime date;
  final ReportType type;
  final String item;
  final int? unitPrice;
  final int? duration;  // 分単位
  final int amount;
  final String? note;
  final String month;  // 'yyyy-MM'
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Report({
    required this.id,
    required this.userId,
    required this.date,
    required this.type,
    required this.item,
    this.unitPrice,
    this.duration,
    required this.amount,
    this.note,
    required this.month,
    required this.createdAt,
    this.updatedAt,
  });
}

enum ReportType { work, expense }
```

#### Entity: User
```dart
// lib/domain/entities/user.dart
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

  bool get isAdmin => role == UserRole.admin;
}

enum UserRole { admin, staff }
```

#### Repository Interface: ReportRepository
```dart
// lib/domain/repositories/report_repository.dart
abstract class ReportRepository {
  /// 指定月のレポート一覧を取得
  Future<List<Report>> getReports({required String month});
  
  /// レポートを保存（新規作成）
  Future<Report> createReport(Report report);
  
  /// レポートを更新
  Future<Report> updateReport(Report report);
  
  /// レポートを削除
  Future<void> deleteReport(String id);
}
```

#### Repository Interface: AuthRepository
```dart
// lib/domain/repositories/auth_repository.dart
abstract class AuthRepository {
  /// 現在のユーザーを取得（未認証時はnull）
  Future<User?> getCurrentUser();
  
  /// ログイン
  Future<User> signIn({required String email, required String password});
  
  /// ログアウト
  Future<void> signOut();
  
  /// 認証状態の変更を監視
  Stream<User?> authStateChanges();
}
```

### Data Layer

#### SupabaseReportRepository
```dart
// lib/data/repositories/supabase_report_repository.dart
class SupabaseReportRepository implements ReportRepository {
  final SupabaseClient _client;
  
  SupabaseReportRepository(this._client);
  
  @override
  Future<List<Report>> getReports({required String month}) async {
    final response = await _client
        .from('reports')
        .select()
        .eq('month', month)
        .order('date', ascending: false);
    
    return response.map((json) => _fromJson(json)).toList();
  }
  
  // ... 他のメソッド実装
  
  Report _fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      type: ReportType.values.byName(json['type']),
      item: json['item'],
      unitPrice: json['unit_price'],
      duration: json['duration'],
      amount: json['amount'],
      note: json['note'],
      month: json['month'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
}
```

### 依存性注入（Riverpod）

```dart
// lib/core/di/providers.dart
import 'package:riverpod/riverpod.dart';

// Supabase Client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Repository Providers
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseReportRepository(client);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});
```

### Phase 3（Ktor移行）時の変更

Ktor移行時は、Data Layerの実装クラスを差し替えるだけで対応可能：

```dart
// lib/data/repositories/ktor_report_repository.dart
class KtorReportRepository implements ReportRepository {
  final KtorApiClient _apiClient;
  
  KtorReportRepository(this._apiClient);
  
  @override
  Future<List<Report>> getReports({required String month}) async {
    final response = await _apiClient.get('/reports', params: {'month': month});
    return response.map((json) => _fromJson(json)).toList();
  }
  
  // ... 他のメソッド実装
}

// providers.dart での差し替え
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final apiClient = ref.watch(ktorApiClientProvider);
  return KtorReportRepository(apiClient);  // ← ここだけ変更
});
```

### API対応表

| 操作 | Phase 1 (GAS) | Phase 2 (Supabase) | Phase 3 (Ktor) |
| :--- | :--- | :--- | :--- |
| 認証 | `verifyPin()` | `AuthRepository.signIn()` | `AuthRepository.signIn()` |
| データ取得 | `getData()` | `ReportRepository.getReports()` | `ReportRepository.getReports()` |
| データ保存 | `saveReport()` | `ReportRepository.createReport()` | `ReportRepository.createReport()` |
| データ更新 | `updateReport()` | `ReportRepository.updateReport()` | `ReportRepository.updateReport()` |
| データ削除 | `deleteData()` | `ReportRepository.deleteReport()` | `ReportRepository.deleteReport()` |

> [!NOTE]
> UI層（Presentation Layer）はRepositoryインターフェースのみに依存するため、バックエンド変更時もUI層のコード変更は不要。

---

## 7. PDF生成フロー

### Phase 2での構成
```
[Flutter Web]
    ↓ 
[Supabase Edge Functions]
    ↓ HTTP Request
[GAS Web App]
    ↓
[PDF Base64 返却]
    ↓
[Flutter Webでダウンロード]
```

### Edge Function 実装概要
```typescript
// supabase/functions/generate-pdf/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  // 1. 認証チェック（JWTから user_id取得）
  // 2. 管理者権限チェック
  // 3. 対象月のデータをSupabaseから取得
  // 4. GAS APIにデータを送信してPDF生成
  // 5. Base64 PDFを返却
})
```

### GAS側の変更
- 認証: Supabase Edge Functionsからの呼び出しのみ許可（APIキー認証など）
- データ取得: GAS側では取得せず、Edge Functionsからデータを受け取る

---

## 8. マイグレーション方針

### 既存データ
- マイグレーション不要（新規データからSupabaseを使用開始）
- 過去データはスプレッドシートに残し、必要に応じて参照

### 移行手順
1. Supabaseプロジェクト作成
2. テーブル・RLS設定
3. Flutter側SDKセットアップ
4. 認証画面実装
5. CRUD処理をSupabase SDKに置き換え
6. Edge Functions + GAS連携でPDF生成実装
7. 動作検証・デプロイ

---

## 9. 画面変更点

### 認証画面
| 変更点 | 詳細 |
| :--- | :--- |
| PIN入力 → ログイン画面 | Email/Passwordフォームに変更 |
| 新規登録 | 管理者がユーザーを事前作成するため、新規登録画面は不要 |
| パスワードリセット | 初期リリースでは実装しない（管理者が手動対応） |

### 履歴画面
| 変更点 | 詳細 |
| :--- | :--- |
| データ表示 | staff: 自分のデータのみ表示 / admin: 全データ表示 |
| PDF発行ボタン | admin のみ表示 |

### レポート入力画面
| 変更点 | 詳細 |
| :--- | :--- |
| 送信時の処理 | user_id を自動付与してSupabaseに保存 |

---

## 10. 成功基準

- [ ] Email/Passwordでログインできる
- [ ] ログアウト後、再ログインが必要になる
- [ ] 清掃スタッフは自分のレポートのみ閲覧・編集・削除できる
- [ ] 管理者は全スタッフのレポートを閲覧・編集・削除できる
- [ ] 管理者のみPDF請求書を発行できる
- [ ] 無料枠内で運用できる（Supabase Free Tier）

---

## 11. 実装タスク（概要）

### フェーズ 2.1: Supabaseセットアップ
1. Supabaseプロジェクト作成
2. テーブル作成（profiles, reports）
3. RLSポリシー設定
4. テストユーザー作成（admin 1名、staff 1名）

### フェーズ 2.2: Domain Layer 構築
> [!NOTE]
> 先にDomain Layerを構築することで、バックエンド実装前にインターフェースを確定させる。

1. `lib/domain/entities/` 配下にEntity作成
   - `report.dart` (Report, ReportType)
   - `user.dart` (User, UserRole)
2. `lib/domain/repositories/` 配下にRepositoryインターフェース作成
   - `report_repository.dart`
   - `auth_repository.dart`

### フェーズ 2.3: Data Layer 構築（Supabase実装）
1. `supabase_flutter` パッケージ追加
2. `lib/data/datasources/supabase_client.dart` 作成
3. `lib/data/repositories/` 配下にRepository実装クラス作成
   - `supabase_report_repository.dart`
   - `supabase_auth_repository.dart`
4. `lib/core/di/providers.dart` でRepository Providerを定義

### フェーズ 2.4: Presentation Layer 修正
1. 認証画面の実装（PIN → Email/Password）
2. 既存のProviderをRepositoryインターフェースを使うよう修正
   - `auth_provider.dart` → `AuthRepository` を使用
   - `history_provider.dart` → `ReportRepository` を使用
3. 画面コンポーネントの修正（既存Entity → Domain Entity）
4. 動作検証

### フェーズ 2.5: PDF生成移行
1. Supabase Edge Functions 作成
2. GAS側の修正（データ受け取り方式に変更）
3. Flutter側のPDF生成呼び出し修正
4. 動作検証

### フェーズ 2.6: 権限・UI調整
1. 履歴画面の権限制御（admin/staff分岐）
2. PDF発行ボタンの表示制御
3. 最終動作検証

---

## 12. 参考資料

- [Supabase Documentation](https://supabase.com/docs)
- [supabase_flutter Package](https://pub.dev/packages/supabase_flutter)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Edge Functions](https://supabase.com/docs/guides/functions)
- [Clean Architecture in Flutter](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

