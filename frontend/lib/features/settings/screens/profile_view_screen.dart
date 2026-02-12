import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/models/user_profile.dart';

/// Profile view screen - displays all user profile data
class ProfileViewScreen extends ConsumerWidget {
  const ProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userState = ref.watch(userProvider);
    final profile = userState.profile;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Container(
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
                      'プロフィール',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                    ),
                    onPressed: () => context.goProfileSetup(),
                  ),
                ],
              ),
            ),

            // Profile content
            Expanded(
              child: profile == null
                  ? _buildEmptyState(context)
                  : _buildProfileContent(context, profile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'プロフィールが設定されていません',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.goProfileSetup(),
            child: const Text('プロフィールを設定'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserProfile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar & name header
        _buildHeader(context, profile, isDark),

        const SizedBox(height: 24),

        // Profile details
        _buildSection(
          context,
          isDark,
          'パーソナル情報',
          [
            _ProfileItem(
              icon: Icons.wc,
              label: '性別',
              value: profile.gender?.label ?? '未設定',
            ),
            _ProfileItem(
              icon: Icons.cake_outlined,
              label: '年代',
              value: profile.ageRange?.label ?? '未設定',
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildSection(
          context,
          isDark,
          'スタイル設定',
          [
            _ProfileItem(
              icon: Icons.palette_outlined,
              label: 'スタイルの好み',
              value: profile.stylePreference?.label ?? '未設定',
              subtitle: profile.stylePreference?.description,
            ),
            _ProfileItem(
              icon: Icons.work_outline,
              label: 'ライフスタイル',
              value: profile.lifestyle?.label ?? '未設定',
              subtitle: profile.lifestyle?.description,
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildSection(
          context,
          isDark,
          '体型のお悩み',
          [
            _ProfileItem(
              icon: Icons.accessibility_new,
              label: '気になるポイント',
              value: profile.bodyConcerns.isNotEmpty
                  ? profile.bodyConcerns.map((c) => c.label).join('、')
                  : '未設定',
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildSection(
          context,
          isDark,
          'アカウント',
          [
            _ProfileItem(
              icon: Icons.email_outlined,
              label: 'メール',
              value: profile.email,
            ),
            if (profile.displayName != null)
              _ProfileItem(
                icon: Icons.badge_outlined,
                label: '表示名',
                value: profile.displayName!,
              ),
          ],
        ),

        const SizedBox(height: 32),

        // Edit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.goProfileSetup(),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('プロフィールを編集'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage:
                profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
            child: profile.photoUrl == null
                ? const Icon(Icons.person, size: 40, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            profile.displayName ?? 'ユーザー',
            style: AppTextStyles.h2.copyWith(
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          // Email
          Text(
            profile.email,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    bool isDark,
    String title,
    List<_ProfileItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
