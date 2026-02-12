import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Google Sign-In with Calendar scope
final googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar.readonly',
  ],
);

/// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Auth service provider
final authServiceProvider = Provider((ref) => AuthService());

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Google Sign-Inを実行し、access_tokenを返す
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // ユーザーがキャンセル

      final googleAuth = await googleUser.authentication;

      // Firebase Authに登録
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);

      return googleAuth.accessToken;
    } catch (e) {
      // エラーを再スロー
      rethrow;
    }
  }

  /// 現在のaccess_tokenを取得（更新可能）
  Future<String?> getAccessToken() async {
    final googleUser = googleSignIn.currentUser ?? await googleSignIn.signInSilently();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    return googleAuth.accessToken;
  }

  /// サインアウト
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      googleSignIn.signOut(),
    ]);
  }
}
