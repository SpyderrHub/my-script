import 'package:flutter/material.dart';

typedef NavTap = void Function(int index);

/// Animated bottom navigation bar with rounded background and subtle elevation.
class AnimatedBottomNav extends StatelessWidget {
  final int selectedIndex;
  final NavTap onTap;

  const AnimatedBottomNav({Key? key, required this.selectedIndex, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.home_outlined, 'label': 'Home'},
      {'icon': Icons.edit_outlined, 'label': 'Edit'},
      {'icon': Icons.auto_awesome_outlined, 'label': 'Effects'},
      {'icon': Icons.upload_outlined, 'label': 'Export'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = i == selectedIndex;
              final item = items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: active ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item['icon'] as IconData, color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.65)),
                        const SizedBox(height: 4),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            active ? item['label'] as String : '',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
