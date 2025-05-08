import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../services/alert_service.dart';
import '../services/database_services.dart';
import '../services/media_service.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
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
  late MediaService _mediaService;
  UserProfile? _otherUser;
  UserProfile? _currentUser;
  Timer? _typingTimer;
  bool _isTyping = false;
  final ImagePicker _picker = ImagePicker();
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _showScrollButton = false;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      final delta = MediaQuery.of(context).size.height * 0.05; // 5% of screen height
      
      setState(() {
        _showScrollButton = currentScroll < maxScroll - delta;
      });
    }
  }

  Future<void> _initializeServices() async {
    if (_isInitializing) {
      print("Services are already being initialized");
      return;
    }

    _isInitializing = true;
    try {
      print("Starting service initialization in ChatPage");
      
      // Initialize services one by one with error handling
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

      try {
        _mediaService = _getIt.get<MediaService>();
        print("MediaService initialized");
      } catch (e) {
        print("Error initializing MediaService: $e");
        rethrow;
      }

      _isInitialized = true;
      print("All services initialized successfully in ChatPage");
      
      // Load users after services are initialized
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

  Future<void> _ensureInitialized() async {
    if (!_isInitialized && !_isInitializing) {
      print("Services not initialized, attempting to initialize...");
      await _initializeServices();
    }
  }

  Future<void> _loadUsers() async {
    try {
      final otherUser = await _databaseService.getUserProfile(widget.otherUserId);
      final currentUser = await _databaseService.getUserProfile(widget.currentUserId);
      if (mounted) {
        setState(() {
          _otherUser = otherUser;
          _currentUser = currentUser;
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

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _getUserName(UserProfile? user) {
    if (user == null) return 'Unknown User';
    return user.name.isNotEmpty ? user.name : 'Unknown User';
  }

  void _startTyping() {
    if (!_isTyping) {
      _isTyping = true;
      _databaseService.updateTypingStatus(widget.chatId, widget.currentUserId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _databaseService.updateTypingStatus(widget.chatId, widget.currentUserId, false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    _stopTyping();
    _messageController.clear(); // Clear the controller before sending

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

  Future<void> _pickAndSendImage(ImageSource source) async {
    await _ensureInitialized();

    if (!_isInitialized) {
      print("Services still not initialized after attempt");
      if (mounted) {
        _alertService.showToast(
          text: "Please wait while services are initializing",
          icon: Icons.error,
        );
      }
      return;
    }

    try {
      print("Starting media pick process...");
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedFile == null) {
        print("No file was picked");
        return;
      }

      print("File picked successfully: ${pickedFile.path}");
      print("File name: ${pickedFile.name}");
      print("File size: ${await pickedFile.length()} bytes");

      // Show loading indicator
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
        _alertService.showToast(
          text: "Uploading media...",
          icon: Icons.upload_file,
        );
      }

      // Upload media to Firebase Storage
      print("Starting media upload to Firebase Storage...");
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String storagePath = 'images/$fileName';
      print("Storage path: $storagePath");
      
      final Reference storageRef = _storage.ref().child(storagePath);
      print("Storage reference created: ${storageRef.fullPath}");

      // Create file metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': widget.currentUserId,
          'chatId': widget.chatId,
        },
      );

      // Upload file with metadata
      final UploadTask uploadTask = storageRef.putFile(
        File(pickedFile.path),
        metadata,
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print('Upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
        print('Upload state: ${snapshot.state}');
      });

      // Wait for upload to complete
      final TaskSnapshot taskSnapshot = await uploadTask;
      print("Upload completed. State: ${taskSnapshot.state}");
      print("Bytes transferred: ${taskSnapshot.bytesTransferred}");

      // Get download URL
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print("Download URL obtained: $downloadUrl");

      // Send message with media URL
      print("Sending message with media URL...");
      final result = await _databaseService.sendMessage(
        widget.chatId,
        widget.currentUserId,
        downloadUrl,
        isMedia: true,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!result.isSuccess) {
        print("Failed to send media message: ${result.error}");
        if (mounted) {
          _alertService.showToast(
            text: "Failed to send media: ${result.error}",
            icon: Icons.error,
          );
        }
      } else {
        print("Media message sent successfully");
        if (mounted) {
          _alertService.showToast(
            text: "Media sent successfully",
            icon: Icons.check_circle,
          );
        }
      }
    } catch (e, stackTrace) {
      print("Error picking/sending media: $e");
      print("Stack trace: $stackTrace");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _alertService.showToast(
          text: "Error sending media: ${e.toString()}",
          icon: Icons.error,
        );
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
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
                  stream: _databaseService.searchInChat(widget.chatId, searchQuery),
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
                      height: 200,
                      child: ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final timestamp = message['timestamp'] as Timestamp?;
                          final messageDate = timestamp?.toDate() ?? DateTime.now();
                          
                          return ListTile(
                            title: Text(message['message']),
                            subtitle: Text(_formatMessageTime(messageDate)),
                            onTap: () {
                              // TODO: Scroll to message
                              Navigator.pop(context);
                            },
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
              child: const Text('Cancel'),
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
        content: Text('Are you sure you want to block ${_getUserName(_otherUser)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _databaseService.blockUser(widget.currentUserId, widget.otherUserId);
                if (mounted) {
                  _alertService.showToast(
                    text: 'User blocked successfully',
                    icon: Icons.check_circle,
                  );
                  Navigator.pop(context); // Return to previous screen
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
        content: const Text('Are you sure you want to clear all messages? This action cannot be undone.'),
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

  Widget _buildMessageStatus(QueryDocumentSnapshot<Map<String, dynamic>> messageDoc) {
    final message = messageDoc.data();
    final isMe = message['senderId'] == widget.currentUserId;
    final readStatus = Map<String, bool>.from(message['readStatus'] ?? {});
    final isDelivered = readStatus.containsKey(widget.otherUserId);
    final isSeen = readStatus[widget.otherUserId] ?? false;

    if (!isMe) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSeen ? Icons.done_all : (isDelivered ? Icons.done_all : Icons.done),
          size: 12,
          color: isSeen ? Colors.blue : Colors.white70,
        ),
        if (isSeen) ...[
          const SizedBox(width: 4),
          const Text(
            'Seen',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ],
    );
  }

  String _formatMessageTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $amPm';
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    // Normalize both dates to midnight in local time
    final localDate1 = DateTime(date1.year, date1.month, date1.day);
    final localDate2 = DateTime(date2.year, date2.month, date2.day);
    
    // Debug prints
    print('Comparing dates:');
    print('Date 1: $localDate1');
    print('Date 2: $localDate2');
    print('Are same day: ${localDate1 == localDate2}');
    
    return localDate1 == localDate2;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    // Debug prints
    print('Current time: $now');
    print('Today date: $today');
    print('Message date: $messageDate');
    print('Is same day: ${isSameDay(messageDate, today)}');

    if (isSameDay(messageDate, today)) {
      return 'Today';
    } else if (isSameDay(messageDate, yesterday)) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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
    final isMedia = message['isMedia'] ?? false;
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
        child: isMedia
            ? GestureDetector(
                onTap: () {
                  // Show full-screen image
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        body: Center(
                          child: Image.network(
                            message['message'],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    message['message'],
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print("Error loading image: $error");
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.error),
                        ),
                      );
                    },
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message['message'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(messageDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _getUserName(_otherUser),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage("assets/chat_bg.png"),fit: BoxFit.fitHeight)
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

                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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

                        // Sort messages by date in ascending order (oldest first)
                        messages.sort((a, b) {
                          final aTime = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                          final bTime = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                          return aTime.compareTo(bTime);
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          itemCount: messages.length,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final message = messages[messages.length - 1 - index].data();
                            print("Building message: ${message.toString()}");
                            return _buildMessageBubble(message);
                          },
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
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.attach_file, color: Color(0XFFA65B17)),
                          onPressed: _showMediaOptions,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
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
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _typingTimer?.cancel();
    _stopTyping();
    _messageController.dispose();
    super.dispose();
  }
} 