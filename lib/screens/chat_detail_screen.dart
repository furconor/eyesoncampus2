import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../widgets/glass_container.dart';
import 'package:flutter/services.dart';
import 'other_profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;

  const ChatDetailScreen({super.key, required this.conversationId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  bool _isTyping = false;

  late final StreamSubscription<List<Map<String, dynamic>>> _messagesSubscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Mark as read when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppData>(context, listen: false);
      provider.markConversationAsRead(widget.conversationId);
      provider.refreshMessages(widget.conversationId);
    });

    // Supabase Realtime (Tabloda Realtime açıksa çalışır)
    _messagesSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        Provider.of<AppData>(context, listen: false).refreshMessages(widget.conversationId);
      }
    });

    // Fallback: Realtime kapalıysa diye her 3 saniyede bir manuel kontrol (Polling)
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        Provider.of<AppData>(context, listen: false).refreshMessages(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    _messagesSubscription.cancel();
    _pollingTimer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    
    final text = _msgController.text.trim();
    _msgController.clear();

    final provider = Provider.of<AppData>(context, listen: false);
    await provider.sendMessage(widget.conversationId, text);
    
    // Mesaj gittikten sonra hemen yenile
    provider.refreshMessages(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppData>(
      builder: (context, provider, child) {
        final convIndex = provider.conversations.indexWhere((c) => c.id == widget.conversationId);
        if (convIndex == -1) {
          return const Scaffold(body: Center(child: Text('Sohbet bulunamadı')));
        }
        
        final conv = provider.conversations[convIndex];
        final otherUser = conv.otherUser;
        final me = provider.currentUser!;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, otherUser, conv.locationTag),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          AppTheme.surface2.withOpacity(0.2),
                          AppTheme.bg,
                        ],
                      ),
                    ),
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: conv.messages.length,
                      itemBuilder: (context, index) {
                        final msg = conv.messages[conv.messages.length - 1 - index];
                        return _buildMessageBubble(msg, me.id, index);
                      },
                    ),
                  ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEnlargedAvatar(BuildContext context, User user) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.width * 0.85,
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
            child: user.profileImageUrl == null 
                ? Text(user.avatar, style: const TextStyle(fontSize: 120, decoration: TextDecoration.none, color: AppTheme.text)) 
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User user, String? location) {
    bool isOnline = user.isOnline;
    bool isCheckedIn = user.campusZone != null && user.campusZone != 'Bilinmiyor';

    return GlassContainer(
      blur: 20,
      opacity: 0.1,
      border: Border(bottom: BorderSide(color: AppTheme.border.withOpacity(0.1))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.muted2),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _showEnlargedAvatar(context, user);
              },
              child: Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOnline ? const Color(0xFF4CAF50).withOpacity(0.5) : AppTheme.border.withOpacity(0.2),
                        width: 2,
                      ),
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
                    child: user.profileImageUrl == null ? Text(user.avatar, style: const TextStyle(fontSize: 18)) : null,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.bg, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OtherProfileScreen(user: user)),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 9,
                        color: isOnline ? const Color(0xFF4CAF50) : AppTheme.muted,
                        fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCheckedIn ? AppTheme.accent.withOpacity(0.12) : AppTheme.surface3.withOpacity(0.3),
                border: Border.all(color: isCheckedIn ? AppTheme.accent.withOpacity(0.4) : AppTheme.border.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isCheckedIn ? Icons.location_on : Icons.history, size: 10, color: isCheckedIn ? AppTheme.accent : AppTheme.muted),
                  const SizedBox(width: 6),
                  Text(
                    isCheckedIn ? user.campusZone! : (location ?? 'Bilinmiyor'),
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 9,
                      color: isCheckedIn ? AppTheme.accent : AppTheme.muted,
                      fontWeight: isCheckedIn ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ).animate(target: isCheckedIn ? 1 : 0).shimmer(duration: 2.seconds, color: Colors.white12),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AppMessage msg, String myId, int index) {
    if (msg.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface3.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border.withOpacity(0.3)),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              color: AppTheme.muted2,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    final isMe = msg.senderId == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.accent : AppTheme.surface3,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.black : Colors.white,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 9,
                    color: AppTheme.muted,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    // Simple heuristic: if unreadCount is 0, assume seen
                    (Provider.of<AppData>(context, listen: false).conversations.firstWhere((c) => c.id == widget.conversationId).unreadCount == 0)
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 12,
                    color: (Provider.of<AppData>(context, listen: false).conversations.firstWhere((c) => c.id == widget.conversationId).unreadCount == 0)
                        ? AppTheme.accent
                        : AppTheme.muted,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border(top: BorderSide(color: AppTheme.border.withOpacity(0.2))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface3.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border.withOpacity(0.3)),
                ),
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(fontSize: 15, color: AppTheme.text),
                  maxLines: 4,
                  minLines: 1,
                  onChanged: (val) => setState(() => _isTyping = val.trim().isNotEmpty),
                  decoration: const InputDecoration(
                    hintText: 'Mesaj yaz...',
                    hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_msgController.text.trim().isNotEmpty) {
                  _sendMessage();
                  setState(() => _isTyping = false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _isTyping ? AppTheme.accent : AppTheme.surface3,
                  shape: BoxShape.circle,
                  boxShadow: _isTyping ? [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : null,
                ),
                child: Icon(
                  Icons.send_rounded,
                  size: 22,
                  color: _isTyping ? Colors.black : AppTheme.muted,
                ),
              ),
            ).animate(target: _isTyping ? 1 : 0).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0)),
          ],
        ),
      ),
    );
  }
}
