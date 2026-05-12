import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'other_profile_screen.dart';
import 'package:eyesoncampus/widgets/point_notification_overlay.dart';
import '../widgets/glass_container.dart';

class VenueDetailScreen extends StatefulWidget {
  final Venue venue;

  const VenueDetailScreen({super.key, required this.venue});

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  bool _isCheckingIn = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    final me = provider.currentUser;
    final isReviewer = me?.name == 'Apple Reviewer';
    List<User> usersInVenue = provider.getUsersAtVenue(widget.venue.name);
    
    final isCheckedIn = provider.currentUser?.campusZone == widget.venue.name;

    return Scaffold(
      backgroundColor: Colors.black, // Dark premium background
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, isCheckedIn, usersInVenue.length),
          SliverToBoxAdapter(
            child: _buildVenueInfo(provider, usersInVenue),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
            sliver: SliverToBoxAdapter(
              child: const Text(
                'ŞU AN BURADAKİLER',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ).animate().fadeIn(delay: 300.ms),
            ),
          ),
          _buildUsersList(context, usersInVenue, isCheckedIn),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for bottom action
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildBottomAction(context, provider, isCheckedIn),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isCheckedIn, int userCount) {
    final Color heatColor = userCount > 10 ? Colors.orange : AppTheme.accent;

    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.45,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.venue.imageUrl != null)
              Image.network(widget.venue.imageUrl!, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 0),
                    radius: 1.2,
                    colors: [AppTheme.accent.withOpacity(0.3), Colors.black],
                  ),
                ),
              ),
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
            // Central glowing icon
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                  color: Colors.black.withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(color: heatColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 5),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Center(
                      child: Icon(Icons.location_on_rounded, color: heatColor, size: 40),
                    ),
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                duration: 2.seconds,
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueInfo(AppData provider, List<User> users) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.venue.name,
            style: const TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
              height: 1.1,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                ).animate(onPlay: (c) => c.repeat()).fade(duration: 1.seconds, begin: 0.3, end: 1),
                const SizedBox(width: 8),
                Text(
                  '${users.length} KİŞİ İÇERİDE',
                  style: const TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildUsersList(BuildContext context, List<User> users, bool isCheckedIn) {
    if (users.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.person_off_rounded, size: 48, color: Colors.white24),
                const SizedBox(height: 16),
                const Text(
                  'ŞU AN KİMSE YOK',
                  style: TextStyle(fontFamily: 'Space Mono', color: Colors.white54, fontSize: 12, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 400.ms),
      );
    }

    // Sort: online first, then by points
    final sortedUsers = List<User>.from(users)..sort((a, b) {
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return b.points.compareTo(a.points);
    });

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final user = sortedUsers[index];
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OtherProfileScreen(user: user)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
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
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: user.genderFlag == 'f' ? AppTheme.red.withOpacity(0.3) : AppTheme.blue.withOpacity(0.3),
                              width: 1.5,
                            ),
                            color: AppTheme.surface3,
                            image: user.profileImageUrl != null
                                ? DecorationImage(
                                    image: user.profileImageUrl!.startsWith('http')
                                        ? NetworkImage(user.profileImageUrl!) as ImageProvider
                                        : FileImage(File(user.profileImageUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            gradient: user.profileImageUrl == null ? LinearGradient(
                              colors: user.genderFlag == 'f'
                                  ? [const Color(0x33FF6B9D), const Color(0x22FF4D6D)]
                                  : [const Color(0x334D9FFF), const Color(0x222266CC)],
                            ) : null,
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
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.surface2, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.department,
                            style: const TextStyle(fontFamily: 'Space Mono', color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (400 + (index * 50)).ms).slideX(begin: 0.1, end: 0);
          },
          childCount: sortedUsers.length,
        ),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, AppData provider, bool isCheckedIn) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _isCheckingIn ? null : () async {
          HapticFeedback.mediumImpact();
          setState(() => _isCheckingIn = true);
          
          String? error;
          if (isCheckedIn) {
            error = await provider.leaveVenue();
          } else {
            error = await provider.checkIn(widget.venue);
          }
          
          if (mounted) {
            setState(() => _isCheckingIn = false);
            if (error != null) {
              if (error.contains('enerjin')) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: const Column(
                      children: [
                        Icon(Icons.bolt_rounded, color: AppTheme.accent, size: 48),
                        SizedBox(height: 16),
                        Text('Enerjin Bitti!', style: TextStyle(color: Colors.white, fontFamily: 'Cormorant Garamond', fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    content: const Text(
                      'Mekan değiştirmek için yeterli enerjin (PWR) kalmadı. Enerjinin dolmasını bekleyebilir veya kampüs etkinliklerine katılarak enerji kazanabilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                    actions: [
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: AppTheme.surface2,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Anladım', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontFamily: 'Space Mono')),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.red));
              }
            } else {
              if (!isCheckedIn) {
                showPointOverlay(context, -1, 'Mekana Giriş');
              }
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: isCheckedIn ? AppTheme.surface2 : AppTheme.accent,
            borderRadius: BorderRadius.circular(20),
            border: isCheckedIn ? Border.all(color: AppTheme.red.withOpacity(0.5), width: 1.5) : null,
            boxShadow: isCheckedIn ? null : [
              BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: _isCheckingIn
                ? SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(color: isCheckedIn ? AppTheme.red : Colors.black, strokeWidth: 3),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCheckedIn ? 'MEKANDAN AYRIL' : 'BURADAYIM',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCheckedIn ? AppTheme.red : Colors.black,
                          letterSpacing: 2,
                        ),
                      ),
                      if (!isCheckedIn) ...[
                        const SizedBox(width: 6),
                        const Text('−1', style: TextStyle(fontFamily: 'Space Mono', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                        const Icon(Icons.bolt, color: Colors.black54, size: 16),
                      ],
                    ],
                  ),
          ),
        ),
      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.5, end: 0),
    );
  }
}
