import 'package:cloud_firestore/cloud_firestore.dart';

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
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      message: json['message'] as String,
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
