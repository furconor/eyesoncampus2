class User {
  final String id;
  final String name;
  final String university;
  final String department;
  final String year;
  final String bio;
  final List<String> interests;
  final String _avatar;
  String get avatar => (_avatar == '🧑' || (_avatar.isNotEmpty && _avatar.runes.first > 0x1F000)) ? (name.isNotEmpty ? name[0].toUpperCase() : 'U') : _avatar;
  final String campusZone;
  final bool isOnline;
  final DateTime lastActive;
  final bool isAnonymous;
  final String? profileImageUrl;
  // Gender/Appereance for demo purposes to match UI
  final String genderFlag;
  final String? universityId;
  final DateTime? lastCheckinAt;
  final int points;
  final List<String> diaryPhotos;


  User({
    required this.id,
    required this.name,
    required this.university,
    required this.department,
    required this.year,
    required this.bio,
    required this.interests,
    required String avatar,
    required this.campusZone,
    required this.isOnline,
    required this.lastActive,
    this.isAnonymous = false,
    this.profileImageUrl,
    this.genderFlag = 'f',
    this.universityId,
    this.lastCheckinAt,
    this.points = 0,
    this.diaryPhotos = const [],
    this.notifLook = true,
    this.notifMatch = true,
    this.quizCompleted = false,
    this.quizStep = 0,
    this.lastEnergySyncAt,
  }) : _avatar = avatar;

  final bool notifLook;
  final bool notifMatch;
  final bool quizCompleted;
  final int quizStep;
  final DateTime? lastEnergySyncAt;


  User copyWith({
    String? name,
    String? university,
    String? department,
    String? year,
    String? bio,
    List<String>? interests,
    String? avatar,
    String? campusZone,
    bool? isOnline,
    bool? isAnonymous,
    String? profileImageUrl,
    String? universityId,
    DateTime? lastCheckinAt,
    int? points,
    List<String>? diaryPhotos,
    bool? notifLook,
    bool? notifMatch,
    bool? quizCompleted,
    int? quizStep,
    DateTime? lastEnergySyncAt,
    bool clearProfileImage = false,
  }) {

    return User(
      id: id,
      name: name ?? this.name,
      university: university ?? this.university,
      department: department ?? this.department,
      year: year ?? this.year,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      avatar: avatar ?? _avatar,
      campusZone: campusZone ?? this.campusZone,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      genderFlag: genderFlag,
      universityId: universityId ?? this.universityId,
      lastCheckinAt: lastCheckinAt ?? this.lastCheckinAt,
      points: points ?? this.points,
      diaryPhotos: diaryPhotos ?? this.diaryPhotos,
      notifLook: notifLook ?? this.notifLook,
      notifMatch: notifMatch ?? this.notifMatch,
      quizCompleted: quizCompleted ?? this.quizCompleted,
      quizStep: quizStep ?? this.quizStep,
      lastEnergySyncAt: lastEnergySyncAt ?? this.lastEnergySyncAt,
      profileImageUrl: clearProfileImage ? null : (profileImageUrl ?? this.profileImageUrl),
    );

  }

  // Helper for first name
  String get firstName => name.split(' ').first;

  // Helper for consistent short name (e.g. "Kaan B.")
  String get shortName {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    final first = parts.sublist(0, parts.length - 1).join(' ');
    final last = parts.last;
    if (last.isEmpty) return first;
    // If it's already formatted like "K.", preserve it
    if (last.length == 2 && last.endsWith('.')) {
      return '$first $last';
    }
    return '$first ${last[0].toUpperCase()}.';
  }
}
