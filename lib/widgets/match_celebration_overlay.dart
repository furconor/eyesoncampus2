import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../providers/app_data_provider.dart';
import '../widgets/glass_container.dart';
import '../screens/chat_detail_screen.dart';

class MatchCelebrationOverlay extends StatelessWidget {
  final User matchedUser;
  final VoidCallback onDismiss;

  const MatchCelebrationOverlay({
    super.key,
    required this.matchedUser,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GlassContainer(
        blur: 25,
        opacity: 0.8,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'MÜKEMMEL!',
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 42,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 8,
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 12),
              
              const Text(
                'YENİ BİR EŞLEŞME YAKALADIN',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  color: AppTheme.muted,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 60),
              
              // Avatars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatar(context.read<AppData>().currentUser!),
                  const SizedBox(width: 20),
                  const Icon(Icons.favorite, color: AppTheme.accent, size: 40)
                      .animate(onPlay: (c) => c.repeat())
                      .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(width: 20),
                  _buildAvatar(matchedUser),
                ],
              ).animate().scale(delay: 600.ms, duration: 800.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 80),
              
              Text(
                matchedUser.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ).animate().fadeIn(delay: 1000.ms),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: () {
                    final provider = context.read<AppData>();
                    final conversation = provider.conversations.firstWhere(
                      (c) => c.otherUser.id == matchedUser.id,
                    );
                    onDismiss();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatDetailScreen(conversationId: conversation.id)),
                    );
                  },
                  child: const Text('MESAJ GÖNDER'),
                ),
              ).animate().fadeIn(delay: 1400.ms).slideY(begin: 0.5, end: 0),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: onDismiss,
                child: const Text(
                  'SONRA',
                  style: TextStyle(color: AppTheme.muted2, letterSpacing: 2, fontSize: 12),
                ),
              ).animate().fadeIn(delay: 1800.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(User user) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.accent, width: 3),
        boxShadow: [
          BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
        ],
        image: user.profileImageUrl != null
            ? DecorationImage(image: NetworkImage(user.profileImageUrl!), fit: BoxFit.cover)
            : null,
        color: AppTheme.surface2,
      ),
      alignment: Alignment.center,
      child: user.profileImageUrl == null ? Text(user.avatar, style: const TextStyle(fontSize: 40)) : null,
    );
  }
}
