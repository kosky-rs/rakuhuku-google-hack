#!/bin/bash

# ========================================
# フロントエンド起動スクリプト
# ========================================

set -e

echo "========================================="
echo "  Rakufuku Frontend (Web)"
echo "========================================="
echo ""

cd frontend

# 依存関係チェック
if [ ! -d ".dart_tool" ]; then
    echo "警告: 依存関係が見つかりません"
    echo "先に flutter pub get を実行してください"
    exit 1
fi

# Flutter Web起動
echo "Flutterアプリを起動中..."
echo ""
echo "Access URL: http://localhost:5000"
echo ""
echo "Press Ctrl+C to stop"
echo ""

flutter run -d chrome --web-port 5000
