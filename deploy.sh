#!/bin/bash

# .env.localから環境変数を読み込む
set -a
source cleaning_report_app/.env.local
set +a

cd cleaning_report_app
fvm flutter build web --release \
  --base-href "/cleaning-report/" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
cd ..
rm -rf docs/*
cp -r cleaning_report_app/build/web/* docs/
touch docs/.nojekyll
git add .
git commit -m "Deploy: $(date)"
git push
