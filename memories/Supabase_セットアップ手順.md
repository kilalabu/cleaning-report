# Supabase セットアップ手順

## Step 1: Supabaseプロジェクト作成

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. GitHubアカウントでログイン（または新規登録）
3. **New Project** をクリック
4. 以下を入力:
   - **Organization**: 個人または組織を選択
   - **Project name**: `cleaning-report`
   - **Database Password**: 強力なパスワードを設定（後で使わないが控えておく）
   - **Region**: `Northeast Asia (Tokyo)` 推奨
5. **Create new project** をクリック
6. プロジェクト作成完了まで1-2分待つ

## Step 2: テーブル・RLS作成

1. Supabase Dashboard で作成したプロジェクトを開く
2. 左メニューから **SQL Editor** を選択
3. **New query** をクリック
4. `supabase/setup.sql` の内容をコピー＆ペースト
5. **Run** をクリック（または Cmd+Enter）
6. 「Success. No rows returned」と表示されれば成功

### 確認方法
1. 左メニューから **Table Editor** を選択
2. `profiles` と `reports` テーブルが表示されていることを確認

## Step 3: テストユーザー作成

### 3.1 管理者ユーザー作成
1. 左メニューから **Authentication** を選択
2. **Users** タブを選択
3. **Add user** → **Create new user** をクリック
4. 以下を入力:
   - **Email**: 管理者のメールアドレス（例: `admin@example.com`）
   - **Password**: パスワードを設定
5. **Create user** をクリック
6. 作成されたユーザーの **User UID** をコピー

### 3.2 スタッフユーザー作成
1. 同様に **Add user** → **Create new user**
2. 以下を入力:
   - **Email**: スタッフのメールアドレス（例: `staff@example.com`）
   - **Password**: パスワードを設定
3. 作成されたユーザーの **User UID** をコピー

### 3.3 profilesにデータ追加
1. **SQL Editor** に戻る
2. 以下のSQLを実行（UUIDは実際の値に置き換え）:

```sql
INSERT INTO public.profiles (id, display_name, role)
VALUES 
  ('ここに管理者のUUID', '桑原 宏和', 'admin'),
  ('ここにスタッフのUUID', '田中 太郎', 'staff');
```

## Step 4: 接続情報の取得

1. 左メニューから **Settings** → **API** を選択
2. 以下の情報をメモ:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **Publishable key** (anon key): `eyJhbGciOiJS...`（クライアントアプリで使用）

> [!NOTE]
> Supabaseは現在、新しいキーシステムへ移行中です：
> - **Publishable key**: 旧 `anon key` に相当。クライアント（Flutter）で使用可能
> - **Secret key**: 旧 `service_role key` に相当。サーバーサイドのみで使用
> 
> Dashboard上で両方の表記が混在している場合がありますが、機能は同じです。

> [!CAUTION]
> **Secret key**（または `service_role` キー）は**絶対にコピーしない**でください。
> このキーはRLSをバイパスするため、クライアントアプリに含めると重大なセキュリティリスクになります。

## Step 5: メール確認の無効化（開発用）

開発中はメール確認を無効化すると便利です:

1. **Authentication** → **Providers** を選択
2. **Email** プロバイダーをクリック
3. **Confirm email** をオフにする
4. **Save** をクリック

## 完了チェックリスト

- [x] プロジェクト作成完了
- [x] テーブル作成完了（profiles, reports）
- [x] RLSポリシー設定完了
- [x] 管理者ユーザー作成＆profiles追加
- [x] スタッフユーザー作成＆profiles追加
- [x] Project URL と Publishable key をメモ

> [!TIP]
> **RLSポリシー設定時の注意**
> `profiles` テーブルのポリシー内で `profiles` 自身を参照すると無限再帰が発生します。
> 詳細は `phase2_db_design_background.md` を参照してください。

---

## 次のステップ

✅ **セットアップ完了！**

接続情報が取得できたら、Flutterプロジェクトに `supabase_flutter` パッケージを追加して接続テストを行います。

詳細な実装手順は以下のドキュメントを参照してください：
- [DB設計背景](phase2_db_design_background.md)
- [Edge Functions設計](edge_functions_design.md)
