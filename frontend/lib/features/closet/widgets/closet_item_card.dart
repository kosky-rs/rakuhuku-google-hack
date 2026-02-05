import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../core/models/clothing_item.dart';

/// Closet item card matching stitch design
class ClosetItemCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback? onTap;

  const ClosetItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or placeholder
                  item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _buildLoading();
                          },
                        )
                      : _buildPlaceholder(),

                  // Usage score badge
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _buildUsageBadge(isDark),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Item name
          Text(
            item.name,
            style: AppTextStyles.labelLarge.copyWith(
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Brand
          if (item.brand != null) ...[
            const SizedBox(height: 2),
            Text(
              item.brand!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.backgroundLight,
      child: Center(
        child: Icon(
          _getCategoryIcon(item.category),
          size: 48,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: AppColors.backgroundLight,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildUsageBadge(bool isDark) {
    final scorePercent = item.usageScore.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withOpacity(0.9)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Container(
            width: 32,
            height: 6,
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: scorePercent / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$scorePercent%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
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
