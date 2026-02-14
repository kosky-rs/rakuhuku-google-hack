# Rakufuku ブログ記事要素集

> 第4回 Agentic AI Hackathon with Google Cloud 出展作品

---

## 1. 記事タイトル案

### Qiita / Zenn 向け（技術+バズ狙い）

1. **「Vertex AI Gemini + マルチエージェントで"毎朝の服選び"を自動化した話【Google Cloudハッカソン】」**
2. **「4つのAIスタイリストが議論する ─ Gemini 2.0 Flash マルチエージェントで最適コーデを導く設計」**
3. **「Vertex AI Imagen 4で"着せ替えマネキン"を生成してみた ─ Google Cloudハッカソン開発記」**
4. **「スワイプするだけでAIが好みを学習 ─ Gemini + Firestore で作る嗜好学習パイプライン」**
5. **「天気 x カレンダー x クローゼット ─ Google Cloud で作るコンテキストアウェアなAIコーデ提案」**
6. **「Cloud Vision + Gemini Visionで全身写真からコーデを診断する ─ Vertex AIフルスタック活用」**
7. **「asyncio.gatherで4エージェント並列実行 ─ Agentic AIハッカソンで学んだマルチエージェント実践パターン」**

### note 向け（ストーリー重視）

8. **「毎朝15分の服選びをゼロにしたい ─ エンジニアがAIスタイリストを作った理由」**
9. **「クローゼットの中身を知っているAI ─ Rakufukuが目指す"楽な服選び"」**

### 技術ブログ向け（深度重視・Google Cloud前面化）

10. **「Vertex AI マルチエージェントオーケストレーション: Gemini 2.0 Flash × 4エージェント協調設計」**
11. **「Gemini 2.0 Flash + Imagen 4 Fast: コーデ提案から画像生成までの Google Cloud AI フルスタック実装」**
12. **「Agentic AI Hackathon 参戦記: Google Cloud で構築したマルチエージェントファッションAIの全設計」**

---

## 2. 記事構成案

### A. ハッカソン振り返り記事（想定 4,000-6,000字）── 審査3軸対応構成

公式審査基準「課題の新規性」「解決策の有効性」「実装品質と拡張性」に沿った構成。

| # | セクション | 要点 | 審査軸 | 想定文字数 |
|---|-----------|------|--------|-----------|
| 1 | はじめに ─ 「毎朝の服選び」という見過ごされた課題 | 意思決定疲れ、クローゼット死蔵率、既存ファッションアプリの限界（SNS型・EC型に偏り、手持ち服の活用が不在） | 課題の新規性 | 500字 |
| 2 | 課題発見の過程 ─ なぜ「コーデ提案」ではなく「コーデ最適化」か | ユーザーインタビュー（仮想）、既存アプリ調査、「手持ちの服を最大活用する」着眼点 | 課題の新規性 | 400字 |
| 3 | Rakufuku の解決策 ─ マルチエージェントAIスタイリスト | プロダクト概要、4エージェント設計思想（多様性と品質の両立）、スクリーンショット | 解決策の有効性 | 600字 |
| 4 | Google Cloud 技術活用の全体像 | Vertex AI（Gemini 2.0 Flash / Imagen 4 Fast）、Cloud Vision API、Firestore、Cloud Storage のフルスタック活用図 | 実装品質と拡張性 | 800字 |
| 5 | マルチエージェント設計の詳細 | 4エージェント並列（asyncio.gather）、オーケストレーター、TPO/天気/嗜好スコアリング、多様性保証アルゴリズム | 実装品質と拡張性 | 1,200字 |
| 6 | Gemini + Imagen 連携パイプライン | Gemini 構造化JSON出力 → 英語プロンプト自動生成 → Imagen 4 Fast マネキン画像 → Cloud Storage | 実装品質と拡張性 | 800字 |
| 7 | 嗜好学習とコーデ診断 | スワイプUI → 指数移動平均3軸学習 → Firestoreプロファイル / Cloud Vision + Gemini Vision 4段階診断 | 解決策の有効性 | 600字 |
| 8 | 苦労した点・工夫した点 | Geminiの「嘘」対策（存在しないIDの自動変換）、Imagen日本語混入防止、フォールバック戦略 | 実装品質と拡張性 | 600字 |
| 9 | まとめと拡張構想 | 振り返り、RAG連携・音声入力・リアルタイムトレンド分析等の拡張ロードマップ | 実装品質と拡張性 | 400字 |

