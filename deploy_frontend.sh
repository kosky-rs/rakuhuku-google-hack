#!/bin/bash

# ========================================
# フロントエンド Firebase Hosting デプロイスクリプト
# ========================================

set -e

echo "========================================="
echo "  Rakufuku Frontend - Firebase Deploy"
echo "========================================="
echo ""

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========================================
# 1. Firebase CLIチェック
# ========================================
echo "1. Firebase CLI確認中..."
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}✗ Firebase CLIが見つかりません${NC}"
    echo "  インストールしてください: npm install -g firebase-tools"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI確認完了${NC}"
echo ""

# ========================================
# 2. Flutterビルド
# ========================================
echo "2. Flutter Webビルドを実行中..."
cd frontend

flutter build web --release

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ビルドに失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ビルド完了${NC}"
echo ""

cd ..

# ========================================
# 3. Firebase Hostingにデプロイ
# ========================================
echo "3. Firebase Hostingにデプロイ中..."

firebase deploy --only hosting

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ デプロイに失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ デプロイ完了${NC}"
echo ""

# ========================================
# 4. デプロイ情報取得
# ========================================
PROJECT_ID="rakufuku-pwa"
HOSTING_URL="https://${PROJECT_ID}.web.app"

echo "========================================="
echo -e "${GREEN}✓ デプロイ成功！${NC}"
echo "========================================="
echo ""
echo -e "${BLUE}Hosting URL:${NC}"
echo "  $HOSTING_URL"
echo ""
echo -e "${BLUE}Firebase Console:${NC}"
echo "  https://console.firebase.google.com/project/${PROJECT_ID}/hosting"
echo ""

echo "デプロイが完了しました！"
