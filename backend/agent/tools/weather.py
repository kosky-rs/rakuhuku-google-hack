"""Weather Tool - 天気・気温情報を取得"""
import os
import httpx
from typing import Optional


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
        {
            "weather": "晴れ",
            "temperature": 18,
            "feels_like": 16,
            "humidity": 45,
            "precipitation_probability": 10,
            "description": "晴れ、18°C、降水確率10%"
        }
    """
    api_key = os.getenv("OPENWEATHER_API_KEY")

    if not api_key:
        # デモ用のモックデータを返す
        return {
            "weather": "晴れ",
            "temperature": 18,
            "feels_like": 16,
            "humidity": 45,
            "precipitation_probability": 10,
            "description": "晴れ、18°C、降水確率10%"
        }

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

    return {
        "weather": weather_ja,
        "temperature": temp,
        "feels_like": feels_like,
        "humidity": humidity,
        "precipitation_probability": 0,  # 基本APIには含まれない
        "description": f"{weather_ja}、{temp}°C、体感温度{feels_like}°C"
    }


# ADK Tool として公開
weather_tool = get_weather
