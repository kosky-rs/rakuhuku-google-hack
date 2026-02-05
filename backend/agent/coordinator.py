"""Poltan Coordinator Agent - メインエージェント"""
from google.adk.agents import Agent
from google.adk.tools import FunctionTool

from .tools.weather import weather_tool
from .tools.closet import closet_tool
from .tools.calendar import calendar_tool
from .tools.style_advisor import style_advisor_tool


# ツールの定義
weather_function = FunctionTool(
    func=weather_tool,
    name="get_weather",
    description="指定された位置の天気情報（天気、気温、体感温度、湿度）を取得します。"
)

closet_function = FunctionTool(
    func=closet_tool,
    name="get_closet_items",
    description="ユーザーのクローゼットからアイテムを検索します。カテゴリ、季節、フォーマル度でフィルタリング可能です。"
)

calendar_function = FunctionTool(
    func=calendar_tool,
    name="get_calendar_events",
    description="ユーザーの予定を取得し、TPO（時間・場所・場面）情報を判定します。"
)

style_advisor_function = FunctionTool(
    func=style_advisor_tool,
    name="evaluate_outfit",
    description="コーディネートを評価してスコアとフィードバックを返します。"
)


# メインエージェントの定義
poltan_agent = Agent(
    name="poltan_coordinator",
    model="gemini-2.0-flash",
    tools=[
        weather_function,
        closet_function,
        calendar_function,
        style_advisor_function,
    ],
    instruction="""
あなたは「Poltan（ポルタン）」、優秀なスタイリストアシスタントです。
ユーザーの今日の予定、天気、手持ちの服を考慮して、最適なコーディネートを提案してください。

## あなたの性格
- 親しみやすく、でも的確
- 提案は簡潔で分かりやすい
- ユーザーの時間を大切にする

## 提案のプロセス
1. まず天気情報を取得して、気温や天候を確認
2. カレンダーから今日の予定を確認してTPOを判定
3. クローゼットから条件に合う服を検索
4. 最適な組み合わせを選び、スタイルアドバイザーで評価
5. 最終提案を作成

## 提案フォーマット
提案には以下を含めてください：

### 今日のおすすめコーデ
**選んだアイテム:**
- トップス: [アイテム名]
- ボトムス: [アイテム名]
- アウター: [アイテム名]（必要な場合）
- シューズ: [アイテム名]

**選んだ理由:**
（1-2文で簡潔に）

### 代替案
もし気分が違うなら...
1. [代替案1の説明]
2. [代替案2の説明]

## 注意事項
- 必ずユーザーの手持ちの服から提案すること
- 気温に合わない服は提案しない
- TPOを最優先に考える
- 代替案は最大2つまで
""",
)


async def get_outfit_recommendation(
    user_id: str = "demo_user",
    target_date: str | None = None,
    latitude: float = 35.6762,
    longitude: float = 139.6503,
) -> dict:
    """
    コーディネート提案を取得するメイン関数

    Args:
        user_id: ユーザーID
        target_date: 対象日付（YYYY-MM-DD形式）
        latitude: 緯度
        longitude: 経度

    Returns:
        提案結果
    """
    # エージェントにプロンプトを送信
    prompt = f"""
今日のコーディネートを提案してください。
ユーザーID: {user_id}
日付: {target_date or "今日"}
位置: 緯度{latitude}, 経度{longitude}
"""

    # ADKエージェントを実行
    response = await poltan_agent.run(prompt)

    return {
        "recommendation": response.text,
        "user_id": user_id,
        "date": target_date,
    }
