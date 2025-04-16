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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        actions: [
          IconButton(
              onPressed: () async {
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
              },
              icon: const Icon(
                Icons.logout,
                color: Colors.red,
              ))
        ],
        title: const Text("Messages"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Chats'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(),
          _buildGroupList(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateGroupPage(),
                  ),
                );
              },
              child: Icon(Icons.group_add),
              tooltip: 'Create Group',
            )
          : null,
    );
  }

  Widget _buildChatList() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
        child: StreamBuilder<List<UserProfile>>(
          stream: _databaseService.getUserProfiles(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print("Error in chat list: ${snapshot.error}");
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "Unable to load data: ${snapshot.error}",
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

            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No users found",
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Other users need to register first",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            final users = snapshot.data!;
            print("Found ${users.length} users");

            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                print("User ${index + 1}: ${user.name} (${user.email})");
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _databaseService.getChatStatus(
                    '${_authService.user!.uid}_${user.uid}',
                  ),
                  builder: (context, chatSnapshot) {
                    if (chatSnapshot.hasData && chatSnapshot.data?.data() != null) {
                      final chat = chat_model.Chat.fromJson(chatSnapshot.data!.data()!);
                      final isRead = chat.readStatus[_authService.user!.uid] ?? false;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            user.pfpURL ?? 
                            'https://ui-avatars.com/api/?name=${user.name}&background=random',
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(user.name),
                            if (!isRead) ...[
                              SizedBox(width: 8),
                              Icon(Icons.circle, size: 8, color: Colors.blue),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          chat.lastMessage ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: chat.lastMessageTime != null
                            ? Text(
                                formatTimestamp(chat.lastMessageTime!),
                                style: TextStyle(fontSize: 12),
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                chatId: '${_authService.user!.uid}_${user.uid}',
                                currentUserId: _authService.user!.uid,
                                otherUserId: user.uid,
                              ),
                            ),
                          );
                        },
                      );
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          user.pfpURL ?? 
                          'https://ui-avatars.com/api/?name=${user.name}&background=random',
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text('No messages yet'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              chatId: '${_authService.user!.uid}_${user.uid}',
                              currentUserId: _authService.user!.uid,
                              otherUserId: user.uid,
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
        ),
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
                
                return ListTile(
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
}
