# Supabase Database 理解度チェックリスト

Supabase DBに関する本質的な理解を確認するための問題集です。

---

## 📚 セクション1: 基礎理解（4択問題）

### Q1. Supabase の `auth.users` テーブルについて正しいのはどれ？

- A) 自由にカラムを追加して拡張できる
- B) 直接 INSERT/UPDATE/DELETE を実行して良い
- C) Supabase Auth が管理するため直接操作してはいけない
- D) public スキーマに含まれている

<details>
<summary>答えを見る</summary>

**正解: C**

`auth.users` は Supabase Auth が管理する特別なテーブルです。直接操作すると認証システムとの不整合が発生する可能性があります。

**ユーザー追加の正しい方法:**
1. Dashboard → Authentication → Users から手動作成
2. `supabase.auth.admin.createUser()` API を使用
3. `supabase.auth.signUp()` でユーザー自身が登録

カスタム属性が必要な場合は `public.profiles` テーブルを別途作成します。
</details>

---

### Q2. RLS（Row Level Security）を有効化した直後、何が起こる？

- A) 全てのデータにアクセス可能になる
- B) adminロールのみアクセス可能になる
- C) 全てのアクセスが拒否される
- D) 認証済みユーザーのみアクセス可能になる

<details>
<summary>答えを見る</summary>

**正解: C**

RLSを有効化しただけでは**全てのアクセスが拒否**されます。ポリシーを追加して初めてアクセスできるようになります。

```sql
-- RLSを有効化（これだけでは全拒否）
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- ポリシーを追加して初めてアクセス可能
CREATE POLICY "Users can manage own reports"
ON public.reports FOR ALL
USING (auth.uid() = user_id);
```
</details>

---

### Q3. Supabase の Publishable key（旧 anon key）と Secret key（旧 service_role key）の違いについて正しいのは？

- A) どちらもクライアントアプリで使用して良い
- B) Publishable key は RLS を適用し、Secret key は RLS をバイパスする
- C) Secret key の方がセキュリティが高いのでクライアントで使うべき
- D) 両者に機能的な違いはない

<details>
<summary>答えを見る</summary>

**正解: B**

| キー | 用途 | RLS |
|:---|:---|:---|
| Publishable key | クライアントアプリ（Flutter）で使用 | RLS適用 |
| Secret key | サーバーサイドのみ。絶対に公開しない | RLSバイパス |

**⚠️ Secret key をクライアントに含めると、RLSが完全にバイパスされ全データにアクセス可能になる重大なセキュリティリスクになります。**
</details>

---

### Q4. `auth.uid()` 関数は何を返す？

- A) 現在のセッションID
- B) 現在ログイン中のユーザーのUUID
- C) 現在のリクエストID
- D) データベース管理者のID

<details>
<summary>答えを見る</summary>

**正解: B**

`auth.uid()` はRLSポリシー内で現在ログイン中のユーザーIDを取得する組み込み関数です。

```sql
-- 「自分のデータのみ」の条件
WHERE user_id = auth.uid()
```

これにより、各ユーザーは自分のデータのみにアクセスできるようRLSポリシーを設定できます。
</details>

---

## 📚 セクション2: SQL選択問題

### Q5. 「ユーザーは自分のレポートのみ全操作可能」というRLSポリシーを実現するSQLはどれ？

**A)**
```sql
CREATE POLICY "Users can manage own reports"
ON public.reports FOR SELECT
USING (auth.uid() = user_id);
```

**B)**
```sql
CREATE POLICY "Users can manage own reports"
ON public.reports FOR ALL
USING (auth.uid() = user_id);
```

**C)**
```sql
CREATE POLICY "Users can manage own reports"
ON public.reports FOR ALL
USING (user_id IS NOT NULL);
```

**D)**
```sql
CREATE POLICY "Users can manage own reports"
ON public.reports FOR INSERT
USING (auth.uid() = user_id);
```

<details>
<summary>答えを見る</summary>

**正解: B**

