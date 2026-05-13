import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../providers/app_data_provider.dart';
import '../models/app_models.dart';
import 'venue_detail_screen.dart';
import '../widgets/glass_container.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    
    // Sort venues by heatLevel (trending first)
    final sortedVenues = List<Venue>.from(provider.filteredVenues)
      ..sort((a, b) => b.heatLevel.compareTo(a.heatLevel));

    return Scaffold(
      backgroundColor: Colors.black, // Deep dark background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(provider),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => provider.refreshVenues(),
                color: AppTheme.accent,
                backgroundColor: AppTheme.surface,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (sortedVenues.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildPremiumVenueCard(context, provider, sortedVenues[index], index);
                            },
                            childCount: sortedVenues.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppData provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Kampüsü Keşfet',
              style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surface3.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppTheme.muted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => provider.setVenueSearchQuery(val),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Mekan ara...',
                      hintStyle: TextStyle(color: AppTheme.muted2, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      provider.setVenueSearchQuery('');
                    },
                    child: const Icon(Icons.close_rounded, color: AppTheme.muted, size: 18),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumVenueCard(BuildContext context, AppData provider, Venue venue, int index) {
    final isCheckedIn = provider.currentUser?.campusZone == venue.name;
    final peopleCount = provider.getVenuePeopleCount(venue.name);
    
    // Determine heat color based on people count relative to capacity (mocked logic)
    Color heatColor;
    String heatLabel;
    if (peopleCount > 15 || venue.heatLevel > 80) {
      heatColor = AppTheme.red; // Very Hot
      heatLabel = 'ÇOK KALABALIK';
    } else if (peopleCount > 5 || venue.heatLevel > 40) {
      heatColor = Colors.orange; // Medium
      heatLabel = 'HAREKETLİ';
    } else {
      heatColor = AppTheme.accent; // Low/Chill
      heatLabel = 'SAKİN';
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: venue)));
      },
      child: Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppTheme.surface2,
          image: venue.imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(venue.imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Dark Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Top Right: Heat Indicator
            Positioned(
              top: 16,
              right: 16,
              child: GlassContainer(
                borderRadius: BorderRadius.circular(20),
                opacity: 0.2,
                blur: 10,
                border: Border.all(color: Colors.white24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: heatColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: heatColor.withOpacity(0.8), blurRadius: 6, spreadRadius: 2),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat()).fade(duration: 800.ms, begin: 0.4, end: 1.0).then().fade(duration: 800.ms, begin: 1.0, end: 0.4),
                      const SizedBox(width: 6),
                      Text(
                        heatLabel,
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: heatColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Content
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue.name,
                          style: const TextStyle(
                            fontFamily: 'Cormorant Garamond',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.group_rounded, color: AppTheme.muted, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '$peopleCount Kişi Burada',
                              style: const TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 12,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Check-in / Primary Action Button
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      if (isCheckedIn) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: venue)));
                      } else {
                        // Attempt to check in right here
                        final error = await provider.checkIn(venue);
                        if (context.mounted) {
                          if (error != null) {
                            if (error.contains('enerjin')) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: AppTheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  title: const Column(
                                    children: [
                                      Icon(Icons.bolt_rounded, color: AppTheme.accent, size: 48),
                                      SizedBox(height: 16),
                                      Text('Enerjin Bitti!', style: TextStyle(color: Colors.white, fontFamily: 'Cormorant Garamond', fontSize: 28, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: const Text(
                                    'Mekan değiştirmek için yeterli enerjin (PWR) kalmadı. Enerjinin dolmasını bekleyebilir veya kampüs etkinliklerine katılarak enerji kazanabilirsin.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                                  ),
                                  actions: [
                                    Center(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          backgroundColor: AppTheme.surface2,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Anladım', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontFamily: 'Space Mono')),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.red));
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mekana giriş yapıldı!'), backgroundColor: AppTheme.accent));
                          }
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCheckedIn ? AppTheme.surface3.withOpacity(0.5) : AppTheme.accent,
                        borderRadius: BorderRadius.circular(16),
                        border: isCheckedIn ? Border.all(color: AppTheme.border) : null,
                        boxShadow: isCheckedIn ? null : [
                          BoxShadow(
                            color: AppTheme.accent.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Text(
                        isCheckedIn ? 'Görüntüle' : 'Buradayım',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCheckedIn ? Colors.white : Colors.black,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 100).ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: AppTheme.muted2),
          const SizedBox(height: 16),
          const Text(
            'MEKAN BULUNAMADI',
            style: TextStyle(fontFamily: 'Space Mono', fontSize: 14, color: AppTheme.muted2, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}
