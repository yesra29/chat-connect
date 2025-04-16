import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tuneup_task/models/user_profile.dart';
import 'package:tuneup_task/services/alert_service.dart';
import 'package:tuneup_task/services/auth_service.dart';
import 'package:tuneup_task/services/database_services.dart';
import 'package:tuneup_task/services/navigation_service.dart';
import 'package:tuneup_task/widgets/chat_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GetIt _getIt = GetIt.instance;
  late AuthService _authService;
  late NavigationService _navigationService;
  late AlertService _alertService;
  late DatabaseService _databaseService;

  @override
  void initState() {
    super.initState();
    _authService = _getIt.get<AuthService>();
    _navigationService = _getIt.get<NavigationService>();
    _alertService = _getIt.get<AlertService>();
    _databaseService = _getIt.get<DatabaseService>();
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
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return SafeArea(
        child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
            child: _chatList()));
  }

  Widget _chatList() {
    return StreamBuilder<List<UserProfile>>(
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

          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
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
                print("User ${index + 1}: ${user.name} (${user.uid})");
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: ChatTile(
                    userProfile: user,
                    onTap: () async{

                    },
                  ),
                );
              });
        });
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
