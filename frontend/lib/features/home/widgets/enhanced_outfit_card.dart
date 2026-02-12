import 'package:flutter/material.dart';
import '../../../core/models/daily_recommendation.dart';
import '../../../config/theme.dart';

/// Enhanced outfit card with theme badge, AI score, and detailed reasoning
class EnhancedOutfitCard extends StatelessWidget {
  final OutfitRecommendation recommendation;

  const EnhancedOutfitCard({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with theme badge
          _buildHeader(isDark),

          // Outfit collage
          Expanded(
            child: _buildOutfitCollage(isDark),
          ),

          // AI Score section
          _buildAIScoreSection(isDark),

          // Reasoning section
          _buildReasoningSection(isDark),

          // Source indicator
          if (recommendation.source != 'closet')
            _buildSourceIndicator(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildThemeBadge(recommendation.agentType),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'AIセレクト',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeBadge(String agentType) {
    final themeMap = {
      'casual': ('カジュアルスタイル', Icons.weekend, Colors.blue),
      'formal': ('フォーマルスタイル', Icons.business, Colors.purple),
      'balanced': ('バランス型', Icons.balance, Colors.green),
      'unique': ('トレンド重視', Icons.star, Colors.orange),
    };

    final theme = themeMap[agentType] ?? ('スタイル', Icons.style, Colors.grey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.$3.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.$3.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.$2, color: theme.$3, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              theme.$1,
              style: TextStyle(
                color: theme.$3,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitCollage(bool isDark) {
    if (recommendation.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checkroom_outlined,
              size: 80,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'アイテムがありません',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark.withOpacity(0.5)
            : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: recommendation.items.take(4).map((item) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildItemPlaceholder(item),
                    ),
                  )
                : _buildItemPlaceholder(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemPlaceholder(item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _getCategoryIcon(item.category),
          size: 40,
          color: AppColors.primary.withOpacity(0.3),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            item.name,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAIScoreSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AIおすすめ度',
                style: AppTextStyles.labelLarge.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${recommendation.score.toInt()}点',
                style: AppTextStyles.h3.copyWith(
                  color: _getScoreColor(recommendation.score),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: recommendation.score / 100,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor(recommendation.score),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final filled = index < (recommendation.score / 20).round();
              return Icon(
                filled ? Icons.star : Icons.star_border,
                size: 20,
                color: Colors.amber,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '選定理由',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  recommendation.reasoning,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceIndicator(bool isDark) {
    if (recommendation.source == 'closet') {
      return const SizedBox.shrink();
    }

    String sourceText;
    IconData sourceIcon;
    Color sourceColor;

    if (recommendation.source == 'external') {
      sourceText = '楽天おすすめ商品';
      sourceIcon = Icons.shopping_bag_outlined;
      sourceColor = Colors.orange;
    } else {
      sourceText = 'クローゼット + 楽天';
      sourceIcon = Icons.auto_awesome;
      sourceColor = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: sourceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: sourceColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sourceIcon, color: sourceColor, size: 20),
          const SizedBox(width: 8),
          Text(
            sourceText,
            style: TextStyle(
              color: sourceColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tops':
        return Icons.checkroom;
      case 'bottoms':
        return Icons.straighten;
      case 'outerwear':
        return Icons.ac_unit;
      case 'shoes':
        return Icons.directions_walk;
      case 'accessories':
        return Icons.watch;
      default:
        return Icons.category;
    }
  }
}
