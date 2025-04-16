import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:tuneup_task/models/user_profile.dart';
import 'package:tuneup_task/services/auth_service.dart';

class DatabaseService {
  final GetIt _getIt = GetIt.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  late AuthService _authService;
  late final CollectionReference<UserProfile> _usersCollection;

  DatabaseService() {
    _authService = _getIt.get<AuthService>();
    _setupCollectionReferences();
  }

  void _setupCollectionReferences() {
    _usersCollection = _firebaseFirestore
        .collection('users')
        .withConverter<UserProfile>(
            fromFirestore: (snapshot, _) =>
                UserProfile.fromJson(snapshot.data()!),
            toFirestore: (userProfile, _) => userProfile.toJson());
  }

  Future<DatabaseResult> createUserProfile(
      {required UserProfile userProfile}) async {
    try {
      await _usersCollection.doc(userProfile.uid).set(userProfile);
      return DatabaseResult.success();
    } on FirebaseException catch (e) {
      return DatabaseResult.error(e.message ?? 'Unknown Firebase error');
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<List<UserProfile>> getUserProfiles() {
    try {
      if (_authService.user == null) {
        print("No current user found");
        return Stream.value([]);
      }
      
      print("Current user UID: ${_authService.user!.uid}");
      print("Current user email: ${_authService.user!.email}");
      
      return _usersCollection
          .where("uid", isNotEqualTo: _authService.user!.uid)
          .snapshots()
          .map((snapshot) {
            print("Firestore snapshot received");
            print("Snapshot size: ${snapshot.docs.length}");
            
            final users = snapshot.docs
                .map((doc) {
                  print("Processing document: ${doc.id}");
                  print("Document data: ${doc.data()}");
                  return doc.data();
                })
                .where((profile) => profile != null)
                .cast<UserProfile>()
                .toList();
            
            print("Total users found: ${users.length}");
            if (users.isEmpty) {
              print("No users found in the database");
            } else {
              print("Found users: ${users.map((u) => '${u.name} (${u.uid})').join(', ')}");
            }
            return users;
          });
    } catch (e, stackTrace) {
      print("Error getting user profiles: $e");
      print("Stack trace: $stackTrace");
      return Stream.value([]);
    }
  }

  Future<DatabaseResult> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _usersCollection.doc(uid).update(updates);
      return DatabaseResult.success();
    } on FirebaseException catch (e) {
      return DatabaseResult.error(e.message ?? 'Unknown Firebase error');
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }
}

class DatabaseResult {
  final bool isSuccess;
  final String? error;

  DatabaseResult.success()
      : isSuccess = true,
        error = null;

  DatabaseResult.error(this.error) : isSuccess = false;

  Future<bool> checkChatExists(String uid1, String uid2) async {
    String chatID
  }
}
