# ADKエージェント設計書

## 1. 概要

ラクフクはGoogle ADK（Agent Development Kit）を使用してAIエージェントを構築します。

### 1.1 エージェント構成

```
┌─────────────────────────────────────────────────────────────────┐
│                   ラクフク Coordinator Agent                       │
│                   (メインエージェント)                            │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                     System Instruction                       │ │
│  │  - スタイリストとしての振る舞い                              │ │
│  │  - 提案フォーマットの定義                                    │ │
│  │  - 判断基準の設定                                            │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ Weather  │ │ Calendar │ │ Closet   │ │ Style    │           │
│  │ Tool     │ │ Tool     │ │ Tool     │ │ Advisor  │           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. メインエージェント

### 2.1 基本設定

```python
from google.adk.agents import Agent
from google.adk.tools import FunctionTool

rakufuku_agent = Agent(
    name="rakufuku_coordinator",
    model="gemini-2.0-flash",
    tools=[
        weather_tool,
        calendar_tool,
        closet_tool,
        style_advisor_tool,
    ],
    instruction=SYSTEM_INSTRUCTION,
)
```

### 2.2 System Instruction

```markdown
# ラクフク - AIスタイリストアシスタント

あなたは「ラクフク（ポルタン）」、優秀なスタイリストアシスタントです。
ユーザーの今日の予定、天気、手持ちの服を考慮して、最適なコーディネートを提案してください。

## あなたの性格
- 親しみやすく、でも的確
- 提案は簡潔で分かりやすい
- ユーザーの時間を大切にする
- ネガティブな表現は避け、ポジティブな言い回しを使う

## 提案のプロセス

以下の順序で情報を収集し、提案を作成してください：

1. **天気情報を取得**
   - get_weather ツールを使用
   - 気温、天候、降水確率を確認

2. **カレンダーから予定を確認**
   - get_calendar_events ツールを使用
   - 最も重要な予定を特定（TPO判定）

3. **クローゼットから服を検索**
   - get_closet_items ツールを使用
   - TPOに合うフォーマル度でフィルタリング
   - 季節に合うアイテムを選択

4. **コーディネートを評価**
   - evaluate_outfit ツールを使用
   - 色の調和、TPOマッチ度をスコアリング

5. **最終提案を作成**
   - メイン提案1つ + 代替案最大2つ

## 提案フォーマット

必ず以下のフォーマットで提案してください：

---

### 今日のおすすめコーデ

**天気**: [天気] [気温]°C
**メインの予定**: [予定名]

**選んだアイテム:**
- トップス: [アイテム名]
- ボトムス: [アイテム名]
- アウター: [アイテム名]（気温20°C以下の場合）
- シューズ: [アイテム名]

**選んだ理由:**
（1-2文で簡潔に、なぜこの組み合わせがベストか）

**スコア**: [数値]/100

---

### もし気分が違うなら...

1. **[代替案1のタイトル]**
   - [変更点の説明]

2. **[代替案2のタイトル]**
   - [変更点の説明]

---

## 判断基準

### TPO優先度（高い順）
1. クライアント対応・商談 → formal
2. 社内会議・通常勤務 → business_casual
3. カジュアル・プライベート → casual

### 気温による判断
- 25°C以上: アウター不要、涼しい素材推奨
- 20-24°C: 軽いアウターはオプション
- 15-19°C: アウター推奨
- 15°C未満: アウター必須

### 色の組み合わせ（推奨）
- ネイビー + 白: 清潔感、信頼感
- グレー + 白: 落ち着き、知的
- ベージュ + ネイビー: 親しみやすさ

## 注意事項

- 必ずユーザーの手持ちの服から提案すること
- 存在しないアイテムを提案しない
- 気温に合わない服は提案しない（夏に冬物など）
- 代替案は最大2つまで
- 不足しているアイテムがあれば、それを伝える
```

---

## 3. ツール定義

### 3.1 Weather Tool

**目的**: 指定位置の天気情報を取得

```python
from google.adk.tools import FunctionTool

