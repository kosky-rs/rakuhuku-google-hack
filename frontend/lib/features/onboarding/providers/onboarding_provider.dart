import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';

/// Onboarding step enum
enum OnboardingStep {
  gender(0, '性別'),
  ageRange(1, '年代'),
  style(2, 'スタイル'),
  bodyConcerns(3, '体型の悩み'),
  lifestyle(4, 'ライフスタイル');

  final int stepIndex;
  final String title;

  const OnboardingStep(this.stepIndex, this.title);

  static OnboardingStep fromStepIndex(int stepIndex) {
    return OnboardingStep.values.firstWhere(
      (e) => e.stepIndex == stepIndex,
      orElse: () => OnboardingStep.gender,
    );
  }

  OnboardingStep? get next {
    if (stepIndex < OnboardingStep.values.length - 1) {
      return OnboardingStep.fromStepIndex(stepIndex + 1);
    }
    return null;
  }

  OnboardingStep? get previous {
    if (stepIndex > 0) {
      return OnboardingStep.fromStepIndex(stepIndex - 1);
    }
    return null;
  }

  bool get isFirst => stepIndex == 0;
  bool get isLast => stepIndex == OnboardingStep.values.length - 1;
}

/// Onboarding state
class OnboardingState {
  final OnboardingStep currentStep;
  final Gender? gender;
  final AgeRange? ageRange;
  final StylePreference? stylePreference;
  final List<BodyConcern> bodyConcerns;
  final Lifestyle? lifestyle;
  final bool isLoading;
  final String? error;

  const OnboardingState({
    this.currentStep = OnboardingStep.gender,
    this.gender,
    this.ageRange,
    this.stylePreference,
    this.bodyConcerns = const [],
    this.lifestyle,
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    Gender? gender,
    AgeRange? ageRange,
    StylePreference? stylePreference,
    List<BodyConcern>? bodyConcerns,
    Lifestyle? lifestyle,
    bool? isLoading,
    String? error,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      gender: gender ?? this.gender,
      ageRange: ageRange ?? this.ageRange,
      stylePreference: stylePreference ?? this.stylePreference,
      bodyConcerns: bodyConcerns ?? this.bodyConcerns,
      lifestyle: lifestyle ?? this.lifestyle,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Check if current step is valid to proceed
  bool get canProceed {
    switch (currentStep) {
      case OnboardingStep.gender:
        return gender != null;
      case OnboardingStep.ageRange:
        return ageRange != null;
      case OnboardingStep.style:
        return stylePreference != null;
      case OnboardingStep.bodyConcerns:
        return true; // Optional step
      case OnboardingStep.lifestyle:
        return lifestyle != null;
    }
  }

  /// Check if all required fields are complete
  bool get isComplete =>
      gender != null &&
      ageRange != null &&
      stylePreference != null &&
      lifestyle != null;

  /// Progress percentage (0.0 - 1.0)
  double get progress => (currentStep.stepIndex + 1) / OnboardingStep.values.length;
}

/// Onboarding notifier
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void setGender(Gender gender) {
    state = state.copyWith(gender: gender);
  }

  void setAgeRange(AgeRange ageRange) {
    state = state.copyWith(ageRange: ageRange);
  }

  void setStylePreference(StylePreference style) {
    state = state.copyWith(stylePreference: style);
  }

  void toggleBodyConcern(BodyConcern concern) {
    final concerns = List<BodyConcern>.from(state.bodyConcerns);
    if (concerns.contains(concern)) {
      concerns.remove(concern);
    } else {
      concerns.add(concern);
    }
    state = state.copyWith(bodyConcerns: concerns);
  }

  void setLifestyle(Lifestyle lifestyle) {
    state = state.copyWith(lifestyle: lifestyle);
  }

  void nextStep() {
    final next = state.currentStep.next;
    if (next != null) {
      state = state.copyWith(currentStep: next);
    }
  }

  void previousStep() {
    final previous = state.currentStep.previous;
    if (previous != null) {
      state = state.copyWith(currentStep: previous);
    }
  }

  void goToStep(OnboardingStep step) {
    state = state.copyWith(currentStep: step);
  }

  void reset() {
    state = const OnboardingState();
  }
}

/// Onboarding provider
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});

/// Current step provider
final currentStepProvider = Provider<OnboardingStep>((ref) {
  return ref.watch(onboardingProvider).currentStep;
});

/// Can proceed provider
final canProceedProvider = Provider<bool>((ref) {
  return ref.watch(onboardingProvider).canProceed;
});

/// Progress provider
final onboardingProgressProvider = Provider<double>((ref) {
  return ref.watch(onboardingProvider).progress;
});
