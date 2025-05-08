import 'package:firebase_auth/firebase_auth.dart';


class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  User? _user;
  User? get user => _user;

  AuthService() {
    _firebaseAuth.authStateChanges().listen(authStateChangesStreamListener);
    _user = _firebaseAuth.currentUser;
  }

  Future<AuthResult> login(String email, String password) async {
    try {
      await _firebaseAuth.setPersistence(Persistence.LOCAL);
      
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
      if (credential.user != null) {
        _user = credential.user;
        return AuthResult.success;
      }
      return AuthResult.failure;
    } on FirebaseAuthException catch (e) {
      return AuthResult.fromFirebaseException(e);
    } catch (e) {
      return AuthResult.unknownError;
    }
  }

  Future<AuthResult> signUp(String email, String password) async {
    try {
      await _firebaseAuth.setPersistence(Persistence.LOCAL);
      
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);
      if (credential.user != null) {
        _user = credential.user;
        return AuthResult.success;
      }
      return AuthResult.failure;
    } on FirebaseAuthException catch (e) {
      return AuthResult.fromFirebaseException(e);
    } catch (e) {
      return AuthResult.unknownError;
    }
  }

  Future<AuthResult> logout() async {
    try {
      await _firebaseAuth.signOut();
      _user = null;
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return AuthResult.fromFirebaseException(e);
    } catch (e) {
      return AuthResult.unknownError;
    }
  }

  void authStateChangesStreamListener(User? user) {
    _user = user;
  }
}

enum AuthResult {
  success,
  failure,
  invalidEmail,
  userDisabled,
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  weakPassword,
  operationNotAllowed,
  unknownError;

  static AuthResult fromFirebaseException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AuthResult.invalidEmail;
      case 'user-disabled':
        return AuthResult.userDisabled;
      case 'user-not-found':
        return AuthResult.userNotFound;
      case 'wrong-password':
        return AuthResult.wrongPassword;
      case 'email-already-in-use':
        return AuthResult.emailAlreadyInUse;
      case 'weak-password':
        return AuthResult.weakPassword;
      case 'operation-not-allowed':
        return AuthResult.operationNotAllowed;
      default:
        return AuthResult.unknownError;
    }
  }
}
