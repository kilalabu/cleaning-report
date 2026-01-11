# 開発環境セットアップ

## 1. 環境変数の設定

`.env.local.example` を `.env.local` にコピーして、Supabaseの接続情報を設定してください：

```bash
cp .env.local.example .env.local
# .env.local を編集してSupabaseの設定を入力
```

## 2. アプリの起動

環境変数を読み込んでからFlutterを起動：

```bash
# macOS / Linux
source .env.local && cd cleaning_report_app && fvm flutter run -d chrome \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# または、直接指定
cd cleaning_report_app && fvm flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## 3. ビルド

```bash
source .env.local && cd cleaning_report_app && fvm flutter build web \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```
