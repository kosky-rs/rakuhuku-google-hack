#!/bin/bash
set -e

# ==============================================================
# ラクフク デプロイスクリプト
# ==============================================================
# 使い方:
#   1. PROJECT_ID を設定
#   2. ./deploy.sh backend   → Cloud Run にデプロイ
#   3. ./deploy.sh frontend  → Firebase Hosting にデプロイ
#   4. ./deploy.sh all       → 両方デプロイ
# ==============================================================

PROJECT_ID="${GCP_PROJECT_ID:?Error: GCP_PROJECT_ID is not set}"
REGION="asia-northeast1"
BACKEND_IMAGE="asia-northeast1-docker.pkg.dev/${PROJECT_ID}/rakufuku-api/rakufuku:latest"

echo "📋 Project: ${PROJECT_ID}"
echo "📋 Region: ${REGION}"

deploy_backend() {
  echo ""
  echo "🚀 === Backend (Cloud Run) デプロイ ==="

  # Artifact Registry リポジトリ作成（初回のみ）
  gcloud artifacts repositories describe rakufuku-api \
    --project="${PROJECT_ID}" \
    --location="${REGION}" 2>/dev/null || \
  gcloud artifacts repositories create rakufuku-api \
    --project="${PROJECT_ID}" \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Poltan API Docker images"

  # Docker イメージビルド & プッシュ
  echo "🔨 Building Docker image..."
  gcloud builds submit \
    --project="${PROJECT_ID}" \
    --tag "${BACKEND_IMAGE}" \
    backend/

  # Cloud Run デプロイ
  echo "🚀 Deploying to Cloud Run..."
  gcloud run deploy rakufuku-api \
    --project="${PROJECT_ID}" \
    --image "${BACKEND_IMAGE}" \
    --region "${REGION}" \
    --platform managed \
    --allow-unauthenticated \
    --set-env-vars "^##^ENVIRONMENT=production##GCP_PROJECT_ID=${PROJECT_ID}##VERTEX_AI_LOCATION=asia-northeast1##ALLOWED_ORIGINS=https://${PROJECT_ID}.web.app,https://${PROJECT_ID}.firebaseapp.com##FIREBASE_STORAGE_BUCKET=${PROJECT_ID}.appspot.com" \
    --set-secrets "OPENWEATHER_API_KEY=openweather-api-key:latest" \
    --memory 512Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 3 \
    --timeout 60

  # Cloud Run URL を取得
  BACKEND_URL=$(gcloud run services describe rakufuku-api \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --format='value(status.url)')

  echo ""
  echo "✅ Backend deployed: ${BACKEND_URL}"
  echo "   Health check: ${BACKEND_URL}/api/v1/health"
}

deploy_frontend() {
  echo ""
  echo "🚀 === Frontend (Firebase Hosting) デプロイ ==="

  # Cloud Run URL を取得
  BACKEND_URL=$(gcloud run services describe rakufuku-api \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --format='value(status.url)' 2>/dev/null || echo "")

  if [ -z "${BACKEND_URL}" ]; then
    echo "⚠️  Cloud Run URL not found. Deploy backend first or set API_BASE_URL manually."
    echo "   Using placeholder URL..."
    BACKEND_URL="https://rakufuku-api-xxxxx-an.a.run.app"
  fi

  API_BASE_URL="${BACKEND_URL}/api/v1"
  echo "📋 API_BASE_URL: ${API_BASE_URL}"

  # Flutter Web ビルド
  echo "🔨 Building Flutter Web..."
  cd frontend
  flutter build web --release \
    --dart-define="API_BASE_URL=${API_BASE_URL}"
  cd ..

  # Firebase Hosting デプロイ
  echo "🚀 Deploying to Firebase Hosting..."
  firebase deploy --only hosting --project="${PROJECT_ID}"

  echo ""
  echo "✅ Frontend deployed: https://${PROJECT_ID}.web.app"
}

# コマンド分岐
case "${1}" in
  backend)
    deploy_backend
    ;;
  frontend)
    deploy_frontend
    ;;
  all)
    deploy_backend
    deploy_frontend
    ;;
  *)
    echo "Usage: ./deploy.sh [backend|frontend|all]"
    echo ""
    echo "Environment variables:"
    echo "  GCP_PROJECT_ID  - Google Cloud Project ID (required)"
    exit 1
    ;;
esac

echo ""
echo "🎉 Deploy complete!"
