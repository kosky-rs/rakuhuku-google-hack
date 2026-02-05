/// Clothing item model
class ClothingItem {
  final String id;
  final String name;
  final String category;
  final String color;
  final List<String> season;
  final String formality;
  final String? imageUrl;
  final List<String> tags;
  final String? brand;
  final int usageScore;
  final DateTime? lastWornAt;
  final DateTime createdAt;

  const ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.season,
    required this.formality,
    this.imageUrl,
    this.tags = const [],
    this.brand,
    this.usageScore = 0,
    this.lastWornAt,
    required this.createdAt,
  });

  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      color: json['color'] as String,
      season: (json['season'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      formality: json['formality'] as String? ?? 'casual',
      imageUrl: json['image_url'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      brand: json['brand'] as String?,
      usageScore: json['usage_score'] as int? ?? 0,
      lastWornAt: json['last_worn_at'] != null
          ? DateTime.parse(json['last_worn_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'color': color,
      'season': season,
      'formality': formality,
      'image_url': imageUrl,
      'tags': tags,
      'brand': brand,
      'usage_score': usageScore,
      'last_worn_at': lastWornAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  ClothingItem copyWith({
    String? id,
    String? name,
    String? category,
    String? color,
    List<String>? season,
    String? formality,
    String? imageUrl,
    List<String>? tags,
    String? brand,
    int? usageScore,
    DateTime? lastWornAt,
    DateTime? createdAt,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      color: color ?? this.color,
      season: season ?? this.season,
      formality: formality ?? this.formality,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      brand: brand ?? this.brand,
      usageScore: usageScore ?? this.usageScore,
      lastWornAt: lastWornAt ?? this.lastWornAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Clothing category enum
enum ClothingCategory {
  tops('tops', 'Tops'),
  bottoms('bottoms', 'Bottoms'),
  outerwear('outerwear', 'Outer'),
  shoes('shoes', 'Shoes'),
  accessories('accessories', 'Accessories');

  final String value;
  final String label;

  const ClothingCategory(this.value, this.label);

  static ClothingCategory fromString(String value) {
    return ClothingCategory.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => ClothingCategory.tops,
    );
  }
}

/// Formality level enum
enum FormalityLevel {
  casual('casual', 'Casual'),
  smartCasual('smart_casual', 'Smart Casual'),
  businessCasual('business_casual', 'Business Casual'),
  formal('formal', 'Formal');

  final String value;
  final String label;

  const FormalityLevel(this.value, this.label);

  static FormalityLevel fromString(String value) {
    return FormalityLevel.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => FormalityLevel.casual,
    );
  }
}

/// Season enum
enum Season {
  spring('spring', 'Spring'),
  summer('summer', 'Summer'),
  autumn('autumn', 'Autumn'),
  winter('winter', 'Winter'),
  allSeason('all_season', 'All Season');

  final String value;
  final String label;

  const Season(this.value, this.label);

  static Season fromString(String value) {
    return Season.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => Season.allSeason,
    );
  }
}
