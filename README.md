# Rakufuku（ラクフク）

**毎朝の服選びを、4人のAIスタイリストが解決する** マルチエージェント型コーディネート提案アプリ

> 「楽」+「服」= 服選びを楽に

---

## 概要

Rakufukuは、天気・予定・手持ちの服・好みの4変数を同時に考慮し、最適なコーディネートを毎朝提案するAIアプリです。Google Cloud AI技術を全面活用し、4つの専門スタイルエージェントが並列でコーディネートを生成するAgentic AIアーキテクチャを採用しています。

### 主な機能

- **日次コーデ提案** -- 天気・カレンダー・クローゼット・嗜好を自動統合し、5パターン以上のコーデを提案
- **マネキン画像生成** -- Imagen 4 Fastによるフォトリアリスティックな着用イメージ
- **コーデ診断** -- 全身写真をアップロードしてAIがスコアリング・改善提案
- **スワイプ学習** -- いいね/パスのスワイプだけでAIが好みを自動学習（EMA）
- **クローゼット管理** -- 写真1枚でCloud Visionが自動認識・一括登録
- **購入リンク生成** -- 不足アイテムを楽天/Amazon/ZOZOTOWNで検索

---

## アーキテクチャ

```
Flutter Web (Firebase Hosting)
    │
    ▼
FastAPI Backend (Cloud Run)
    │
    ├── Integration Helper ─┬── Weather Tool (OpenWeather API)
    │                       ├── Calendar Tool (Google Calendar API)
    │                       └── Preference Learner (Firestore)
    │
    ├── Orchestrator ───────┬── Casual Agent ────┐
    │                       ├── Formal Agent ────┤
    │                       ├── Balanced Agent ──┤── Gemini 2.0 Flash
    │                       └── Unique Agent ────┘
    │
    ├── Imagen 4 Fast (マネキン画像生成) → Cloud Storage
    │
    └── Outfit Analyzer ────┬── Gemini 2.5 Flash (コーデ評価)
                            └── Cloud Vision API (物体検出)
```

### マルチエージェント構成

| エージェント | 役割 | 得意なTPO |
|---|---|---|
| **Casual Agent** | リラックスした日常スタイル | 休日・友人との食事 |
| **Formal Agent** | プロフェッショナルな装い | 会議・商談・セミナー |
| **Balanced Agent** | 万能なスマートカジュアル | オフィスカジュアル |
| **Unique Agent** | 個性的なトレンドスタイル | ファッション感度高めのシーン |

4エージェントが`asyncio.gather()`で並列実行し、オーケストレーターがTPO適合度・嗜好一致度でスコアリング。各エージェントから最低1着を確保した上で、上位5着以上を選出します。

---

## 技術スタック

### バックエンド

| 技術 | 用途 |
|---|---|
| Python 3.13+ / FastAPI | APIサーバー |
| Gemini 2.0 Flash (Vertex AI) | コーディネート生成（JSON構造化出力） |
| Gemini 2.5 Flash (Vertex AI) | コーデ診断（マルチモーダル入力） |
| Imagen 4 Fast (Vertex AI) | マネキン画像生成 |
| Cloud Vision API | 服飾アイテム検出 |
| Google ADK | エージェント設定共有 |
| Cloud Firestore | ユーザーデータ・キャッシュ・履歴 |
| Cloud Storage | 生成画像の保存・配信 |
| Cloud Run | コンテナ実行環境 |

### フロントエンド

| 技術 | 用途 |
|---|---|
| Flutter Web | SPA |
| Riverpod | 状態管理 |
| Dio | HTTPクライアント |
| flutter_card_swiper | スワイプUI |
| Firebase Auth | 認証 |
| Firebase Hosting | CDN配信 |

### 外部API

| API | 用途 |
|---|---|
| OpenWeather API | 天気・気温取得 |
| Google Calendar API | 予定取得・TPO自動判定 |
| 楽天市場 API | 商品検索・購入リンク |

---

## プロジェクト構成

