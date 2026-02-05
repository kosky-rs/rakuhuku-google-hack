import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/outfit.dart';

/// API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Outfit recommendation state
class OutfitState {
  final DailyOutfitProposal? proposal;
  final bool isLoading;
  final String? error;
  final int selectedAlternativeIndex;

  const OutfitState({
    this.proposal,
    this.isLoading = false,
    this.error,
    this.selectedAlternativeIndex = -1,
  });

  OutfitState copyWith({
    DailyOutfitProposal? proposal,
    bool? isLoading,
    String? error,
    int? selectedAlternativeIndex,
  }) {
    return OutfitState(
      proposal: proposal ?? this.proposal,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedAlternativeIndex:
          selectedAlternativeIndex ?? this.selectedAlternativeIndex,
    );
  }
}

/// Outfit recommendation notifier
class OutfitNotifier extends StateNotifier<OutfitState> {
  final ApiClient _apiClient;

  OutfitNotifier(this._apiClient) : super(const OutfitState());

  Future<void> fetchRecommendation() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final proposal = await _apiClient.getOutfitRecommendation();
      state = state.copyWith(
        proposal: proposal,
        isLoading: false,
        selectedAlternativeIndex: -1,
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

  void selectMainOutfit() {
    state = state.copyWith(selectedAlternativeIndex: -1);
  }

  void selectAlternative(int index) {
    if (state.proposal != null &&
        index >= 0 &&
        index < state.proposal!.alternatives.length) {
      state = state.copyWith(selectedAlternativeIndex: index);
    }
  }

  Future<void> refresh() async {
    await fetchRecommendation();
  }
}

/// Outfit provider
final outfitProvider =
    StateNotifierProvider<OutfitNotifier, OutfitState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OutfitNotifier(apiClient);
});

/// Weather provider (convenience)
final weatherProvider = Provider<Weather?>((ref) {
  return ref.watch(outfitProvider).proposal?.weather;
});

/// TPO provider (convenience)
final tpoProvider = Provider<TPO?>((ref) {
  return ref.watch(outfitProvider).proposal?.tpo;
});
