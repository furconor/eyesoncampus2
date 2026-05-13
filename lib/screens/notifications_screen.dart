import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';
import 'chat_detail_screen.dart';
import '../widgets/glass_container.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppData>().markAllNotificationsSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = Provider.of<AppData>(context).notifications;

    return Scaffold(
      backgroundColor: Colors.black, // Deep dark background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationItem(context, notifications[index], index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'Aktivite',
            style: TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.muted.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'HENÜZ AKTİVİTE YOK',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 14,
              color: AppTheme.muted,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildNotificationItem(BuildContext context, AppNotification notif, int index) {
    final provider = Provider.of<AppData>(context, listen: false);
    
    // Determine visual style based on notification type
    final isMatch = notif.type == NotificationType.match;
    final isLook = notif.type == NotificationType.look;
    final isMessage = notif.type == NotificationType.message;
    
    // Blur identity if it's an anonymous look (wink) that hasn't resulted in a match yet
    final blurIdentity = isLook;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        opacity: notif.isNew ? 0.2 : 0.1,
        blur: 15,
        border: Border.all(
          color: notif.isNew 
              ? AppTheme.accent.withOpacity(0.5)
              : Colors.white12,
          width: notif.isNew ? 1.5 : 1,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(notif, blurIdentity),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMessageText(notif, blurIdentity),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notif.timestamp),
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 10,
                        color: AppTheme.muted,
                      ),
                    ),
                    if (isLook && notif.isNew)
                      _buildLookAction(context),
                    if (isMatch || isMessage)
                      _buildMatchAction(context, notif),
                  ],
                ),
              ),
              if (notif.isNew)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms, duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildAvatar(AppNotification notif, bool blurIdentity) {
    if (blurIdentity) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppTheme.accent.withOpacity(0.5), Colors.transparent],
                radius: 1.0,
              ),
            ),
          ),
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent.withOpacity(0.5), width: 1.5),
                  color: Colors.white10,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.visibility_off_rounded, color: AppTheme.accent, size: 20),
              ),
            ),
          ),
        ],
      );
    }

    if (notif.relatedUser != null) {
      final user = notif.relatedUser!;
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: user.profileImageUrl != null
              ? DecorationImage(image: NetworkImage(user.profileImageUrl!), fit: BoxFit.cover)
              : null,
          border: Border.all(color: AppTheme.border, width: 1),
          color: AppTheme.surface2,
        ),
        alignment: Alignment.center,
        child: user.profileImageUrl == null ? Text(user.avatar, style: const TextStyle(fontSize: 24)) : null,
      );
    }

    // System icon fallback
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surface3.withOpacity(0.5),
        border: Border.all(color: Colors.white12),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
    );
  }

  Widget _buildMessageText(AppNotification notif, bool blurIdentity) {
    if (notif.type == NotificationType.look) {
      return const Text(
        'Biri sana göz kırptı!',
        style: TextStyle(
          fontSize: 15,
          color: AppTheme.accent,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (notif.type == NotificationType.match) {
      return RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.3),
          children: [
            TextSpan(
              text: '${notif.relatedUser?.name ?? 'Biri'} ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
            ),
            const TextSpan(text: 'ile eşleştin! Karşılıklı göz teması kuruldu.'),
          ],
        ),
      );
    }

    if (notif.type == NotificationType.message) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.3),
              children: [
                TextSpan(
                  text: '${notif.relatedUser?.name ?? 'Biri'} ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
                const TextSpan(text: 'sana yeni bir mesaj gönderdi:'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"${notif.message}"',
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Text(
      notif.message,
      style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.3),
    );
  }

  Widget _buildLookAction(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          // Go to radar
          final provider = Provider.of<AppData>(context, listen: false);
          provider.setTabIndex(0);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radar_rounded, size: 14, color: AppTheme.accent),
              SizedBox(width: 8),
              Text(
                'Radarda Bul',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchAction(BuildContext context, AppNotification notif) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.mediumImpact();
          final appData = Provider.of<AppData>(context, listen: false);
          if (notif.relatedUser != null) {
            final conv = await appData.findOrRefreshConversation(notif.relatedUser!.id);
            if (conv != null && context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversationId: conv.id)));
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Sohbet Aç',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays == 1) return 'dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    if (diff.inDays < 14) return 'geçen hafta';
    return '${time.day}.${time.month}.${time.year}';
  }
}
