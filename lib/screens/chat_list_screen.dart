import 'dart:io';
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

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    final allConvs = provider.conversations;
    
    // Search Logic
    final List<Conversation> peopleResults = _searchQuery.isEmpty 
        ? allConvs 
        : allConvs.where((c) => c.otherUser.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final List<Map<String, dynamic>> messageResults = [];
    if (_searchQuery.isNotEmpty) {
      for (var c in allConvs) {
        for (var m in c.messages) {
          if (m.text.toLowerCase().contains(_searchQuery.toLowerCase())) {
            messageResults.add({
              'conv': c,
              'msg': m,
            });
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black, // Premium Dark Background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(provider),
            Expanded(
              child: _searchQuery.isEmpty 
                ? (peopleResults.isEmpty 
                    ? _buildEmptyState(provider)
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 100),
                        physics: const BouncingScrollPhysics(),
                        itemCount: peopleResults.length,
                        itemBuilder: (context, index) {
                          return _buildChatListItem(context, peopleResults[index], index);
                        },
                      ))
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      if (peopleResults.isNotEmpty) ...[
                        _buildSearchSectionHeader('KİŞİLER'),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildChatListItem(context, peopleResults[index], index),
                            childCount: peopleResults.length,
                          ),
                        ),
                      ],
                      if (messageResults.isNotEmpty) ...[
                        _buildSearchSectionHeader('MESAJLAR'),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final res = messageResults[index];
                              return _buildMessageSearchResultItem(context, res['conv'], res['msg'], index);
                            },
                            childCount: messageResults.length,
                          ),
                        ),
                      ],
                      if (peopleResults.isEmpty && messageResults.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'SONUÇ BULUNAMADI',
                              style: TextStyle(fontFamily: 'Space Mono', color: Colors.white24, letterSpacing: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppData provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 24),
          Text(
            provider.t('no_chats_yet').toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 12,
              letterSpacing: 2,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildHeader(AppData provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Sohbetler',
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontFamily: 'Space Mono', fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Mesaj veya kişi ara...',
                hintStyle: const TextStyle(fontFamily: 'Space Mono', fontSize: 13, color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accent, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildSearchSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildChatListItem(BuildContext context, Conversation conv, int index) {
    final user = conv.otherUser;
    final lastMsg = conv.lastMessage;
    final bool isOnline = user.isOnline;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatDetailScreen(conversationId: conv.id)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: conv.isNewMatch ? AppTheme.accent.withOpacity(0.5) : Colors.white10,
              width: conv.isNewMatch ? 1.5 : 1.0,
            ),
            boxShadow: conv.isNewMatch ? [
              BoxShadow(color: AppTheme.accent.withOpacity(0.1), blurRadius: 20, spreadRadius: -5)
            ] : null,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface3,
                      border: Border.all(color: Colors.white10, width: 2),
                      image: user.profileImageUrl != null
                          ? DecorationImage(
                              image: user.profileImageUrl!.startsWith('http')
                                  ? NetworkImage(user.profileImageUrl!) as ImageProvider
                                  : FileImage(File(user.profileImageUrl!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: user.profileImageUrl == null ? Text(user.avatar, style: const TextStyle(fontSize: 28)) : null,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface2, width: 3),
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
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        if (conv.isNewMatch)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'YENİ',
                              style: TextStyle(fontFamily: 'Space Mono', fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.accent, letterSpacing: 1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lastMsg != null ? lastMsg.text : 'Eşleşme sağlandı! İlk mesajı gönder.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: conv.unreadCount > 0 ? Colors.white : Colors.white54,
                        fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (lastMsg != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(lastMsg.timestamp),
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 10,
                        color: conv.unreadCount > 0 ? AppTheme.accent : Colors.white38,
                        fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (conv.unreadCount > 0)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildMessageSearchResultItem(BuildContext context, Conversation conv, AppMessage msg, int index) {
    String text = msg.text;
    int idx = text.toLowerCase().indexOf(_searchQuery.toLowerCase());
    int start = (idx - 20).clamp(0, text.length);
    int end = (idx + _searchQuery.length + 30).clamp(0, text.length);
    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatDetailScreen(conversationId: conv.id)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: conv.otherUser.profileImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(conv.otherUser.profileImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: AppTheme.surface3,
                ),
                alignment: Alignment.center,
                child: conv.otherUser.profileImageUrl == null ? Text(conv.otherUser.avatar) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.otherUser.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: Colors.white54),
                        children: [
                          TextSpan(text: snippet.substring(0, snippet.toLowerCase().indexOf(_searchQuery.toLowerCase()) + (start > 0 ? 3 : 0))),
                          TextSpan(
                            text: _searchQuery,
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: snippet.substring(snippet.toLowerCase().indexOf(_searchQuery.toLowerCase()) + _searchQuery.length + (start > 0 ? 3 : 0))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${msg.timestamp.day}/${msg.timestamp.month}',
                style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}/${time.month}';
  }
}
