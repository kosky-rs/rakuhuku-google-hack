# データモデル設計書（Firestore）

## 1. 概要

ラクフクはFirestoreをメインデータベースとして使用します。

### 1.1 設計原則

| 原則 | 説明 |
|------|------|
| 非正規化 | 読み取り最適化のため適度に非正規化 |
| サブコレクション | ユーザーごとのデータはサブコレクションで管理 |
| 複合インデックス | 頻出クエリに対してインデックスを設定 |

---

## 2. コレクション構造

```
firestore-root/
│
├── users/                          # ユーザー情報
│   └── {user_id}/
│       ├── profile                 # プロフィール（ドキュメント）
│       │
│       ├── closet_items/           # クローゼットアイテム（サブコレクション）
│       │   └── {item_id}/
│       │
│       ├── outfits/                # 提案されたコーディネート履歴
│       │   └── {outfit_id}/
│       │
│       └── feedback/               # フィードバック履歴
│           └── {feedback_id}/
│
├── style_presets/                  # スタイルプリセット（全ユーザー共通）
│   └── {preset_id}/
│
└── app_config/                     # アプリ設定
    └── settings/
```

---

## 3. ドキュメント定義

### 3.1 users/{user_id}

ユーザーのプロフィール情報

```typescript
interface User {
  // 基本情報
  uid: string;                    // Firebase Auth UID
  email: string;
  display_name: string;
  photo_url?: string;

  // 設定
  preferences: {
    default_location: {
      latitude: number;
      longitude: number;
      name: string;              // "東京" など
    };
    style_preference: string;    // "professional" | "casual" | "smart_casual"
    notification_enabled: boolean;
    notification_time: string;   // "07:00"
  };

  // 統計
  stats: {
    total_items: number;
    total_outfits: number;
    total_feedback: number;
  };

  // メタ情報
  created_at: Timestamp;
  updated_at: Timestamp;
  last_login_at: Timestamp;
}
```

**例:**
```json
{
  "uid": "abc123",
  "email": "user@example.com",
  "display_name": "高橋健斗",
  "photo_url": "https://...",
  "preferences": {
    "default_location": {
      "latitude": 35.6762,
      "longitude": 139.6503,
      "name": "東京"
    },
    "style_preference": "professional",
    "notification_enabled": true,
    "notification_time": "07:00"
  },
  "stats": {
    "total_items": 32,
    "total_outfits": 150,
    "total_feedback": 120
  },
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-15T09:00:00Z",
  "last_login_at": "2024-01-15T08:00:00Z"
}
```

---

### 3.2 users/{user_id}/closet_items/{item_id}

クローゼット内のアイテム

```typescript
interface ClosetItem {
  id: string;
  name: string;

  // 分類
  category: "tops" | "bottoms" | "outerwear" | "shoes" | "accessories";
  sub_category?: string;          // "shirt", "t-shirt", "jacket" など

  // 属性
  color: string;                  // "navy", "white", "gray" など
  color_hex?: string;             // "#1a365d"
  pattern?: string;               // "solid", "striped", "checked"
  material?: string;              // "cotton", "wool", "polyester"

  // 着用条件
  season: ("spring" | "summer" | "autumn" | "winter")[];
  formality: "casual" | "business_casual" | "formal";
  temperature_range?: {
    min: number;                  // 最低気温
    max: number;                  // 最高気温
  };

  // メディア
  image_url?: string;
  thumbnail_url?: string;

  // メタデータ
  tags: string[];
  brand?: string;
  purchase_date?: Timestamp;
  notes?: string;

  // 統計
  wear_count: number;
  last_worn_at?: Timestamp;

  // システム
  auto_detected: {               // Vision AIによる自動検出結果
    category?: string;
    color?: string;
    confidence: number;
  };

  created_at: Timestamp;
  updated_at: Timestamp;
}
```

**例:**
```json
{
  "id": "item_001",
  "name": "ネイビージャケット",
  "category": "outerwear",
  "sub_category": "jacket",
  "color": "navy",
  "color_hex": "#1a365d",
  "pattern": "solid",
  "material": "wool",
  "season": ["spring", "autumn", "winter"],
  "formality": "formal",
  "temperature_range": {
    "min": 10,
    "max": 22
  },
  "image_url": "https://storage.googleapis.com/.../jacket.jpg",
  "thumbnail_url": "https://storage.googleapis.com/.../jacket_thumb.jpg",
  "tags": ["定番", "商談向け"],
  "brand": "UNIQLO",
  "wear_count": 25,
  "last_worn_at": "2024-01-10T08:00:00Z",
  "auto_detected": {
    "category": "outerwear",
    "color": "blue",
    "confidence": 0.92
  },
  "created_at": "2023-10-01T00:00:00Z",
  "updated_at": "2024-01-10T08:00:00Z"
}
```

