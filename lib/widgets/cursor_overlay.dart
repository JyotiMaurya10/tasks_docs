import 'package:flutter/material.dart';
import '../models/cursor_model.dart';

class CursorOverlay extends StatefulWidget {
  final CursorModel cursor;
  final int textLength;
  final TextEditingController textController;
  final String displayColor;

  const CursorOverlay({super.key, required this.cursor, required this.textLength, required this.textController, required this.displayColor});

  @override
  State<CursorOverlay> createState() => _CursorOverlayState();
}

class _CursorOverlayState extends State<CursorOverlay> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Color getColorFromIndex(int colorIndex) {
    const colors = [Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFE66D), Color(0xFF95E1D3), Color(0xFFC7CEEA), Color(0xFFFFB3BA)];
    return colors[colorIndex % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = getColorFromIndex(widget.cursor.colorIndex);

    final baseOffset = widget.cursor.baseOffset.clamp(0, widget.textLength);
    final extentOffset = widget.cursor.extentOffset.clamp(0, widget.textLength);

    final hasSelection = baseOffset != extentOffset;
    final selectionStart = baseOffset < extentOffset ? baseOffset : extentOffset;
    final selectionEnd = baseOffset > extentOffset ? baseOffset : extentOffset;

    if (!hasSelection) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${widget.cursor.displayName}: ${selectionEnd - selectionStart} chars',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
