import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../home/providers/outfit_provider.dart' show apiClientProvider, currentUserIdProvider;

/// Categories that allow only 1 item selection (radio-button behavior)
const _singleSelectCategories = {'tops', 'bottoms', 'outerwear', 'shoes'};

/// Diagnosis state
class DiagnosisState {
  final bool isLoading;
  final bool isAnalyzing;
  final String? error;
  final String? imagePath;
  final String? imageBase64;
  final Map<String, dynamic>? result;
  final List<Map<String, dynamic>> selectedItems;
  final List<Map<String, dynamic>> deduplicatedItems;

  const DiagnosisState({
    this.isLoading = false,
    this.isAnalyzing = false,
    this.error,
    this.imagePath,
    this.imageBase64,
    this.result,
    this.selectedItems = const [],
    this.deduplicatedItems = const [],
  });

  DiagnosisState copyWith({
    bool? isLoading,
    bool? isAnalyzing,
    String? error,
    String? imagePath,
    String? imageBase64,
    Map<String, dynamic>? result,
    List<Map<String, dynamic>>? selectedItems,
    List<Map<String, dynamic>>? deduplicatedItems,
  }) {
    return DiagnosisState(
      isLoading: isLoading ?? this.isLoading,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      result: result ?? this.result,
      selectedItems: selectedItems ?? this.selectedItems,
      deduplicatedItems: deduplicatedItems ?? this.deduplicatedItems,
    );
  }

  // Helper getters
  Map<String, dynamic>? get evaluation => result?['evaluation'];
  List<dynamic>? get detectedItems => result?['detected_items'];
  List<dynamic>? get productSuggestions => result?['product_suggestions'];
  List<dynamic>? get closetSuggestions => result?['closet_suggestions'];
  String? get diagnosisId => result?['diagnosis_id'];

  double? get score => evaluation?['score']?.toDouble();
  List<dynamic>? get goodPoints => evaluation?['good_points'];
  List<dynamic>? get improvementSuggestions => evaluation?['improvement_suggestions'];
  String? get overallStyle => evaluation?['overall_style'];
  String? get colorHarmony => evaluation?['color_harmony'];
}

/// Diagnosis notifier
class DiagnosisNotifier extends StateNotifier<DiagnosisState> {
  final ApiClient _apiClient;
  final String _userId;

  DiagnosisNotifier(this._apiClient, this._userId) : super(const DiagnosisState());

  /// Deduplicate detected items:
  /// - tops/bottoms/outerwear/shoes: keep highest-confidence item per category
  /// - accessories: deduplicate by name, keep highest-confidence per unique name
  /// Assigns _itemId for unique identification
  static List<Map<String, dynamic>> _deduplicateItems(List<dynamic> rawItems) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final raw in rawItems) {
      final item = Map<String, dynamic>.from(raw as Map);
      final category = (item['category'] as String? ?? 'tops').toLowerCase();
      grouped.putIfAbsent(category, () => []).add(item);
    }

    final List<Map<String, dynamic>> result = [];

    for (final entry in grouped.entries) {
      final category = entry.key;
      final items = entry.value;

      // Sort by confidence descending
      items.sort((a, b) =>
          ((b['confidence'] as num?)?.toDouble() ?? 0.0)
              .compareTo((a['confidence'] as num?)?.toDouble() ?? 0.0));

      if (_singleSelectCategories.contains(category)) {
        // Keep only the highest-confidence item
        result.add(items.first);
      } else {
        // Accessories: deduplicate by name
        final Map<String, Map<String, dynamic>> byName = {};
        for (final item in items) {
          final name = item['name'] as String? ?? '';
          if (!byName.containsKey(name)) {
            byName[name] = item;
          }
        }
        result.addAll(byName.values);
      }
    }

    // Assign unique _itemId
    for (int i = 0; i < result.length; i++) {
      result[i]['_itemId'] = i;
    }

    return result;
  }

  /// Set captured image from bytes (works on both web and native)
  void setImageFromBytes(String imagePath, Uint8List bytes) {
    final base64Image = base64Encode(bytes);
    state = state.copyWith(
      isLoading: false,
      imagePath: imagePath,
      imageBase64: base64Image,
    );
  }

  /// Analyze outfit
  Future<void> analyzeOutfit({Map<String, dynamic>? context}) async {
    if (state.imageBase64 == null) {
      state = state.copyWith(error: 'No image to analyze');
      return;
    }

    state = state.copyWith(isAnalyzing: true, error: null);

    try {
      final result = await _apiClient.diagnoseOutfit(
        imageBase64: state.imageBase64,
        userId: _userId,
        context: context,
      );

      // Deduplicate and pre-select all items
      final detectedItems = result['detected_items'] as List<dynamic>? ?? [];
      final deduplicated = _deduplicateItems(detectedItems);
      final selected = List<Map<String, dynamic>>.from(deduplicated);

      state = state.copyWith(
        isAnalyzing: false,
        result: result,
        deduplicatedItems: deduplicated,
        selectedItems: selected,
      );
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        error: 'Analysis failed: $e',
      );
    }
  }

  /// Toggle item selection for closet registration
  /// Single-select categories (tops/bottoms/outerwear/shoes): radio behavior
  /// Accessories: checkbox behavior (multiple allowed)
  void toggleItemSelection(Map<String, dynamic> item) {
    final current = List<Map<String, dynamic>>.from(state.selectedItems);
    final itemId = item['_itemId'];
    final category = (item['category'] as String? ?? '').toLowerCase();
    final index = current.indexWhere((i) => i['_itemId'] == itemId);

    if (index >= 0) {
      // Deselect
      current.removeAt(index);
    } else {
      // For single-select categories, remove existing item of same category
      if (_singleSelectCategories.contains(category)) {
        current.removeWhere((i) =>
            (i['category'] as String? ?? '').toLowerCase() == category);
      }
      current.add(item);
    }

    state = state.copyWith(selectedItems: current);
  }

  /// Check if item is selected
  bool isItemSelected(Map<String, dynamic> item) {
    final itemId = item['_itemId'];
    return state.selectedItems.any((i) => i['_itemId'] == itemId);
  }

  /// Register selected items to closet
  Future<bool> registerSelectedItems() async {
    // Debug: Log selected items count
    if (kDebugMode) {
      print('[DiagnosisProvider] registerSelectedItems called with ${state.selectedItems.length} items');
    }

    if (state.selectedItems.isEmpty) {
      if (kDebugMode) {
        print('[DiagnosisProvider] No items selected, setting error');
      }
      state = state.copyWith(error: 'アイテムが選択されていません');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final items = state.selectedItems.map((item) => {
        'name': item['name'],
        'category': item['category'],
        'color': item['color'] ?? '',
        'image_base64': item['cropped_image_base64'],
        'source': 'diagnosis',
        'source_diagnosis_id': state.diagnosisId,
      }).toList();

      if (kDebugMode) {
        print('[DiagnosisProvider] Sending ${items.length} items to API');
        print('[DiagnosisProvider] First item: ${items.first}');
      }

      final response = await _apiClient.addClosetItemsBulk(userId: _userId, items: items);

      if (kDebugMode) {
        print('[DiagnosisProvider] API success: $response');
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[DiagnosisProvider] Error registering items: $e');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'アイテムの登録に失敗しました: $e',
      );
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const DiagnosisState();
  }
}

/// Providers (apiClientProvider/currentUserIdProvider imported from outfit_provider.dart)
final diagnosisProvider =
    StateNotifierProvider<DiagnosisNotifier, DiagnosisState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return DiagnosisNotifier(apiClient, userId);
});
