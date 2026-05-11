import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../widgets/point_notification_overlay.dart';

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  late int _currentIndex;
  late int _score;
  bool _isAnswered = false;
  int? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppData>();
    _currentIndex = provider.quizCurrentIndex;
    _score = provider.quizScore;
  }


  static const List<Map<String, dynamic>> _fallbackQuestions = [
    {
      'question': 'Boğaziçi Üniversitesi\'nin en meşhur kafesi hangisidir?',
      'options': ['Ruby Cafe', 'Merkez Kafe', 'Kuzey Piramit', 'Güney Sosyal'],
      'answer': 0,
    },
    {
      'question': 'Kampüste "Göz Kırpma" kaç puan kazandırır?',
      'options': ['1 Puan', '2 Puan', '5 Puan', '10 Puan'],
      'answer': 0,
    },
    {
      'question': 'Ruby Cafe\'de bedava kahve kazanmak için kaç puana ulaşmalısın?',
      'options': ['100', '250', '500', '1000'],
      'answer': 1,
    },
    {
      'question': 'En popüler etkinlikler genellikle nerede olur?',
      'options': ['Kütüphane', 'Güney Çimler', 'Laboratuvar', 'Spor Salonu'],
      'answer': 1,
    },
    {
      'question': 'Uygulamada birinin sana göz kırpması kaç puan?',
      'options': ['1 Puan', '2 Puan', '3 Puan', '4 Puan'],
      'answer': 1,
    },
    {
      'question': 'Hangi eylem 2 puan kazandırır?',
      'options': ['Göz Kırpma', 'Mesaj Atma', 'Etkinlik Başlatma', 'Profil Bakma'],
      'answer': 2,
    },
    {
      'question': 'Radar ekranında yanan blimler neyi temsil eder?',
      'options': ['Çevrimdışı Kişiler', 'Sistem Mesajları', 'Çevredeki Aktif Kullanıcılar', 'Engellenenler'],
      'answer': 2,
    },
    {
      'question': 'Uygulamada "Discovery" sekmesi ne işe yarar?',
      'options': ['Harita Görüntüleme', 'Ayarlar Değiştirme', 'Mekan ve Etkinlik Bulma', 'Mesajlaşma'],
      'answer': 2,
    },
    {
      'question': 'Hangi üniversite ilk olarak sisteme dahil edilmiştir?',
      'options': ['İTÜ', 'ODTÜ', 'Boğaziçi Üniversitesi', 'Koç Üniversitesi'],
      'answer': 2,
    },
    {
      'question': 'Uygulamanın adı nedir?',
      'options': ['CampusEye', 'EyesOnCampus', 'UniRadar', 'DateCampus'],
      'answer': 1,
    },
  ];

  List<Map<String, dynamic>> get _questions {
    final provider = context.read<AppData>();
    return provider.quizQuestions.isNotEmpty ? provider.quizQuestions : _fallbackQuestions;
  }

  void _handleAnswer(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = index;
      _isAnswered = true;
      if (index == _questions[_currentIndex]['answer']) {
        _score++;
        // Award point immediately for correct answer
        context.read<AppData>().addPoints(1, 'Doğru Cevap!');
        showPointOverlay(context, 1, 'Doğru Cevap!');
        HapticFeedback.heavyImpact();
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      final provider = context.read<AppData>();
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _isAnswered = false;
          _selectedAnswer = null;
        });
        provider.updateQuizProgress(_currentIndex, _score);
      } else {
        provider.updateQuizProgress(_currentIndex, _score, isCompleted: true);
        _showResult();
      }
    });
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppTheme.accent)),
        title: const Text(
          'Tebrikler!',
          style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 28, color: AppTheme.accent),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_outlined, size: 60, color: AppTheme.accent),
            const SizedBox(height: 16),
            Text(
              '10 sorudan $_score tanesini bildin!',
              style: const TextStyle(color: AppTheme.text, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Toplamda $_score puan kazandın.',
              style: const TextStyle(color: AppTheme.muted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to Home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Harika!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppData>();
    if (provider.quizIsCompleted && _currentIndex == _questions.length - 1) {
       return Scaffold(
         backgroundColor: AppTheme.bg,
         appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
         body: Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.star_outline, size: 60, color: AppTheme.accent),
               const SizedBox(height: 20),
               const Text(
                 'Quiz başarıyla tamamlandı!',
                 style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 10),
               const Text('Bütün soruları yanıtladın, harikasın!', style: TextStyle(color: AppTheme.muted)),
               const SizedBox(height: 30),
               ElevatedButton(
                 onPressed: () => Navigator.pop(context),
                 style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black),
                 child: const Text('Geri Dön'),
               ),
             ],
           ),
         ),
       );
    }

    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'QUİZ',
          style: TextStyle(fontFamily: 'Space Mono', fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(color: AppTheme.surface3, borderRadius: BorderRadius.circular(4)),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 8,
                        width: MediaQuery.of(context).size.width * ((_currentIndex + 1) / _questions.length),
                        decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 10)]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_currentIndex + 1}/${_questions.length}',
                  style: const TextStyle(fontFamily: 'Space Mono', fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface3,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Column(
                children: [
                  const Icon(Icons.help_outline, size: 40, color: AppTheme.accent),
                  const SizedBox(height: 20),
                  Text(
                    q['question'],
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 40),
            
            // Options
            Expanded(
              child: ListView.builder(
                itemCount: q['options'].length,
                itemBuilder: (context, index) {
                  bool isCorrect = index == q['answer'];
                  bool isSelected = index == _selectedAnswer;
                  
                  Color borderColor = AppTheme.border;
                  Color bgColor = AppTheme.surface3;
                  Widget? trainee;

                  if (_isAnswered) {
                    if (isCorrect) {
                      borderColor = Colors.green;
                      bgColor = Colors.green.withOpacity(0.1);
                      trainee = const Icon(Icons.check_circle, color: Colors.green, size: 20);
                    } else if (isSelected) {
                      borderColor = Colors.red;
                      bgColor = Colors.red.withOpacity(0.1);
                      trainee = const Icon(Icons.cancel, color: Colors.red, size: 20);
                    }
                  }

                  return GestureDetector(
                    onTap: () => _handleAnswer(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              q['options'][index],
                              style: TextStyle(
                                color: AppTheme.text,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (trainee != null) trainee,
                        ],
                      ),
                    ),
                  ).animate(target: isSelected ? 1 : 0).shimmer(duration: 500.ms);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
