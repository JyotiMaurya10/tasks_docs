import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

final authViewModelProvider = Provider<AuthViewModel>(
  (ref) => AuthViewModel(ref),
);

class AuthViewModel {
  final Ref ref;
  AuthViewModel(this.ref);

  User? get user => FirebaseService.auth.currentUser;

  Future<void> ensureSignedIn() async {
    final auth = FirebaseService.auth;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  String get userId => user?.uid ?? 'unknown';
  String get displayName => 'Anon-${user?.uid.substring(0, 6) ?? "guest"}';
}
