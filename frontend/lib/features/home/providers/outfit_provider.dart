import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/outfit.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/auth_service.dart';

/// API client provider (with auth wiring)
final apiClientProvider = Provider<ApiClient>((ref) {
  final userState = ref.watch(userProvider);
  final authService = ref.read(authServiceProvider);

  // Pass token provider function - token is fetched on-demand for each request
  final apiClient = ApiClient(
    tokenProvider: userState.isSignedIn ? () => authService.getAccessToken() : null,
  );

  return apiClient;
});

/// Current user ID provider
final currentUserIdProvider = Provider<String>((ref) {
  final userState = ref.watch(userProvider);
  return userState.profile?.id ?? 'demo_user';
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
  final String _userId;

  OutfitNotifier(this._apiClient, this._userId) : super(const OutfitState());

  Future<void> fetchRecommendation() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final proposal = await _apiClient.getOutfitRecommendation(
        userId: _userId,
      );
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

  /// Save current outfit to history
  Future<bool> saveToHistory() async {
    final proposal = state.proposal;
    if (proposal == null) return false;

    try {
      final items = state.selectedAlternativeIndex >= 0
          ? proposal.alternatives[state.selectedAlternativeIndex].items
          : proposal.recommendation.items;

      await _apiClient.saveOutfitHistory(
        userId: _userId,
        items: items.map((e) => e.toJson()).toList(),
        weather: {
          'temperature': proposal.weather.temperature,
          'condition': proposal.weather.condition,
          'description': proposal.weather.description,
        },
        tpo: {
          'formality_required': proposal.tpo.formalityRequired,
          'summary': proposal.tpo.summary,
        },
        score: proposal.recommendation.score,
        feedback: proposal.recommendation.feedback,
      );
      return true;
    } catch (e) {
      return false;
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
  final userId = ref.watch(currentUserIdProvider);
  return OutfitNotifier(apiClient, userId);
});

/// Weather provider (convenience)
final weatherProvider = Provider<Weather?>((ref) {
  return ref.watch(outfitProvider).proposal?.weather;
});

/// TPO provider (convenience)
final tpoProvider = Provider<TPO?>((ref) {
  return ref.watch(outfitProvider).proposal?.tpo;
});
