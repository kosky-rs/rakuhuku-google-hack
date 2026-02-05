"""Calendar Tool - Google Calendar から予定を取得"""
from datetime import datetime, date
from typing import Optional
from pydantic import BaseModel


class CalendarEvent(BaseModel):
    """カレンダーの予定"""
    id: str
    title: str
    start_time: str
    end_time: str
    event_type: str  # meeting, client_meeting, casual, date, exercise, other
    location: Optional[str] = None
    description: Optional[str] = None


# デモ用のモックデータ
def get_mock_events(target_date: date) -> list[CalendarEvent]:
    """デモ用の予定を生成"""
    weekday = target_date.weekday()

    if weekday < 5:  # 平日
        return [
            CalendarEvent(
                id="1",
                title="朝会",
                start_time="09:00",
                end_time="09:30",
                event_type="meeting",
                location="オフィス"
            ),
            CalendarEvent(
                id="2",
                title="クライアントMTG",
                start_time="14:00",
                end_time="15:30",
                event_type="client_meeting",
                location="会議室A",
                description="新規プロジェクトの提案"
            ),
        ]
    else:  # 週末
        return [
            CalendarEvent(
                id="1",
                title="友人とランチ",
                start_time="12:00",
                end_time="14:00",
                event_type="casual",
                location="イタリアンレストラン"
            ),
        ]


async def get_calendar_events(
    user_id: str = "demo_user",
    target_date: Optional[str] = None,
) -> dict:
    """
    ユーザーの予定を取得し、TPO情報を返します。

    Args:
        user_id: ユーザーID
        target_date: 取得する日付（YYYY-MM-DD形式、デフォルト: 今日）

    Returns:
        予定情報とTPO判定
        {
            "events": [...],
            "tpo": {
                "formality_required": "formal",
                "main_event": "クライアントMTG",
                "recommendation": "商談があるため、フォーマルな服装を推奨"
            }
        }
    """
    if target_date:
        date_obj = datetime.strptime(target_date, "%Y-%m-%d").date()
    else:
        date_obj = date.today()

    # TODO: Google Calendar API から実際のデータを取得
    events = get_mock_events(date_obj)

    # TPO判定
    formality_priority = {
        "client_meeting": 4,
        "meeting": 3,
        "date": 2,
        "casual": 1,
        "exercise": 0,
        "other": 1,
    }

    max_formality = 0
    main_event = None

    for event in events:
        priority = formality_priority.get(event.event_type, 1)
        if priority > max_formality:
            max_formality = priority
            main_event = event

    # フォーマル度の判定
    if max_formality >= 4:
        formality_required = "formal"
        recommendation = f"「{main_event.title}」があるため、フォーマルな服装を推奨します"
    elif max_formality >= 3:
        formality_required = "business_casual"
        recommendation = f"「{main_event.title}」があるため、ビジネスカジュアルを推奨します"
    else:
        formality_required = "casual"
        recommendation = "カジュアルな予定のみです"

    return {
        "events": [event.model_dump() for event in events],
        "tpo": {
            "formality_required": formality_required,
            "main_event": main_event.title if main_event else None,
            "recommendation": recommendation
        }
    }


# ADK Tool として公開
calendar_tool = get_calendar_events
