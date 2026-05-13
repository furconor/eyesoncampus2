import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/glass_container.dart';
import 'package:flutter/services.dart';
import 'other_profile_screen.dart';

class EventChatScreen extends StatefulWidget {
  final Event event;

  const EventChatScreen({super.key, required this.event});

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _msgFocusNode = FocusNode();
  String? _pendingImageUrl;
  bool _isUploadingMedia = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppData>().loadEventMessages(widget.event.id);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _msgFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_isUploadingMedia) return;
    if (_msgController.text.trim().isEmpty && _pendingImageUrl == null) return;
    
    final text = _msgController.text.trim();
    _msgController.clear();
    final imageUrl = _pendingImageUrl;
    setState(() => _pendingImageUrl = null);

    final provider = Provider.of<AppData>(context, listen: false);
    provider.sendEventMessage(widget.event.id, text, imageUrl: imageUrl);
  }

  void _onReply(EventMessage msg) {
    HapticFeedback.lightImpact();
    setState(() {
      _msgController.text = '@${msg.sender.name} ';
      _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
    });
    FocusScope.of(context).requestFocus(_msgFocusNode);
  }

  void _onMoreOptions(EventMessage msg, String myUserId) {
    HapticFeedback.lightImpact();
    final isMe = msg.sender.id == myUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.red),
                title: const Text('Gönderiyi Sil', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi silindi (mock)')));
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: AppTheme.text),
                title: Text('@${msg.sender.name} kullanıcısını engelle', style: const TextStyle(color: AppTheme.text)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı engellendi (mock)')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppTheme.red),
                title: const Text('Şikayet Et', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şikayet gönderildi!')));
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickChatMedia(ImageSource source) async {
    Navigator.pop(context);
    try {
      setState(() => _isUploadingMedia = true);
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final url = await context.read<AppData>().uploadEventMediaBytes(bytes, ext);

      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medya yüklenemedi. Tekrar dene.'),
            backgroundColor: AppTheme.red,
          ),
        );
        return;
      }

      setState(() => _pendingImageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medya seçilemedi: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _onAddPhoto() {
    if (_isUploadingMedia) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.text),
              title: const Text('Kamera', style: TextStyle(color: AppTheme.text)),
              onTap: () {
                _pickChatMedia(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.text),
              title: const Text('Galeri', style: TextStyle(color: AppTheme.text)),
              onTap: () {
                _pickChatMedia(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppData>(
      builder: (context, provider, child) {
        final messages = provider.getEventMessages(widget.event.id);
        final me = provider.currentUser!;
        // Sort messages: newest first
        final reversedMessages = List<EventMessage>.from(messages).reversed.toList();

        return Scaffold(
          backgroundColor: AppTheme.bg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, provider),
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: reversedMessages.isEmpty
                        ? const Center(
                            child: Text(
                              'Henüz mesaj yok.\nİlk mesajı sen at!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white24, fontSize: 14, height: 1.6),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            itemCount: reversedMessages.length,
                            itemBuilder: (context, index) {
                              final msg = reversedMessages[index];
                              return _buildFeedPost(msg, me.id, index, provider);
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

  Widget _buildHeader(BuildContext context, AppData provider) {
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent.withOpacity(0.5), width: 2),
                image: widget.event.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: widget.event.imageUrl.startsWith('http')
                            ? NetworkImage(widget.event.imageUrl) as ImageProvider
                            : FileImage(File(widget.event.imageUrl)),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: AppTheme.surface3,
              ),
              alignment: Alignment.center,
              child: widget.event.imageUrl.isEmpty ? const Icon(Icons.event, color: AppTheme.accent) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 10, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.event.attendeesCount} Kişi',
                        style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: AppTheme.accent.withOpacity(0.8), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Builder(builder: (context) {
              final isCreator = provider.currentUser?.id == widget.event.createdBy;
              final buttonText = isCreator ? 'Bitir' : 'Ayrıl';
              final dialogTitle = isCreator ? 'Etkinliği Bitir' : 'Etkinlikten Ayrıl';
              final dialogContent = isCreator
                  ? '"${widget.event.title}" etkinliğini bitirmek istediğine emin misin?'
                  : '"${widget.event.title}" etkinliğinden ayrılmak istediğine emin misin?';

              return GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(dialogTitle, style: const TextStyle(color: Colors.white, fontFamily: 'Cormorant Garamond', fontSize: 22, fontWeight: FontWeight.bold)),
                      content: Text(
                        dialogContent,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Hayır', style: TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(buttonText, style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    if (isCreator) {
                      await provider.finishEvent(widget.event.id);
                    } else {
                      await provider.joinEvent(widget.event.id, false);
                    }
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.red.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isCreator ? Icons.stop_circle_outlined : Icons.logout_rounded, size: 14, color: AppTheme.red),
                      const SizedBox(width: 5),
                      Text(buttonText, style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.red)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedPost(EventMessage msg, String myUserId, int index, AppData provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => OtherProfileScreen(user: msg.sender)));
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
                image: msg.sender.profileImageUrl != null
                    ? DecorationImage(
                        image: msg.sender.profileImageUrl!.startsWith('http')
                            ? NetworkImage(msg.sender.profileImageUrl!) as ImageProvider
                            : FileImage(File(msg.sender.profileImageUrl!)),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: AppTheme.surface3,
              ),
              alignment: Alignment.center,
              child: msg.sender.profileImageUrl == null ? Text(msg.sender.avatar, style: const TextStyle(fontSize: 22)) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            msg.sender.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '@${msg.sender.name.toLowerCase().replaceAll(' ', '')}',
                            style: const TextStyle(fontSize: 13, color: Colors.white54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${_formatTime(msg.timestamp)}',
                            style: const TextStyle(fontFamily: 'Space Mono', fontSize: 11, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
                      onPressed: () => _onMoreOptions(msg, myUserId),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  msg.text,
                  style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                ),
                if (msg.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      msg.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _onReply(msg),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white38),
                          const SizedBox(width: 6),
                          Text(
                            '${msg.repliesCount}',
                            style: const TextStyle(fontFamily: 'Space Mono', fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 20).ms, duration: 200.ms);
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border(top: BorderSide(color: AppTheme.border.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface3.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border.withOpacity(0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isUploadingMedia)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Medya yükleniyor...',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_pendingImageUrl != null)
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 100,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            image: DecorationImage(
                              image: NetworkImage(_pendingImageUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _pendingImageUrl = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.add_photo_alternate_outlined, color: _pendingImageUrl != null ? AppTheme.muted : AppTheme.accent),
                        onPressed: _isUploadingMedia ? null : _onAddPhoto,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          focusNode: _msgFocusNode,
                          style: const TextStyle(fontSize: 14, color: AppTheme.text),
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Neler oluyor?',
                            hintStyle: TextStyle(fontSize: 14, color: AppTheme.muted.withOpacity(0.5)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _sendMessage();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.send_rounded, color: Color(0xFF0A0800), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
