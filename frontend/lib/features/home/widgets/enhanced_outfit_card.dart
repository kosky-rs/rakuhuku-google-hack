import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/daily_recommendation.dart';
import '../../../core/models/clothing_item.dart';
import '../../../config/theme.dart';

/// Full-bleed photo card with overlay text (Tinder-style)
class EnhancedOutfitCard extends StatelessWidget {
  final OutfitRecommendation recommendation;
  final Weather? weather;
  final TPO? tpo;
  final VoidCallback? onTap;

  const EnhancedOutfitCard({
    super.key,
    required this.recommendation,
    this.weather,
    this.tpo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showOutfitDetailDialog(context),
      child: Container(
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
              // Base: full-bleed image
              _buildFullBleedImage(isDark),

              // Bottom: gradient overlay with text info
              _buildBottomOverlay(isDark),

              // Top: floating badges
              _buildTopBadges(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullBleedImage(bool isDark) {
    final imageUrl = recommendation.mannequinImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (hasImage) {
      return Image.network(
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
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(isDark),
      );
    }

    return _buildImagePlaceholder(isDark);
  }

  Widget _buildImagePlaceholder(bool isDark) {
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

  Widget _buildTopBadges(bool isDark) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        children: [
          // Theme badge (frosted glass)
          _buildFrostedPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getThemeIcon(recommendation.agentType),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _getThemeName(recommendation.agentType),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Recommended badge
          if (recommendation.isRecommended) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'おすすめ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Source badge (if external)
          if (recommendation.source != 'closet')
            _buildFrostedPill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    recommendation.source == 'external'
                        ? Icons.shopping_bag_outlined
                        : Icons.auto_awesome,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    recommendation.source == 'external' ? '楽天' : 'MIX',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFrostedPill({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(bool isDark) {
    return Positioned(
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
            // Weather chip
            if (weather != null) ...[
              _buildWeatherChip(),
              const SizedBox(height: 10),
            ],

            // Theme name (large)
            Text(
              _getThemeLabel(recommendation.agentType),
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

            // Items list (compact, single line)
            Text(
              recommendation.items.map((i) => i.name).join('  /  '),
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

            // Score badge + tap hint
            Row(
              children: [
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
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
                        '${recommendation.score.toInt()}点',
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

                // Tap hint
                Text(
                  'タップで詳細',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.touch_app_outlined,
                  color: Colors.white.withOpacity(0.5),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherChip() {
    return Row(
      children: [
        Icon(
          _getWeatherIcon(weather!.condition),
          color: Colors.white.withOpacity(0.9),
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          '${weather!.temperature.round()}°C',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            weather!.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- Helper methods ---

  String _getThemeName(String agentType) {
    switch (agentType) {
      case 'casual':
        return 'カジュアル';
      case 'formal':
        return 'フォーマル';
      case 'balanced':
        return 'バランス';
      case 'unique':
        return 'トレンド';
      default:
        return 'スタイル';
    }
  }

  String _getThemeLabel(String agentType) {
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

  IconData _getThemeIcon(String agentType) {
    switch (agentType) {
      case 'casual':
        return Icons.weekend;
      case 'formal':
        return Icons.business;
      case 'balanced':
        return Icons.balance;
      case 'unique':
        return Icons.star;
      default:
        return Icons.style;
    }
  }

  IconData _getWeatherIcon(String condition) {
    if (condition.contains('晴') || condition.toLowerCase().contains('clear')) {
      return Icons.wb_sunny;
    }
    if (condition.contains('曇') || condition.toLowerCase().contains('cloud')) {
      return Icons.cloud;
    }
    if (condition.contains('雨') || condition.toLowerCase().contains('rain')) {
      return Icons.umbrella;
    }
    if (condition.contains('雪') || condition.toLowerCase().contains('snow')) {
      return Icons.ac_unit;
    }
    return Icons.wb_cloudy;
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

  String _getCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'tops':
        return 'トップス';
      case 'bottoms':
        return 'ボトムス';
      case 'outerwear':
        return 'アウター';
      case 'shoes':
        return 'シューズ';
      case 'accessories':
        return 'アクセサリー';
      default:
        return category;
    }
  }

  // --- Detail dialog (preserved from original) ---

  void _showOutfitDetailDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white,
                        size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'コーデ詳細',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Weather & TPO
                      if (weather != null) ...[
                        _buildDialogWeatherSection(isDark),
                        const SizedBox(height: 20),
                      ],

                      // Theme badge
                      _buildDialogThemeBadge(recommendation.agentType),

                      const SizedBox(height: 20),

                      // AI Score
                      Text(
                        'AIおすすめ度',
                        style: AppTextStyles.h3.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDialogAIScore(isDark),

                      const SizedBox(height: 24),

                      // Reasoning
                      Text(
                        'AIの選定理由',
                        style: AppTextStyles.h3.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.backgroundDark
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb, color: Colors.blue,
                                size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                recommendation.reasoning,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  height: 1.6,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Items
                      Text(
                        'アイテム',
                        style: AppTextStyles.h3.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...recommendation.items
                          .map((item) => _buildItemCard(item, isDark))
                          .toList(),

                      // External products
                      if (recommendation.externalProducts != null &&
                          recommendation.externalProducts!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          '楽天おすすめ商品',
                          style: AppTextStyles.h3.copyWith(
                            color:
                                isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recommendation.externalProducts!
                            .map((product) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.backgroundDark
                                        : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.shopping_bag,
                                              color: Colors.orange, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              product.name,
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            '\u00a5${product.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                            style: AppTextStyles.h3.copyWith(
                                              color: Colors.orange,
                                            ),
                                          ),
                                          if (product.reviewAverage !=
                                              null) ...[
                                            const SizedBox(width: 16),
                                            const Icon(Icons.star,
                                                color: Colors.amber, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              product.reviewAverage!
                                                  .toStringAsFixed(1),
                                              style: AppTextStyles.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        product.shopName,
                                        style:
                                            AppTextStyles.bodySmall.copyWith(
                                          color: isDark
                                              ? Colors.white70
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(ClothingItem item, bool isDark) {
    final isExternal = item.source == 'external';
    final isCloset = item.source == 'closet';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExternal
              ? Colors.orange.withOpacity(0.4)
              : isDark
                  ? AppColors.borderDark
                  : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isExternal
                      ? Colors.orange.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(item.category),
                  color: isExternal ? Colors.orange : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
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
              // Source badge
              if (isCloset)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checkroom, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '持っている',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isExternal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          color: Colors.orange, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '購入提案',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Marketplace links for external items
          if (isExternal &&
              item.marketplaceLinks != null &&
              item.marketplaceLinks!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.marketplaceLinks!
                  .map((link) => _buildMarketplaceLinkButton(link, isDark))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketplaceLinkButton(MarketplaceLink link, bool isDark) {
    // Platform-specific colors and icons
    final platformStyle = _getPlatformStyle(link.platform);

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(link.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: platformStyle.$2.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: platformStyle.$2.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(platformStyle.$1, color: platformStyle.$2, size: 16),
            const SizedBox(width: 6),
            Text(
              link.platform,
              style: TextStyle(
                color: platformStyle.$2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, color: platformStyle.$2, size: 12),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _getPlatformStyle(String platform) {
    if (platform.contains('楽天')) {
      return (Icons.shopping_bag, const Color(0xFFBF0000));
    } else if (platform.contains('Amazon')) {
      return (Icons.local_shipping, const Color(0xFFFF9900));
    } else if (platform.contains('ZOZO')) {
      return (Icons.storefront, const Color(0xFF00A5E3));
    }
    return (Icons.open_in_browser, Colors.grey);
  }

  Widget _buildDialogWeatherSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _getWeatherIcon(weather!.condition),
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${weather!.temperature.round()}°C',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              weather!.description,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
          if (tpo != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.event_note, color: AppColors.primary, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                tpo!.summary,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDialogThemeBadge(String agentType) {
    final themeMap = {
      'casual': ('カジュアルスタイル', Icons.weekend, Colors.blue),
      'formal': ('フォーマルスタイル', Icons.business, Colors.purple),
      'balanced': ('バランス型', Icons.balance, Colors.green),
      'unique': ('トレンド重視', Icons.star, Colors.orange),
    };

    final theme =
        themeMap[agentType] ?? ('スタイル', Icons.style, Colors.grey);

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
          Text(
            theme.$1,
            style: TextStyle(
              color: theme.$3,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogAIScore(bool isDark) {
    return Column(
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
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: recommendation.score / 100,
            minHeight: 8,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getScoreColor(recommendation.score),
            ),
          ),
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
    );
  }
}
