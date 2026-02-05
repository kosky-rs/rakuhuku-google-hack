# 外部連携設計書

## 1. 概要

ラクフクは以下の外部サービスと連携します。

| サービス | 用途 | 必須/任意 |
|---------|------|----------|
| OpenWeather API | 天気・気温取得 | 必須 |
| Google Calendar API | 予定取得・TPO判定 | 任意 |
| Vision AI | 服の自動分類 | 任意 |
| Firebase Auth | ユーザー認証 | 必須 |
| Firebase Storage | 画像保存 | 必須 |

---

## 2. OpenWeather API

### 2.1 概要

| 項目 | 値 |
|------|-----|
| API Version | 2.5 / 3.0 |
| 認証方式 | API Key |
| レート制限 | 60回/分（無料プラン） |
| ドキュメント | https://openweathermap.org/api |

### 2.2 使用エンドポイント

#### Current Weather Data

```http
GET https://api.openweathermap.org/data/2.5/weather
```

**パラメータ:**

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| lat | number | Yes | 緯度 |
| lon | number | Yes | 経度 |
| appid | string | Yes | APIキー |
| units | string | No | 単位（metric推奨） |
| lang | string | No | 言語（ja推奨） |

**リクエスト例:**
```bash
curl "https://api.openweathermap.org/data/2.5/weather?lat=35.6762&lon=139.6503&appid=YOUR_API_KEY&units=metric&lang=ja"
```

**レスポンス例:**
```json
{
  "coord": {
    "lon": 139.6503,
    "lat": 35.6762
  },
  "weather": [
    {
      "id": 800,
      "main": "Clear",
      "description": "晴天",
      "icon": "01d"
    }
  ],
  "main": {
    "temp": 18.5,
    "feels_like": 16.2,
    "temp_min": 15.0,
    "temp_max": 21.0,
    "pressure": 1013,
    "humidity": 45
  },
  "wind": {
    "speed": 3.5,
    "deg": 180
  },
  "clouds": {
    "all": 0
  },
  "dt": 1705276800,
  "sys": {
    "country": "JP",
    "sunrise": 1705266000,
    "sunset": 1705302000
  },
  "timezone": 32400,
  "name": "Tokyo"
}
```

### 2.3 データマッピング

| OpenWeather | ラクフク | 変換ロジック |
|-------------|--------|------------|
| weather[0].main | weather | 日本語変換（Clear→晴れ） |
| main.temp | temperature | 四捨五入 |
| main.feels_like | feels_like | 四捨五入 |
| main.humidity | humidity | そのまま |
| - | precipitation_probability | One Call APIで取得（オプション） |

### 2.4 エラーハンドリング

| HTTPステータス | 対応 |
|---------------|------|
| 401 | APIキー無効 → モックデータ使用 |
| 429 | レート制限 → キャッシュデータ使用 |
| 5xx | サーバーエラー → モックデータ使用 |

### 2.5 キャッシュ戦略

```python
WEATHER_CACHE_TTL = 900  # 15分
```

---

## 3. Google Calendar API

### 3.1 概要

| 項目 | 値 |
|------|-----|
| API Version | v3 |
| 認証方式 | OAuth 2.0 |
| スコープ | calendar.readonly |
| ドキュメント | https://developers.google.com/calendar |

### 3.2 使用エンドポイント

#### Events: list

```http
GET https://www.googleapis.com/calendar/v3/calendars/{calendarId}/events
```

**パラメータ:**

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| calendarId | string | Yes | カレンダーID（primary推奨） |
| timeMin | datetime | Yes | 開始日時（RFC3339） |
| timeMax | datetime | Yes | 終了日時（RFC3339） |
| singleEvents | boolean | No | true推奨（繰り返しイベント展開） |
| orderBy | string | No | startTime推奨 |

**リクエスト例:**
```bash
curl -H "Authorization: Bearer ACCESS_TOKEN" \
  "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=2024-01-15T00:00:00Z&timeMax=2024-01-15T23:59:59Z&singleEvents=true&orderBy=startTime"
```

