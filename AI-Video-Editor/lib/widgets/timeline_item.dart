import 'dart:io';
import 'package:flutter/material.dart';
import '../state/editor_state.dart';

class TimelineItem extends StatelessWidget {
  final ClipModel clip;
  final void Function()? onTap;
  final void Function()? onTrim;
  final void Function()? onSplit;
  final void Function()? onDelete;
  const TimelineItem({
    Key? key,
    required this.clip,
    this.onTap,
    this.onTrim,
    this.onSplit,
    this.onDelete,
  }) : super(key: key);

  String _formatMs(int ms) {
    final s = (ms / 1000).floor();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = clip.thumbnailPath;
    return Card(
      key: ValueKey(clip.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: thumb != null
            ? Image.file(File(thumb), width: 72, height: 48, fit: BoxFit.cover)
            : Container(width: 72, height: 48, color: Colors.grey.shade300, child: const Icon(Icons.videocam)),
        title: Text(thumb != null ? File(clip.path).uri.pathSegments.last : clip.path, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_formatMs(clip.durationMs)}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.content_cut), onPressed: onTrim),
          IconButton(icon: const Icon(Icons.call_split), onPressed: onSplit),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
        ]),
      ),
    );
  }
}
