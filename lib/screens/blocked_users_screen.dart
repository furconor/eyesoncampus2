import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/supabase_service.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<User> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    final sb = SupabaseService();
    final users = await sb.getBlockedUsers();
    if (mounted) {
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _unblock(User user) async {
    // Optimistic UI: önce listeden çıkar
    setState(() {
      _blockedUsers.removeWhere((u) => u.id == user.id);
    });

    final provider = Provider.of<AppData>(context, listen: false);
    final success = await provider.unblockUser(user.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text(
            '${user.name} engeli kaldırıldı.',
            style: const TextStyle(color: AppTheme.text, fontFamily: 'Space Mono', fontSize: 12),
          ),
        ),
      );
    } else {
      // Geri al
      setState(() {
        _blockedUsers.add(user);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Engel kaldırılamadı. Tekrar deneyin.',
            style: TextStyle(color: Colors.white, fontFamily: 'Space Mono', fontSize: 12),
          ),
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          provider.t('blocked').toUpperCase(), 
          style: const TextStyle(
            fontFamily: 'Space Mono', 
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppTheme.text,
          )
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block_flipped, size: 64, color: AppTheme.muted.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        provider.t('no_blocked'), 
                        style: const TextStyle(color: AppTheme.muted, fontFamily: 'Space Mono', fontSize: 12)
                      ),
                    ],
                  )
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface3.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.surface3,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                            ),
                            alignment: Alignment.center,
                            child: user.profileImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Image.network(user.profileImageUrl!, fit: BoxFit.cover, width: 44, height: 44),
                                  )
                                : Text(user.avatar, style: const TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name, 
                                  style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Space Mono')
                                ),
                                Text(
                                  user.university, 
                                  style: TextStyle(color: AppTheme.muted.withOpacity(0.7), fontSize: 10, fontFamily: 'Space Mono')
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _unblock(user),
                            style: TextButton.styleFrom(
                              backgroundColor: AppTheme.red.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            child: Text(
                              provider.currentLanguage == 'tr' ? 'KALDIR' : 'REMOVE', 
                              style: const TextStyle(color: AppTheme.red, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Space Mono')
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
