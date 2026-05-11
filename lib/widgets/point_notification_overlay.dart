import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';

class PointNotificationOverlay extends StatefulWidget {
  final int amount;
  final String reason;
  final VoidCallback onComplete;

  const PointNotificationOverlay({
    super.key,
    required this.amount,
    required this.reason,
    required this.onComplete,
  });

  @override
  State<PointNotificationOverlay> createState() => _PointNotificationOverlayState();
}

class _PointNotificationOverlayState extends State<PointNotificationOverlay> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _confettiController.play();
    
    // Auto-remove after animation
    Future.delayed(const Duration(seconds: 2), widget.onComplete);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.amber, Colors.orange, Colors.yellow, Colors.white],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.amber, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on, color: Colors.amber, size: 28),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${widget.amount} PUAN!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                           fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.reason,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
            .animate()
            .scale(duration: 400.ms, curve: Curves.elasticOut)
            .then()
            .slideY(begin: 0, end: -0.2, duration: 1000.ms)
            .fadeOut(duration: 500.ms),
          ],
        ),
      ),
    );
  }
}

// Global function to show the point overlay
void showPointOverlay(BuildContext context, int amount, String reason) {
  OverlayState overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => PointNotificationOverlay(
      amount: amount,
      reason: reason,
      onComplete: () {
        overlayEntry.remove();
      },
    ),
  );

  overlayState.insert(overlayEntry);
}
