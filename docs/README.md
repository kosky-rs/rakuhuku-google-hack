# ラクフク（Rakufuku）設計ドキュメント

## 概要

**ラクフク（Rakufuku）** - 毎朝1分で"正解"のコーディネートを提案するAIスタイリストアプリ

> 「楽」+ 「服」= 服選びを楽に

---

## ドキュメント構成

```
docs/
├── README.md                          # このファイル
├── initial-designs/
│   └── basic.md                       # 初期設計（コンセプト）
├── architecture/
│   └── system-architecture.md         # システムアーキテクチャ設計
├── api/
│   └── api-specification.md           # API仕様書
├── data-model/
│   └── firestore-schema.md            # Firestoreデータモデル設計
├── agent/
│   └── adk-agent-design.md            # ADKエージェント設計
├── ui/
│   └── screen-design.md               # 画面設計（Flutter UI）
└── integration/
    └── external-apis.md               # 外部API連携設計
```

---

## ドキュメント一覧

| ドキュメント | 説明 | 対象者 |
|-------------|------|--------|
| [システムアーキテクチャ](./architecture/system-architecture.md) | 全体構成、データフロー、非機能要件 | 全員 |
| [API仕様書](./api/api-specification.md) | RESTエンドポイント、リクエスト/レスポンス | バックエンド、フロントエンド |
| [データモデル設計](./data-model/firestore-schema.md) | Firestoreコレクション、セキュリティルール | バックエンド |
| [ADKエージェント設計](./agent/adk-agent-design.md) | エージェント構成、ツール定義、プロンプト | AI/バックエンド |
| [画面設計](./ui/screen-design.md) | ワイヤーフレーム、コンポーネント、ナビゲーション | フロントエンド、デザイン |
| [外部API連携](./integration/external-apis.md) | Weather API、Calendar API、Vision AI等 | バックエンド |

---

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| フロントエンド | Flutter |
| バックエンド | Cloud Run + Python + FastAPI |
| AI | Google ADK + Gemini 2.0 Flash |
| データベース | Firestore |
| 認証 | Firebase Auth |
| 画像ストレージ | Firebase Storage |
| 画像認識 | Cloud Vision AI |

---

## 実装フェーズ

### Phase 1: 基盤構築
- [ ] Flutter プロジェクト初期化
- [ ] Cloud Run バックエンド初期化
- [ ] Firestore セットアップ
- [ ] 基本的なAPI通信確認

### Phase 2: AI機能
- [ ] ADKエージェント実装
- [ ] Weather Tool 実装
- [ ] Closet Tool 実装
- [ ] コーディネート提案ロジック

### Phase 3: Flutter UI
- [ ] ホーム画面（提案表示）
- [ ] クローゼット画面
- [ ] 服登録画面（Vision AI連携）
- [ ] スワイプUI実装

### Phase 4: 仕上げ
- [ ] UI/UXポリッシュ
- [ ] デモ動画作成
- [ ] 最終デプロイ

---

## クイックリンク

- [初期コンセプト](./initial-designs/basic.md)
- [APIエンドポイント一覧](./api/api-specification.md#2-エンドポイント一覧)
- [Firestoreスキーマ](./data-model/firestore-schema.md#3-ドキュメント定義)
- [画面フロー](./ui/screen-design.md#2-画面一覧)
