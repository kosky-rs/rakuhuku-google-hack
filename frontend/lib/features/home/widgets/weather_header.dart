import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../core/models/outfit.dart';

/// Weather and TPO header widget
class WeatherHeader extends StatelessWidget {
  final Weather weather;
  final TPO tpo;

  const WeatherHeader({
    super.key,
    required this.weather,
    required this.tpo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // Weather info row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getWeatherIcon(weather.condition),
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '東京 • ${weather.temperatureDisplay} ${weather.description}',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // TPO summary
          Text(
            '今日: ${tpo.summary}',
            style: AppTextStyles.bodyLarge.copyWith(
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          // Weather recommendation
          Text(
            weather.recommendation.isNotEmpty
                ? weather.recommendation
                : '選んだコーデにぴったりの天気です',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
      case 'cloudy':
        return Icons.cloud;
      case 'rain':
        return Icons.water_drop;
      case 'snow':
        return Icons.ac_unit;
      case 'thunderstorm':
        return Icons.thunderstorm;
      default:
        return Icons.wb_sunny;
    }
  }
}
