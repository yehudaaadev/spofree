import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  static String _formatEmail(String username) {
    var sanitized = username.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (sanitized.isEmpty) {
      sanitized = 'user_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '$sanitized@spotube.local';
  }

  static String extractUsername(String? email) {
    if (email == null || !email.contains('@')) return 'Pengguna';
    return email.split('@').first;
  }

  Future<UserCredential> register({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      throw Exception('Username tidak boleh kosong');
    }
    if (password.length < 6) {
      throw Exception('Password minimal 6 karakter');
    }

    final email = _formatEmail(cleanUsername);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'username': cleanUsername,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Username "$cleanUsername" sudah terdaftar. Silakan login.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password terlalu lemah. Gunakan minimal 6 karakter.');
      }
      throw Exception(e.message ?? 'Gagal melakukan registrasi');
    }
  }

  Future<UserCredential> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      throw Exception('Username tidak boleh kosong');
    }
    if (password.isEmpty) {
      throw Exception('Password tidak boleh kosong');
    }

    final email = _formatEmail(cleanUsername);

    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Username atau password salah.');
      }
      throw Exception(e.message ?? 'Gagal melakukan login');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
