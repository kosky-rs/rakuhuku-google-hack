"""Poltan API - メインエントリーポイント"""
import os
import sys
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# MOCK: モックモジュールをパスに追加 - 本番リリース前に削除必須
# MOCK: これによりbackend/mock/からインポートが可能になる
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # MOCK: パス設定

from api.routes import router


# 環境変数読み込み
load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションのライフサイクル管理"""
    # 起動時の処理
    print("🚀 Poltan API starting...")

    # MOCK: モックモード警告表示 - 本番リリース前に削除必須
    from mock import is_mock_mode  # MOCK: インポート
    if is_mock_mode():  # MOCK: モードチェック
        print("=" * 60)  # MOCK: 警告表示
        print("⚠️  MOCK MODE ENABLED - DO NOT USE IN PRODUCTION")  # MOCK: 警告表示
        print("   Set MOCK_MODE=false for production deployment")  # MOCK: 警告表示
        print("=" * 60)  # MOCK: 警告表示
    # MOCK: ここまでモック警告処理

    yield
    # 終了時の処理
    print("👋 Poltan API shutting down...")


# FastAPIアプリケーション
app = FastAPI(
    title="Poltan API",
    description="毎朝1分で正解のコーディネートを提案するAIスタイリスト",
    version="0.1.0",
    lifespan=lifespan,
)


# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切に制限する
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ルーターを登録
app.include_router(router, prefix="/api/v1")


# ルートエンドポイント
@app.get("/")
async def root():
    return {
        "message": "Welcome to Poltan API",
        "docs": "/docs",
        "health": "/api/v1/health",
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
