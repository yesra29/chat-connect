import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType{Text,Image}

class Message{
  String? senderID;
  String? content;
  MessageType? messageType;
  Timestamp? sentAt;

  Message({
    required this.senderID,
    required this.content,
    required this.messageType,
    required this.sentAt,
});



class Message {
  Message.fromJson(Map<String,dynamic>json) {
}

Map<String,dynamic> toJson() {
    final Map<String,dynamic> data = new Map<String,dynamic>();
    data['senderID'] = senderID;
    data['content'] = content;
    data['sentAt'] = sentAt;
    data['messageType'] = messageType!.name;
    return data;
}
}