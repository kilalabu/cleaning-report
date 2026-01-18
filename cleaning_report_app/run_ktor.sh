#!/bin/bash
# Ktor API接続モードで起動
# 使い方: ./run_ktor.sh [local|cloud]
# local: ローカルのKtorサーバーに接続 (デフォルト)
# cloud: Cloud RunにデプロイされたKtorサーバーに接続

# .env.localがあれば読み込む
if [ -f .env.local ]; then
  source .env.local
fi

# 接続先の設定
MODE=${1:-local}

if [ "$MODE" = "cloud" ]; then
  # Cloud Run URL
  KTOR_API_URL="https://cleaning-report-api-243254208495.asia-northeast1.run.app"
  echo "🌐 Cloud Runに接続します: $KTOR_API_URL"
else
  # ローカルURL
  KTOR_API_URL=${KTOR_API_URL:-http://localhost:8080}
  echo "🏠 ローカルサーバーに接続します: $KTOR_API_URL"
fi

export USE_KTOR_API=true
export KTOR_API_URL=$KTOR_API_URL

fvm flutter run -d chrome \
  --dart-define=USE_KTOR_API=true \
  --dart-define=KTOR_API_URL=$KTOR_API_URL \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
