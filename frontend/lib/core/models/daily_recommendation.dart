import 'clothing_item.dart';

/// 日次コーディネート推奨
class DailyRecommendation {
  final String date; // YYYY-MM-DD
  final List<OutfitRecommendation> recommendations;
  final Weather weather;
  final TPO tpo;
  final int generationsRemaining;
  final bool canRegenerate;

  const DailyRecommendation({
    required this.date,
    required this.recommendations,
    required this.weather,
    required this.tpo,
    required this.generationsRemaining,
    required this.canRegenerate,
  });

  factory DailyRecommendation.fromJson(Map<String, dynamic> json) {
    return DailyRecommendation(
      date: json['date'] as String,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => OutfitRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
      weather: Weather.fromJson(json['weather'] as Map<String, dynamic>),
      tpo: TPO.fromJson(json['tpo'] as Map<String, dynamic>),
      generationsRemaining: json['generations_remaining'] as int,
      canRegenerate: json['can_regenerate'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'recommendations': recommendations.map((e) => e.toJson()).toList(),
      'weather': weather.toJson(),
      'tpo': tpo.toJson(),
      'generations_remaining': generationsRemaining,
      'can_regenerate': canRegenerate,
    };
  }
}

/// コーディネート推奨
class OutfitRecommendation {
  final String id;
  final String agentType; // casual, formal, balanced, unique
  final List<ClothingItem> items;
  final double score;
  final String reasoning;
  final String source; // closet or external
  final List<RakutenProduct>? externalProducts;

  const OutfitRecommendation({
    required this.id,
    required this.agentType,
    required this.items,
    required this.score,
    required this.reasoning,
    required this.source,
    this.externalProducts,
  });

  factory OutfitRecommendation.fromJson(Map<String, dynamic> json) {
    return OutfitRecommendation(
      id: json['outfit_id'] as String,
      agentType: json['agent_type'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      score: (json['score'] as num).toDouble(),
      reasoning: json['reasoning'] as String,
      source: json['source'] as String,
      externalProducts: json['external_products'] != null
          ? (json['external_products'] as List<dynamic>)
              .map((e) => RakutenProduct.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outfit_id': id,
      'agent_type': agentType,
      'items': items.map((e) => e.toJson()).toList(),
      'score': score,
      'reasoning': reasoning,
      'source': source,
      if (externalProducts != null)
        'external_products': externalProducts!.map((e) => e.toJson()).toList(),
    };
  }
}

/// 楽天商品
class RakutenProduct {
  final String id;
  final String name;
  final int price;
  final String imageUrl;
  final String shopName;
  final String productUrl;
  final double? reviewAverage;
  final int? reviewCount;

  const RakutenProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.shopName,
    required this.productUrl,
    this.reviewAverage,
    this.reviewCount,
  });

  factory RakutenProduct.fromJson(Map<String, dynamic> json) {
    return RakutenProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      imageUrl: json['image_url'] as String,
      shopName: json['shop_name'] as String,
      productUrl: json['product_url'] as String,
      reviewAverage: json['review_average'] != null
          ? (json['review_average'] as num).toDouble()
          : null,
      reviewCount: json['review_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'shop_name': shopName,
      'product_url': productUrl,
      if (reviewAverage != null) 'review_average': reviewAverage,
      if (reviewCount != null) 'review_count': reviewCount,
    };
  }
}

/// 天気情報
class Weather {
  final double temperature;
  final String condition;
  final String description;

  const Weather({
    required this.temperature,
    required this.condition,
    required this.description,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: (json['temperature'] as num).toDouble(),
      condition: json['condition'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'condition': condition,
      'description': description,
    };
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

/// TPO情報
class TPO {
  final String formalityRequired;
  final String summary;

  const TPO({
    required this.formalityRequired,
    required this.summary,
  });

  factory TPO.fromJson(Map<String, dynamic> json) {
    return TPO(
      formalityRequired: json['formality_required'] as String,
      summary: json['summary'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formality_required': formalityRequired,
      'summary': summary,
    };
  }
}
