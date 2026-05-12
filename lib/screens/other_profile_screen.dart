import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../models/user_model.dart';
import '../screens/chat_detail_screen.dart';
import '../widgets/point_notification_overlay.dart';

class OtherProfileScreen extends StatefulWidget {
  final User user;

  const OtherProfileScreen({super.key, required this.user});

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppData>(context, listen: false);
      provider.logProfileVisit(widget.user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppData>(
      builder: (context, provider, child) {
        final isMatched = provider.isMatched(widget.user.id);
        final hasSent = provider.hasSentInterest(widget.user.id);
        final showAnon = widget.user.isAnonymous && !isMatched;
        
        final screenHeight = MediaQuery.of(context).size.height;

        return Scaffold(
          backgroundColor: Colors.black, // Dark premium background
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Large Hero Image
                  SliverAppBar(
                    expandedHeight: screenHeight * 0.55,
                    stretch: true,
                    pinned: true,
                    backgroundColor: Colors.black,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
                        onPressed: () => _showActionMenu(context, provider),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          showAnon ? _buildAnonymousHeroImage() : _buildHeroImage(widget.user),
                          // Gradient overlay for readability
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                  Colors.black,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.2, 0.7, 1.0],
                              ),
                            ),
                          ),
                          // Floating Name & Basic Info at the bottom of the image
                          Positioned(
                            bottom: 24,
                            left: 24,
                            right: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  showAnon ? provider.t('anon_user') : widget.user.name,
                                  style: const TextStyle(
                                    fontFamily: 'Cormorant Garamond',
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                    height: 1.1,
                                  ),
                                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(showAnon ? Icons.lock_outline_rounded : Icons.school_rounded, size: 16, color: AppTheme.accent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        showAnon 
                                            ? provider.t('hidden_until_match').toUpperCase()
                                            : '${widget.user.university} · ${widget.user.department}',
                                        style: const TextStyle(
                                          fontFamily: 'Space Mono',
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content Layout
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          if (!showAnon) ...[
                            _buildBioSection(widget.user),
                            const SizedBox(height: 40),
                            _buildPhotoGallery(widget.user),
                            const SizedBox(height: 40),
                            _buildInterestsSection(widget.user),
                          ] else ...[
                            _buildAnonymousBio(provider),
                            const SizedBox(height: 32),
                            _buildSafetyActions(provider),
                            const SizedBox(height: 40),
                            _buildAnonymousInterests(provider),
                          ],
                          const SizedBox(height: 40),
                          _buildBottomAction(context, hasSent, isMatched: isMatched),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroImage(User user) {
    if (user.profileImageUrl != null) {
      if (user.profileImageUrl!.startsWith('http')) {
        return Image.network(user.profileImageUrl!, fit: BoxFit.cover);
      } else {
        return Image.file(File(user.profileImageUrl!), fit: BoxFit.cover);
      }
    }
    
    // Fallback if no image
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: user.genderFlag == 'f'
              ? [const Color(0xFFFF6B9D), const Color(0xFF900020)]
              : [const Color(0xFF4D9FFF), const Color(0xFF003366)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(user.avatar, style: const TextStyle(fontSize: 100)),
    );
  }

  Widget _buildAnonymousHeroImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF333333), Colors.black],
              radius: 1.0,
            ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withOpacity(0.5),
            alignment: Alignment.center,
            child: const Icon(Icons.person_outline_rounded, size: 120, color: Colors.white24),
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection(User user) {
    if (user.bio.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BİYOGRAFİ',
          style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppTheme.accent),
        ),
        const SizedBox(height: 12),
        Text(
          user.bio,
          style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5, fontWeight: FontWeight.w400),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms);
  }


