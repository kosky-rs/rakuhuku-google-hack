import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../../../core/providers/user_provider.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/gender_selector.dart';
import '../widgets/age_range_selector.dart';
import '../widgets/style_preference_selector.dart';
import '../widgets/body_concern_selector.dart';
import '../widgets/lifestyle_selector.dart';

/// Profile setup screen (5-step wizard)
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final onboardingState = ref.read(onboardingProvider);

    if (onboardingState.currentStep.isLast) {
      _completeOnboarding();
    } else {
      ref.read(onboardingProvider.notifier).nextStep();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    final onboardingState = ref.read(onboardingProvider);

    if (onboardingState.currentStep.isFirst) {
      context.go(AppRoutes.login);
    } else {
      ref.read(onboardingProvider.notifier).previousStep();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final onboardingState = ref.read(onboardingProvider);

    // Update user profile with onboarding data
    await ref.read(userProvider.notifier).updateOnboardingData(
          gender: onboardingState.gender,
          ageRange: onboardingState.ageRange,
          stylePreference: onboardingState.stylePreference,
          bodyConcerns: onboardingState.bodyConcerns,
          lifestyle: onboardingState.lifestyle,
        );

    // Mark onboarding as complete
    await ref.read(userProvider.notifier).completeOnboarding();

    // Reset onboarding state
    ref.read(onboardingProvider.notifier).reset();

    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);
    final userState = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            _buildHeader(onboardingState),

            // Progress bar
            _buildProgressBar(onboardingState.progress),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPage(
                    GenderSelector(
                      selectedGender: onboardingState.gender,
                      onSelected: ref.read(onboardingProvider.notifier).setGender,
                    ),
                  ),
                  _buildPage(
                    AgeRangeSelector(
                      selectedAgeRange: onboardingState.ageRange,
                      onSelected:
                          ref.read(onboardingProvider.notifier).setAgeRange,
                    ),
                  ),
                  _buildPage(
                    StylePreferenceSelector(
                      selectedStyle: onboardingState.stylePreference,
                      onSelected: ref
                          .read(onboardingProvider.notifier)
                          .setStylePreference,
                    ),
                  ),
                  _buildPage(
                    BodyConcernSelector(
                      selectedConcerns: onboardingState.bodyConcerns,
                      onToggle: ref
                          .read(onboardingProvider.notifier)
                          .toggleBodyConcern,
                    ),
                  ),
                  _buildPage(
                    LifestyleSelector(
                      selectedLifestyle: onboardingState.lifestyle,
                      onSelected:
                          ref.read(onboardingProvider.notifier).setLifestyle,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom buttons
            _buildBottomButtons(onboardingState, userState.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(OnboardingState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _previousStep,
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white70,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              'ステップ ${state.currentStep.stepIndex + 1} / ${OnboardingStep.values.length}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ),
          // Skip button (only for body concerns step)
          if (state.currentStep == OnboardingStep.bodyConcerns)
            TextButton(
              onPressed: _nextStep,
              child: const Text(
                'スキップ',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPage(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildBottomButtons(OnboardingState state, bool isLoading) {
    final isLastStep = state.currentStep.isLast;
    final canProceed = state.canProceed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          // Step indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: OnboardingStep.values.map((step) {
              final isActive = step == state.currentStep;
              final isCompleted = step.stepIndex < state.currentStep.stepIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary
                        : isCompleted
                            ? AppColors.primary.withOpacity(0.5)
                            : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Next/Complete button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (canProceed && !isLoading) ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      isLastStep ? '設定を完了' : '次へ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
