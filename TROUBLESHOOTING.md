# トラブルシューティングガイド

## デプロイ後のエラー確認手順

### 1. ブラウザでNetworkタブを開く

1. https://rakufuku-pwa.web.app にアクセス
2. Chrome DevTools を開く（F12 または Cmd+Option+I）
3. **Network** タブに移動
4. ページをリロード（Cmd+R）

### 2. 失敗したリクエストを確認

- 赤色で表示されているリクエストをクリック
- **Headers** タブで以下を確認：
  - Request URL
  - Request Method
  - Status Code
- **Response** タブでエラーメッセージを確認
- **Console** タブで詳細なエラーログを確認

### 3. よくあるエラーと対処法

#### エラー: "CORS policy: No 'Access-Control-Allow-Origin' header"

**原因**: バックエンドのCORS設定が正しくない

**対処法**:
```bash
# Cloud Run環境変数を確認
gcloud run services describe poltan-api \
  --region=asia-northeast1 \
  --project=rakufuku-pwa \
  --format="value(spec.template.spec.containers[0].env)" | grep ALLOWED_ORIGINS

# 正しい値: https://rakufuku-pwa.web.app,https://rakufuku-pwa.firebaseapp.com
```

#### エラー: "Failed to fetch" または "Network Error"

**原因**: バックエンドURLが間違っている、またはバックエンドがダウンしている

**対処法**:
```bash
# バックエンドのHealth Checkを実行
curl https://poltan-api-1024882237054.asia-northeast1.run.app/api/v1/health

# 期待される応答: {"status":"healthy","service":"poltan-api"}
```

#### エラー: "An unexpected error occurred"

**原因**: APIエラーレスポンスが返ってきている

**対処法**:
1. Network タブで失敗したリクエストの Response を確認
2. Cloud Run ログを確認:
```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=poltan-api AND severity>=ERROR" \
  --limit 50 \
  --project=rakufuku-pwa
```

#### エラー: "FedCM was disabled" (Google Sign-In)

**原因**: Google Sign-Inの設定またはブラウザ設定

**対処法**:
- これは致命的なエラーではありません
- 未認証でもdemo_userとしてアプリは動作します
- Chrome設定 → プライバシーとセキュリティ → サードパーティCookie → rakufuku-pwa.web.app を許可

---

## デバッグコマンド集

### バックエンドログ確認

```bash
# エラーログのみ
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=poltan-api AND severity>=ERROR" \
  --limit 50 \
  --project=rakufuku-pwa

# 全ログ（最新50件）
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=poltan-api" \
  --limit 50 \
  --project=rakufuku-pwa
```

### API直接テスト

```bash
# Health Check
curl https://poltan-api-1024882237054.asia-northeast1.run.app/api/v1/health

# 日次推奨取得
curl -X POST https://poltan-api-1024882237054.asia-northeast1.run.app/api/v1/outfit/daily \
  -H "Content-Type: application/json" \
  -d '{"user_id":"demo_user","latitude":35.6762,"longitude":139.6503}'

# Agent Health Check
curl https://poltan-api-1024882237054.asia-northeast1.run.app/api/v1/agent/health
```

### Cloud Run環境変数確認

```bash
gcloud run services describe poltan-api \
  --region=asia-northeast1 \
  --project=rakufuku-pwa \
  --format="value(spec.template.spec.containers[0].env)"
```

---

## 緊急時のロールバック

### フロントエンド

```bash
# 以前のバージョンに戻す
firebase hosting:channel:deploy previous --project=rakufuku-pwa
```

### バックエンド

```bash
# リビジョン一覧確認
gcloud run revisions list --service=poltan-api --region=asia-northeast1 --project=rakufuku-pwa

# 特定のリビジョンにロールバック
gcloud run services update-traffic poltan-api \
  --to-revisions=poltan-api-00010-xxx=100 \
  --region=asia-northeast1 \
  --project=rakufuku-pwa
```

---

## 現在のデプロイ情報

**最終デプロイ日**: 2026-02-12

**バックエンド**:
- URL: https://poltan-api-1024882237054.asia-northeast1.run.app
- Service: poltan-api
- Region: asia-northeast1
- Project: rakufuku-pwa

**フロントエンド**:
- URL: https://rakufuku-pwa.web.app
- Project: rakufuku-pwa

**設定済み環境変数**:
- ENVIRONMENT=production
- GCP_PROJECT_ID=rakufuku-pwa
- VERTEX_AI_LOCATION=asia-northeast1
- ALLOWED_ORIGINS=https://rakufuku-pwa.web.app,https://rakufuku-pwa.firebaseapp.com
- FIREBASE_STORAGE_BUCKET=rakufuku-pwa.appspot.com
- OPENWEATHER_API_KEY=（Secret Managerから取得）

**未設定の環境変数（Cloud Runコンソールで設定が必要）**:
- GOOGLE_API_KEY (Vertex AI/Gemini用)
- RAKUTEN_APPLICATION_ID
- RAKUTEN_AFFILIATE_ID