- `FOR ALL` は SELECT, INSERT, UPDATE, DELETE すべての操作に適用
- `FOR SELECT` は読み取りのみ
- `auth.uid() = user_id` で「自分のデータのみ」を表現

Aは読み取りのみ、Cは全ユーザーのデータにアクセス可能、DはINSERTのみ対象。
</details>

---

### Q6. 管理者が全レポートにアクセスできるポリシーとして正しいのは？

**A)**
```sql
CREATE POLICY "Admins can manage all reports"
ON public.reports FOR ALL
USING (role = 'admin');
```

**B)**
```sql
CREATE POLICY "Admins can manage all reports"
ON public.reports FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

**C)**
```sql
CREATE POLICY "Admins can manage all reports"
ON public.reports FOR ALL
USING (auth.uid() = 'admin');
```

**D)**
```sql
CREATE POLICY "Admins can manage all reports"
ON public.reports FOR ALL
USING (user_id = 'admin');
```

<details>
<summary>答えを見る</summary>

**正解: B**

`reports` テーブルには `role` カラムがないため、`profiles` テーブルを参照してログイン中のユーザーのロールを確認する必要があります。

```sql
EXISTS (
  SELECT 1 FROM public.profiles 
  WHERE id = auth.uid() AND role = 'admin'
)
```

- `auth.uid()` で現在のユーザーIDを取得
- `profiles` テーブルでそのユーザーの `role` を確認
- `role = 'admin'` ならポリシー条件を満たす
</details>

---

### Q7. `profiles` テーブルを作成する際、`auth.users` との関連付けとして正しいのは？

**A)**
```sql
CREATE TABLE public.profiles (
  id SERIAL PRIMARY KEY,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL
);
```

**B)**
```sql
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL
);
```

**C)**
```sql
CREATE TABLE public.profiles (
  user_email TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL
);
```

**D)**
```sql
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  display_name TEXT NOT NULL,
  role TEXT NOT NULL
);
```

<details>
<summary>答えを見る</summary>

**正解: B**

`profiles.id` を `auth.users.id` の外部キーにすることで：
- 1:1 リレーションを明示
- `ON DELETE CASCADE` でユーザー削除時に連動削除
- `auth.uid()` をそのまま `profiles.id` と比較可能

```
auth.users（Supabase管理）
├── id (UUID)
...
    ↓ 1:1 リレーション
public.profiles（自分で管理）
├── id (UUID, auth.usersのid参照)
...
```
</details>

---

## 📚 セクション3: アンチパターン問題

### Q8. 以下のRLSポリシーには問題があります。何が問題でしょうか？

```sql
-- profiles テーブルに設定
CREATE POLICY "Admins can view all profiles"
ON public.profiles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

- A) `FOR SELECT` を `FOR ALL` に変更すべき
- B) `profiles` テーブルのポリシー内で `profiles` 自身を参照すると無限再帰が発生する
- C) `auth.uid()` は `profiles` テーブルでは使用できない
- D) `EXISTS` 句は RLS ポリシーでは使用できない

<details>
<summary>答えを見る</summary>

**正解: B**

`profiles` テーブルのRLSポリシー評価時に `profiles` テーブルを参照すると、その参照にもRLSが適用され、無限ループが発生します。

**解決策:**
- `profiles` テーブルは「自分のプロフィールのみ閲覧可」ポリシーのみを使用
- admin 用のポリシーは `reports` テーブルなど他のテーブルに対してのみ設定
</details>

---

### Q9. 以下の設計のアンチパターンを指摘してください。

「Flutter アプリで RLS を使わず、クエリ実行時に `WHERE user_id = 現在のユーザーID` をアプリ側で付与してフィルタリングする」

- A) 問題ない。RLSより柔軟で高速
- B) クライアントサイドのフィルタリングはバイパス可能でセキュリティホールになる
- C) Supabase では WHERE 句を使えないので動作しない
- D) user_id はサーバー側でしか取得できないので動作しない

