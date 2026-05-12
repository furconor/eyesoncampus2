import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_data_provider.dart';
import '../theme/app_theme.dart';
import 'other_profile_screen.dart';

class RadarMapScreen extends StatefulWidget {
  final List<User> users;
  final Venue? venue;

  const RadarMapScreen({super.key, required this.users, this.venue});

  @override
  State<RadarMapScreen> createState() => _RadarMapScreenState();
}

class _RadarMapScreenState extends State<RadarMapScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset> _panNotifier = ValueNotifier(Offset.zero);
  static const double _maxPan = 340.0;

  User? _selectedUser;
  bool _isDragging = false;
  double _totalDrag = 0;

  late final AnimationController _radarCtrl;
  late final List<Offset> _worldPositions;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _worldPositions = List.generate(widget.users.length, (i) {
      final rng = math.Random(widget.users[i].id.hashCode ^ (i * 7919));
      final angle = rng.nextDouble() * 2 * math.pi;
      final radius = 70.0 + rng.nextDouble() * 300.0;
      return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    });
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _panNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    final imageUrl = widget.venue?.imageUrl;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanStart: (_) {
          _isDragging = false;
          _totalDrag = 0;
        },
        onPanUpdate: (d) {
          _totalDrag += d.delta.distance;
          if (_totalDrag > 4) _isDragging = true;
          final cur = _panNotifier.value;
          _panNotifier.value = Offset(
            (cur.dx + d.delta.dx).clamp(-_maxPan, _maxPan),
            (cur.dy + d.delta.dy).clamp(-_maxPan, _maxPan),
          );
        },
        onTap: () {
          if (!_isDragging) setState(() => _selectedUser = null);
        },
        child: Stack(
          children: [
            // ── Layer 1: Venue photo (never rebuilds) ──
            if (imageUrl != null)
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0A0A0A)),
                ),
              )
            else
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFF0A0A0A)),
              ),

            // ── Layer 2: Dark overlay (never rebuilds) ──
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(imageUrl != null ? 0.52 : 0.80),
              ),
            ),

            // ── Layer 3: Radar rings (never rebuild) ──
            for (int i = 0; i < 4; i++)
              Center(
                child: SizedBox(
                  width: (i + 1) * 90.0,
                  height: (i + 1) * 90.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.12 + 0.04 * (4 - i)),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Layer 4: Radar sweep (animated, isolated) ──
            Center(
              child: AnimatedBuilder(
                animation: _radarCtrl,
                builder: (_, __) => Transform.rotate(
                  angle: _radarCtrl.value * 2 * math.pi,
                  child: SizedBox(
                    width: 380,
                    height: 380,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.transparent,
                            AppTheme.accent.withOpacity(0.03),
                            AppTheme.accent.withOpacity(0.30),
                          ],
                          stops: const [0.0, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Layer 5: Users (pan-reactive via ValueListenableBuilder only) ──
            ValueListenableBuilder<Offset>(
              valueListenable: _panNotifier,
              builder: (ctx, pan, __) => Stack(
                children: [
                  for (int i = 0; i < widget.users.length; i++)
                    _buildUserDot(i, center, pan, size),
                ],
              ),
            ),

            // ── Layer 6: Center dot ──
            Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent,
                  boxShadow: [
                    BoxShadow(color: AppTheme.accent.withOpacity(0.55), blurRadius: 12),
                  ],
                ),
              ),
            ),

            // ── Layer 7: Top bar ──
            Positioned(
              top: topPad + 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.60),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
                    ),
                  ),
                  if (widget.venue != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          widget.venue!.name,
                          style: const TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 11,
                            color: Colors.white70,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '${widget.users.length} KİŞİ',
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Layer 8: Selected user card ──
            if (_selectedUser != null)
              Positioned(
                bottom: 32,
                left: 20,
                right: 20,
                child: _buildSelectedCard(_selectedUser!),
              )
            else
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Kaydır · kişiye dokun',
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.28),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDot(int i, Offset center, Offset pan, Size screenSize) {
    final user = widget.users[i];
    final worldPos = _worldPositions[i];
    final screenPos = center + worldPos + pan;

    if (screenPos.dx < -40 ||
        screenPos.dx > screenSize.width + 40 ||
        screenPos.dy < -40 ||
        screenPos.dy > screenSize.height + 40) {
      return const SizedBox.shrink();
    }

    final isSelected = _selectedUser?.id == user.id;
    final sz = isSelected ? 52.0 : 44.0;

    return Positioned(
      left: screenPos.dx - sz / 2,
      top: screenPos.dy - sz / 2,
      child: GestureDetector(
        onTap: () {
          if (!_isDragging) {
            HapticFeedback.lightImpact();
            setState(() => _selectedUser = isSelected ? null : user);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surface3,
            border: Border.all(
              color: isSelected ? AppTheme.accent : Colors.white38,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: AppTheme.accent.withOpacity(0.45), blurRadius: 14)]
                : null,
            image: user.profileImageUrl != null
                ? DecorationImage(
                    image: NetworkImage(user.profileImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: user.profileImageUrl == null
              ? Text(user.avatar, style: TextStyle(fontSize: isSelected ? 24 : 20))
              : null,
        ),
      ),
    );
  }

  Widget _buildSelectedCard(User user) {
    final provider = Provider.of<AppData>(context, listen: false);
    final alreadyWinked = provider.hasSentInterest(user.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEE141414),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 24)],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface3,
              border: Border.all(color: Colors.white24),
              image: user.profileImageUrl != null
                  ? DecorationImage(image: NetworkImage(user.profileImageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: user.profileImageUrl == null
                ? Text(user.avatar, style: const TextStyle(fontSize: 22))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  user.department,
                  style: const TextStyle(fontFamily: 'Space Mono', fontSize: 9, color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OtherProfileScreen(user: user)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'Profil',
                style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: alreadyWinked
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    final error = await provider.sendInterest(user.id);
                    if (!mounted) return;
                    if (error != null) {
                      _showToast(error, isError: true);
                    } else {
                      _showToast('Göz kırptın!  −1 ⚡');
                      setState(() {});
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: alreadyWinked
                    ? Colors.white.withOpacity(0.04)
                    : AppTheme.accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: alreadyWinked
                      ? Colors.white12
                      : AppTheme.accent.withOpacity(0.55),
                ),
              ),
              child: Text(
                alreadyWinked ? '👁️' : '😉',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? const Color(0xFF5C1A1A) : AppTheme.surface2,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2500),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }
}
