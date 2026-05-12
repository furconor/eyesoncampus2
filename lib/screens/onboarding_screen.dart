import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import '../providers/app_data_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  void _nextPage() {
    if (_currentIndex < 4 - 1) { // Fixed count for mock
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    
    const _fallbackImages = [
      'https://upload.wikimedia.org/wikipedia/commons/b/bf/Anderson_Hall%2C_Bogazici_University.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/6/68/ITU_Ta%C5%9Fk%C4%B1%C5%9Fla_Campus.JPG/1280px-ITU_Ta%C5%9Fk%C4%B1%C5%9Fla_Campus.JPG',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/METU_Library.jpg/1280px-METU_Library.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/d/da/Wisteria_south_campus_Bogazici_University_2022.jpg',
    ];
    final dbImages = provider.onboardingImages;
    String _img(int i) => (dbImages.length > i && dbImages[i].isNotEmpty) ? dbImages[i] : _fallbackImages[i];

    final List<Map<String, dynamic>> onboardingData = [
      {
        'icon': Icons.location_on_outlined,
        'title': provider.t('onboarding_title_1'),
        'desc': provider.t('onboarding_desc_1'),
        'image': _img(0),
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': provider.t('onboarding_title_2'),
        'desc': provider.t('onboarding_desc_2'),
        'image': _img(1),
      },
      {
        'icon': Icons.school_outlined,
        'title': provider.t('onboarding_title_3'),
        'desc': provider.t('onboarding_desc_3'),
        'image': _img(2),
      },
      {
        'icon': Icons.security_outlined,
        'title': provider.t('onboarding_title_4'),
        'desc': provider.t('onboarding_desc_4'),
        'image': _img(3),
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Background Image with Ken Burns effect (simulated with scale)
          AnimatedSwitcher(
            duration: const Duration(seconds: 1),
            child: Container(
              key: ValueKey(_currentIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(onboardingData[_currentIndex]['image'] as String),
                  fit: BoxFit.cover,
                  opacity: 0.35,
                ),
              ),
            ),
          ),
          
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.4),
                  AppTheme.bg.withOpacity(0.8),
                  AppTheme.bg,
                ],
                stops: const [0, 0.4, 0.7, 1],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontFamily: 'Space Mono', fontSize: 12, color: AppTheme.text, fontWeight: FontWeight.bold),
                      ),
                      _buildLangToggle(provider),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
                        child: Text(
                          provider.t('onboarding_skip').toUpperCase(), 
                          style: const TextStyle(color: AppTheme.muted, fontSize: 10, fontFamily: 'Space Mono', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: onboardingData.length,
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    itemBuilder: (context, index) {
                      final item = onboardingData[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 60,
                              color: AppTheme.accent,
                            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                            const SizedBox(height: 32),
                            Text(
                              item['title'] as String,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Cormorant Garamond',
                                fontSize: 36,
                                fontWeight: FontWeight.w300,
                                height: 1.1,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              item['desc'] as String,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 11,
                                color: AppTheme.muted,
                                height: 1.8,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 60),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentIndex == index ? 24 : 6,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: _currentIndex == index ? AppTheme.accent : AppTheme.border.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            (_currentIndex == onboardingData.length - 1
                                ? provider.t('onboarding_start')
                                : provider.t('onboarding_next')),
                            style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold, letterSpacing: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangToggle(AppData provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface3.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmallLangBtn('TR', provider.currentLanguage == 'tr', () => provider.setLanguage('tr')),
          _buildSmallLangBtn('EN', provider.currentLanguage == 'en', () => provider.setLanguage('en')),
        ],
      ),
    );
  }

  Widget _buildSmallLangBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : AppTheme.muted,
          ),
        ),
      ),
    );
  }
}
