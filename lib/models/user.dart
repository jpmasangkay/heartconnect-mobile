class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatar;
  final String? bio;
  final List<String> skills;
  final String? location;
  final String? university;
  final String? portfolio;
  final String? createdAt;

  // Verification
  final bool isVerified;
  final String? verificationStatus;
  final String? verificationMethod;

  // 2FA
  final bool twoFactorEnabled;
  final String? twoFactorMethod;

  // Onboarding
  final bool hasCompletedOnboarding;

  // Legal
  final bool agreedToTerms;

  // Presence
  final String? lastSeen;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar,
    this.bio,
    this.skills = const [],
    this.location,
    this.university,
    this.portfolio,
    this.createdAt,
    this.isVerified = false,
    this.verificationStatus,
    this.verificationMethod,
    this.twoFactorEnabled = false,
    this.twoFactorMethod,
    this.hasCompletedOnboarding = false,
    this.agreedToTerms = false,
    this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      avatar: json['avatar'],
      bio: json['bio'],
      skills: List<String>.from(json['skills'] ?? []),
      location: json['location'],
      university: json['university'],
      portfolio: json['portfolio'],
      createdAt: json['createdAt'],
      isVerified: json['isVerified'] ?? false,
      verificationStatus: json['verificationStatus'],
      verificationMethod: json['verificationMethod'],
      twoFactorEnabled: json['twoFactorEnabled'] ?? false,
      twoFactorMethod: json['twoFactorMethod'],
      hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
      agreedToTerms: json['agreedToTerms'] ?? false,
      lastSeen: json['lastSeen'],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatar': avatar,
        'bio': bio,
        'skills': skills,
        'location': location,
        'university': university,
        'portfolio': portfolio,
        'createdAt': createdAt,
        'isVerified': isVerified,
        'verificationStatus': verificationStatus,
        'verificationMethod': verificationMethod,
        'twoFactorEnabled': twoFactorEnabled,
        'twoFactorMethod': twoFactorMethod,
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'agreedToTerms': agreedToTerms,
        'lastSeen': lastSeen,
      };

  User copyWith({
    String? name,
    String? bio,
    String? location,
    String? university,
    String? portfolio,
    List<String>? skills,
    bool? isVerified,
    String? verificationStatus,
    String? verificationMethod,
    bool? twoFactorEnabled,
    String? twoFactorMethod,
    bool? hasCompletedOnboarding,
    bool? agreedToTerms,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      avatar: avatar,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      location: location ?? this.location,
      university: university ?? this.university,
      portfolio: portfolio ?? this.portfolio,
      createdAt: createdAt,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      twoFactorMethod: twoFactorMethod ?? this.twoFactorMethod,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      lastSeen: lastSeen,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