**レスポンス例:**
```json
{
  "kind": "calendar#events",
  "items": [
    {
      "id": "event_id_1",
      "summary": "クライアントMTG",
      "start": {
        "dateTime": "2024-01-15T14:00:00+09:00"
      },
      "end": {
        "dateTime": "2024-01-15T15:30:00+09:00"
      },
      "location": "会議室A",
      "description": "新規プロジェクトの提案"
    },
    {
      "id": "event_id_2",
      "summary": "朝会",
      "start": {
        "dateTime": "2024-01-15T09:00:00+09:00"
      },
      "end": {
        "dateTime": "2024-01-15T09:30:00+09:00"
      }
    }
  ]
}
```

### 3.3 TPO判定ロジック

```python
# イベントタイプの判定キーワード
EVENT_TYPE_KEYWORDS = {
    "client_meeting": ["クライアント", "商談", "提案", "顧客", "client", "proposal"],
    "meeting": ["会議", "MTG", "ミーティング", "meeting", "朝会", "定例"],
    "interview": ["面接", "面談", "interview"],
    "date": ["デート", "date", "ディナー", "dinner"],
    "exercise": ["ジム", "gym", "ランニング", "running", "筋トレ"],
    "casual": ["ランチ", "lunch", "飲み会", "友人", "friend"],
}

# フォーマル度マッピング
FORMALITY_MAP = {
    "client_meeting": "formal",
    "interview": "formal",
    "meeting": "business_casual",
    "date": "business_casual",
    "casual": "casual",
    "exercise": "casual",
}
```

### 3.4 OAuth 2.0 フロー

```
1. ユーザーが「Googleカレンダー連携」をタップ
2. Google OAuth画面にリダイレクト
3. ユーザーが許可
4. アプリにリダイレクト（認可コード付き）
5. 認可コードをアクセストークンに交換
6. リフレッシュトークンをFirestoreに保存
7. 以降はリフレッシュトークンで自動更新
```

---

## 4. Vision AI (Cloud Vision API)

### 4.1 概要

| 項目 | 値 |
|------|-----|
| API Version | v1 |
| 認証方式 | Service Account |
| 使用機能 | Label Detection, Color Detection |
| ドキュメント | https://cloud.google.com/vision |

### 4.2 使用エンドポイント

#### images:annotate

```http
POST https://vision.googleapis.com/v1/images:annotate
```

**リクエスト:**
```json
{
  "requests": [
    {
      "image": {
        "source": {
          "imageUri": "gs://rakufuku-images/user123/item456.jpg"
        }
      },
      "features": [
        {
          "type": "LABEL_DETECTION",
          "maxResults": 10
        },
        {
          "type": "IMAGE_PROPERTIES"
        }
      ]
    }
  ]
}
```

**レスポンス例:**
```json
{
  "responses": [
    {
      "labelAnnotations": [
        {
          "description": "Jacket",
          "score": 0.95
        },
        {
          "description": "Outerwear",
          "score": 0.92
        },
        {
          "description": "Blazer",
          "score": 0.88
        },
        {
          "description": "Clothing",
          "score": 0.85
        }
      ],
      "imagePropertiesAnnotation": {
        "dominantColors": {
          "colors": [
            {
              "color": {
                "red": 26,
                "green": 54,
                "blue": 93
              },
              "score": 0.45,
              "pixelFraction": 0.35
            }
          ]
        }
      }
    }
  ]
}
```

### 4.3 カテゴリマッピング

```python
# Vision AIラベル → ラクフクカテゴリ
CATEGORY_MAPPING = {
    # トップス
    "Shirt": "tops",
    "T-shirt": "tops",
    "Blouse": "tops",
    "Polo shirt": "tops",
    "Sweater": "tops",

    # ボトムス
    "Pants": "bottoms",
    "Jeans": "bottoms",
    "Trousers": "bottoms",
    "Shorts": "bottoms",
    "Skirt": "bottoms",

    # アウター
    "Jacket": "outerwear",
    "Coat": "outerwear",
    "Blazer": "outerwear",
    "Cardigan": "outerwear",

    # シューズ
    "Shoe": "shoes",
    "Sneakers": "shoes",
    "Boot": "shoes",
    "Sandal": "shoes",
}
```

