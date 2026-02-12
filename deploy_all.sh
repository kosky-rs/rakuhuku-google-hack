#!/bin/bash

# ========================================
# フルスタックデプロイスクリプト
# ========================================

set -e

echo "========================================="
echo "  Rakufuku - Full Stack Deploy"
echo "========================================="
echo ""

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========================================
# デプロイ順序の確認
# ========================================
echo "デプロイ順序:"
echo "  1. バックエンド (Cloud Run)"
echo "  2. フロントエンド (Firebase Hosting)"
echo ""

read -p "続行しますか？ (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "デプロイをキャンセルしました"
    exit 0
fi

# ========================================
# 1. バックエンドデプロイ
# ========================================
echo ""
echo "========================================="
echo "  Step 1: バックエンドデプロイ"
echo "========================================="
echo ""

./deploy_backend.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ バックエンドデプロイに失敗しました${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ バックエンドデプロイ完了${NC}"
echo ""

# ========================================
# 2. フロントエンドデプロイ
# ========================================
echo ""
echo "========================================="
echo "  Step 2: フロントエンドデプロイ"
echo "========================================="
echo ""

./deploy_frontend.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ フロントエンドデプロイに失敗しました${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ フロントエンドデプロイ完了${NC}"
echo ""

# ========================================
# 完了
# ========================================
PROJECT_ID="rakufuku-pwa"
REGION="asia-northeast1"
SERVICE_NAME="rakufuku-api"

BACKEND_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)' 2>/dev/null || echo "https://rakufuku-api-1024882237054.asia-northeast1.run.app")
FRONTEND_URL="https://${PROJECT_ID}.web.app"

echo "========================================="
echo -e "${GREEN}✓ フルスタックデプロイ完了！${NC}"
echo "========================================="
echo ""
echo -e "${BLUE}Backend URL:${NC}"
echo "  $BACKEND_URL"
echo "  Health: $BACKEND_URL/api/v1/health"
echo "  Docs:   $BACKEND_URL/docs"
echo ""
echo -e "${BLUE}Frontend URL:${NC}"
echo "  $FRONTEND_URL"
echo ""
echo -e "${YELLOW}次のステップ:${NC}"
echo "  1. Cloud Runコンソールで環境変数を設定"
echo "  2. フロントエンドにアクセスして動作確認"
echo "  3. Firebase Authenticationの設定確認"
echo ""
