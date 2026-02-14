import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../../../core/models/clothing_item.dart';
import '../../closet/providers/closet_provider.dart';
import '../providers/diagnosis_provider.dart';

/// Diagnosis result screen showing score, suggestions, and detected items
class DiagnosisResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? result;

  const DiagnosisResultScreen({super.key, this.result});

  @override
  ConsumerState<DiagnosisResultScreen> createState() => _DiagnosisResultScreenState();
}

class _DiagnosisResultScreenState extends ConsumerState<DiagnosisResultScreen> {
  int _selectedTab = 0; // 0: Score, 1: Products, 2: Items

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    if (result == null) {
      return _buildErrorState();
    }

    final evaluation = result['evaluation'] as Map<String, dynamic>?;
    final detectedItems = result['detected_items'] as List<dynamic>? ?? [];
    final productSuggestions = result['product_suggestions'] as List<dynamic>? ?? [];
    final closetSuggestions = result['closet_suggestions'] as List<dynamic>? ?? [];

    final score = evaluation?['score']?.toDouble() ?? 0.0;
    final goodPoints = evaluation?['good_points'] as List<dynamic>? ?? [];
    final improvements = evaluation?['improvement_suggestions'] as List<dynamic>? ?? [];
    final overallStyle = evaluation?['overall_style'] ?? '';
    final colorHarmony = evaluation?['color_harmony'] ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, isDark),
            _buildTabBar(isDark),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildScoreTab(score, goodPoints, improvements, overallStyle, colorHarmony, isDark),
                  _buildProductsTab(productSuggestions, closetSuggestions, isDark),
                  _buildItemsTab(detectedItems, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('診断結果がありません'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              '診断結果',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            onPressed: () {
              // TODO: Share functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildTab('スコア', 0, Icons.star_outline, isDark),
          const SizedBox(width: 8),
          _buildTab('おすすめ商品', 1, Icons.shopping_bag_outlined, isDark),
          const SizedBox(width: 8),
          _buildTab('アイテム', 2, Icons.checkroom_outlined, isDark),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textMuted : AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textMuted : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreTab(
    double score,
    List<dynamic> goodPoints,
    List<dynamic> improvements,
    String overallStyle,
    String colorHarmony,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score card
          _buildScoreCard(score, overallStyle, isDark),
          const SizedBox(height: 24),

          // Color harmony
          if (colorHarmony.isNotEmpty) ...[
            _buildSectionTitle('色合わせ', isDark),
            const SizedBox(height: 8),
            _buildInfoCard(colorHarmony, Icons.palette_outlined, isDark),
            const SizedBox(height: 24),
          ],

          // Good points
          if (goodPoints.isNotEmpty) ...[
            _buildSectionTitle('良いポイント', isDark),
            const SizedBox(height: 8),
            ...goodPoints.map((point) => _buildPointItem(
                  point.toString(),
                  Icons.check_circle_outline,
                  AppColors.success,
                  isDark,
                )),
            const SizedBox(height: 24),
          ],

          // Improvements
          if (improvements.isNotEmpty) ...[
            _buildSectionTitle('改善ポイント', isDark),
            const SizedBox(height: 8),
            ...improvements.map((imp) {
              final impMap = imp as Map<String, dynamic>;
              return _buildImprovementCard(impMap, isDark);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard(double score, String style, bool isDark) {
    Color scoreColor;
    String scoreLabel;
    if (score >= 8) {
      scoreColor = AppColors.success;
      scoreLabel = '素晴らしい！';
    } else if (score >= 6) {
      scoreColor = AppColors.primary;
      scoreLabel = '良い';
    } else if (score >= 4) {
      scoreColor = AppColors.warning;
      scoreLabel = 'まあまあ';
    } else {
      scoreColor = AppColors.error;
      scoreLabel = '改善の余地あり';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withOpacity(0.1), scoreColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '/10',
                  style: TextStyle(
                    fontSize: 24,
                    color: scoreColor.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              scoreLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (style.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'スタイル: $style',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildInfoCard(String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointItem(String text, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementCard(Map<String, dynamic> improvement, bool isDark) {
    final point = improvement['point'] ?? '';
    final category = improvement['category'] ?? '';
    final suggestedColor = improvement['suggested_color'];
    final suggestedStyle = improvement['suggested_style'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            point,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          if (suggestedColor != null || suggestedStyle != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (suggestedColor != null)
                  Chip(
                    label: Text(suggestedColor),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelStyle: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                if (suggestedStyle != null)
                  Chip(
                    label: Text(suggestedStyle),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelStyle: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsTab(List<dynamic> products, List<dynamic> closetSuggestions, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Closet suggestions
          if (closetSuggestions.isNotEmpty) ...[
            _buildSectionTitle('クローゼットから', isDark),
            const SizedBox(height: 8),
            ...closetSuggestions.map((s) => _buildClosetSuggestionCard(s, isDark)),
            const SizedBox(height: 24),
          ],

          // Product suggestions
          _buildSectionTitle('ショップおすすめ', isDark),
          const SizedBox(height: 8),
          if (products.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'おすすめ商品はありません',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...products.map((p) => _buildProductCard(p, isDark)),
        ],
      ),
    );
  }

  Widget _buildClosetSuggestionCard(dynamic suggestion, bool isDark) {
    final suggestionMap = suggestion as Map<String, dynamic>;
    final point = suggestionMap['improvement_point'] ?? '';
    final suggestedItem = suggestionMap['suggested_item'] as Map<String, dynamic>?;

    if (suggestedItem == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checkroom, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestedItem['name'] ?? '不明なアイテム',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (point.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              point,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductCard(dynamic product, bool isDark) {
    final productMap = product as Map<String, dynamic>;
    final reason = productMap['suggestion_reason'] ?? '';
    final keywords = productMap['search_keywords'] as List<dynamic>? ?? [];
    final priceRange = productMap['price_range'] ?? '';
    final affiliateLinks = productMap['affiliate_links'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reason,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keywords.map((k) => Chip(
              label: Text(k.toString()),
              backgroundColor: AppColors.primary.withOpacity(0.1),
              labelStyle: TextStyle(color: AppColors.primary, fontSize: 12),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            )).toList(),
          ),
          if (priceRange.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '価格帯: $priceRange',
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: affiliateLinks.map((link) {
              final linkMap = link as Map<String, dynamic>;
              return _buildAffiliateButton(linkMap, isDark);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliateButton(Map<String, dynamic> link, bool isDark) {
    final provider = link['provider'] ?? '';
    final url = link['url'] ?? '';
    final displayName = link['display_name'] ?? 'ショップ';

    Color buttonColor;
    switch (provider) {
      case 'zozotown':
        buttonColor = const Color(0xFF00A0E9);
        break;
      case 'rakuten':
        buttonColor = const Color(0xFFBF0000);
        break;
      case 'amazon':
        buttonColor = const Color(0xFFFF9900);
        break;
      default:
        buttonColor = AppColors.primary;
    }

    return InkWell(
      onTap: () => _launchUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('このリンクを開けません'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('リンクを開けませんでした'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildItemsTab(List<dynamic> items, bool isDark) {
    final diagnosisState = ref.watch(diagnosisProvider);
    final deduplicatedItems = diagnosisState.deduplicatedItems;

    // Group by ClothingCategory in enum order
    final Map<ClothingCategory, List<Map<String, dynamic>>> grouped = {};
    for (final cat in ClothingCategory.values) {
      grouped[cat] = [];
    }
    for (final item in deduplicatedItems) {
      final categoryStr = (item['category'] as String? ?? 'tops').toLowerCase();
      final cat = ClothingCategory.fromString(categoryStr);
      grouped[cat]!.add(item);
    }

    // Filter out empty categories
    final nonEmptyCategories = ClothingCategory.values
        .where((cat) => grouped[cat]!.isNotEmpty)
        .toList();

    return Column(
      children: [
        Expanded(
          child: nonEmptyCategories.isEmpty
              ? Center(
                  child: Text(
                    'アイテムが検出されませんでした',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final cat in nonEmptyCategories) ...[
                      _buildCategoryHeader(cat, isDark),
                      for (final item in grouped[cat]!)
                        _buildItemCard(
                          item,
                          isDark,
                          cat != ClothingCategory.accessories,
                        ),
                    ],
                  ],
                ),
        ),
        _buildRegisterButton(items, diagnosisState, isDark),
      ],
    );
  }

  Widget _buildCategoryHeader(ClothingCategory category, bool isDark) {
    final isSingleSelect = category != ClothingCategory.accessories;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Text(
            category.label,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isSingleSelect ? '(1つ選択)' : '(複数選択可)',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isDark, bool isSingleSelect) {
    final name = item['name'] ?? '不明';
    final category = item['category'] ?? '';
    final color = item['color'] ?? '';
    final croppedImage = item['cropped_image_base64'] as String?;
    final isSelected = ref.read(diagnosisProvider.notifier).isItemSelected(item);

    // Map category to Japanese label
    final categoryLabel = category.toString().isNotEmpty
        ? ClothingCategory.fromString(category).label
        : '';

    return GestureDetector(
      onTap: () => ref.read(diagnosisProvider.notifier).toggleItemSelection(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator: radio for single-select, checkbox for multi-select
            if (isSingleSelect)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            const SizedBox(width: 12),

            // Image
            if (croppedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(croppedImage),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.checkroom, color: AppColors.textMuted),
              ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (color.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      color,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton(List<dynamic> items, DiagnosisState state, bool isDark) {
    final selectedCount = state.selectedItems.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$selectedCount 件選択中',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedCount > 0 ? _registerItems : null,
                child: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('クローゼットに追加'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerItems() async {
    try {
      final selectedCount = ref.read(diagnosisProvider).selectedItems.length;

      if (selectedCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('アイテムを選択してください'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final success = await ref.read(diagnosisProvider.notifier).registerSelectedItems();

      if (!mounted) return;

      if (success) {
        // Refresh closet data so the closet screen shows the newly added items
        await ref.read(closetProvider.notifier).fetchCloset();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$selectedCount 件のアイテムをクローゼットに追加しました！'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
        context.goHome();
      } else {
        final error = ref.read(diagnosisProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'アイテムの登録に失敗しました'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('予期しないエラーが発生しました: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