### 4.4 色マッピング

```python
# RGB → 色名
def rgb_to_color_name(r, g, b):
    colors = {
        "white": (255, 255, 255),
        "black": (0, 0, 0),
        "navy": (26, 54, 93),
        "gray": (128, 128, 128),
        "beige": (245, 245, 220),
        "light_blue": (173, 216, 230),
        # ...
    }

    # 最も近い色を計算
    min_distance = float('inf')
    closest_color = "unknown"

    for name, (cr, cg, cb) in colors.items():
        distance = ((r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2) ** 0.5
        if distance < min_distance:
            min_distance = distance
            closest_color = name

    return closest_color
```

---

## 5. Firebase Auth

### 5.1 概要

| 項目 | 値 |
|------|-----|
| 認証方式 | Email/Password, Google Sign-In |
| セッション管理 | Firebase ID Token |
| トークン有効期限 | 1時間（自動更新） |

### 5.2 サポートする認証方式

| 方式 | MVP | 優先度 |
|------|-----|--------|
| Google Sign-In | Yes | P0 |
| Email/Password | Yes | P1 |
| Apple Sign-In | No | P2 |

### 5.3 認証フロー（Google Sign-In）

```
1. ユーザーが「Googleでログイン」をタップ
2. Firebase Auth SDK がGoogle Sign-In画面を表示
3. ユーザーがGoogleアカウントを選択
4. Firebase Auth が ID Token を発行
5. ID Token をバックエンドAPIに送信
6. バックエンドで ID Token を検証
7. ユーザーセッション開始
```

### 5.4 バックエンドでのトークン検証

```python
from firebase_admin import auth

def verify_token(id_token: str) -> dict:
    """Firebase ID Tokenを検証"""
    try:
        decoded_token = auth.verify_id_token(id_token)
        return {
            "uid": decoded_token["uid"],
            "email": decoded_token.get("email"),
            "name": decoded_token.get("name"),
        }
    except auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired")
```

---

## 6. Firebase Storage

### 6.1 概要

| 項目 | 値 |
|------|-----|
| バケット | gs://rakufuku-images |
| 最大ファイルサイズ | 10MB |
| 対応形式 | JPEG, PNG, WebP |

### 6.2 ディレクトリ構造

```
gs://rakufuku-images/
├── users/
│   └── {user_id}/
│       └── closet/
│           ├── {item_id}.jpg       # オリジナル
│           └── {item_id}_thumb.jpg # サムネイル
```

### 6.3 セキュリティルール

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/closet/{fileName} {
      // 自分のファイルのみ読み書き可能
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // ファイルサイズ制限
      allow write: if request.resource.size < 10 * 1024 * 1024;

      // 画像形式のみ
      allow write: if request.resource.contentType.matches('image/.*');
    }
  }
}
```

### 6.4 画像アップロードフロー

```
1. Flutterアプリで画像を選択/撮影
2. 画像をリサイズ（最大1024px）
3. Firebase Storageにアップロード
4. ダウンロードURLを取得
5. URLをClosetItemに保存
```

---

## 7. 環境変数

### 7.1 バックエンド（.env）

```bash
# OpenWeather API
OPENWEATHER_API_KEY=your_api_key_here

# Google Cloud
GOOGLE_CLOUD_PROJECT=rakufuku-project
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

# Firebase
FIREBASE_PROJECT_ID=rakufuku-project

# Server
PORT=8000
ENV=development
```

### 7.2 Flutterアプリ

```dart
// lib/config/env.dart
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'rakufuku-project',
  );
}
```

---

## 8. フォールバック戦略

| サービス | フォールバック |
|---------|--------------|
| OpenWeather API | モックデータを返す |
| Google Calendar | TPO判定をスキップ（casual想定） |
| Vision AI | 手動入力を促す |
| Firebase Auth | ゲストモード（機能制限あり） |
