import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

/// User profile service provider
final userProfileServiceProvider = Provider((ref) => UserProfileService());

/// Service for Firestore user profile operations
class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Get user profile by ID
  Future<UserProfile?> getProfile(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson({...doc.data()!, 'id': doc.id});
  }

  /// Create a new user profile
  Future<UserProfile> createProfile({
    required String userId,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final now = DateTime.now();
    final profile = UserProfile(
      id: userId,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      createdAt: now,
      updatedAt: now,
    );

    await _usersCollection.doc(userId).set(profile.toJson());
    return profile;
  }

  /// Update user profile
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
    await _usersCollection.doc(profile.id).update(updatedProfile.toJson());
    return updatedProfile;
  }

  /// Update onboarding data
  Future<UserProfile> updateOnboardingData({
    required String userId,
    Gender? gender,
    AgeRange? ageRange,
    StylePreference? stylePreference,
    List<BodyConcern>? bodyConcerns,
    Lifestyle? lifestyle,
    bool? onboardingCompleted,
  }) async {
    final currentProfile = await getProfile(userId);
    if (currentProfile == null) {
      throw Exception('User profile not found');
    }

    final updatedProfile = currentProfile.copyWith(
      gender: gender ?? currentProfile.gender,
      ageRange: ageRange ?? currentProfile.ageRange,
      stylePreference: stylePreference ?? currentProfile.stylePreference,
      bodyConcerns: bodyConcerns ?? currentProfile.bodyConcerns,
      lifestyle: lifestyle ?? currentProfile.lifestyle,
      onboardingCompleted: onboardingCompleted ?? currentProfile.onboardingCompleted,
      updatedAt: DateTime.now(),
    );

    await _usersCollection.doc(userId).update(updatedProfile.toJson());
    return updatedProfile;
  }

  /// Complete onboarding
  Future<UserProfile> completeOnboarding(String userId) async {
    return updateOnboardingData(
      userId: userId,
      onboardingCompleted: true,
    );
  }

  /// Check if user exists
  Future<bool> userExists(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    return doc.exists;
  }

  /// Stream user profile changes
  Stream<UserProfile?> watchProfile(String userId) {
    return _usersCollection.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromJson({...doc.data()!, 'id': doc.id});
    });
  }
}