---

### 3.3 users/{user_id}/outfits/{outfit_id}

提案されたコーディネート

```typescript
interface Outfit {
  id: string;

  // アイテム構成
  items: {
    tops?: string;               // item_id
    bottoms?: string;
    outerwear?: string;
    shoes?: string;
    accessories?: string[];
  };

  // コンテキスト
  context: {
    date: Timestamp;
    weather: {
      weather: string;
      temperature: number;
      feels_like: number;
    };
    tpo: {
      formality_required: string;
      main_event?: string;
    };
  };

  // 評価
  evaluation: {
    total_score: number;
    color_harmony: number;
    formality_match: number;
    season_match: number;
    style_balance: number;
    feedback: string;
  };

  // ステータス
  status: "proposed" | "worn" | "skipped";

  // メタ
  created_at: Timestamp;
  updated_at: Timestamp;
}
```

**例:**
```json
{
  "id": "outfit_20240115",
  "items": {
    "tops": "item_002",
    "bottoms": "item_003",
    "outerwear": "item_001",
    "shoes": "item_004"
  },
  "context": {
    "date": "2024-01-15T07:00:00Z",
    "weather": {
      "weather": "晴れ",
      "temperature": 18,
      "feels_like": 16
    },
    "tpo": {
      "formality_required": "formal",
      "main_event": "クライアントMTG"
    }
  },
  "evaluation": {
    "total_score": 92,
    "color_harmony": 95,
    "formality_match": 90,
    "season_match": 90,
    "style_balance": 93,
    "feedback": "ネイビージャケットと白シャツの組み合わせは相性抜群。"
  },
  "status": "worn",
  "created_at": "2024-01-15T07:00:00Z",
  "updated_at": "2024-01-15T08:00:00Z"
}
```

---

### 3.4 users/{user_id}/feedback/{feedback_id}

フィードバック

```typescript
interface Feedback {
  id: string;
  outfit_id: string;

  // フィードバック内容
  action: "wore" | "skipped";
  temperature_feedback?: "too_hot" | "comfortable" | "too_cold";
  style_rating?: number;         // 1-5
  comment?: string;

  // 学習用データ
  skip_reason?: string;          // "気分じゃない", "TPOに合わない" など

  created_at: Timestamp;
}
```

---

### 3.5 style_presets/{preset_id}

スタイルプリセット（全ユーザー共通のマスターデータ）

```typescript
interface StylePreset {
  id: string;
  name: string;                  // "信頼感MAX", "親しみやすさ" など
  description: string;

  // スタイルルール
  rules: {
    preferred_colors: string[];
    preferred_formality: string[];
    color_combinations: {
      base: string;
      accent: string;
    }[];
  };

  // アイコン
  icon_url: string;

  is_active: boolean;
  created_at: Timestamp;
  updated_at: Timestamp;
}
```

---

## 4. インデックス定義

### 4.1 closet_items

```
Collection: users/{user_id}/closet_items

Composite Indexes:
1. category ASC, formality ASC, created_at DESC
2. category ASC, season ARRAY_CONTAINS, created_at DESC
3. formality ASC, season ARRAY_CONTAINS, created_at DESC
```

### 4.2 outfits

```
Collection: users/{user_id}/outfits

Composite Indexes:
1. status ASC, created_at DESC
2. context.date DESC
```

### 4.3 feedback

```
Collection: users/{user_id}/feedback

Composite Indexes:
1. outfit_id ASC, created_at DESC
2. action ASC, created_at DESC
```

---

## 5. セキュリティルール

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ユーザードキュメント
    match /users/{userId} {
      // 自分のデータのみ読み書き可能
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // サブコレクション
      match /closet_items/{itemId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      match /outfits/{outfitId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      match /feedback/{feedbackId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // スタイルプリセット（読み取りのみ）
    match /style_presets/{presetId} {
      allow read: if request.auth != null;
      allow write: if false; // 管理者のみ（Firebase Consoleから）
    }

    // アプリ設定（読み取りのみ）
    match /app_config/{docId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

---

## 6. データ移行・バックアップ

### 6.1 バックアップ戦略

| 項目 | 設定 |
|------|------|
| 自動バックアップ | 毎日（GCS） |
| 保持期間 | 30日 |
| リージョン | asia-northeast1 |

### 6.2 エクスポート形式

```bash
# Firestoreエクスポート
gcloud firestore export gs://rakufuku-backup/$(date +%Y%m%d)
```
