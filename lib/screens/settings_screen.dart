import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import 'auth_screen.dart'; import 'edit_profile_screen.dart';
import 'legal_screen.dart';
import 'blocked_users_screen.dart';

import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifLook = true;
  bool _notifMatch = true;

  @override
  void initState() {
    super.initState();
    // Default to provider values if available
    final provider = Provider.of<AppData>(context, listen: false);
    if (provider.currentUser != null) {
      _notifLook = provider.currentUser!.notifLook;
      _notifMatch = provider.currentUser!.notifMatch;
    } else {
      _loadNotifPrefs();
    }
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifLook = prefs.getBool('notifLook') ?? true;
      _notifMatch = prefs.getBool('notifMatch') ?? true;
    });
  }

  Future<void> _saveNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı açılamadı: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: Text(
          provider.t('settings').toUpperCase(), 
          style: const TextStyle(
            fontFamily: 'Space Mono', 
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppTheme.text,
          )
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildLangSwitch(provider),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 16),
            _buildGroupTitle(provider.t('account')),
            _buildSettingItem(
              icon: Icons.person_outline,
              iconBgColor: AppTheme.accent.withOpacity(0.1),
              title: provider.t('edit_profile'),
              subtitle: provider.t('profile_name_desc'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              },
            ),
            _buildSettingItem(
              icon: Icons.school_outlined,
              iconBgColor: AppTheme.blue.withOpacity(0.1),
              title: provider.t('university_verify'),
              subtitle: provider.t('edu_email'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  provider.t('verified').toUpperCase(),
                  style: const TextStyle(fontFamily: 'Space Mono', fontSize: 8, color: AppTheme.accent, fontWeight: FontWeight.bold),
                ),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: AppTheme.surface,
                  content: Text(provider.t('edu_verified'), style: const TextStyle(color: AppTheme.text))
                ));
              },
            ),
            
            _buildGroupTitle(provider.t('privacy')),
            _buildSettingItem(
              icon: Icons.block_flipped,
              iconBgColor: AppTheme.red.withOpacity(0.1),
              title: provider.t('blocked'),
              subtitle: provider.t('blocked_desc'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen()));
              },
            ),
 
            _buildGroupTitle(provider.t('notifs')),
            _buildToggleItem(
              icon: Icons.notifications_none_outlined,
              iconBgColor: AppTheme.accent.withOpacity(0.1),
              title: provider.t('look_notif'),
              value: _notifLook,
              onChanged: (v) {
                setState(() => _notifLook = v);
                provider.updateNotifSettings(v, _notifMatch);
              },
            ),
            _buildToggleItem(
              icon: Icons.auto_awesome_outlined,
              iconBgColor: AppTheme.accent.withOpacity(0.1),
              title: provider.t('match_notif'),
              value: _notifMatch,
              onChanged: (v) {
                setState(() => _notifMatch = v);
                provider.updateNotifSettings(_notifLook, v);
              },
            ),
 
            _buildGroupTitle(provider.t('general')),
            _buildSettingItem(
              icon: Icons.headset_mic_outlined,
              iconBgColor: AppTheme.muted.withOpacity(0.1),
              title: provider.t('contact_us'),
              onTap: () => _launchURL('mailto:eyesonmecorp@gmail.com?subject=Destek Talebi'),
            ),
            _buildSettingItem(
              icon: Icons.lock_outline,
              iconBgColor: AppTheme.muted.withOpacity(0.1),
              title: provider.t('privacy_policy'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(
                  title: provider.currentLanguage == 'tr' ? 'Gizlilik Politikası' : 'Privacy Policy',
                  content: provider.currentLanguage == 'tr' ? LegalScreen.privacyContent : LegalScreen.privacyContentEn,
                )));
              },
            ),
            _buildSettingItem(
              icon: Icons.description_outlined,
              iconBgColor: AppTheme.muted.withOpacity(0.1),
              title: provider.t('eula'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(
                  title: provider.currentLanguage == 'tr' ? 'Kullanım Şartları (EULA)' : 'Terms of Use (EULA)',
                  content: provider.currentLanguage == 'tr' ? LegalScreen.eulaContent : LegalScreen.eulaContentEn,
                )));
              },
            ),
            
            const SizedBox(height: 32),
            _buildSettingItem(
              icon: Icons.logout_outlined,
              iconBgColor: AppTheme.red.withOpacity(0.1),
              title: provider.t('logout'),
              titleColor: AppTheme.red.withOpacity(0.8),
              onTap: () {
                provider.logout();
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false
                );
              },
            ),
            _buildSettingItem(
              icon: Icons.warning_amber_rounded,
              iconBgColor: AppTheme.red.withOpacity(0.2),
              title: provider.t('delete_account'),
              titleColor: AppTheme.red,
              onTap: () => _showDeleteAccountDialog(context),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLangSwitch(AppData provider) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surface3.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmallLangBtn('TR', provider.currentLanguage == 'tr', () => provider.setLanguage('tr')),
          _buildSmallLangBtn('EN', provider.currentLanguage == 'en', () => provider.setLanguage('en')),
        ],
      ),
    );
  }

  Widget _buildSmallLangBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: active ? [
            BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontFamily: 'Space Mono',
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : AppTheme.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 10,
          letterSpacing: 2,
          color: AppTheme.muted,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: titleColor ?? AppTheme.text),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.w600, 
                          color: titleColor ?? AppTheme.text,
                          fontFamily: 'Space Mono',
                        )
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 10,
                            color: AppTheme.muted.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing
                else if (onTap != null)
                  Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.muted.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppTheme.text),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title, 
              style: const TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.w600, 
                color: AppTheme.text,
                fontFamily: 'Space Mono',
              )
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          Provider.of<AppData>(context, listen: false).t('delete_account'), 
          style: const TextStyle(color: AppTheme.red, fontFamily: 'Cormorant Garamond', fontSize: 24, fontWeight: FontWeight.bold)
        ),
        content: const Text(
          'Hesabını ve tüm verilerini (eşleşmeler, mesajlar) kalıcı olarak silmek istediğine emin misin? Bu işlem geri alınamaz.',
          style: TextStyle(color: AppTheme.muted, fontFamily: 'Space Mono', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: AppTheme.text, fontFamily: 'Space Mono', fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await Provider.of<AppData>(context, listen: false).deleteAccount();
              if (success) {
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (_) => const AuthScreen()), 
                    (route) => false
                  );
                }
              }
            },
            child: const Text('EVET, SİL', style: TextStyle(fontFamily: 'Space Mono', fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
