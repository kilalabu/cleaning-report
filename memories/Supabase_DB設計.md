# Supabase DB設計 背景説明書

## 目次
1. [Supabaseとは](#supabaseとは)
2. [Supabase特有の制約と仕様](#supabase特有の制約と仕様)
3. [テーブル設計の背景](#テーブル設計の背景)
4. [RLS設計の背景](#rls設計の背景)
5. [ユーザー作成の手順](#ユーザー作成の手順)
6. [Q&A](#qa)

---

## Supabaseとは

Supabaseは「オープンソースのFirebase代替」として開発されたBaaS（Backend as a Service）です。

### 主要コンポーネント
| コンポーネント | 説明 |
| :--- | :--- |
| **Database** | PostgreSQLベースのRDB。フルSQL対応 |
| **Auth** | 認証・認可システム（Email/Password、OAuth等） |
| **Storage** | ファイルストレージ（S3互換） |
| **Edge Functions** | Deno製のサーバーレス関数 |
| **Realtime** | WebSocketベースのリアルタイム通信 |

### Free Tierの制限（2025年1月時点）
| リソース | 制限 |
| :--- | :--- |
| Database容量 | 500MB |
| ファイルストレージ | 1GB |
| Edge Function呼び出し | 500,000回/月 |
| 月間アクティブユーザー | 50,000 MAU |
| プロジェクト数 | 2個 |
| **休止ポリシー** | **7日間アクセスがないとプロジェクトが一時停止** |

> [!WARNING]
> **休止ポリシーに注意**: 7日間データベースへのアクセスがないと、プロジェクトが自動で一時停止されます。復旧は可能ですが、利用頻度が低い場合は定期的なアクセスが必要です。

---

## Supabase特有の制約と仕様

### 1. `auth.users` テーブルは直接操作しない

```
⚠️ Supabase Auth が管理する auth.users テーブルは直接INSERT/UPDATE/DELETEしてはいけない
```

Supabase Authは `auth` スキーマに専用のテーブル群を持っています：
- `auth.users` - ユーザー情報（email, encrypted_password等）
- `auth.sessions` - セッション情報
- `auth.refresh_tokens` - リフレッシュトークン

**ユーザー追加の正しい方法**:
1. Dashboard → Authentication → Users から手動作成
2. `supabase.auth.admin.createUser()` API を使用
3. `supabase.auth.signUp()` でユーザー自身が登録

**カスタム属性（role, display_name等）の追加方法**:
→ `public.profiles` テーブルを作成し、`auth.users.id` とリレーションを張る

### 2. `public` スキーマと `auth` スキーマ

```sql
-- ✅ publicスキーマ: 自由に操作可能
public.profiles
public.reports

-- ❌ authスキーマ: Supabase管理、直接操作NG
auth.users
auth.sessions
```

### 3. RLS（Row Level Security）はデフォルト無効

```
⚠️ テーブル作成後、RLSを明示的に有効化しないと全データが公開状態になる
```

```sql
-- RLSを有効化（必須）
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
```

RLSを有効化しただけだと**全てのアクセスが拒否**されます。ポリシーを追加して初めてアクセスできるようになります。

### 4. `auth.uid()` 関数

RLSポリシー内で現在ログイン中のユーザーIDを取得する組み込み関数:

```sql
-- 「自分のデータのみ」の条件
WHERE user_id = auth.uid()
```

### 5. APIキーの種類

Supabaseは現在、新しいキーシステムへ移行中です：

| 新しい名称 | 旧名称 | 用途 | RLS |
| :--- | :--- | :--- | :--- |
| **Publishable key** | anon key | クライアントアプリ（Flutter）で使用 | RLS適用 |
| **Secret key** | service_role key | サーバーサイドのみ。絶対に公開しない | RLSバイパス |

> [!NOTE]
> Dashboard上で両方の表記が混在している場合がありますが、機能は同じです。

> [!CAUTION]
> **Secret key**（または `service_role` キー）をFlutterアプリやフロントエンドに埋め込んではいけません。RLSが完全にバイパスされ、全データにアクセス可能になります。

---

## テーブル設計の背景

### なぜ `profiles` テーブルを別途作成するのか？

**理由**: `auth.users` に直接カラムを追加できないため

```
auth.users（Supabase管理）
├── id (UUID)
├── email
├── encrypted_password
└── ...（Supabase内部用）

↓ 1:1 リレーション

public.profiles（自分で管理）
├── id (UUID, auth.usersのid参照)
├── display_name
├── role
└── ...（カスタム属性）
```

#### 代替案: `auth.users.raw_user_meta_data` を使う

Supabaseでは `raw_user_meta_data` というJSONカラムにカスタム属性を格納できます：

```sql
-- ユーザー作成時にmetadataを設定
INSERT INTO auth.users (...) VALUES (..., '{"role": "admin", "display_name": "田中太郎"}'::jsonb)
```

**メリット**:
- テーブル数が減る
- 管理がシンプル

**デメリット**:
- RLSで `role` を参照するクエリが複雑になる
- 正規化されていないのでデータ整合性の担保が難しい
- インデックスが効きにくい

**今回の選択: `profiles` テーブルを使用**
- RLSポリシーで `role` を参照しやすい
- 将来的に属性が増えても対応しやすい

---

### `reports` テーブル設計

#### Phase 1（スプレッドシート）との対応

| Phase 1 カラム | Phase 2 カラム | 変更理由 |
| :--- | :--- | :--- |
| ID | id (UUID) | PostgreSQLのUUID型を使用 |
| Date | date (DATE) | DATE型で日付のみ保持 |
| Type | type (TEXT) | ENUM的にCHECK制約で制限 |
| Item | item (TEXT) | 変更なし |
| UnitPrice | unit_price (INTEGER) | snake_case命名規則に統一 |
| Duration | duration (INTEGER) | 分単位で保持 |
| Amount | amount (INTEGER) | 変更なし |
| Note | note (TEXT) | 変更なし |
| CreatedAt | created_at (TIMESTAMPTZ) | タイムゾーン付きで保存 |
| Month | month (TEXT) | 'yyyy-MM' 形式を維持 |
| *なし* | **user_id (UUID)** | **ユーザー識別用に追加** |
| *なし* | **updated_at (TIMESTAMPTZ)** | **更新追跡用に追加** |

#### `month` カラムを保持する理由

「`date` から月を抽出すれば不要では？」という疑問があるかもしれません。

**保持する理由**:
1. **インデックス効率**: `WHERE month = '2026-01'` はインデックスが効きやすい
2. **クエリ簡略化**: 毎回 `EXTRACT(YEAR FROM date) || '-' || LPAD(...)` を書く必要がない
3. **Phase 1との互換性**: 既存ロジックをそのまま移行しやすい

---

## RLS設計の背景

### ポリシー設計のポイント

#### 1. `profiles` テーブルのポリシー

```sql
-- ポリシー1: 自分のプロフィールは見れる
CREATE POLICY "Users can view own profile"
ON public.profiles FOR SELECT
USING (auth.uid() = id);

-- ポリシー2: 管理者は全員のプロフィールを見れる
CREATE POLICY "Admins can view all profiles"
ON public.profiles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

**なぜ2つのポリシーが必要か？**

RLSポリシーは **OR条件** で評価されます。つまり：
- ポリシー1 **または** ポリシー2 を満たせばアクセス可能

これにより：
- 一般スタッフ → 自分のプロフィールのみ閲覧可
- 管理者 → 全員のプロフィール閲覧可

> [!CAUTION]
> **profiles テーブルの RLS で無限再帰に注意**
> 「Admins can view all profiles」ポリシー内で `profiles` テーブル自身を参照すると、ポリシー評価時に無限ループが発生します。
> 実際の実装では、この問題を回避するため「自分のプロフィールのみ閲覧可」ポリシーのみを使用し、admin用のポリシーは `reports` テーブルに対してのみ設定しています。

#### 2. `reports` テーブルのポリシー

```sql
-- ポリシー1: 自分のレポートは全操作可
CREATE POLICY "Users can manage own reports"
ON public.reports FOR ALL
USING (auth.uid() = user_id);

-- ポリシー2: 管理者は全レポートに対して全操作可
CREATE POLICY "Admins can manage all reports"
ON public.reports FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

### RLSのパフォーマンス考慮

`EXISTS` サブクエリを使ったポリシーは、毎回 `profiles` テーブルを参照します。

```sql
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
```

**最適化のポイント**:
- `profiles.id` にはPRIMARY KEYインデックスがある
- `profiles.role` にもインデックスを追加すると良い（任意）

```sql
CREATE INDEX idx_profiles_role ON public.profiles(role);
```

今回のデータ量（ユーザー2名、レポート月数十件）では問題になりませんが、スケール時は検討が必要です。

---

## ユーザー作成の手順

### 推奨手順（Dashboard経由）

1. **Supabase Dashboard** にログイン
2. **Authentication** → **Users** に移動
3. **Add user** をクリック
4. Email / Password を入力して作成
5. 作成されたユーザーのUUIDをコピー
6. **SQL Editor** で `profiles` にデータを追加:

```sql
INSERT INTO public.profiles (id, display_name, role)
VALUES 
  ('UUID-of-admin-user', '桑原 宏和', 'admin'),
  ('UUID-of-staff-user', '田中 太郎', 'staff');
```

### 注意点

> [!IMPORTANT]
> **ユーザー作成 → profiles挿入** の順序は必須です。
> `profiles.id` は `auth.users.id` を外部キー参照しているため、先に `auth.users` にユーザーが存在している必要があります。

### 初回ログイン

ユーザー作成時に「Auto confirm users」オプションを有効にしない場合、ユーザーはメール確認が必要です。

開発中は **Authentication → Providers → Email** で「Confirm email」をオフにすると便利です。

---

## Q&A

### Q1: profilesへの挿入を自動化できないか？

**A**: Supabaseのトリガー機能で自動化可能です：

```sql
-- auth.usersに新規ユーザーが追加されたらprofilesにも自動追加
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'role', 'staff')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

ただし今回はユーザー数が2名のため、**手動作成で十分**と判断しています。

### Q2: RLSを使わずにFlutter側でフィルタリングしても良いのでは？

**A**: セキュリティ上、推奨しません。

クライアントサイドのフィルタリングは**バイパス可能**です。悪意あるユーザーがAPIを直接叩けば、全データにアクセスできてしまいます。

RLSはデータベースレベルで強制されるため、クライアントの実装に関係なくセキュリティが担保されます。

### Q3: `type` カラムはENUM型にすべきでは？

**A**: PostgreSQLのENUM型は後からの変更が面倒なため、`TEXT + CHECK制約` を選択しています：

```sql
type TEXT NOT NULL CHECK (type IN ('work', 'expense'))
```

ENUM型の課題:
- 新しい値の追加に `ALTER TYPE ... ADD VALUE` が必要
- 値の削除・変更は非常に困難

### Q4: user_idの代わりにemailで識別できないか？

**A**: 技術的には可能ですが、以下の理由でUUIDを使用します：

1. **パフォーマンス**: UUIDはバイナリ比較、emailは文字列比較でUUIDが高速
2. **不変性**: emailは変更される可能性がある（将来的に）
3. **Supabase標準**: Supabase Authが `auth.uid()` でUUIDを返すため

---

## 次のステップ

✅ **Phase 2 完了!** 以下の実装が完了しています：

1. [x] Supabaseプロジェクト作成
2. [x] SQLでテーブル作成（profiles, reports）
3. [x] RLSポリシー設定
4. [x] テストユーザー作成（Dashboardから）
5. [x] Flutterから接続テスト
