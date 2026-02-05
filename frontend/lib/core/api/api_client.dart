import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import '../models/outfit.dart';
import '../models/closet.dart';
import '../models/clothing_item.dart';

/// API client for Poltan backend
class ApiClient {
  final Dio _dio;
  final String baseUrl;

  /// Android エミュレータでは 10.0.2.2 でホストマシンにアクセス
  static String get _defaultBaseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api/v1';
      }
    } catch (_) {}
    return 'http://localhost:8000/api/v1';
  }

  ApiClient({
    String? baseUrl,
    Dio? dio,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl,
        _dio = dio ?? Dio() {
    _dio.options.baseUrl = this.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add logging interceptor for debug
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (log) => print('[API] $log'),
    ));
  }

  // ==================== Health Check ====================

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }

  // ==================== Outfit Recommendation ====================

  Future<DailyOutfitProposal> getOutfitRecommendation({
    String userId = 'demo_user',
    String? targetDate,
    double latitude = 35.6762,
    double longitude = 139.6503,
  }) async {
    try {
      final response = await _dio.post('/outfit/recommend', data: {
        'user_id': userId,
        'target_date': targetDate,
        'latitude': latitude,
        'longitude': longitude,
      });
      return DailyOutfitProposal.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==================== Closet ====================

  Future<ClosetResponse> getCloset({String userId = 'demo_user'}) async {
    try {
      final response = await _dio.get('/closet', queryParameters: {
        'user_id': userId,
      });
      return ClosetResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<ClothingItem>> getClosetByCategory({
    String userId = 'demo_user',
    required String category,
  }) async {
    final closet = await getCloset(userId: userId);
    return closet.items
        .where((item) => item.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  Future<Map<String, int>> getClosetCategories({
    String userId = 'demo_user',
  }) async {
    try {
      final response = await _dio.get('/closet/categories', queryParameters: {
        'user_id': userId,
      });
      return (response.data['categories'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ClothingItem> addClosetItem({
    String userId = 'demo_user',
    required CreateClothingItemRequest item,
  }) async {
    try {
      final response = await _dio.post(
        '/closet/items',
        data: item.toJson(),
        queryParameters: {'user_id': userId},
      );
      return ClothingItem.fromJson(response.data['item']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==================== Weather ====================

  Future<Weather> getWeather({
    double latitude = 35.6762,
    double longitude = 139.6503,
  }) async {
    try {
      final response = await _dio.get('/weather', queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      });
      return Weather.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==================== Calendar ====================

  Future<Map<String, dynamic>> getCalendar({
    String userId = 'demo_user',
    String? targetDate,
  }) async {
    try {
      final response = await _dio.get('/calendar', queryParameters: {
        'user_id': userId,
        if (targetDate != null) 'target_date': targetDate,
      });
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==================== Outfit Diagnosis ====================

  Future<Map<String, dynamic>> diagnoseOutfit({
    String userId = 'demo_user',
    String? imageBase64,
    String? imageUrl,
    Map<String, dynamic>? context,
    bool includeClosetSuggestions = true,
  }) async {
    try {
      final response = await _dio.post('/outfit/diagnose', data: {
        'user_id': userId,
        if (imageBase64 != null) 'image_base64': imageBase64,
        if (imageUrl != null) 'image_url': imageUrl,
        'context': context ?? {},
        'include_closet_suggestions': includeClosetSuggestions,
      });
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> addClosetItemsBulk({
    String userId = 'demo_user',
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _dio.post('/closet/items/bulk', data: {
        'user_id': userId,
        'items': items,
      });
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

/// API exception wrapper
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timeout. Please check your internet connection.',
          statusCode: null,
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Unable to connect to server. Please try again later.',
          statusCode: null,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        String message;

        if (data is Map && data.containsKey('detail')) {
          message = data['detail'].toString();
        } else if (statusCode == 404) {
          message = 'Resource not found';
        } else if (statusCode == 500) {
          message = 'Server error. Please try again later.';
        } else {
          message = 'An error occurred';
        }

        return ApiException(
          message: message,
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request was cancelled',
          statusCode: null,
        );

      default:
        return ApiException(
          message: error.message ?? 'An unexpected error occurred',
          statusCode: null,
        );
    }
  }

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
