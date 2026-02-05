# API設計書

## 1. 概要

ラクフク APIは、コーディネート提案機能を提供するRESTful APIです。

### 1.1 基本情報

| 項目 | 値 |
|------|-----|
| Base URL | `https://api.rakufuku.app/api/v1` |
| Protocol | HTTPS |
| Format | JSON |
| Authentication | Bearer Token (Firebase Auth) |

### 1.2 共通ヘッダー

```http
Content-Type: application/json
Authorization: Bearer <firebase_id_token>
```

### 1.3 共通レスポンス形式

**成功時**
```json
{
  "data": { ... },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2024-01-15T09:00:00Z"
  }
}
```

**エラー時**
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "details": { ... }
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2024-01-15T09:00:00Z"
  }
}
```

---

## 2. エンドポイント一覧

| メソッド | パス | 説明 | 認証 |
|---------|------|------|------|
| GET | `/health` | ヘルスチェック | 不要 |
| POST | `/outfit/recommend` | コーディネート提案 | 必要 |
| GET | `/closet` | クローゼット一覧 | 必要 |
| GET | `/closet/categories` | カテゴリ別集計 | 必要 |
| POST | `/closet/items` | アイテム追加 | 必要 |
| PUT | `/closet/items/{id}` | アイテム更新 | 必要 |
| DELETE | `/closet/items/{id}` | アイテム削除 | 必要 |
| GET | `/weather` | 天気情報取得 | 必要 |
| GET | `/calendar` | カレンダー・TPO取得 | 必要 |
| POST | `/feedback` | フィードバック送信 | 必要 |

---

## 3. エンドポイント詳細

### 3.1 ヘルスチェック

**GET /health**

```http
GET /api/v1/health
```

**Response 200**
```json
{
  "status": "healthy",
  "service": "rakufuku-api",
  "version": "0.1.0"
}
```

---

### 3.2 コーディネート提案

**POST /outfit/recommend**

最適なコーディネートを提案します。

**Request**
```json
{
  "target_date": "2024-01-15",
  "latitude": 35.6762,
  "longitude": 139.6503,
  "preferences": {
    "style_mood": "professional",
    "exclude_items": ["item_id_1", "item_id_2"]
  }
}
```

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| target_date | string | No | 対象日付（デフォルト: 今日） |
| latitude | number | No | 緯度（デフォルト: 東京） |
| longitude | number | No | 経度（デフォルト: 東京） |
| preferences.style_mood | string | No | スタイルの雰囲気 |
| preferences.exclude_items | array | No | 除外するアイテムID |

**Response 200**
```json
{
  "data": {
    "weather": {
      "weather": "晴れ",
      "temperature": 18,
      "feels_like": 16,
      "humidity": 45,
      "precipitation_probability": 10,
      "description": "晴れ、18°C、降水確率10%"
    },
    "tpo": {
      "formality_required": "formal",
      "main_event": "クライアントMTG",
      "recommendation": "商談があるため、フォーマルな服装を推奨"
    },
    "recommendation": {
      "items": [
        {
          "id": "1",
          "name": "ネイビージャケット",
          "category": "outerwear",
          "color": "navy",
          "image_url": "https://..."
        },
        {
          "id": "2",
          "name": "白シャツ",
          "category": "tops",
          "color": "white",
          "image_url": "https://..."
        },
        {
          "id": "3",
          "name": "グレースラックス",
          "category": "bottoms",
          "color": "gray",
          "image_url": "https://..."
        },
        {
          "id": "4",
          "name": "黒革靴",
          "category": "shoes",
          "color": "black",
          "image_url": "https://..."
        }
      ],
      "score": 92,
      "feedback": "ネイビージャケットと白シャツの組み合わせは相性抜群。クライアントMTGにぴったりのスタイルです。"
    },
    "alternatives": [
      {
        "items": [...],
        "description": "ライトブルーシャツを使った爽やかバリエーション"
      },
      {
        "items": [...],
        "description": "チノパンでカジュアルダウン"
      }
    ]
  }
}
```

---

### 3.3 クローゼット一覧

**GET /closet**

ユーザーのクローゼット内のアイテム一覧を取得します。

**Query Parameters**

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| category | string | No | カテゴリでフィルタ |
| season | string | No | 季節でフィルタ |
| formality | string | No | フォーマル度でフィルタ |
| limit | number | No | 取得件数（デフォルト: 50） |
| offset | number | No | オフセット（デフォルト: 0） |

**Response 200**
```json
{
  "data": {
    "items": [
      {
        "id": "1",
        "name": "ネイビージャケット",
        "category": "outerwear",
        "color": "navy",
        "season": ["spring", "autumn", "winter"],
        "formality": "formal",
        "image_url": "https://...",
        "tags": ["定番", "商談向け"],
        "created_at": "2024-01-10T10:00:00Z",
        "updated_at": "2024-01-10T10:00:00Z"
      }
    ],
    "categories": {
      "tops": 12,
      "bottoms": 8,
      "outerwear": 5,
      "shoes": 4,
      "accessories": 3
    },
    "total_count": 32
  }
}
```

---

### 3.4 カテゴリ別集計

**GET /closet/categories**

カテゴリ別のアイテム数を取得します。

**Response 200**
```json
{
  "data": {
    "categories": {
      "tops": 12,
      "bottoms": 8,
      "outerwear": 5,
      "shoes": 4,
      "accessories": 3
    }
  }
}
```

---

### 3.5 アイテム追加

**POST /closet/items**

クローゼットに新しいアイテムを追加します。

**Request**
```json
{
  "name": "白シャツ",
  "category": "tops",
  "color": "white",
  "season": ["spring", "summer", "autumn", "winter"],
  "formality": "formal",
  "image_url": "https://storage.googleapis.com/...",
  "tags": ["清潔感", "万能"]
}
```

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| name | string | Yes | アイテム名 |
| category | string | Yes | カテゴリ |
| color | string | Yes | 色 |
| season | array | Yes | 着用可能な季節 |
| formality | string | Yes | フォーマル度 |
| image_url | string | No | 画像URL |
| tags | array | No | タグ |

**Response 201**
```json
{
  "data": {
    "id": "new_item_id",
    "name": "白シャツ",
    "category": "tops",
    "color": "white",
    "season": ["spring", "summer", "autumn", "winter"],
    "formality": "formal",
    "image_url": "https://...",
    "tags": ["清潔感", "万能"],
    "created_at": "2024-01-15T09:00:00Z"
  }
}
```

---

### 3.6 アイテム更新

**PUT /closet/items/{id}**

既存のアイテム情報を更新します。

**Request**
```json
{
  "name": "白シャツ（お気に入り）",
  "tags": ["清潔感", "万能", "お気に入り"]
}
```

**Response 200**
```json
{
  "data": {
    "id": "item_id",
    "name": "白シャツ（お気に入り）",
    "tags": ["清潔感", "万能", "お気に入り"],
    "updated_at": "2024-01-15T10:00:00Z"
  }
}
```

---

### 3.7 アイテム削除

**DELETE /closet/items/{id}**

アイテムを削除します。

**Response 204**
```
No Content
```

---

### 3.8 天気情報取得

**GET /weather**

指定位置の天気情報を取得します。

**Query Parameters**

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| latitude | number | No | 緯度（デフォルト: 35.6762） |
| longitude | number | No | 経度（デフォルト: 139.6503） |

**Response 200**
```json
{
  "data": {
    "weather": "晴れ",
    "temperature": 18,
    "feels_like": 16,
    "humidity": 45,
    "precipitation_probability": 10,
    "description": "晴れ、18°C、体感温度16°C"
  }
}
```

---

### 3.9 カレンダー・TPO取得

**GET /calendar**

指定日の予定とTPO判定を取得します。

**Query Parameters**

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| target_date | string | No | 対象日付（デフォルト: 今日） |

**Response 200**
```json
{
  "data": {
    "events": [
      {
        "id": "1",
        "title": "朝会",
        "start_time": "09:00",
        "end_time": "09:30",
        "event_type": "meeting",
        "location": "オフィス"
      },
      {
        "id": "2",
        "title": "クライアントMTG",
        "start_time": "14:00",
        "end_time": "15:30",
        "event_type": "client_meeting",
        "location": "会議室A"
      }
    ],
    "tpo": {
      "formality_required": "formal",
      "main_event": "クライアントMTG",
      "recommendation": "商談があるため、フォーマルな服装を推奨"
    }
  }
}
```

---

### 3.10 フィードバック送信

**POST /feedback**

コーディネートへのフィードバックを送信します。

**Request**
```json
{
  "outfit_id": "outfit_123",
  "action": "wore",
  "temperature_feedback": "comfortable",
  "style_rating": 5,
  "comment": "商談がうまくいきました！"
}
```

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| outfit_id | string | Yes | コーディネートID |
| action | string | Yes | `wore` / `skipped` |
| temperature_feedback | string | No | `too_hot` / `comfortable` / `too_cold` |
| style_rating | number | No | 1-5のスタイル評価 |
| comment | string | No | コメント |

**Response 201**
```json
{
  "data": {
    "feedback_id": "feedback_123",
    "message": "フィードバックを受け付けました"
  }
}
```

---

## 4. エラーコード

| コード | HTTPステータス | 説明 |
|--------|---------------|------|
| UNAUTHORIZED | 401 | 認証エラー |
| FORBIDDEN | 403 | アクセス権限なし |
| NOT_FOUND | 404 | リソースが見つからない |
| VALIDATION_ERROR | 400 | リクエストバリデーションエラー |
| INTERNAL_ERROR | 500 | サーバー内部エラー |
| SERVICE_UNAVAILABLE | 503 | サービス一時停止 |

---

## 5. レート制限

| エンドポイント | 制限 |
|---------------|------|
| /outfit/recommend | 60回/時間 |
| /closet/* | 300回/時間 |
| その他 | 600回/時間 |

レート制限時のレスポンス:
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "リクエスト数の上限に達しました",
    "details": {
      "retry_after": 3600
    }
  }
}
```
