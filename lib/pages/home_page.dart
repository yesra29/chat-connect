import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/database_services.dart';
import '../services/navigation_service.dart';
import '../models/chat.dart' as chat_model;
import '../models/group.dart';
import '../utils.dart';
import 'chat_page.dart';
import 'group_page.dart';
import 'create_group_page.dart';
import '../widgets/custom_app_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GetIt _getIt = GetIt.instance;
  late AuthService _authService;
  late NavigationService _navigationService;
  late AlertService _alertService;
  late DatabaseService _databaseService;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _authService = _getIt.get<AuthService>();
    _navigationService = _getIt.get<NavigationService>();
    _alertService = _getIt.get<AlertService>();
    _databaseService = _getIt.get<DatabaseService>();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search users...',
          prefixIcon: const Icon(Icons.search, color: Color(0XFFA65B17)),
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _databaseService.getUserChats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chatDocs = snapshot.data?.docs ?? [];
        if (chatDocs.isEmpty) {
          return const Center(child: Text('No chats yet'));
        }

        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chatData = chatDocs[index].data();
            final participants =
                List<String>.from(chatData['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != _authService.user!.uid,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) return const SizedBox.shrink();

            return FutureBuilder<UserProfile?>(
              future: _databaseService.getUserProfile(otherUserId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final user = userSnapshot.data!;

                if (_searchQuery.isNotEmpty &&
                    !user.name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase())) {
                  return const SizedBox.shrink();
                }

                final chat = chat_model.Chat.fromJson(chatData);
                final isRead = chat.readStatus[_authService.user!.uid] ?? false;
                final lastMessageTime = chat.lastMessageTime;
                final lastSenderId = chatData['lastSenderId'] as String?;
                final isLastMessageMine =
                    lastSenderId == _authService.user!.uid;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0XFF174EA6),
                    child: Text(
                      getInitials(user.name),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(user.name),
                  subtitle: Text(
                    chat.lastMessage ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (lastMessageTime != null)
                        Text(
                          formatTimestamp(lastMessageTime),
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (!isRead && !isLastMessageMine)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () async {
                    final chatId = await _databaseService.getChatId(
                      _authService.user!.uid,
                      otherUserId,
                    );

                    if (!mounted) return;

                    if (chatId == null || chatId.isEmpty) {
                      _alertService.showToast(
                        text: "Failed to create chat",
                        icon: Icons.error,
                      );
                      return;
                    }

                    final result = await _databaseService.createChat(
                      _authService.user!.uid,
                      otherUserId,
                    );

                    if (!result.isSuccess) {
                      _alertService.showToast(
                        text: "Failed to create chat: ${result.error}",
                        icon: Icons.error,
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          chatId: chatId,
                          currentUserId: _authService.user!.uid,
                          otherUserId: otherUserId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Widget _buildGroupList() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _databaseService.getUserGroups(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "Unable to load groups: ${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!snapshot.hasData ||
                snapshot.data == null ||
                snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No groups found",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            final groups = snapshot.data!.docs.map((doc) {
              return Group.fromJson(doc.data());
            }).toList();

            return ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final isRead = group.isReadBy(_authService.user!.uid);

                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: group.groupImageUrl != null
                            ? NetworkImage(group.groupImageUrl!)
                            : null,
                        child: group.groupImageUrl == null
                            ? Text(group.name[0].toUpperCase())
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(group.name),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.circle,
                                size: 8, color: Colors.blue),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        group.lastMessage ?? 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: group.lastMessageTime != null
                          ? Text(
                              formatTimestamp(group.lastMessageTime!),
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupPage(
                              groupId: group.id,
                              currentUserId: _authService.user!.uid,
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 0,
                      thickness: 0.5,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _getErrorMessage(AuthResult result) {
    switch (result) {
      case AuthResult.operationNotAllowed:
        return "Logout is currently disabled";
      default:
        return "An unexpected error occurred";
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'SmiloChat',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0XFF174EA6),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              position: PopupMenuPosition.under,
              onCanceled: () {
                // Unfocus to prevent keyboard from showing
                FocusScope.of(context).unfocus();
              },
              onSelected: (value) {
                switch (value) {
                  case 'new_chat':
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('New Chat'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                hintText: 'Type a name or number',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                // TODO: Implement real-time search
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Contacts on ChatWave',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<List<UserProfile>>(
                              stream: _databaseService.getUserProfiles(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final users = snapshot.data!;
                                return SizedBox(
                                  height: 300,
                                  child: ListView.builder(
                                    itemCount: users.length,
                                    itemBuilder: (context, index) {
                                      final user = users[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: user.pfpURL != null
                                              ? NetworkImage(user.pfpURL!)
                                              : null,
                                          child: user.pfpURL == null
                                              ? Text(
                                                  user.name?[0].toUpperCase() ??
                                                      'U')
                                              : null,
                                        ),
                                        title:
                                            Text(user.name ?? 'Unknown User'),
                                        subtitle: Text(user.email ?? ''),
                                        onTap: () async {
                                          final chatId =
                                              await _databaseService.getChatId(
                                            _authService.user!.uid,
                                            user.uid,
                                          );
                                          if (!mounted) return;

                                          // Add validation for chat ID
                                          if (chatId == null ||
                                              chatId.isEmpty) {
                                            _alertService.showToast(
                                              text: "Failed to create chat",
                                              icon: Icons.error,
                                            );
                                            return;
                                          }

                                          // Create chat if it doesn't exist
                                          final result =
                                              await _databaseService.createChat(
                                            _authService.user!.uid,
                                            user.uid,
                                          );

                                          if (!result.isSuccess) {
                                            _alertService.showToast(
                                              text:
                                                  "Failed to create chat: ${result.error}",
                                              icon: Icons.error,
                                            );
                                            return;
                                          }

                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatPage(
                                                chatId: chatId,
                                                currentUserId:
                                                    _authService.user!.uid,
                                                otherUserId: user.uid,
                                              ),
                                            ),
                                          );
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
                    );
                    break;
                  case 'new_group':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateGroupPage(),
                      ),
                    );
                    break;
                  case 'read_all':
                    // TODO: Implement read all functionality
                    _alertService.showToast(
                      text: "Marking all messages as read",
                      icon: Icons.check,
                    );
                    break;
                  case 'settings':
                    // TODO: Navigate to settings page
                    _alertService.showToast(
                      text: "Settings page coming soon",
                      icon: Icons.settings,
                    );
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'new_chat',
                  child: const Row(
                    children: [
                      Icon(Icons.chat, color: Color(0XFFA65B17)),
                      SizedBox(width: 8),
                      Text(
                        'New Chat',
                        style: TextStyle(color: Color(0XFFA65B17)),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'new_group',
                  child: Row(
                    children: [
                      Icon(Icons.group_add, color: Color(0XFFA65B17)),
                      SizedBox(width: 8),
                      Text(
                        'New Group',
                        style: TextStyle(color: Color(0XFFA65B17)),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, color: Color(0XFFA65B17)),
                      SizedBox(width: 8),
                      Text(
                        'Read All',
                        style: TextStyle(color: Color(0XFFA65B17)),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Color(0XFFA65B17)),
                      SizedBox(width: 8),
                      Text(
                        'Settings',
                        style: TextStyle(color: Color(0XFFA65B17)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/home_page_bg.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(
              color: Colors.white.withOpacity(0.7),
            ),
            Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChatList(),
                      _buildGroupList(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _signOut() async {
    AuthResult result = await _authService.logout();
    if (result == AuthResult.success) {
      _alertService.showToast(
          text: "Successfully logged out!", icon: Icons.check);
      _navigationService.pushReplacementNamed("/login");
    } else {
      _alertService.showToast(
          text: "Failed to logout: ${_getErrorMessage(result)}",
          icon: Icons.error);
    }
  }
}
