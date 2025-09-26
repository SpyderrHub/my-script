import 'package:flutter/material.dart';
import '../state/editor_state.dart';

/// A compact, modern swipeable timeline widget.
/// - horizontal PageView segments (pages of thumbnails)
/// - short press to select clip
/// - long-press + drag to start a reorder (uses a callback)
///
/// This widget focuses on smooth gestures and visual polish; the heavy editing operations are handled by the editor state.
class SwipeableTimeline extends StatefulWidget {
  final List<ClipModel> clips;
  final void Function(String clipId) onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;
  final String? selectedClipId;

  const SwipeableTimeline({
    Key? key,
    required this.clips,
    required this.onSelect,
    required this.onReorder,
    this.selectedClipId,
  }) : super(key: key);

  @override
  State<SwipeableTimeline> createState() => _SwipeableTimelineState();
}

class _SwipeableTimelineState extends State<SwipeableTimeline> {
  final PageController _pageController = PageController(viewportFraction: 0.98);
  static const int pageSize = 6; // number of thumbnails per page

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<List<ClipModel>> _pagesFromClips() {
    final pages = <List<ClipModel>>[];
    for (var i = 0; i < widget.clips.length; i += pageSize) {
      pages.add(widget.clips.sublist(i, (i + pageSize).clamp(0, widget.clips.length)));
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pagesFromClips();

    return SizedBox(
      height: 140,
      child: PageView.builder(
        controller: _pageController,
        itemCount: pages.length,
        itemBuilder: (context, pageIndex) {
          final page = pages[pageIndex];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: page.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final clip = page[i];
                    final globalIndex = pageIndex * pageSize + i;
                    final selected = clip.id == widget.selectedClipId;
                    return LongPressDraggable<int>(
                      data: globalIndex,
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      feedback: Opacity(
                        opacity: 0.95,
                        child: _buildThumb(context, clip, selected, shadow: true),
                      ),
                      childWhenDragging: Opacity(opacity: 0.35, child: _buildThumb(context, clip, selected)),
                      onDragStarted: () {},
                      child: DragTarget<int>(
                        onAccept: (from) {
                          widget.onReorder(from, globalIndex);
                        },
                        onWillAccept: (from) => from != globalIndex,
                        builder: (ctx, cand, rej) {
                          return GestureDetector(
                            onTap: () => widget.onSelect(clip.id),
                            child: _buildThumb(context, clip, selected),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumb(BuildContext context, ClipModel clip, bool selected, {bool shadow = false}) {
    final thumb = clip.thumbnailPath;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: shadow ? [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8, offset: const Offset(0, 4))] : null,
        border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumb != null
                  ? Image.file(
                      // safety: thumbnailPath may be null or not exist
                      File(thumb),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(color: Colors.grey.shade800, child: const Icon(Icons.movie, color: Colors.white60, size: 36)),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              clip.path.split('/').last,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9), fontSize: 12),
            ),
          )
        ],
      ),
    );
  }
}
