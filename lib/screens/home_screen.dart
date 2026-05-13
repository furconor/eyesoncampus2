import 'dart:async';
import 'dart:io';
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  final TextEditingController _radarSearchCtrl = TextEditingController();
  bool _radarSearchVisible = false;
  String _radarSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _radarSearchCtrl.addListener(() {
      setState(() {
        _radarSearchQuery = _radarSearchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _radarSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    final lastMatch = provider.lastNewMatch;

    final me = provider.currentUser;
    final isExpired = provider.isCheckinExpired;
    final isCheckedIn =
        !isExpired && me?.campusZone != null && me?.campusZone != 'Bilinmiyor';

    List<User> users = [];
    List<Venue> topVenues = [];

    if (isCheckedIn) {
      users = provider.getUsersAtVenue(me!.campusZone!);
    } else {
      topVenues = List<Venue>.from(provider.venues)
        ..sort((a, b) => b.peopleCount.compareTo(a.peopleCount));
      topVenues = topVenues.take(10).toList();
    }

    final filteredRadarUsers = _radarSearchQuery.isEmpty
        ? users
        : users.where((user) {
            final searchable =
                '${user.name} ${user.department}'.toLowerCase();
            return searchable.contains(_radarSearchQuery);
          }).toList();
    final radarCountText = _radarSearchQuery.isEmpty
        ? '${users.length} KİŞİ'
        : '${filteredRadarUsers.length}/${users.length}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(context, provider),
              SliverToBoxAdapter(
                child: _buildLocationBar(context, provider, isCheckedIn),
              ),
              if (provider.currentUser?.quizCompleted == false)
                SliverToBoxAdapter(child: _buildDailyQuizCard(context)),
              if (isCheckedIn) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 72),
                    child: _buildRadarVisualization(
                      users, provider.venues.firstWhere(
                        (v) => v.name == me?.campusZone,
                        orElse: () => provider.venues.isNotEmpty ? provider.venues.first : Venue(id: '', name: me?.campusZone ?? '', icon: '📍', peopleCount: users.length, heatLevel: 0.5),
                      )),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 78),
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // RADARINDAKİLER header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('RADARINDAKİLER',
                                style: TextStyle(
                                    fontFamily: 'Space Mono',
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent)),
                            if (_radarSearchVisible) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _radarSearchCtrl,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  cursorColor: AppTheme.accent,
                                  decoration: const InputDecoration(
                                    hintText: 'Kullanıcı ara',
                                    hintStyle: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ] else
                              const Spacer(),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _radarSearchVisible = !_radarSearchVisible;
                                      if (!_radarSearchVisible) {
                                        _radarSearchCtrl.clear();
                                      }
                                    });
                                  },
                                  child: Icon(
                                    _radarSearchVisible
                                        ? Icons.close_rounded
                                        : Icons.search_rounded,
                                    size: 20,
                                    color: const Color(0xFFFFD700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.accent.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Text(radarCountText,
                                      style: const TextStyle(
                                          fontFamily: 'Space Mono',
                                          fontSize: 9,
                                          color: AppTheme.accent)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Content
                      if (users.isEmpty)
                        const SizedBox(
                          height: 134,
                          child: Center(
                            child: Text(
                            'RADARINDA KİMSE YOK',
                            style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 11,
                                color: Colors.white24,
                                letterSpacing: 2),
                            ),
                          ),
                        )
                      else if (filteredRadarUsers.isEmpty)
                        const SizedBox(
                          height: 134,
                          child: Center(
                            child: Text(
                            'KULLANICI BULUNAMADI',
                            style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 10,
                                color: Colors.white38,
                                letterSpacing: 1.5),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 134,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredRadarUsers.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final user = filteredRadarUsers[index];
                              return SizedBox(
                                width: 96,
                                child: _RadarUserCard(
                                  user: user,
                                  index: index,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          OtherProfileScreen(user: user),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  ),
                ),
              ] else ...[
                // ── Checked-out: Radar (statik) ──
                SliverToBoxAdapter(
                  child: _buildRadarVisualization([], null),
                ),

                // ── EN POPÜLER MEKANLAR başlığı ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('EN POPÜLER MEKANLAR',
                            style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 10,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent)),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildTopVenueItem(context, topVenues[index], index),
                      childCount: topVenues.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          ),
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
  } // end build()

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
        style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1),
      ),
      leading: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.accent),
              const SizedBox(width: 2),
              Text('${me?.points ?? 0}',
                  style: const TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent)),
            ],
          ),
        ),
      ),
      leadingWidth: 80,
      actions: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppTheme.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded,
                    size: 20, color: Colors.white),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppTheme.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBar(
      BuildContext context, AppData provider, bool isCheckedIn) {
    final me = provider.currentUser;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showVenueSelector(context, provider),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? AppTheme.accent.withOpacity(0.1)
                      : AppTheme.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isCheckedIn
                          ? AppTheme.accent.withOpacity(0.5)
                          : Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isCheckedIn)
                            const Text(
                              'Şu anda buradasın:',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54,
                                  fontFamily: 'Space Mono'),
                            ),
                          Text(
                            isCheckedIn
                                ? me?.campusZone ?? 'Bilinmiyor'
                                : 'Neredeyim?',
                            style: TextStyle(
                              fontSize: isCheckedIn ? 16 : 14,
                              fontWeight: isCheckedIn
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCheckedIn
                                  ? AppTheme.accent
                                  : Colors.white54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: isCheckedIn ? AppTheme.accent : Colors.white38),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Odadan Ayrıl',
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cormorant Garamond',
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    content: Text(
                      '${me?.campusZone} mekanından ayrılmak istediğine emin misin?',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hayır',
                            style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Ayrıl',
                            style: TextStyle(
                                color: AppTheme.red,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) provider.leaveVenue();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.red.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: AppTheme.red),
                    SizedBox(width: 6),
                    Text('Ayrıl',
                        style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.red)),
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
      builder: (context) {
        String? _loadingId;
        final sheetCtx = context;
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Şu an Neredesin?',
                      style: TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: provider.venues.length,
                    itemBuilder: (context, index) {
                      // Active venue always first
                      final sorted = [
                        ...provider.venues.where(
                            (v) => v.name == provider.currentUser?.campusZone),
                        ...provider.venues.where(
                            (v) => v.name != provider.currentUser?.campusZone),
                      ];
                      final venue = sorted[index];
                      final isLoading = _loadingId == venue.id;
                      final isActive =
                          provider.currentUser?.campusZone == venue.name;
                      final hasActiveVenue =
                          provider.currentUser?.campusZone != null &&
                              provider.venues.any((v) =>
                                  v.name == provider.currentUser?.campusZone);
                      final showDivider = hasActiveVenue && index == 1;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDivider)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                              child: Text(
                                'Mekan Değiştir',
                                style: TextStyle(
                                  fontFamily: 'Cormorant Garamond',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: Colors.white10, width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                // Left: navigate to venue detail
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pop(context);
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => VenueDetailScreen(
                                                  venue: venue)));
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: venue.imageUrl != null &&
                                                    venue.imageUrl!.isNotEmpty
                                                ? Image.network(
                                                    venue.imageUrl!,
                                                    width: 52,
                                                    height: 52,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            _venueFallback(52),
                                                  )
                                                : _venueFallback(52),
                                          ),
                                          const SizedBox(width: 14),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(venue.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 15)),
                                              const SizedBox(height: 3),
                                              Text('${venue.peopleCount} Kişi',
                                                  style: const TextStyle(
                                                      fontFamily: 'Space Mono',
                                                      fontSize: 10,
                                                      color: Colors.white54)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Right: check-in button (inactive if already here)
                                GestureDetector(
                                  onTap: isActive || isLoading
                                      ? null
                                      : () async {
                                          HapticFeedback.mediumImpact();
                                          setSheetState(
                                              () => _loadingId = venue.id);
                                          final errorMsg =
                                              await provider.checkIn(venue);
                                          if (!sheetCtx.mounted) return;
                                          if (errorMsg != null) {
                                            setSheetState(
                                                () => _loadingId = null);
                                            if (errorMsg.contains('enerjin')) {
                                              Navigator.pop(sheetCtx);
                                              showDialog(
                                                context: sheetCtx,
                                                builder: (ctx) => AlertDialog(
                                                  backgroundColor:
                                                      AppTheme.surface,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              24)),
                                                  title: const Column(
                                                    children: [
                                                      Icon(Icons.bolt_rounded,
                                                          color:
                                                              AppTheme.accent,
                                                          size: 48),
                                                      SizedBox(height: 16),
                                                      Text('Enerjin Bitti!',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontFamily:
                                                                  'Cormorant Garamond',
                                                              fontSize: 28,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ],
                                                  ),
                                                  content: const Text(
                                                    'Mekan değiştirmek için yeterli enerjin kalmadı. Enerjinin dolmasını bekleyebilir veya kampüs etkinliklerine katılarak enerji kazanabilirsin.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 14,
                                                        height: 1.5),
                                                  ),
                                                  actions: [
                                                    Center(
                                                      child: TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        style: TextButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              AppTheme.surface2,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      24,
                                                                  vertical: 12),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12)),
                                                        ),
                                                        child: const Text(
                                                            'Anladım',
                                                            style: TextStyle(
                                                                color: AppTheme
                                                                    .accent,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontFamily:
                                                                    'Space Mono')),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(sheetCtx)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(errorMsg),
                                                      backgroundColor:
                                                          AppTheme.red));
                                            }
                                          } else {
                                            Navigator.pop(sheetCtx);
                                            _showToast(sheetCtx,
                                                icon: '⚡',
                                                title:
                                                    '${venue.name}\'e geçtin  −1 ⚡',
                                                borderColor: AppTheme.accent,
                                                dopamine: true);
                                          }
                                        },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(left: 10),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isActive ? 14 : 12,
                                      vertical: isActive ? 10 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLoading
                                          ? AppTheme.accent.withOpacity(0.9)
                                          : isActive
                                              ? AppTheme.accent
                                              : AppTheme.accent
                                                  .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(
                                          isActive ? 14 : 12),
                                      border: Border.all(
                                        color: isActive || isLoading
                                            ? AppTheme.accent
                                            : AppTheme.accent.withOpacity(0.35),
                                        width: isActive ? 0 : 1,
                                      ),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                  color: AppTheme.accent
                                                      .withOpacity(0.35),
                                                  blurRadius: 10,
                                                  spreadRadius: 1)
                                            ]
                                          : null,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 42,
                                            height: 14,
                                            child: Center(
                                              child: SizedBox(
                                                width: 12,
                                                height: 12,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.black),
                                              ),
                                            ),
                                          )
                                        : isActive
                                            ? const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons.location_on_rounded,
                                                      size: 11,
                                                      color: Colors.black),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'BURADASIN',
                                                    style: TextStyle(
                                                      fontFamily: 'Space Mono',
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const Text(
                                                'GİT',
                                                style: TextStyle(
                                                  fontFamily: 'Space Mono',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.accent,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyQuizCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DailyQuizScreen()));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppTheme.accent.withOpacity(0.2),
            AppTheme.accent.withOpacity(0.05)
          ]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: AppTheme.accent, shape: BoxShape.circle),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.black, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Günün Sorusunu Çöz',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: 4),
                  Text('+5 PWR Kazan',
                      style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 10,
                          color: AppTheme.accent)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppTheme.accent),
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
    final hasPhoto =
        currentVenue?.imageUrl != null && currentVenue!.imageUrl!.isNotEmpty;
    const radarSize = 330.0;

    return SizedBox(
      width: radarSize,
      height: radarSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Layer 1: Venue photo clipped to circle (background) ──
          if (hasPhoto)
            Container(
              width: radarSize,
              height: radarSize,
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
              width: radarSize,
              height: radarSize,
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
          ...List.generate(2, (index) {
            final size = (index + 1) * 105.0;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accent.withOpacity(hasPhoto
                      ? 0.35 + (0.1 * (3 - index))
                      : 0.1 + (0.05 * (3 - index))),
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
                  width: radarSize,
                  height: radarSize,
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
            width: radarSize,
            height: radarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.accent.withOpacity(0.4), width: 1.5),
            ),
          ),

          // ── Layer 6: Floating user avatars ──
          if (users.isNotEmpty)
            ...List.generate(math.min(users.length, 6), (index) {
              final user = users[index];
              final angle =
                  (index * (math.pi * 2 / math.min(users.length, 6))) +
                      (math.pi / 4);
              final distance = 75.0 + (index % 3) * 30.0;
              final offsetX = math.cos(angle) * distance;
              final offsetY = math.sin(angle) * distance;
              // Kenara yakınsa küçül: 70px→44, 130px→30
              final avatarSize =
                  (44.0 - (distance - 70.0) / 60.0 * 14.0).clamp(30.0, 44.0);
              // Kenara yakınsa gölge opaklığı artar: 70px→0.0, 130px→0.45
              final shadowOpacity =
                  ((distance - 70.0) / 60.0 * 0.45).clamp(0.0, 0.45);
              final firstName = user.name.split(' ').first;

              return Transform.translate(
                offset: Offset(offsetX, offsetY),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OtherProfileScreen(user: user)));
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white54, width: 1.5),
                              image: user.profileImageUrl != null
                                  ? DecorationImage(
                                      image: user.profileImageUrl!
                                              .startsWith('http')
                                          ? NetworkImage(user.profileImageUrl!)
                                              as ImageProvider
                                          : FileImage(
                                              File(user.profileImageUrl!)),
                                      fit: BoxFit.cover)
                                  : null,
                              color: AppTheme.surface3,
                            ),
                            alignment: Alignment.center,
                            child: user.profileImageUrl == null
                                ? Text(user.avatar,
                                    style:
                                        TextStyle(fontSize: avatarSize * 0.45))
                                : null,
                          ),
                          // Kenar gölgesi
                          if (shadowOpacity > 0)
                            Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(shadowOpacity),
                              ),
                            ),
                        ],
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                            delay: (index * 200).ms,
                            duration: 1.5.seconds,
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.1, 1.1),
                          ),
                      const SizedBox(height: 3),
                      Text(
                        firstName,
                        style: TextStyle(
                          fontSize: avatarSize * 0.22,
                          color: Colors.white.withOpacity(0.75),
                          fontFamily: 'Space Mono',
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          // ── Layer 7: Center location icon + venue name ──
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.7),
                  border: Border.all(color: AppTheme.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.accent.withOpacity(0.6), blurRadius: 16)
                  ],
                ),
                alignment: Alignment.center,
                child:
                    const Icon(Icons.radar, color: AppTheme.accent, size: 20),
              ),
              if (currentVenue != null) ...[
                const SizedBox(height: 4),
                Text(
                  currentVenue.name,
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppTheme.accent,
                    fontFamily: 'Space Mono',
                    letterSpacing: 0.5,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
              ],
            ],
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
            style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 12,
                letterSpacing: 2,
                color: Colors.white54,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir mekana gitmeyi dene.',
            style: TextStyle(
                fontFamily: 'Space Mono', fontSize: 10, color: Colors.white24),
          ),
        ],
      ).animate().fadeIn(delay: 300.ms),
    );
  }

  Widget _buildTopVenueItem(BuildContext context, Venue venue, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => VenueDetailScreen(venue: venue)));
        },
        child: Container(
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
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
                      Text(venue.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 12, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text('${venue.peopleCount} Kişi',
                              style: const TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontSize: 10,
                                  color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('GİT',
                        style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
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
      child: const Icon(Icons.location_city_rounded,
          color: Colors.white10, size: 28),
    );
  }
}

// ─── Radar user card with long-press dopamine interaction ──────────────────

void _showToast(
  BuildContext ctx, {
  required String icon,
  required String title,
  String? subtitle,
  required Color borderColor,
  bool dopamine = false,
}) {
  ScaffoldMessenger.of(ctx)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor.withOpacity(0.55), width: 1.2),
          boxShadow: [
            BoxShadow(
              color:
                  dopamine ? AppTheme.accent.withOpacity(0.28) : Colors.black54,
              blurRadius: dopamine ? 22 : 14,
              spreadRadius: dopamine ? 2 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.2)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2800),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      padding: EdgeInsets.zero,
    ));
}

