import 'package:flutter/material.dart';

class VenueIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color;

  const VenueIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (icon.startsWith('http')) {
      return Image.network(
        icon,
        width: size,
        height: size,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.place,
          size: size,
          color: color,
        ),
      );
    } else {
      return Text(
        icon,
        style: TextStyle(fontSize: size),
      );
    }
  }
}
