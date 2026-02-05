import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/clothing_item.dart';
import '../../../core/models/closet.dart';
import '../../home/providers/outfit_provider.dart';

/// Closet state
class ClosetState {
  final List<ClothingItem> items;
  final Map<String, int> categories;
  final ClothingCategory selectedCategory;
  final bool isLoading;
  final String? error;

  const ClosetState({
    this.items = const [],
    this.categories = const {},
    this.selectedCategory = ClothingCategory.tops,
    this.isLoading = false,
    this.error,
  });

  List<ClothingItem> get filteredItems {
    return items
        .where((item) =>
            item.category.toLowerCase() == selectedCategory.value.toLowerCase())
        .toList();
  }

  int get totalCount => items.length;

  ClosetState copyWith({
    List<ClothingItem>? items,
    Map<String, int>? categories,
    ClothingCategory? selectedCategory,
    bool? isLoading,
    String? error,
  }) {
    return ClosetState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Closet notifier
class ClosetNotifier extends StateNotifier<ClosetState> {
  final ApiClient _apiClient;

  ClosetNotifier(this._apiClient) : super(const ClosetState());

  Future<void> fetchCloset() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.getCloset();
      state = state.copyWith(
        items: response.items,
        categories: response.categories,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  void selectCategory(ClothingCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<void> addItem(CreateClothingItemRequest request) async {
    try {
      final item = await _apiClient.addClosetItem(item: request);
      state = state.copyWith(
        items: [...state.items, item],
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> refresh() async {
    await fetchCloset();
  }
}

/// Closet provider
final closetProvider =
    StateNotifierProvider<ClosetNotifier, ClosetState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ClosetNotifier(apiClient);
});

/// Selected category provider
final selectedCategoryProvider = Provider<ClothingCategory>((ref) {
  return ref.watch(closetProvider).selectedCategory;
});

/// Filtered items provider
final filteredItemsProvider = Provider<List<ClothingItem>>((ref) {
  return ref.watch(closetProvider).filteredItems;
});
