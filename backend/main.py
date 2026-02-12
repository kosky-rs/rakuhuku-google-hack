"""Poltan API - メインエントリーポイント"""
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import router


# 環境変数読み込み
load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションのライフサイクル管理"""
    print("Poltan API starting...")

    # Firebase Admin SDK 初期化
    try:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:
            cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
            if cred_path:
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred, {
                    "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", ""),
                })
            else:
                firebase_admin.initialize_app(options={
                    "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", ""),
                })
            print("Firebase Admin SDK initialized successfully")
    except Exception as e:
        print(f"Warning: Firebase initialization failed: {e}")
        print("Some features (Firestore, Storage) may not work.")

    # Vertex AI 初期化
    try:
        import vertexai
        project_id = os.getenv("GCP_PROJECT_ID", "rakufuku-pwa")
        location = os.getenv("VERTEX_AI_LOCATION", "asia-northeast1")
        vertexai.init(project=project_id, location=location)
        print(f"Vertex AI initialized (project={project_id}, location={location})")
    except Exception as e:
        print(f"Warning: Vertex AI initialization failed: {e}")
        print("AI features (outfit diagnosis) may not work.")

    yield
    print("Poltan API shutting down...")


# FastAPIアプリケーション
app = FastAPI(
    title="Poltan API",
    description="毎朝1分で正解のコーディネートを提案するAIスタイリスト",
    version="0.1.0",
    lifespan=lifespan,
)


# CORS設定
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
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
