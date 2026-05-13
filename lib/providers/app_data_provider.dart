import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

import '../models/app_models.dart';
import '../services/localization_service.dart';
import '../providers/supabase_service.dart';
import '../utils/content_filter.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class AppData extends ChangeNotifier with WidgetsBindingObserver {
  // App State
  bool _hasSeenOnboarding = false;
  bool _isLoggedIn = false;
  bool _isInitialized = false;
  String _currentLanguage = 'tr'; 
  int _selectedTabIndex = 0;
  StreamSubscription? _profileSubscription;
  StreamSubscription? _notifSubscription;
  Timer? _energyTimer;
  String _energyCountdown = "";
  
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String get currentLanguage => _currentLanguage;
  int get selectedTabIndex => _selectedTabIndex;
  String get energyCountdown => _energyCountdown;

  Map<String, List<String>> _appImages = {};
  List<String> get onboardingImages => _appImages['onboarding'] ?? [];
  List<String> get authImages => _appImages['auth'] ?? [];

  String t(String key) => LocalizationService.translate(key, _currentLanguage);

  // Me (Current User)
  User? _currentUser;
  User? get currentUser => _currentUser;

  int _dailyInterestsLeft = 5;
  int get dailyInterestsLeft => _dailyInterestsLeft;

  int _dailyWinkCount = 0;
  List<String> _dailyWinkTargets = [];
  int get nextWinkCost => _dailyWinkCount + 1;

  // Data Lists
  List<User> _allUsers = [];
  List<User> get allUsers => _allUsers.where((u) => !_hiddenUserIds.contains(u.id)).toList();
  
  List<Venue> _venues = [];
  List<Venue> get venues => _venues;

  List<University> _universities = [];
  List<University> get universities => _universities;

  List<Conversation> _conversations = [];
  Map<String, List<EventMessage>> _eventMessages = {};
  
  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications.where((n) => !_hiddenUserIds.contains(n.relatedUser?.id)).toList();
  
  List<Conversation> get conversations => _conversations.where((c) => !_hiddenUserIds.contains(c.otherUser.id)).toList();
  
  List<Event> _events = [];
  List<Event> get events => _events;
  
  // Sent Interests & Matches
  Set<String> _sentInterests = {};
  Set<String> _matches = {};

  // Safety & Moderation (Immediate local hiding)
  Set<String> _hiddenUserIds = {};
  Set<String> _hiddenPhotoUrls = {};

  // Privacy Settings
  bool _showOnRadar = true;
  bool _shareLocation = true;

  bool get showOnRadar => _showOnRadar;
  bool get shareLocation => _shareLocation;
  Set<String> get hiddenPhotoUrls => _hiddenPhotoUrls;
  
  // Discovery Filtering
  String _selectedCategory = 'All';
  String _venueSearchQuery = '';
  int _monthlyViews = 0;

  String get selectedCategory => _selectedCategory;
  String get venueSearchQuery => _venueSearchQuery;
  int get monthlyViews => _monthlyViews;

  void setVenueCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setVenueSearchQuery(String query) {
    _venueSearchQuery = query.toLowerCase();
    notifyListeners();
  }

  List<Venue> get filteredVenues {
    List<Venue> result = _venues.where((v) {
      final matchesSearch = v.name.toLowerCase().contains(_venueSearchQuery);
      final matchesCategory = _selectedCategory == 'All' || _selectedCategory == 'Trend' || v.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    if (_selectedCategory == 'Trend') {
      result.sort((a, b) => b.heatLevel.compareTo(a.heatLevel));
    }
    return result;
  }

  // Quiz Persistence (Prefers current user's persistent data)
  int _quizScore = 0;

  int get quizCurrentIndex => _currentUser?.quizStep ?? 0;
  int get quizScore => _quizScore;
  bool get quizIsCompleted => _currentUser?.quizCompleted ?? false;

  // Quiz Questions from DB
  List<Map<String, dynamic>> _quizQuestions = [];
  List<Map<String, dynamic>> get quizQuestions => _quizQuestions;

  int _incomingWinkCount = 0;
  int _matchCount = 0;
  int _chatCount = 0;

  int get lookCount => _incomingWinkCount;
  int get matchCount => _matchCount;
  int get chatCount => _chatCount;

  void updateQuizProgress(int index, int score, {bool isCompleted = false}) async {
    _quizScore = score;
    
    if (_currentUser != null) {
      final updatedUser = _currentUser!.copyWith(
        quizStep: index,
        quizCompleted: isCompleted,
      );
      
      // Update locally immediately
      _currentUser = updatedUser;
      notifyListeners();

      // Sync to Supabase
      final supabase = SupabaseService();
      await supabase.updateProfile({
        'quiz_step': index,
        'quiz_completed': isCompleted,
      });
    } else {
      notifyListeners();
    }
  }

  void resetQuiz() {
    _quizScore = 0;
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(quizStep: 0, quizCompleted: false);
      SupabaseService().updateProfile({'quiz_step': 0, 'quiz_completed': false});
    }
    notifyListeners();
  }

  Future<void> _syncQuizState() async {
    // Quiz state is now synced directly with currentUser profile from Supabase
    // No more daily resets or SharedPreferences needed
    notifyListeners();
  }

  Future<void> _recalculateEnergy() async {
    await _checkDailyReset();
  }

  Future<void> _checkDailyReset() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final savedDate = prefs.getString('daily_wink_date') ?? '';

    if (savedDate != todayStr) {
      // Yeni gün: eşleşmeyenleri sentInterests'ten çıkar
      final yesterdayTargets = prefs.getStringList('daily_wink_targets') ?? [];
      final toRemove = yesterdayTargets.where((id) => !_matches.contains(id)).toList();
      for (final id in toRemove) {
        _sentInterests.remove(id);
      }
      if (toRemove.isNotEmpty) {
        unawaited(SupabaseService().deleteUnmatchedSwipes(toRemove));
      }
      // Ne olursa olsun 10'a sabitle (23.59 sıfırlaması)
      final resetPoints = 10;
      _currentUser = _currentUser!.copyWith(points: resetPoints);
      await SupabaseService().updateProfile({'points': resetPoints});
      // Günlük sayaçları sıfırla
      _dailyWinkCount = 0;
      _dailyWinkTargets = [];
      await prefs.setString('daily_wink_date', todayStr);
      await prefs.setInt('daily_wink_count', 0);
      await prefs.setStringList('daily_wink_targets', []);
      notifyListeners();
    } else {
      _dailyWinkCount = prefs.getInt('daily_wink_count') ?? 0;
      _dailyWinkTargets = List<String>.from(prefs.getStringList('daily_wink_targets') ?? []);
      // Bugünkü wink'leri _sentInterests'e de ekle (2 saatlik DB filtresi dışında kalanlar için)
      _sentInterests.addAll(_dailyWinkTargets);
    }
  }

  Future<void> _loadQuizQuestions() async {
    final supabase = SupabaseService();
    final dbQuestions = await supabase.getQuizQuestions();
    
    if (dbQuestions.isNotEmpty) {
      _quizQuestions = dbQuestions.map((q) {
        return {
          'question': q['question'] as String,
          'options': List<String>.from(q['options'] as List),
          'answer': q['answer'] as int,
        };
      }).toList();
    }
    // Boşsa daily_quiz_screen kendi fallback sorularını kullanacak
    notifyListeners();
  }

  bool get isReviewer => _currentUser?.name == 'Apple Reviewer';

  List<User> getUsersAtVenue(String venueName) {
    if (venueName == 'Bilinmiyor') return [];
    
    final dummyNames = ['Zeynep K.', 'Kaan B.', 'Aylin Y.', 'Emre T.', 'Deniz A.', 'Apple Reviewer'];
    final isAppleReviewer = _currentUser?.name == 'Apple Reviewer';

    // 1. Get users from DB
    List<User> users = _allUsers
        .where((u) => u.campusZone == venueName && 
                      u.id != _currentUser?.id && 
                      !_hiddenUserIds.contains(u.id))
        .toList();
    
    if (isAppleReviewer) {
      // Reviewer her şeyi görsün, eksik varsa (DB'de yoksa) enjekte et
      final existingNames = users.map((u) => u.name).toSet();
      for (var name in dummyNames) {
        if (name == 'Apple Reviewer') continue;
        if (!existingNames.contains(name)) {
          try {
            final dummy = _allUsers.firstWhere((u) => u.name == name);
            users.add(dummy.copyWith(campusZone: venueName));
          } catch (_) {}
        }
      }
    } else {
      // NORMAL KULLANICI: Sahte hesapları asla görmesin (DB'de olsalar bile filtrele)
      users.removeWhere((u) => dummyNames.contains(u.name));
    }
    
    return users;
  }

  int getVenuePeopleCount(String venueName) {
    return getUsersAtVenue(venueName).length;
  }


  bool get isCheckinExpired {
    if (_currentUser == null || _currentUser!.lastCheckinAt == null) return true;
    final diff = DateTime.now().difference(_currentUser!.lastCheckinAt!);
    return diff.inHours >= 2;
  }

  AppData() {
    _initData();
    _startEnergyTimer();
    WidgetsBinding.instance.addObserver(this);
  }

  void _startEnergyTimer() {
    _energyTimer?.cancel();
    _energyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateEnergyCountdown();
    });
  }

  void _updateEnergyCountdown() {
    if (_currentUser == null) return;
    final now = DateTime.now();

    // Gece yarısı geçtiyse reset tetikle
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.getInstance().then((prefs) {
      if ((prefs.getString('daily_wink_date') ?? '') != todayStr) _checkDailyReset();
    });

    if (_currentUser!.points >= 10) {
      _energyCountdown = "TAM DOLU";
    } else {
      final midnight = DateTime(now.year, now.month, now.day + 1);
      final remaining = midnight.difference(now);
      final h = remaining.inHours.toString().padLeft(2, '0');
      final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      _energyCountdown = "$h:$m:$s";
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileSubscription?.cancel();
    _notifSubscription?.cancel();
    _energyTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLoggedIn) return;
    final supabase = SupabaseService();
    if (state == AppLifecycleState.resumed) {
      supabase.updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      supabase.updateOnlineStatus(false);
    }
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _currentLanguage = prefs.getString('language') ?? 'tr';
    
    final supabase = SupabaseService();
    // 1. Prioritize live Supabase session
    final bool actuallyAuthenticated = supabase.isAuthenticated;
    
    // 2. Fallback/Sync with preferences
    if (actuallyAuthenticated) {
      _isLoggedIn = true;
      if (prefs.getBool('isLoggedIn') != true) {
        await prefs.setBool('isLoggedIn', true);
      }
    } else {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    }

    if (_isLoggedIn) {
      _currentUser = await supabase.getCurrentUserProfile();
      if (_currentUser == null) {
        _isLoggedIn = false;
        await prefs.setBool('isLoggedIn', false);
      } else {
        _dailyInterestsLeft = prefs.getInt('dailyInterests') ?? 5;
        _allUsers = await supabase.getAllUsers();
        _conversations = await supabase.getConversations();
        _matches = _conversations.map<String>((c) => c.otherUser.id).toSet();
        _sentInterests = (await supabase.getSentInterests()).toSet();
        _events = await supabase.getEvents(universityId: _currentUser?.universityId);

        // Engellenen kullanıcıları yükle (dinamik filtreleme için)
        final blockedList = await supabase.getBlockedUserIds();
        _hiddenUserIds = blockedList.toSet();

        await _loadNotifications();
        _startRealtimeListeners();
        await _syncQuizState();
        await _recalculateEnergy();
        await _loadQuizQuestions();
        
        // OneSignal'a giriş yap (cihazı Supabase ID ile eşleştir)
        OneSignal.login(_currentUser!.id);
        
        await _fetchProfileStats();
        
        // Set online status initially
        await supabase.updateOnlineStatus(true);
      }
    }

    await loadUniversities();
    await _loadVenues();
    unawaited(_loadAppImages());
    _selectedTabIndex = 0;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadAppImages() async {
    final svc = SupabaseService();
    _appImages = await svc.getAppImages();
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    notifyListeners();
  }

  Future<void> login(User user) async {
    _currentUser = user;
    _isLoggedIn = true;
    _selectedTabIndex = 0; // Default to Radar screen
    _dailyInterestsLeft = 5;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('dailyInterests', 5);
    
    final supabase = SupabaseService();
    
    // OneSignal'a giriş yap
    OneSignal.login(user.id);
    
    _allUsers = await supabase.getAllUsers();
    _conversations = await supabase.getConversations();
    _matches = _conversations.map<String>((c) => c.otherUser.id).toSet();
    _sentInterests = (await supabase.getSentInterests()).toSet();
    
    await _loadNotifications();
    _updateVenueCounts();
    await _syncQuizState();
    await _recalculateEnergy();
    notifyListeners();
  }
  
  Future<void> logout() async {
    final supabase = SupabaseService();
    await supabase.signOut();
    
    _isLoggedIn = false;
    _currentUser = null;
    _allUsers = [];
    _conversations = [];
    _notifications = [];
    _matches.clear();
    _sentInterests.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    resetQuiz();
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    final supabase = SupabaseService();
    // Clean up avatar storage before deleting account
    if (_currentUser != null && _currentUser!.profileImageUrl != null) {
      try {
        await supabase.deleteAvatarStorage(_currentUser!.id);
      } catch (_) {
        // Continue with account deletion even if storage cleanup fails
      }
    }
    final success = await supabase.deleteAccount();
    if (success) {
      await logout();
    }
    return success;
  }

  Future<bool> updateProfile(User updatedUser, {Uint8List? avatarBytes, String? avatarExt}) async {
    final supabase = SupabaseService();
    String? finalImageUrl = updatedUser.profileImageUrl;
    
    // Yükleme (Baytlarla veya fallback olarak path ile)
    if (avatarBytes != null) {
      final cloudUrl = await supabase.uploadAvatarBytes(avatarBytes, avatarExt ?? 'jpg');
      if (cloudUrl != null) {
        finalImageUrl = cloudUrl;
      }
    } else if (finalImageUrl != null && (finalImageUrl.contains('/') || finalImageUrl.contains('\\')) && !finalImageUrl.startsWith('http')) {
      final cloudUrl = await supabase.uploadAvatar(finalImageUrl);
      if (cloudUrl != null) {
        finalImageUrl = cloudUrl;
      }
    }

    final success = await supabase.updateProfile({
      'name': updatedUser.name,
      'bio': updatedUser.bio,
      'department': updatedUser.department,
      'year': updatedUser.year,
      'campus_zone': updatedUser.campusZone,
      'interests': updatedUser.interests,
      'avatar': finalImageUrl ?? updatedUser.avatar,
      'university_id': updatedUser.universityId,
      'diary_photos': updatedUser.diaryPhotos,
    });

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      
      final hadNoPhoto = _currentUser?.profileImageUrl == null || _currentUser!.profileImageUrl!.isEmpty;
      final nowHasPhoto = finalImageUrl != null && finalImageUrl.isNotEmpty;
      
      bool earnedProfilePoint = prefs.getBool('has_earned_profile_pic_point') ?? false;
      int bonus = 0;
      
      if (nowHasPhoto && !earnedProfilePoint) {
         bonus = 1;
         await prefs.setBool('has_earned_profile_pic_point', true);
      }

      final newPoints = (_currentUser?.points ?? 0) + bonus;

      _currentUser = updatedUser.copyWith(
        profileImageUrl: finalImageUrl,
        clearProfileImage: finalImageUrl == null,
        points: bonus > 0 ? newPoints : updatedUser.points,
      );

      if (bonus > 0) {
        await supabase.updateProfile({'points': newPoints});
      }

      notifyListeners();
    }
    return success;
  }

  Future<String?> uploadDiaryPhoto(Uint8List bytes, String ext) async {
    final supabase = SupabaseService();
    final url = await supabase.uploadDiaryPhotoBytes(bytes, ext);
    if (url != null && _currentUser != null) {
      final newList = List<String>.from(_currentUser!.diaryPhotos)..add(url);
      final success = await updateProfile(_currentUser!.copyWith(diaryPhotos: newList));
      
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        int earnedDiary = prefs.getInt('diary_photos_points_earned') ?? 0;
        if (earnedDiary < 6) {
           await prefs.setInt('diary_photos_points_earned', earnedDiary + 1);
           await addPoints(1, 'Fotoğraf Yükleme');
        }
        return url;
      }
    }
    return null;
  }

  Future<void> removeDiaryPhoto(String url) async {
    final supabase = SupabaseService();
    await supabase.deleteDiaryPhoto(url);
    if (_currentUser != null) {
      final newList = List<String>.from(_currentUser!.diaryPhotos)..remove(url);
      await updateProfile(_currentUser!.copyWith(diaryPhotos: newList));
    }
  }

  // --- ACTIONS ---

  bool hasSentInterest(String userId) {
    return _sentInterests.contains(userId);
  }

  bool isMatched(String userId) {
    return _matches.contains(userId);
  }

  Future<Conversation?> findOrRefreshConversation(String userId) async {
    // First try local
    final localIdx = _conversations.indexWhere((c) => c.otherUser.id == userId);
    if (localIdx != -1) return _conversations[localIdx];

    // Refresh from Supabase and try again
    final supabase = SupabaseService();
    _conversations = await supabase.getConversations();
    _matches = _conversations.map<String>((c) => c.otherUser.id).toSet();
    notifyListeners();

    final refreshedIdx = _conversations.indexWhere((c) => c.otherUser.id == userId);
    if (refreshedIdx != -1) return _conversations[refreshedIdx];

    // If still not found but user is matched locally, create match + conversation in DB
    if (_matches.contains(userId) || isReviewer) {
      final user = _allUsers.firstWhere((u) => u.id == userId, orElse: () => _allUsers[0]);
      
      // Ensure match exists in DB
      await supabase.ensureMatch(userId);
      
      // Create conversation
      final convId = await supabase.createConversation(userId, user.campusZone);
      if (convId != null) {
        final conv = Conversation(
          id: convId,
          otherUser: user,
          messages: [],
          isNewMatch: true,
          locationTag: user.campusZone,
        );
        _conversations.insert(0, conv);
        _matches.add(userId);
        notifyListeners();
        return conv;
      }
    }
    
    return null;
  }

  Future<String?> checkIn(Venue venue) async {
    if (_currentUser == null) return null;
    
    // 1. Calculate energy locally first (Consolidation)
    final now = DateTime.now();
    int currentPoints = _currentUser!.points;

    if (currentPoints < 1) {
      return 'Yeterli enerjin yok! Enerjinin dolmasını bekle.';
    }

    // 3. Deduct point for check-in
    final finalPoints = currentPoints - 1;
    final finalSyncTime = now; // Update sync time to now since we just modified points

    final supabase = SupabaseService();
    
    // 4. Perform SINGLE consolidated update
    final success = await supabase.updateCheckIn(
      venue.id, 
      venue.name, 
      newPoints: finalPoints, 
      newSyncTime: finalSyncTime
    );
    
    if (success) {
      _currentUser = _currentUser!.copyWith(
        campusZone: venue.name,
        lastCheckinAt: now,
        points: finalPoints,
        lastEnergySyncAt: finalSyncTime,
      );
      
      // Log check-in for weekly reports
      await supabase.logCheckin(venue.name);
      
      _updateVenueCounts();
      notifyListeners();
      return null; // Başarılı
    }
    return 'Bir hata oluştu, tekrar dene.';
  }

  Future<String?> leaveVenue() async {
    if (_currentUser == null) return null;
    
    final supabase = SupabaseService();
    final success = await supabase.updateCheckIn(null, null);
    
    if (success) {
      _currentUser = _currentUser!.copyWith(
        campusZone: 'Bilinmiyor',
        lastCheckinAt: null,
      );
      _updateVenueCounts();
      notifyListeners();
      return null;
    }
    return 'Bir hata oluştu, tekrar dene.';
  }

  Future<String?> sendInterest(String targetUserId, {bool forceMatch = false}) async {
    await _checkDailyReset();
    if (_sentInterests.contains(targetUserId)) return 'Zaten göz kırptın!';
    if (_currentUser == null) return 'Kullanıcı bulunamadı.';

    // Artan maliyet: 1. wink=1, 2. wink=2, 3. wink=3 ...
    final int cost = _dailyWinkCount + 1;
    if (_currentUser!.points < cost) {
      return 'Yeterli enerjin yok! Bu göz kırpma $cost enerji gerektiriyor.';
    }

    final supabase = SupabaseService();

    // 1. Konum kontrolü (Reviewer değilse)
    if (!isReviewer) {
      final targetUser = _allUsers.firstWhere((u) => u.id == targetUserId, orElse: () => _allUsers.isNotEmpty ? _allUsers[0] : User(id: 'temp', name: 'User', university: '', department: '', year: '', bio: '', interests: [], avatar: '', campusZone: '', isOnline: false, lastActive: DateTime.now()));
      if (_currentUser?.campusZone != targetUser.campusZone) {
        return 'Sadece seninle aynı mekanda olanlara göz kırpabilirsin.';
      }
    }

    _sentInterests.add(targetUserId);
    _dailyWinkTargets.add(targetUserId);
    _dailyWinkCount++;

    // Artan maliyeti düş
    await addPoints(-cost, 'Göz kırpma');

    // Günlük sayaçları kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_wink_count', _dailyWinkCount);
    await prefs.setStringList('daily_wink_targets', _dailyWinkTargets);

    final isMatch = await supabase.sendInterest(targetUserId);
    
    if (isMatch) {
      // Award points to the recipient for the interest/match
      await supabase.updatePointsForUser(targetUserId, 2);
      
      await _triggerMatch(targetUserId);
    }
    
    notifyListeners();
    return null; // Başarılı
  }

  Future<void> _triggerMatch(String targetUserId) async {
    _matches.add(targetUserId);
    final user = _allUsers.firstWhere((User u) => u.id == targetUserId, orElse: () => _allUsers[0]);
    
    _notifications.insert(0, AppNotification(
      id: 'n_m_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.match,
      relatedUser: user,
      title: 'Yeni Eşleşme',
      message: 'ile eşleştiniz! Sohbet başlatabilirsiniz.',
      location: user.campusZone,
      timestamp: DateTime.now(),
    ));

    // Push notification gönder
    NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '✨ Yeni Eşleşme!',
      body: '${user.name} ile eşleştin! Sohbet başlat.',
      payload: 'match_${user.id}',
    );

    final supabase = SupabaseService();
    
    // Ensure match row exists in DB (critical for reviewer/forced matches)
    await supabase.ensureMatch(targetUserId);
    
    final String matchLocation = (user.campusZone != null && user.campusZone != 'Bilinmiyor') 
        ? user.campusZone! 
        : (_currentUser?.campusZone ?? 'Kampüs');
        
    final convId = await supabase.createConversation(targetUserId, matchLocation);

    if (convId != null) {
      final existingIdx = _conversations.indexWhere((c) => c.id == convId);
      if (existingIdx == -1) {
        _conversations.insert(0, Conversation(
          id: convId,
          otherUser: user,
          messages: [],
          isNewMatch: true,
          locationTag: matchLocation,
        ));
      }
      // Heavy haptics for a match!
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.heavyImpact());
    }
    notifyListeners();
  }

  Future<bool> sendMessage(String conversationId, String text) async {
    // Apply content filter
    final filteredText = ContentFilter.filter(text);
    
    final supabase = SupabaseService();
    bool success = await supabase.sendMessage(conversationId, filteredText);
    
    if (success) {
      HapticFeedback.lightImpact();
      final convIdx = _conversations.indexWhere((c) => c.id == conversationId);
      if (convIdx != -1) {
        final newMessage = AppMessage(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}',
          senderId: _currentUser!.id,
          receiverId: _conversations[convIdx].otherUser.id,
          text: filteredText,
          timestamp: DateTime.now(),
        );
        _conversations[convIdx].messages.add(newMessage);
        notifyListeners();
      }
    }
    return success;
  }

  Future<void> loadEvents() async {
    final supabase = SupabaseService();
    final dbEvents = await supabase.getEvents(universityId: _currentUser?.universityId);
    
    if (dbEvents.isNotEmpty) {
      _events = dbEvents;
    } else {
      // Fallback/Mock with categories
       _generateMockEvents();
    }
    notifyListeners();
  }

  void _generateMockEvents() {
    _events = [
      Event(
        id: 'e1',
        title: 'Bahar Şenliği Konseri',
        description: 'Büyük konser alanı ve eğlence!',
        location: 'ODTÜ Devrim',
        date: DateTime.now(),
        imageUrl: '',
        isLive: true,
        attendeesCount: 15,
        category: 'Social',
        attendeePreviews: _allUsers.take(3).toList(),
        startAt: DateTime.now(),
        endAt: DateTime.now().add(const Duration(hours: 4)),
      ),
      Event(
        id: 'e2',
        title: 'Vize Öncesi Kütüphane Maratonu',
        description: 'Birlikte ders çalışalım.',
        location: 'Merkez Kütüphane',
        date: DateTime.now().add(const Duration(days: 1)),
        imageUrl: '',
        attendeesCount: 8,
        category: 'Study',
        attendeePreviews: _allUsers.skip(2).take(2).toList(),
        startAt: DateTime.now().add(const Duration(days: 1, hours: 10)),
        endAt: DateTime.now().add(const Duration(days: 1, hours: 18)),
      ),
      Event(
        id: 'e3',
        title: 'Kampüs Basketbol Turnuvası',
        description: '3v3 maçlar başlasın.',
        location: 'Spor Salonu',
        date: DateTime.now().add(const Duration(days: 2)),
        imageUrl: '',
        attendeesCount: 22,
        category: 'Sports',
        attendeePreviews: _allUsers.skip(1).take(3).toList(),
        startAt: DateTime.now().add(const Duration(days: 2, hours: 16)),
        endAt: DateTime.now().add(const Duration(days: 2, hours: 20)),
      ),
    ];
  }

  Future<String?> startEvent({
    required String title,
    required String description,
    required String location,
    required bool isLive,
    required DateTime startAt,
    required DateTime endAt,
    String? category,
  }) async {
    await _recalculateEnergy();
    if (_currentUser == null) return 'Kullanıcı bulunamadı.';
    
    // Check if user has enough points
    if (_currentUser!.points < 1) {
      return 'Yeterli enerjin yok! Enerjinin dolmasını bekle.';
    }

    try {
      final supabase = SupabaseService();
      final eventId = await supabase.createEvent(
        title: title,
        description: description,
        location: location,
        isLive: isLive,
        startAt: startAt,
        endAt: endAt,
        universityId: _currentUser?.universityId,
        category: category,
      );

      if (eventId != null) {
        // Deduct points for starting an event
        await addPoints(-1, 'Etkinlik Başlatma');
        await loadEvents();
        notifyListeners();
        return null; // Başarılı
      }
      return 'Etkinlik oluşturulurken bir hata oluştu.';
    } catch (e) {
      debugPrint('Event creation error: $e');
      if (e.toString().contains('PostgrestException')) {
        return 'Veritabanı hatası: ${e.toString().split('message: ').last.split(',').first}';
      }
      return 'Hata: $e';
    }
  }

  Future<bool> joinEvent(String eventId, bool join) async {
    final supabase = SupabaseService();
    
    final eventIdx = _events.indexWhere((e) => e.id == eventId);
    if (eventIdx == -1) return false;
    final event = _events[eventIdx];

    // Check time conflicts only when joining
    if (join && event.startAt != null && event.endAt != null) {
      final conflicting = _events.where((e) {
        if (!e.isJoined || e.id == eventId) return false;
        if (e.startAt == null || e.endAt == null) return false;
        // Overlap: e starts before event ends AND e ends after event starts
        return e.startAt!.isBefore(event.endAt!) && e.endAt!.isAfter(event.startAt!);
      }).toList();

      if (conflicting.isNotEmpty) {
        // Return false — caller should show conflict message
        return false;
      }
    }

    final isFakeEvent = eventId.startsWith('e');
    final success = isFakeEvent ? true : await supabase.toggleEventJoin(eventId, join);
    
    if (success) {
      if (!isFakeEvent) {
        await loadEvents();
      } else {
        // Manually toggle local fake event
        _events[eventIdx] = _events[eventIdx].copyWith(
          isJoined: join,
          attendeesCount: _events[eventIdx].attendeesCount + (join ? 1 : -1)
        );
      }
      
      if (join) {
        final updatedEvent = _events.firstWhere((e) => e.id == eventId);
        HapticFeedback.mediumImpact();

        if (updatedEvent.attendeesCount >= 3 && event.attendeesCount < 3 && event.createdBy != null) {
           await supabase.updatePointsForUser(event.createdBy!, 2);
           debugPrint('Event creator bonus awarded for event: $eventId');
        }
      }
      
      notifyListeners();
    }
    return success;
  }

  Future<bool> finishEvent(String eventId) async {
    final supabase = SupabaseService();
    final success = await supabase.deleteEvent(eventId);
    if (success) {
      await loadEvents();
      notifyListeners();
    }
    return success;
  }


  Future<List<User>> getEventAttendees(String eventId) async {
    final supabase = SupabaseService();
    return await supabase.getEventAttendees(eventId);
  }

  // --- EVENT MESSAGES ---
  List<EventMessage> getEventMessages(String eventId) {
    if (!_eventMessages.containsKey(eventId)) {
      // Mock data for the feed
      _eventMessages[eventId] = [];
      if (_allUsers.isNotEmpty) {
        final mockSender1 = _allUsers[0 % _allUsers.length];
        final mockSender2 = _allUsers[1 % _allUsers.length];
        
        _eventMessages[eventId]!.add(EventMessage(
          id: 'mock1_$eventId',
          eventId: eventId,
          sender: mockSender1,
          text: 'Etkinliğe geldik bile! Ortam çok iyi.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
          imageUrl: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=500&auto=format&fit=crop',
          likesCount: 12,
          repliesCount: 3,
        ));
        
        _eventMessages[eventId]!.add(EventMessage(
          id: 'mock2_$eventId',
          eventId: eventId,
          sender: mockSender2,
          text: 'Birazdan başlıyoruz, sahnenin hemen önündeyiz!',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          likesCount: 5,
        ));
      }
    }
    return _eventMessages[eventId]!;
  }

  void sendEventMessage(String eventId, String text, {String? imageUrl, String? videoUrl}) {
    if (_currentUser == null) return;
    
    final msg = EventMessage(
      id: 'em_${DateTime.now().millisecondsSinceEpoch}',
      eventId: eventId,
      sender: _currentUser!,
      text: text,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      videoUrl: videoUrl,
    );
    
    if (!_eventMessages.containsKey(eventId)) {
      _eventMessages[eventId] = [];
    }
    _eventMessages[eventId]!.add(msg);
    notifyListeners();
  }
  
  void toggleLikeEventMessage(String eventId, String messageId) {
    if (!_eventMessages.containsKey(eventId)) return;
    
    final messages = _eventMessages[eventId]!;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final msg = messages[index];
      msg.isLiked = !msg.isLiked;
      msg.likesCount += msg.isLiked ? 1 : -1;
      notifyListeners();
    }
  }

  // --- NOTIFICATIONS ---

  Future<void> addPoints(int amount, String reason) async {
    if (_currentUser == null) return;
    
    final newPoints = _currentUser!.points + amount;
    final now = DateTime.now();
    _currentUser = _currentUser!.copyWith(
      points: newPoints,
      lastEnergySyncAt: now,
    );
    
    // Persistence
    final supabase = SupabaseService();
    await supabase.updateProfile({
      'points': newPoints,
      'last_energy_sync_at': now.toIso8601String(),
    });
    
    notifyListeners();
    
    // Trigger UI Overlay (will be implemented in a widget)
    debugPrint('Points earned: $amount for $reason. Total: $newPoints');
  }

  Future<void> refreshMessages(String conversationId) async {
    final supabase = SupabaseService();
    final messages = await supabase.getMessages(conversationId);
    
    final convIdx = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIdx != -1) {
      _conversations[convIdx].messages.clear();
      _conversations[convIdx].messages.addAll(messages);
      notifyListeners();
    }
  }

  void markConversationAsRead(String conversationId) {
    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex == -1) return;
    
    final conv = _conversations[convIndex];
    if (conv.unreadCount > 0 || conv.isNewMatch) {
      _conversations[convIndex] = Conversation(
        id: conv.id,
        otherUser: conv.otherUser,
        messages: conv.messages,
        unreadCount: 0,
        isNewMatch: false,
        locationTag: conv.locationTag,
      );
      notifyListeners();
    }
  }

  void blockUser(String userId) async {
    _hiddenUserIds.add(userId);
    notifyListeners();
    
    final supabase = SupabaseService();
    await supabase.blockUser(userId);
  }

  Future<bool> unblockUser(String userId) async {
    final supabase = SupabaseService();
    final success = await supabase.unblockUser(userId);
    if (success) {
      _hiddenUserIds.remove(userId);
      // Kullanıcı listede yoksa, veritabanından çekip listeye geri ekle
      if (!_allUsers.any((u) => u.id == userId)) {
        try {
          final profile = await supabase.getUserProfile(userId);
          if (profile != null) {
            _allUsers.add(profile);
          }
        } catch (_) {}
      }
      notifyListeners();
    }
    return success;
  }

  void reportUser(String userId, String reason) async {
    _hiddenUserIds.add(userId);
    _allUsers.removeWhere((User u) => u.id == userId);
    notifyListeners();
    
    final supabase = SupabaseService();
    await supabase.reportUser(userId, reason);
  }

  void reportContent(String url, String reason) async {
    _hiddenPhotoUrls.add(url);
    notifyListeners();
    
    final supabase = SupabaseService();
    // Assuming supabase has a general content report or we treat it as a user report with context
    await supabase.reportUser(_currentUser?.id ?? 'reporter', 'UGC Report: $url - Reason: $reason');
  }

  Future<void> refreshProfileStats() async {
    await _fetchProfileStats();
  }

  Future<void> _fetchProfileStats() async {
    if (_currentUser == null) return;
    final supabase = SupabaseService();
    
    try {
      // Monthly views
      _monthlyViews = await supabase.getProfileViewCount(thisMonthOnly: true);
      
      // Incoming winks (Total)
      _incomingWinkCount = await supabase.getIncomingWinkCount();
      
      // Match count (Total)
      final matchesList = await supabase.getConversations(); // This returns conversations which represent matches
      _matchCount = matchesList.length;
      
      // Active chats (Conversations with messages)
      _chatCount = matchesList.where((c) => c.messages.isNotEmpty).length;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching profile stats: $e');
    }
  }

  Future<void> logProfileVisit(String targetUserId) async {
    final supabase = SupabaseService();
    await supabase.logProfileView(targetUserId);
  }

  void markAllNotificationsSeen() {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].isNew) {
        _notifications[i] = _notifications[i].copyWith(isNew: false);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void setLanguage(String lang) async {
    _currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  void updatePrivacy({bool? radar, bool? location}) {
    if (radar != null) _showOnRadar = radar;
    if (location != null) _shareLocation = location;
    notifyListeners();
  }

  void setTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  // Public method for pull-to-refresh
  Future<void> refreshVenues() async {
    await _loadVenues();
  }

  // Full data refresh for pull-to-refresh on Radar
  Future<void> refreshAllData() async {
    final supabase = SupabaseService();
    _allUsers = await supabase.getAllUsers();
    _conversations = await supabase.getConversations();
    _matches = _conversations.map<String>((c) => c.otherUser.id).toSet();
    _sentInterests = (await supabase.getSentInterests()).toSet();
    _currentUser = await supabase.getCurrentUserProfile() ?? _currentUser;
    await _loadVenues();
    await _loadNotifications();
    notifyListeners();
  }

  void _injectMockUsers() {
    if (_allUsers.isEmpty) {
      _allUsers = [
        User(id: 'u1', name: 'Zeynep K.', university: 'Boğaziçi', department: 'Mimarlık', year: '3', bio: 'Tasarım aşığı.', interests: ['Sanat', 'Mimari'], avatar: '👩‍🎨', points: 15, campusZone: 'Güney Çimler', isOnline: true, lastActive: DateTime.now(), profileImageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=1974&auto=format&fit=crop', quizCompleted: true),
        User(id: 'u2', name: 'Kaan B.', university: 'Boğaziçi', department: 'Yazılım', year: '4', bio: 'Kod yazmak hayatım.', interests: ['Flutter', 'AI'], avatar: '👨‍💻', points: 28, campusZone: 'Kütüphane', isOnline: true, lastActive: DateTime.now(), profileImageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1974&auto=format&fit=crop', quizCompleted: true),
        User(id: 'u3', name: 'Aylin Y.', university: 'Boğaziçi', department: 'Psikoloji', year: '2', bio: 'Kitaplar ve kahve.', interests: ['Psikoloji', 'Kitap'], avatar: '🎨', points: 12, campusZone: 'Ruby Cafe', isOnline: true, lastActive: DateTime.now(), profileImageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=1976&auto=format&fit=crop', quizCompleted: true),
        User(id: 'u4', name: 'Emre T.', university: 'Boğaziçi', department: 'İşletme', year: '1', bio: 'Girişimcilik ve spor.', interests: ['Spor', 'Finans'], avatar: '🏀', points: 8, campusZone: 'Ruby Cafe', isOnline: true, lastActive: DateTime.now(), profileImageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1974&auto=format&fit=crop'),
        User(id: 'u5', name: 'Buse G.', university: 'Boğaziçi', department: 'Endüstri', year: '3', bio: 'Analitik düşünce.', interests: ['Matematik', 'Dans'], avatar: '👩‍🔬', points: 42, campusZone: 'Güney Çimler', isOnline: true, lastActive: DateTime.now(), profileImageUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?q=80&w=2070&auto=format&fit=crop'),
      ];
    }
  }

  // Real venues from database
  Future<void> _loadVenues() async {
    final supabase = SupabaseService();

    // university adını önce profilden, yoksa _universities listesinden türet
    String? uniName = _currentUser?.university;
    if (uniName == null && _currentUser?.universityId != null) {
      final match = _universities.where((u) => u.id == _currentUser!.universityId).firstOrNull;
      uniName = match?.name;
    }
    debugPrint('🏛️ _loadVenues — uniName: $uniName');

    final dbVenues = await supabase.getVenues(universityName: uniName);
    
    if (dbVenues.isNotEmpty) {
      _venues = dbVenues;
    } else {
      // Fallback
      _venues = [
        Venue(id: 'v2', name: 'Kuzey Piramit', icon: '📐', peopleCount: 0, isHot: false, heatLevel: 0.9, category: 'Study', imageUrl: 'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?q=80&w=2070&auto=format&fit=crop'),
        Venue(id: 'v3', name: 'Kütüphane', icon: '📚', peopleCount: 0, isHot: false, heatLevel: 0.7, category: 'Study', imageUrl: 'https://images.unsplash.com/photo-1568667256549-094345857637?q=80&w=2030&auto=format&fit=crop'),
        Venue(id: 'v4', name: 'Güney Çimler', icon: '🌳', peopleCount: 0, isHot: false, heatLevel: 0.6, category: 'Relax', imageUrl: 'https://images.unsplash.com/photo-1541829070764-84a7d30dd3f3?q=80&w=2069&auto=format&fit=crop'),
        Venue(id: 'v5', name: 'Ruby Cafe', icon: '🍱', peopleCount: 0, isHot: false, heatLevel: 0.5, category: 'Eat', imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=1974&auto=format&fit=crop'),
      ];
    }

    _injectMockUsers();
    
    // Sync conversations with injected mock users to fix "Bilinmiyor"
    for (int i = 0; i < _conversations.length; i++) {
        final mockIdx = _allUsers.indexWhere((u) => u.id == _conversations[i].otherUser.id);
        if (mockIdx != -1) {
            _conversations[i] = Conversation(
                id: _conversations[i].id,
                otherUser: _allUsers[mockIdx],
                messages: _conversations[i].messages,
                unreadCount: _conversations[i].unreadCount,
                isNewMatch: _conversations[i].isNewMatch,
                locationTag: _conversations[i].locationTag,
            );
        }
    }

    _updateVenueCounts();
    notifyListeners();
  }

  void _updateVenueCounts() {
    _venues = _venues.map((venue) {
      return venue.copyWith(peopleCount: getVenuePeopleCount(venue.name));
    }).toList();
  }

  Future<void> loadUniversities() async {
    final supabase = SupabaseService();
    _universities = await supabase.getUniversities();
    notifyListeners();
  }

  Future<void> updateUniversity(String universityId) async {
    if (_currentUser == null) return;
    
    final supabase = SupabaseService();
    final success = await supabase.updateProfile({
      'university_id': universityId,
    });
    
    if (success) {
      _currentUser = _currentUser!.copyWith(universityId: universityId);
      await _loadVenues();
      notifyListeners();
    }
  }

  Future<void> updateNotifSettings(bool notifLook, bool notifMatch) async {
    if (_currentUser == null) return;
    
    final supabase = SupabaseService();
    final success = await supabase.updateProfile({
      'notif_look': notifLook,
      'notif_match': notifMatch,
    });
    
    if (success) {
      _currentUser = _currentUser!.copyWith(
        notifLook: notifLook,
        notifMatch: notifMatch,
      );
      notifyListeners();
    }
  }

  void _generateMockVenues() {
    // Deprecated for _loadVenues
  }

  Future<void> _loadNotifications() async {
    final supabase = SupabaseService();
    final incomingWinks = await supabase.getIncomingWinks();
    final matchUserIds = _conversations.map((c) => c.otherUser.id).toSet();
    
    // Preserve existing timestamps
    final existingNotifs = {for (var n in _notifications) n.id: n};
    
    _notifications.clear();
    
    // 1. Matches and Messages as notifications
    for (var conv in _conversations) {
      final nidMatch = 'n_match_${conv.id}';
      final tsMatch = conv.messages.isNotEmpty ? conv.messages.first.timestamp : (existingNotifs[nidMatch]?.timestamp ?? DateTime.now());

      _notifications.add(AppNotification(
        id: nidMatch,
        type: NotificationType.match,
        relatedUser: conv.otherUser,
        title: 'Yeni Eşleşme',
        message: 'ile eşleştiniz! Sohbet başlatabilirsiniz.',
        location: conv.locationTag,
        timestamp: tsMatch,
        isNew: existingNotifs[nidMatch]?.isNew ?? conv.messages.isEmpty,
      ));

      final lastMsg = conv.lastMessage;
      if (lastMsg != null && lastMsg.senderId != _currentUser?.id) {
          final nidMsg = 'n_msg_${conv.id}';
          _notifications.add(AppNotification(
            id: nidMsg,
            type: NotificationType.message,
            relatedUser: conv.otherUser,
            title: 'Yeni Mesaj',
            message: lastMsg.text,
            location: conv.locationTag,
            timestamp: lastMsg.timestamp,
            isNew: conv.unreadCount > 0,
          ));
      }
    }
    
    // Sort notifications by timestamp descending
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final prefs = await SharedPreferences.getInstance();
    final awardedWinks = prefs.getStringList('awarded_winks') ?? [];
    bool pointsUpdated = false;

    // 2. Incoming Winks (Anonymous)
    for (var winkData in incomingWinks) {
      final senderId = winkData['id'];
      final location = winkData['location'];
      
      if (!matchUserIds.contains(senderId)) {
        final nid = 'n_wink_$senderId';
        
        // If this is a new wink we haven't awarded points for yet
        if (!awardedWinks.contains(senderId)) {
           await addPoints(2, 'Göz kırpıldı!');
           awardedWinks.add(senderId);
           pointsUpdated = true;
        }

        _notifications.add(AppNotification(
          id: nid,
          type: NotificationType.look,
          title: 'Yeni Etkileşim',
          message: 'birisi sana göz kırptı!',
          location: location,
          timestamp: existingNotifs[nid]?.timestamp ?? DateTime.now().subtract(const Duration(minutes: 5)),
          isNew: existingNotifs[nid]?.isNew ?? !awardedWinks.contains(senderId),
        ));
        // Push notification gönder
        if (!awardedWinks.contains(senderId)) {
          NotificationService().showNotification(
            id: senderId.hashCode,
            title: 'Biri sana göz kırptı',
            body: 'Şu anda burada biri sana göz kırptı.',
            payload: 'look_$senderId',
          );
        }
      }
    }

    if (pointsUpdated) {
      await prefs.setStringList('awarded_winks', awardedWinks);
    }
    
    notifyListeners();
  }


  void _generateMockNotifications() {
    if (_allUsers.isEmpty) return;
    _notifications = [
      AppNotification(
        id: 'n2',
        type: NotificationType.match,
        relatedUser: _allUsers[0],
        title: 'Eşleşme',
        message: 'ile eşleştiniz! Sohbet başlatabilirsiniz.',
        location: 'Kafe',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      AppNotification(
        id: 'n3',
        type: NotificationType.system,
        title: 'Popüler Mekan',
        message: "Bugün Kafe B-01'de 18 kişi var. Popüler bir gün!",
        location: 'Sistem',
        systemIcon: '🏫',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isNew: false,
      ),
    ];
  }

  final Map<String, StreamSubscription> _messageSubscriptions = {};

  User? _lastNewMatch;
  User? get lastNewMatch => _lastNewMatch;

  void clearLastMatch() {
    _lastNewMatch = null;
    notifyListeners();
  }

  void _startRealtimeListeners() {
    _startProfileRealtimeListener();
    _startAllMessagesListener();
    _startNotificationListener();
  }

  void _startNotificationListener() {
    _notifSubscription?.cancel();
    final supabase = SupabaseService();
    _notifSubscription = supabase.streamNotifications().listen((List<Map<String, dynamic>> data) {
      if (data.isEmpty) return;
      
      bool hasNewNotif = false;
      int oldLen = _notifications.length;
      
      List<AppNotification> newNotifs = data.map<AppNotification>((d) {
        final userId = d['related_user_id'];
        User? relatedUser;
        if (userId != null) {
          try {
            relatedUser = _allUsers.firstWhere((u) => u.id == userId);
          } catch (_) {}
        }

        return AppNotification(
          id: d['id'].toString(),
          type: d['type'] == 'match' ? NotificationType.match : NotificationType.system,
          title: d['title'] ?? 'Bildirim',
          message: d['message'] ?? '',
          location: d['location'] ?? 'Kampüs',
          timestamp: DateTime.parse(d['timestamp'] ?? DateTime.now().toIso8601String()),
          isNew: d['is_new'] ?? true,
          relatedUser: relatedUser,
        );
      }).toList();

      if (newNotifs.length > oldLen && newNotifs.first.isNew) {
         final latest = newNotifs.first;
         NotificationService().showNotification(
           id: latest.id.hashCode,
           title: latest.title,
           body: latest.message,
         );
         HapticFeedback.mediumImpact();
      }

      _notifications = newNotifs;
      notifyListeners();
    });
  }

  void _startProfileRealtimeListener() {
    _profileSubscription?.cancel();
    final supabase = SupabaseService();
    _profileSubscription = supabase.streamProfileChanges().listen((List<Map<String, dynamic>> data) {
      bool changed = false;
      for (var profile in data) {
        final profileId = profile['id'];
        
        // Update _allUsers
        final userIdx = _allUsers.indexWhere((u) => u.id == profileId);
        if (userIdx != -1) {
          final updatedUser = User(
            id: profileId,
            name: profile['name'] ?? 'İsimsiz',
            university: profile['university'] ?? 'Bilinmiyor',
            department: profile['department'] ?? '',
            year: profile['year'] ?? '',
            bio: profile['bio'] ?? '',
            interests: List<String>.from(profile['interests'] ?? []),
            avatar: (profile['avatar'] != null && profile['avatar'].startsWith('http')) ? '🧑' : (profile['avatar'] ?? '🧑'),
            profileImageUrl: (profile['avatar'] != null && profile['avatar'].startsWith('http')) ? profile['avatar'] : null,
            campusZone: profile['campus_zone'] ?? 'Bilinmiyor',
            isOnline: profile['is_online'] ?? false,
            lastActive: profile['last_active'] != null ? DateTime.parse(profile['last_active']) : DateTime.now(),
            genderFlag: profile['gender_flag'] ?? 'm',
            lastCheckinAt: profile['last_checkin_at'] != null ? DateTime.parse(profile['last_checkin_at']) : null,
            points: profile['points'] ?? 0,
            quizCompleted: profile['quiz_completed'] ?? false,
            quizStep: profile['quiz_step'] ?? 0,
            lastEnergySyncAt: profile['last_energy_sync_at'] != null ? DateTime.parse(profile['last_energy_sync_at']) : null,
          );
          
          if (_allUsers[userIdx].isOnline != updatedUser.isOnline || _allUsers[userIdx].campusZone != updatedUser.campusZone) {
            _allUsers[userIdx] = updatedUser;
            changed = true;
          }
        }
        
        // Update _conversations
        final convIdx = _conversations.indexWhere((c) => c.otherUser.id == profileId);
        if (convIdx != -1) {
          final updatedUserForConv = _allUsers.firstWhere((u) => u.id == profileId);
          _conversations[convIdx] = Conversation(
            id: _conversations[convIdx].id,
            otherUser: updatedUserForConv,
            messages: _conversations[convIdx].messages,
            unreadCount: _conversations[convIdx].unreadCount,
            isNewMatch: _conversations[convIdx].isNewMatch,
            locationTag: _conversations[convIdx].locationTag,
          );
          changed = true;
        }
      }
      
      if (changed) {
        notifyListeners();
        _updateVenueCounts();
      }
    });
  }

  void _startAllMessagesListener() {
    final supabase = SupabaseService();
    // Cancel old subs
    for (var sub in _messageSubscriptions.values) {
      sub.cancel();
    }
    _messageSubscriptions.clear();

    // Listen for each conversation
    for (var conv in _conversations) {
      _messageSubscriptions[conv.id] = supabase.streamMessages(conv.id).listen((msgs) {
        final convIdx = _conversations.indexWhere((c) => c.id == conv.id);
        if (convIdx != -1) {
          final oldLen = _conversations[convIdx].messages.length;
          if (msgs.length > oldLen) {
            // New message detected!
            _conversations[convIdx].messages.clear();
            _conversations[convIdx].messages.addAll(msgs);
            
            final lastMsg = msgs.last;
            if (lastMsg.senderId != _currentUser?.id) {
               // Notify if it's from someone else
               final notifier = NotificationService();
               notifier.showNotification(
                 id: conv.id.hashCode,
                 title: conv.otherUser.name,
                 body: lastMsg.text,
               );
               HapticFeedback.lightImpact();

               final nidMsg = 'n_msg_${conv.id}';
               _notifications.removeWhere((n) => n.id == nidMsg);
               _notifications.insert(0, AppNotification(
                 id: nidMsg,
                 type: NotificationType.message,
                 relatedUser: conv.otherUser,
                 title: 'Yeni Mesaj',
                 message: lastMsg.text,
                 location: conv.locationTag,
                 timestamp: lastMsg.timestamp,
                 isNew: true,
               ));
               _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            }
            notifyListeners();
          }
        }
      });
    }
  }

  void markAllConversationsAsRead() {
    bool changed = false;
    for (int i = 0; i < _conversations.length; i++) {
      if (_conversations[i].unreadCount > 0 || _conversations[i].isNewMatch) {
         _conversations[i] = Conversation(
            id: _conversations[i].id,
            otherUser: _conversations[i].otherUser,
            messages: _conversations[i].messages,
            unreadCount: 0,
            isNewMatch: false,
            locationTag: _conversations[i].locationTag,
          );
          changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}
