import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../home/providers/outfit_provider.dart';

/// History state
class HistoryState {
  final List<Map<String, dynamic>> entries;
  final bool isLoading;
  final String? error;

  const HistoryState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  HistoryState copyWith({
    List<Map<String, dynamic>>? entries,
    bool? isLoading,
    String? error,
  }) {
    return HistoryState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// History notifier
class HistoryNotifier extends StateNotifier<HistoryState> {
  final ApiClient _apiClient;
  final String _userId;

  HistoryNotifier(this._apiClient, this._userId) : super(const HistoryState());

  Future<void> fetchHistory() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final history = await _apiClient.getOutfitHistory(userId: _userId);
      state = state.copyWith(entries: history, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred');
    }
  }

  Future<void> refresh() async {
    await fetchHistory();
  }
}

/// History provider
final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return HistoryNotifier(apiClient, userId);
});