class _Particle {
  final int id;
  final String emoji;
  final double dx;
  _Particle({required this.id, required this.emoji, required this.dx});
}

class _RadarUserCard extends StatefulWidget {
  final User user;
  final int index;
  final VoidCallback onTap;

  const _RadarUserCard({
    required this.user,
    required this.index,
    required this.onTap,
  });

  @override
  State<_RadarUserCard> createState() => _RadarUserCardState();
}

class _RadarUserCardState extends State<_RadarUserCard>
    with TickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late AnimationController _pulseCtrl;
  bool _isPressed = false;
  bool _isCompleted = false;
  bool _showWink = false;
  final List<_Particle> _particles = [];
  int _particleId = 0;
  Timer? _hapticTimer;
  Timer? _particleTimer;
  late BuildContext _ctx;

  static const _emojis = ['⚡', '🔥', '✨', '💫', '⭐', '🌟'];
  static const _burst = [
    '🎉',
    '💥',
    '⚡',
    '🔥',
    '✨',
    '💫',
    '🌟',
    '❤️‍🔥',
    '👀',
    '😍'
  ];

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onCompleted();
      });
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    _hapticTimer?.cancel();
    _particleTimer?.cancel();
    super.dispose();
  }

  void _start(LongPressStartDetails _) {
    final provider = Provider.of<AppData>(_ctx, listen: false);

    if (provider.hasSentInterest(widget.user.id)) {
      HapticFeedback.lightImpact();
      _showToast(
        _ctx,
        icon: '😏',
        title: 'Zaten göz kırptın!',
        subtitle: 'Bu kişiye bir kez gönderebilirsin.',
        borderColor: Colors.white24,
      );
      return;
    }

    final cost = provider.nextWinkCost;
    if ((provider.currentUser?.points ?? 0) < cost) {
      HapticFeedback.lightImpact();
      _showToast(
        _ctx,
        icon: '⚡',
        title: 'Enerji yetmez!',
        subtitle: 'Bu göz kırpma $cost enerji götürür.',
        borderColor: const Color(0xFFFF6B6B),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isPressed = true;
      _isCompleted = false;
      _showWink = false;
      _particles.clear();
    });
    _progressCtrl.forward(from: 0);

    _hapticTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) HapticFeedback.selectionClick();
    });
    _particleTimer = Timer.periodic(const Duration(milliseconds: 160), (_) {
      if (!mounted) return;
      final rand = math.Random();
      setState(() {
        _particles.add(_Particle(
          id: _particleId++,
          emoji: _emojis[rand.nextInt(_emojis.length)],
          dx: (rand.nextDouble() - 0.5) * 60,
        ));
        if (_particles.length > 7) _particles.removeAt(0);
      });
    });
  }

  void _end(LongPressEndDetails _) {
    if (!_isCompleted) _cancel();
  }

  void _cancel() {
    _hapticTimer?.cancel();
    _particleTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isPressed = false;
      _particles.clear();
    });
    _progressCtrl.reverse();
  }

  void _onCompleted() {
    _hapticTimer?.cancel();
    _particleTimer?.cancel();

    HapticFeedback.heavyImpact();
    Future.delayed(120.ms, () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    Future.delayed(250.ms, () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    Future.delayed(400.ms, () {
      if (mounted) HapticFeedback.vibrate();
    });

    final rand = math.Random();
    setState(() {
      _isCompleted = true;
      _showWink = true;
      _particles.clear();
      for (int i = 0; i < 10; i++) {
        _particles.add(_Particle(
          id: _particleId++,
          emoji: _burst[i % _burst.length],
          dx: (rand.nextDouble() - 0.5) * 90,
        ));
      }
    });

    Provider.of<AppData>(_ctx, listen: false)
        .sendInterest(widget.user.id)
        .then((error) {
      if (!mounted) return;
      if (error != null) {
        _showToast(
          _ctx,
          icon: '😅',
          title: 'Bir sorun çıktı',
          subtitle: error,
          borderColor: Colors.white24,
        );
      } else {
        _showToast(
          _ctx,
          icon: '😉',
          title: 'Göz kırptın!  −1 ⚡',
          borderColor: AppTheme.accent,
          dopamine: true,
        );
      }
    });

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _isPressed = false;
        _isCompleted = false;
        _showWink = false;
        _particles.clear();
      });
      _progressCtrl.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    _ctx = context;
    final provider = Provider.of<AppData>(context);
    final alreadyWinked = provider.hasSentInterest(widget.user.id);
    final winkCost = provider.nextWinkCost;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onLongPressStart: _start,
      onLongPressEnd: _end,
      onLongPressCancel: _cancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_progressCtrl, _pulseCtrl]),
        builder: (context, _) => _buildCard(alreadyWinked, winkCost),
      ),
    );
  }

  Widget _buildCard(bool alreadyWinked, int winkCost) {
    final p = _progressCtrl.value;
    final glow = _isPressed ? (0.3 + 0.12 * _pulseCtrl.value) * p : 0.0;
    final nameParts = widget.user.name.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.length > 1
        ? nameParts.take(nameParts.length - 1).join(' ')
        : widget.user.name;
    final secondPart =
        nameParts.length > 1 ? nameParts.last : widget.user.department;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: _isCompleted
                  ? const Color(0xFF1F1A0D)
                  : const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isPressed
                    ? AppTheme.accent.withOpacity(0.5 + 0.5 * p)
                    : alreadyWinked
                        ? AppTheme.accent.withOpacity(0.32)
                        : Colors.white.withOpacity(0.14),
                width: _isPressed ? 1.5 : 1.2,
              ),
              boxShadow: glow > 0
                  ? [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(glow),
                        blurRadius: 18 * p,
                        spreadRadius: 1 * p,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      )
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                _buildAvatar(alreadyWinked),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    firstName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFECECEC),
                      height: 1.05,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    secondPart,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0x73FFFFFF),
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.user.isOnline)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surface3, width: 1.5),
              ),
            ),
          ),
        ..._particles.map(_buildParticle),
      ],
    );
  }

  Widget _buildAvatar(bool alreadyWinked) {
    final p = _progressCtrl.value;
    const double size = 62;
    const double innerSize = 54;
    const avatarBlue = Color(0xFF0058A8);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_showWink)
            Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface3,
                border: Border.all(color: AppTheme.accent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.5),
                    blurRadius: 14,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('😉', style: TextStyle(fontSize: 26)),
            ).animate().scale(
                  begin: const Offset(1.4, 1.4),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                )
          else
            Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface3,
                border: Border.all(
                  color: _isPressed
                      ? Colors.transparent
                      : alreadyWinked
                          ? avatarBlue.withOpacity(0.48)
                          : avatarBlue,
                  width: 3,
                ),
                image: widget.user.profileImageUrl != null
                    ? DecorationImage(
                        image: widget.user.profileImageUrl!.startsWith('http')
                            ? NetworkImage(widget.user.profileImageUrl!)
                                as ImageProvider
                            : FileImage(File(widget.user.profileImageUrl!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: widget.user.profileImageUrl == null
                  ? Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name[0].toUpperCase()
                          : widget.user.avatar,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          if (_isPressed)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: _isCompleted ? 1.0 : p,
                strokeWidth: 3,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isCompleted
                      ? Colors.greenAccent
                      : Color.lerp(avatarBlue, Colors.greenAccent, p)!,
                ),
                strokeCap: StrokeCap.round,
              ),
            ),
          if (alreadyWinked && !_isPressed && !_showWink)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('👁️', style: TextStyle(fontSize: 9)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticle(_Particle particle) {
    final left = (50.0 + particle.dx - 8).clamp(-30.0, 130.0);
    return Positioned(
      key: ValueKey(particle.id),
      left: left,
      top: 5,
      child: IgnorePointer(
        child: Text(particle.emoji, style: const TextStyle(fontSize: 16))
            .animate()
            .moveY(begin: 0, end: -85, duration: 950.ms, curve: Curves.easeOut)
            .fadeOut(duration: 850.ms)
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1.1, 1.1),
              duration: 350.ms,
            ),
      ),
    );
  }
}