  Widget _buildPhotoGallery(User user) {
    final photos = user.diaryPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KAMPÜS GÜNLÜĞÜ',
          style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, letterSpacing: 2, color: AppTheme.accent, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        if (photos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: const Column(
              children: [
                Icon(Icons.photo_library_outlined, color: Colors.white24, size: 32),
                SizedBox(height: 16),
                Text('Henüz fotoğraf yok', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(photos[index]),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
              ).animate().fadeIn(delay: (index * 100).ms);
            },
          ),
      ],
    ).animate().fadeIn(delay: 500.ms, duration: 600.ms);
  }

  Widget _buildInterestsSection(User user) {
    if (user.interests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İLGİ ALANLARI',
          style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppTheme.accent),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: user.interests.map((interest) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
              ),
              child: Text(
                interest,
                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms, duration: 600.ms);
  }

  Widget _buildAnonymousBio(AppData provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.visibility_off_rounded, color: AppTheme.accent, size: 32),
          const SizedBox(height: 16),
          Text(
            provider.t('anon_bio_desc'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildSafetyActions(AppData provider) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security_rounded, size: 14, color: Colors.white38),
            const SizedBox(width: 8),
            Text(
              provider.t('verified_student'),
              style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white54, letterSpacing: 1),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildAnonymousInterests(AppData provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İPUÇLARI',
          style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppTheme.accent),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: List.generate(3, (index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'Gizli İlgi Alanı',
                style: TextStyle(fontSize: 13, color: Colors.white38),
              ),
            );
          }),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildBottomAction(BuildContext context, bool hasSent, {required bool isMatched}) {
    if (isMatched) {
      return GestureDetector(
        onTap: () async {
          HapticFeedback.mediumImpact();
          final appData = Provider.of<AppData>(context, listen: false);
          final conv = await appData.findOrRefreshConversation(widget.user.id);
          if (conv != null && context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversationId: conv.id)));
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.red, Color(0xFFFF4D6D)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppTheme.red.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 4)),
            ],
          ),
          child: const Center(
            child: Text(
              'SOHBETİ AÇ',
              style: TextStyle(fontFamily: 'Space Mono', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 2),
            ),
          ),
        ),
      ).animate().fadeIn(delay: 700.ms);
    }

    return GestureDetector(
      onTap: hasSent ? null : () {
        HapticFeedback.mediumImpact();
        _sendInterest(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: hasSent ? AppTheme.surface3 : AppTheme.accent,
          borderRadius: BorderRadius.circular(20),
          border: hasSent ? Border.all(color: AppTheme.border) : null,
          boxShadow: hasSent ? null : [
            BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(
            hasSent ? 'GÖZ KIRPILDI' : 'GÖZ KIRP',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: hasSent ? Colors.white54 : Colors.black,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 700.ms);
  }

  void _showActionMenu(BuildContext context, AppData provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.block_flipped, color: AppTheme.red, size: 22),
              title: Text(provider.t('block_user'), style: const TextStyle(color: AppTheme.red, fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                provider.blockUser(widget.user.id);
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı engellendi.'), backgroundColor: AppTheme.accent),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.white54, size: 22),
              title: Text(provider.t('report_user'), style: const TextStyle(fontSize: 14, color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Report dialog mock
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _sendInterest(BuildContext context) async {
    final provider = Provider.of<AppData>(context, listen: false);
    String? error = await provider.sendInterest(widget.user.id);
    if (!mounted) return;

    if (error == null) {
      if (provider.isMatched(widget.user.id)) {
        _showMatchOverlay(context);
      } else {
        showPointOverlay(context, -1, 'Göz Kırpma');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.t('interest_sent'))));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.red));
    }
  }

  void _showMatchOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black.withOpacity(0.95),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 64, color: AppTheme.accent),
              const SizedBox(height: 24),
              const Text(
                'GÖZ TEMASI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'BİR BAĞLANTI KURULDU',
                style: TextStyle(fontFamily: 'Space Mono', fontSize: 12, letterSpacing: 4, color: Colors.white54),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMatchAvatar(Provider.of<AppData>(context, listen: false).currentUser!),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Icon(Icons.handshake_rounded, size: 32, color: AppTheme.accent),
                  ),
                  _buildMatchAvatar(widget.user),
                ],
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final appData = Provider.of<AppData>(context, listen: false);
                    final conv = await appData.findOrRefreshConversation(widget.user.id);
                    if (conv != null && context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversationId: conv.id)));
                    }
                  },
                  child: const SizedBox(
                    width: double.infinity, 
                    child: Center(
                      child: Text('SOHBETİ BAŞLAT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14))
                    )
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('KAPAT', style: TextStyle(color: Colors.white38, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchAvatar(User user) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.accent, width: 2),
        image: user.profileImageUrl != null
            ? DecorationImage(
                image: user.profileImageUrl!.startsWith('http')
                    ? NetworkImage(user.profileImageUrl!) as ImageProvider
                    : FileImage(File(user.profileImageUrl!)),
                fit: BoxFit.cover,
              )
            : null,
        color: AppTheme.surface3,
      ),
      alignment: Alignment.center,
      child: user.profileImageUrl == null ? Text(user.avatar, style: const TextStyle(fontSize: 36)) : null,
    );
  }
}
