import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group.dart';
import '../models/group_message.dart';
import '../models/user_profile.dart';
import '../services/database_services.dart';
import 'dart:async';

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
  final DatabaseService _databaseService =
      GetIt.instance.get<DatabaseService>();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _groupStream;
  Map<String, UserProfile?> _userProfiles = {};
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = _databaseService.getGroupMessages(widget.groupId);
    _groupStream = _databaseService.getGroupStatus(widget.groupId);
  }

  Future<void> _loadUserProfile(String userId) async {
    if (!_userProfiles.containsKey(userId)) {
      final profile = await _databaseService.getUserProfile(userId);
      if (mounted) {
        setState(() {
          _userProfiles[userId] = profile;
        });
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear(); // Clear the controller before sending

    try {
      final result = await _databaseService.sendGroupMessage(
        widget.groupId,
        message,
      );

      if (!result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Failed to send message')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sending message')),
        );
      }
    }
  }

  Future<void> _markMessageAsRead(String messageId) async {
    await _databaseService.markGroupMessageAsRead(widget.groupId, messageId);
  }

  String _formatMessageTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $amPm';
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    // Normalize both dates to midnight in local time
    final localDate1 = DateTime(date1.year, date1.month, date1.day);
    final localDate2 = DateTime(date2.year, date2.month, date2.day);

    // Debug prints

    return localDate1 == localDate2;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    // Debug prints

    if (isSameDay(messageDate, today)) {
      return 'Today';
    } else if (isSameDay(messageDate, yesterday)) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildMessageStatus(Message message) {
    final isMe = message.senderId == widget.currentUserId;
    final readStatus = message.readStatus;
    final totalParticipants = _userProfiles.length;
    final readCount = readStatus.values.where((read) => read).length;
    final isDelivered = readCount > 0;
    final isSeenByAll =
        readCount == totalParticipants - 1; // -1 to exclude sender

    if (!isMe) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSeenByAll
              ? Icons.done_all
              : (isDelivered ? Icons.done_all : Icons.done),
          size: 12,
          color: isSeenByAll ? Colors.blue : Colors.white70,
        ),
        if (isSeenByAll) ...[
          const SizedBox(width: 4),
          const Text(
            'Seen by all',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data()!;
        final typingStatus = Map<String, bool>.from(data['typingStatus'] ?? {});
        final typingUsers = typingStatus.entries
            .where((entry) => entry.value && entry.key != widget.currentUserId)
            .map((entry) => _userProfiles[entry.key]?.name ?? 'Unknown User')
            .toList();

        if (typingUsers.isEmpty) {
          return const SizedBox.shrink();
        }

        String typingText;
        if (typingUsers.length == 1) {
          typingText = '${typingUsers[0]} is typing...';
        } else if (typingUsers.length == 2) {
          typingText = '${typingUsers[0]} and ${typingUsers[1]} are typing...';
        } else {
          typingText =
              '${typingUsers[0]} and ${typingUsers.length - 1} others are typing...';
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            typingText,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _groupStream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data?.data() != null) {
              final group = Group.fromJson(snapshot.data!.data()!);
              return Text(group.name);
            }
            return const Text('Group Chat');
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/chat_bg.png"),
                fit: BoxFit.fitHeight)),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildTypingIndicator(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final messages = snapshot.data?.docs.map((doc) {
                              final data = doc.data();
                              return Message(
                                id: doc.id,
                                senderId: data['senderId'] as String,
                                message: data['message'] as String,
                                timestamp: (data['timestamp'] as Timestamp?)
                                        ?.toDate() ??
                                    DateTime.now(),
                                readStatus: Map<String, bool>.from(
                                    data['readStatus'] ?? {}),
                              );
                            }).toList() ??
                            [];

                        // Sort messages by date in descending order
                        messages
                            .sort((a, b) => b.timestamp.compareTo(a.timestamp));

                        // Group messages by date
                        Map<DateTime, List<Message>> groupedMessages = {};
                        for (var message in messages) {
                          final messageDay = DateTime(
                            message.timestamp.year,
                            message.timestamp.month,
                            message.timestamp.day,
                          );

                          if (!groupedMessages.containsKey(messageDay)) {
                            groupedMessages[messageDay] = [];
                          }
                          groupedMessages[messageDay]!.add(message);
                        }

                        // Sort the dates in descending order
                        final sortedDates = groupedMessages.keys.toList()
                          ..sort((a, b) => b.compareTo(a));

                        // Convert grouped messages to a list for ListView
                        List<Widget> messageWidgets = [];
                        for (var date in sortedDates) {
                          final messages = groupedMessages[date]!;

                          // Add date separator
                          messageWidgets.add(
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDate(date),
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );

                          // Add messages for this date
                          for (var message in messages) {
                            final isMe =
                                message.senderId == widget.currentUserId;
                            final messageDate = message.timestamp;

                            // Load user profile if not already loaded
                            _loadUserProfile(message.senderId);

                            // Mark message as read when it becomes visible
                            if (!isMe &&
                                !message.isReadBy(widget.currentUserId)) {
                              _markMessageAsRead(message.id);
                            }

                            final userProfile = _userProfiles[message.senderId];
                            final userName =
                                userProfile?.name ?? 'Unknown User';

                            messageWidgets.add(
                              Padding(
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
                                        backgroundColor: Colors.blue,
                                        radius: 16,
                                        child: Text(
                                          _getInitials(userName),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: IntrinsicWidth(
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.75,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? Colors.blue
                                                : Colors.grey[200],
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(8),
                                              topRight:
                                                  const Radius.circular(8),
                                              bottomLeft:
                                                  Radius.circular(isMe ? 8 : 0),
                                              bottomRight:
                                                  Radius.circular(isMe ? 0 : 8),
                                            ),
                                          ),
                                          child: IntrinsicHeight(
                                            child: Stack(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    left: 12,
                                                    right: 12,
                                                    top: 8,
                                                    bottom: 30,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if (!isMe) ...[
                                                        Text(
                                                          userName,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                      ],
                                                      Text(
                                                        message.message,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Positioned(
                                                  right: 8,
                                                  bottom: 8,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        _formatMessageTime(
                                                            message.timestamp),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[900],
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      _buildMessageStatus(
                                                          message),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        backgroundColor: Colors.blue,
                                        radius: 16,
                                        child: Text(
                                          _getInitials(userName),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }
                        }

                        return ListView.builder(
                          reverse: true,
                          itemCount: messageWidgets.length,
                          itemBuilder: (context, index) =>
                              messageWidgets[messageWidgets.length - 1 - index],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
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
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
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
    _typingTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }
}