### B. 技術解説記事（想定 5,000-8,000字）

| # | セクション | 要点 | 想定文字数 |
|---|-----------|------|-----------|
| 1 | 導入 ─ なぜマルチエージェントか | 単一LLMとの比較。多様性と品質の両立。Agentic AI パラダイム | 500字 |
| 2 | システムアーキテクチャ | Google Cloud 全体図、コンポーネント間の責務分担 | 600字 |
| 3 | エージェント設計 | BaseStyleAgent の継承構造、ペルソナプロンプト設計（4つのスタイリスト人格） | 1,200字 |
| 4 | オーケストレーター | 並列実行、多様性保証（_ensure_agent_diversity）、TPO/天気ボーナススコアリング | 1,200字 |
| 5 | Gemini構造化出力 | response_mime_type="application/json"、バリデーション、存在しないIDの自動変換フォールバック | 1,000字 |
| 6 | Imagen 4 Fast 画像生成 | 2段階プロンプト構築（Gemini英語記述優先）、Cloud Storage連携、9:16マネキン画像 | 800字 |
| 7 | コーデ診断パイプライン | Gemini 2.5 Flash評価 → Cloud Vision物体検出 → Gemini 2.5 Flash詳細分析 → 画像クロップ（4段階） | 800字 |
| 8 | 嗜好学習 | EMA(指数移動平均 alpha=0.1)、色嗜好(固定デルタ+-5)、フォーマリティ(頻度カウント) の3軸学習 | 600字 |
| 9 | 外部連携 | 楽天/Amazon/ZOZOTOWN マーケットプレイスリンク自動生成 | 400字 |
| 10 | パフォーマンスと信頼性 | asyncio.gather並列、キャッシュ、Tier制限、全ステップのフォールバック設計 | 600字 |

### C. ストーリー記事（note向け・想定 3,000-4,000字）

| # | セクション | 要点 |
|---|-----------|------|
| 1 | 朝の風景 ─ クローゼットの前で立ち尽くす | 共感を呼ぶ導入 |
| 2 | 「AIにコーデを任せたい」 | 動機と着想 |
| 3 | 4人のスタイリストを作る | カジュアル/フォーマル/バランス/ユニーク の擬人化 |
| 4 | クローゼットを丸ごとデジタル化 | 写真を撮ればAIが認識・登録 |
| 5 | スワイプで"好み"を教える | Tinder的UXでの嗜好学習 |
| 6 | 足りないアイテムはAIが提案 | 外部購入リンクとマーケットプレイス連携 |
| 7 | 「ラクに服を選ぶ」未来 | プロダクトビジョン |

---

## 3. リード文案

### A. 技術者向け

> Gemini 2.0 Flash を使った4つの専門スタイリストエージェントが並列でコーデを生成し、オーケストレーターがTPO・天気・嗜好を加味してスコアリング。さらに Imagen 4 Fast でマネキン画像をリアルタイム生成する ── そんなマルチエージェントシステムをハッカソンで作りました。設計思想からプロンプトエンジニアリングまで、すべて公開します。

### B. 一般向け

> 「今日なに着よう？」── 毎朝クローゼットの前で悩む時間、もったいないと思いませんか？ Rakufuku（ラクフク）は、あなたのクローゼットの中身を覚えて、天気や予定に合わせて最適なコーデをAIが提案してくれるアプリです。4人のAIスタイリストがそれぞれの視点でコーデを考え、あなた好みの1着を届けます。

### C. ハッカソン審査員・参加者向け

> 第4回 Agentic AI Hackathon with Google Cloud に出展した「Rakufuku」の技術全容です。Google Cloud の Vertex AI（Gemini 2.0 Flash / Gemini 2.5 Flash + Imagen 4 Fast）を中核に、Cloud Vision API / Firestore / Cloud Storage をフル活用したマルチエージェントAIコーデ提案システムを構築しました。4エージェント並列実行、構造化JSON出力、スワイプ嗜好学習、全身写真診断 ── 「課題の新規性」「解決策の有効性」「実装品質と拡張性」の3軸で、アーキテクチャ図とコードスニペット付きで解説します。

### D. 課題ドリブンリード（審査基準「課題の新規性」強調）

