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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search, color: Color(0XFFA65B17)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0XFFA65B17)),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildChatList() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _databaseService.getUserChats(),
                builder: (context, chatSnapshot) {
                  if (chatSnapshot.hasError) {
                    print("Error in chat list: ${chatSnapshot.error}");
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            "Unable to load chats: ${chatSnapshot.error}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  }

                  if (chatSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No chats yet",
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Start a new conversation",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final chatDocs = chatSnapshot.data!.docs;
                  return ListView.builder(
                    itemCount: chatDocs.length,
                    itemBuilder: (context, index) {
                      final chatData = chatDocs[index].data();
                      final participants = List<String>.from(chatData['participants'] ?? []);
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
                          final chat = chat_model.Chat.fromJson(chatData);
                          final isRead = chat.readStatus[_authService.user!.uid] ?? false;
                          final lastMessageTime = chat.lastMessageTime;
                          final lastSenderId = chatData['lastSenderId'] as String?;
                          final isLastMessageMine = lastSenderId == _authService.user!.uid;

                          return Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    user.pfpURL ?? 
                                    'https://ui-avatars.com/api/?name=${user.name}&background=random',
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(user.name ?? 'Unknown User'),
                                    if (!isRead && !isLastMessageMine) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
                                    if (isLastMessageMine) ...[
                                      const Icon(
                                        Icons.done_all,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        chat.lastMessage ?? 'No messages yet',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: lastMessageTime != null
                                    ? Text(
                                        formatTimestamp(lastMessageTime),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatPage(
                                        chatId: chatDocs[index].id,
                                        currentUserId: _authService.user!.uid,
                                        otherUserId: otherUserId,
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
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
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
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
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

            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
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
                            SizedBox(width: 8),
                            Icon(Icons.circle, size: 8, color: Colors.blue),
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
                              style: TextStyle(fontSize: 12),
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
        appBar: CustomAppBar(
          title: 'SmiloChat',
          showBackButton: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                // Add search functionality
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                // Add more options menu
              },
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
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton(
                onPressed: () {
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
                                            ? Text(user.name?[0].toUpperCase() ?? 'U')
                                            : null,
                                      ),
                                      title: Text(user.name ?? 'Unknown User'),
                                      subtitle: Text(user.email ?? ''),
                                      onTap: () async {
                                        final chatId = await _databaseService.getChatId(
                                          _authService.user!.uid,
                                          user.uid,
                                        );
                                        if (!mounted) return;
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatPage(
                                              chatId: chatId,
                                              currentUserId: _authService.user!.uid,
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
                },
                backgroundColor: const Color(0XFFA65B17),
                child: const Icon(Icons.chat, color: Colors.white),
                tooltip: 'New Chat',
              )
            : FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateGroupPage(),
                    ),
                  );
                },
                backgroundColor: const Color(0XFFA65B17),
                child: const Icon(Icons.group_add, color: Colors.white),
                tooltip: 'Create Group',
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
