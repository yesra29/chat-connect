import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, bool> readStatus;

  Chat({
    required this.id,
    required this.participants,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.readStatus = const {},
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id']?.toString() ?? '',
      participants: List<String>.from(json['participants'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: json['lastMessage']?.toString(),
      lastMessageTime: (json['lastMessageTime'] as Timestamp?)?.toDate(),
      readStatus: Map<String, bool>.from(json['readStatus'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'lastMessageTime':
          lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'readStatus': readStatus,
    };
  }

  // Get the other participant's ID
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => participants.first,
    );
  }

  bool isReadBy(String userId) {
    return readStatus[userId] ?? false;
  }
}

class Message {
  final String id;
  final String senderId;
  final String message;
  final DateTime timestamp;
  final Map<String, bool> readStatus;

  Message({
    required this.id,
    required this.senderId,
    required this.message,
    required this.timestamp,
    this.readStatus = const {},
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readStatus: Map<String, bool>.from(json['readStatus'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'readStatus': readStatus,
    };
  }

  bool isSentByMe(String currentUserId) {
    return senderId == currentUserId;
  }

  bool isReadBy(String userId) {
    return readStatus[userId] ?? false;
  }
}
