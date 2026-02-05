# Mock Registry - モック実装追跡ドキュメント

> **⚠️ 重要: 本番リリース前にすべてのモックを削除すること**

## 削除確認コマンド

```bash
# すべてのモックコードを検索
grep -rn "# MOCK:" backend/

# モックインポートを検索
grep -rn "from mock" backend/
grep -rn "import mock" backend/

# モック関連ファイルを一覧
ls -la backend/mock/
```

## モックモード設定

環境変数 `MOCK_MODE` で切り替え:

```bash
# 開発時（デフォルト）
export MOCK_MODE=true

# 本番環境
export MOCK_MODE=false
```

---

## モック実装一覧

### 1. モック設定モジュール

| ファイル | 説明 | 本番対応 |
|---------|------|---------|
| `backend/mock/__init__.py` | モード設定・警告表示 | ファイル削除 |
| `backend/mock/gemini_mock.py` | Gemini Vision APIモック | ファイル削除 |
| `backend/mock/vision_mock.py` | Cloud Vision APIモック | ファイル削除 |
| `backend/mock/closet_mock.py` | クローゼットデータモック | ファイル削除 |

### 2. API関連ツール

| ファイル | 関数 | モック内容 | 本番対応 |
|---------|------|----------|---------|
| `backend/agent/tools/outfit_analyzer.py` | `evaluate_outfit_with_gemini()` | コーデ評価のモックレスポンス | Gemini API接続 |
| `backend/agent/tools/outfit_analyzer.py` | `detect_items_with_cloud_vision()` | アイテム検出のモックレスポンス | Cloud Vision API接続 |
| `backend/agent/tools/outfit_analyzer.py` | `analyze_item_details_with_gemini()` | アイテム詳細分析のモック | Gemini API接続 |
| `backend/agent/tools/outfit_analyzer.py` | `crop_detected_items()` | ダミー画像（1x1 PNG） | PIL実画像処理 |
| `backend/agent/tools/outfit_analyzer.py` | `fallback_detect_items_with_gemini()` | フォールバック検出モック | Gemini API接続 |
| `backend/agent/tools/closet.py` | `get_closet_items()` | モッククローゼットデータ | Firestore接続 |
| `backend/agent/tools/closet.py` | `get_all_categories()` | モックカテゴリデータ | Firestore接続 |

### 3. APIエンドポイント

| ファイル | エンドポイント | モック内容 | 本番対応 |
|---------|--------------|----------|---------|
| `backend/api/routes.py` | `POST /closet/items` | TODO: Firestoreに保存 | Firestore実装 |
| `backend/api/routes.py` | `POST /closet/items/bulk` | モックIDを生成 | Firestore実装 |

---

## 本番リリースチェックリスト

### Phase 1: GCP環境セットアップ

- [ ] Google Cloud プロジェクト作成
- [ ] Gemini API キー取得（`GOOGLE_API_KEY`）
- [ ] Cloud Vision API 有効化
- [ ] Firestore データベース作成
- [ ] Cloud Storage バケット作成

### Phase 2: 環境変数設定

```bash
# 必須
export MOCK_MODE=false
export GOOGLE_API_KEY=your-api-key
export GOOGLE_CLOUD_PROJECT=your-project-id

# オプション
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

### Phase 3: モックコード削除

```bash
# 1. モックディレクトリ削除
rm -rf backend/mock/

# 2. モックインポート削除（手動）
#    各ファイルから `from mock import ...` を削除

# 3. モック条件分岐削除（手動）
#    各ファイルから `if is_mock_mode(): ...` ブロックを削除

# 4. 削除漏れ確認
grep -rn "# MOCK:" backend/
# → 結果が0件であることを確認
```

### Phase 4: 動作確認

- [ ] `MOCK_MODE=false` でサーバー起動
- [ ] `/outfit/diagnose` エンドポイントテスト
- [ ] `/closet` エンドポイントテスト
- [ ] クロップ画像が正しく生成されることを確認

---

## モックデータサンプル

### コーデ評価レスポンス

```json
{
  "score": 7.5,
  "good_points": ["色の組み合わせがまとまっている", "シルエットがきれい"],
  "improvement_suggestions": [
    {
      "point": "靴をレザーシューズに変えると洗練された印象に",
      "category": "shoes",
      "suggested_color": "ブラック",
      "suggested_style": "レザーローファー"
    }
  ],
  "overall_style": "ビジネスカジュアル",
  "color_harmony": "ネイビーとホワイトで清潔感あり"
}
```

### 検出アイテムレスポンス

```json
[
  {
    "category": "tops",
    "name": "ライトブルーシャツ",
    "color": "ライトブルー",
    "confidence": 0.92,
    "bounding_box": {"x": 0.25, "y": 0.15, "width": 0.5, "height": 0.35}
  }
]
```

---

## 注意事項

1. **`# MOCK:` マーカーは絶対に削除しないこと** - 本番移行時の検索に必要
2. **モック関数は本番コードと同じ型を返すこと** - 型チェックエラーを防ぐ
3. **本番環境で `MOCK_MODE=true` は厳禁** - 必ず `false` に設定

---

*最終更新: 2026-02-04*
