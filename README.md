# かんたん清掃報告システム (Flutter Web + GAS API版)

## 構成
- **Frontend**: Flutter Web (`cleaning_report_app/`)
- **Backend API**: Google Apps Script (`src/Code.js`)
- **Database**: Google Spreadsheet

## セットアップ手順

### 1. GAS API のデプロイ
1. Google スプレッドシートを新規作成
2. **拡張機能 > Apps Script** を開く
3. `src/Code.js` の内容を `Code.gs` に貼り付け
4. `initialSetup` 関数を実行（シートを自動作成）
5. **デプロイ > 新しいデプロイ** > **ウェブアプリ**で公開
   - 次のユーザーとして実行: **自分**
   - アクセス: **全員**
6. 発行された **Web App URL** をコピー

### 2. Flutter アプリの設定
1. `cleaning_report_app/lib/core/api/gas_api_client.dart` を開く
2. `baseUrl` を上記でコピーしたURLに置き換え:
   ```dart
   static const String baseUrl = 'https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec';
   ```

### 3. ローカルで動作確認

#### 開発サーバーで起動（ホットリロード有効）
```bash
cd cleaning_report_app
fvm flutter run -d chrome
```

#### ビルドして静的サーバーで確認
```bash
# ビルド
cd cleaning_report_app
fvm flutter build web --release

# 静的サーバーで起動（Python使用）
cd build/web
python3 -m http.server 8000
```
→ ブラウザで `http://localhost:8000` を開く

ビルド成果物: `build/web/`

### 4. ホスティング (GitHub Pages)

#### 4-1. GitHubリポジトリを作成
1. [github.com](https://github.com) で新規リポジトリを作成
2. リポジトリ名を入力（例: `cleaning-report`）
3. **Public** を選択
4. 「Create repository」をクリック

#### 4-2. ビルド（base-href指定）
```bash
cd cleaning_report_app
fvm flutter build web --release --base-href "/cleaning-report/"
```
> ⚠️ `--base-href` はリポジトリ名に合わせて `/リポジトリ名/` の形式で指定

#### 4-3. リポジトリにプッシュ
```bash
cd /Users/kuwa/Develop/studio/cleaning-report

# docsフォルダにビルド成果物をコピー
mkdir -p docs
cp -r cleaning_report_app/build/web/* docs/

# Jekyll処理を無効化（重要！）
touch docs/.nojekyll

# git初期化
git init
git remote add origin https://github.com/kilalabu/cleaning-report.git

# コミット & プッシュ
git add .
git commit -m "Initial commit with Flutter Web app"
git branch -M main
git push -u origin main
```

#### 4-4. GitHub Pagesを有効化
1. GitHubリポジトリの **Settings** タブ
2. 左メニューの **Pages** をクリック
3. **Source** で:
   - Branch: `main`
   - Folder: `/docs`
4. **Save** をクリック
5. 数分後、公開URL（`https://kilalabu.github.io/cleaning-report/`）でアクセス可能

---

## 更新・デプロイ手順

UIを更新してGitHub Pagesに反映する手順です。

### 手動デプロイ

1. コードを編集: `cleaning_report_app/lib/features/` 配下のDartファイルを編集
2. リビルド:
   ```bash
   cd cleaning_report_app
   fvm flutter build web --release --base-href "/cleaning-report/"
   ```
3. docsフォルダを更新:
   ```bash
   cd ..
   rm -rf docs/*
   cp -r cleaning_report_app/build/web/* docs/
   touch docs/.nojekyll
   ```
4. Git commit & push:
   ```bash
   git add .
   git commit -m "Update UI"
   git push
   ```

### 自動デプロイスクリプト（推奨）

`deploy.sh` を実行:
```bash
./deploy.sh
```

---

## 機能
- PIN認証（4桁）
- 清掃報告（通常/追加/緊急）
- 立替費用報告
- 履歴表示・削除
- 請求書PDF発行

## 使用ライブラリ
- `flutter_riverpod`, `hooks_riverpod`, `flutter_hooks`
- `go_router`, `http`, `google_fonts`
