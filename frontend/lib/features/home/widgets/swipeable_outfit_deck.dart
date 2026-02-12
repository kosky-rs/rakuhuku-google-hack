import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../../core/models/daily_recommendation.dart';
import '../../../config/theme.dart';

/// Swipeable outfit deck (Tinder-style)
class SwipeableOutfitDeck extends StatefulWidget {
  final List<OutfitRecommendation> recommendations;
  final Function(int index, String action) onSwipe;
  final VoidCallback onAllRejected;

  const SwipeableOutfitDeck({
    super.key,
    required this.recommendations,
    required this.onSwipe,
    required this.onAllRejected,
  });

  @override
  State<SwipeableOutfitDeck> createState() => _SwipeableOutfitDeckState();
}

class _SwipeableOutfitDeckState extends State<SwipeableOutfitDeck> {
  late final CardSwiperController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CardSwiperController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recommendations.isEmpty) {
      return const Center(
        child: Text('コーデが見つかりませんでした'),
      );
    }

    return CardSwiper(
      controller: _controller,
      cardsCount: widget.recommendations.length,
      numberOfCardsDisplayed: widget.recommendations.length > 1 ? 2 : 1,
      backCardOffset: const Offset(0, 30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      duration: const Duration(milliseconds: 300),
      maxAngle: 30,
      threshold: 80,
      scale: 0.9,
      isLoop: false,
      onSwipe: (previousIndex, currentIndex, direction) {
        if (direction == CardSwiperDirection.right) {
          widget.onSwipe(previousIndex, 'approve');
        } else if (direction == CardSwiperDirection.left) {
          widget.onSwipe(previousIndex, 'reject');
        }

        // If all cards swiped
        if (currentIndex == null) {
          Future.delayed(const Duration(milliseconds: 300), () {
            widget.onAllRejected();
          });
        }

        return true;
      },
      onEnd: () {
        widget.onAllRejected();
      },
      cardBuilder: (context, index, horizontalOffsetPercentage, verticalOffsetPercentage) {
        return _SwipeableOutfitCard(
          recommendation: widget.recommendations[index],
          horizontalOffset: horizontalOffsetPercentage.toDouble(),
        );
      },
    );
  }
}

/// Individual swipeable outfit card
class _SwipeableOutfitCard extends StatelessWidget {
  final OutfitRecommendation recommendation;
  final double horizontalOffset;

  const _SwipeableOutfitCard({
    required this.recommendation,
    required this.horizontalOffset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Main card
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Agent type badge
              _buildAgentBadge(context, isDark),

              // Items section
              Expanded(
                child: _buildItemsSection(context, isDark),
              ),

              // Score and reasoning
              _buildFooterSection(context, isDark),
            ],
          ),
        ),

        // Swipe indicators
        if (horizontalOffset.abs() > 0.1)
          _buildSwipeIndicator(context, horizontalOffset),
      ],
    );
  }

  Widget _buildAgentBadge(BuildContext context, bool isDark) {
    final agentColors = {
      'casual': Colors.blue,
      'formal': Colors.purple,
      'balanced': Colors.green,
      'unique': Colors.orange,
    };

    final agentLabels = {
      'casual': 'カジュアル',
      'formal': 'フォーマル',
      'balanced': 'バランス',
      'unique': 'ユニーク',
    };

    final color = agentColors[recommendation.agentType] ?? Colors.grey;
    final label = agentLabels[recommendation.agentType] ?? recommendation.agentType;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (recommendation.source == 'external')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '新商品',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recommendation.items.isNotEmpty)
            ...recommendation.items.map((item) => _buildItemTile(item, isDark)),
          if (recommendation.externalProducts != null &&
              recommendation.externalProducts!.isNotEmpty)
            ...recommendation.externalProducts!
                .map((product) => _buildExternalProductTile(product, isDark)),
        ],
      ),
    );
  }

  Widget _buildItemTile(item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark.withOpacity(0.5)
            : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.category} • ${item.color}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalProductTile(RakutenProduct product, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              product.imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark.withOpacity(0.5)
            : AppColors.backgroundLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                size: 16,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 4),
              Text(
                'スコア: ${recommendation.score.toStringAsFixed(1)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.reasoning,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeIndicator(BuildContext context, double offset) {
    final isRight = offset > 0;
    final opacity = (offset.abs() * 2).clamp(0.0, 1.0);

    return Positioned(
      top: 50,
      left: isRight ? null : 50,
      right: isRight ? 50 : null,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isRight ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRight ? Icons.check : Icons.close,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isRight ? '承認' : '拒否',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
