#!/bin/bash

# ========================================
# 統合テスト環境セットアップスクリプト
# ========================================

set -e  # Exit on error

echo "========================================="
echo "  統合テスト環境セットアップ"
echo "========================================="
echo ""

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ========================================
# 1. 依存関係チェック
# ========================================
echo "1. 依存関係チェック中..."

# Python3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python3 が見つかりません${NC}"
    echo "  インストールしてください: https://www.python.org/downloads/"
    exit 1
else
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ ${PYTHON_VERSION}${NC}"
fi

# Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}✗ Flutter が見つかりません${NC}"
    echo "  インストールしてください: https://flutter.dev/docs/get-started/install"
    exit 1
else
    FLUTTER_VERSION=$(flutter --version 2>&1 | head -1)
    echo -e "${GREEN}✓ ${FLUTTER_VERSION}${NC}"
fi

echo ""

# ========================================
# 2. .env ファイル作成
# ========================================
echo "2. .env ファイルの作成"

if [ -f "backend/.env" ]; then
    echo -e "${YELLOW}⚠ backend/.env は既に存在します${NC}"
    read -p "上書きしますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "スキップします"
    else
        rm backend/.env
        cp backend/.env.example backend/.env
        echo -e "${GREEN}✓ backend/.env を作成しました${NC}"
        echo -e "${YELLOW}⚠ backend/.env を編集して、APIキーを設定してください${NC}"
    fi
else
    cp backend/.env.example backend/.env
    echo -e "${GREEN}✓ backend/.env を作成しました${NC}"
    echo -e "${YELLOW}⚠ backend/.env を編集して、APIキーを設定してください${NC}"
fi

echo ""
echo "必要なAPIキー:"
echo "  - OPENWEATHER_API_KEY (https://openweathermap.org/api)"
echo "  - GOOGLE_API_KEY (https://console.cloud.google.com/)"
echo "  - RAKUTEN_APPLICATION_ID (https://webservice.rakuten.co.jp/)"
echo "  - RAKUTEN_AFFILIATE_ID (https://affiliate.rakuten.co.jp/)"
echo ""

# ========================================
# 3. バックエンド依存関係インストール
# ========================================
echo "3. バックエンド依存関係のインストール"

cd backend

if [ ! -d "venv" ]; then
    echo "仮想環境を作成中..."
    python3 -m venv venv
    echo -e "${GREEN}✓ 仮想環境を作成しました${NC}"
fi

echo "仮想環境を有効化中..."
source venv/bin/activate

echo "依存関係をインストール中..."
pip3 install -r requirements.txt > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ バックエンド依存関係をインストールしました${NC}"
else
    echo -e "${RED}✗ バックエンド依存関係のインストールに失敗しました${NC}"
    exit 1
fi

cd ..

echo ""

# ========================================
# 4. フロントエンド依存関係インストール
# ========================================
echo "4. フロントエンド依存関係のインストール"

cd frontend

flutter pub get > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ フロントエンド依存関係をインストールしました${NC}"
else
    echo -e "${RED}✗ フロントエンド依存関係のインストールに失敗しました${NC}"
    exit 1
fi

cd ..

echo ""

# ========================================
# 5. セットアップ完了
# ========================================
echo "========================================="
echo -e "${GREEN}✓ セットアップ完了！${NC}"
echo "========================================="
echo ""
echo "次のステップ:"
echo "  1. backend/.env を編集してAPIキーを設定"
echo "  2. Firebase設定ファイルを配置"
echo "  3. バックエンド起動: ./run_backend.sh"
echo "  4. フロントエンド起動: ./run_frontend.sh"
echo "  5. 統合テスト実行: ./run_integration_test.sh"
echo ""
