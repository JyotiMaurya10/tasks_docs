import 'package:flutter/material.dart';

class TaskTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const TaskTile({super.key, required this.title, required this.subtitle, this.onTap, this.onShare, this.onDelete});

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with SingleTickerProviderStateMixin {
  late AnimationController hoverController;
  late Animation<double> scaleAnimation;
  late Animation<double> shadowAnimation;

  @override
  void initState() {
    super.initState();
    hoverController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(CurvedAnimation(parent: hoverController, curve: Curves.easeOut));
    shadowAnimation = Tween<double>(begin: 0, end: 8).animate(CurvedAnimation(parent: hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    hoverController.dispose();
    super.dispose();
  }

  void onHoverEnter() {
    hoverController.forward();
  }

  void onHoverExit() {
    hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hoverController,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: Card(
            elevation: shadowAnimation.value,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHover: (isHovered) {
                  if (isHovered) {
                    onHoverEnter();
                  } else {
                    onHoverExit();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title.isEmpty ? '(no title)' : widget.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle.isEmpty ? '(no description)' : widget.subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 4,
                        children: [
                          buildActionButton(icon: Icons.share, tooltip: 'Share', onPressed: widget.onShare),
                          buildActionButton(
                            icon: Icons.delete,
                            tooltip: 'Delete',
                            color: Colors.red,
                            onPressed: () {
                              widget.onDelete?.call();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildActionButton({required IconData icon, required String tooltip, required VoidCallback? onPressed, Color? color}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: IconButton(
          icon: Icon(icon),
          color: color,
          iconSize: 18,
          constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
