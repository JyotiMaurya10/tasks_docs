import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/task_model.dart';
import '../services/firebase_service.dart';

final taskListViewModelProvider = StateNotifierProvider<TaskListViewModel, AsyncValue<List<TaskModel>>>((ref) => TaskListViewModel(ref));

// Provider to track loading more state
final taskListLoadingMoreProvider = StateProvider<bool>((ref) => false);

class TaskListViewModel extends StateNotifier<AsyncValue<List<TaskModel>>> {
  final Ref ref;
  static const int pageSize = 10;
  DocumentSnapshot? lastDoc;
  bool hasMore = true;
  bool loadingMore = false;

  TaskListViewModel(this.ref) : super(const AsyncValue.loading()) {
    listenInitial();
  }

  void listenInitial() {
    try {
      FirebaseService.tasksRef()
          .orderBy('updatedAt', descending: true)
          .limit(pageSize)
          .snapshots()
          .listen(
            (snap) {
              try {
                lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
                hasMore = snap.docs.length >= pageSize;
                final tasks = snap.docs.map((d) => TaskModel.fromDoc(d)).toList();
                state = AsyncValue.data(tasks);
              } catch (e, st) {
                debugPrint('Error mapping tasks: $e');
                state = AsyncValue.error(e, st);
              }
            },
            onError: (e, st) {
              debugPrint('Stream error in task list: $e');
              state = AsyncValue.error(e, st);
            },
          );
    } catch (e, st) {
      debugPrint('Error initializing task list: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || loadingMore) return;
    if (lastDoc == null) return;

    loadingMore = true;
    // Update the provider to trigger UI rebuild
    ref.read(taskListLoadingMoreProvider.notifier).state = true;

    try {
      final q = FirebaseService.tasksRef().orderBy('updatedAt', descending: true).startAfterDocument(lastDoc!).limit(pageSize);

      final snap = await q.get();

      if (snap.docs.isEmpty) {
        hasMore = false;
      } else {
        lastDoc = snap.docs.last;
        final newTasks = snap.docs.map((d) => TaskModel.fromDoc(d)).toList();
        final current = state.asData?.value ?? [];
        state = AsyncValue.data([...current, ...newTasks]);
      }
    } catch (e, st) {
      debugPrint('Error loading more tasks: $e');
      state = AsyncValue.error(e, st);
    } finally {
      loadingMore = false;
      // Update the provider to stop showing loader
      ref.read(taskListLoadingMoreProvider.notifier).state = false;
    }
  }

  Future<void> createTask(String title, String content) async {
    if (title.trim().isEmpty) {
      throw Exception('Task title cannot be empty');
    }

    try {
      final docRef = FirebaseService.tasksRef().doc();
      await docRef.set({
        'title': title.trim(),
        'content': content.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await FirebaseService.deleteTask(id);
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }
}
