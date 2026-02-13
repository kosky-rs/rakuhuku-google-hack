import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../providers/daily_recommendation_provider.dart';
import '../widgets/horizontal_outfit_browser.dart';

/// Home screen with daily outfit recommendation (swipe UI)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch daily recommendations on first load
    Future.microtask(() {
      ref.read(dailyRecommendationProvider.notifier).fetchDailyRecommendations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dailyRecState = ref.watch(dailyRecommendationProvider);
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
              child: _buildContent(context, dailyRecState, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    final dailyRecState = ref.watch(dailyRecommendationProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            onPressed: () => context.goProfileView(),
          ),

          // Title (removed generation count)
          Expanded(
            child: Text(
              'Rakufuku',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),

          // Regenerate button
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: dailyRecState.isLoading
                  ? Colors.grey
                  : AppColors.primary,
            ),
            onPressed: dailyRecState.isLoading
                ? null
                : () {
                    ref.read(dailyRecommendationProvider.notifier).regenerate();
                  },
            tooltip: 'コーデを再生成',
          ),

          // Calendar button
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            onPressed: () => _showCalendarDialog(context, dailyRecState),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, DailyRecommendationState state, bool isDark) {
    // Loading state
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'AIがあなたにぴったりのコーデを生成中...',
              style: AppTextStyles.bodyLarge.copyWith(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Error state
    if (state.error != null) {
      // Tier limit error has special UI
      if (state.isTierLimited) {
        return _buildTierLimitedState(state.error!, isDark);
      }
      return _buildErrorState(state.error!, isDark);
    }

    // All rejected state (show regenerate prompt)
    if (state.allRejected) {
      return _buildRegeneratePrompt(state, isDark);
    }

    // Main swipeable deck
    if (state.recommendations.isNotEmpty) {
      return Column(
        children: [
          // Weather & TPO header
          if (state.dailyRec != null)
            _buildContextHeader(state.dailyRec!, isDark),

          // Horizontal browser with vertical swipe
          Expanded(
            child: HorizontalOutfitBrowser(
              recommendations: state.recommendations,
              onSelectAsToday: (index, outfit) {
                ref.read(dailyRecommendationProvider.notifier).selectAsToday(
                  index: index,
                  outfit: outfit,
                );
              },
              onSkip: (index) {
                // Skip handler - just logs the skip action
              },
            ),
          ),

          // Updated swipe instructions
          _buildNewSwipeInstructions(isDark),
        ],
      );
    }

    // Empty state
    return Center(
      child: Text(
        'コーデが見つかりませんでした',
        style: AppTextStyles.bodyLarge.copyWith(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildContextHeader(dailyRec, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Weather
          Row(
            children: [
              Icon(
                _getWeatherIcon(dailyRec.weather.condition),
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '${dailyRec.weather.temperature.toStringAsFixed(1)}°C',
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dailyRec.weather.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // TPO
          Row(
            children: [
              Icon(
                Icons.event_note,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dailyRec.tpo.summary,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewSwipeInstructions(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInstructionItem(
            Icons.swipe,
            '横スクロール: 閲覧',
            AppColors.primary,
            isDark,
          ),
          _buildInstructionItem(
            Icons.arrow_upward,
            '上スワイプ: 決定',
            Colors.green,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRegeneratePrompt(DailyRecommendationState state, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh,
              size: 64,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              '別のコーデを見ますか？',
              style: AppTextStyles.h3.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => ref.read(dailyRecommendationProvider.notifier).regenerate(),
              icon: const Icon(Icons.refresh),
              label: const Text('新しいコーデを生成'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierLimitedState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              '本日の生成回数上限に達しました',
              style: AppTextStyles.h3.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    message,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Free tierは1日1回の生成制限があります。\n明日0時にリセットされます。',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to premium upgrade page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Premium tierは近日公開予定です'),
                  ),
                );
              },
              icon: const Icon(Icons.upgrade),
              label: const Text('Premium にアップグレード'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  ref.read(dailyRecommendationProvider.notifier).fetchDailyRecommendations(),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWeatherIcon(String condition) {
    if (condition.contains('晴')) return Icons.wb_sunny;
    if (condition.contains('曇')) return Icons.cloud;
    if (condition.contains('雨')) return Icons.umbrella;
    if (condition.contains('雪')) return Icons.ac_unit;
    return Icons.wb_cloudy;
  }

  void _handleSwipe(int index, String action, DailyRecommendationState state) {
    final outfit = state.recommendations[index];
    ref.read(dailyRecommendationProvider.notifier).recordSwipe(
          outfitId: outfit.id,
          action: action,
          outfitDetails: {
            'items': outfit.items.map((e) => e.toJson()).toList(),
            'score': outfit.score,
            'reasoning': outfit.reasoning,
            'source': outfit.source,
          },
        );
  }

  void _handleAllRejected() {
    ref.read(dailyRecommendationProvider.notifier).markAllRejected();
  }

  void _showCalendarDialog(BuildContext context, DailyRecommendationState state) {
    final tpo = state.dailyRec?.tpo;
    if (tpo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予定情報を取得できませんでした')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.calendar_month, color: AppColors.primary),
            SizedBox(width: 8),
            Text('今日の予定'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tpo.summary,
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '推奨: ${tpo.formalityRequired == "casual" ? "カジュアル" : tpo.formalityRequired == "formal" ? "フォーマル" : "ビジネスカジュアル"}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
