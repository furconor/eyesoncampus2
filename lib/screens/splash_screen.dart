import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'daily_quiz_screen.dart';
import 'main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Minimum branding delay
    final minDelay = Future.delayed(const Duration(seconds: 2));
    
    final appData = Provider.of<AppData>(context, listen: false);
    
    // Wait for AppData to finish its async initialization
    while (!appData.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    await minDelay; // Ensure at least 2 seconds delay
    if (!mounted) return;
    
    if (appData.isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 0.2), // Maps approx to 50% 60%
            radius: 0.8,
            colors: [
              Color(0x1EE8C97A), // rgba(232,201,122,0.12)
              AppTheme.bg,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  'assets/icon/app_logo.jpeg',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1), 
                end: const Offset(1.1, 1.1),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              Text(
                'EyesOnCampus',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 26,
                  letterSpacing: 5,
                  height: 1.1,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ).animate().fadeIn(duration: 800.ms),
              const SizedBox(height: 6),
              Text(
                'ÜNİVERSİTE SOSYAL AĞI',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 7, // Adjusting closely approx to UI CSS
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