> ファッションAIアプリは数あれど、「手持ちの服を最大活用する」視点は意外と空白地帯でした。クローゼットの死蔵率は約7割。ECサイトは「買わせる」AIばかりで「着る」を最適化するAIがいない ── この課題に、Google Cloud の Vertex AI マルチエージェントで挑みました。

---

## 4. 技術解説セクション

### 4.1 非エンジニア向けの平易な説明

**マルチエージェント = 4人のスタイリスト会議**

> 1人のAIに「コーデ考えて」と頼むと、毎回似た提案になりがちです。Rakufukuでは「カジュアル担当」「フォーマル担当」「バランス担当」「個性派担当」の4人のAIスタイリストを用意。それぞれが独自の視点でコーデを考え、最後にマネージャー（オーケストレーター）が天気・予定・好みを総合判断して、ベスト5を選びます。

**嗜好学習 = 使うほど賢くなる**

> 提案されたコーデを「いいね」か「ちょっと違う」とスワイプするだけで、AIがあなたの好みを学習。カジュアルが好きなのかフォーマルが好きなのか、何色が好きなのか ── 使うほど精度が上がっていきます。

**コーデ診断 = 全身写真でチェック**

> お出かけ前に全身写真を撮ると、AIがコーデを10点満点で採点。「色合わせがいいですね」「靴をレザーにするともっと良くなります」など、具体的なアドバイスと改善商品の提案までしてくれます。

### 4.2 コードスニペット候補

**[1] 4エージェント並列実行（インパクト: 高）**
```python
# backend/agent/orchestrator.py:91-99
tasks = [
    self.agents["casual"].generate_outfit(user_id, context),
    self.agents["formal"].generate_outfit(user_id, context),
    self.agents["balanced"].generate_outfit(user_id, context),
    self.agents["unique"].generate_outfit(user_id, context),
]

try:
    results = await asyncio.gather(*tasks, return_exceptions=True)
```

**[2] エージェントペルソナ定義（インパクト: 高）**
```python
# backend/agent/style_agents.py:398-409
@property
def agent_persona_prompt(self) -> str:
    return """あなたはカジュアルファッション専門のスタイリストです。
リラックスした日常スタイルを提案します。

重視するポイント:
- 着心地と動きやすさを最優先
- デニム、Tシャツ、スニーカーなどカジュアルアイテムを好む
- 色はアースカラー（ベージュ、オリーブ、グレー）やベーシックカラーを中心に
...
```

**[3] Gemini構造化JSON出力（インパクト: 高）**
```python
# backend/agent/tools/gemini_outfit_composer.py:75-87
model = GenerativeModel(
    MODEL_NAME,
    system_instruction=agent_persona,
)

response = model.generate_content(
    contents=user_message,
    generation_config=GenerationConfig(
        temperature=0.7,
        max_output_tokens=2048,
        response_mime_type="application/json",
    ),
)
```

**[4] 嗜好学習の指数移動平均（インパクト: 中）**
```python
# backend/agent/tools/preference_learner.py:90-93
current_score = profile["style_scores"][agent_type]
reward = 100 if action == "approve" else 0
new_score = current_score * (1 - STYLE_SCORE_ALPHA) + reward * STYLE_SCORE_ALPHA
profile["style_scores"][agent_type] = round(new_score, 2)
```

**[5] Imagen 4 Fast マネキン画像生成（インパクト: 高）**
```python
# backend/agent/tools/nano_banana.py:78-87
model = ImageGenerationModel.from_pretrained("imagen-4.0-fast-generate-001")

images = model.generate_images(
    prompt=prompt,
    number_of_images=1,
    aspect_ratio="9:16",  # Vertical for mannequin
    safety_filter_level="block_some",
    person_generation="allow_adult",
)
```

**[6] TPOボーナススコアリングマトリクス（インパクト: 中）**
```python
# backend/agent/orchestrator.py:315-327
bonus_map = {
    ("formal", "formal"): 10,
    ("formal", "business_casual"): 5,
    ("balanced", "business_casual"): 10,
    ("balanced", "formal"): 5,
    ("balanced", "casual"): 5,
    ("casual", "casual"): 10,
    ("casual", "business_casual"): 0,
    ("casual", "formal"): -5,
    ("unique", "casual"): 5,
    ("unique", "business_casual"): 0,
    ("unique", "formal"): -5,
}
```

### 4.3 図解すべきポイント

