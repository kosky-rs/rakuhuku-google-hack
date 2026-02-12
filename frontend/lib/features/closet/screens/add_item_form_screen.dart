import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../../../core/models/clothing_item.dart';
import '../../../core/models/closet.dart';
import '../../../core/services/storage_service.dart';
import '../../home/providers/outfit_provider.dart' show currentUserIdProvider;
import '../providers/closet_provider.dart';

/// Add item form screen
class AddItemFormScreen extends ConsumerStatefulWidget {
  final String? imagePath;

  const AddItemFormScreen({
    super.key,
    this.imagePath,
  });

  @override
  ConsumerState<AddItemFormScreen> createState() => _AddItemFormScreenState();
}

class _AddItemFormScreenState extends ConsumerState<AddItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  ClothingCategory _selectedCategory = ClothingCategory.tops;
  String _selectedColor = 'Black';
  FormalityLevel _selectedFormality = FormalityLevel.casual;
  final Set<Season> _selectedSeasons = {Season.allSeason};

  bool _isSubmitting = false;

  static const _colors = [
    'Black',
    'White',
    'Navy',
    'Grey',
    'Brown',
    'Beige',
    'Blue',
    'Red',
    'Green',
    'Pink',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('アイテムを追加'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image preview
            if (widget.imagePath != null)
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(widget.imagePath!),
                  fit: BoxFit.cover,
                ),
              ),

            // Name field
            _buildSectionTitle('名前'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '例: オックスフォードシャツ',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '名前を入力してください';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Category
            _buildSectionTitle('カテゴリ'),
            _buildCategorySelector(isDark),

            const SizedBox(height: 24),

            // Color
            _buildSectionTitle('カラー'),
            _buildColorSelector(isDark),

            const SizedBox(height: 24),

            // Formality
            _buildSectionTitle('フォーマル度'),
            _buildFormalitySelector(isDark),

            const SizedBox(height: 24),

            // Season
            _buildSectionTitle('シーズン'),
            _buildSeasonSelector(isDark),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ClothingCategory.values.take(4).map((category) {
        final isSelected = category == _selectedCategory;
        return ChoiceChip(
          label: Text(category.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => _selectedCategory = category);
          },
          selectedColor: AppColors.primary.withOpacity(0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colors.map((color) {
        final isSelected = color == _selectedColor;
        return ChoiceChip(
          label: Text(color),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => _selectedColor = color);
          },
          selectedColor: AppColors.primary.withOpacity(0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormalitySelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FormalityLevel.values.map((formality) {
        final isSelected = formality == _selectedFormality;
        return ChoiceChip(
          label: Text(formality.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => _selectedFormality = formality);
          },
          selectedColor: AppColors.primary.withOpacity(0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeasonSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Season.values.map((season) {
        final isSelected = _selectedSeasons.contains(season);
        return FilterChip(
          label: Text(season.label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (season == Season.allSeason) {
                _selectedSeasons.clear();
                _selectedSeasons.add(Season.allSeason);
              } else {
                _selectedSeasons.remove(Season.allSeason);
                if (selected) {
                  _selectedSeasons.add(season);
                } else {
                  _selectedSeasons.remove(season);
                }
                if (_selectedSeasons.isEmpty) {
                  _selectedSeasons.add(Season.allSeason);
                }
              }
            });
          },
          selectedColor: AppColors.primary.withOpacity(0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Upload image to Firebase Storage if image path exists
      String? uploadedImageUrl;
      if (widget.imagePath != null) {
        final userId = ref.read(currentUserIdProvider);
        uploadedImageUrl = await ref
            .read(storageServiceProvider)
            .uploadClothingImage(widget.imagePath!, userId);
      }

      final request = CreateClothingItemRequest(
        name: _nameController.text.trim(),
        category: _selectedCategory.value,
        color: _selectedColor.toLowerCase(),
        season: _selectedSeasons.map((s) => s.value).toList(),
        formality: _selectedFormality.value,
        imageUrl: uploadedImageUrl,
      );

      await ref.read(closetProvider.notifier).addItem(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('クローゼットに追加しました！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go(AppRoutes.closet);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像のアップロードに失敗しました: ${e.message}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アイテムの追加に失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
