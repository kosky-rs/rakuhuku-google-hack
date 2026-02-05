import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

/// Diagnosis state
class DiagnosisState {
  final bool isLoading;
  final bool isAnalyzing;
  final String? error;
  final String? imagePath;
  final String? imageBase64;
  final Map<String, dynamic>? result;
  final List<Map<String, dynamic>> selectedItems;

  const DiagnosisState({
    this.isLoading = false,
    this.isAnalyzing = false,
    this.error,
    this.imagePath,
    this.imageBase64,
    this.result,
    this.selectedItems = const [],
  });

  DiagnosisState copyWith({
    bool? isLoading,
    bool? isAnalyzing,
    String? error,
    String? imagePath,
    String? imageBase64,
    Map<String, dynamic>? result,
    List<Map<String, dynamic>>? selectedItems,
  }) {
    return DiagnosisState(
      isLoading: isLoading ?? this.isLoading,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      result: result ?? this.result,
      selectedItems: selectedItems ?? this.selectedItems,
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

  DiagnosisNotifier(this._apiClient) : super(const DiagnosisState());

  /// Set captured image
  Future<void> setImage(String imagePath) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      state = state.copyWith(
        isLoading: false,
        imagePath: imagePath,
        imageBase64: base64Image,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load image: $e',
      );
    }
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
        context: context,
      );

      // Pre-select all detected items
      final detectedItems = result['detected_items'] as List<dynamic>? ?? [];
      final selected = detectedItems
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      state = state.copyWith(
        isAnalyzing: false,
        result: result,
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
  void toggleItemSelection(Map<String, dynamic> item) {
    final current = List<Map<String, dynamic>>.from(state.selectedItems);
    final index = current.indexWhere((i) =>
        i['name'] == item['name'] && i['category'] == item['category']);

    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.add(item);
    }

    state = state.copyWith(selectedItems: current);
  }

  /// Check if item is selected
  bool isItemSelected(Map<String, dynamic> item) {
    return state.selectedItems.any((i) =>
        i['name'] == item['name'] && i['category'] == item['category']);
  }

  /// Register selected items to closet
  Future<bool> registerSelectedItems() async {
    if (state.selectedItems.isEmpty) {
      return true;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final items = state.selectedItems.map((item) => {
        'name': item['name'],
        'category': item['category'],
        'color': item['color'] ?? '',
        'source': 'diagnosis',
        'source_diagnosis_id': state.diagnosisId,
      }).toList();

      await _apiClient.addClosetItemsBulk(items: items);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to register items: $e',
      );
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const DiagnosisState();
  }
}

/// Providers
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final diagnosisProvider =
    StateNotifierProvider<DiagnosisNotifier, DiagnosisState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DiagnosisNotifier(apiClient);
});
