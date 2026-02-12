/// Gender options
enum Gender {
  male('male', '男性'),
  female('female', '女性'),
  other('other', 'その他');

  final String value;
  final String label;

  const Gender(this.value, this.label);

  static Gender fromString(String value) {
    return Gender.values.firstWhere(
      (e) => e.value == value,
      orElse: () => Gender.other,
    );
  }
}

/// Age range options
enum AgeRange {
  twenties('20s', '20代'),
  thirties('30s', '30代'),
  forties('40s', '40代'),
  fiftyPlus('50s+', '50代以上');

  final String value;
  final String label;

  const AgeRange(this.value, this.label);

  static AgeRange fromString(String value) {
    return AgeRange.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AgeRange.twenties,
    );
  }
}

/// Style preference options
enum StylePreference {
  casual('casual', 'カジュアル', 'リラックスした普段着スタイル'),
  elegant('elegant', 'キレイめ', '上品で洗練されたスタイル'),
  natural('natural', 'ナチュラル', '自然体でシンプルなスタイル'),
  mode('mode', 'モード', '個性的でトレンド重視のスタイル');

  final String value;
  final String label;
  final String description;

  const StylePreference(this.value, this.label, this.description);

  static StylePreference fromString(String value) {
    return StylePreference.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StylePreference.casual,
    );
  }
}

/// Body concern options (multiple selection)
enum BodyConcern {
  height('height', '身長'),
  weight('weight', '体重'),
  shoulders('shoulders', '肩幅'),
  waist('waist', 'ウエスト'),
  legs('legs', '脚'),
  arms('arms', '腕');

  final String value;
  final String label;

  const BodyConcern(this.value, this.label);

  static BodyConcern fromString(String value) {
    return BodyConcern.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BodyConcern.height,
    );
  }
}

/// Lifestyle options
enum Lifestyle {
  workFocused('work_focused', '仕事中心', 'ビジネスシーンが多い'),
  privateFocused('private_focused', 'プライベート中心', '休日・プライベートが多い'),
  balanced('balanced', 'バランス', '仕事とプライベート半々');

  final String value;
  final String label;
  final String description;

  const Lifestyle(this.value, this.label, this.description);

  static Lifestyle fromString(String value) {
    return Lifestyle.values.firstWhere(
      (e) => e.value == value,
      orElse: () => Lifestyle.balanced,
    );
  }
}

/// User profile model
class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final Gender? gender;
  final AgeRange? ageRange;
  final StylePreference? stylePreference;
  final List<BodyConcern> bodyConcerns;
  final Lifestyle? lifestyle;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.gender,
    this.ageRange,
    this.stylePreference,
    this.bodyConcerns = const [],
    this.lifestyle,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      gender: json['gender'] != null
          ? Gender.fromString(json['gender'] as String)
          : null,
      ageRange: json['age_range'] != null
          ? AgeRange.fromString(json['age_range'] as String)
          : null,
      stylePreference: json['style_preference'] != null
          ? StylePreference.fromString(json['style_preference'] as String)
          : null,
      bodyConcerns: (json['body_concerns'] as List<dynamic>?)
              ?.map((e) => BodyConcern.fromString(e as String))
              .toList() ??
          [],
      lifestyle: json['lifestyle'] != null
          ? Lifestyle.fromString(json['lifestyle'] as String)
          : null,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'gender': gender?.value,
      'age_range': ageRange?.value,
      'style_preference': stylePreference?.value,
      'body_concerns': bodyConcerns.map((e) => e.value).toList(),
      'lifestyle': lifestyle?.value,
      'onboarding_completed': onboardingCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    Gender? gender,
    AgeRange? ageRange,
    StylePreference? stylePreference,
    List<BodyConcern>? bodyConcerns,
    Lifestyle? lifestyle,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      ageRange: ageRange ?? this.ageRange,
      stylePreference: stylePreference ?? this.stylePreference,
      bodyConcerns: bodyConcerns ?? this.bodyConcerns,
      lifestyle: lifestyle ?? this.lifestyle,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if profile has all required fields for onboarding
  bool get isProfileComplete =>
      gender != null &&
      ageRange != null &&
      stylePreference != null &&
      lifestyle != null;
}
