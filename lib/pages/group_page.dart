import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group.dart';
import '../models/group_message.dart';
import '../models/user_profile.dart';
import '../services/database_services.dart';
import '../utils.dart';

class GroupPage extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupPage({
    Key? key,
    required this.groupId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseService _databaseService = GetIt.instance.get<DatabaseService>();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _groupStream;
  Map<String, UserProfile> _userProfiles = {};

  @override
  void initState() {
    super.initState();
    _messagesStream = _databaseService.getGroupMessages(widget.groupId);
    _groupStream = _databaseService.getGroupStatus(widget.groupId);
    _loadUserProfiles();
  }

  Future<void> _loadUserProfiles() async {
    try {
      final groupDoc = await _databaseService.getGroupStatus(widget.groupId).first;
      if (groupDoc.exists) {
        final group = Group.fromJson(groupDoc.data()!);
        final profiles = await _databaseService.getUserProfilesByIds(group.participants);
        setState(() {
          _userProfiles = profiles;
        });
      }
    } catch (e) {
      print("Error loading user profiles: $e");
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final result = await _databaseService.sendGroupMessage(
      widget.groupId,
      _messageController.text.trim(),
    );

    if (result.isSuccess) {
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to send message')),
      );
    }
  }

  Future<void> _markMessageAsRead(String messageId) async {
    await _databaseService.markGroupMessageAsRead(widget.groupId, messageId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
            ),
          ),
        ),
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _groupStream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data?.data() != null) {
              final group = Group.fromJson(snapshot.data!.data()!);
              return Text(group.name);
            }
            return Text('Group Chat');
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data?.docs.map((doc) {
                    final data = doc.data();
                    return Message(
                      id: doc.id,
                      senderId: data['senderId'] as String,
                      message: data['message'] as String,
                      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      readStatus: Map<String, bool>.from(data['readStatus'] ?? {}),
                    );
                  }).toList() ?? [];

                  return ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.currentUserId;
                      final senderProfile = _userProfiles[message.senderId];
                      final senderName = senderProfile?.name ?? 'Unknown User';

                      if (!isMe && !message.isReadBy(widget.currentUserId)) {
                        _markMessageAsRead(message.id);
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isMe 
                              ? LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                )
                              : null,
                            color: isMe ? null : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                Text(
                                  senderName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                              ],
                              Text(
                                message.message,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatTimestamp(message.timestamp),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isMe ? Colors.white70 : theme.textTheme.labelSmall?.color,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    SizedBox(width: 4),
                                    Icon(
                                      message.isReadBy(widget.currentUserId)
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 12,
                                      color: message.isReadBy(widget.currentUserId)
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: theme.textTheme.labelSmall?.color),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
} 