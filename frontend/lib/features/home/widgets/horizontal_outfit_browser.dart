import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../core/models/daily_recommendation.dart';
import '../../../config/theme.dart';
import 'enhanced_outfit_card.dart';

/// Horizontal outfit browser with vertical swipe gestures
///
/// Features:
/// - Horizontal scroll: Browse through outfit recommendations (PageView)
/// - Vertical swipe up: Select as today's outfit with celebration animation
/// - Vertical swipe down: Skip to next outfit
class HorizontalOutfitBrowser extends StatefulWidget {
  final List<OutfitRecommendation> recommendations;
  final Function(int index, OutfitRecommendation) onSelectAsToday;
  final Function(int index) onSkip;

  const HorizontalOutfitBrowser({
    super.key,
    required this.recommendations,
    required this.onSelectAsToday,
    required this.onSkip,
  });

  @override
  State<HorizontalOutfitBrowser> createState() => _HorizontalOutfitBrowserState();
}

class _HorizontalOutfitBrowserState extends State<HorizontalOutfitBrowser> {
  late PageController _pageController;
  late ConfettiController _confettiController;
  double _verticalDragDistance = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recommendations.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        // Main content: PageView with gesture detection
        GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() {
              _verticalDragDistance += details.delta.dy;
            });
          },
          onVerticalDragEnd: (details) {
            if (_verticalDragDistance < -100) {
              // Swipe up: Select as today
              _handleSelectAsToday();
            } else if (_verticalDragDistance > 100) {
              // Swipe down: Skip
              _handleSkip();
            }
            setState(() {
              _verticalDragDistance = 0;
            });
          },
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.recommendations.length,
            itemBuilder: (context, index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.identity()
                  ..translate(0.0, _verticalDragDistance.clamp(-50.0, 50.0)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: EnhancedOutfitCard(
                    recommendation: widget.recommendations[index],
                  ),
                ),
              );
            },
          ),
        ),

        // Confetti animation
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            blastDirection: -3.14 / 2, // Up
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.1,
            colors: const [
              AppColors.primary,
              AppColors.secondary,
              Colors.pink,
              Colors.green,
              Colors.orange,
            ],
          ),
        ),

        // Swipe indicator
        if (_verticalDragDistance.abs() > 20)
          Positioned(
            top: _verticalDragDistance < 0 ? 20 : null,
            bottom: _verticalDragDistance > 0 ? 20 : null,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _verticalDragDistance < 0
                      ? Colors.green.withOpacity(0.9)
                      : Colors.grey.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _verticalDragDistance < 0 ? Icons.check_circle : Icons.skip_next,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _verticalDragDistance < 0 ? '今日のコーデに決定!' : 'スキップ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Page indicator
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.recommendations.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? AppColors.primary
                      : AppColors.textMuted.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleSelectAsToday() {
    final currentIndex = _pageController.page?.round() ?? 0;
    final outfit = widget.recommendations[currentIndex];

    // Play confetti
    _confettiController.play();

    // Show celebration dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '今日のコーデに決定!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '素敵な一日を過ごしてください！',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Auto-close dialog after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
        _confettiController.stop();
      }
    });

    // Trigger callback
    widget.onSelectAsToday(currentIndex, outfit);
  }

  void _handleSkip() {
    final currentIndex = _pageController.page?.round() ?? 0;
    widget.onSkip(currentIndex);

    // Move to next page if available
    if (currentIndex < widget.recommendations.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Show message that all outfits have been viewed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('すべてのコーデを確認しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
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
            'コーデ提案がありません',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'クローゼットにアイテムを追加してください',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
