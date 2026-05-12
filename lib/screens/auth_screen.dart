import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../providers/supabase_service.dart';
import 'main_layout.dart';
import '../utils/content_filter.dart';
import 'legal_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _step = 0; // 0: Splash/Option, 1: Email, 2: Verification, 3: Profile Settings
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _confirmedAge = false;
  String? _selectedUniversityId;
  
  void _nextStep() async {
    if (_step == 1) {
      final email = _emailController.text.trim().toLowerCase();

      if (email == 'apple_test@eyesoncampus.com') {
        _nameController.text = 'apple_test';
        setState(() => _step = 2);
        return;
      }

      if (!email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bir e-posta giriniz.')),
        );
        return;
      }

      final domain = email.split('@').last;
      _nameController.text = email.split('@').first;

      final provider = Provider.of<AppData>(context, listen: false);
      final match = provider.universities.where((u) {
        if (u.domain == null) return false;
        final domains = u.domain!.toLowerCase().split(',').map((d) => d.trim()).toList();
        return domains.contains(domain);
      }).toList();

      if (match.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu e-posta adresiyle kayıt yapılamamaktadır. Lütfen üniversite mailinizi kullanın.')),
        );
        return;
      }

      setState(() {
        _selectedUniversityId = match.first.id;
        _step = 2;
      });
      return;
    }

    if (_step == 2) {
      if (!ContentFilter.isClean(_deptController.text) || !ContentFilter.isClean(_yearController.text)) {
        _showError(ContentFilter.getBlockedMessage(Provider.of<AppData>(context, listen: false).currentLanguage));
        return;
      }
      setState(() => _step = 3);
      return;
    }

    if (_step == 3) {
      if (_passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifreniz en az 6 karakter olmalıdır.')),
        );
        return;
      }
      if (!_acceptedTerms || !_confirmedAge) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devam etmek için sözleşmeleri onaylamalısın.')),
        );
        return;
      }
      await _completeRegistration();
    }
  }
  
  Future<void> _completeRegistration() async {
    setState(() => _isLoading = true);
    final supabase = SupabaseService();

    // Kullanıcı zaten authenticated ise (giriş yapıp profile geldiyse) direkt profil oluştur
    if (supabase.isAuthenticated) {
      await _finalizingRegistration();
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final String? result = await supabase.signUpWithEmail(
      _emailController.text.trim().toLowerCase(),
      _passwordController.text,
    );

    if (result == 'verification_required') {
      if (mounted) setState(() { _isLoading = false; _step = 4; });
      return;
    }

    if (result == null) {
      await _finalizingRegistration();
    } else {
      _showError(result);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _getFriendlyErrorMessage(String? error) {
    if (error == null) return "";
    final e = error.toLowerCase();
    
    if (e.contains('invalid login credentials') || e.contains('invalid_credentials')) {
      return "E-posta veya şifre hatalı.";
    }
    if (e.contains('user not found') || e.contains('user_not_found')) {
      return "Bu e-posta ile kayıtlı bir kullanıcı bulunamadı.";
    }
    if (e.contains('email not confirmed')) {
      return "Lütfen e-posta adresinizi doğrulayın.";
    }
    if (e.contains('network') || e.contains('connection')) {
      return "Bağlantı hatası. Lütfen internetinizi kontrol edin.";
    }
    if (e.contains('too many requests')) {
      return "Çok fazla deneme yapıldı. Lütfen biraz bekleyin.";
    }
    
    return "Bir hata oluştu, lütfen tekrar deneyin.";
  }

  void _showError(String msg) {
    final friendlyMsg = _getFriendlyErrorMessage(msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                friendlyMsg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _verifySignupOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen 6 haneli kodu girin.')));
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim().toLowerCase();
    final supabase = SupabaseService();
    bool success = await supabase.verifySignupOtp(email, _otpController.text);

    if (success) {
      await _finalizingRegistration();
    } else {
      if (!mounted) return;
      _showError('Doğrulama kodu hatalı veya süresi dolmuş.');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizingRegistration() async {
    final supabase = SupabaseService();
    final profileData = {
      'name': _nameController.text,
      'university': _universityIdToName(context, _selectedUniversityId) ?? 'Belirtilmedi',
      'university_id': _selectedUniversityId,
      'department': _deptController.text.isNotEmpty ? _deptController.text : 'Hazırlık',
      'year': _yearController.text.isNotEmpty ? _yearController.text : '1. Sınıf',
      'bio': 'Kampüste yeni.',
      'interests': ['Kahve'],
      'avatar': '🧑',
      'campus_zone': 'Merkez',
      'gender_flag': 'm', // Default 
      'quiz_completed': false,
      'quiz_step': 0,
      'last_energy_sync_at': DateTime.now().toIso8601String(),
    };
    await supabase.createProfile(profileData);
    
    final newUser = await supabase.getCurrentUserProfile();
    if (newUser != null) {
      final provider = Provider.of<AppData>(context, listen: false);
      await provider.completeOnboarding();
      await provider.login(newUser);
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    }
  }

  void _showLoginDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: AppTheme.border.withOpacity(0.5))),
        title: const Text(
          'GİRİŞ YAP', 
          style: TextStyle(color: AppTheme.accent, fontFamily: 'Space Mono', fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _buildPremiumTextField(controller: emailCtrl, hint: 'E-posta adresi', icon: Icons.email_outlined),
            const SizedBox(height: 16),
            _buildPremiumTextField(controller: passCtrl, hint: 'Şifre', icon: Icons.lock_outline, obscureText: true),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showForgotPasswordFlow(context);
                },
                child: const Text('Şifremi Unuttum', style: TextStyle(color: AppTheme.muted, fontSize: 11, fontFamily: 'Space Mono')),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.border.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('İPTAL', style: TextStyle(color: AppTheme.muted, fontSize: 12, fontFamily: 'Space Mono')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final sb = SupabaseService();
                    String? errorMessage;
                    bool success = false;
                    
                    // Sign In attempt
                    try {
                      success = await sb.signInWithEmail(emailCtrl.text.trim(), passCtrl.text);
                    } catch (e) {
                      errorMessage = e.toString();
                    }
                    
                    // APPLE REVIEWER KORUMASI: Sadece bu hesap girdiginde verileri yukle
                    if (!success && emailCtrl.text.trim().toLowerCase() == 'apple_test@eyesoncampus.com' && passCtrl.text == 'AppleTest2026*') {
                      await sb.seedDummyData();
                      success = await sb.signInWithEmail(emailCtrl.text.trim(), passCtrl.text);
                    }
                    
                    if (success) {
                      final user = await sb.getCurrentUserProfile();
                      if (user != null) {
                        final provider = Provider.of<AppData>(context, listen: false);
                        await provider.completeOnboarding();
                        await provider.login(user);
                        if (mounted) {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
                        }
                      } else {
                        // OTOMATİK PROFİL KURTARMA: Auth var ama Profil yoksa kayıt adım 3'e (profil oluşturma) at
                        if (mounted) {
                          // Üniversiteyi e-postadan otomatik tanıyalım
                          final email = emailCtrl.text.trim().toLowerCase();
                          final domain = email.split('@').last;
                          final provider = Provider.of<AppData>(context, listen: false);
                          
                          final match = provider.universities.where((u) {
                            if (u.domain == null) return false;
                            final domains = u.domain!.toLowerCase().split(',').map((d) => d.trim()).toList();
                            return domains.contains(domain);
                          }).toList();

                          setState(() {
                            if (match.isNotEmpty) {
                              _selectedUniversityId = match.first.id;
                            }
                            _step = 2;
                            _isLoading = false;
                          });
                          // Use a nice informational snackbar instead of default
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Hesabınız bulundu! Lütfen profilinizi tamamlayın.', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                            backgroundColor: AppTheme.accent.withOpacity(0.9),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      }
                    } else {
                      if (mounted) {
                        _showError(errorMessage ?? 'Bilgileri kontrol edin.');
                      }
                    }
                    if (mounted) setState(() => _isLoading = false);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('GİRİŞ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Space Mono')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showForgotPasswordFlow(BuildContext context) {
    final emailCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    int step = 0; // 0: email, 1: otp, 2: new password
    String userEmail = '';
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: isLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.surface3,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Title
                        Text(
                          step == 0 ? 'Şifremi Unuttum'
                            : step == 1 ? 'Doğrulama Kodu'
                            : 'Yeni Şifre',
                          style: const TextStyle(
                            fontFamily: 'Cormorant Garamond',
                            fontSize: 28,
                            color: AppTheme.accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step == 0 ? 'Kayıtlı e-posta adresini gir, sana doğrulama kodu gönderelim.'
                            : step == 1 ? '$userEmail adresine gönderilen 6 haneli kodu gir.'
                            : 'Yeni şifreni belirle.',
                          style: const TextStyle(color: AppTheme.muted2, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        
                        // Step 0: Email
                        if (step == 0) ...[
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppTheme.text),
                            decoration: InputDecoration(
                              hintText: 'E-posta adresi',
                              hintStyle: const TextStyle(color: AppTheme.muted),
                              filled: true,
                              fillColor: AppTheme.surface3,
                              prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.muted, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                        ],
                        
                        // Step 1: OTP Code
                        if (step == 1) ...[
                          TextField(
                            controller: otpCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            style: const TextStyle(
                              color: AppTheme.text,
                              fontSize: 28,
                              letterSpacing: 8,
                              fontFamily: 'Space Mono',
                            ),
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: TextStyle(color: AppTheme.muted.withOpacity(0.3), fontSize: 28, letterSpacing: 8),
                              filled: true,
                              fillColor: AppTheme.surface3,
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                        ],
                        
                        // Step 2: New Password
                        if (step == 2) ...[
                          TextField(
                            controller: newPassCtrl,
                            obscureText: true,
                            style: const TextStyle(color: AppTheme.text),
                            decoration: InputDecoration(
                              hintText: 'Yeni şifre (en az 6 karakter)',
                              hintStyle: const TextStyle(color: AppTheme.muted),
                              filled: true,
                              fillColor: AppTheme.surface3,
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.muted, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: confirmPassCtrl,
                            obscureText: true,
                            style: const TextStyle(color: AppTheme.text),
                            decoration: InputDecoration(
                              hintText: 'Yeni şifre (tekrar)',
                              hintStyle: const TextStyle(color: AppTheme.muted),
                              filled: true,
                              fillColor: AppTheme.surface3,
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.muted, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final supabase = SupabaseService();
                              
                              if (step == 0) {
                                // Send OTP
                                final email = emailCtrl.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Geçerli bir e-posta girin.')),
                                  );
                                  return;
                                }
                                setSheetState(() => isLoading = true);
                                final success = await supabase.sendPasswordResetOtp(email);
                                setSheetState(() => isLoading = false);
                                if (success) {
                                  userEmail = email;
                                  setSheetState(() => step = 1);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('E-posta gönderilemedi. Lütfen tekrar dene.')),
                                    );
                                  }
                                }
                              } else if (step == 1) {
                                // Verify OTP
                                final code = otpCtrl.text.trim();
                                if (code.length != 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('6 haneli kodu girin.')),
                                  );
                                  return;
                                }
                                setSheetState(() => isLoading = true);
                                final success = await supabase.verifyOtp(userEmail, code);
                                setSheetState(() => isLoading = false);
                                if (success) {
                                  setSheetState(() => step = 2);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Kod hatalı veya süresi dolmuş. Tekrar dene.')),
                                    );
                                  }
                                }
                              } else if (step == 2) {
                                // Update Password
                                final newPass = newPassCtrl.text;
                                final confirmPass = confirmPassCtrl.text;
                                if (newPass.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Şifre en az 6 karakter olmalı.')),
                                  );
                                  return;
                                }
                                if (newPass != confirmPass) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Şifreler eşleşmiyor.')),
                                  );
                                  return;
                                }
                                setSheetState(() => isLoading = true);
                                final success = await supabase.updatePassword(newPass);
                                setSheetState(() => isLoading = false);
                                if (success) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Şifren başarıyla güncellendi! Yeni şifrenle giriş yapabilirsin.'),
                                        backgroundColor: AppTheme.accent,
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Şifre güncellenemedi. Tekrar dene.')),
                                    );
                                  }
                                }
                              }
                            },
                            child: Text(
                              step == 0 ? 'Doğrulama Kodu Gönder'
                                : step == 1 ? 'Kodu Doğrula'
                                : 'Şifreyi Güncelle',
                            ),
                          ),
                        ),
                        if (step == 1) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () async {
                                setSheetState(() => isLoading = true);
                                await SupabaseService().sendPasswordResetOtp(userEmail);
                                setSheetState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Kod tekrar gönderildi.')),
                                  );
                                }
                              },
                              child: const Text('Kodu tekrar gönder', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _step > 0 ? AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => setState(() => _step--),
        ),
        title: Text(
          _step == 1 ? 'E-posta'
          : _step == 2 ? 'Profil'
          : _step == 3 ? 'Güvenlik'
          : 'Doğrulama',
          style: const TextStyle(color: AppTheme.text, fontSize: 16),
        ),
      ) : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : Column(
                children: [
                  if (_step >= 1 && _step <= 3)
                    LinearProgressIndicator(
                      value: _step / 3,
                      minHeight: 2,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                    ),
                  Expanded(child: _buildBody()),
                ],
              ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0: return _buildSplashOption();
      case 1: return _buildEmailStep();
      case 2: return _buildProfileStep();
      case 3: return _buildSecurityStep();
      case 4: return _buildSignupVerificationStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildSplashOption() {
    final provider = Provider.of<AppData>(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        image: DecorationImage(
          image: AssetImage('assets/images/onboarding_3.png'),
          fit: BoxFit.cover,
          opacity: 0.15,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.0),
              Colors.black.withOpacity(0.8),
              AppTheme.bg,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildLangBtn('TR', provider.currentLanguage == 'tr', () => provider.setLanguage('tr')),
                  const SizedBox(width: 8),
                  _buildLangBtn('EN', provider.currentLanguage == 'en', () => provider.setLanguage('en')),
                ],
              ),
              const Spacer(),
              Hero(
                tag: 'app_logo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/icon/app_logo.jpeg',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).shimmer(delay: 1.seconds, duration: 2.seconds),
              ),
              const SizedBox(height: 32),
              Text(
                'EyesOnCampus',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  height: 1.0,
                  color: AppTheme.text,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 800.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 12),
              Text(
                provider.t('tagline').toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 800.ms),
              const Spacer(),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    provider.t('get_started').toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Space Mono', 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 1,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _showLoginDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: BorderSide(color: AppTheme.border.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    provider.t('already_have_account').toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Space Mono', 
                      color: AppTheme.text, 
                      fontSize: 12, 
                      letterSpacing: 1
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.surface3.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'Space Mono',
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : AppTheme.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    final provider = Provider.of<AppData>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.t('email_label'),
            style: const TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 32, color: AppTheme.accent),
          ),
          const SizedBox(height: 12),
          Text(
            provider.t('email_desc'),
            style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 40),
          _buildPremiumTextField(
            controller: _emailController,
            hint: provider.t('email_hint'),
            keyboardType: TextInputType.emailAddress,
            icon: Icons.email_outlined,
          ),
          const Spacer(),
          _buildPremiumButton(
            onPressed: _nextStep,
            label: 'DEVAM ET',
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    IconData? icon,
    int? maxLength,
    TextAlign textAlign = TextAlign.start,
    double? letterSpacing,
    double? fontSize,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textAlign: textAlign,
      maxLength: maxLength,
      style: TextStyle(
        color: AppTheme.text,
        fontSize: fontSize ?? 15,
        letterSpacing: letterSpacing,
        fontFamily: fontSize != null ? 'Space Mono' : null,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.muted.withOpacity(0.5), letterSpacing: 0, fontSize: 14),
        filled: true,
        fillColor: AppTheme.surface3.withOpacity(0.4),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.muted, size: 20) : null,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.border.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPremiumButton({required VoidCallback? onPressed, required String label}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14),
        ),
      ),
    );
  }

  // Adım 2 — Bölüm + Sınıf (üniversite chip olarak gösterilir, isim alanı yok)
  Widget _buildProfileStep() {
    final provider = Provider.of<AppData>(context);
    final uniName = _universityIdToName(context, _selectedUniversityId);
    final username = _nameController.text.isNotEmpty ? _nameController.text : '';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.t('complete_profile'),
            style: const TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 32, color: AppTheme.accent),
          ),
          const SizedBox(height: 12),
          Text(
            'Kampüste seni nasıl tanımlayalım?',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 28),
          // Read-only info rows
          _buildReadOnlyField(label: 'Kullanıcı Adı', value: username, icon: Icons.person_outline),
          if (uniName != null) ...[
            const SizedBox(height: 12),
            _buildReadOnlyField(label: 'Üniversite', value: uniName, icon: Icons.school_outlined),
          ],
          const SizedBox(height: 28),
          _buildInputLabel(provider.t('dept')),
          _buildPremiumTextField(controller: _deptController, hint: 'Örn: Bilgisayar Müh.', icon: Icons.menu_book_outlined),
          const SizedBox(height: 20),
          _buildInputLabel(provider.t('class')),
          _buildPremiumTextField(controller: _yearController, hint: 'Örn: 2. Sınıf', icon: Icons.calendar_today_outlined),
          const SizedBox(height: 48),
          _buildPremiumButton(onPressed: _nextStep, label: 'DEVAM ET'),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.muted, fontSize: 11, letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.muted, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 14),
                ),
              ),
              const Icon(Icons.lock_outline, color: AppTheme.border, size: 14),
            ],
          ),
        ),
      ],
    );
  }

  // Adım 3 — Şifre + Sözleşmeler
  Widget _buildSecurityStep() {
    final provider = Provider.of<AppData>(context);
    final canProceed = _acceptedTerms && _confirmedAge;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Güvenlik',
            style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 32, color: AppTheme.accent),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hesabın için güçlü bir şifre belirle.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 40),
          _buildInputLabel('Şifre'),
          _buildPremiumTextField(
            controller: _passwordController,
            hint: 'En az 6 karakter',
            obscureText: true,
            icon: Icons.lock_outline,
            fontSize: 24,
            letterSpacing: 4,
          ),
          const SizedBox(height: 40),
          _buildAgreementItem(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5),
                children: [
                  TextSpan(
                    text: provider.t('accept_terms'),
                    style: const TextStyle(color: AppTheme.accent, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(
                        title: provider.currentLanguage == 'tr' ? 'Kullanım Şartları (EULA)' : 'Terms of Use (EULA)',
                        content: provider.currentLanguage == 'tr' ? LegalScreen.eulaContent : LegalScreen.eulaContentEn,
                      )));
                    },
                  ),
                  const TextSpan(text: ' & '),
                  TextSpan(
                    text: provider.currentLanguage == 'tr' ? 'Gizlilik Politikası' : 'Privacy Policy',
                    style: const TextStyle(color: AppTheme.accent, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(
                        title: provider.currentLanguage == 'tr' ? 'Gizlilik Politikası' : 'Privacy Policy',
                        content: provider.currentLanguage == 'tr' ? LegalScreen.privacyContent : LegalScreen.privacyContentEn,
                      )));
                    },
                  ),
                  TextSpan(text: provider.t('accept_desc')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildAgreementItem(
            value: _confirmedAge,
            onChanged: (v) => setState(() => _confirmedAge = v ?? false),
            child: Text(
              provider.currentLanguage == 'tr'
                  ? '18 yaşından büyük olduğumu onaylıyorum.'
                  : 'I confirm that I am over 18 years old.',
              style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 48),
          _buildPremiumButton(
            onPressed: canProceed ? _nextStep : null,
            label: provider.t('complete_reg'),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementItem({required bool value, required ValueChanged<bool?> onChanged, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
            checkColor: const Color(0xFF0A0800),
            side: const BorderSide(color: AppTheme.muted, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.muted2, 
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String? _universityIdToName(BuildContext context, String? id) {
    if (id == null) return null;
    try {
      final unis = Provider.of<AppData>(context, listen: false).universities;
      return unis.firstWhere((u) => u.id == id).name;
    } catch (_) {
      return null;
    }
  }

  Widget _buildSignupVerificationStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DOĞRULAMA KODU',
            style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 32, color: AppTheme.accent),
          ),
          const SizedBox(height: 12),
          Text(
            '${_emailController.text} adresine gönderilen 6 haneli kayıt kodunu gir.',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 40),
          _buildPremiumTextField(
            controller: _otpController,
            hint: '000000',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            fontSize: 32,
            letterSpacing: 12,
          ),
          const Spacer(),
          _buildPremiumButton(
            onPressed: _verifySignupOtp,
            label: 'DOĞRULA VE TAMAMLA',
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod tekrar gönderiliyor...')));
                _completeRegistration();
              },
              child: const Text('Kodu tekrar gönder', style: TextStyle(color: AppTheme.muted, fontSize: 12, fontFamily: 'Space Mono')),
            ),
          ),
        ],
      ),
    );
  }
}
