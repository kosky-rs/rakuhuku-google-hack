import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../../../core/models/daily_recommendation.dart';
import '../../../core/models/clothing_item.dart';
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
      final notifier = ref.read(dailyRecommendationProvider.notifier);
      notifier.prefetchWeatherAndCalendar(); // 先行取得（軽量）
      notifier.fetchDailyRecommendations(); // 既存フロー（変更なし）
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
    // Show selected today's outfit at top if available
    if (state.selectedTodayOutfit != null) {
      return _buildSelectedTodayOutfit(state.selectedTodayOutfit!, state, isDark);
    }

    // Loading state
    if (state.isLoading) {
      final prefetchedWeather = state.prefetchedWeather;
      final prefetchedTpo = state.prefetchedTpo;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // プリフェッチされた天気・TPO情報を先行表示
            if (prefetchedWeather != null || prefetchedTpo != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    if (prefetchedWeather != null)
                      Row(
                        children: [
                          Icon(
                            _getWeatherIcon(prefetchedWeather.condition),
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${prefetchedWeather.temperature.round()}°C',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              prefetchedWeather.description,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (prefetchedWeather != null && prefetchedTpo != null)
                      const SizedBox(height: 8),
                    if (prefetchedTpo != null)
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              prefetchedTpo.summary,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
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
          // Horizontal browser with vertical swipe (weather/TPO integrated into card)
          Expanded(
            child: HorizontalOutfitBrowser(
              recommendations: state.recommendations,
              weather: state.dailyRec?.weather ?? state.prefetchedWeather,
              tpo: state.dailyRec?.tpo ?? state.prefetchedTpo,
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

          // Minimal swipe hint
          _buildMinimalSwipeHint(isDark),
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

  Widget _buildMinimalSwipeHint(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            '左右: 閲覧',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.arrow_upward, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            '上: 決定',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineWeatherTPO(dailyRec, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getWeatherIcon(dailyRec.weather.condition),
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${dailyRec.weather.temperature.toStringAsFixed(1)}°C',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dailyRec.tpo.summary,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

  Widget _buildSelectedTodayOutfit(
    OutfitRecommendation outfit,
    DailyRecommendationState state,
    bool isDark,
  ) {
    final imageUrl = outfit.mannequinImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Column(
      children: [
        // Full-bleed hero card (same style as browse card)
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Full-bleed image
                  if (hasImage)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: isDark ? AppColors.surfaceDark : Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => _buildSelectedPlaceholder(isDark),
                    )
                  else
                    _buildSelectedPlaceholder(isDark),

                  // Top badges
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        // "今日のコーデ" badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green[600]!, Colors.green[400]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                '今日のコーデ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),

                  // Bottom gradient overlay with info
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.4, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.78),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Weather
                          if (state.dailyRec != null) ...[
                            Row(
                              children: [
                                Icon(
                                  _getWeatherIcon(state.dailyRec!.weather.condition),
                                  color: Colors.white.withOpacity(0.9),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${state.dailyRec!.weather.temperature.round()}°C',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    state.dailyRec!.weather.description,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Theme name
                          Text(
                            _getSelectedThemeLabel(outfit.agentType),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Items
                          Text(
                            outfit.items.map((i) => i.name).join('  /  '),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              height: 1.4,
                              shadows: const [
                                Shadow(blurRadius: 4, color: Colors.black45),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 12),

                          // Score + change button
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${outfit.score.toInt()}点',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  ref.read(dailyRecommendationProvider.notifier).reset();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.swap_horiz, color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        '他のコーデに変更する',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Detail section (scrollable)
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reasoning
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AIの選定理由',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              outfit.reasoning,
                              style: AppTextStyles.bodySmall.copyWith(
                                height: 1.5,
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Items
                Text(
                  'アイテム',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                ...outfit.items.map((item) => _buildItemCard(item, isDark)).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.surfaceDark, const Color(0xFF0D1520)]
              : [Colors.grey[100]!, Colors.grey[300]!],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checkroom_outlined,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'コーディネート画像',
              style: AppTextStyles.bodyLarge.copyWith(
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSelectedThemeLabel(String agentType) {
    switch (agentType) {
      case 'casual':
        return 'カジュアルスタイル';
      case 'formal':
        return 'フォーマルスタイル';
      case 'balanced':
        return 'バランス型コーデ';
      case 'unique':
        return 'トレンド重視コーデ';
      default:
        return 'おすすめコーデ';
    }
  }

  Widget _buildItemCard(ClothingItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(item.category),
              color: AppColors.primary,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getCategoryName(item.category)} • ${item.color}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'tops':
        return Icons.checkroom;
      case 'bottoms':
        return Icons.safety_divider;
      case 'shoes':
        return Icons.snooze;
      case 'outerwear':
        return Icons.dry_cleaning;
      case 'accessories':
        return Icons.watch;
      default:
        return Icons.shopping_bag;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'tops':
        return 'トップス';
      case 'bottoms':
        return 'ボトムス';
      case 'shoes':
        return 'シューズ';
      case 'outerwear':
        return 'アウター';
      case 'accessories':
        return 'アクセサリー';
      default:
        return category;
    }
  }

  void _showCalendarDialog(BuildContext context, DailyRecommendationState state) {
    final tpo = state.dailyRec?.tpo ?? state.prefetchedTpo;
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