1. **Google Cloud 活用マップ** ─ どのコンポーネントがどの Google Cloud サービスを使っているか一覧
2. **マルチエージェントパイプライン全体図** ─ Weather/Calendar/Closet/Preference入力 → 4エージェント並列 → オーケストレーター → Top5選出 → Imagen画像生成
3. **エージェント継承構造** ─ BaseStyleAgent → Casual/Formal/Balanced/Unique
4. **スコアリング計算式** ─ base_score + TPOボーナス(+-10%) + 嗜好ボーナス(+-5%)
5. **コーデ診断フロー** ─ 全身写真 → Gemini 2.5 Flash評価 → Cloud Vision物体検出 → Gemini 2.5 Flash詳細分析 → 画像クロップ（4段階）
6. **嗜好学習ループ** ─ コーデ提案 → スワイプ → プロファイル更新(3軸) → 次回提案に反映

---

## 5. ユーザーストーリー / ペルソナ

### ペルソナ A: 忙しいIT企業勤務（30代男性）

| 項目 | 内容 |
|------|------|
| 名前 | 田中健太（仮名） |
| 背景 | 都内のIT企業で働くエンジニア。効率化が好き。服自体には興味があるが、毎朝の意思決定コストが苦痛 |
| 課題 | 毎朝の服選びに15分。リモートと出社が混在し、TPO判断を間違えた経験あり（会議日にパーカー出社）。クローゼットの7割は着回せていない |
| Rakufukuとの出会い | 「もう服で悩みたくない」と思っていたところに、カレンダー連携で会議日はフォーマル寄りを自動提案してくれるアプリを発見 |
| 解決 | カレンダー連携で会議日はフォーマル寄りのコーデを自動提案。朝の準備時間が15分から2分に短縮。死蔵していた服が提案に登場し、クローゼット活用率が向上 |
| 刺さる機能 | TPO判定、天気連動、「今日のおすすめ」1タップ選択 |

### ペルソナ B: ファッション初心者（20代男性）

| 項目 | 内容 |
|------|------|
| 名前 | 鈴木翔太（仮名） |
| 背景 | 新社会人。学生時代は制服・ジャージで過ごし、「大人の普段着」がわからない。買い物に行っても何を選べばいいか迷う |
| 課題 | コーデの正解がわからない。ネットで服を買っても組み合わせが浮かばず、結局いつも同じ格好になる |
| Rakufukuとの出会い | 先輩に「AIがコーデ採点してくれるアプリがある」と教えられ、半信半疑で全身写真を撮ってみたら的確なアドバイスが返ってきた |
| 解決 | 全身写真診断でAIが採点＆改善提案。「靴をレザーにするともっと良くなります」等の具体的アドバイス。足りないアイテムは楽天/Amazon/ZOZOのリンクで即購入可能 |
| 刺さる機能 | コーデ診断、改善提案、外部購入リンク、マネキン画像プレビュー |

### ペルソナ C: おしゃれ好きだが効率も重視（20代女性）

| 項目 | 内容 |
|------|------|
| 名前 | 佐藤美咲（仮名） |
| 背景 | アパレル企業のマーケティング担当。服はたくさん持っているが、仕事で疲れた朝は「いつもの組み合わせ」に逃げがち |
| 課題 | クローゼットにたくさん服があるのに、いつも同じ組み合わせになる。せっかく買ったトレンドアイテムを活かしきれていない |
| Rakufukuとの出会い | 「AIが自分のクローゼットの中身を全部覚えてくれるなら、意外な組み合わせを発見できるかも」と興味を持った |
| 解決 | ユニークエージェントが「テラコッタのスカート × カーキのジャケット」など意外な組み合わせを提案。「こんな着方があったのか」という発見が毎朝ある |
| 刺さる機能 | 4スタイルの多様な提案、スワイプ嗜好学習、トレンドカラー活用 |

---

## 6. 記事内で使える図解提案

### 6.1 Google Cloud アーキテクチャ図

```
[ユーザー (Flutter App)]
        |
    [FastAPI Backend]
        |
  +-----+-----+-----+-----+
  |     |     |     |     |
[Weather][Calendar][Closet][Preference]
  API    API  Firestore  Firestore
  |     |     |     |
  +-----+-----+-----+
        |
  [Orchestrator]
   /   |   |   \
[Casual][Formal][Balanced][Unique]  ← Gemini 2.0 Flash × 4 (並列)
   \   |   |   /
  [スコアリング & 多様性保証 & Top5選出]
        |
  [Imagen 4 Fast マネキン画像生成]
        |
  [Cloud Storage アップロード]
        |
  [レスポンス → Flutter表示]
```

