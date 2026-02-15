import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:dio/dio.dart';
import '../models/outfit.dart';
import '../models/closet.dart';
import '../models/clothing_item.dart';
import '../models/daily_recommendation.dart' as daily;

/// Token provider function type
typedef AccessTokenProvider = Future<String?> Function();

/// API client for Poltan backend
class ApiClient {
  final Dio _dio;
  final String baseUrl;
  AccessTokenProvider? _tokenProvider;

  /// 環境変数 API_BASE_URL または デフォルトURL
  static String get _defaultBaseUrl {
    // --dart-define=API_BASE_URL=xxx で指定
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // 本番URL
    if (kIsWeb) return 'https://rakufuku-api-1024882237054.asia-northeast1.run.app/api/v1';

    // ローカル開発
    return 'http://localhost:8000/api/v1';
  }

  ApiClient({
    String? baseUrl,
    Dio? dio,
    AccessTokenProvider? tokenProvider,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl,
        _dio = dio ?? Dio(),
        _tokenProvider = tokenProvider {
    _dio.options.baseUrl = this.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Authorization header interceptor - fetches token on demand
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_tokenProvider != null) {
          try {
            final token = await _tokenProvider!();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            if (kDebugMode) {
              print('[API] Failed to get access token: $e');
            }
          }
        }
        return handler.next(options);
      },
    ));

    // Add logging interceptor for debug
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (log) => print('[API] $log'),
      ));
    }
  }

  /// トークンプロバイダを設定（各リクエスト時に自動でトークンを取得）
  void setTokenProvider(AccessTokenProvider? provider) {
    _tokenProvider = provider;
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

  /// 日次コーディネート推奨取得（マルチエージェント版）
  Future<daily.DailyRecommendation> getDailyOutfits({
    String userId = 'demo_user',
    double latitude = 35.6762,
    double longitude = 139.6503,
    bool forceRegenerate = false,
  }) async {
    try {
      final response = await _dio.post('/outfit/daily', data: {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'force_regenerate': forceRegenerate,
      });
      return daily.DailyRecommendation.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// 強制再生成（Tier制限あり）
  Future<daily.DailyRecommendation> regenerateOutfits({
    String userId = 'demo_user',
    double latitude = 35.6762,
    double longitude = 139.6503,
  }) async {
    try {
      final response = await _dio.post('/outfit/regenerate', data: {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
      });
      return daily.DailyRecommendation.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// スワイプアクション記録
  Future<void> recordSwipe({
    String userId = 'demo_user',
    required String outfitId,
    required String action, // "approve" or "reject"
    required Map<String, dynamic> outfitDetails,
  }) async {
    try {
      await _dio.post('/outfit/swipe', data: {
        'user_id': userId,
        'outfit_id': outfitId,
        'action': action,
        'outfit_details': outfitDetails,
      });
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

  /// 天気情報を先行取得（daily_recommendation.Weather型で返す）
  Future<daily.Weather> prefetchWeather({
    double latitude = 35.6762,
    double longitude = 139.6503,
  }) async {
    final response = await _dio.get('/weather', queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
    });
    return daily.Weather.fromJson(response.data);
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

  /// カレンダーTPO情報を先行取得
  Future<daily.TPO> prefetchCalendarTPO({
    String userId = 'demo_user',
    String? targetDate,
  }) async {
    final response = await _dio.get('/calendar', queryParameters: {
      'user_id': userId,
      if (targetDate != null) 'target_date': targetDate,
    });
    final tpoData = response.data['tpo'] as Map<String, dynamic>;
    return daily.TPO.fromJson(tpoData);
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

  Future<void> deleteClosetItem({
    String userId = 'demo_user',
    required String itemId,
  }) async {
    try {
      await _dio.delete(
        '/closet/items/$itemId',
        queryParameters: {'user_id': userId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==================== Outfit History ====================

  Future<void> saveOutfitHistory({
    String userId = 'demo_user',
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? weather,
    Map<String, dynamic>? tpo,
    double? score,
    String? feedback,
    String? wornDate,
  }) async {
    try {
      await _dio.post('/outfit/history', data: {
        'user_id': userId,
        'items': items,
        'weather': weather,
        'tpo': tpo,
        'score': score,
        'feedback': feedback,
        'worn_date': wornDate ?? DateTime.now().toIso8601String().split('T')[0],
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getOutfitHistory({
    String userId = 'demo_user',
    int limit = 30,
  }) async {
    try {
      final response = await _dio.get('/outfit/history', queryParameters: {
        'user_id': userId,
        'limit': limit,
      });
      return (response.data['history'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==================== Bulk Items ====================

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

  /// Check if this is a tier limit exception
  bool get isTierLimitExceeded => statusCode == 429;

  /// Get upgrade required flag from response data
  bool get upgradeRequired {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        return detail['upgrade_required'] == true;
      }
    }
    return false;
  }

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

        if (statusCode == 429) {
          // Tier limit exceeded
          if (data is Map && data.containsKey('detail')) {
            final detail = data['detail'];
            if (detail is Map && detail.containsKey('message')) {
              message = detail['message'].toString();
            } else if (detail is String) {
              message = detail;
            } else {
              message = '本日の生成回数上限に達しました';
            }
          } else {
            message = '本日の生成回数上限に達しました';
          }
        } else if (data is Map && data.containsKey('detail')) {
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
