import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../core/models/user_profile.dart';

class BodyConcernSelector extends StatelessWidget {
  final List<BodyConcern> selectedConcerns;
  final ValueChanged<BodyConcern> onToggle;

  const BodyConcernSelector({
    super.key,
    required this.selectedConcerns,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '体型の悩みはありますか？',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '複数選択可・スキップもOKです',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '悩みに合わせた着こなしをアドバイスします',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 32),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children:
              BodyConcern.values.map((concern) => _buildOption(concern)).toList(),
        ),
      ],
    );
  }

  Widget _buildOption(BodyConcern concern) {
    final isSelected = selectedConcerns.contains(concern);

    return InkWell(
      onTap: () => onToggle(concern),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIcon(concern),
              color: isSelected ? AppColors.primary : Colors.white70,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              concern.label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(BodyConcern concern) {
    switch (concern) {
      case BodyConcern.height:
        return Icons.height;
      case BodyConcern.weight:
        return Icons.monitor_weight_outlined;
      case BodyConcern.shoulders:
        return Icons.accessibility_new;
      case BodyConcern.waist:
        return Icons.straighten;
      case BodyConcern.legs:
        return Icons.directions_walk;
      case BodyConcern.arms:
        return Icons.sports_handball;
    }
  }
}
