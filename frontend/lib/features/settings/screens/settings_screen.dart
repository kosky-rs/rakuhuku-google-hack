import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/models/user_profile.dart';
import '../../onboarding/widgets/style_preference_selector.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userState = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      '設定',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Settings list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection(
                    context,
                    'アカウント',
                    [
                      _SettingsTile(
                        icon: Icons.person_outline,
                        title: 'プロフィール',
                        subtitle: 'プロフィールを確認・編集',
                        onTap: () => context.goProfileView(),
                      ),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: '通知',
                        subtitle: '通知の管理',
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildSection(
                    context,
                    '環境設定',
                    [
                      _SettingsTile(
                        icon: Icons.location_on_outlined,
                        title: '位置情報と天気',
                        subtitle: '位置情報を設定',
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: Icons.palette_outlined,
                        title: 'スタイルの好み',
                        subtitle: userState.profile?.stylePreference?.label ?? 'スタイルをカスタマイズ',
                        onTap: () => _showStylePreferenceSheet(context, ref, userState),
                      ),
                      _SettingsTile(
                        icon: Icons.calendar_today_outlined,
                        title: 'カレンダー連携',
                        subtitle: 'Googleカレンダーと連携済み',
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildSection(
                    context,
                    'サポート',
                    [
                      _SettingsTile(
                        icon: Icons.help_outline,
                        title: 'ヘルプ・よくある質問',
                        subtitle: 'ヘルプと回答を見る',
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: Icons.info_outline,
                        title: 'アプリについて',
                        subtitle: 'バージョン 1.0.0',
                        onTap: () => _showAboutDialog(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Account info (if signed in)
                  if (userState.profile != null)
                    _buildSection(
                      context,
                      'アカウント情報',
                      [
                        _SettingsTile(
                          icon: Icons.email_outlined,
                          title: userState.profile!.email,
                          subtitle: userState.profile!.displayName ?? 'ユーザー',
                          onTap: () {},
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Logout button
                  _buildLogoutButton(context, ref),

                  const SizedBox(height: 48),

                  // Version info
                  Center(
                    child: Text(
                      'Rakufuku v1.0.0\nAIパーソナルスタイリスト',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStylePreferenceSheet(BuildContext context, WidgetRef ref, UserState userState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: StylePreferenceSelector(
                  selectedStyle: userState.profile?.stylePreference,
                  onSelected: (style) {
                    ref.read(userProvider.notifier).updateOnboardingData(
                      stylePreference: style,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('スタイルを「${style.label}」に変更しました'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rakufuku'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('バージョン 1.0.0'),
            SizedBox(height: 8),
            Text('毎朝1分で正解のコーディネートを提案するAIパーソナルスタイリスト'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: () => _showLogoutConfirmation(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                color: AppColors.error,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'ログアウト',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'ログアウト',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'ログアウトしてもよろしいですか？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(userProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            child: const Text(
              'ログアウト',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_SettingsTile> tiles,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            children: tiles.asMap().entries.map((entry) {
              final isLast = entry.key == tiles.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 56,
                      color:
                          isDark ? AppColors.borderDark : AppColors.borderLight,
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
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
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
