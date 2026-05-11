import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import 'notifications_screen.dart';
import 'other_profile_screen.dart';
import 'venue_detail_screen.dart';
import 'daily_quiz_screen.dart';
import '../widgets/match_celebration_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    final lastMatch = provider.lastNewMatch;

    final me = provider.currentUser;
    final isExpired = provider.isCheckinExpired;
    final isCheckedIn = !isExpired && me?.campusZone != null && me?.campusZone != 'Bilinmiyor';

    List<User> users = [];
    List<Venue> topVenues = [];

    if (isCheckedIn) {
      users = provider.getUsersAtVenue(me!.campusZone!);
    } else {
      topVenues = List<Venue>.from(provider.venues)..sort((a, b) => b.peopleCount.compareTo(a.peopleCount));
      topVenues = topVenues.take(10).toList();
    }

    return Scaffold(
      backgroundColor: Colors.black, // Deep dark background
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, provider),
              
              SliverToBoxAdapter(
                child: _buildLocationBar(context, provider, isCheckedIn),
              ),

              if (provider.currentUser?.quizCompleted == false)
                SliverToBoxAdapter(child: _buildDailyQuizCard(context)),

              SliverToBoxAdapter(
                child: _buildRadarVisualization(users, isCheckedIn ? _findCurrentVenue(provider, me?.campusZone) : null),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isCheckedIn ? 'RADARINDAKİLER' : 'EN POPÜLER MEKANLAR',
                        style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppTheme.accent),
                      ),
                      Text(
                        isCheckedIn ? '${users.length} KİŞİ' : '',
                        style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),

              if (isCheckedIn && users.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else if (isCheckedIn)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildRadarUserItem(context, users[index], index);
                      },
                      childCount: users.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildTopVenueItem(context, topVenues[index], index);
                      },
                      childCount: topVenues.length,
                    ),
                  ),
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 120)), // Bottom nav padding
            ],
          ),

          // Match Overlay
          if (lastMatch != null)
            MatchCelebrationOverlay(
              matchedUser: lastMatch,
              onDismiss: () => provider.clearLastMatch(),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppData provider) {
    final unreadCount = provider.notifications.where((n) => n.isNew).length;
    final me = provider.currentUser;

    return SliverAppBar(
      backgroundColor: Colors.black,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'EyeRadar',
        style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
      ),
      leading: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.accent.withOpacity(0.3))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.accent),
              const SizedBox(width: 2),
              Text('${me?.points ?? 0}', style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent)),
            ],
          ),
        ),
      ),
      leadingWidth: 80,
      actions: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppTheme.surface2, shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.white),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppTheme.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBar(BuildContext context, AppData provider, bool isCheckedIn) {
    final me = provider.currentUser;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showVenueSelector(context, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isCheckedIn ? AppTheme.accent.withOpacity(0.1) : AppTheme.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isCheckedIn ? AppTheme.accent.withOpacity(0.5) : Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCheckedIn ? me?.campusZone ?? 'Bilinmiyor' : 'Şu an Neredesin?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCheckedIn ? FontWeight.bold : FontWeight.normal,
                          color: isCheckedIn ? AppTheme.accent : Colors.white54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isCheckedIn ? AppTheme.accent : Colors.white38),
                  ],
                ),
              ),
            ),
          ),
          if (isCheckedIn) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Odadan Ayrıl', style: TextStyle(color: Colors.white, fontFamily: 'Cormorant Garamond', fontSize: 22, fontWeight: FontWeight.bold)),
                    content: Text(
                      '${me?.campusZone} mekanından ayrılmak istediğine emin misin?',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hayır', style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Ayrıl', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) provider.leaveVenue();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.red.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: AppTheme.red),
                    SizedBox(width: 6),
                    Text('Ayrıl', style: TextStyle(fontFamily: 'Space Mono', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.red)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showVenueSelector(BuildContext context, AppData provider) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Şu an Neredesin?', style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: provider.venues.length,
                itemBuilder: (context, index) {
                  final venue = provider.venues[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        provider.checkIn(venue);
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: venue.imageUrl != null && venue.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      venue.imageUrl!,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _venueFallback(52),
                                    )
                                  : _venueFallback(52),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(venue.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  Text('${venue.peopleCount} Kişi', style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white54)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyQuizCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyQuizScreen()));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.accent.withOpacity(0.2), AppTheme.accent.withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              child: const Icon(Icons.psychology_rounded, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Günün Sorusunu Çöz', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('+5 PWR Kazan', style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: AppTheme.accent)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.accent),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Venue? _findCurrentVenue(AppData provider, String? campusZone) {
    if (campusZone == null || provider.venues.isEmpty) return null;
    try {
      return provider.venues.firstWhere((v) => v.name == campusZone);
    } catch (_) {
      return null;
    }
  }

  Widget _buildRadarVisualization(List<User> users, Venue? currentVenue) {
    final hasPhoto = currentVenue?.imageUrl != null && currentVenue!.imageUrl!.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.35,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [

          // ── Layer 1: Venue photo clipped to circle (background) ──
          if (hasPhoto)
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(currentVenue!.imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // ── Layer 2: Dark vignette over photo so radar is visible ──
          if (hasPhoto)
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.75),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),

          // ── Layer 3: Concentric radar rings ──
          ...List.generate(3, (index) {
            final size = (index + 1) * 100.0;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accent.withOpacity(hasPhoto ? 0.35 + (0.1 * (3 - index)) : 0.1 + (0.05 * (3 - index))),
                  width: 1.5,
                ),
              ),
            );
          }),

          // ── Layer 4: Radar sweep scanner ──
          AnimatedBuilder(
            animation: _radarController,
            builder: (_, __) {
              return Transform.rotate(
                angle: _radarController.value * 2 * math.pi,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        AppTheme.accent.withOpacity(0.05),
                        AppTheme.accent.withOpacity(hasPhoto ? 0.6 : 0.4),
                      ],
                      stops: const [0.0, 0.8, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Layer 5: Outer border ring ──
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent.withOpacity(0.4), width: 1.5),
            ),
          ),

          // ── Layer 6: Floating user avatars ──
          if (users.isNotEmpty)
            ...List.generate(math.min(users.length, 6), (index) {
              final user = users[index];
              final angle = (index * (math.pi * 2 / math.min(users.length, 6))) + (math.pi / 4);
              final distance = 70.0 + (index % 3) * 30.0;
              final offsetX = math.cos(angle) * distance;
              final offsetY = math.sin(angle) * distance;

              return Transform.translate(
                offset: Offset(offsetX, offsetY),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OtherProfileScreen(user: user)));
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54, width: 1.5),
                      image: user.profileImageUrl != null
                          ? DecorationImage(image: user.profileImageUrl!.startsWith('http') ? NetworkImage(user.profileImageUrl!) as ImageProvider : FileImage(File(user.profileImageUrl!)), fit: BoxFit.cover)
                          : null,
                      color: AppTheme.surface3,
                    ),
                    alignment: Alignment.center,
                    child: user.profileImageUrl == null ? Text(user.avatar, style: const TextStyle(fontSize: 20)) : null,
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    delay: (index * 200).ms, duration: 1.5.seconds, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)
                  ),
                ),
              );
            }),

          // ── Layer 7: Center location icon (top) ──
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.7),
              border: Border.all(color: AppTheme.accent, width: 2),
              boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.6), blurRadius: 16)],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.radar, color: AppTheme.accent, size: 20),
          ),
        ],
      ).animate().fadeIn(duration: 800.ms),
    );

  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.radar_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 24),
          const Text(
            'RADARINDA KİMSE YOK',
            style: TextStyle(fontFamily: 'Space Mono', fontSize: 12, letterSpacing: 2, color: Colors.white54, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir mekana gitmeyi dene.',
            style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white24),
          ),
        ],
      ).animate().fadeIn(delay: 300.ms),
    );
  }

  Widget _buildRadarUserItem(BuildContext context, User user, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => OtherProfileScreen(user: user)));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface3,
                      border: Border.all(color: Colors.white24),
                      image: user.profileImageUrl != null
                          ? DecorationImage(
                              image: user.profileImageUrl!.startsWith('http')
                                  ? NetworkImage(user.profileImageUrl!) as ImageProvider
                                  : FileImage(File(user.profileImageUrl!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: user.profileImageUrl == null ? Text(user.avatar, style: const TextStyle(fontSize: 24)) : null,
                  ),
                  if (user.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: const Color(0xFF4CAF50), shape: BoxShape.circle, border: Border.all(color: AppTheme.surface2, width: 2)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(user.department, style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white54)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Text('${user.points}', style: const TextStyle(fontFamily: 'Space Mono', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                    const Icon(Icons.bolt_rounded, size: 12, color: AppTheme.accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildTopVenueItem(BuildContext context, Venue venue, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: venue)));
        },
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
              // Venue photo – same width/height as the card height
              SizedBox(
                width: 80,
                height: 80,
                child: venue.imageUrl != null && venue.imageUrl!.isNotEmpty
                    ? Image.network(
                        venue.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _venueFallback(80),
                      )
                    : _venueFallback(80),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(venue.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text('${venue.peopleCount} Kişi', style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Text('GİT', style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _venueFallback(double size) {
    return Container(
      width: size,
      height: size,
      color: AppTheme.surface3,
      child: const Icon(Icons.location_city_rounded, color: Colors.white10, size: 28),
    );
  }
}
