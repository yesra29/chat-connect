import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  User? user;
  User? get _user {
    return user;
  }
  AuthService() {}

  Future<bool> login(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
      if (credential.user != null) {
        user = credential.user;
        return true;
      }
    } catch (e) {
      print(e);
    }
    return false;
  }
}
