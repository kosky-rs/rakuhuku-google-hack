"""Calendar Tool - Google Calendar API から予定を取得"""
import logging
from datetime import datetime, date, timezone, timedelta
from typing import Optional

import httpx
from pydantic import BaseModel

logger = logging.getLogger(__name__)


class CalendarEvent(BaseModel):
    """カレンダーの予定"""
    id: str
    title: str
    start_time: str
    end_time: str
    event_type: str  # meeting, client_meeting, casual, date, exercise, other
    location: Optional[str] = None
    description: Optional[str] = None


def _classify_event_type(title: str, description: str = "") -> str:
    """イベントタイトルからTPO分類を推定"""
    text = (title + " " + description).lower()

    # クライアント・商談系
    if any(w in text for w in ["クライアント", "商談", "提案", "プレゼン", "client", "proposal"]):
        return "client_meeting"

    # ミーティング・会議系
    if any(w in text for w in ["会議", "mtg", "meeting", "朝会", "定例", "面談", "1on1"]):
        return "meeting"

    # デート系
    if any(w in text for w in ["デート", "date", "記念日", "anniversary"]):
        return "date"

    # 運動系
    if any(w in text for w in ["ジム", "gym", "ランニング", "ヨガ", "yoga", "運動", "exercise"]):
        return "exercise"

    # カジュアル
    if any(w in text for w in ["ランチ", "飲み会", "友人", "lunch", "dinner", "カフェ"]):
        return "casual"

    return "other"


async def get_calendar_events(
    user_id: str = "demo_user",
    target_date: Optional[str] = None,
    access_token: Optional[str] = None,
) -> dict:
    """
    ユーザーの予定を取得し、TPO情報を返します。

    Args:
        user_id: ユーザーID
        target_date: 取得する日付（YYYY-MM-DD形式、デフォルト: 今日）
        access_token: Google OAuth access_token（フロントエンドから受け渡し）

    Returns:
        予定情報とTPO判定
    """
    if target_date:
        date_obj = datetime.strptime(target_date, "%Y-%m-%d").date()
    else:
        date_obj = date.today()

    events = []

    if access_token:
        # Google Calendar API v3 から実データを取得
        events = await _fetch_google_calendar_events(access_token, date_obj)
    else:
        logger.warning("No access_token provided, returning empty events")

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
    elif main_event:
        formality_required = "casual"
        recommendation = "カジュアルな予定のみです"
    else:
        formality_required = "casual"
        recommendation = "本日の予定はありません。カジュアルな服装でOKです"

    return {
        "events": [event.model_dump() for event in events],
        "tpo": {
            "formality_required": formality_required,
            "main_event": main_event.title if main_event else None,
            "recommendation": recommendation,
            "summary": recommendation,
            "occasion": main_event.event_type if main_event else "general",
            "activities": [event.title for event in events],
        }
    }


async def _fetch_google_calendar_events(
    access_token: str,
    target_date: date,
) -> list[CalendarEvent]:
    """
    Google Calendar API v3 からイベントを取得

    Args:
        access_token: OAuthアクセストークン
        target_date: 取得する日付

    Returns:
        CalendarEventのリスト
    """
    # 当日の開始・終了時刻（JST = UTC+9）
    jst = timezone(timedelta(hours=9))
    time_min = datetime.combine(target_date, datetime.min.time()).replace(tzinfo=jst)
    time_max = datetime.combine(target_date, datetime.max.time()).replace(tzinfo=jst)

    url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    params = {
        "timeMin": time_min.isoformat(),
        "timeMax": time_max.isoformat(),
        "singleEvents": "true",
        "orderBy": "startTime",
        "maxResults": 20,
    }
    headers = {
        "Authorization": f"Bearer {access_token}",
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params, headers=headers)
            response.raise_for_status()
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 401:
                logger.warning("Google Calendar API returned 401 - access token may be expired")
                return []
            logger.error(f"Google Calendar API error: {e.response.status_code} - {e.response.text}")
            return []
        except httpx.RequestError as e:
            logger.error(f"Google Calendar API request failed: {e}")
            return []
        data = response.json()

    events = []
    for item in data.get("items", []):
        title = item.get("summary", "（タイトルなし）")
        description = item.get("description", "")
        location = item.get("location")

        # 開始・終了時刻
        start = item.get("start", {})
        end = item.get("end", {})
        start_time = start.get("dateTime", start.get("date", ""))
        end_time = end.get("dateTime", end.get("date", ""))

        # 時刻部分のみ抽出（表示用）
        if "T" in start_time:
            start_display = start_time.split("T")[1][:5]
        else:
            start_display = "終日"

        if "T" in end_time:
            end_display = end_time.split("T")[1][:5]
        else:
            end_display = "終日"

        event_type = _classify_event_type(title, description)

        events.append(CalendarEvent(
            id=item.get("id", ""),
            title=title,
            start_time=start_display,
            end_time=end_display,
            event_type=event_type,
            location=location,
            description=description,
        ))

    return events


# ADK Tool として公開
calendar_tool = get_calendar_events
