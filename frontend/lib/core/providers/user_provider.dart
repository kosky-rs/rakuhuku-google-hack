import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/auth_service.dart';

/// User state
class UserState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const UserState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isSignedIn => profile != null;
  bool get needsOnboarding => profile != null && !profile!.onboardingCompleted;
  bool get isReady => profile != null && profile!.onboardingCompleted;
}

/// User notifier
class UserNotifier extends StateNotifier<UserState> {
  final UserProfileService _profileService;
  final AuthService _authService;

  UserNotifier(this._profileService, this._authService)
      : super(const UserState());

  /// Initialize user state based on Firebase Auth
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        state = const UserState();
        return;
      }

      final profile = await _profileService.getProfile(firebaseUser.uid);
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load user profile: $e',
      );
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final accessToken = await _authService.signInWithGoogle();
      if (accessToken == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Authentication failed',
        );
        return false;
      }

      var profile = await _profileService.getProfile(firebaseUser.uid);

      if (profile == null) {
        profile = await _profileService.createProfile(
          userId: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName,
          photoUrl: firebaseUser.photoURL,
        );
      }

      state = state.copyWith(profile: profile, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign in failed: $e',
      );
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.signOut();
      state = const UserState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign out failed: $e',
      );
    }
  }

  /// Update profile
  Future<void> updateProfile(UserProfile profile) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedProfile = await _profileService.updateProfile(profile);
      state = state.copyWith(profile: updatedProfile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update profile: $e',
      );
    }
  }

  /// Update onboarding data
  Future<void> updateOnboardingData({
    Gender? gender,
    AgeRange? ageRange,
    StylePreference? stylePreference,
    List<BodyConcern>? bodyConcerns,
    Lifestyle? lifestyle,
  }) async {
    if (state.profile == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedProfile = await _profileService.updateOnboardingData(
        userId: state.profile!.id,
        gender: gender,
        ageRange: ageRange,
        stylePreference: stylePreference,
        bodyConcerns: bodyConcerns,
        lifestyle: lifestyle,
      );
      state = state.copyWith(profile: updatedProfile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update onboarding data: $e',
      );
    }
  }

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    if (state.profile == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedProfile = await _profileService.completeOnboarding(
        state.profile!.id,
      );
      state = state.copyWith(profile: updatedProfile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to complete onboarding: $e',
      );
    }
  }
}

/// User provider
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final profileService = ref.watch(userProfileServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return UserNotifier(profileService, authService);
});

/// Auth state stream provider (from Firebase Auth)
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Convenience providers
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(userProvider).isSignedIn;
});

final needsOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(userProvider).needsOnboarding;
});

final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(userProvider).profile;
});