weather_tool = FunctionTool(
    func=get_weather,
    name="get_weather",
    description="""
指定された位置の天気情報を取得します。

Parameters:
- latitude (float, optional): 緯度。デフォルト: 35.6762（東京）
- longitude (float, optional): 経度。デフォルト: 139.6503（東京）

Returns:
- weather: 天気（晴れ、曇り、雨など）
- temperature: 気温（℃）
- feels_like: 体感温度（℃）
- humidity: 湿度（%）
- precipitation_probability: 降水確率（%）
- description: 天気の説明文
"""
)
```

**入力スキーマ:**
```json
{
  "type": "object",
  "properties": {
    "latitude": {
      "type": "number",
      "description": "緯度"
    },
    "longitude": {
      "type": "number",
      "description": "経度"
    }
  }
}
```

**出力例:**
```json
{
  "weather": "晴れ",
  "temperature": 18,
  "feels_like": 16,
  "humidity": 45,
  "precipitation_probability": 10,
  "description": "晴れ、18°C、降水確率10%"
}
```

---

### 3.2 Calendar Tool

**目的**: ユーザーの予定を取得しTPOを判定

```python
calendar_tool = FunctionTool(
    func=get_calendar_events,
    name="get_calendar_events",
    description="""
ユーザーの予定を取得し、TPO（Time, Place, Occasion）情報を判定します。

Parameters:
- user_id (str, optional): ユーザーID。デフォルト: "demo_user"
- target_date (str, optional): 対象日付（YYYY-MM-DD形式）。デフォルト: 今日

Returns:
- events: 予定のリスト
- tpo: TPO判定結果
  - formality_required: 必要なフォーマル度（casual/business_casual/formal）
  - main_event: 最も重要な予定の名前
  - recommendation: 服装の推奨事項
"""
)
```

**出力例:**
```json
{
  "events": [
    {
      "id": "1",
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
```

---

### 3.3 Closet Tool

**目的**: ユーザーのクローゼットからアイテムを検索

```python
closet_tool = FunctionTool(
    func=get_closet_items,
    name="get_closet_items",
    description="""
ユーザーのクローゼットからアイテムを検索します。

Parameters:
- user_id (str, optional): ユーザーID
- category (str, optional): カテゴリでフィルタ
  - "tops": トップス
  - "bottoms": ボトムス
  - "outerwear": アウター
  - "shoes": シューズ
  - "accessories": アクセサリー
- season (str, optional): 季節でフィルタ
  - "spring", "summer", "autumn", "winter"
- formality (str, optional): フォーマル度でフィルタ
  - "casual", "business_casual", "formal"

Returns:
- アイテムのリスト（各アイテムにはid, name, category, color, formality, tagsが含まれる）
"""
)
```

**出力例:**
```json
[
  {
    "id": "1",
    "name": "ネイビージャケット",
    "category": "outerwear",
    "color": "navy",
    "season": ["spring", "autumn", "winter"],
    "formality": "formal",
    "tags": ["定番", "商談向け"]
  },
  {
    "id": "2",
    "name": "白シャツ",
    "category": "tops",
    "color": "white",
    "season": ["spring", "summer", "autumn", "winter"],
    "formality": "formal",
    "tags": ["清潔感", "万能"]
  }
]
```

---

### 3.4 Style Advisor Tool

**目的**: コーディネートを評価しスコアとフィードバックを返す

```python
style_advisor_tool = FunctionTool(
    func=evaluate_outfit,
    name="evaluate_outfit",
    description="""
コーディネートを評価してスコアとフィードバックを返します。

Parameters:
- items (list): 選択したアイテムのリスト
  - 各アイテムには id, name, category, color, formality が必要
- weather (dict): 天気情報
- tpo (dict): TPO情報（formality_required を含む）
- current_season (str, optional): 現在の季節

Returns:
- total_score: 総合スコア（0-100）
- color_harmony: 色の調和スコア
- formality_match: TPOマッチスコア
- season_match: 季節マッチスコア
- style_balance: スタイルバランススコア
- feedback: フィードバックコメント
"""
)
```

**出力例:**
```json
{
  "total_score": 92,
  "color_harmony": 95,
  "formality_match": 90,
  "season_match": 90,
  "style_balance": 93,
  "feedback": "ネイビージャケットと白シャツの組み合わせは相性抜群。クライアントMTGにぴったりのスタイルです。"
}
```

---

## 4. エージェント実行フロー

### 4.1 シーケンス図

```
User                 App                  Agent               Tools
 │                    │                     │                   │
 │ アプリ起動         │                     │                   │
 │──────────────────▶│                     │                   │
 │                    │ 提案リクエスト       │                   │
 │                    │────────────────────▶│                   │
 │                    │                     │                   │
 │                    │                     │ get_weather       │
 │                    │                     │──────────────────▶│
 │                    │                     │◀──────────────────│
 │                    │                     │                   │
 │                    │                     │ get_calendar      │
 │                    │                     │──────────────────▶│
 │                    │                     │◀──────────────────│
 │                    │                     │                   │
 │                    │                     │ get_closet_items  │
 │                    │                     │──────────────────▶│
 │                    │                     │◀──────────────────│
 │                    │                     │                   │
 │                    │                     │ evaluate_outfit   │
 │                    │                     │──────────────────▶│
 │                    │                     │◀──────────────────│
 │                    │                     │                   │
 │                    │◀────────────────────│                   │
 │◀──────────────────│ 提案表示             │                   │
 │                    │                     │                   │
```

### 4.2 サンプル実行ログ

```
[Agent] Starting recommendation process...
[Agent] Calling tool: get_weather(latitude=35.6762, longitude=139.6503)
[Tool:weather] Response: {"weather": "晴れ", "temperature": 18, ...}
[Agent] Calling tool: get_calendar_events(user_id="demo_user")
[Tool:calendar] Response: {"events": [...], "tpo": {"formality_required": "formal", ...}}
[Agent] Calling tool: get_closet_items(user_id="demo_user", formality="formal", season="winter")
[Tool:closet] Response: [{"name": "ネイビージャケット", ...}, ...]
[Agent] Calling tool: evaluate_outfit(items=[...], weather={...}, tpo={...})
[Tool:style_advisor] Response: {"total_score": 92, ...}
[Agent] Generating final recommendation...
[Agent] Done.
```

---

## 5. 将来の拡張

### 5.1 マルチエージェント構成（Phase 2）

```
┌─────────────────────────────────────────────────────────────────┐
│                   ラクフク Orchestrator                            │
│                   (オーケストレーター)                           │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Weather      │  │ Style        │  │ Learning     │          │
│  │ Analyst      │  │ Curator      │  │ Agent        │          │
│  │ Agent        │  │ Agent        │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 パーソナライゼーション強化（Phase 3）

- フィードバック学習
- スタイル傾向分析
- 季節・イベント別最適化
