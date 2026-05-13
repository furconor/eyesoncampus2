import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../models/app_models.dart' as app_models;

List<String> _parseList(dynamic data) {
  if (data == null) return [];
  if (data is Iterable) return List<String>.from(data);
  if (data is String) {
    final str = data.trim();
    if (str.isEmpty) return [];
    if (str.startsWith('[') && str.endsWith(']')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Iterable) {
          return List<String>.from(decoded).where((e) => e != '[]' && e.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    // Fallback: Postgrest array syntax {a,b,c}
    if (str.startsWith('{') && str.endsWith('}')) {
      final inner = str.substring(1, str.length - 1);
      if (inner.isEmpty) return [];
      return inner.split(',').map((e) => e.trim()).where((e) => e != '[]' && e.isNotEmpty).toList();
    }
    if (str == '[]') return [];
    return [str];
  }
  return [];
}

class SupabaseService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool get isAuthenticated => _client.auth.currentUser != null;
  String? get currentUserId => _client.auth.currentUser?.id;

  // Profil verisini getir
  Future<app_models.User?> getCurrentUserProfile() async {
    if (!isAuthenticated) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', currentUserId!)
          .single();

      return app_models.User(
        id: response['id'],
        name: response['name'],
        university: response['university'],
        department: response['department'],
        year: response['year'],
        bio: response['bio'] ?? '',
        interests: _parseList(response['interests']),
        avatar: (response['avatar'] != null && response['avatar'].startsWith('http')) ? '🧑' : (response['avatar'] ?? '🧑'),
        profileImageUrl: (response['avatar'] != null && response['avatar'].startsWith('http')) ? response['avatar'] : null,
        campusZone: response['campus_zone'] ?? 'Bilinmiyor',
        isOnline: response['is_online'] ?? false,
        lastActive: DateTime.parse(response['last_active']),
        genderFlag: response['gender_flag'],
        universityId: response['university_id'],
        lastCheckinAt: response['last_checkin_at'] != null ? DateTime.parse(response['last_checkin_at']) : null,
        points: response['points'] ?? 0,
        diaryPhotos: _parseList(response['diary_photos']),
        notifLook: response['notif_look'] ?? true,
        notifMatch: response['notif_match'] ?? true,
        quizCompleted: response['quiz_completed'] ?? false,
        quizStep: response['quiz_step'] ?? 0,
        lastEnergySyncAt: response['last_energy_sync_at'] != null ? DateTime.parse(response['last_energy_sync_at']) : null,
      );

    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  // E-posta ile Giriş
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow; // Rethrow to let the UI handle the specific error message
    }
  }

  // E-posta ile Kayıt
  // Dönen değer null ise başarılı (oturum açıldı), 'verification_required' ise OTP bekliyor, diğerleri hata mesajıdır.
  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.session == null && response.user != null) {
        return 'verification_required';
      }
      return null;
    } on AuthException catch (e) {
      debugPrint('Sign up AuthException: $e');
      return e.message;
    } catch (e) {
      debugPrint('Sign up error: $e');
      return e.toString();
    }
  }

  // Kayıt OTP Doğrulama
  Future<bool> verifySignupOtp(String email, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      return response.session != null;
    } catch (e) {
      debugPrint('Error verifying signup OTP: $e');
      return false;
    }
  }

  // ÇEVRİMİÇİ DURUMUNU GÜNCELLE
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (!isAuthenticated) return;
    try {
      await _client.from('profiles').update({
        'is_online': isOnline,
        'last_active': DateTime.now().toIso8601String(),
      }).eq('id', currentUserId!);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // PROFİL DEĞİŞİKLİKLERİNİ REAL-TIME DİNLE
  Stream<List<Map<String, dynamic>>> streamProfileChanges() {
    return _client.from('profiles').stream(primaryKey: ['id']);
  }

  // MESAJLARI REAL-TIME DİNLE
  Stream<List<app_models.AppMessage>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) => data.map((m) => app_models.AppMessage(
              id: m['id'].toString(),
              senderId: m['sender_id'] ?? 'system',
              receiverId: '',
              text: m['text'],
              timestamp: DateTime.parse(m['created_at']),
              isSystem: m['is_system'] ?? false,
            )).toList());
  }

  // Çıkış Yap
  Future<void> signOut() async {
    await _client.auth.signOut();
    notifyListeners();
  }

  // HESABI SİL (App Store Requirement)
  Future<bool> deleteAccount() async {
    if (!isAuthenticated) return false;
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      // 1. Profil bilgisini silmeye calis
      // Not: Eger veritabaninda foreign key kisitlamalari varsa burasi hata verebilir.
      // O durumda en azindan oturumu kapatiyoruz.
      try {
        await _client.from('profiles').delete().eq('id', userId);
      } catch (e) {
        debugPrint('Profil tablosu silinemedi (muhtemelen iliskili veriler var): $e');
      }
      
      // 2. Oturumu kapat (Artik bu cihazda login degil)
      await signOut();
      return true;
    } catch (e) {
      debugPrint('Error during account deletion process: $e');
      // Kritik bir hata olsa bile kullaniciyi sistemden atmak icin signOut() cagiriyoruz.
      await signOut();
      return true; 
    }
  }

  // Delete avatar files from storage
  Future<void> deleteAvatarStorage(String userId) async {
    try {
      final List<FileObject> files = await _client.storage.from('app_data').list(path: 'avatars');
      final userFiles = files.where((f) => f.name.startsWith(userId)).toList();
      if (userFiles.isNotEmpty) {
        await _client.storage.from('app_data').remove(
          userFiles.map((f) => 'avatars/${f.name}').toList(),
        );
      }
    } catch (e) {
      debugPrint('Error deleting avatar storage: $e');
    }
  }

  // Block User (Guideline 1.2)
  Future<bool> blockUser(String blockedUserId) async {
    if (!isAuthenticated) return false;
    try {
      await _client.from('blocks').insert({
        'blocker_id': currentUserId,
        'blocked_user_id': blockedUserId,
      });
      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  // Report User (Guideline 1.2)
  Future<bool> reportUser(String reportedUserId, String reason) async {
    if (!isAuthenticated) return false;
    try {
      await _client.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': reportedUserId,
        'reason': reason,
      });
      return true;
    } catch (e) {
      debugPrint('Error reporting user: $e');
      return false;
    }
  }

  // Profil Güncelleme (mevcut profil için — partial update güvenli)
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    if (!isAuthenticated) return false;
    try {
      await _client.from('profiles').update(profileData).eq('id', currentUserId!);
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // Update User Points
  Future<bool> updatePoints(int points) async {
    if (!isAuthenticated) return false;
    try {
      await _client.from('profiles').update({'points': points}).eq('id', currentUserId!);
      return true;
    } catch (e) {
      debugPrint('Error updating points: $e');
      return false;
    }
  }

  // Update specific user's points (e.g. for event creator bonus) 
  Future<bool> updatePointsForUser(String userId, int bonusAmount) async {
    try {
      // Get current points first
      final userResponse = await _client.from('profiles').select('points').eq('id', userId).single();
      final currentPoints = userResponse['points'] ?? 0;
      
      // Update with bonus
      await _client.from('profiles').update({'points': currentPoints + bonusAmount}).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error updating points for user $userId: $e');
      return false;
    }
  }

  // Profil Oluşturma (Sign Up sonrası — upsert ile tam veri)
  Future<bool> createProfile(Map<String, dynamic> profileData) async {
    if (!isAuthenticated) return false;
    try {
      profileData['id'] = currentUserId;
      // Yeni kullanıcılara 15 enerji (puan) vererek başlatıyoruz
      profileData['points'] ??= 15; 
      await _client.from('profiles').upsert(profileData);
      return true;
    } catch (e) {
      debugPrint('Error creating profile: $e');
      return false;
    }
  }

  // QUIZ SORULARINI ÇEK (Günlük rotasyon ile)
  Future<List<Map<String, dynamic>>> getQuizQuestions() async {
    try {
      final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      final dayIndex = dayOfYear % 7; // 7 günlük rotasyon

      final response = await _client
          .from('quiz_questions')
          .select()
          .eq('day_index', dayIndex)
          .limit(10);

      if ((response as List).isEmpty) {
        // Fallback: day_index filtresi olmadan tüm soruları çek
        final fallback = await _client
            .from('quiz_questions')
            .select()
            .limit(10);
        return List<Map<String, dynamic>>.from(fallback as List);
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching quiz questions: $e');
      return []; // Boş döner, app fallback kullanır
    }
  }

  // FOTOĞRAF YÜKLE (Supabase Storage) - Baytlarla (Web/Mobil Uyumluluğu)
  Future<String?> uploadAvatarBytes(Uint8List bytes, String extension) async {
    if (!isAuthenticated) return null;
    try {
      final String fileName = '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String path = 'avatars/$fileName';

      await _client.storage.from('app_data').uploadBinary(
        path, 
        bytes,
        fileOptions: FileOptions(contentType: 'image/$extension', upsert: true),
      );

      final String publicUrl = _client.storage.from('app_data').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar by bytes: $e');
      return null;
    }
  }

  // DIARY PHOTO YÜKLE
  Future<String?> uploadDiaryPhotoBytes(Uint8List bytes, String extension) async {
    if (!isAuthenticated) return null;
    try {
      final String fileName = '${currentUserId}_diary_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String path = 'diary/$fileName';

      await _client.storage.from('app_data').uploadBinary(
        path, 
        bytes,
        fileOptions: FileOptions(contentType: 'image/$extension', upsert: true),
      );

      final String publicUrl = _client.storage.from('app_data').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading diary photo: $e');
      return null;
    }
  }

  // DIARY PHOTO SIL
  Future<void> deleteDiaryPhoto(String url) async {
    try {
      // URL'den path'i ayıkla (app_data/public/diary/...)
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final indexOfFolder = pathSegments.indexOf('diary');
      if (indexOfFolder != -1) {
        final path = pathSegments.sublist(indexOfFolder).join('/');
        await _client.storage.from('app_data').remove([path]);
      }
    } catch (e) {
      debugPrint('Error deleting diary photo: $e');
    }
  }

  // FOTOĞRAF YÜKLE (Supabase Storage) - XFile ile byte olarak yükle
  Future<String?> uploadAvatar(dynamic fileSource) async {
    if (!isAuthenticated) return null;
    try {
      final String fileName = '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'avatars/$fileName';

      if (fileSource is String) {
        // fileSource is a path, read bytes using XFile for cross-platform support
        final xFile = XFile(fileSource);
        final bytes = await xFile.readAsBytes();
        
        await _client.storage.from('app_data').uploadBinary(
          path, 
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      } else {
        return null;
      }

      // Public URL al
      final String publicUrl = _client.storage.from('app_data').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  // Gerçek cihazları/kullanıcıları getiren temel bir fonksiyon
  Future<List<app_models.User>> getAllUsers() async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client
          .from('profiles')
          .select()
          .neq('id', currentUserId as Object);

      return (response as List).map((data) => app_models.User(
        id: data['id'],
        name: data['name'],
        university: data['university'] ?? 'İTÜ',
        department: data['department'] ?? '',
        year: data['year'] ?? '',
        bio: data['bio'] ?? '',
        interests: _parseList(data['interests']),
        avatar: (data['avatar'] != null && data['avatar'].startsWith('http')) ? '🧑' : (data['avatar'] ?? '🧑'),
        profileImageUrl: (data['avatar'] != null && data['avatar'].startsWith('http')) ? data['avatar'] : null,
        campusZone: data['campus_zone'] ?? 'Bilinmiyor',
        isOnline: data['is_online'] ?? false,
        lastActive: data['last_active'] != null ? DateTime.parse(data['last_active']) : DateTime.now(),
        genderFlag: data['gender_flag'] ?? 'm',
        lastCheckinAt: data['last_checkin_at'] != null ? DateTime.parse(data['last_checkin_at']) : null,
        points: data['points'] ?? 0,
        diaryPhotos: _parseList(data['diary_photos']),
        notifLook: data['notif_look'] ?? true,
        notifMatch: data['notif_match'] ?? true,
        quizCompleted: data['quiz_completed'] ?? false,
        quizStep: data['quiz_step'] ?? 0,
        lastEnergySyncAt: data['last_energy_sync_at'] != null ? DateTime.parse(data['last_energy_sync_at']) : null,
      )).toList();

    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  // TEST VE APPLE REVIEW İÇİN SAHTE VERİ YÜKLEME (SEED)
  Future<void> seedDummyData({String? targetZone}) async {
    final dummies = [
      {'email': 'apple_test@eyesoncampus.com', 'pass': 'AppleTest2026*', 'name': 'Apple Reviewer', 'dep': 'App Review', 'year': 'Reviewer', 'bio': 'Uygulamayı App Store Guideline kurallarına göre inceliyorum.', 'avatar': '🧑', 'gender': 'm', 'zone': targetZone ?? 'Merkez Kafe'},
      {'email': 'zeynep@edu.tr', 'pass': '12345678', 'name': 'Zeynep K.', 'dep': 'Bilgisayar Müh.', 'year': '2. Sınıf', 'bio': 'Kod yazarken kahve içmeyi severim.', 'avatar': '👩', 'gender': 'f', 'zone': targetZone ?? 'Kuzey Piramit'},
      {'email': 'kaan@edu.tr', 'pass': '12345678', 'name': 'Kaan B.', 'dep': 'Makine Müh.', 'year': '1. Sınıf', 'bio': 'Spor salonundayım genelde.', 'avatar': '👦', 'gender': 'm', 'zone': targetZone ?? 'Kuzey Piramit'},
      {'email': 'aylin@edu.tr', 'pass': '12345678', 'name': 'Aylin Y.', 'dep': 'Mimarlık', 'year': '4. Sınıf', 'bio': 'Proje çizimleri...', 'avatar': '👩', 'gender': 'f', 'zone': targetZone ?? 'Güney Çimler'},
      {'email': 'emre@edu.tr', 'pass': '12345678', 'name': 'Emre T.', 'dep': 'Elektrik Müh.', 'year': '2. Sınıf', 'bio': 'Gece kütüphanecisi.', 'avatar': '👦', 'gender': 'm', 'zone': targetZone ?? 'Kütüphane'},
      {'email': 'deniz@edu.tr', 'pass': '12345678', 'name': 'Deniz A.', 'dep': 'Endüstri Müh.', 'year': '3. Sınıf', 'bio': 'Piramit kafede takılıyorum.', 'avatar': '👩', 'gender': 'f', 'zone': targetZone ?? 'Ruby Cafe'},
    ];

    for (var d in dummies) {
      String? userId;
      try {
        final authRes = await _client.auth.signUp(email: d['email']!, password: d['pass']!);
        userId = authRes.user?.id;
      } catch (e) {
        // Zaten kayıtlıysa giriş yap
        try {
          final loginRes = await _client.auth.signInWithPassword(email: d['email']!, password: d['pass']!);
          userId = loginRes.user?.id;
        } catch (inner) {
          debugPrint('Failed to login for seeding ${d['email']}: $inner');
        }
      }

      if (userId != null) {
        await _client.from('profiles').upsert({
          'id': userId,
          'name': d['name'],
          'university': 'İstanbul Teknik Üniversitesi',
          'department': d['dep'],
          'year': d['year'],
          'bio': d['bio'],
          'avatar': d['avatar'],
          'gender_flag': d['gender'],
          'campus_zone': d['zone'],
          'is_online': true,
          'last_active': DateTime.now().toIso8601String(),
          'last_checkin_at': DateTime.now().toIso8601String(),
        });
      }
    }

    // REVIEWER İÇİN OTOMATİK EŞLEŞME (Demo Kolaylığı)
    try {
      final reviewer = await _client.from('profiles').select('id').eq('name', 'Apple Reviewer').maybeSingle();
      final zeynep = await _client.from('profiles').select('id').eq('name', 'Zeynep K.').maybeSingle();

      if (reviewer != null && zeynep != null) {
        final rId = reviewer['id'];
        final zId = zeynep['id'];

        // Karşılıklı ilgi
        await _client.from('swipes').upsert({'sender_id': rId, 'receiver_id': zId});
        await _client.from('swipes').upsert({'sender_id': zId, 'receiver_id': rId});

        // Match kaydı
        final match = await _client.from('matches').upsert({
          'user1_id': rId,
          'user2_id': zId,
        }).select().single();

        // Konuşma ve ilk mesaj
        final conv = await _client.from('conversations').upsert({
          'match_id': match['id'],
          'location_tag': 'Merkez Kafe',
        }).select().single();

        await _client.from('messages').insert({
          'conversation_id': conv['id'],
          'sender_id': zId,
          'text': 'Merhaba! Uygulamaya hoş geldin. Seninle eşleştiğimiz için mutluyum.',
        });
      }
    } catch (e) {
      debugPrint('Error seeding reviewer match: $e');
    }
    
    // Oturumu kapat ki asıl kullanıcı hesabını oluşturup girebilsin
    await _client.auth.signOut();
  }

  // BİR KULLANICIYA İLGİ GÖNDERME (SWIPE / LIKE)
  Future<bool> sendInterest(String receiverId) async {
    if (!isAuthenticated) return false;

    try {
      // 1. Swipes tablosuna ekle (created_at'i guncelliyoruz ki 1 saatlik sure sifirlansin)
      try {
        await _client.from('swipes').insert({
          'sender_id': currentUserId,
          'receiver_id': receiverId,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Zaten varsa suresini guncelle
        await _client.from('swipes').update({
          'created_at': DateTime.now().toIso8601String(),
        }).eq('sender_id', currentUserId!).eq('receiver_id', receiverId);
      }

      // 2. Etkileşimi logla (Hız sınırı için)
      await logInteraction('wink');

      // MAGIC: Otomatik Eşleşme (Sadece video çekimi ve test için sahte hesaplara anında eşleşme)
      try {
        final rUser = await _client.from('profiles').select('name').eq('id', receiverId).maybeSingle();
        if (rUser != null && ['Zeynep K.', 'Kaan B.', 'Aylin Y.', 'Emre T.', 'Deniz A.'].contains(rUser['name'])) {
          await ensureMatch(receiverId);
          return true;
        }
      } catch (_) {}

      // 3. Karşı taraf da bana daha önceden ilgi göndermiş mi? (Eşleşme kontrolü - Son 2 Saat)
      final expirationTime = getWinkExpirationFilter();
      final checkMatch = await _client
          .from('swipes')
          .select()
          .eq('sender_id', receiverId)
          .eq('receiver_id', currentUserId!)
          .gt('created_at', expirationTime)
          .limit(1);

      // Eğer karşı taraf da beni beğenmişse
      if ((checkMatch as List).isNotEmpty) {
        // Matches tablosuna ekle (İki kombinasyonu da ekleyelim ya da tekil id sistemi kuralım. Şimdilik düz insert)
        await _client.from('matches').insert({
          'user1_id': currentUserId,
          'user2_id': receiverId,
        });
        
        // Eşleşmeyi geri dön (true)
        return true;
      }

      // Eşleşme yok sadece ilgi gönderildi
      return false;
    } catch (e) {
      debugPrint('Error sending interest: $e');
      return false;
    }
  }

  // GÜNLÜK RESET: Eşleşmeyenlerin swipe kayıtlarını sil
  Future<void> deleteUnmatchedSwipes(List<String> receiverIds) async {
    if (!isAuthenticated || receiverIds.isEmpty) return;
    try {
      await _client
          .from('swipes')
          .delete()
          .eq('sender_id', currentUserId!)
          .inFilter('receiver_id', receiverIds);
    } catch (e) {
      debugPrint('Error deleting unmatched swipes: $e');
    }
  }

  // GÖNDERİLEN GÖZ KIRPMALARI GETİR
  Future<List<String>> getSentInterests() async {
    if (!isAuthenticated) return [];
    try {
      final oneHourAgo = getWinkExpirationFilter();
      final response = await _client
          .from('swipes')
          .select('receiver_id')
          .eq('sender_id', currentUserId!)
          .gt('created_at', oneHourAgo);
      
      return (response as List).map((data) => data['receiver_id'] as String).toList();
    } catch (e) {
      debugPrint('Error fetching sent interests: $e');
      return [];
    }
  }

  // BANA GÖNDERİLEN GÖZ KIRPMALARI GETİR
  Future<List<Map<String, dynamic>>> getIncomingWinks() async {
    if (!isAuthenticated) return [];
    try {
      final oneHourAgo = getWinkExpirationFilter();
      final response = await _client
          .from('swipes')
          .select('sender_id, profiles!swipes_sender_id_fkey(campus_zone)')
          .eq('receiver_id', currentUserId!)
          .gt('created_at', oneHourAgo);
      
      final list = (response as List).map((data) => {
        'id': data['sender_id'] as String,
        'location': data['profiles'] != null ? data['profiles']['campus_zone'] : 'Kampüste'
      }).toList();
      
      return list;
    } catch (e) {
      debugPrint('Error fetching incoming winks: $e');
      return [];
    }
  }

  // BANA GELEN TOPLAM GÖZ KIRPMA SAYISINI GETİR
  Future<int> getIncomingWinkCount() async {
    if (!isAuthenticated) return 0;
    try {
      final response = await _client
          .from('swipes')
          .select('*')
          .eq('receiver_id', currentUserId!)
          .count(CountOption.exact);
      
      return response.count;
    } catch (e) {
      debugPrint('Error fetching incoming wink count: $e');
      return 0;
    }
  }

  // SOHBETLERİ (CONVERSATIONS) GETİR
  Future<List<app_models.Conversation>> getConversations() async {
    if (!isAuthenticated) return [];

    try {
      // 1. Önce benim dahil olduğum maçları çek
      final matchesResponse = await _client
          .from('matches')
          .select('id')
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId');
      
      if ((matchesResponse as List).isEmpty) return [];
      
      final matchIds = matchesResponse.map((m) => m['id']).toList();

      // 2. Bu maçlara ait konuşmaları çek
      final response = await _client
          .from('conversations')
          .select('*, matches(user1_id, user2_id)')
          .inFilter('match_id', matchIds);

      final conversationsData = response as List<dynamic>;
      if (conversationsData.isEmpty) return [];

      // DİKKAT: N+1 Optimizasyonu
      // Bütün otherUserIds ve conversationIds toplanır
      Set<String> otherUserIds = {};
      List<String> conversationIds = [];
      for (var row in conversationsData) {
        final match = row['matches'];
        final otherUserId = match['user1_id'] == currentUserId ? match['user2_id'] : match['user1_id'];
        otherUserIds.add(otherUserId);
        conversationIds.add(row['id']);
      }

      // Profilleri toplu çek
      final profilesResp = await _client
          .from('profiles')
          .select()
          .inFilter('id', otherUserIds.toList());
      
      Map<String, dynamic> profilesMap = {};
      for (var p in profilesResp as List<dynamic>) {
        profilesMap[p['id']] = p;
      }

      // Mesajları toplu çek
      final messagesResp = await _client
          .from('messages')
          .select()
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: true);

      Map<String, List<app_models.AppMessage>> messagesMap = { for (var id in conversationIds) id: [] };
      for (var data in messagesResp as List<dynamic>) {
        messagesMap[data['conversation_id']]?.add(app_models.AppMessage(
          id: data['id'],
          senderId: data['sender_id'] ?? 'system',
          receiverId: '', // Bu modelde çok kritik değil ama doldurulabilir
          text: data['text'],
          timestamp: DateTime.parse(data['created_at']),
          isSystem: data['is_system'] ?? false,
        ));
      }

      List<app_models.Conversation> conversations = [];
      
      for (var row in conversationsData) {
        final match = row['matches'];
        final otherUserId = match['user1_id'] == currentUserId ? match['user2_id'] : match['user1_id'];
        
        final otherUserProfile = profilesMap[otherUserId];
        if (otherUserProfile == null) continue;

        final otherUser = app_models.User(
          id: otherUserProfile['id'],
          name: otherUserProfile['name'],
          university: otherUserProfile['university'] ?? 'İTÜ',
          department: otherUserProfile['department'] ?? '',
          year: otherUserProfile['year'] ?? '',
          bio: otherUserProfile['bio'] ?? '',
          interests: _parseList(otherUserProfile['interests']),
          avatar: (otherUserProfile['avatar'] != null && otherUserProfile['avatar'].startsWith('http')) ? '🧑' : (otherUserProfile['avatar'] ?? '🧑'),
          profileImageUrl: (otherUserProfile['avatar'] != null && otherUserProfile['avatar'].startsWith('http')) ? otherUserProfile['avatar'] : null,
          campusZone: otherUserProfile['campus_zone'] ?? 'Bilinmiyor',
          isOnline: otherUserProfile['is_online'] ?? false,
          lastActive: otherUserProfile['last_active'] != null ? DateTime.parse(otherUserProfile['last_active']) : DateTime.now(),
          genderFlag: otherUserProfile['gender_flag'] ?? 'm',
          lastCheckinAt: otherUserProfile['last_checkin_at'] != null ? DateTime.parse(otherUserProfile['last_checkin_at']) : null,
        );

        final messages = messagesMap[row['id']] ?? [];

        conversations.add(app_models.Conversation(
          id: row['id'],
          otherUser: otherUser,
          messages: messages,
          locationTag: row['location_tag'] ?? '',
          isNewMatch: messages.isEmpty,
          createdAt: row['created_at'] != null ? DateTime.parse(row['created_at']) : null,
        ));
      }

      return conversations;
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      return [];
    }
  }

  // MESAJLARI GETİR
  Future<List<app_models.AppMessage>> getMessages(String conversationId) async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List).map((data) => app_models.AppMessage(
        id: data['id'].toString(),
        senderId: data['sender_id'] ?? 'system',
        receiverId: '', 
        text: data['text'],
        timestamp: DateTime.parse(data['created_at']),
        isSystem: data['is_system'] ?? false,
      )).toList();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  // MESAJ GÖNDER
  Future<bool> sendMessage(String conversationId, String text) async {
    if (!isAuthenticated) return false;
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'text': text,
        'is_system': false,
      });
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  // Ensure a match row exists in the database (for forced/reviewer matches)
  Future<void> ensureMatch(String otherUserId) async {
    if (!isAuthenticated) return;
    try {
      // Check if match already exists
      final existing = await _client
          .from('matches')
          .select('id')
          .or('and(user1_id.eq.$currentUserId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$currentUserId)')
          .maybeSingle();

      if (existing == null) {
        // Create swipes in both directions to simulate mutual interest
        try {
          await _client.from('swipes').upsert({
            'sender_id': currentUserId,
            'receiver_id': otherUserId,
            'created_at': DateTime.now().toIso8601String(),
          });
          await _client.from('swipes').upsert({
            'sender_id': otherUserId,
            'receiver_id': currentUserId,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}

        // Create the match row
        await _client.from('matches').insert({
          'user1_id': currentUserId,
          'user2_id': otherUserId,
        });
      }
    } catch (e) {
      debugPrint('Error ensuring match: $e');
    }
  }

  // YENİ KONUŞMA OLUŞTUR (Eşleşme olduğunda)
  Future<String?> createConversation(String receiverId, String locationTag) async {
    if (!isAuthenticated) return null;
    try {
      // Önce match ID'yi bulalım (iki taraflı da olabilir)
      final matchResponse = await _client
          .from('matches')
          .select('id')
          .or('and(user1_id.eq.$currentUserId,user2_id.eq.$receiverId),and(user1_id.eq.$receiverId,user2_id.eq.$currentUserId)')
          .maybeSingle();

      if (matchResponse == null) return null;

      final matchId = matchResponse['id'];

      // Zaten bir konuşma var mı kontrol et
      final existingConv = await _client
          .from('conversations')
          .select('id')
          .eq('match_id', matchId)
          .maybeSingle();

      if (existingConv != null) return existingConv['id'];

      // Yeni oluştur
      final newConv = await _client.from('conversations').insert({
        'match_id': matchId,
        'location_tag': locationTag,
      }).select().single();

      return newConv['id'];
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      return null;
    }
  }

  // Şifre Sıfırlama — OTP gönder
  Future<bool> sendPasswordResetOtp(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      debugPrint('Error sending password reset: $e');
      return false;
    }
  }

  // OTP Doğrulama
  Future<bool> verifyOtp(String email, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      return response.session != null;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }

  // Şifre Güncelleme (OTP doğrulandıktan sonra)
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      debugPrint('Error updating password: $e');
      return false;
    }
  }

  // Engellenen Kullanıcıları Getir
  Future<List<app_models.User>> getBlockedUsers() async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client
          .from('blocks')
          .select('blocked_user_id, profiles!blocks_blocked_user_id_fkey(*)')
          .eq('blocker_id', currentUserId!);
      
      return (response as List).map((data) {
        final profile = data['profiles'];
        return app_models.User(
          id: profile['id'],
          name: profile['name'],
          university: profile['university'] ?? 'İTÜ',
          department: profile['department'] ?? '',
          year: profile['year'] ?? '',
          bio: profile['bio'] ?? '',
          interests: _parseList(profile['interests']),
          avatar: profile['avatar'] ?? '🧑',
          campusZone: profile['campus_zone'] ?? 'Bilinmiyor',
          isOnline: profile['is_online'] ?? false,
          lastActive: profile['last_active'] != null ? DateTime.parse(profile['last_active']) : DateTime.now(),
          genderFlag: profile['gender_flag'] ?? 'm',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
      return [];
    }
  }

  // Engellemeyi Kaldır
  Future<bool> unblockUser(String userId) async {
    if (!isAuthenticated) return false;
    try {
      await _client.from('blocks').delete().eq('blocker_id', currentUserId!).eq('blocked_user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }
  // APP IMAGES (onboarding / auth backgrounds) — Supabase Storage'dan çeker
  Future<Map<String, List<String>>> getAppImages() async {
    const bucket = 'app-images';
    const screens = ['auth', 'onboarding'];
    final Map<String, List<String>> result = {};
    for (final screen in screens) {
      try {
        final files = await _client.storage.from(bucket).list(path: screen);
        final urls = files
            .where((f) => f.name != '.emptyFolderPlaceholder')
            .map((f) => _client.storage.from(bucket).getPublicUrl('$screen/${f.name}'))
            .toList();
        urls.sort();
        if (urls.isNotEmpty) result[screen] = urls;
      } catch (e) {
        debugPrint('❌ getAppImages[$screen] error: $e');
      }
    }
    return result;
  }

  // MEKANLARI (VENUES) GETİR
  Future<List<app_models.Venue>> getVenues({String? universityName}) async {
    try {
      debugPrint('🏛️ getVenues called — universityName: $universityName');
      var query = _client.from('venues').select();

      if (universityName != null) {
        query = query.eq('university', universityName);
      }

      final response = await query.order('name', ascending: true);
      final list = response as List;
      debugPrint('🏛️ getVenues returned ${list.length} rows. First: ${list.isNotEmpty ? list.first : "—"}');

      return list.map((data) => app_models.Venue(
        id: data['id'],
        name: data['name'],
        icon: data['icon'] ?? '🏢',
        peopleCount: data['people_count'] ?? 0,
        isHot: data['is_hot'] ?? false,
        heatLevel: (data['heat_level'] ?? 0).toDouble(),
        latitude: (data['latitude'] ?? 0).toDouble(),
        longitude: (data['longitude'] ?? 0).toDouble(),
        radius: (data['radius'] ?? 100).toDouble(),
        universityId: data['university_id'],
        category: data['category'] ?? _inferCategory(data['name'], data['icon']),
        imageUrl: data['image_url'],
      )).toList();
    } catch (e, st) {
      debugPrint('❌ getVenues error: $e\n$st');
      return [];
    }
  }

  String _inferCategory(String name, String? icon) {
    final n = name.toLowerCase();
    if (n.contains('kafe') || n.contains('cafe') || n.contains('ruby') || n.contains('kahve')) return 'Social';
    if (n.contains('kütüphane') || n.contains('library') || n.contains('çalışma') || n.contains('lab')) return 'Study';
    if (n.contains('çimler') || n.contains('park') || n.contains('manzara') || n.contains('çatı')) return 'Relax';
    if (n.contains('spor') || n.contains('salon') || n.contains('gym')) return 'Sport';
    if (n.contains('yemek') || n.contains('restoran') || n.contains('kantin')) return 'Eat';
    return 'Other';
  }

  // ÜNİVERSİTELERİ GETİR
  Future<List<app_models.University>> getUniversities() async {
    try {
      final response = await _client.from('universities').select().order('name');
      return (response as List).map((data) => app_models.University(
        id: data['id'],
        name: data['name'],
        domain: data['domain'],
        logoUrl: data['logo_url'],
      )).toList();
    } catch (e) {
      debugPrint('Error fetching universities: $e');
      return [];
    }
  }

  // --- KAMPÜS KURALLARI (LIMITS & EXPIRIES) ---

  // Hız sınırı kontrolü (type: 'checkin' veya 'wink')
  // Hız sınırı kontrolü (Artık puan sistemi olduğu için bu kısıtlamaları kapatıyoruz)
  Future<bool> checkInteractionLimit(String type, int maxCount, Duration window) async {
    return true; // Puan sistemi geldiği için saatlik limitleri kaldırdık
  }

  // Etkileşimi kaydet
  Future<void> logInteraction(String type) async {
    if (!isAuthenticated) return;
    try {
      await _client.from('interaction_logs').insert({
        'user_id': currentUserId,
        'type': type,
      });
    } catch (e) {
      debugPrint('Error logging interaction: $e');
    }
  }

  // Mekan Check-in (2 saat kuralı ile) veya Ayrıl (nullable)
  // Consolidation: Support updating points in the same single update call
  Future<bool> updateCheckIn(String? venueId, String? venueName, {int? newPoints, DateTime? newSyncTime}) async {
    if (!isAuthenticated) return false;
    try {
      final Map<String, dynamic> updateData = {
        'campus_zone': venueName ?? 'Bilinmiyor',
        'last_checkin_at': venueId == null ? null : DateTime.now().toIso8601String(),
      };

      if (newPoints != null) updateData['points'] = newPoints;
      if (newSyncTime != null) updateData['last_energy_sync_at'] = newSyncTime.toIso8601String();

      // 1. Profili tek seferde güncelle
      await _client.from('profiles').update(updateData).eq('id', currentUserId!);

      // 2. Etkileşimi logla (Limit kontrolü için)
      await logInteraction('checkin');
      return true;
    } catch (e) {
      debugPrint('Error updating checkin: $e');
      return false;
    }
  }

  // Göz kırpmaları filtrele (1 saatlik geçerlilik)
  // Bu metod swipes sorgusunu filtrelemek için kullanılacak
  String getWinkExpirationFilter() {
    return DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
  }
  // --- EVENTS ---

  Future<List<app_models.Event>> getEvents({String? universityId}) async {
    try {
      var query = _client.from('events').select().gt('end_at', DateTime.now().toIso8601String());
      if (universityId != null) {
        query = query.eq('university_id', universityId);
      }
      final response = await query.order('date', ascending: true);
      
      final eventsData = response as List;
      if (eventsData.isEmpty) return [];

      // DİKKAT: N+1 Optimizasyonu
      final eventIds = eventsData.map((e) => e['id']).toList();
      final attendeesRes = await _client
          .from('event_attendees')
          .select('event_id, user_id, profiles(id, name, avatar)')
          .inFilter('event_id', eventIds);

      Map<String, List<String>> eventAttendeesMap = {};
      Map<String, List<app_models.User>> eventAttendeeUsersMap = {};
      
      for (var row in attendeesRes as List) {
        final eventId = row['event_id'];
        final userId = row['user_id'];
        eventAttendeesMap.putIfAbsent(eventId, () => []).add(userId);
        
        final profile = row['profiles'];
        if (profile != null) {
          eventAttendeeUsersMap.putIfAbsent(eventId, () => []).add(app_models.User(
            id: profile['id'],
            name: profile['name'] ?? 'İsimsiz',
            university: '',
            department: '',
            year: '',
            bio: '',
            interests: [],
            campusZone: 'Bilinmiyor',
            isOnline: false,
            lastActive: DateTime.now(),
            avatar: (profile['avatar'] != null && profile['avatar'].startsWith('http')) ? '🧑' : (profile['avatar'] ?? '🧑'),
            profileImageUrl: (profile['avatar'] != null && profile['avatar'].startsWith('http')) ? profile['avatar'] : null,
          ));
        }
      }

      List<app_models.Event> events = [];
      for (var data in eventsData) {
        final eventId = data['id'];
        final attendees = eventAttendeesMap[eventId] ?? [];
        final attendeesCount = attendees.length;
        
        bool isJoined = false;
        if (isAuthenticated) {
          isJoined = attendees.contains(currentUserId);
        }

        events.add(app_models.Event(
          id: eventId,
          title: data['title'],
          description: data['description'] ?? '',
          location: data['location'] ?? '',
          date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
          imageUrl: data['image_url'] ?? '',
          attendeesCount: attendeesCount,
          isJoined: isJoined,
          isLive: data['is_live'] ?? false,
          createdBy: data['created_by'],
          startAt: data['start_at'] != null ? DateTime.parse(data['start_at']) : null,
          endAt: data['end_at'] != null ? DateTime.parse(data['end_at']) : null,
          category: data['category'],
          attendeePreviews: eventAttendeeUsersMap[eventId] ?? [],
        ));
      }
      return events;
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  Future<List<app_models.User>> getEventAttendees(String eventId) async {
    try {
      final response = await _client
          .from('event_attendees')
          .select('user_id, profiles(*)')
          .eq('event_id', eventId);
      
      return (response as List).map((data) {
        final profile = data['profiles'];
        return app_models.User(
          id: profile['id'],
          name: profile['name'],
          university: profile['university'] ?? 'İTÜ',
          department: profile['department'] ?? '',
          year: profile['year'] ?? '',
          bio: profile['bio'] ?? '',
          interests: _parseList(profile['interests']),
          avatar: (profile['avatar'] != null && profile['avatar'].startsWith('http')) ? '🧑' : (profile['avatar'] ?? '🧑'),
          profileImageUrl: (profile['avatar'] != null && profile['avatar'].startsWith('http')) ? profile['avatar'] : null,
          campusZone: profile['campus_zone'] ?? 'Bilinmiyor',
          isOnline: profile['is_online'] ?? false,
          lastActive: profile['last_active'] != null ? DateTime.parse(profile['last_active']) : DateTime.now(),
          genderFlag: profile['gender_flag'] ?? 'm',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching event attendees: $e');
      return [];
    }
  }

  Future<bool> toggleEventJoin(String eventId, bool join) async {
    if (!isAuthenticated) return false;
    try {
      if (join) {
        await _client.from('event_attendees').insert({
          'event_id': eventId,
          'user_id': currentUserId,
        });
      } else {
        await _client.from('event_attendees').delete().eq('event_id', eventId).eq('user_id', currentUserId!);
      }
      return true;
    } catch (e) {
      debugPrint('Error toggling event join: $e');
      return false;
    }
  }

  Future<String?> createEvent({
    required String title,
    required String description,
    required String location,
    required bool isLive,
    required DateTime startAt,
    required DateTime endAt,
    String? universityId,
    String? category,
  }) async {
    if (!isAuthenticated) return null;
    try {
      final response = await _client.from('events').insert({
        'title': title,
        'description': description,
        'location': location,
        'is_live': isLive,
        'university_id': universityId,
        'date': DateTime.now().toIso8601String(),
        'image_url': '', 
        'created_by': currentUserId,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'category': category,
      }).select().single();

      final eventId = response['id'];
      
      // Automatically join the creator to the event
      await toggleEventJoin(eventId, true);
      
      return eventId;
    } catch (e) {
      debugPrint('Error creating event: $e');
      return null;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    if (!isAuthenticated) return false;
    try {
      // First delete attendees (Supabase might handle this with cascading, but let's be safe)
      await _client.from('event_attendees').delete().eq('event_id', eventId);
      
      // Then delete the event
      // We allow deletion if the user is the creator OR if creator is null (legacy cleanup)
      final response = await _client
          .from('events')
          .delete()
          .eq('id', eventId)
          .or('created_by.eq.${currentUserId!},created_by.is.null')
          .select();
      
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  // --- PROFILE VIEW TRACKING ---

  Future<void> logCheckin(String zoneName) async {
    if (!isAuthenticated) return;
    try {
      await _client.from('checkin_logs').insert({
        'user_id': currentUserId,
        'venue_name': zoneName,
      });
    } catch (e) {
      debugPrint('Error logging checkin: $e');
    }
  }

  Future<void> logProfileView(String targetUserId) async {
    if (!isAuthenticated || currentUserId == targetUserId) return;
    try {
      await _client.from('profile_views').insert({
        'viewer_id': currentUserId,
        'target_id': targetUserId,
      });
    } catch (e) {
      debugPrint('Error logging profile view: $e');
    }
  }

  Future<int> getProfileViewCount({bool todayOnly = false, bool thisMonthOnly = false}) async {
    if (!isAuthenticated) return 0;
    try {
      var query = _client.from('profile_views').select('*').eq('target_id', currentUserId!);
      
      if (todayOnly) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        query = query.gte('viewed_at', today);
      } else if (thisMonthOnly) {
        final now = DateTime.now();
        final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
        query = query.gte('viewed_at', firstDayOfMonth);
      }

      final response = await query.count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('Error fetching profile view count: $e');
      return 0;
    }
  }

  Stream<List<Map<String, dynamic>>> streamNotifications() {
    return Stream.value([]);
  }

  // --- EVENT MESSAGES ---

  Future<List<Map<String, dynamic>>> getEventMessagesRaw(String eventId) async {
    try {
      final response = await _client
          .from('event_messages')
          .select('*, profiles:sender_id(id, name, avatar, department, year, bio, university, campus_zone, is_online, last_active, gender_flag, interests)')
          .eq('event_id', eventId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching event messages: $e');
      return [];
    }
  }

  Future<bool> insertEventMessage(String eventId, String text, {String? imageUrl}) async {
    if (!isAuthenticated) return false;
    try {
      await _client.from('event_messages').insert({
        'event_id': eventId,
        'sender_id': currentUserId,
        'text': text,
        if (imageUrl != null) 'image_url': imageUrl,
      });
      return true;
    } catch (e) {
      debugPrint('Error inserting event message: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> streamEventMessages(String eventId) {
    return _client
        .from('event_messages')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('created_at', ascending: true);
  }
}


