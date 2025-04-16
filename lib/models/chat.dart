import 'package:tuneup_task/models/messages.dart';


class Chat {
  String? id;
  List<String> ?participants;
  List<Message> ?messages;
}

Chat ({
  required this.id,
  required this.participants,
  required this.messages,
});

Chat.fromJson(Map<String,dynamic>json) {

}