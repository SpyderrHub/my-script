import 'package:flutter/material.dart';

/// Minimal, rounded button used throughout the app.
/// Accepts an icon (optional) and label.
class RoundedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool elevated;
  final double radius;

  const RoundedButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.elevated = true,
    this.radius = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );

    return elevated
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
            ),
            child: child,
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: child,
          );
  }
}
