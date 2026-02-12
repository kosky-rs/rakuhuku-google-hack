"""Weather Tool - 天気・気温情報を取得"""
import os
import httpx


async def get_weather(
    latitude: float = 35.6762,  # 東京のデフォルト座標
    longitude: float = 139.6503,
) -> dict:
    """
    指定された位置の天気情報を取得します。

    Args:
        latitude: 緯度（デフォルト: 東京）
        longitude: 経度（デフォルト: 東京）

    Returns:
        天気情報を含む辞書

    Raises:
        ValueError: OPENWEATHER_API_KEY が設定されていない場合
    """
    api_key = os.getenv("OPENWEATHER_API_KEY")

    if not api_key:
        raise ValueError("OPENWEATHER_API_KEY environment variable is required")

    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {
        "lat": latitude,
        "lon": longitude,
        "appid": api_key,
        "units": "metric",
        "lang": "ja"
    }

    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        data = response.json()

    weather_main = data.get("weather", [{}])[0].get("main", "不明")
    weather_desc = data.get("weather", [{}])[0].get("description", "不明")
    temp = round(data.get("main", {}).get("temp", 20))
    feels_like = round(data.get("main", {}).get("feels_like", 20))
    humidity = data.get("main", {}).get("humidity", 50)

    # 天気を日本語に変換
    weather_ja_map = {
        "Clear": "晴れ",
        "Clouds": "曇り",
        "Rain": "雨",
        "Snow": "雪",
        "Thunderstorm": "雷雨",
        "Drizzle": "小雨",
        "Mist": "霧",
        "Fog": "霧",
    }
    weather_ja = weather_ja_map.get(weather_main, weather_desc)

    # 天気に基づく服装アドバイスを生成
    recommendation = _get_weather_recommendation(weather_main, temp, feels_like, humidity)

    return {
        "weather": weather_ja,
        "condition": weather_main.lower(),
        "temperature": temp,
        "feels_like": feels_like,
        "humidity": humidity,
        "precipitation_probability": 0,  # 基本APIには含まれない
        "description": f"{weather_ja}、{temp}°C、体感温度{feels_like}°C",
        "recommendation": recommendation,
    }


def _get_weather_recommendation(condition: str, temp: int, feels_like: int, humidity: int) -> str:
    """天気に基づく服装アドバイスを生成"""
    parts = []

    if condition in ("Rain", "Drizzle"):
        parts.append("傘をお忘れなく。防水素材がおすすめです")
    elif condition == "Snow":
        parts.append("雪対策に防水ブーツがおすすめです")
    elif condition == "Thunderstorm":
        parts.append("雷雨の予報です。外出は最小限に")

    if feels_like < 5:
        parts.append("厳しい寒さです。厚手のアウターやマフラーを")
    elif feels_like < 10:
        parts.append("冷え込みます。暖かいアウターを羽織りましょう")
    elif feels_like < 15:
        parts.append("少し肌寒い日です。軽いアウターがあると安心")
    elif feels_like > 30:
        parts.append("猛暑日です。通気性の良い服装で熱中症対策を")
    elif feels_like > 25:
        parts.append("暑い日です。涼しい素材の服がおすすめ")

    if humidity > 80 and condition not in ("Rain", "Drizzle", "Snow", "Thunderstorm"):
        parts.append("湿度が高めです。さらっとした素材が快適")

    if not parts:
        parts.append("過ごしやすい天気です。お好みのコーデを楽しんで")

    return "。".join(parts)


# ADK Tool として公開
weather_tool = get_weather
