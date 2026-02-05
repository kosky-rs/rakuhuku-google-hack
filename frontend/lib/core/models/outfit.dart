import 'clothing_item.dart';

/// Outfit recommendation model
class OutfitRecommendation {
  final List<ClothingItem> items;
  final double score;
  final String feedback;

  const OutfitRecommendation({
    required this.items,
    required this.score,
    required this.feedback,
  });

  factory OutfitRecommendation.fromJson(Map<String, dynamic> json) {
    return OutfitRecommendation(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'score': score,
      'feedback': feedback,
    };
  }
}

/// Alternative outfit suggestion
class AlternativeOutfit {
  final List<ClothingItem> items;
  final String description;

  const AlternativeOutfit({
    required this.items,
    required this.description,
  });

  factory AlternativeOutfit.fromJson(Map<String, dynamic> json) {
    return AlternativeOutfit(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      description: json['description'] as String? ?? '',
    );
  }
}

/// Daily outfit proposal response
class DailyOutfitProposal {
  final Weather weather;
  final TPO tpo;
  final OutfitRecommendation recommendation;
  final List<AlternativeOutfit> alternatives;
  final EvaluationDetails? evaluationDetails;

  const DailyOutfitProposal({
    required this.weather,
    required this.tpo,
    required this.recommendation,
    required this.alternatives,
    this.evaluationDetails,
  });

  factory DailyOutfitProposal.fromJson(Map<String, dynamic> json) {
    return DailyOutfitProposal(
      weather: Weather.fromJson(json['weather'] as Map<String, dynamic>),
      tpo: TPO.fromJson(json['tpo'] as Map<String, dynamic>),
      recommendation: OutfitRecommendation.fromJson(
          json['recommendation'] as Map<String, dynamic>),
      alternatives: (json['alternatives'] as List<dynamic>?)
              ?.map((e) => AlternativeOutfit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      evaluationDetails: json['evaluation_details'] != null
          ? EvaluationDetails.fromJson(
              json['evaluation_details'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Weather information
class Weather {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final String condition;
  final String description;
  final String recommendation;

  const Weather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.condition,
    required this.description,
    required this.recommendation,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 20.0,
      feelsLike: (json['feels_like'] as num?)?.toDouble() ?? 20.0,
      humidity: json['humidity'] as int? ?? 50,
      condition: json['condition'] as String? ?? 'clear',
      description: json['description'] as String? ?? 'Clear sky',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  String get temperatureDisplay => '${temperature.round()}°C';

  String get icon {
    switch (condition.toLowerCase()) {
      case 'clear':
        return 'wb_sunny';
      case 'clouds':
      case 'cloudy':
        return 'cloud';
      case 'rain':
        return 'rainy';
      case 'snow':
        return 'ac_unit';
      case 'thunderstorm':
        return 'thunderstorm';
      default:
        return 'wb_sunny';
    }
  }
}

/// TPO (Time, Place, Occasion) information
class TPO {
  final String summary;
  final String formalityRequired;
  final String occasion;
  final List<String> activities;

  const TPO({
    required this.summary,
    required this.formalityRequired,
    required this.occasion,
    required this.activities,
  });

  factory TPO.fromJson(Map<String, dynamic> json) {
    return TPO(
      summary: json['summary'] as String? ?? 'Normal Day',
      formalityRequired:
          json['formality_required'] as String? ?? 'smart_casual',
      occasion: json['occasion'] as String? ?? 'general',
      activities: (json['activities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Evaluation details for outfit
class EvaluationDetails {
  final double totalScore;
  final double weatherScore;
  final double tpoScore;
  final double colorScore;
  final String feedback;

  const EvaluationDetails({
    required this.totalScore,
    required this.weatherScore,
    required this.tpoScore,
    required this.colorScore,
    required this.feedback,
  });

  factory EvaluationDetails.fromJson(Map<String, dynamic> json) {
    return EvaluationDetails(
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
      weatherScore: (json['weather_score'] as num?)?.toDouble() ?? 0.0,
      tpoScore: (json['tpo_score'] as num?)?.toDouble() ?? 0.0,
      colorScore: (json['color_score'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback'] as String? ?? '',
    );
  }
}
