import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../providers/outfit_provider.dart';
import '../widgets/weather_header.dart';
import '../widgets/outfit_card.dart';

/// Home screen with daily outfit recommendation
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch recommendation on first load
    Future.microtask(() {
      ref.read(outfitProvider.notifier).fetchRecommendation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final outfitState = ref.watch(outfitProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            _buildAppBar(context, isDark),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(outfitProvider.notifier).refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      // Weather and context section
                      if (outfitState.proposal != null)
                        WeatherHeader(
                          weather: outfitState.proposal!.weather,
                          tpo: outfitState.proposal!.tpo,
                        ),

                      // Loading state
                      if (outfitState.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(),
                        ),

                      // Error state
                      if (outfitState.error != null)
                        _buildErrorState(outfitState.error!),

                      // Outfit card
                      if (outfitState.proposal != null && !outfitState.isLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: OutfitCard(
                            recommendation: outfitState.proposal!.recommendation,
                            alternatives: outfitState.proposal!.alternatives,
                            selectedAlternativeIndex:
                                outfitState.selectedAlternativeIndex,
                            onSelectMain: () =>
                                ref.read(outfitProvider.notifier).selectMainOutfit(),
                            onSelectAlternative: (index) =>
                                ref.read(outfitProvider.notifier).selectAlternative(index),
                            onWearOutfit: () => _handleWearOutfit(context),
                            onRefresh: () =>
                                ref.read(outfitProvider.notifier).refresh(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          // Profile button
          IconButton(
            icon: Icon(
              Icons.account_circle_outlined,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            onPressed: () => context.goSettings(),
          ),

          // Title
          Expanded(
            child: Text(
              'Rakufuku',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),

          // Calendar button
          IconButton(
            icon: Icon(
              Icons.calendar_today_outlined,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            onPressed: () => _showCalendarEvents(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'おすすめを読み込めませんでした',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.read(outfitProvider.notifier).refresh(),
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCalendarEvents(BuildContext context, bool isDark) async {
    final apiClient = ref.read(apiClientProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: apiClient.getCalendar(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'カレンダー情報を取得できませんでした',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            final events = (data['events'] as List?) ?? [];
            final tpo = data['tpo'] as Map<String, dynamic>? ?? {};
            final recommendation = tpo['recommendation'] as String? ?? '';

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    '今日の予定',
                    style: AppTextStyles.h3.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // TPO recommendation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.checkroom,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Events list
                  if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          '予定はありません',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...events.map((event) {
                      final e = event as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _eventTypeColor(e['event_type'] as String? ?? 'other'),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e['title'] as String? ?? '',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${e['start_time'] ?? ''} - ${e['end_time'] ?? ''}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _eventTypeColor(String type) {
    switch (type) {
      case 'client_meeting':
        return Colors.red;
      case 'meeting':
        return Colors.orange;
      case 'date':
        return Colors.pink;
      case 'exercise':
        return Colors.green;
      case 'casual':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleWearOutfit(BuildContext context) async {
    final saved = await ref.read(outfitProvider.notifier).saveToHistory();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'コーデを履歴に保存しました！' : '保存に失敗しました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

}