**使用 Google Cloud サービス一覧:**
| サービス | 用途 |
|---------|------|
| Vertex AI Gemini 2.0 Flash | コーデ提案（4エージェントの思考エンジン） |
| Vertex AI Gemini 2.5 Flash | コーデ診断（マルチモーダル評価）、アイテム詳細分析 |
| Vertex AI Imagen 4 Fast | マネキン画像生成（9:16縦長） |
| Cloud Vision API | 全身写真からのアイテム物体検出 |
| Cloud Firestore | ユーザーデータ、クローゼット、嗜好プロファイル、スワイプ履歴 |
| Cloud Storage | マネキン画像保存・配信 |
| Cloud Run (想定) | FastAPIバックエンドのホスティング |

### 6.2 パイプラインフロー図

```
[入力コンテキスト]
  天気: 22度/晴れ
  予定: 午後会議
  クローゼット: 30アイテム
  嗜好: カジュアル寄り
      |
[Gemini 2.0 Flash × 4エージェント] (asyncio.gather並列)
  Casual Agent → コーデA (base_score: 78)
  Formal Agent → コーデB (base_score: 82)
  Balanced Agent → コーデC (base_score: 85)
  Unique Agent → コーデD (base_score: 71)
      |
[オーケストレーター]
  多様性保証: 各エージェントから最低1つ採用
  TPOボーナス: 会議あり → Formal +10, Casual -5
  嗜好ボーナス: カジュアル好き → Casual +3
  最終スコア計算 → Top5選出 → 最高スコアに「おすすめ」ラベル
      |
[Imagen 4 Fast]
  Geminiが生成した英語プロンプト(image_prompt_en)優先
  → マネキン画像5枚生成 → Cloud Storage アップロード
      |
[ユーザーに5つのコーデ提案]
  スワイプで承認/却下 → 嗜好プロファイル3軸更新(EMA + 色 + フォーマリティ)
```

### 6.3 Before / After 比較

| | Before (従来) | After (Rakufuku) |
|---|---|---|
| 朝の服選び | クローゼットを眺めて15分悩む | AIが5パターン提案、1タップ選択 |
| TPO対応 | 自分で判断（失敗リスクあり） | カレンダー連携で自動判定 |
| 天気対応 | 天気アプリを別途確認 | 気温・天候を自動反映 |
| コーデの多様性 | いつも同じパターン | 4スタイルAIが毎回異なる提案 |
| 好みの反映 | 自分の感覚頼み | スワイプで学習、使うほど精度向上 |
| 足りないアイテム | ショップを自分で探す | 楽天/Amazon/ZOZOのリンク付きで提案 |
| コーデチェック | 鏡で自己判断 | AI採点 + 改善アドバイス |
| クローゼット活用 | 7割が死蔵 | AI が全アイテムを把握し意外な組み合わせを発見 |

---

## 7. SEOキーワード候補

### メインキーワード

- Google Cloud ハッカソン AI コーデ
- Agentic AI マルチエージェント ファッション
- Vertex AI Gemini コーデ 自動生成
- AI コーディネート 提案 アプリ
- Imagen 4 画像生成 ファッション

### ロングテールキーワード

- Gemini 2.0 Flash マルチエージェント 実装 Python
- Vertex AI Imagen 4 Fast マネキン画像 生成
- Python asyncio マルチエージェント 並列実行 パターン
- スワイプ 嗜好学習 指数移動平均 EMA
- Cloud Vision API 服 検出 コーデ診断
- Vertex AI 構造化JSON出力 response_mime_type application/json
- Flutter FastAPI Vertex AI アプリ 開発
- Agentic AI Hackathon Google Cloud 開発記
- 毎朝 服選び 時短 AI 自動化
- クローゼット デジタル化 AI管理 死蔵率
- Google Cloud ハッカソン 参戦記 2025
- マルチエージェント オーケストレーター パターン 設計

---

## 8. SNSシェア用短文案

### Twitter / X 用（5案）

1. > 4人のAIスタイリストが毎朝コーデを考えてくれるアプリ作った。Gemini 2.0 Flash で提案 → Imagen 4 Fast で着せ替え画像生成 → スワイプで好み学習。#AgenticAI #GoogleCloud #VertexAI #ハッカソン

