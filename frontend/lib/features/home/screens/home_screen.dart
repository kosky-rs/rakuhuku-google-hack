import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../../../core/models/outfit.dart';
import '../../../core/models/clothing_item.dart';
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
                      // Diagnosis CTA
                      _buildDiagnosisCta(isDark),

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
            onPressed: () {},
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
            onPressed: () {},
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

  void _handleWearOutfit(BuildContext context) {
    // TODO: Record outfit selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('コーデを履歴に保存しました！'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildDiagnosisCta(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'コーデ診断',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AIがあなたのコーデを採点します',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.goDiagnosis(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'コーデを診断する',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
