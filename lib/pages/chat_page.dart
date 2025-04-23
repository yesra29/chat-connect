import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat.dart' as chat_model;
import '../models/user_profile.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/database_services.dart';
import '../utils.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;

  const ChatPage({
    Key? key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final GetIt _getIt = GetIt.instance;
  late DatabaseService _databaseService;
  late AlertService _alertService;
  UserProfile? _otherUser;

  @override
  void initState() {
    super.initState();
    _databaseService = _getIt.get<DatabaseService>();
    _alertService = _getIt.get<AlertService>();
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final user = await _databaseService.getUserProfile(widget.otherUserId);
    if (mounted) {
      setState(() {
        _otherUser = user;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    print("Sending message in chat ${widget.chatId}");
    print("Current user: ${widget.currentUserId}");
    print("Other user: ${widget.otherUserId}");

    final result = await _databaseService.sendMessage(
      widget.chatId,
      widget.currentUserId,
      message,
    );

    if (result.isSuccess) {
      _messageController.clear();
    } else {
      _alertService.showToast(
        text: "Failed to send message: ${result.error}",
        icon: Icons.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUser?.name ?? 'Chat'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _databaseService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data?.docs ?? [];
                print("Number of messages: ${messages.length}");

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data();
                    final isMe = message['senderId'] == widget.currentUserId;
                    final timestamp = message['timestamp'] as Timestamp?;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              backgroundImage: NetworkImage(
                                _otherUser?.pfpURL ??
                                    'https://ui-avatars.com/api/?name=${_otherUser?.name ?? ""}&background=random',
                              ),
                              radius: 16,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF2196F3) : Colors.grey[300],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['message'] as String,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  if (timestamp != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      formatTimestamp(timestamp.toDate()),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.black.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundImage: NetworkImage(
                                'https://ui-avatars.com/api/?name=Me&background=random',
                              ),
                              radius: 16,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
} 