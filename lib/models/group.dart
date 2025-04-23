import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tuneup_task/models/user_profile.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final List<String> participants;
  final String? groupImageUrl;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, bool> readStatus;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.participants,
    this.groupImageUrl,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.readStatus = const {},
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      adminId: json['adminId'] as String,
      participants: List<String>.from(json['participants'] as List),
      groupImageUrl: json['groupImageUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null 
          ? (json['lastMessageTime'] as Timestamp).toDate()
          : null,
      readStatus: Map<String, bool>.from(json['readStatus'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'adminId': adminId,
      'participants': participants,
      'groupImageUrl': groupImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null 
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'readStatus': readStatus,
    };
  }

  bool isAdmin(String userId) => adminId == userId;
  bool isParticipant(String userId) => participants.contains(userId);
  bool isReadBy(String userId) => readStatus[userId] ?? false;
} 