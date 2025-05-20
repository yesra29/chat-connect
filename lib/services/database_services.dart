import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:tuneup_task/models/user_profile.dart';
import 'package:tuneup_task/models/group.dart';
import 'package:tuneup_task/services/auth_service.dart';

class DatabaseService {
  final GetIt _getIt = GetIt.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  late AuthService _authService;
  late final CollectionReference<UserProfile> _usersCollection;
  late final CollectionReference<Map<String, dynamic>> _chatsCollection;
  late final CollectionReference<Map<String, dynamic>> _groupsCollection;

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

    _chatsCollection = _firebaseFirestore
        .collection('chats')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        );

    _groupsCollection = _firebaseFirestore
        .collection('groups')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        );
  }

  Future<DatabaseResult> createUserProfile(
      {required UserProfile userProfile}) async {
    try {
      if (userProfile.uid.isEmpty) {
        return DatabaseResult.error("User ID cannot be empty");
      }

      if (userProfile.name.isEmpty) {
        return DatabaseResult.error("Name cannot be empty");
      }

      final existingUser = await getUserProfile(userProfile.uid);
      if (existingUser != null) {
        return DatabaseResult.error("User profile already exists");
      }

      // Get the current user's email
      final currentUser = _authService.user;
      if (currentUser != null) {
        userProfile = UserProfile(
          uid: userProfile.uid,
          name: userProfile.name,
          pfpURL: userProfile.pfpURL,
          email: currentUser.email,
        );
      }

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
        return Stream.value([]);
      }

      final currentUser = _authService.user!;

      return _usersCollection
          .where("uid", isNotEqualTo: currentUser.uid)
          .snapshots()
          .map((snapshot) {
        final users = snapshot.docs
            .map((doc) {
              final user = doc.data();
              return user;
            })
            .where((user) => user.uid != currentUser.uid)
            .toList();

        users.forEach((user) {});

        return users;
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  Future<DatabaseResult> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      if (uid.isEmpty) {
        return DatabaseResult.error("User ID cannot be empty");
      }

      final user = await getUserProfile(uid);
      if (user == null) {
        return DatabaseResult.error("User not found");
      }

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
      if (uid.isEmpty) {
        return null;
      }

      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) {
        return null;
      }

      return doc.data();
    } catch (e) {
      return null;
    }
  }

  Future<DatabaseResult> createGroup({
    required String name,
    required String description,
    required List<String> participants,
    String? groupImageUrl,
  }) async {
    try {
      if (name.isEmpty) {
        return DatabaseResult.error("Group name cannot be empty");
      }

      if (participants.length > 20) {
        return DatabaseResult.error(
            "Group cannot have more than 20 participants");
      }

      final currentUser = _authService.user;
      if (currentUser == null) {
        return DatabaseResult.error("User not authenticated");
      }

      final groupId = _firebaseFirestore.collection('groups').doc().id;
      final group = Group(
        id: groupId,
        name: name,
        description: description,
        adminId: currentUser.uid,
        participants: [...participants, currentUser.uid],
        groupImageUrl: groupImageUrl,
        createdAt: DateTime.now(),
      );

      await _groupsCollection.doc(groupId).set(group.toJson());
      return DatabaseResult.success();
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserGroups() {
    try {
      final currentUser = _authService.user;
      if (currentUser == null) {
        return const Stream.empty();
      }

      return _groupsCollection
          .where('participants', arrayContains: currentUser.uid)
          .snapshots();
    } catch (e) {
      return const Stream.empty();
    }
  }

  Future<DatabaseResult> addGroupParticipants(
      String groupId, List<String> userIds) async {
    try {
      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        return DatabaseResult.error("Group not found");
      }

      final group = Group.fromJson(groupDoc.data()!);
      if (group.participants.length + userIds.length > 20) {
        return DatabaseResult.error(
            "Group cannot have more than 20 participants");
      }

      await _groupsCollection.doc(groupId).update({
        'participants': FieldValue.arrayUnion(userIds),
      });

      return DatabaseResult.success();
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Future<DatabaseResult> removeGroupParticipants(
      String groupId, List<String> userIds) async {
    try {
      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        return DatabaseResult.error("Group not found");
      }

      final group = Group.fromJson(groupDoc.data()!);
      if (group.adminId == _authService.user?.uid) {
        await _groupsCollection.doc(groupId).update({
          'participants': FieldValue.arrayRemove(userIds),
        });
        return DatabaseResult.success();
      } else {
        return DatabaseResult.error("Only group admin can remove participants");
      }
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getGroupMessages(String groupId) {
    try {
      return _groupsCollection
          .doc(groupId)
          .collection('messages')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          )
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      return const Stream.empty();
    }
  }

  Future<DatabaseResult> sendGroupMessage(
      String groupId, String message) async {
    try {
      final currentUser = _authService.user;
      if (currentUser == null) {
        return DatabaseResult.error("User not authenticated");
      }

      if (message.trim().isEmpty) {
        return DatabaseResult.error("Message cannot be empty");
      }

      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        return DatabaseResult.error("Group not found");
      }

      final group = Group.fromJson(groupDoc.data()!);
      if (!group.isParticipant(currentUser.uid)) {
        return DatabaseResult.error("User is not a participant of this group");
      }

      final messageRef =
          await _groupsCollection.doc(groupId).collection('messages').add({
        'senderId': currentUser.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'readStatus': {currentUser.uid: true},
      });

      // Update last message in group document
      await _groupsCollection.doc(groupId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'readStatus': {currentUser.uid: true},
      });

      return DatabaseResult.success();
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Future<DatabaseResult> markGroupMessageAsRead(
      String groupId, String messageId) async {
    try {
      final currentUser = _authService.user;
      if (currentUser == null) {
        return DatabaseResult.error("User not authenticated");
      }

      await _groupsCollection
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readStatus.${currentUser.uid}': true,
      });

      // Also update group read status
      await _groupsCollection.doc(groupId).update({
        'readStatus.${currentUser.uid}': true,
      });

      return DatabaseResult.success();
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getGroupStatus(
      String groupId) {
    try {
      return _groupsCollection.doc(groupId).snapshots();
    } catch (e) {
      return const Stream.empty();
    }
  }

  Future<String> getChatId(String uid1, String uid2) {
    // Always sort UIDs to ensure consistent chat ID regardless of who initiates
    final sortedIds = [uid1, uid2]..sort();
    final chatId = '${sortedIds[0]}_${sortedIds[1]}';
    return Future.value(chatId);
  }

  Future<bool> checkChatExists(String uid1, String uid2) async {
    try {
      final chatId = await getChatId(uid1, uid2);
      final doc = await _chatsCollection.doc(chatId).get();
      final exists = doc.exists;
      return exists;
    } catch (e) {
      return false;
    }
  }

  Future<DatabaseResult> createChat(String uid1, String uid2) async {
    try {
      if (uid1.isEmpty || uid2.isEmpty) {
        return DatabaseResult.error("User IDs cannot be empty");
      }

      // Get both user profiles to check their emails
      final user1 = await getUserProfile(uid1);
      final user2 = await getUserProfile(uid2);

      if (user1 == null || user2 == null) {
        return DatabaseResult.error("One or both users not found");
      }

      // Check if users have different emails
      if (user1.email == user2.email) {
        return DatabaseResult.error("Cannot create chat with the same user");
      }

      final chatId = await getChatId(uid1, uid2);

      // Check if chat already exists
      final chatExists = await checkChatExists(uid1, uid2);
      if (chatExists) {
        return DatabaseResult.success();
      }

      await _chatsCollection.doc(chatId).set({
        'participants': [uid1, uid2],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
        'readStatus': {},
      });

      return DatabaseResult.success();
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getChatMessages(String chatId) {
    try {
      return _chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        snapshot.docs.forEach((doc) {
          final data = doc.data();
        });
        return snapshot;
      });
    } catch (e) {
      return const Stream.empty();
    }
  }

  Future<DatabaseResult> sendMessage(
    String chatId,
    String senderId,
    String message, {
    bool isMedia = false,
  }) async {
    try {
      final messageData = {
        'senderId': senderId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isMedia': isMedia,
        'readStatus': {
          senderId: true,
        },
      };

      final messageRef = await _firebaseFirestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      await _firebaseFirestore.collection('chats').doc(chatId).update({
        'lastMessage': isMedia ? '📷 Image' : message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'readStatus': {
          senderId: true,
        },
      });

      return DatabaseResult.success();
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Future<DatabaseResult> markMessageAsRead(
      String chatId, String messageId, String userId) async {
    try {
      await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readStatus.$userId': true,
      });

      await _chatsCollection.doc(chatId).update({
        'readStatus.$userId': true,
      });

      return DatabaseResult.success();
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Future<DatabaseResult> updateTypingStatus(
      String chatId, String userId, bool isTyping) async {
    try {
      await _chatsCollection.doc(chatId).update({
        'typingStatus.$userId': isTyping,
      });
      return DatabaseResult.success();
    } catch (e) {
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getChatStatus(String chatId) {
    return _chatsCollection.doc(chatId).snapshots();
  }

  Future<void> updateGroupTypingStatus(
      String groupId, String userId, bool isTyping) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'typingStatus.$userId': isTyping,
      });
    } catch (e) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserChats() {
    return _firebaseFirestore
        .collection('chats')
        .where('participants', arrayContains: _authService.user!.uid)
        .snapshots();
  }

  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(blockedUserId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
      });

      final chatQuery = await _firebaseFirestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in chatQuery.docs) {
        final participants =
            List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(blockedUserId)) {
          await doc.reference.delete();
          break;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearChat(String chatId) async {
    try {
      final messagesQuery = await _firebaseFirestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firebaseFirestore.batch();
      for (var doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      batch.update(_firebaseFirestore.collection('chats').doc(chatId), {
        'lastMessage': null,
        'lastMessageTime': null,
        'lastSenderId': null,
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> searchInChat(String chatId, String query) {
    if (query.isEmpty) {
      return Stream.value([]);
    }

    return _firebaseFirestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).where((data) {
        final message = (data['message'] as String).toLowerCase();
        return message.contains(query.toLowerCase());
      }).toList();
    });
  }
}

class DatabaseResult {
  final bool isSuccess;
  final String? error;

  DatabaseResult.success()
      : isSuccess = true,
        error = null;

  DatabaseResult.error(this.error) : isSuccess = false;
}
