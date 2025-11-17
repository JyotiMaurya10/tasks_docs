import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/services/share_service.dart';
import '../viewmodels/task_vm.dart';
import '../viewmodels/auth_vm.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cursor_model.dart';

class TaskView extends ConsumerStatefulWidget {
  final String taskId;
  const TaskView({super.key, required this.taskId});

  @override
  ConsumerState<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends ConsumerState<TaskView> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  StreamSubscription<DocumentSnapshot>? taskSub;
  StreamSubscription<QuerySnapshot>? cursorSub;
  Map<String, CursorModel> cursors = {};
  final Map<String, OverlayEntry> overlayEntries = {};
  Timer? updateDebounce;
  Timer? selectionDebounce;
  String lastKnownRemoteContent = '';
  bool isUpdatingFromFirebase = false;
  TextSelection? lastSelection;

  @override
  void initState() {
    super.initState();
    listenTask();
    listenCursors();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNode);
    });

    lastSelection = controller.selection;

    controller.addListener(() {
      if (isUpdatingFromFirebase) return;

      final currentSelection = controller.selection;
      final selectionChanged =
          lastSelection?.baseOffset != currentSelection.baseOffset || lastSelection?.extentOffset != currentSelection.extentOffset;
      lastSelection = currentSelection;

      if (selectionChanged && focusNode.hasFocus) {
        selectionDebounce?.cancel();
        selectionDebounce = Timer(const Duration(milliseconds: 100), () {
          final vm = ref.read(taskViewModelProvider(widget.taskId).notifier);
          final sel = controller.selection;
          vm.updateCursor(sel.baseOffset, sel.extentOffset);
        });
      }

      updateDebounce?.cancel();
      updateDebounce = Timer(const Duration(milliseconds: 500), () {
        final vm = ref.read(taskViewModelProvider(widget.taskId).notifier);

        if (controller.text != lastKnownRemoteContent) {
          vm.updateContent(controller.text);
        }

        final sel = controller.selection;
        vm.updateCursor(sel.baseOffset, sel.extentOffset);
      });
    });

    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        ref.read(taskViewModelProvider(widget.taskId).notifier).removeCursor();
      }
    });
  }

  void listenTask() {
    taskSub = FirebaseService.tasksRef()
        .doc(widget.taskId)
        .snapshots()
        .listen(
          (doc) {
            if (!doc.exists) return;
            final data = doc.data() as Map<String, dynamic>;
            final remoteContent = data['content'] ?? '';

            if (remoteContent != lastKnownRemoteContent) {
              lastKnownRemoteContent = remoteContent;

              try {
                isUpdatingFromFirebase = true;

                if (focusNode.hasFocus && controller.text != remoteContent) {
                  final selection = controller.selection;
                  controller.text = remoteContent;

                  if (selection.baseOffset >= 0) {
                    final baseOffset = selection.baseOffset > remoteContent.length ? remoteContent.length : selection.baseOffset;
                    final extentOffset = selection.extentOffset > remoteContent.length ? remoteContent.length : selection.extentOffset;
                    controller.selection = TextSelection(baseOffset: baseOffset, extentOffset: extentOffset);
                  }
                } else if (!focusNode.hasFocus) {
                  controller.text = remoteContent;
                }
              } finally {
                isUpdatingFromFirebase = false;
              }
            }
          },
          onError: (e) {
            debugPrint('Error listening to task: $e');
          },
        );
  }

  void listenCursors() {
    cursorSub = FirebaseService.cursorsRef(widget.taskId).snapshots().listen((snap) {
      final entries = <String, CursorModel>{};
      for (final d in snap.docs) {
        final m = d.data() as Map<String, dynamic>;
        entries[d.id] = CursorModel.fromMap(m);
      }
      setState(() {
        cursors = entries;
      });
    });
  }

  String getColorFromIndex(int colorIndex) {
    const colors = ['FF6B6B', '4ECDC4', 'FFE66D', '95E1D3', 'C7CEEA', 'FFB3BA'];
    return colors[colorIndex % colors.length];
  }

  Offset _calculateCursorPosition(int offset, BuildContext context, double maxWidth) {
    final safeOffset = offset.clamp(0, controller.text.length);

    try {
      final textStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

      // Create painter for full text with exact TextField width
      final fullTextPainter = TextPainter(
        text: TextSpan(text: controller.text, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 16,
      );
      fullTextPainter.layout(maxWidth: maxWidth);

      // Get the offset for caret position on the full text
      final offset2D = fullTextPainter.getOffsetForCaret(TextPosition(offset: safeOffset), Rect.fromLTWH(0, 0, maxWidth, double.infinity));

      return Offset(offset2D.dx + 4, offset2D.dy + 2);
    } catch (e) {
      debugPrint('Error calculating cursor position: $e');
      return const Offset(0, 0);
    }
  }

  (Offset, Offset) _calculateTextRangePositions(int startOffset, int endOffset, BuildContext context, double maxWidth) {
    final textStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

    // Create painter for full text with exact TextField width
    final fullTextPainter = TextPainter(
      text: TextSpan(text: controller.text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 16,
    );
    fullTextPainter.layout(maxWidth: maxWidth);

    // Get positions on the full text
    final startOffset2D = fullTextPainter.getOffsetForCaret(TextPosition(offset: startOffset), Rect.fromLTWH(0, 0, maxWidth, double.infinity));

    final endOffset2D = fullTextPainter.getOffsetForCaret(TextPosition(offset: endOffset), Rect.fromLTWH(0, 0, maxWidth, double.infinity));

    return (Offset(startOffset2D.dx + 4, startOffset2D.dy + 2), Offset(endOffset2D.dx + 4, endOffset2D.dy + 2));
  }

  Widget buildTextFieldWithCursors(BuildContext context, List<MapEntry<String, CursorModel>> activeCollaborators) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Use LayoutBuilder to get actual TextField width
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Add task description...',
                    filled: true,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: 16,
                  keyboardType: TextInputType.multiline,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                // Overlay for collaborator cursors and selections
                if (activeCollaborators.isNotEmpty)
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Stack(
                        children: [
                          // Selection highlights and badges
                          ...activeCollaborators.expand((entry) {
                            final cursor = entry.value;
                            final color = Color(int.parse('FF${getColorFromIndex(cursor.colorIndex)}', radix: 16));
                            final hasSelection = cursor.baseOffset != cursor.extentOffset;

                            if (!hasSelection) return [];

                            final selectionStart = cursor.baseOffset < cursor.extentOffset ? cursor.baseOffset : cursor.extentOffset;
                            final selectionEnd = cursor.baseOffset > cursor.extentOffset ? cursor.baseOffset : cursor.extentOffset;

                            final safeStart = selectionStart.clamp(0, controller.text.length);
                            final safeEnd = selectionEnd.clamp(0, controller.text.length);

                            final (startPos, endPos) = _calculateTextRangePositions(safeStart, safeEnd, context, constraints.maxWidth);

                            final widgets = <Widget>[];

                            final selectedText = controller.text.substring(safeStart, safeEnd);

                            final textPainter = TextPainter(
                              text: TextSpan(text: selectedText, style: Theme.of(context).textTheme.bodyLarge),
                              textDirection: TextDirection.ltr,
                            );
                            textPainter.layout(maxWidth: constraints.maxWidth);

                            widgets.add(
                              Positioned(
                                left: startPos.dx,
                                top: startPos.dy,
                                child: Container(
                                  width: textPainter.width,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.25),
                                    border: Border(
                                      left: BorderSide(color: color, width: 2),
                                      right: BorderSide(color: color, width: 2),
                                    ),
                                  ),
                                ),
                              ),
                            );

                            widgets.add(
                              Positioned(
                                left: endPos.dx + 5,
                                top: endPos.dy + 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                                  ),
                                  child: Text(
                                    cursor.displayName,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );

                            return widgets;
                          }).toList(),

                          // Blinking cursors
                          ...activeCollaborators.where((entry) => entry.value.baseOffset == entry.value.extentOffset).map((entry) {
                            final cursor = entry.value;
                            final color = Color(int.parse('FF${getColorFromIndex(cursor.colorIndex)}', radix: 16));

                            final safeOffset = cursor.baseOffset > controller.text.length ? controller.text.length : cursor.baseOffset;

                            final pos = _calculateCursorPosition(safeOffset, context, constraints.maxWidth);

                            return Positioned(
                              left: pos.dx,
                              top: pos.dy,
                              child: _BlinkingCursorIndicator(color: color, displayName: cursor.displayName, offset: safeOffset),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    updateDebounce?.cancel();
    selectionDebounce?.cancel();
    taskSub?.cancel();
    cursorSub?.cancel();

    ref.read(taskViewModelProvider(widget.taskId).notifier).removeCursor();
    for (final e in overlayEntries.values) {
      e.remove();
    }
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskViewModelProvider(widget.taskId));
    final currentUserId = ref.read(authViewModelProvider).userId;

    final activeCollaborators = cursors.entries.where((e) => e.key != currentUserId).toList();

    return Scaffold(
      appBar: AppBar(
        title: taskAsync.when(
          data: (t) => Text(t?.title ?? 'Task'),
          loading: () => const Text('Loading...'),
          error: (e, st) => const Text('Error loading task'),
        ),
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Share task',
            child: IconButton(icon: const Icon(Icons.share), onPressed: () => ShareService.shareTaskLink(widget.taskId)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeCollaborators.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, size: 20, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Active Collaborators (${activeCollaborators.length})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: activeCollaborators.map((entry) {
                        final cursor = entry.value;
                        return Chip(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(int.parse('FF${getColorFromIndex(cursor.colorIndex)}', radix: 16)),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                          ),
                          label: Text(
                            cursor.displayName,
                            style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          backgroundColor: Colors.grey.shade100,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: Color(int.parse('FF${getColorFromIndex(cursor.colorIndex)}', radix: 16)).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          elevation: 1,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

              taskAsync.when(
                data: (task) {
                  if (task == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.task_alt, size: 64, color: Theme.of(context).primaryColor.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('Task not found', style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                      ),
                    );
                  }
                  return Text(
                    task.title.isEmpty ? '(no title)' : task.title,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                  );
                },
                loading: () => const SizedBox(height: 32, child: CircularProgressIndicator()),
                error: (e, st) =>
                    Text('Error loading task', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.error)),
              ),
              const SizedBox(height: 24),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Task Content', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('Characters: ${controller.text.length}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  buildTextFieldWithCursors(context, activeCollaborators),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursorIndicator extends StatefulWidget {
  final Color color;
  final String displayName;
  final int offset;

  const _BlinkingCursorIndicator({required this.color, required this.displayName, required this.offset});

  @override
  State<_BlinkingCursorIndicator> createState() => _BlinkingCursorIndicatorState();
}

class _BlinkingCursorIndicatorState extends State<_BlinkingCursorIndicator> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    _opacity = Tween<double>(begin: 1.0, end: 0.3).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _opacity,
            builder: (context, child) {
              return Opacity(
                opacity: _opacity.value,
                child: SizedBox(
                  width: 2,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(1)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: widget.color.withOpacity(0.9), borderRadius: BorderRadius.circular(3)),
            child: Text(
              widget.displayName,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:todo_app/services/share_service.dart';
// import '../viewmodels/task_vm.dart';
// import '../viewmodels/auth_vm.dart';
// import '../services/firebase_service.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/cursor_model.dart';

// class TaskView extends ConsumerStatefulWidget {
//   final String taskId;
//   const TaskView({super.key, required this.taskId});

//   @override
//   ConsumerState<TaskView> createState() => _TaskViewState();
// }

// class _TaskViewState extends ConsumerState<TaskView> {
//   final TextEditingController controller = TextEditingController();
//   final FocusNode focusNode = FocusNode();
//   StreamSubscription<DocumentSnapshot>? taskSub;
//   StreamSubscription<QuerySnapshot>? cursorSub;
//   Map<String, CursorModel> cursors = {};
//   final Map<String, OverlayEntry> overlayEntries = {};
//   Timer? updateDebounce;
//   Timer? selectionDebounce;
//   String lastKnownRemoteContent = '';
//   bool isUpdatingFromFirebase = false;
//   TextSelection? lastSelection;

//   @override
//   void initState() {
//     super.initState();
//     listenTask();
//     listenCursors();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       FocusScope.of(context).requestFocus(focusNode);
//     });

//     lastSelection = controller.selection;

//     controller.addListener(() {
//       if (isUpdatingFromFirebase) return;

//       final currentSelection = controller.selection;
//       final selectionChanged =
//           lastSelection?.baseOffset != currentSelection.baseOffset || lastSelection?.extentOffset != currentSelection.extentOffset;
//       lastSelection = currentSelection;

//       if (selectionChanged && focusNode.hasFocus) {
//         selectionDebounce?.cancel();
//         selectionDebounce = Timer(const Duration(milliseconds: 100), () {
//           final vm = ref.read(taskViewModelProvider(widget.taskId).notifier);
//           final sel = controller.selection;
//           vm.updateCursor(sel.baseOffset, sel.extentOffset);
//         });
//       }

//       updateDebounce?.cancel();
//       updateDebounce = Timer(const Duration(milliseconds: 500), () {
//         final vm = ref.read(taskViewModelProvider(widget.taskId).notifier);

//         if (controller.text != lastKnownRemoteContent) {
//           vm.updateContent(controller.text);
//         }

//         final sel = controller.selection;
//         vm.updateCursor(sel.baseOffset, sel.extentOffset);
//       });
//     });

//     focusNode.addListener(() {
//       if (!focusNode.hasFocus) {
//         ref.read(taskViewModelProvider(widget.taskId).notifier).removeCursor();
//       }
//     });
//   }

//   void listenTask() {
//     taskSub = FirebaseService.tasksRef()
//         .doc(widget.taskId)
//         .snapshots()
//         .listen(
//           (doc) {
//             if (!doc.exists) return;
//             final data = doc.data() as Map<String, dynamic>;
//             final remoteContent = data['content'] ?? '';

//             if (remoteContent != lastKnownRemoteContent) {
//               lastKnownRemoteContent = remoteContent;

//               try {
//                 isUpdatingFromFirebase = true;

//                 if (focusNode.hasFocus && controller.text != remoteContent) {
//                   final selection = controller.selection;
//                   controller.text = remoteContent;

//                   if (selection.baseOffset >= 0) {
//                     final baseOffset = selection.baseOffset > remoteContent.length ? remoteContent.length : selection.baseOffset;
//                     final extentOffset = selection.extentOffset > remoteContent.length ? remoteContent.length : selection.extentOffset;
//                     controller.selection = TextSelection(baseOffset: baseOffset, extentOffset: extentOffset);
//                   }
//                 } else if (!focusNode.hasFocus) {
//                   controller.text = remoteContent;
//                 }
//               } finally {
//                 isUpdatingFromFirebase = false;
//               }
//             }
//           },
//           onError: (e) {
//             debugPrint('Error listening to task: $e');
//           },
//         );
//   }

//   void listenCursors() {
//     cursorSub = FirebaseService.cursorsRef(widget.taskId).snapshots().listen((snap) {
//       final entries = <String, CursorModel>{};
//       for (final d in snap.docs) {
//         final m = d.data() as Map<String, dynamic>;
//         entries[d.id] = CursorModel.fromMap(m);
//       }
//       setState(() {
//         cursors = entries;
//       });
//     });
//   }

//   String getColorFromIndex(int colorIndex) {
//     const colors = ['FF6B6B', '4ECDC4', 'FFE66D', '95E1D3', 'C7CEEA', 'FFB3BA'];
//     return colors[colorIndex % colors.length];
//   }

//   Offset _calculateCursorPosition(int offset, BuildContext context) {
//     final safeOffset = offset.clamp(0, controller.text.length);

//     try {
//       final textStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

//       final textPainter = TextPainter(
//         text: TextSpan(text: controller.text.substring(0, safeOffset), style: textStyle),
//         textDirection: TextDirection.ltr,
//         maxLines: 6,
//       );
//       textPainter.layout(maxWidth: double.infinity);

//       final offset2D = textPainter.getOffsetForCaret(TextPosition(offset: safeOffset), Rect.fromLTWH(0, 0, double.infinity, double.infinity));

//       return Offset(offset2D.dx + 4, offset2D.dy + 2);
//     } catch (e) {
//       return const Offset(0, 0);
//     }
//   }

//   (Offset, Offset) _calculateTextRangePositions(int startOffset, int endOffset, BuildContext context) {
//     final textStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

//     final startPainter = TextPainter(
//       text: TextSpan(text: controller.text.substring(0, startOffset), style: textStyle),
//       textDirection: TextDirection.ltr,
//       maxLines: 6,
//     );
//     startPainter.layout(maxWidth: double.infinity);
//     final startOffset2D = startPainter.getOffsetForCaret(TextPosition(offset: startOffset), Rect.fromLTWH(0, 0, double.infinity, double.infinity));

//     final endPainter = TextPainter(
//       text: TextSpan(text: controller.text.substring(0, endOffset), style: textStyle),
//       textDirection: TextDirection.ltr,
//       maxLines: 6,
//     );
//     endPainter.layout(maxWidth: double.infinity);
//     final endOffset2D = endPainter.getOffsetForCaret(TextPosition(offset: endOffset), Rect.fromLTWH(0, 0, double.infinity, double.infinity));

//     return (Offset(startOffset2D.dx + 4, startOffset2D.dy + 2), Offset(endOffset2D.dx + 4, endOffset2D.dy + 2));
//   }

//   Widget _buildTextFieldWithCursors(BuildContext context, List<MapEntry<String, CursorModel>> activeCollaborators) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Stack(
//           children: [
//             TextField(
//               controller: controller,
//               focusNode: focusNode,
//               decoration: InputDecoration(
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                 hintText: 'Add task description...',
//                 filled: true,
//                 isDense: true,
//                 contentPadding: EdgeInsets.zero,
//               ),
//               maxLines: 6,
//               keyboardType: TextInputType.multiline,
//               style: Theme.of(context).textTheme.bodyLarge,
//             ),

//             if (activeCollaborators.isNotEmpty)
//               IgnorePointer(
//                 child: SizedBox(
//                   height: MediaQuery.of(context).size.height,
//                   child: Stack(
//                     children: [
//                       ...activeCollaborators.expand((entry) {
//                         final cursor = entry.value;
//                         final color = Color(int.parse('FF${getColorFromIndex(cursor.colorIndex)}', radix: 16));
//                         final hasSelection = cursor.baseOffset != cursor.extentOffset;

//                         if (!hasSelection) return [];

//                         final selectionStart = cursor.baseOffset < cursor.extentOffset ? cursor.baseOffset : cursor.extentOffset;
//                         final selectionEnd = cursor.baseOffset > cursor.extentOffset ? cursor.baseOffset : cursor.extentOffset;

//                         final safeStart = selectionStart.clamp(0, controller.text.length);
//                         final safeEnd = selectionEnd.clamp(0, controller.text.length);

//                         final (startPos, endPos) = _calculateTextRangePositions(safeStart, safeEnd, context);

//                         final widgets = <Widget>[];

//                         final selectedText = controller.text.substring(safeStart, safeEnd);

//                         final textPainter = TextPainter(
//                           text: TextSpan(text: selectedText, style: Theme.of(context).textTheme.bodyLarge),
//                           textDirection: TextDirection.ltr,
//                         );
//                         textPainter.layout();

//                         widgets.add(
//                           Positioned(
//                             left: startPos.dx,
//                             top: startPos.dy,
//                             child: Container(
//                               width: textPainter.width,
//                               height: 20,
//                               decoration: BoxDecoration(
//                                 color: color.withOpacity(0.25),
//                                 border: Border(
//                                   left: BorderSide(color: color, width: 2),
//                                   right: BorderSide(color: color, width: 2),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         );

//                         widgets.add(
//                           Positioned(
//                             left: endPos.dx + 5,
//                             top: endPos.dy + 2,
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
//                               decoration: BoxDecoration(
//                                 color: color,
//                                 borderRadius: BorderRadius.circular(4),
//                                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
//                               ),
//                               child: Text(
//                                 cursor.displayName,
//                                 style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ),
//                         );

//                         return widgets;
//                       }),

//                       ...activeCollaborators.where((entry) => entry.value.baseOffset == entry.value.extentOffset).map((entry) {
//                         final cursor = entry.value;
//                         final color = Color(int.parse('FF${getColorFromIndex(cursor.colorIndex)}', radix: 16));

//                         final safeOffset = cursor.baseOffset > controller.text.length ? controller.text.length : cursor.baseOffset;

//                         final pos = _calculateCursorPosition(safeOffset, context);

//                         return Positioned(
//                           left: pos.dx,
//                           top: pos.dy,
//                           child: _BlinkingCursorIndicator(color: color, displayName: cursor.displayName, offset: safeOffset),
//                         );
//                       }),
//                     ],
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     updateDebounce?.cancel();
//     selectionDebounce?.cancel();
//     taskSub?.cancel();
//     cursorSub?.cancel();

//     ref.read(taskViewModelProvider(widget.taskId).notifier).removeCursor();
//     for (final e in overlayEntries.values) {
//       e.remove();
//     }
//     controller.dispose();
//     focusNode.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final taskAsync = ref.watch(taskViewModelProvider(widget.taskId));
//     final currentUserId = ref.read(authViewModelProvider).userId;

//     final activeCollaborators = cursors.entries.where((e) => e.key != currentUserId).toList();

//     return Scaffold(
//       appBar: AppBar(
//         title: taskAsync.when(
//           data: (t) => Text(t?.title ?? 'Task'),
//           loading: () => const Text('Loading...'),
//           error: (e, st) => const Text('Error loading task'),
//         ),
//         elevation: 0,
//         actions: [
//           Tooltip(
//             message: 'Share task',
//             child: IconButton(icon: const Icon(Icons.share), onPressed: () => ShareService.shareTaskLink(widget.taskId)),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               if (activeCollaborators.isNotEmpty)
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(Icons.people, size: 20, color: Theme.of(context).primaryColor),
//                         const SizedBox(width: 8),
//                         Text(
//                           'Active Collaborators (${activeCollaborators.length})',
//                           style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     Wrap(
//                       spacing: 8,
//                       runSpacing: 8,
//                       children: activeCollaborators.map((entry) {
//                         final cursor = entry.value;
//                         return Chip(
//                           materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                           visualDensity: VisualDensity.compact,
//                           avatar: Container(
//                             width: 10,
//                             height: 10,
//                             decoration: BoxDecoration(
//                               color: Color(int.parse('FF${getColorFromIndex(cursor.colorIndex)}', radix: 16)),
//                               shape: BoxShape.circle,
//                               boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
//                             ),
//                           ),
//                           label: Text(
//                             cursor.displayName,
//                             style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
//                           ),
//                           backgroundColor: Colors.grey.shade100,
//                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                             side: BorderSide(
//                               color: Color(int.parse('FF${getColorFromIndex(cursor.colorIndex)}', radix: 16)).withOpacity(0.4),
//                               width: 1,
//                             ),
//                           ),
//                           elevation: 1,
//                         );
//                       }).toList(),
//                     ),
//                     const SizedBox(height: 24),
//                   ],
//                 ),

//               taskAsync.when(
//                 data: (task) {
//                   if (task == null) {
//                     return Center(
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 32),
//                         child: Column(
//                           children: [
//                             Icon(Icons.task_alt, size: 64, color: Theme.of(context).primaryColor.withOpacity(0.3)),
//                             const SizedBox(height: 16),
//                             Text('Task not found', style: Theme.of(context).textTheme.titleLarge),
//                           ],
//                         ),
//                       ),
//                     );
//                   }
//                   return Text(
//                     task.title.isEmpty ? '(no title)' : task.title,
//                     style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
//                   );
//                 },
//                 loading: () => const SizedBox(height: 32, child: CircularProgressIndicator()),
//                 error: (e, st) =>
//                     Text('Error loading task', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.error)),
//               ),
//               const SizedBox(height: 24),

//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text('Task Content', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
//                       const SizedBox(height: 12),
//                       _buildTextFieldWithCursors(context, activeCollaborators),
//                       const SizedBox(height: 12),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [Text('Characters: ${controller.text.length}', style: Theme.of(context).textTheme.bodySmall)],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _BlinkingCursorIndicator extends StatefulWidget {
//   final Color color;
//   final String displayName;
//   final int offset;

//   const _BlinkingCursorIndicator({required this.color, required this.displayName, required this.offset});

//   @override
//   State<_BlinkingCursorIndicator> createState() => _BlinkingCursorIndicatorState();
// }

// class _BlinkingCursorIndicatorState extends State<_BlinkingCursorIndicator> with SingleTickerProviderStateMixin {
//   late AnimationController controller;
//   late Animation<double> _opacity;

//   @override
//   void initState() {
//     super.initState();
//     controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

//     _opacity = Tween<double>(begin: 1.0, end: 0.3).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

//     controller.repeat(reverse: true);
//   }

//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 20,
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           AnimatedBuilder(
//             animation: _opacity,
//             builder: (context, child) {
//               return Opacity(
//                 opacity: _opacity.value,
//                 child: SizedBox(
//                   width: 2,
//                   height: 22,
//                   child: DecoratedBox(
//                     decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(1)),
//                   ),
//                 ),
//               );
//             },
//           ),
//           const SizedBox(width: 4),

//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//             decoration: BoxDecoration(color: widget.color.withOpacity(0.9), borderRadius: BorderRadius.circular(3)),
//             child: Text(
//               widget.displayName,
//               style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
//               overflow: TextOverflow.ellipsis,
//               maxLines: 1,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
