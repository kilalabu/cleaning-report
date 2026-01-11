-- ============================================
-- Supabase テーブル・RLS セットアップスクリプト
-- プロジェクト: cleaning-report (Phase 2)
-- ============================================

-- ============================================
-- 1. profiles テーブル作成
-- ============================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- インデックス（roleでの検索を高速化）
CREATE INDEX idx_profiles_role ON public.profiles(role);

-- RLS有効化
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. reports テーブル作成
-- ============================================
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

-- RLS有効化
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 3. RLS ポリシー: profiles
-- ============================================

-- 自分のプロフィールを閲覧可能
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

-- 自分のプロフィールを更新可能
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id);

-- ============================================
-- 4. RLS ポリシー: reports
-- ============================================

-- 自分のレポートに対して全操作可能
CREATE POLICY "Users can manage own reports"
ON public.reports FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 管理者は全レポートに対して全操作可能
CREATE POLICY "Admins can manage all reports"
ON public.reports FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 5. updated_at 自動更新トリガー
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reports_updated_at
  BEFORE UPDATE ON public.reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- セットアップ完了確認
-- ============================================
-- 以下のクエリでテーブルが作成されたことを確認:
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
