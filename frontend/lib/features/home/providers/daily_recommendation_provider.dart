import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/daily_recommendation.dart';
import '../../../core/models/clothing_item.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/auth_service.dart';

/// API client provider (with auth wiring)
final apiClientProvider = Provider<ApiClient>((ref) {
  final userState = ref.watch(userProvider);
  final authService = ref.read(authServiceProvider);

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

/// Daily recommendation state
class DailyRecommendationState {
  final DailyRecommendation? dailyRec;
  final bool isLoading;
  final String? error;
  final int currentCardIndex;
  final bool allRejected;
  final bool isTierLimited;
  final OutfitRecommendation? selectedTodayOutfit;

  const DailyRecommendationState({
    this.dailyRec,
    this.isLoading = false,
    this.error,
    this.currentCardIndex = 0,
    this.allRejected = false,
    this.isTierLimited = false,
    this.selectedTodayOutfit,
  });

  int get generationsRemaining => dailyRec?.generationsRemaining ?? 0;
  bool get canRegenerate => dailyRec?.canRegenerate ?? false;
  List<OutfitRecommendation> get recommendations =>
      dailyRec?.recommendations ?? [];

  DailyRecommendationState copyWith({
    DailyRecommendation? dailyRec,
    bool? isLoading,
    String? error,
    int? currentCardIndex,
    bool? allRejected,
    bool? isTierLimited,
    OutfitRecommendation? selectedTodayOutfit,
    bool clearSelectedOutfit = false,
  }) {
    return DailyRecommendationState(
      dailyRec: dailyRec ?? this.dailyRec,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentCardIndex: currentCardIndex ?? this.currentCardIndex,
      allRejected: allRejected ?? this.allRejected,
      isTierLimited: isTierLimited ?? this.isTierLimited,
      selectedTodayOutfit: clearSelectedOutfit ? null : (selectedTodayOutfit ?? this.selectedTodayOutfit),
    );
  }
}

/// Daily recommendation notifier
class DailyRecommendationNotifier
    extends StateNotifier<DailyRecommendationState> {
  final ApiClient _apiClient;
  final String _userId;

  DailyRecommendationNotifier(this._apiClient, this._userId)
      : super(const DailyRecommendationState());

  /// Fetch daily recommendations
  Future<void> fetchDailyRecommendations() async {
    state = state.copyWith(isLoading: true, error: null, isTierLimited: false);

    try {
      final dailyRec = await _apiClient.getDailyOutfits(
        userId: _userId,
      );

      // Check if user already selected today's outfit
      OutfitRecommendation? selectedOutfit;
      try {
        final history = await _apiClient.getOutfitHistory(userId: _userId, limit: 1);
        if (history.isNotEmpty) {
          final latestHistory = history.first;
          final wornDate = latestHistory['worn_date'] as String?;
          final today = DateTime.now().toIso8601String().split('T')[0];

          if (wornDate == today) {
            // Find matching outfit in recommendations
            final items = latestHistory['items'] as List<dynamic>;
            for (final rec in dailyRec.recommendations) {
              if (_itemsMatch(rec.items, items)) {
                selectedOutfit = rec;
                print('Restored today\'s outfit from history: ${rec.id}');
                break;
              }
            }
          }
        }
      } catch (e) {
        print('Failed to restore today\'s outfit: $e');
      }

      state = state.copyWith(
        dailyRec: dailyRec,
        isLoading: false,
        currentCardIndex: 0,
        allRejected: false,
        isTierLimited: false,
        selectedTodayOutfit: selectedOutfit,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        isTierLimited: e.isTierLimitExceeded,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
        isTierLimited: false,
      );
    }
  }

  /// Check if two item lists match
  bool _itemsMatch(List<ClothingItem> recItems, List<dynamic> historyItems) {
    if (recItems.length != historyItems.length) return false;

    final recNames = recItems.map((e) => e.name).toSet();
    final historyNames = historyItems.map((e) => e['name'] as String).toSet();

    return recNames.length == historyNames.length &&
           recNames.intersection(historyNames).length == recNames.length;
  }

  /// Record swipe action (approve or reject)
  Future<void> recordSwipe({
    required String outfitId,
    required String action,
    required Map<String, dynamic> outfitDetails,
  }) async {
    try {
      await _apiClient.recordSwipe(
        userId: _userId,
        outfitId: outfitId,
        action: action,
        outfitDetails: outfitDetails,
      );

      // If approved, save to history
      if (action == 'approve') {
        await _saveToHistory(outfitDetails);
      }

      // Move to next card
      final nextIndex = state.currentCardIndex + 1;
      if (nextIndex >= state.recommendations.length) {
        // All cards swiped
        state = state.copyWith(allRejected: true);
      } else {
        state = state.copyWith(currentCardIndex: nextIndex);
      }
    } catch (e) {
      // Silent fail - swipe state is already updated
    }
  }

  /// Save approved outfit to history
  Future<void> _saveToHistory(Map<String, dynamic> outfitDetails) async {
    try {
      final items = outfitDetails['items'] as List<dynamic>;
      final weather = state.dailyRec?.weather;
      final tpo = state.dailyRec?.tpo;
      final today = DateTime.now().toIso8601String().split('T')[0];

      await _apiClient.saveOutfitHistory(
        userId: _userId,
        items: items.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        weather: weather != null
            ? {
                'temperature': weather.temperature,
                'condition': weather.condition,
                'description': weather.description,
              }
            : null,
        tpo: tpo != null
            ? {
                'formality_required': tpo.formalityRequired,
                'summary': tpo.summary,
              }
            : null,
        score: outfitDetails['score'] as double?,
        feedback: outfitDetails['reasoning'] as String?,
        wornDate: today,
      );
      print('✅ Successfully saved outfit to history for user $_userId on $today');
    } catch (e) {
      print('❌ Failed to save outfit to history: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  /// Regenerate outfits (consumes generation limit)
  Future<void> regenerate() async {
    if (!state.canRegenerate) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      isTierLimited: false,
      clearSelectedOutfit: true, // Reset selected outfit when regenerating
    );

    try {
      final dailyRec = await _apiClient.regenerateOutfits(
        userId: _userId,
      );
      state = state.copyWith(
        dailyRec: dailyRec,
        isLoading: false,
        currentCardIndex: 0,
        allRejected: false,
        isTierLimited: false,
        clearSelectedOutfit: true, // Ensure it stays cleared
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        isTierLimited: e.isTierLimitExceeded,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
        isTierLimited: false,
      );
    }
  }

  /// Select outfit as today's choice (from vertical swipe up)
  ///
  /// This is triggered when user swipes up on an outfit card.
  /// Automatically records the approval and saves to history.
  Future<void> selectAsToday({
    required int index,
    required OutfitRecommendation outfit,
  }) async {
    print('🎯 selectAsToday called for outfit: ${outfit.id}');

    // Update state immediately - mark as selected
    state = state.copyWith(
      allRejected: false,
      selectedTodayOutfit: outfit,
    );

    final outfitDetails = {
      'items': outfit.items.map((e) => e.toJson()).toList(),
      'score': outfit.score,
      'reasoning': outfit.reasoning,
      'source': outfit.source,
      'agent_type': outfit.agentType,
    };

    try {
      // Save to history first (most important)
      print('📝 Saving to history...');
      await _saveToHistory(outfitDetails);
      print('✅ Successfully saved today\'s outfit to history');
    } catch (e) {
      print('❌ CRITICAL: Failed to save to history: $e');
      // Update state to show error (optional: add error field to state)
      return; // Don't proceed if history save fails
    }

    try {
      // Record the swipe as approval (for preference learning)
      print('📊 Recording swipe...');
      await _apiClient.recordSwipe(
        userId: _userId,
        outfitId: outfit.id,
        action: 'approve',
        outfitDetails: outfitDetails,
      );
      print('✅ Successfully recorded swipe');
    } catch (e) {
      print('⚠️ Failed to record swipe (non-critical): $e');
      // This is less critical, so we don't return
    }

    print('🎉 selectAsToday completed successfully');
  }

  /// Mark all as rejected (show regenerate prompt)
  void markAllRejected() {
    state = state.copyWith(allRejected: true);
  }

  /// Reset to first card and clear selected outfit
  void reset() {
    state = state.copyWith(
      currentCardIndex: 0,
      allRejected: false,
      clearSelectedOutfit: true,
    );
  }
}

/// Daily recommendation provider
final dailyRecommendationProvider = StateNotifierProvider<
    DailyRecommendationNotifier, DailyRecommendationState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return DailyRecommendationNotifier(apiClient, userId);
});

/// Weather provider (convenience)
final dailyWeatherProvider = Provider<Weather?>((ref) {
  return ref.watch(dailyRecommendationProvider).dailyRec?.weather;
});

/// TPO provider (convenience)
final dailyTpoProvider = Provider<TPO?>((ref) {
  return ref.watch(dailyRecommendationProvider).dailyRec?.tpo;
});
