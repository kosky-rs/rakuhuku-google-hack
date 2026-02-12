import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/closet/screens/closet_screen.dart';
import '../features/closet/screens/camera_screen.dart';
import '../features/closet/screens/image_preview_screen.dart';
import '../features/closet/screens/add_item_form_screen.dart';
import '../features/diagnosis/screens/diagnosis_screen.dart';
import '../features/diagnosis/screens/diagnosis_result_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/onboarding/screens/profile_setup_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/profile_view_screen.dart';
import '../shared/widgets/app_scaffold.dart';

/// Route names
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const closet = '/closet';
  static const camera = '/closet/camera';
  static const imagePreview = '/closet/preview';
  static const addItem = '/closet/add';
  static const history = '/history';
  static const settings = '/settings';
  // Onboarding
  static const onboarding = '/onboarding';
  static const profileSetup = '/profile-setup';
  // Profile
  static const profileView = '/profile';
  // Diagnosis routes
  static const diagnosis = '/diagnosis';
  static const diagnosisResult = '/diagnosis/result';
}

/// Navigation shell key
final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

/// App router configuration
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: true,
  routes: [
    // Splash screen (outside shell)
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),

    // Login screen (outside shell)
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),

    // Onboarding tutorial screen (outside shell)
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Profile view screen (outside shell)
    GoRoute(
      path: AppRoutes.profileView,
      builder: (context, state) => const ProfileViewScreen(),
    ),

    // Profile setup screen (outside shell)
    GoRoute(
      path: AppRoutes.profileSetup,
      builder: (context, state) => const ProfileSetupScreen(),
    ),

    // Main shell with bottom navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        // Home tab
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),

        // Closet tab
        GoRoute(
          path: AppRoutes.closet,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ClosetScreen(),
          ),
        ),

        // History tab
        GoRoute(
          path: AppRoutes.history,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HistoryScreen(),
          ),
        ),

        // Settings tab
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),

    // Camera screen (full screen, outside shell)
    GoRoute(
      path: AppRoutes.camera,
      builder: (context, state) => const CameraScreen(),
    ),

    // Image preview screen
    GoRoute(
      path: AppRoutes.imagePreview,
      builder: (context, state) {
        final imagePath = state.extra as String?;
        return ImagePreviewScreen(imagePath: imagePath ?? '');
      },
    ),

    // Add item form screen
    GoRoute(
      path: AppRoutes.addItem,
      builder: (context, state) {
        final imagePath = state.extra as String?;
        return AddItemFormScreen(imagePath: imagePath);
      },
    ),

    // Diagnosis screen (full screen, outside shell)
    GoRoute(
      path: AppRoutes.diagnosis,
      builder: (context, state) {
        final imageData = state.extra as Map<String, dynamic>?;
        return DiagnosisScreen(initialImageData: imageData);
      },
    ),

    // Diagnosis result screen
    GoRoute(
      path: AppRoutes.diagnosisResult,
      builder: (context, state) {
        final result = state.extra as Map<String, dynamic>?;
        return DiagnosisResultScreen(result: result);
      },
    ),
  ],

  // Error page
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'ページが見つかりません',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            state.uri.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('ホームに戻る'),
          ),
        ],
      ),
    ),
  ),
);

/// Navigation extension for easier access
extension NavigationExtension on BuildContext {
  void goHome() => go(AppRoutes.home);
  void goLogin() => go(AppRoutes.login);
  void goCloset() => go(AppRoutes.closet);
  void goHistory() => go(AppRoutes.history);
  void goSettings() => go(AppRoutes.settings);
  void goCamera() => push(AppRoutes.camera);
  void goImagePreview(String imagePath) =>
      push(AppRoutes.imagePreview, extra: imagePath);
  void goAddItem({String? imagePath}) =>
      push(AppRoutes.addItem, extra: imagePath);
  // Diagnosis navigation
  void goDiagnosis([Map<String, dynamic>? imageData]) =>
      push(AppRoutes.diagnosis, extra: imageData);
  void goDiagnosisResult(Map<String, dynamic> result) =>
      push(AppRoutes.diagnosisResult, extra: result);
  // Onboarding navigation
  void goOnboarding() => go(AppRoutes.onboarding);
  void goProfileView() => push(AppRoutes.profileView);
  void goProfileSetup() => push(AppRoutes.profileSetup);
}
