import 'clothing_item.dart';

/// Closet response model
class ClosetResponse {
  final List<ClothingItem> items;
  final Map<String, int> categories;
  final int totalCount;

  const ClosetResponse({
    required this.items,
    required this.categories,
    required this.totalCount,
  });

  factory ClosetResponse.fromJson(Map<String, dynamic> json) {
    return ClosetResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      categories: (json['categories'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as int),
          ) ??
          {},
      totalCount: json['total_count'] as int? ?? 0,
    );
  }
}

/// Create clothing item request
class CreateClothingItemRequest {
  final String name;
  final String category;
  final String color;
  final List<String> season;
  final String formality;
  final String? imageUrl;
  final List<String> tags;

  const CreateClothingItemRequest({
    required this.name,
    required this.category,
    required this.color,
    required this.season,
    required this.formality,
    this.imageUrl,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'color': color,
      'season': season,
      'formality': formality,
      'image_url': imageUrl,
      'tags': tags,
    };
  }
}
