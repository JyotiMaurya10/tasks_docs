import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/task_model.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_vm.dart';

final taskViewModelProvider =
    StateNotifierProvider.family<TaskViewModel, AsyncValue<TaskModel?>, String>(
      (ref, taskId) => TaskViewModel(ref, taskId),
    );

class TaskViewModel extends StateNotifier<AsyncValue<TaskModel?>> {
  final Ref ref;
  final String taskId;
  StreamSubscription<DocumentSnapshot>? _taskSub;
  StreamSubscription<QuerySnapshot>? _cursorSub;

  TaskViewModel(this.ref, this.taskId) : super(const AsyncValue.loading()) {
    _listen();
  }

  void _listen() {
    _taskSub = FirebaseService.tasksRef().doc(taskId).snapshots().listen(
      (doc) {
        if (!doc.exists) {
          state = const AsyncValue.data(null);
          return;
        }
        state = AsyncValue.data(TaskModel.fromDoc(doc));
      },
      onError: (e) {
        state = AsyncValue.error(e, StackTrace.current);
      },
    );

    // Cursors handled in UI using separate provider
    _cursorSub = FirebaseService.cursorsRef(taskId).snapshots().listen(
      (snap) {
        // Cursors handled in UI
      },
      onError: (e) {
        // Log cursor subscription errors but don't fail the main task
        print('Cursor sync error: $e');
      },
    );
  }

  Future<void> updateContent(String content) async {
    try {
      await FirebaseService.updateTask(taskId, {'content': content});
    } catch (e) {
      print('Error updating content: $e');
      rethrow;
    }
  }

  Future<void> updateTitle(String title) async {
    try {
      await FirebaseService.updateTask(taskId, {'title': title});
    } catch (e) {
      print('Error updating title: $e');
      rethrow;
    }
  }

  Future<void> updateCursor(int base, int extent) async {
    try {
      final auth = ref.read(authViewModelProvider);
      await FirebaseService.updateCursor(taskId, auth.userId, {
        'userId': auth.userId,
        'displayName': auth.displayName,
        'baseOffset': base,
        'extentOffset': extent,
        'colorIndex': auth.userId.hashCode % 6,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating cursor: $e');
      // Don't rethrow - cursor updates shouldn't break the main task
    }
  }

  Future<void> removeCursor() async {
    try {
      final auth = ref.read(authViewModelProvider);
      await FirebaseService.removeCursor(taskId, auth.userId);
    } catch (e) {
      print('Error removing cursor: $e');
    }
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _cursorSub?.cancel();
    super.dispose();
  }
}
