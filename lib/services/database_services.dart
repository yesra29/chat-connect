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
    
    _chatsCollection = _firebaseFirestore.collection('chats').withConverter<Map<String, dynamic>>(
      fromFirestore: (snapshot, _) => snapshot.data()!,
      toFirestore: (data, _) => data,
    );

    _groupsCollection = _firebaseFirestore.collection('groups').withConverter<Map<String, dynamic>>(
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
      print("Successfully created user profile for ${userProfile.name}");
      return DatabaseResult.success();
    } on FirebaseException catch (e) {
      print("Firebase error creating user profile: ${e.message}");
      return DatabaseResult.error(e.message ?? 'Unknown Firebase error');
    } catch (e) {
      print("Unexpected error creating user profile: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<List<UserProfile>> getUserProfiles() {
    try {
      if (_authService.user == null) {
        print("No current user found");
        return Stream.value([]);
      }
      
      final currentUser = _authService.user!;
      print("Current user UID: ${currentUser.uid}");
      print("Current user email: ${currentUser.email}");
      
      return _usersCollection
          .where("uid", isNotEqualTo: currentUser.uid)
          .snapshots()
          .map((snapshot) {
            print("Firestore snapshot received");
            print("Snapshot size: ${snapshot.docs.length}");
            
            final users = snapshot.docs
                .map((doc) {
                  final user = doc.data();
                  print("Processing user: ${user.name} (${user.email}) with UID: ${user.uid}");
                  return user;
                })
                .where((user) => user != null && user.uid != currentUser.uid)
                .toList();
            
            print("Found ${users.length} users after filtering");
            users.forEach((user) {
              print("Available user: ${user.name} (${user.email})");
            });
            
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
      if (uid.isEmpty) {
        return DatabaseResult.error("User ID cannot be empty");
      }

      final user = await getUserProfile(uid);
      if (user == null) {
        return DatabaseResult.error("User not found");
      }

      await _usersCollection.doc(uid).update(updates);
      print("Successfully updated user profile for $uid");
      return DatabaseResult.success();
    } on FirebaseException catch (e) {
      print("Firebase error updating user profile: ${e.message}");
      return DatabaseResult.error(e.message ?? 'Unknown Firebase error');
    } catch (e) {
      print("Unexpected error updating user profile: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      if (uid.isEmpty) {
        print("Empty UID provided");
        return null;
      }

      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) {
        print("User document not found for UID: $uid");
        return null;
      }

      return doc.data();
    } catch (e) {
      print("Error getting user profile: $e");
      return null;
    }
  }

  // Group functionality
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
        return DatabaseResult.error("Group cannot have more than 20 participants");
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
      print("Error creating group: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserGroups() {
    try {
      final currentUser = _authService.user;
      if (currentUser == null) {
        return Stream.empty();
      }

      return _groupsCollection
          .where('participants', arrayContains: currentUser.uid)
          .snapshots();
    } catch (e) {
      print("Error getting user groups: $e");
      return Stream.empty();
    }
  }

  Future<DatabaseResult> addGroupParticipants(String groupId, List<String> userIds) async {
    try {
      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        return DatabaseResult.error("Group not found");
      }

      final group = Group.fromJson(groupDoc.data()!);
      if (group.participants.length + userIds.length > 20) {
        return DatabaseResult.error("Group cannot have more than 20 participants");
      }

      await _groupsCollection.doc(groupId).update({
        'participants': FieldValue.arrayUnion(userIds),
      });

      return DatabaseResult.success();
    } catch (e) {
      print("Error adding group participants: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Future<DatabaseResult> removeGroupParticipants(String groupId, List<String> userIds) async {
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
      print("Error removing group participants: $e");
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
      print("Error getting group messages: $e");
      return Stream.empty();
    }
  }

  Future<DatabaseResult> sendGroupMessage(String groupId, String message) async {
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

      final messageRef = await _groupsCollection.doc(groupId).collection('messages').add({
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
      print("Error sending group message: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Future<DatabaseResult> markGroupMessageAsRead(String groupId, String messageId) async {
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
      print("Error marking group message as read: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getGroupStatus(String groupId) {
    try {
      return _groupsCollection.doc(groupId).snapshots();
    } catch (e) {
      print("Error getting group status: $e");
      return Stream.empty();
    }
  }

  // Existing chat functionality
  Future<String> getChatId(String uid1, String uid2) {
    // Always sort UIDs to ensure consistent chat ID regardless of who initiates
    final sortedIds = [uid1, uid2]..sort();
    final chatId = '${sortedIds[0]}_${sortedIds[1]}';
    print("Generated chat ID: $chatId for users: $uid1 and $uid2");
    return Future.value(chatId);
  }

  Future<bool> checkChatExists(String uid1, String uid2) async {
    try {
      final chatId = await getChatId(uid1, uid2);
      print("Checking chat existence for ID: $chatId");
      final doc = await _chatsCollection.doc(chatId).get();
      final exists = doc.exists;
      print("Chat ${exists ? 'exists' : 'does not exist'} for ID: $chatId");
      return exists;
    } catch (e) {
      print("Error checking chat existence: $e");
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
      print("Generated chat ID: $chatId");
      
      // Check if chat already exists
      final chatExists = await checkChatExists(uid1, uid2);
      if (chatExists) {
        print("Chat already exists with ID: $chatId");
        return DatabaseResult.success(); // Return success if chat already exists
      }

      print("Creating new chat with ID: $chatId");
      await _chatsCollection.doc(chatId).set({
        'participants': [uid1, uid2],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
        'readStatus': {},
      });

      print("Successfully created chat between ${user1.name} and ${user2.name}");
      return DatabaseResult.success();
    } catch (e) {
      print("Error creating chat: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getChatMessages(String chatId) {
    try {
      print("Getting messages for chat: $chatId");
      return _chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            print("Received ${snapshot.docs.length} messages");
            snapshot.docs.forEach((doc) {
              final data = doc.data();
              print("Message data: ${data.toString()}");
              print("Is media: ${data['isMedia']}");
              print("Message content: ${data['message']}");
            });
            return snapshot;
          });
    } catch (e) {
      print("Error getting chat messages: $e");
      return Stream.empty();
    }
  }

  Future<DatabaseResult> sendMessage(
    String chatId,
    String senderId,
    String message, {
    bool isMedia = false,
  }) async {
    try {
      print("Sending message to chat: $chatId");
      print("Message type: ${isMedia ? 'Media' : 'Text'}");
      print("Message content: $message");

      final messageData = {
        'senderId': senderId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isMedia': isMedia,
        'readStatus': {
          senderId: true,
        },
      };

      // Add message to messages subcollection
      final messageRef = await _firebaseFirestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      print("Message added with ID: ${messageRef.id}");

      // Update chat document
      await _firebaseFirestore.collection('chats').doc(chatId).update({
        'lastMessage': isMedia ? '📷 Image' : message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'readStatus': {
          senderId: true,
        },
      });

      print("Chat document updated successfully");
      return DatabaseResult.success();
    } catch (e) {
      print("Error sending message: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Future<DatabaseResult> markMessageAsRead(String chatId, String messageId, String userId) async {
    try {
      await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readStatus.$userId': true,
      });

      // Also update chat read status
      await _chatsCollection.doc(chatId).update({
        'readStatus.$userId': true,
      });

      return DatabaseResult.success();
    } catch (e) {
      print("Error marking message as read: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Future<DatabaseResult> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _chatsCollection.doc(chatId).update({
        'typingStatus.$userId': isTyping,
      });
      return DatabaseResult.success();
    } catch (e) {
      print("Error updating typing status: $e");
      return DatabaseResult.error(e.toString());
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getChatStatus(String chatId) {
    return _chatsCollection.doc(chatId).snapshots();
  }

  Future<void> updateGroupTypingStatus(String groupId, String userId, bool isTyping) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'typingStatus.$userId': isTyping,
      });
    } catch (e) {
      print("Error updating group typing status: $e");
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserChats() {
    return _firebaseFirestore
        .collection('chats')
        .where('participants', arrayContains: _authService.user!.uid)
        .snapshots();
  }

  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    try {
      // Add to blocked users collection
      await _firebaseFirestore.collection('users').doc(currentUserId).collection('blocked_users').doc(blockedUserId).set({
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Delete the chat if it exists
      final chatQuery = await _firebaseFirestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in chatQuery.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(blockedUserId)) {
          await doc.reference.delete();
          break;
        }
      }
    } catch (e) {
      print('Error blocking user: $e');
      rethrow;
    }
  }

  Future<void> clearChat(String chatId) async {
    try {
      // Get all messages in the chat
      final messagesQuery = await _firebaseFirestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      // Delete all messages
      final batch = _firebaseFirestore.batch();
      for (var doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Update chat metadata
      batch.update(_firebaseFirestore.collection('chats').doc(chatId), {
        'lastMessage': null,
        'lastMessageTime': null,
        'lastSenderId': null,
      });

      await batch.commit();
    } catch (e) {
      print('Error clearing chat: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> searchInChat(String chatId, String query) {
    return _firebaseFirestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('message', isGreaterThanOrEqualTo: query)
        .where('message', isLessThanOrEqualTo: query + '\uf8ff')
        .orderBy('message')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
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