<details>
<summary>答えを見る</summary>

**正解: B**

クライアントサイドのフィルタリングは**バイパス可能**です。悪意あるユーザーが API を直接叩けば、全データにアクセスできてしまいます。

**RLSの利点:**
- データベースレベルで強制される
- クライアントの実装に関係なくセキュリティが担保される
- APIを直接叩いてもポリシー外のデータにはアクセスできない
</details>

---

### Q10. `type` カラムを PostgreSQL の ENUM 型にせず `TEXT + CHECK制約` を選択した理由として正しいのは？

```sql
type TEXT NOT NULL CHECK (type IN ('work', 'expense'))
```

- A) PostgreSQL は ENUM 型をサポートしていないから
- B) ENUM 型は後からの値の追加・削除・変更が困難だから
- C) TEXT 型の方がストレージ効率が良いから
- D) RLS ポリシーで ENUM 型は使用できないから

<details>
<summary>答えを見る</summary>

**正解: B**

PostgreSQL の ENUM 型は後からの変更が面倒です：

**ENUM型の課題:**
- 新しい値の追加に `ALTER TYPE ... ADD VALUE` が必要
- 値の削除・変更は非常に困難（場合によってはテーブル再作成が必要）

**TEXT + CHECK制約のメリット:**
- 値の追加は `ALTER TABLE ... DROP CONSTRAINT` + 新しい CHECK 制約追加で対応可能
- より柔軟な運用が可能
</details>

---

### Q11. 以下のユーザー作成手順で問題がある箇所はどれ？

```sql
-- 手順1: profilesにデータを先に追加
INSERT INTO public.profiles (id, display_name, role)
VALUES ('some-uuid', '田中太郎', 'staff');

-- 手順2: その後でDashboardからユーザーを作成
```

- A) 問題ない
- B) UUIDの形式が間違っている
- C) `profiles.id` は `auth.users.id` を外部キー参照しているため、先に `auth.users` にユーザーが存在している必要がある
- D) Dashboardからユーザーを作成できない

<details>
<summary>答えを見る</summary>

**正解: C**

`profiles.id` は `auth.users.id` を外部キー（REFERENCES）として参照しています。そのため：

1. **先に** Dashboard や API で `auth.users` にユーザーを作成
2. **その後で** 作成されたUUIDを使って `profiles` にデータを追加

この順序を守らないと外部キー制約違反でINSERTが失敗します。
</details>

---

### Q12. `month` カラム（'yyyy-MM' 形式）を `reports` テーブルに持つ理由として適切でないのは？

- A) `WHERE month = '2026-01'` はインデックスが効きやすい
- B) 毎回 `EXTRACT(YEAR FROM date)` を書く必要がなくなる
- C) データの正規化のため
- D) Phase 1（スプレッドシート）との互換性を保つため

<details>
<summary>答えを見る</summary>

**正解: C**

`month` カラムは `date` から導出可能な冗長データであり、**正規化に反しています**。しかし以下の実用的な理由から保持しています：

1. **インデックス効率**: 単一カラム検索が高速
2. **クエリ簡略化**: 複雑な日付抽出ロジックが不要
3. **互換性**: 既存ロジックをそのまま移行しやすい

正規化を犠牲にしてパフォーマンスや利便性を優先した設計判断です。
</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 完全に理解している |
| 9-10問 | 👍 概ね理解している。復習推奨箇所あり |
| 6-8問 | 📖 基礎は理解しているが、深い理解が必要 |
| 5問以下 | 📚 ドキュメントを再度読み込むことを推奨 |

---

## 📝 復習用キーワード

- **RLS（Row Level Security）**: 行レベルのアクセス制御
- **auth.uid()**: 現在ログイン中のユーザーIDを取得
- **profiles テーブル**: auth.users のカスタム拡張用
- **Publishable key vs Secret key**: クライアント用 vs サーバー用
- **外部キー制約**: テーブル間の整合性を保証
- **CHECK制約**: カラム値の制限
