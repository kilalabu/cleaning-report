#!/bin/bash
# Ktor API接続モードで起動

# .env.localがあれば読み込む
if [ -f .env.local ]; then
  source .env.local
fi

export USE_KTOR_API=true
export KTOR_API_URL=${KTOR_API_URL:-http://localhost:8080}

fvm flutter run -d chrome \
  --dart-define=USE_KTOR_API=true \
  --dart-define=KTOR_API_URL=$KTOR_API_URL \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
