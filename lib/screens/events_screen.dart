import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/create_event_sheet.dart';
import '../widgets/point_notification_overlay.dart';
import 'other_profile_screen.dart';
import 'event_chat_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppData>().loadEvents();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppData>(
      builder: (context, provider, child) {
        final allEvents = List<Event>.from(provider.events);
        
        Event? topEvent;
        List<Event> remainingEvents = [];

        if (allEvents.isNotEmpty) {
          final joinedEvents = allEvents.where((e) => e.isJoined).toList();
          if (joinedEvents.isNotEmpty) {
            topEvent = joinedEvents.first;
          } else {
            allEvents.sort((a, b) => b.attendeesCount.compareTo(a.attendeesCount));
            topEvent = allEvents.first;
          }
          
          remainingEvents = allEvents.where((e) => e.id != topEvent!.id).toList();
          remainingEvents.sort((a, b) => b.attendeesCount.compareTo(a.attendeesCount));
        }

        return Scaffold(
          backgroundColor: Colors.black, // Dark premium background
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 90.0),
            child: FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.lightImpact();
                _showCreateEventSheet(context);
              },
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              elevation: 8,
              icon: const Icon(Icons.add_rounded, size: 24),
              label: const Text(
                'BAŞLAT',
                style: TextStyle(fontFamily: 'Space Mono', fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              setState(() => _isLoading = true);
              await provider.loadEvents();
              if (mounted) setState(() => _isLoading = false);
            },
            color: AppTheme.accent,
            backgroundColor: AppTheme.surface2,
            child: SafeArea(
              child: _isLoading
                ? _buildLoadingState()
                : allEvents.isEmpty 
                ? _buildEmptyState(provider)
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(provider),
                            const SizedBox(height: 20),
                            if (topEvent != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: _buildMainEventCard(context, topEvent, provider),
                              ),
                              const SizedBox(height: 32),
                            ],
                            if (remainingEvents.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: _buildSectionTitle(provider.t('other_events') ?? 'DİĞER ETKİNLİKLER'),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                      if (remainingEvents.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final e = remainingEvents[index];
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    _showEventDetail(context, e, provider);
                                  },
                                  child: _buildOtherEventCard(e).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0),
                                );
                              },
                              childCount: remainingEvents.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.accent),
    );
  }

  Widget _buildEmptyState(AppData provider) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.celebration_rounded, size: 64, color: Colors.white10),
                const SizedBox(height: 24),
                Text(
                  provider.t('no_events').toUpperCase(),
                  style: const TextStyle(fontFamily: 'Space Mono', fontSize: 14, letterSpacing: 2, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),
        ),
      ],
    );
  }

  Widget _buildHeader(AppData provider) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Center(
        child: Text(
          'Etkinlikler',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Space Mono',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: AppTheme.accent,
        letterSpacing: 2,
      ),
    ).animate().fadeIn();
  }

  Widget _buildMainEventCard(BuildContext context, Event event, AppData provider) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (event.isJoined) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventChatScreen(event: event)));
        } else {
          _showEventDetail(context, event, provider);
        }
      },
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: event.isJoined ? AppTheme.accent.withOpacity(0.5) : Colors.white10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
            if (event.isJoined) BoxShadow(color: AppTheme.accent.withOpacity(0.1), blurRadius: 30, spreadRadius: -5),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                Image.network(
                  event.imageUrl!, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildEventPlaceholder(event.category, false),
                )
              else
                _buildEventPlaceholder(event.category, false),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent, Colors.black.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_rounded, size: 12, color: AppTheme.accent),
                              const SizedBox(width: 6),
                              Text('${event.attendeesCount}', style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                        if (event.isJoined)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.accent),
                            ),
                            child: const Text('KATILDIN', style: TextStyle(fontFamily: 'Space Mono', fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accent, letterSpacing: 1)),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      event.title,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(fontFamily: 'Space Mono', fontSize: 11, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildOtherEventCard(Event event) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Image.network(
                event.imageUrl!, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildEventPlaceholder(event.category, true),
              )
            else
              _buildEventPlaceholder(event.category, true),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_rounded, size: 10, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text('${event.attendeesCount}', style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.location,
                    style: const TextStyle(fontFamily: 'Space Mono', fontSize: 9, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateEventSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateEventSheet(),
    );
  }

  void _showEventDetail(BuildContext context, Event event, AppData provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildEventDetailSheet(context, event, provider),
    );
  }

  Widget _buildEventDetailSheet(BuildContext context, Event event, AppData provider) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                      SizedBox(
                        height: 250,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          child: Image.network(
                            event.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildEventPlaceholder(event.category, false),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 250,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          child: _buildEventPlaceholder(event.category, false),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${event.attendeesCount} KATILIMCI',
                                  style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            event.title,
                            style: const TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 20, color: AppTheme.accent),
                              const SizedBox(width: 12),
                              Text(event.location, style: const TextStyle(fontSize: 16, color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 20, color: Colors.white54),
                              const SizedBox(width: 12),
                              Text('${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontFamily: 'Space Mono', fontSize: 14, color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'AÇIKLAMA',
                            style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppTheme.accent),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            event.description,
                            style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 10,
                shadowColor: AppTheme.accent.withOpacity(0.4),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final success = await provider.joinEvent(event.id, true);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EventChatScreen(event: event)));
                  } else {
                    // Check if there's a time conflict
                    final joined = provider.events.where((e) => e.isJoined && e.id != event.id).toList();
                    final hasConflict = joined.any((e) {
                      if (e.startAt == null || e.endAt == null || event.startAt == null || event.endAt == null) return false;
                      return e.startAt!.isBefore(event.endAt!) && e.endAt!.isAfter(event.startAt!);
                    });
                    final msg = hasConflict
                        ? 'Bu etkinlik, katıldığın başka bir etkinlikle çakışıyor!'
                        : 'Katılamadın, lütfen tekrar dene.';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.red));
                  }
                }
              },
              child: const Text('KATIL VE SOHBETE GİR', style: TextStyle(fontFamily: 'Space Mono', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              children: [
                if (event.createdBy == provider.currentUser?.id)
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Etkinliği İptal Et', style: TextStyle(color: Colors.white, fontFamily: 'Cormorant Garamond', fontSize: 22, fontWeight: FontWeight.bold)),
                          content: const Text(
                            'Bu etkinliği tamamen iptal etmek ve kaldırmak istediğine emin misin?',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Hayır', style: TextStyle(color: Colors.white54)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Evet, Kaldır', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final success = await provider.finishEvent(event.id);
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik kaldırıldı.'), backgroundColor: AppTheme.accent));
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik kaldırılamadı.'), backgroundColor: AppTheme.red));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.red),
                    ),
                  ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventPlaceholder(String? category, bool isSmall) {
    List<Color> colors;
    IconData icon;
    
    switch (category) {
      case 'Social':
        colors = [const Color(0xFF6B11FF), const Color(0xFF120033)];
        icon = Icons.people_alt_rounded;
        break;
      case 'Sports':
        colors = [const Color(0xFFFF4D4D), const Color(0xFF330000)];
        icon = Icons.sports_basketball_rounded;
        break;
      case 'Study':
        colors = [const Color(0xFF007BFF), const Color(0xFF001A33)];
        icon = Icons.menu_book_rounded;
        break;
      case 'Food':
        colors = [const Color(0xFFFF9900), const Color(0xFF331A00)];
        icon = Icons.restaurant_rounded;
        break;
      case 'Games':
        colors = [const Color(0xFF00E676), const Color(0xFF003311)];
        icon = Icons.sports_esports_rounded;
        break;
      default:
        colors = [AppTheme.accent, const Color(0xFF1A1A00)];
        icon = Icons.celebration_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white.withOpacity(0.15), size: isSmall ? 64 : 140),
      ),
    );
  }
}
