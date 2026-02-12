#!/bin/bash

# ========================================
# バックエンド起動スクリプト
# ========================================

set -e

echo "========================================="
echo "  Rakufuku Backend Server"
echo "========================================="
echo ""

cd backend

# 仮想環境チェック
if [ ! -d "venv" ]; then
    echo "エラー: 仮想環境が見つかりません"
    echo "先に ./setup_integration_test.sh を実行してください"
    exit 1
fi

# 仮想環境を有効化
echo "仮想環境を有効化中..."
source venv/bin/activate

# .env チェック
if [ ! -f ".env" ]; then
    echo "警告: .env ファイルが見つかりません"
    echo "backend/.env.example をコピーして .env を作成し、APIキーを設定してください"
    exit 1
fi

# サーバー起動
echo "バックエンドサーバーを起動中..."
echo ""
echo "Access URLs:"
echo "  Health Check: http://localhost:8000/api/v1/health"
echo "  Agent Health: http://localhost:8000/api/v1/agent/health"
echo "  API Docs:     http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop"
echo ""

uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