```
.
├── backend/
│   ├── main.py                     # FastAPIエントリーポイント
│   ├── api/routes.py               # APIルーティング
│   ├── agent/
│   │   ├── adk_config.py           # ADK設定（モデル・リージョン）
│   │   ├── style_agents.py         # 4つの専門スタイルエージェント
│   │   ├── orchestrator.py         # オーケストレーター（並列実行・ランキング）
│   │   ├── integration_helper.py   # コンテキスト統合ヘルパー
│   │   └── tools/
│   │       ├── gemini_outfit_composer.py  # Gemini 2.0 Flashコーデ生成
│   │       ├── nano_banana.py             # Imagen 4 Fast画像生成
│   │       ├── outfit_analyzer.py         # コーデ診断パイプライン
│   │       ├── weather.py                 # 天気取得
│   │       ├── calendar.py                # カレンダー・TPO判定
│   │       ├── preference_learner.py      # 嗜好学習（EMA）
│   │       ├── closet.py                  # クローゼット管理
│   │       ├── recommendation_cache.py    # 日次キャッシュ・Tier管理
│   │       ├── rakuten_api.py             # 楽天API
│   │       └── product_search.py          # 商品検索
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/                 # テーマ・ルーティング
│   │   ├── core/
│   │   │   ├── api/api_client.dart
│   │   │   └── models/            # データモデル
│   │   ├── features/
│   │   │   ├── home/              # 日次コーデ提案・スワイプUI
│   │   │   ├── closet/            # クローゼット管理
│   │   │   ├── history/           # コーデ履歴
│   │   │   └── settings/          # 設定
│   │   └── shared/widgets/
│   └── pubspec.yaml
├── docs/                           # 設計ドキュメント
├── firebase.json
├── firestore.rules
└── deploy.sh                       # デプロイスクリプト
```

---

## セットアップ

### 前提条件

- Python 3.13+
- Flutter SDK 3.2.0+
- Google Cloud プロジェクト（Vertex AI, Firestore, Cloud Storage有効化済み）
- Firebase プロジェクト

### 1. 依存関係インストール

```bash
# バックエンド
cd backend && python -m venv venv && source venv/bin/activate && pip install -r requirements.txt

# フロントエンド
cd frontend && flutter pub get
```

### 2. 環境変数の設定

`backend/.env` を作成し、以下を設定:

```bash
OPENWEATHER_API_KEY=<your_key>
GOOGLE_API_KEY=<your_key>
RAKUTEN_APPLICATION_ID=<your_app_id>
RAKUTEN_AFFILIATE_ID=<your_affiliate_id>
FIREBASE_STORAGE_BUCKET=<your_bucket>
```

### 3. バックエンド起動

```bash
./run_backend.sh
```

確認:
- http://localhost:8000/api/v1/health → `{"status": "healthy"}`
- http://localhost:8000/api/v1/agent/health → 4エージェントステータス
- http://localhost:8000/docs → Swagger UI

### 4. フロントエンド起動

```bash
./run_frontend.sh
```

確認: http://localhost:5000

---

## デプロイ

```bash
# バックエンド（Cloud Run）
./deploy.sh backend

# フロントエンド（Firebase Hosting）
./deploy.sh frontend

# 両方
./deploy.sh all
```

`GCP_PROJECT_ID` 環境変数の設定が必要です。

---

## API

| メソッド | エンドポイント | 機能 |
|---|---|---|
| `POST` | `/outfit/daily` | 日次コーデ提案（5パターン以上） |
| `POST` | `/outfit/regenerate` | コーデ強制再生成 |
| `POST` | `/outfit/diagnose` | 全身写真コーデ診断 |
| `POST` | `/outfit/swipe` | スワイプアクション記録 |
| `POST` | `/outfit/history` | コーデ履歴保存 |
| `GET` | `/outfit/history` | コーデ履歴取得 |
| `GET` | `/closet` | クローゼットアイテム一覧 |
| `POST` | `/closet/items` | アイテム追加 |
| `POST` | `/closet/items/bulk` | アイテム一括登録 |
| `DELETE` | `/closet/items/{item_id}` | アイテム削除 |
| `GET` | `/weather` | 天気情報取得 |
| `GET` | `/calendar` | カレンダー・TPO取得 |
| `GET` | `/health` | ヘルスチェック |
| `GET` | `/agent/health` | エージェントヘルスチェック |

全エンドポイントのベースパス: `/api/v1`

---

## レジリエンス設計

全コンポーネントに独立したフォールバックを実装しています。

| コンポーネント | フォールバック |
|---|---|
| 天気取得 | デフォルト値（20℃・晴れ） |
| カレンダー | casual TPO |
| 嗜好プロファイル | 全スタイル50点の初期値 |
| コーデ生成（Gemini） | ルールベースの決定論的選択 |
| 画像生成（Imagen） | フロントエンドのプレースホルダー |
| 物体検出（Cloud Vision） | Gemini 2.5 Flashによる推測 |
| 商品検索 | アフィリエイトリンク生成 |
| エージェント障害 | 成功したエージェントの結果のみ使用 |

日次キャッシュ（Firestore）により同日の再アクセスはキャッシュから即時返却し、APIコストを最小化しています。

---

## ライセンス

Private
