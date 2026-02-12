#!/bin/bash

# ========================================
# バックエンド Cloud Run デプロイスクリプト
# ========================================

set -e

echo "========================================="
echo "  Rakufuku Backend - Cloud Run Deploy"
echo "========================================="
echo ""

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========================================
# 設定
# ========================================
PROJECT_ID="rakufuku-pwa"
REGION="asia-northeast1"
SERVICE_NAME="rakufuku-api"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo -e "${BLUE}プロジェクト:${NC} $PROJECT_ID"
echo -e "${BLUE}リージョン:${NC} $REGION"
echo -e "${BLUE}サービス名:${NC} $SERVICE_NAME"
echo ""

# ========================================
# 1. gcloud CLIチェック
# ========================================
echo "1. gcloud CLI確認中..."
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}✗ gcloud CLIが見つかりません${NC}"
    echo "  インストールしてください: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
echo -e "${GREEN}✓ gcloud CLI確認完了${NC}"
echo ""

# ========================================
# 2. プロジェクト設定
# ========================================
echo "2. Google Cloudプロジェクト設定中..."
gcloud config set project $PROJECT_ID
echo -e "${GREEN}✓ プロジェクト設定完了${NC}"
echo ""

# ========================================
# 3. 必要なAPIを有効化
# ========================================
echo "3. 必要なAPIを有効化中..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    containerregistry.googleapis.com \
    --quiet
echo -e "${GREEN}✓ API有効化完了${NC}"
echo ""

# ========================================
# 4. Dockerイメージビルド
# ========================================
echo "4. Dockerイメージをビルド中..."
cd backend

gcloud builds submit \
    --tag $IMAGE_NAME \
    --quiet

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ビルドに失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ イメージビルド完了${NC}"
echo ""

cd ..

# ========================================
# 5. Cloud Runにデプロイ
# ========================================
echo "5. Cloud Runにデプロイ中..."

# 環境変数を設定（Secret Managerから取得する場合はコメントアウトを外す）
# PORT は Cloud Run により自動設定されるため、--set-env-vars で指定しない
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --memory 2Gi \
    --cpu 2 \
    --timeout 300 \
    --min-instances 0 \
    --max-instances 10 \
    --quiet

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ デプロイに失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ デプロイ完了${NC}"
echo ""

# ========================================
# 6. デプロイ情報取得
# ========================================
echo "6. デプロイ情報を取得中..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')

echo ""
echo "========================================="
echo -e "${GREEN}✓ デプロイ成功！${NC}"
echo "========================================="
echo ""
echo -e "${BLUE}Service URL:${NC}"
echo "  $SERVICE_URL"
echo ""
echo -e "${BLUE}Health Check:${NC}"
echo "  curl $SERVICE_URL/api/v1/health"
echo ""
echo -e "${BLUE}Agent Health:${NC}"
echo "  curl $SERVICE_URL/api/v1/agent/health"
echo ""
echo -e "${BLUE}API Docs:${NC}"
echo "  $SERVICE_URL/docs"
echo ""

# ========================================
# 7. 環境変数設定の注意
# ========================================
echo -e "${YELLOW}⚠ 重要: 環境変数の設定${NC}"
echo ""
echo "以下の環境変数をCloud Runコンソールで設定してください:"
echo "https://console.cloud.google.com/run/detail/${REGION}/${SERVICE_NAME}/variables?project=${PROJECT_ID}"
echo ""
echo "必要な環境変数:"
echo "  - OPENWEATHER_API_KEY"
echo "  - GOOGLE_API_KEY"
echo "  - RAKUTEN_APPLICATION_ID"
echo "  - RAKUTEN_AFFILIATE_ID"
echo "  - FIREBASE_STORAGE_BUCKET"
echo ""
echo "または Secret Manager を使用する場合:"
echo "  gcloud secrets create OPENWEATHER_API_KEY --data-file=- < <your_key>"
echo "  gcloud run services update $SERVICE_NAME \\"
echo "    --update-secrets=OPENWEATHER_API_KEY=OPENWEATHER_API_KEY:latest \\"
echo "    --region $REGION"
echo ""

# ========================================
# 8. ヘルスチェック
# ========================================
echo -e "${BLUE}ヘルスチェックを実行中...${NC}"
sleep 5
HEALTH_STATUS=$(curl -s $SERVICE_URL/api/v1/health | grep -o '"status":"healthy"' || echo "")

if [ -n "$HEALTH_STATUS" ]; then
    echo -e "${GREEN}✓ ヘルスチェック成功${NC}"
else
    echo -e "${YELLOW}⚠ ヘルスチェックに失敗しました（環境変数が未設定の可能性）${NC}"
fi

echo ""
echo "デプロイが完了しました！"
