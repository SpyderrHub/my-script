import 'package:flutter/material.dart';

/// Floating edit FAB with expanding mini-action buttons.
/// Smooth animated expansion, used on Edit page.
class EditFab extends StatefulWidget {
  final void Function(String action) onAction;

  const EditFab({Key? key, required this.onAction}) : super(key: key);

  @override
  State<EditFab> createState() => _EditFabState();
}

class _EditFabState extends State<EditFab> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  bool open = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      open = !open;
      if (open) _ctl.forward(); else _ctl.reverse();
    });
  }

  Widget _mini(String label, IconData icon, String action, {Color? color}) {
    final anim = CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic);
    return ScaleTransition(
      scale: anim,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FloatingActionButton.extended(
          heroTag: 'mini_$action',
          onPressed: () {
            widget.onAction(action);
            _toggle();
          },
          backgroundColor: color ?? Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (open) _mini('Trim', Icons.content_cut, 'trim'),
        if (open) _mini('Split', Icons.call_split, 'split'),
        if (open) _mini('Effects', Icons.auto_awesome, 'effects'),
        FloatingActionButton(
          onPressed: _toggle,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: FadeTransition(opacity: anim, child: child)),
            child: Icon(open ? Icons.close : Icons.edit, key: ValueKey(open)),
          ),
        )
      ],
    );
  }
}
