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
                  print("Processing document: ${doc.id}");
                  print("Document data: ${doc.data()}");
                  return doc.data();
                })
                .where((profile) => profile != null)
                .cast<UserProfile>()
                .toList();
            
            // Filter out users who don't have an email (not authenticated)
            final authenticatedUsers = users.where((user) => 
              user.email != null && 
              user.email != currentUser.email
            ).toList();
            
            print("Total authenticated users found: ${authenticatedUsers.length}");
            if (authenticatedUsers.isEmpty) {
              print("No authenticated users found in the database");
            } else {
              print("Found authenticated users: ${authenticatedUsers.map((u) => '${u.name} (${u.email})').join(', ')}");
            }
            return authenticatedUsers;
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
    // Make this synchronous since we're just doing string operations
    final sortedIds = [uid1, uid2]..sort();
    return Future.value('${sortedIds[0]}_${sortedIds[1]}');
  }

  Future<bool> checkChatExists(String uid1, String uid2) async {
    try {
      final chatId = await getChatId(uid1, uid2);
      print("Checking chat existence for ID: $chatId");
      final doc = await _chatsCollection.doc(chatId).get();
      print("Chat exists: ${doc.exists} for ID: $chatId");
      return doc.exists;
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
      return _chatsCollection
          .doc(chatId)
          .collection('messages')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          )
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      print("Error getting chat messages: $e");
      return Stream.empty();
    }
  }

  Future<DatabaseResult> sendMessage(String chatId, String senderId, String message) async {
    try {
      if (message.trim().isEmpty) {
        return DatabaseResult.error("Message cannot be empty");
      }

      print("Attempting to send message in chat: $chatId");

      // Check if chat exists
      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (!chatDoc.exists) {
        print("Chat does not exist, creating new chat...");
        // Extract UIDs from chatId (format: "uid1_uid2")
        final uids = chatId.split('_');
        if (uids.length != 2) {
          print("Invalid chat ID format: $chatId");
          return DatabaseResult.error("Invalid chat ID format");
        }

        // Create chat first
        print("Creating chat between ${uids[0]} and ${uids[1]}");
        await _chatsCollection.doc(chatId).set({
          'participants': uids,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageTime': null,
          'readStatus': {},
        });
      }

      print("Sending message to chat: $chatId");
      final messageRef = await _chatsCollection.doc(chatId).collection('messages').add({
        'senderId': senderId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'readStatus': {senderId: true},
      });

      // Update last message in chat document
      await _chatsCollection.doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'readStatus': {senderId: true},
      });

      print("Successfully sent message in chat $chatId");
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> getChatStatus(String chatId) {
    try {
      return _chatsCollection.doc(chatId).snapshots();
    } catch (e) {
      print("Error getting chat status: $e");
      return Stream.empty();
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
}