2. > 「今日なに着よう？」をAIに丸投げできるアプリ Rakufuku。天気・予定・好みを全部加味して5パターン提案してくれる。Google Cloud フル活用の設計と実装を記事にしました

3. > asyncio.gatherで4エージェント並列実行 → オーケストレーターがスコアリング → Imagen 4 Fastで画像生成。Vertex AI マルチエージェントの実践パターンまとめた #Python #VertexAI #AgenticAI

4. > スワイプするだけでAIが服の好みを学習する仕組み、指数移動平均(alpha=0.1)で実装したら思った以上にいい感じに収束した。Gemini + Firestore のコード付きで解説

5. > Gemini に response_mime_type="application/json" を指定すると構造化出力が安定する。ただしGeminiが存在しないIDを「幻覚」するので自動変換フォールバックも必須。その設計パターンを紹介 #Gemini #VertexAI

### LinkedIn 用（2案）

1. > 第4回 Agentic AI Hackathon with Google Cloud にて、マルチエージェントAIファッションコーディネート提案システム「Rakufuku」を開発しました。Google Cloud の Vertex AI（Gemini 2.0 Flash + Imagen 4 Fast）を中核に、Cloud Vision API / Firestore / Cloud Storage をフル活用。4つの専門スタイリストエージェントが並列でコーデを生成し、天気・予定・嗜好を加味してスコアリング。スワイプUIによる嗜好学習パイプラインも実装しています。技術詳細を記事にまとめましたので、AI x プロダクト開発に興味のある方はぜひご覧ください。

2. > 「手持ちの服を最大活用する」── この課題に Google Cloud のマルチエージェントAIで挑みました。既存のファッションAIは「新しい服を買わせる」ものが大半ですが、Rakufuku はクローゼットの中身を起点にコーデを最適化します。マルチエージェント設計、Gemini構造化出力、Imagen画像生成、嗜好学習 ── 複数のAI技術を統合する中で得た設計知見は、ファッション以外のドメインにも応用可能です。

---

## 9. コードスニペット詳細提案

記事の中で実際のコードとして掲載すると効果的な箇所を、ファイルパスと正確な行番号付きで提案します。

### [A] マルチエージェント並列実行パターン（最重要）

**ファイル**: `backend/agent/orchestrator.py:91-99`

4つのエージェントを `asyncio.gather` で並列起動し、例外もキャッチ。マルチエージェントの核心部分。

```python
# Run all agents in parallel
tasks = [
    self.agents["casual"].generate_outfit(user_id, context),
    self.agents["formal"].generate_outfit(user_id, context),
    self.agents["balanced"].generate_outfit(user_id, context),
    self.agents["unique"].generate_outfit(user_id, context),
]

try:
    results = await asyncio.gather(*tasks, return_exceptions=True)
except Exception as e:
    logger.error(f"Agent execution failed: {e}")
    return []
```

### [B] エージェント多様性保証アルゴリズム

**ファイル**: `backend/agent/orchestrator.py:242-264`

各エージェントタイプから最低1つは採用する多様性保証ロジック。「いつも同じ提案」を防ぐ設計上の工夫。

```python
def _ensure_agent_diversity(self, outfits: List[Dict]) -> List[Dict]:
    agent_types = ['casual', 'formal', 'balanced', 'unique']
    guaranteed = []

    for agent_type in agent_types:
        candidates = [o for o in outfits if o.get('agent_type') == agent_type
                      and o.get('final_score', 0) > 0]
        if candidates:
            best = max(candidates, key=lambda x: x.get('final_score', 0))
            guaranteed.append(best)

    return guaranteed
```

### [C] Gemini構造化出力 + ハルシネーション対策バリデーション

**ファイル**: `backend/agent/tools/gemini_outfit_composer.py:237-241`

Gemini応答のJSONパース後、クローゼットIDバリデーション。LLMが存在しないアイテムIDを「幻覚」した場合、自動的に外部アイテムに変換する防御パターン。

```python
# クローゼットに存在しないIDをGeminiが生成した場合、外部アイテムに変換
if item.get("item_source") == "closet":
    if item.get("id") and item["id"] not in valid_ids:
        logger.warning(f"Gemini selected non-existent closet item: {item['id']}, converting to external")
        item["item_source"] = "external"
        item["search_keyword"] = item.get("name", "ファッションアイテム")
```

