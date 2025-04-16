import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String message;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.message,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      message: json['message'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  bool isSentByMe(String currentUserId) {
    return senderId == currentUserId;
  }
}