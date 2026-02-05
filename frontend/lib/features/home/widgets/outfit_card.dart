import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../core/models/outfit.dart';
import '../../../core/models/clothing_item.dart';

/// Outfit recommendation card widget
class OutfitCard extends StatelessWidget {
  final OutfitRecommendation recommendation;
  final List<AlternativeOutfit> alternatives;
  final int selectedAlternativeIndex;
  final VoidCallback onSelectMain;
  final Function(int) onSelectAlternative;
  final VoidCallback onWearOutfit;
  final VoidCallback onRefresh;

  const OutfitCard({
    super.key,
    required this.recommendation,
    required this.alternatives,
    required this.selectedAlternativeIndex,
    required this.onSelectMain,
    required this.onSelectAlternative,
    required this.onWearOutfit,
    required this.onRefresh,
  });

  List<ClothingItem> get _currentItems {
    if (selectedAlternativeIndex >= 0 &&
        selectedAlternativeIndex < alternatives.length) {
      return alternatives[selectedAlternativeIndex].items;
    }
    return recommendation.items;
  }

  String get _currentTitle {
    if (selectedAlternativeIndex >= 0 &&
        selectedAlternativeIndex < alternatives.length) {
      return '代替コーデ ${selectedAlternativeIndex + 1}';
    }
    return 'エグゼクティブスタイル';
  }

  String get _currentSubtitle {
    if (selectedAlternativeIndex >= 0 &&
        selectedAlternativeIndex < alternatives.length) {
      return alternatives[selectedAlternativeIndex].description;
    }
    return '10:00のプレゼンに最適なコーデ';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Outfit image section
          _buildImageSection(context, isDark),

          // Details section
          _buildDetailsSection(context, isDark),

          // Actions section
          _buildActionsSection(context),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark.withOpacity(0.5)
            : AppColors.backgroundLight,
      ),
      child: Column(
        children: [
          // Outfit collage placeholder
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? AppColors.surfaceDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _currentItems.isNotEmpty
                  ? _buildOutfitCollage()
                  : const Center(
                      child: Icon(
                        Icons.checkroom,
                        size: 64,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Outfit info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentTitle,
                      style: AppTextStyles.h2.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentSubtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'AIセレクト',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Item list
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Column(
              children: _currentItems.map((item) => _buildItemRow(item, isDark)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitCollage() {
    // Grid layout for outfit items
    if (_currentItems.isEmpty) {
      return const Center(
        child: Icon(Icons.checkroom, size: 64, color: AppColors.textMuted),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: _currentItems.take(4).map((item) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildItemPlaceholder(item),
                  ),
                )
              : _buildItemPlaceholder(item),
        );
      }).toList(),
    );
  }

  Widget _buildItemPlaceholder(ClothingItem item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _getCategoryIcon(item.category),
          size: 32,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 4),
        Text(
          item.name,
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildItemRow(ClothingItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.white70 : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, bool isDark) {
    // Alternative outfit selector
    if (alternatives.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Main outfit dot
          GestureDetector(
            onTap: onSelectMain,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectedAlternativeIndex == -1
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Alternative dots
          ...List.generate(alternatives.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => onSelectAlternative(index),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selectedAlternativeIndex == index
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Wear button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onWearOutfit,
              icon: const Icon(Icons.checkroom),
              label: const Text('このコーデを着る'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Refresh button
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('別のコーデを提案'),
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
      default:
        return Icons.category;
    }
  }
}
