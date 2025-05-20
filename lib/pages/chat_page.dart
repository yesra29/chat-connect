import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../services/alert_service.dart';
import '../services/database_services.dart';
import 'dart:async';
import '../widgets/custom_app_bar.dart';

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
  final ScrollController _scrollController = ScrollController();
  final GetIt _getIt = GetIt.instance;
  late DatabaseService _databaseService;
  late AlertService _alertService;
  UserProfile? _otherUser;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isInitialized = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    if (_isInitializing) {
      print("Services are already being initialized");
      return;
    }

    _isInitializing = true;
    try {
      print("Starting service initialization in ChatPage");

      try {
        _databaseService = _getIt.get<DatabaseService>();
        print("DatabaseService initialized");
      } catch (e) {
        print("Error initializing DatabaseService: $e");
        rethrow;
      }

      try {
        _alertService = _getIt.get<AlertService>();
        print("AlertService initialized");
      } catch (e) {
        print("Error initializing AlertService: $e");
        rethrow;
      }

      _isInitialized = true;
      print("All services initialized successfully in ChatPage");

      await _loadUsers();
    } catch (e, stackTrace) {
      print("Error during service initialization: $e");
      print("Stack trace: $stackTrace");
      _isInitialized = false;
      if (mounted) {
        _alertService.showToast(
          text: "Error initializing services",
          icon: Icons.error,
        );
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _loadUsers() async {
    try {
      final otherUser =
          await _databaseService.getUserProfile(widget.otherUserId);
      if (mounted) {
        setState(() {
          _otherUser = otherUser;
        });
      }
    } catch (e) {
      print("Error loading user profiles: $e");
      if (mounted) {
        _alertService.showToast(
          text: "Error loading user profiles",
          icon: Icons.error,
        );
      }
    }
  }

  String _getUserName(UserProfile? user) {
    if (user == null) return 'Unknown User';
    return user.name.isNotEmpty ? user.name : 'Unknown User';
  }

  void _startTyping() {
    if (!_isTyping) {
      _isTyping = true;
      _databaseService.updateTypingStatus(
          widget.chatId, widget.currentUserId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _databaseService.updateTypingStatus(
          widget.chatId, widget.currentUserId, false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    _stopTyping();
    _messageController.clear();

    print("Sending message in chat ${widget.chatId}");
    print("Current user: ${widget.currentUserId}");
    print("Other user: ${widget.otherUserId}");

    try {
      final result = await _databaseService.sendMessage(
        widget.chatId,
        widget.currentUserId,
        message,
      );

      if (!result.isSuccess) {
        if (mounted) {
          _alertService.showToast(
            text: "Failed to send message: ${result.error}",
            icon: Icons.error,
          );
        }
      }
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {
        _alertService.showToast(
          text: "Error sending message",
          icon: Icons.error,
        );
      }
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search, color: Color(0XFF174EA6)),
              title: const Text('Search in Chat'),
              onTap: () {
                Navigator.pop(context);
                _showSearchDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Color(0XFF174EA6)),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Color(0XFF174EA6)),
              title: const Text('Clear Chat'),
              onTap: () {
                Navigator.pop(context);
                _showClearChatConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Search in Chat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Type to search...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (searchQuery.isNotEmpty)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream:
                      _databaseService.searchInChat(widget.chatId, searchQuery),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return const Text('No messages found');
                    }

                    return SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return ListTile(
                            title: Text(message['message'] ?? ''),
                            subtitle: Text(
                              _formatDate(
                                  (message['timestamp'] as Timestamp).toDate()),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content:
            Text('Are you sure you want to block ${_getUserName(_otherUser)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _databaseService.blockUser(
                    widget.currentUserId, widget.otherUserId);
                if (mounted) {
                  Navigator.pop(context); // Return to previous screen
                  _alertService.showToast(
                    text: 'User blocked successfully',
                    icon: Icons.check_circle,
                  );
                }
              } catch (e) {
                if (mounted) {
                  _alertService.showToast(
                    text: 'Failed to block user: $e',
                    icon: Icons.error,
                  );
                }
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
            'Are you sure you want to clear all messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _databaseService.clearChat(widget.chatId);
                if (mounted) {
                  _alertService.showToast(
                    text: 'Chat cleared successfully',
                    icon: Icons.check_circle,
                  );
                }
              } catch (e) {
                if (mounted) {
                  _alertService.showToast(
                    text: 'Failed to clear chat: $e',
                    icon: Icons.error,
                  );
                }
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['senderId'] == widget.currentUserId;
    final timestamp = message['timestamp'] as Timestamp?;
    final messageDate = timestamp?.toDate() ?? DateTime.now();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0XFFA65B17) : const Color(0XFF174EA6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message['message'] ?? '',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(messageDate),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (messageDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _databaseService.getChatStatus(widget.chatId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data()!;
        final typingStatus = Map<String, bool>.from(data['typingStatus'] ?? {});
        final isOtherUserTyping = typingStatus[widget.otherUserId] ?? false;

        if (!isOtherUserTyping) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Row(
            children: [
              Text(
                _getUserName(_otherUser),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'is typing...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _getUserName(_otherUser),
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/chat_bg.png"),
            fit: BoxFit.fitHeight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildTypingIndicator(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _databaseService.getChatMessages(widget.chatId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          print("Error in StreamBuilder: ${snapshot.error}");
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
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

                        messages.sort((a, b) {
                          final aTime =
                              (a.data()['timestamp'] as Timestamp?)?.toDate() ??
                                  DateTime.now();
                          final bTime =
                              (b.data()['timestamp'] as Timestamp?)?.toDate() ??
                                  DateTime.now();
                          return aTime.compareTo(bTime);
                        });

                        return ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(messages[index].data());
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Container(
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
                      onChanged: (_) => _startTyping(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0XFFA65B17),
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
    _scrollController.dispose();
    _typingTimer?.cancel();
    _stopTyping();
    _messageController.dispose();
    super.dispose();
  }
}
