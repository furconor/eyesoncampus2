import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';
import '../utils/content_filter.dart';
import '../widgets/glass_container.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _deptController;
  late TextEditingController _yearController;
  List<String> _interests = [];
  String? _profileImageUrl;
  Uint8List? _avatarBytes;
  String? _avatarExt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final me = Provider.of<AppData>(context, listen: false).currentUser!;
    _nameController = TextEditingController(text: me.name);
    _bioController = TextEditingController(text: me.bio);
    _deptController = TextEditingController(text: me.department);
    _yearController = TextEditingController(text: me.year);
    _interests = List.from(me.interests);
    _profileImageUrl = me.profileImageUrl;
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final ext = pickedFile.name.split('.').last;
      setState(() {
        _profileImageUrl = pickedFile.path;
        _avatarBytes = bytes;
        _avatarExt = ext;
      });
    }
  }

  Future<void> _saveProfile() async {
    HapticFeedback.mediumImpact();
    if (_isSaving) return;
    
    final String nameText = _nameController.text;
    final String bioText = _bioController.text;
    final String deptText = _deptController.text;
    final String yearText = _yearController.text;

    if (!ContentFilter.isClean(nameText) || !ContentFilter.isClean(bioText) || !ContentFilter.isClean(deptText) || !ContentFilter.isClean(yearText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ContentFilter.getBlockedMessage(Provider.of<AppData>(context, listen: false).currentLanguage)), backgroundColor: AppTheme.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = Provider.of<AppData>(context, listen: false);
      final updated = provider.currentUser!.copyWith(
        name: _nameController.text,
        bio: _bioController.text,
        department: _deptController.text,
        year: _yearController.text,
        interests: _interests,
        profileImageUrl: _profileImageUrl,
        clearProfileImage: _profileImageUrl == null && provider.currentUser!.profileImageUrl != null,
      );
      
      final success = await provider.updateProfile(updated, avatarBytes: _avatarBytes, avatarExt: _avatarExt);
      
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.t('profile_updated')), backgroundColor: AppTheme.accent, behavior: SnackBarBehavior.floating));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.t('profile_error')), backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addInterest(String val) {
    if (val.trim().isNotEmpty && !_interests.contains(val.trim())) {
      setState(() => _interests.add(val.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    final me = provider.currentUser!;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                ),
                actions: [
                  _isSaving 
                    ? const Padding(padding: EdgeInsets.only(right: 20, top: 20), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
                    : IconButton(
                        icon: const Icon(Icons.check_rounded, color: AppTheme.accent, size: 28),
                        onPressed: _saveProfile,
                      ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Blurred background of the current avatar
                      Container(
                        decoration: BoxDecoration(
                          image: _profileImageUrl != null 
                              ? DecorationImage(
                                  image: _avatarBytes != null 
                                      ? MemoryImage(_avatarBytes!) 
                                      : (_profileImageUrl!.startsWith('http') ? NetworkImage(_profileImageUrl!) : FileImage(File(_profileImageUrl!))) as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Container(color: Colors.black.withOpacity(0.7)),
                      ),
                      _buildAvatarPicker(me),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildSectionTitle('KAMPÜS GÜNLÜĞÜ'),
                      _buildDiaryGrid(provider, me),
                      
                      const SizedBox(height: 40),
                      _buildSectionTitle('HESAP BİLGİLERİ'),
                      GlassContainer(
                        blur: 20,
                        opacity: 0.1,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildTextField(_nameController, 'İsim Soyisim', Icons.person_outline_rounded),
                              const Divider(color: Colors.white10, height: 24),
                              _buildTextField(_deptController, 'Bölüm', Icons.menu_book_rounded),
                              const Divider(color: Colors.white10, height: 24),
                              _buildTextField(_yearController, 'Sınıf', Icons.school_outlined),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('BİYOGRAFİ'),
                      GlassContainer(
                        blur: 20,
                        opacity: 0.1,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildTextField(_bioController, 'Kendinden bahset...', null, maxLines: 4),
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('İLGİ ALANLARI'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          ..._interests.map((i) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(i, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _interests.remove(i));
                                  },
                                  child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.accent),
                                )
                              ],
                            ),
                          )),
                          GestureDetector(
                            onTap: _showAddInterestDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 16, color: Colors.white54),
                                  const SizedBox(width: 4),
                                  Text('EKLE', style: const TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.bold, fontFamily: 'Space Mono')),
                                ],
                              ),
                            ),
                          )
                        ],
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 10,
          letterSpacing: 2,
          color: AppTheme.accent,
          fontWeight: FontWeight.bold,
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildAvatarPicker(User me) {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface2,
              border: Border.all(color: AppTheme.accent, width: 2),
              boxShadow: [
                BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 40, spreadRadius: 5),
              ],
              image: _avatarBytes != null
                  ? DecorationImage(image: MemoryImage(_avatarBytes!), fit: BoxFit.cover)
                  : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: _profileImageUrl!.startsWith('http')
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : FileImage(File(_profileImageUrl!)),
                          fit: BoxFit.cover,
                        )
                      : null),
            ),
            child: (_avatarBytes == null && _profileImageUrl == null)
                ? Center(child: Text(me.avatar, style: const TextStyle(fontSize: 54)))
                : null,
          ),
          if (_profileImageUrl != null)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _profileImageUrl = null;
                    _avatarBytes = null;
                    _avatarExt = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.black),
            ),
          ),
        ],
      ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildDiaryGrid(AppData provider, User me) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        final hasPhoto = index < me.diaryPhotos.length;
        final photoUrl = hasPhoto ? me.diaryPhotos[index] : null;

        return GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            if (!hasPhoto) {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                final bytes = await pickedFile.readAsBytes();
                final ext = pickedFile.name.split('.').last;
                await provider.uploadDiaryPhoto(bytes, ext);
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              image: hasPhoto ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
            ),
            child: Stack(
              children: [
                if (!hasPhoto)
                  const Center(child: Icon(Icons.add_a_photo_rounded, color: Colors.white24, size: 28)),
                if (hasPhoto)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        provider.removeDiaryPhoto(photoUrl!);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(delay: (100 + index * 50).ms),
        );
      },
    );
  }

  void _showAddInterestDialog() {
    HapticFeedback.lightImpact();
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: const Text(
          'İlgi Alanı Ekle', 
          style: TextStyle(color: Colors.white, fontFamily: 'Cormorant Garamond', fontSize: 24, fontWeight: FontWeight.bold)
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontFamily: 'Space Mono'),
          decoration: InputDecoration(
            hintText: 'Örn: Fotoğrafçılık',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('İPTAL', style: TextStyle(color: Colors.white54, fontFamily: 'Space Mono', fontSize: 12, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _addInterest(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('EKLE', style: TextStyle(fontFamily: 'Space Mono', fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData? icon, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 16),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0, left: icon == null ? 12 : 0),
            ),
          ),
        ),
      ],
    );
  }
}
