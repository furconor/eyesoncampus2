import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/glass_container.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppData>().refreshProfileStats();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    final me = provider.currentUser;
    if (me == null) return const Center(child: CircularProgressIndicator());

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
                  icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildHeroImage(me),
                      // Gradient overlay for readability
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                              Colors.black, // Fade into the list
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
                              me.name,
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
                                const Icon(Icons.school_rounded, size: 16, color: AppTheme.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${me.university} · ${me.department}',
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
                      _buildBioSection(me),
                      const SizedBox(height: 32),
                      _buildEnergyHub(provider, me),
                      const SizedBox(height: 32),
                      _buildSocialStats(provider, me),
                      const SizedBox(height: 40),
                      _buildPhotoGallery(provider),
                      const SizedBox(height: 40),
                      _buildInformationSection(me),
                      const SizedBox(height: 40),
                      _buildInterestsSection(me),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          if (_isUploadingPhoto)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accent),
                    SizedBox(height: 20),
                    Text(
                      'Fotoğraf yükleniyor...',
                      style: TextStyle(color: Colors.white, fontFamily: 'Space Mono', fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(User me) {
    if (me.profileImageUrl != null) {
      if (me.profileImageUrl!.startsWith('http')) {
        return Image.network(me.profileImageUrl!, fit: BoxFit.cover);
      } else {
        return Image.file(File(me.profileImageUrl!), fit: BoxFit.cover);
      }
    }
    
    // Fallback if no image
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: me.genderFlag == 'f'
              ? [const Color(0xFFFF6B9D), const Color(0xFF900020)]
              : [const Color(0xFF4D9FFF), const Color(0xFF003366)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(me.avatar, style: const TextStyle(fontSize: 100)),
    );
  }

  Widget _buildBioSection(User me) {
    if (me.bio.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BİYOGRAFİ',
          style: TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          me.bio,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms);
  }

  Widget _buildEnergyHub(AppData provider, User me) {
    final energyColor = _getEnergyColor(me.points);
    
    return GlassContainer(
      blur: 20,
      opacity: 0.15,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white12),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PWR SEVİYESİ',
                      style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, letterSpacing: 2, color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${me.points}',
                          style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: energyColor, fontFamily: 'Space Mono'),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.bolt, color: energyColor, size: 28),
                      ],
                    ),
                  ],
                ),
                _buildEnergyIndicator(me.points),
              ],
            ),
            if (me.points < 10) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    const Text(
                      'YENİLENME: ',
                      style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white70, letterSpacing: 1),
                    ),
                    Text(
                      provider.energyCountdown,
                      style: const TextStyle(fontFamily: 'Space Mono', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildEnergyIndicator(int points) {
    const double maxPoints = 10.0;
    const int totalBars = 4;
    final energyColor = _getEnergyColor(points);
    return Row(
      children: List.generate(totalBars, (index) {
        final isActive = points > (index * (maxPoints / totalBars));
        return Container(
          margin: const EdgeInsets.only(left: 6),
          width: 8,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? energyColor : Colors.white10,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive ? [BoxShadow(color: energyColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)] : null,
          ),
        );
      }),
    );
  }

  Color _getEnergyColor(int points) {
    if (points >= 8) return const Color(0xFF34C759);
    if (points >= 4) return AppTheme.accent;
    return AppTheme.red;
  }

  Widget _buildSocialStats(AppData provider, User me) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatBox('GÖZ ATAN', '${provider.lookCount}', Icons.remove_red_eye_rounded, count: 4),
        _buildStatBox('EŞLEŞME', '${provider.matchCount}', Icons.auto_awesome_rounded, count: 4),
        _buildStatBox('SOHBET', '${provider.chatCount}', Icons.chat_bubble_rounded, count: 4),
        _buildStatBox('AYLIK GÖZ', '${provider.monthlyViews}', Icons.insights_rounded, count: 4),
      ],
    ).animate().fadeIn(delay: 500.ms, duration: 600.ms);
  }

  Widget _buildStatBox(String label, String value, IconData icon, {int count = 4}) {
    return Container(
      width: (MediaQuery.of(context).size.width - 40 - ((count - 1) * 12)) / count,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppTheme.accent),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Space Mono', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              label,
              style: const TextStyle(fontFamily: 'Space Mono', fontSize: 8, color: Colors.white54, letterSpacing: 1, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery(AppData provider) {
    final me = provider.currentUser!;
    final photos = me.diaryPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'KAMPÜS GÜNLÜĞÜ',
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 10,
                letterSpacing: 2,
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (photos.isNotEmpty)
              GestureDetector(
                onTap: () => _pickAndUploadPhoto(context, provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_a_photo_rounded, size: 14, color: AppTheme.accent),
                      SizedBox(width: 6),
                      Text(
                        'EKLE',
                        style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (photos.isEmpty)
          GestureDetector(
            onTap: () => _pickAndUploadPhoto(context, provider),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.accent, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text('Kampüs hayatından anlar paylaş', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('İlk fotoğrafını ekle', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
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
    ).animate().fadeIn(delay: 600.ms, duration: 600.ms);
  }

  Widget _buildInformationSection(User me) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BİLGİLER',
          style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppTheme.accent),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildInfoRow(Icons.school_rounded, 'Okul', me.university),
              _buildDivider(),
              _buildInfoRow(Icons.menu_book_rounded, 'Bölüm', me.department),
              _buildDivider(),
              _buildInfoRow(Icons.calendar_today_rounded, 'Sınıf', me.year),
              _buildDivider(),
              _buildInfoRow(Icons.pin_drop_rounded, 'Güncel Konum', me.campusZone ?? 'Bilinmiyor'),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 700.ms, duration: 600.ms);
  }

  Widget _buildInterestsSection(User me) {
    if (me.interests.isEmpty) return const SizedBox.shrink();

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
          children: me.interests.map((interest) {
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
    ).animate().fadeIn(delay: 800.ms, duration: 600.ms);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.white54)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: Colors.white10, height: 1),
    );
  }

  Future<void> _pickAndUploadPhoto(BuildContext context, AppData provider) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null && mounted) {
        setState(() => _isUploadingPhoto = true);
        
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last;
        final success = await provider.uploadDiaryPhoto(bytes, ext) != null;
        
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fotoğraf başarıyla eklendi!'), backgroundColor: AppTheme.accent),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fotoğraf eklenemedi.'), backgroundColor: AppTheme.red),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf seçilirken hata oluştu.'), backgroundColor: AppTheme.red),
        );
      }
    }
  }
}
