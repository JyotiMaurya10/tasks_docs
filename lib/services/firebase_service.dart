import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Tasks collection root
  static CollectionReference tasksRef() => firestore.collection('tasks');

  // Cursor subcollection: tasks/<taskId>/cursors
  static CollectionReference cursorsRef(String taskId) =>
      tasksRef().doc(taskId).collection('cursors');

  // Create task
  static Future<DocumentReference> createTask({
    required String title,
    required String content,
  }) {
    final docRef = tasksRef().doc();
    return docRef
        .set({
          'title': title,
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .then((_) => docRef);
  }

  static Future<void> updateTask(String id, Map<String, dynamic> data) =>
      tasksRef().doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> deleteTask(String id) => tasksRef().doc(id).delete();

  // Cursor updates
  static Future<void> updateCursor(
    String taskId,
    String userId,
    Map<String, dynamic> cursorData,
  ) => cursorsRef(taskId).doc(userId).set(cursorData);

  static Future<void> removeCursor(String taskId, String userId) =>
      cursorsRef(taskId).doc(userId).delete();
}