### [D] Imagen 4 Fast プロンプト構築（2段階設計）

**ファイル**: `backend/agent/tools/nano_banana.py:164-197`

Geminiが生成した英語プロンプト（image_prompt_en）を優先し、日本語混入を防ぐ2段階プロンプト設計。フォールバックとしてアイテム情報からの構築も用意。

```python
# Use Gemini's English description if available (preferred - avoids Japanese in prompt)
if image_prompt_en:
    outfit_sentence = image_prompt_en
else:
    # Fallback: build from items (may contain Japanese text)
    outfit_parts = []
    for item in items:
        name = item.get("name", "")
        color = item.get("color", "")
        # ...build from individual items

prompt = f"""A single {gender_term} fashion mannequin wearing a complete \
{style_desc} {season_hint} outfit: {outfit_sentence}. ...
CRITICAL: Show exactly ONE mannequin only. All clothing items must be \
worn ON the mannequin body. ..."""
```

### [E] 嗜好学習: スタイル・色・フォーマリティの3軸同時更新

**ファイル**: `backend/agent/tools/preference_learner.py:62-136`

スワイプ1回で3つの軸を同時更新。スタイルスコアはEMA(alpha=0.1)、色嗜好は固定デルタ(+-5)、フォーマリティは承認時のみカウント。

```python
# スタイルスコア: 指数移動平均 (STYLE_SCORE_ALPHA = 0.1)
reward = 100 if action == "approve" else 0
new_score = current_score * (1 - STYLE_SCORE_ALPHA) + reward * STYLE_SCORE_ALPHA

# 色嗜好: 固定デルタ (COLOR_PREFERENCE_DELTA = 5)
delta = COLOR_PREFERENCE_DELTA if action == "approve" else -COLOR_PREFERENCE_DELTA
new_pref = max(0, min(100, current_pref + delta))

# フォーマリティ: 承認時のみカウント
delta = 1 if action == "approve" else 0
profile["formality_distribution"][formality] = current_count + delta
```

### [F] コンテキスト統合エントリポイント（5段階パイプライン）

**ファイル**: `backend/agent/integration_helper.py:22-148`

Weather API → Calendar API → Preference Profile → Orchestrator → Cache という5段階パイプラインを1関数で統合。各ステップにフォールバックを用意し、どこで障害が起きても全体が止まらない設計。

```python
async def generate_daily_outfits_with_cache(user_id, latitude, longitude, ...):
    # 1. 天気取得（失敗時: デフォルト値でフォールバック）
    weather = await weather_tool(latitude=latitude, longitude=longitude)

    # 2. カレンダー取得（失敗時: casual デフォルト）
    calendar_data = await calendar_tool(user_id=user_id, ...)
    tpo = calendar_data.get("tpo", {})

    # 3. 嗜好プロファイル取得（失敗時: 初期値）
    user_preferences = await get_preference_profile(user_id)

    # 4. オーケストレーター実行 + キャッシュ
    result = await get_or_generate_daily_recommendations(
        ..., generator_func=outfit_generator)

    return result
```

### [G] コーデ診断: 4段階AI分析パイプライン

**ファイル**: `backend/agent/tools/outfit_analyzer.py:413-464`

Gemini 2.5 Flash評価 → Cloud Vision物体検出 → Gemini 2.5 Flash詳細分析 → 画像クロップの4段階パイプライン。Cloud Vision失敗時はGemini 2.5 Flashフォールバックで冗長化。

```python
async def analyze_outfit_photo(image_base64, image_url, context):
    # 1. Gemini Vision でコーデ全体を評価（10点満点スコア + 改善提案）
    evaluation = await evaluate_outfit_with_gemini(image_base64, context)

    # 2. Cloud Vision API でアイテム物体検出（失敗時 → Geminiフォールバック）
    try:
        detected_items = await detect_items_with_cloud_vision(image_base64)
    except Exception:
        detected_items = await fallback_detect_items_with_gemini(image_base64)

    # 3. Gemini で各アイテムの詳細分析（色・素材感）
    detected_items = await analyze_item_details_with_gemini(image_base64, detected_items)

    # 4. バウンディングボックスで画像クロップ
    detected_items = await crop_detected_items(image_base64, detected_items)

    return OutfitAnalysisResult(evaluation, detected_items, context)
```
